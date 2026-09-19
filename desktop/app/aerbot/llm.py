"""LLM provider client — real model calls over OpenAI-compatible and
Anthropic Messages APIs. Normalizes both into one ChatResponse so the agent
loop is provider-agnostic.

Providers (first match wins):
  1. OPENAI_API_KEY (+ optional OPENAI_API_BASE or KTTQ_API_BASE)  [OpenAI-compatible]
  2. ANTHROPIC_API_KEY                                              [Anthropic]
  3. OLLAMA_HOST (default http://localhost:11434/v1) reachable      [Ollama]
Explicit overrides: KTQ_LLM_URL, KTQ_LLM_KEY, KTQ_LLM_MODEL.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field

import httpx

OPENAI_DEFAULT = "https://api.openai.com/v1"
TIMEOUT = 300  # generous: local CPU models can take a minute per tool turn


def _env_path():
    import pathlib
    return pathlib.Path(__file__).resolve().parent.parent.parent / ".env"


def _load_env_file() -> None:
    """Load KEY=VALUE lines from a project-root .env (never committed).
    Existing shell exports win; a key present in both is not overwritten."""
    import os as _os
    path = _env_path()
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and not _os.environ.get(key):
            _os.environ[key] = value


_load_env_file()


class ModelNotConfigured(Exception):
    """Raised when no LLM provider is available."""


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict = field(default_factory=dict)


@dataclass
class ChatResponse:
    content: str | None = None
    tool_calls: list[ToolCall] = field(default_factory=list)


def _ollama_model() -> str:
    if os.environ.get("KTQ_OLLAMA_MODEL"):
        return os.environ["KTQ_OLLAMA_MODEL"]
    tag = os.environ.get("KTQ_LLM_MODEL") or ""
    # an ollama-style tag (name:tag) is usable locally; cloud model names
    # (gpt-oss-20b, gemini-flash, openai, ...) are not valid Ollama tags
    if ":" in tag and "/" not in tag:
        return tag
    return "qwen2.5:7b-instruct"


def _models() -> dict:
    return {
        "openai": os.environ.get("KTQ_LLM_MODEL") or os.getenv("OPENAI_MODEL") or "gpt-4o-mini",
        "anthropic": os.environ.get("KTQ_LLM_MODEL") or os.environ.get("ANTHROPIC_MODEL")
        or "claude-3-5-sonnet-latest",
        "ollama": _ollama_model(),
    }


def _ollama_reachable(base: str) -> bool:
    try:
        r = httpx.get(base.rstrip("/") + "/v1/models", timeout=2)
        return r.status_code == 200
    except httpx.HTTPError:
        return False


PROVIDER_MODES = ("auto", "offline", "groq", "keyless")
POLLINATIONS_URL = "https://text.pollinations.ai/openai"


def provider_mode() -> str:
    mode = os.environ.get("KTQ_PROVIDER_MODE", "auto").strip().lower()
    return mode if mode in PROVIDER_MODES else "auto"


def save_env_values(updates: dict, path=None) -> None:
    """Persist keys to .env preserving comments and other entries."""
    path = path or _env_path()
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    seen, out = set(), []
    for ln in lines:
        s = ln.strip()
        key = s.split("=", 1)[0].strip() if s and not s.startswith("#") and "=" in s else ""
        if key and key in updates:
            out.append(f"{key}={updates[key]}")
            seen.add(key)
        else:
            out.append(ln)
    for key, value in updates.items():
        if key not in seen:
            out.append(f"{key}={value}")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


GROQ_URL = "https://api.groq.com/openai/v1"
GROQ_MODEL = "openai/gpt-oss-20b"


def _groq_key_present() -> bool:
    url = os.environ.get("KTQ_LLM_URL", "") or os.environ.get("OPENAI_API_BASE", "")
    if "groq" in url and (os.environ.get("KTQ_LLM_KEY") or os.getenv("OPENAI_API_KEY")):
        return True
    return False


def validate_groq_key(key: str) -> bool:
    try:
        r = httpx.get(GROQ_URL + "/models",
                      headers={"Authorization": f"Bearer {key}"}, timeout=15)
        if r.status_code == 200:
            return True
        raise ValueError(f"Groq answered HTTP {r.status_code} "
                         f"({'bad or revoked key' if r.status_code == 401 else 'see console.groq.com/keys'})")
    except httpx.HTTPError as e:
        raise ValueError(f"could not reach Groq ({e.__class__.__name__}) — not saved")
    return False


def provider_settings() -> dict:
    """UI-safe settings: the key itself is never returned."""
    chain = resolve_chain()
    return {"mode": provider_mode(),
            "has_groq_key": _groq_key_present(),
            "ocr_lang": os.environ.get("KTQ_OCR_LANG", "eng"),
            "chain": [f"{p}:{c.get('model')}" + (" (demo)" if c.get("demo") else "")
                      for p, c in chain],
            "serving": LAST_PROVIDER["name"],
            "fell_back": LAST_PROVIDER["fell_back"],
            "keyless_warning": provider_mode() == "keyless"}


def set_provider_settings(mode: str, groq_key: str | None = None,
                          ocr_lang: str | None = None) -> dict:
    mode = (mode or "").strip().lower()
    if mode not in ("offline", "groq", "keyless", "auto"):
        raise ValueError("mode must be offline, groq, keyless or auto")
    updates: dict[str, str] = {"KTQ_PROVIDER_MODE": mode}
    if ocr_lang is not None and ocr_lang.strip():
        updates["KTQ_OCR_LANG"] = "+".join(
            c for c in ocr_lang.replace(",", "+").split("+") if c.strip()) or "eng"
    if mode == "groq":
        key = (groq_key or "").strip() or os.environ.get("KTQ_LLM_KEY", "")
        if not key:
            raise ValueError("Groq mode needs an API key (console.groq.com/keys)")
        if not validate_groq_key(key):
            raise ValueError("key rejected by Groq — not saved")
        updates.update({"KTQ_LLM_URL": GROQ_URL, "KTQ_LLM_KEY": key,
                        "KTQ_LLM_MODEL": GROQ_MODEL})
    for key, value in updates.items():
        os.environ[key] = value
    save_env_values(updates)
    return provider_settings()


def _cloud_configured() -> bool:
    return bool(os.environ.get("KTQ_LLM_URL") or os.getenv("OPENAI_API_KEY")
                or os.getenv("ANTHROPIC_API_KEY"))


def resolve_chain() -> list[tuple[str, dict]]:
    """All configured providers, cloud first, local Ollama last. A 429/5xx/
    timeout on one falls through to the next; 4xx (bad key) fails fast.
    KTQ_PROVIDER_MODE: auto (everything configured) | offline (local only) |
    groq (Groq endpoint + local) | keyless (free demo cloud + local)."""
    models = _models()
    mode = provider_mode()
    chain: list[tuple[str, dict]] = []
    if mode in ("auto", "groq"):
        if os.environ.get("KTQ_LLM_URL"):
            chain.append(("openai", {"url": os.environ["KTQ_LLM_URL"],
                                     "key": os.environ.get("KTQ_LLM_KEY"),
                                     "model": models["openai"]}))
        if mode == "auto" and os.getenv("OPENAI_API_KEY"):
            key = os.environ["OPENAI_API_KEY"]
            base = os.environ.get("OPENAI_API_BASE") or os.environ.get("OPENAI_BASE_URL") or OPENAI_DEFAULT
            chain.append(("openai", {"url": base.rstrip("/"), "key": key,
                                     "model": models["openai"]}))
        if mode == "auto" and os.getenv("ANTHROPIC_API_KEY"):
            chain.append(("anthropic", {"key": os.environ["ANTHROPIC_API_KEY"],
                                        "model": models["anthropic"]}))
    if mode == "keyless":
        chain.append(("openai", {"url": POLLINATIONS_URL, "key": None,
                                 "model": os.environ.get("KTQ_POLL_MODEL", "openai"),
                                 "demo": True}))
    ollama = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
    if _ollama_reachable(ollama):
        chain.append(("ollama", {"url": ollama.rstrip("/"), "key": None,
                                 "model": models["ollama"]}))
    return chain


def resolve_provider() -> tuple[str, dict]:
    """Primary provider (first of the chain) or raise ModelNotConfigured."""
    chain = resolve_chain()
    if not chain:
        raise ModelNotConfigured(
            "No LLM provider configured. Set OPENAI_API_KEY (or ANTHROPIC_API_KEY, or start "
            "Ollama, or set KTQ_LLM_URL/KTQ_LLM_KEY). Tool execution still works and is deterministic.")
    return chain[0]


def _strip_nones(node):
    """Recursively drop None values from tool schemas. Harmless to OpenAI/
    Groq; required by stricter OpenAI-compatible backends that 400 on
    e.g. "default": null."""
    if isinstance(node, dict):
        return {k: _strip_nones(v) for k, v in node.items() if v is not None}
    if isinstance(node, list):
        return [_strip_nones(v) for v in node]
    return node


def _openai_tool_schema(tools):
    return [{"type": "function",
             "function": {"name": t["name"], "description": t.get("description", ""),
                           "parameters": _strip_nones(t.get("parameters") or
                                                      {"type": "object",
                                                       "properties": {}})}} for t in tools]


def _call_openai(cfg: dict, messages, system, tools) -> ChatResponse:
    payload = {"model": cfg["model"], "temperature": 0.1,
               "messages": ([{"role": "system", "content": system}] + messages)}
    if tools:  # some OpenAI-compatible hosts 400 on empty tools arrays
        payload["tools"] = _openai_tool_schema(tools)
        payload["tool_choice"] = "auto"
    headers = {"Content-Type": "application/json"}
    if cfg.get("key"):
        headers["Authorization"] = f"Bearer {cfg['key']}"
    with httpx.Client(timeout=TIMEOUT) as client:
        r = client.post(cfg["url"] + "/chat/completions", json=payload, headers=headers)
        r.raise_for_status()
        msg = r.json()["choices"][0]["message"]
    calls = []
    for tc in msg.get("tool_calls") or []:
        try:
            args = json.loads(tc["function"]["arguments"] or "{}")
        except json.JSONDecodeError:
            args = {}
        calls.append(ToolCall(id=tc["id"], name=tc["function"]["name"], arguments=args))
    return ChatResponse(content=msg.get("content"), tool_calls=calls)


def _call_anthropic(cfg: dict, messages, system, tools) -> ChatResponse:
    # history: assistant is preserved; OpenAI-style "tool" role -> user content block
    msgs = []
    for m in messages:
        if m["role"] == "system":
            continue
        if m["role"] == "assistant" and m.get("tool_calls"):
            blocks = [_text_block(m.get("content") or "")]
            for c in m["tool_calls"]:
                try:
                    args = json.loads(c.get("function", {}).get("arguments") or "{}")
                except json.JSONDecodeError:
                    args = {}
                blocks.append({"type": "tool_use", "id": c["id"], "name": c["function"]["name"],
                               "input": args})
            msgs.append({"role": "assistant", "content": blocks})
        elif m["role"] == "tool":
            msgs.append({"role": "user",
                         "content": [{"type": "tool_result",
                                      "tool_use_id": m["tool_call_id"],
                                      "content": m.get("content") or "{}"}]})
        else:
            msgs.append({"role": m["role"], "content": m.get("content", "")})
    payload = {"model": cfg["model"], "max_tokens": 1600, "system": system,
               "messages": msgs,
               "tools": [{"name": t["name"], "description": t.get("description", ""),
                          "input_schema": t.get("parameters") or {"type": "object",
                                                                  "properties": {}}}
                         for t in tools]}
    headers = {"x-api-key": cfg["key"], "anthropic-version": "2023-06-01",
               "Content-Type": "application/json"}
    with httpx.Client(timeout=TIMEOUT) as client:
        r = client.post("https://api.anthropic.com/v1/messages", json=payload, headers=headers)
        r.raise_for_status()
        resp = r.json()
    text, calls = None, []
    for blk in resp.get("content", []):
        if blk["type"] == "text":
            text = (text or "") + blk.get("text", "")
        elif blk["type"] == "tool_use":
            calls.append(ToolCall(id=blk["id"], name=blk["name"], arguments=blk.get("input") or {}))
    return ChatResponse(content=text, tool_calls=calls)


def _text_block(text):
    return {"type": "text", "text": text}


def _ollama_messages(messages, system):
    """Translate the agent's OpenAI-shaped history into Ollama's native format."""
    out = [{"role": "system", "content": system}]
    for m in messages:
        role = m.get("role")
        if role == "assistant" and m.get("tool_calls"):
            calls = []
            for c in m["tool_calls"]:
                fn = c.get("function", {})
                try:
                    args = json.loads(fn.get("arguments") or "{}")
                except json.JSONDecodeError:
                    args = {}
                calls.append({"function": {"name": fn.get("name"), "arguments": args}})
            out.append({"role": "assistant", "content": m.get("content") or "",
                        "tool_calls": calls})
        elif role == "tool":
            out.append({"role": "tool", "content": m.get("content") or "",
                        "tool_name": m.get("name", "")})
        else:
            out.append({"role": role or "user", "content": m.get("content") or ""})
    return out


def _call_ollama(cfg: dict, messages, system, tools) -> ChatResponse:
    model = cfg["model"]
    payload = {"model": model, "stream": False,
               "keep_alive": os.environ.get("KTQ_OLLAMA_KEEP_ALIVE", "15m"),
               "options": {"num_ctx": int(os.environ.get("KTQ_OLLAMA_NUM_CTX", "8192")),
                           "num_predict": int(os.environ.get("KTQ_OLLAMA_NUM_PREDICT", "2048")),
                           "temperature": 0},
               "messages": _ollama_messages(messages, system),
               "tools": _openai_tool_schema(tools)}
    # reasoning models otherwise spend minutes "thinking"; non-reasoning models
    # (e.g. qwen2.5) reject the field, so only send it when it applies
    if "qwen3" in model or "r1" in model or "reasoning" in model:
        payload["think"] = False
    with httpx.Client(timeout=TIMEOUT) as client:
        r = client.post(cfg["url"].rstrip("/") + "/api/chat", json=payload)
        r.raise_for_status()
        msg = r.json()["message"]
    calls = []
    for i, tc in enumerate(msg.get("tool_calls") or []):
        fn = tc.get("function", {})
        args = fn.get("arguments")
        if isinstance(args, str):
            try:
                args = json.loads(args or "{}")
            except json.JSONDecodeError:
                args = {}
        calls.append(ToolCall(id=tc.get("id") or f"call_{i}", name=fn.get("name"),
                              arguments=args or {}))
    return ChatResponse(content=msg.get("content"), tool_calls=calls)


_LOUD_STATUS = (401, 403, 404)

LAST_PROVIDER = {"name": None, "fell_back": False}


def _should_fallback(exc: BaseException) -> bool:
    """Fall back on rate limits, outages, network issues AND backend quirks
    (400/422 from strict OpenAI-compatible hosts). Only auth/forbidden and
    unknown-endpoint errors fail fast so bad keys and bad configs surface."""
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code not in _LOUD_STATUS
    return isinstance(exc, (httpx.TimeoutException, httpx.ConnectError,
                            httpx.RemoteProtocolError, httpx.ReadError,
                            httpx.WriteError, httpx.PoolTimeout))


def _dispatch(provider: str, cfg: dict, messages, system, tools) -> ChatResponse:
    if provider == "openai":
        return _call_openai(cfg, messages, system, tools)
    if provider == "ollama":
        return _call_ollama(cfg, messages, system, tools)
    return _call_anthropic(cfg, messages, system, tools)


def client_chat(system: str, messages, tools) -> ChatResponse:
    """Real-model call over the provider chain (cloud first, local last).
    Raises ModelNotConfigured if nothing is configured."""
    chain = resolve_chain()
    if not chain:
        raise ModelNotConfigured(
            "No LLM provider configured. Set OPENAI_API_KEY (or ANTHROPIC_API_KEY, or start "
            "Ollama, or set KTQ_LLM_URL/KTQ_LLM_KEY). Tool execution still works and is deterministic.")
    last_err: BaseException | None = None
    for i, (provider, cfg) in enumerate(chain):
        try:
            resp = _dispatch(provider, cfg, messages, system, tools)
            LAST_PROVIDER["name"] = f"{provider}:{cfg.get('model')}"
            LAST_PROVIDER["fell_back"] = i > 0
            return resp
        except Exception as e:  # noqa: BLE001 — provider errors route below
            if i == len(chain) - 1 or not _should_fallback(e):
                raise
            last_err = e
    raise last_err  # pragma: no cover — loop always returns or raises

# ------------------------------------------------------- local model manager
import re as _re
import threading as _threading

_MODEL_NAME_RE = _re.compile(r"^[A-Za-z0-9._\-/:]{1,80}$")
_PULL_STATE: dict = {"running": False, "model": None, "done": False,
                     "error": None, "log": []}
_PULL_LOCK = _threading.Lock()


def ollama_base() -> str:
    return os.environ.get("OLLAMA_HOST", "http://localhost:11434").rstrip("/")


def required_local_model() -> str:
    return _ollama_model()


def ollama_inventory() -> dict:
    """Installed Ollama models + whether the required local model is present."""
    models: list[dict] = []
    try:
        r = httpx.get(ollama_base() + "/api/tags", timeout=10)
        if r.status_code == 200:
            for m in r.json().get("models", []):
                models.append({"name": m.get("name"),
                               "size_gb": round((m.get("size") or 0) / 1e9, 2),
                               "modified": (m.get("modified_at") or "")[:10]})
    except httpx.HTTPError:
        return {"reachable": False, "models": [], "required": required_local_model(),
                "installed": False, "models_dir": _ollama_models_dir()}
    required = required_local_model()
    base = required.split(":")[0]
    installed = any(m["name"] == required or m["name"].startswith(base + ":")
                    for m in models)
    return {"reachable": True, "models": models, "required": required,
            "installed": installed, "models_dir": _ollama_models_dir()}


def _ollama_models_dir() -> str:
    """Where this machine's Ollama daemon keeps model blobs."""
    custom = os.environ.get("OLLAMA_MODELS")
    if custom:
        return custom
    home = os.path.expanduser("~/.ollama/models")
    if os.path.isdir(home):
        return home
    return "managed by the Ollama daemon (OLLAMA_MODELS not set locally)"


def _valid_model_name(name: str) -> bool:
    return bool(name) and bool(_MODEL_NAME_RE.fullmatch(name)) \
        and ".." not in name and name[0] not in "./"


def start_model_pull(model: str | None = None) -> dict:
    """Start `ollama pull` in the background (takes minutes for GB models).
    Returns the shared pull state; poll pull_status() for progress."""
    model = (model or required_local_model()).strip()
    if not _valid_model_name(model):
        raise ValueError(f"bad model name {model!r}")
    with _PULL_LOCK:
        if _PULL_STATE["running"]:
            return dict(_PULL_STATE)
        _PULL_STATE.update(running=True, model=model, done=False,
                           error=None, log=[f"pulling {model} …"])
    _threading.Thread(target=_pull_worker, args=(model,), daemon=True).start()
    return dict(_PULL_STATE)


def _pull_worker(model: str):
    import json as _json
    try:
        with httpx.stream("POST", ollama_base() + "/api/pull",
                          json={"name": model}, timeout=None) as r:
            r.raise_for_status()
            for line in r.iter_lines():
                if not line:
                    continue
                try:
                    ev = _json.loads(line)
                except ValueError:
                    continue
                msg = ev.get("status", "")
                if ev.get("digest"):
                    total = ev.get("total") or 0
                    done_b = ev.get("completed") or 0
                    pct = f" {done_b * 100 // total}%" if total else ""
                    msg = f"{msg} {ev['digest'][:12]}{pct}".strip()
                with _PULL_LOCK:
                    _PULL_STATE["log"].append(msg)
                    _PULL_STATE["log"] = _PULL_STATE["log"][-15:]
        with _PULL_LOCK:
            _PULL_STATE.update(running=False, done=True)
    except Exception as e:  # noqa: BLE001 — surfaced via status, never raised
        with _PULL_LOCK:
            _PULL_STATE.update(running=False, done=True,
                               error=f"{type(e).__name__}: {e}")


def pull_status() -> dict:
    with _PULL_LOCK:
        return dict(_PULL_STATE, log=list(_PULL_STATE["log"]))

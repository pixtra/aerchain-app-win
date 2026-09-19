#!/usr/bin/env bash
# Aerchain Kill-the-Quote — one-time setup. Idempotent: safe to re-run.
# Installs: python venv + deps, Tesseract (OCR), Ollama + local model,
# .env defaults, and builds the database.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODEL="${KTQ_OLLAMA_MODEL:-qwen2.5:7b-instruct}"
OLLAMA_BIN="${OLLAMA_BIN:-$HOME/.local/bin/ollama}"

ok()   { printf '  \e[32m[ok]\e[0m %s\n' "$*"; }
step() { printf '\e[1m%s\e[0m\n' "$*"; }
warn() { printf '  \e[33m[warn]\e[0m %s\n' "$*"; }

# --- 1. python ---------------------------------------------------------------
step "1/6  Python"
if ! command -v python3 >/dev/null; then
  echo "ERROR: python3 not found. Install Python 3.10+ and re-run."; exit 1
fi
PYV="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [ "$(printf '%s\n3.10\n' "$PYV" | sort -V | head -1)" != "3.10" ]; then
  echo "ERROR: python $PYV too old (need 3.10+)."; exit 1
fi
ok "python $PYV"

# --- 2. venv + deps ----------------------------------------------------------
step "2/6  Python environment"
if [ ! -x "$ROOT/.venv/bin/python" ]; then
  python3 -m venv "$ROOT/.venv"
fi
"$ROOT/.venv/bin/pip" install -q -r "$ROOT/requirements.txt"
ok "dependencies installed"

# --- 3. tesseract (real OCR) -------------------------------------------------
step "3/6  OCR engine (Tesseract)"
if command -v tesseract >/dev/null; then
  ok "$(tesseract --version 2>/dev/null | head -1)"
elif sudo -n true 2>/dev/null && command -v apt-get >/dev/null; then
  sudo -n apt-get install -y -q tesseract-ocr >/dev/null 2>&1 \
    && ok "tesseract installed" \
    || warn "apt install failed — image OCR will use degraded mode."
else
  warn "tesseract not found and no passwordless sudo."
  warn "  For real image OCR run:  sudo apt install tesseract-ocr"
  warn "  Continuing — everything else works."
fi

# --- 4. ollama (local model server, no root) ---------------------------------
step "4/6  Local model server"
if [ ! -x "$OLLAMA_BIN" ]; then
  mkdir -p "$HOME/.local/bin" "$(dirname "$OLLAMA_BIN")"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  curl -sL "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tar.zst" \
    -o "$TMP/ollama.tar.zst"
  tar --zstd -xf "$TMP/ollama.tar.zst" -C "$HOME/.local" 2>/dev/null \
    || { mkdir -p "$TMP/ox" && tar -xf "$TMP/ollama.tar.zst" -C "$TMP/ox" && cp "$TMP/ox/bin/ollama" "$HOME/.local/bin/"; }
  rm -rf "$TMP"; trap - EXIT
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
    warn "add to your shell once:  export PATH=\"\$HOME/.local/bin:\$PATH\"";; esac
fi
export PATH="$HOME/.local/bin:$PATH"
ok "$("$OLLAMA_BIN" --version 2>/dev/null || echo ollama)"

# --- 5. model (one ~4.7 GB download, cached afterwards) -----------------------
step "5/6  Model ($MODEL)"
if ! pgrep -x ollama >/dev/null 2>&1; then
  (setsid "$OLLAMA_BIN" serve >/tmp/ollama-serve.log 2>&1 </dev/null &)
  sleep 3
fi
if "$OLLAMA_BIN" list 2>/dev/null | grep -q "${MODEL%%:*}"; then
  ok "$MODEL already downloaded"
else
  echo "  downloading $MODEL (~4.7 GB, one time)…"
  "$OLLAMA_BIN" pull "$MODEL"
  ok "$MODEL ready"
fi

# --- 6. config + database ----------------------------------------------------
step "6/6  Config + database"
[ -f "$ROOT/.env" ] || { cp "$ROOT/.env.example" "$ROOT/.env"; echo "  created .env (edit to add a cloud key, optional)"; }

# --- 6b. optional Groq cloud key (faster + stronger NL; offline otherwise) ----
if ! grep -q "^KTQ_LLM_URL=" "$ROOT/.env" 2>/dev/null; then
  KEY="${GROQ_API_KEY:-}"
  if [ -z "$KEY" ] && [ -t 0 ]; then
    printf '  Groq API key for cloud speed (Enter to skip, stays offline): '
    IFS= read -rs KEY || true
    echo ""
  fi
  if [ -z "$KEY" ] && [ -t 0 ]; then
    printf '  No key pasted. Open the Groq key page to create one (30s)? [y/N] '
    IFS= read -r OPENKEY || true
    if [[ "$OPENKEY" =~ ^[Yy]$ ]]; then
      command -v xdg-open >/dev/null \
        && (xdg-open "https://console.groq.com/keys" >/dev/null 2>&1 &) || true
      echo "  Log in → Create API Key → paste it here:"
      printf '  Groq API key: '
      IFS= read -rs KEY || true
      echo ""
    fi
  fi
  if [ -n "$KEY" ]; then
    CODE="$(curl -s -m 15 -o /dev/null -w "%{http_code}" \
      https://api.groq.com/openai/v1/models -H "Authorization: Bearer $KEY" || echo 000)"
    if [ "$CODE" != "200" ]; then
      warn "key rejected by Groq (HTTP $CODE) — not saved. Continuing offline;"
      warn "  re-run ./setup.sh once you have a working key."
      KEY=""
    fi
  fi
  if [ -n "$KEY" ]; then
    # KTQ_LLM_MODEL names the cloud model now; drop the local-model line so
    # the file has exactly one (first occurrence wins at load).
    grep -v "^KTQ_LLM_MODEL=" "$ROOT/.env" > "$ROOT/.env.tmp" \
      && mv "$ROOT/.env.tmp" "$ROOT/.env"
    {
      echo "KTQ_LLM_URL=https://api.groq.com/openai/v1"
      echo "KTQ_LLM_KEY=$KEY"
      echo "KTQ_LLM_MODEL=openai/gpt-oss-20b"
    } >> "$ROOT/.env"
    ok "Groq configured (cloud first, local fallback automatic)"
  else
    echo "  no cloud key — fully offline mode (local model)"
  fi
else
  ok "cloud endpoint already configured"
fi
if [ ! -f "$ROOT/data/aerchain.db" ]; then
  (cd "$ROOT" && .venv/bin/python -m app.pipeline | tail -4)
else
  ok "database present (re-seed anytime from the dashboard)"
fi

echo ""
echo -e "\e[1;32mSetup complete.\e[0m  Start the app with:  ./run.sh"

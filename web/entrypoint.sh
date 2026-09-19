#!/usr/bin/env bash
# Container boot: config -> (optional) local model -> database -> app.
set -euo pipefail

PORT="${PORT:-8000}"
MODEL="${KTQ_OLLAMA_MODEL:-qwen2.5:7b-instruct}"
MODE="${KTQ_PROVIDER_MODE:-offline}"

[ -f /app/.env ] || cp /app/.env.example /app/.env
if [ -n "${GROQ_API_KEY:-}" ] && ! grep -q "^KTQ_LLM_URL=" /app/.env; then
  {
    echo "KTQ_PROVIDER_MODE=groq"
    echo "KTQ_LLM_URL=https://api.groq.com/openai/v1"
    echo "KTQ_LLM_KEY=$GROQ_API_KEY"
    echo "KTQ_LLM_MODEL=${KTQ_LLM_MODEL:-openai/gpt-oss-20b}"
  } >> /app/.env
  MODE="groq"
fi

if [ "$MODE" = "offline" ] || [ "$MODE" = "auto" ]; then
  (ollama serve >/tmp/ollama.log 2>&1 &) || true
  for _ in $(seq 1 20); do
    curl -s -m 2 http://127.0.0.1:11434/v1/models >/dev/null 2>&1 && break
    sleep 1
  done
  if ! ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
    echo "pulling $MODEL (one time, needs disk + RAM)…"
    ollama pull "$MODEL"
  fi
else
  echo "cloud mode ($MODE): skipping local model"
fi

if [ ! -f /app/data/aerchain.db ]; then
  echo "building database…"
  python -m app.pipeline | tail -3
fi

exec python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT" --log-level warning

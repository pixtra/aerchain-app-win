#!/usr/bin/env bash
# Aerchain Kill-the-Quote — daily start. Usage: ./run.sh [PORT]
# Starts Ollama (if needed) + the app, opens the dashboard.
# Ctrl-C stops the app server. Never uses pkill.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-${PORT:-8000}}"
MODEL="${KTQ_OLLAMA_MODEL:-qwen2.5:7b-instruct}"
OLLAMA_BIN="${OLLAMA_BIN:-$HOME/.local/bin/ollama}"
RUNDIR="$ROOT/.run"
PIDFILE="$RUNDIR/uvicorn-$PORT.pid"
export PATH="$HOME/.local/bin:$PATH"

die() { echo "ERROR: $*"; exit 1; }
[ -x "$ROOT/.venv/bin/python" ] || die "not set up yet — run ./setup.sh first"

health() { curl -s -m 2 "http://127.0.0.1:$PORT/api/health" 2>/dev/null | grep -q ok; }

# already running? just point at it
if health; then
  echo "Already running → http://localhost:$PORT/"
  exit 0
fi
if ss -ltn 2>/dev/null | grep -q ":$PORT "; then
  die "port $PORT is taken by something else — try:  ./run.sh 8001"
fi

# stale pidfile from a crash?
if [ -f "$PIDFILE" ] && ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  rm -f "$PIDFILE"
fi

# config + database
[ -f "$ROOT/.env" ] || cp "$ROOT/.env.example" "$ROOT/.env"
[ -f "$ROOT/data/aerchain.db" ] || { echo "Building database (first run)…"; (cd "$ROOT" && .venv/bin/python -m app.pipeline | tail -2); }

# model server
if ! curl -s -m 2 http://localhost:11434/v1/models >/dev/null 2>&1; then
  [ -x "$OLLAMA_BIN" ] || die "ollama missing — run ./setup.sh first"
  echo "Starting local model server…"
  mkdir -p "$RUNDIR"
  (setsid "$OLLAMA_BIN" serve >"$RUNDIR/ollama.log" 2>&1 </dev/null &)
  for _ in $(seq 1 15); do
    curl -s -m 2 http://localhost:11434/v1/models >/dev/null 2>&1 && break
    sleep 1
  done
fi
if ! "$OLLAMA_BIN" list 2>/dev/null | grep -q "${MODEL%%:*}"; then
  echo "Downloading model $MODEL (~4.7 GB, one time)…"
  "$OLLAMA_BIN" pull "$MODEL"
fi

# app server (direct child: $! is the real PID for trap/wait/pidfile)
mkdir -p "$RUNDIR"
echo $$ > "$RUNDIR/run-$PORT.pid"
echo "Starting Aerchain on port $PORT…"
cd "$ROOT"
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port "$PORT" \
  --log-level warning >"$RUNDIR/app-$PORT.log" 2>&1 &
SRV=$!
echo "$SRV" > "$PIDFILE"
cleanup() { kill "$SRV" 2>/dev/null; rm -f "$PIDFILE" "$RUNDIR/run-$PORT.pid"; echo; echo "Stopped."; }
trap cleanup INT TERM

for _ in $(seq 1 20); do health && break; sleep 1; done
health || { echo "Server failed to start — see $RUNDIR/app-$PORT.log"; rm -f "$PIDFILE"; exit 1; }

URL="http://localhost:$PORT/"
LANIP="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo ""
echo -e "\e[1;32mAerchain is live → $URL\e[0m  (Ctrl-C to stop)"
if [ -n "$LANIP" ]; then
  echo -e "Same-network devices → \e[1mhttp://$LANIP:$PORT/\e[0m  (no login — trusted networks only)"
fi
echo "Share beyond your network (deliberate act, no login): ./share.sh $PORT"
command -v xdg-open >/dev/null && (xdg-open "$URL" >/dev/null 2>&1 &) || true
wait "$SRV"

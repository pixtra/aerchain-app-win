#!/usr/bin/env bash
# Double-clickable launcher (also: ./desktop.sh). First run sets up venv.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
[ -x "$ROOT/.venv/bin/python" ] || {
  echo "First run: creating environment…"
  python3 -m venv "$ROOT/.venv"
  "$ROOT/.venv/bin/pip" install -q -r "$ROOT/requirements.txt"
}
exec "$ROOT/.venv/bin/python" "$ROOT/desktop.py" "$@"

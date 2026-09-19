# Aerchain app — one project, three ways to run

| Mode | Where | How |
|---|---|---|
| Local web | `web/` | `cd web && ./run.sh` → http://localhost:8000/ |
| Global link | `web/` | `./run.sh` first, then `./share.sh` (Ctrl-C closes) |
| Desktop | `desktop/` | `cd desktop && ./desktop.sh` (native window, no browser) |

`web/` and `desktop/` are independent copies: separate databases, uploads,
drafts and conditions. They share only Ollama (one model server) and system
Tesseract. Each copy builds its own `.venv` via its `setup.sh`.

# Aerchain on Windows

Same app as the Linux `aerchain_app`. Use the `.bat` files (ignore the `.sh`
files — they're for Linux/macOS).

## Prerequisites (install once, in this order)
1. **Python 3.10+** — https://www.python.org/downloads/ — tick
   **"Add python.exe to PATH"** during install (setup.bat stops without it).
2. **Ollama** — https://ollama.com/download/OllamaSetup.exe — for offline mode.
   Or skip this and use a free Groq key (Settings tab) instead.
3. **Tesseract OCR** (only for photo/scan uploads) —
   https://github.com/UB-Mannheim/tesseract/wiki — install to the default
   `C:\Program Files\Tesseract-OCR\`; `setup.bat` detects it automatically and
   stores the path. Without it, image uploads use degraded mode; everything
   else works.
4. WebView2 (for the desktop window) — preinstalled on Windows 10 1803+ and
   all Windows 11. Nothing to do.

## Run
```bat
cd web
setup.bat      :: once: venv, packages, model (~4.7 GB), database
run.bat        :: daily: http://localhost:8000/  (run.bat 8001 for a 2nd copy)
share.bat      :: public link for someone far away (needs run.bat going)
cd ..\desktop
desktop.bat    :: native window, no browser (build-exe.bat makes AerchainDesktop.exe)
```

## Windows-specific notes
- Models live in `%USERPROFILE%\.ollama\models` (shown in Settings → Local model).
- Scanned PDFs render via PyMuPDF (installed automatically) — no poppler needed.
- `curl`/`tar` used by scripts ship with Windows 10+; no extra tools required.
- PowerShell execution policy is irrelevant — everything is `.bat` + Python.
- Firewall: Windows may prompt on first run — Allow, otherwise LAN devices
  can't connect. Same no-login warning as Linux: trusted networks only.
- Line endings, paths, and temp dirs are handled in code; `setup.bat` writes
  `TESSERACT_CMD` into `.env` when it finds the standard install path.

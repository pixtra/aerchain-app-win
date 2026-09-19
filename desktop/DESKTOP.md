# Aerchain desktop app for Windows (pywebview + WebView2)

Native window, no browser needed. WebView2 ships with Windows 10/11, so
unlike Linux there is nothing extra to install for the window itself.

## Run from source
```bat
desktop.bat
```
First run creates `.venv` and installs everything. Close the window to stop.
Needs: Python 3.10+ (tick "Add to PATH"), Tesseract (UB-Mannheim installer,
auto-detected), and Ollama + model *or* a Groq key (Settings tab).

## Ship as AerchainDesktop.exe
```bat
build-exe.bat
```
Produces `dist\AerchainDesktop\` — hand over that **whole folder**
(single `AerchainDesktop.exe` inside plus its support files). First launch
builds its database next to the exe. Console window stays visible on purpose:
if anything fails, the error is right there instead of a silent exit.

Still external (by design, not bundled):
- **Ollama + model** (~5 GB) — or use Groq cloud, no install at all.
- **Tesseract** — for photo/scan uploads only; everything else works without it.
- **`.env`** — created next to the exe on first run (Groq key lives there).

## Notes
- Backend serves on 127.0.0.1, random free port — LAN/tunnel sharing does not
  apply here; use `run.bat` + `share.bat` from the web layout for that.
- Own database, fully separate from any other copy.
- Set `DESKTOP_TEST=1` in the environment before launching for an
  open-and-auto-close smoke test.

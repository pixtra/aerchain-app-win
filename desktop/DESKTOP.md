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

## Ship as a single AerchainDesktop.exe
```bat
build-exe.bat
```
Produces `dist\AerchainDesktop.exe` — **one file, hand it over**. First launch
creates `%APPDATA%\AerchainDesktop` (database + settings) and defaults to
keyless demo cloud, so it works immediately with zero installs.

## Ship as Setup-AerChain-V0-Demo.exe (client installer)
1. Build the exe above, then open `installer.iss` in **Inno Setup 6**
   (jrsoftware.org/isinfo.php, free) and press Ctrl+F9.
2. Hand over `installer-out\Setup-AerChain-V0-Demo.exe`. It installs a Start
   Menu / desktop app literally called **AerChain V0 (Demo)**, per-user (no
   admin), with an uninstaller included. First launch behaves exactly like
   the raw exe above.

Still external (by design, never inside the exe):
- **Ollama + model** (~5 GB) — only for offline mode; switch in Settings.
- **Tesseract** — only for photo/scan uploads (degraded mode otherwise).
  Optionally drop a portable build in `tess\` before running `build-exe.bat`
  and it gets bundled (`tess\tesseract.exe` + tessdata).
- **Groq key** — typed into Settings on first run if you want cloud speed.

## Notes
- Backend serves on 127.0.0.1, random free port — LAN/tunnel sharing does not
  apply here; use `run.bat` + `share.bat` from the web layout for that.
- Own database, fully separate from any other copy.
- Set `DESKTOP_TEST=1` in the environment before launching for an
  open-and-auto-close smoke test.

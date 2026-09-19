@echo off
REM Aerchain desktop app - native window, no browser needed.
REM First run creates the environment (needs internet once).
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo First run: creating environment...
  python -m venv .venv
  .venv\Scripts\python -m pip install -q -r requirements.txt
  if errorlevel 1 (
    echo ERROR: dependency install failed - check the messages above.
    exit /b 1
  )
)
.venv\Scripts\python desktop.py

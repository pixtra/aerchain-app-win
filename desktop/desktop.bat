@echo off
call :main %*
set EC=%ERRORLEVEL%
if not "%EC%"=="0" if not "%EC%"=="130" (
  echo.
  echo Stopped with an error. Press any key to close...
  pause >nul
)
exit /b %EC%

:main
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
.venv\Scripts\python -c "import uvicorn, fastapi, webview" 2>nul
if errorlevel 1 (
  echo ERROR: packages incomplete - delete the .venv folder and re-run desktop.bat.
  exit /b 1
)
.venv\Scripts\python desktop.py
exit /b 0

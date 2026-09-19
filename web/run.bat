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
REM Aerchain Kill-the-Quote - daily start. Usage: run.bat [PORT] [--headless]
REM Interactive: browser opens, Ctrl-C stops. Headless: pythonw, no console,
REM no browser (stop it with stop.bat [PORT]).
setlocal
cd /d "%~dp0"
set HEADLESS=
if "%~1"=="--headless" set HEADLESS=1
if "%~2"=="--headless" set HEADLESS=1
if "%~1"=="" (set PORT=8000) else if not "%~1"=="--headless" (set PORT=%~1)
if not defined PORT set PORT=8000

if not exist ".venv\Scripts\python.exe" (
  echo ERROR: not set up yet - run setup.bat first.
  exit /b 1
)
if not exist ".env" copy /y .env.example .env >nul
if not exist "data\aerchain.db" (
  echo Building database, first run...
  .venv\Scripts\python -m app.pipeline
  if errorlevel 1 (
    echo ERROR: database build failed - check the messages above.
    exit /b 1
  )
)

REM already running?
curl -s -m 2 http://127.0.0.1:%PORT%/api/health 2>nul | findstr "ok" >nul
if not errorlevel 1 (
  echo Already running -^> http://localhost:%PORT%/
  exit /b 0
)

REM model server
curl -s -m 2 http://localhost:11434/v1/models >nul 2>nul
if errorlevel 1 (
  where ollama >nul 2>nul
  if errorlevel 1 (
    echo ERROR: Ollama not running and not installed - run setup.bat first,
    echo or switch to Groq cloud in Settings once the app is up.
    exit /b 1
  )
  echo Starting local model server...
  start "Ollama" /min ollama serve
  timeout /t 5 /nobreak >nul
)
ollama list >nul 2>nul
if not errorlevel 1 (
  ollama list 2>nul | findstr /c:"qwen2.5" >nul
  if errorlevel 1 (
    echo NOTE: local model not downloaded yet - chat answers will say LLM offline
    echo until you install it: open Settings - Local model - Install.
    echo Or switch to Groq cloud in Settings - no download at all.
  )
)

echo Starting Aerchain on port %PORT%...
if defined HEADLESS goto :headless
start "" /min powershell -c "Start-Sleep -Seconds 8; Start-Process 'http://localhost:%PORT%/'"
.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port %PORT% --log-level warning
exit /b 0

:headless
if not exist .run mkdir .run
start "" /min cmd /c ".venv\Scripts\pythonw.exe -m uvicorn app.main:app --host 0.0.0.0 --port %PORT% --log-level warning > .run\app-%PORT%.log 2>&1"
echo Running headless on http://localhost:%PORT%/ - stop it with: stop.bat %PORT%
exit /b 0

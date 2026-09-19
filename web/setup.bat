@echo off
REM Aerchain Kill-the-Quote - one-time Windows setup. Safe to re-run.
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo [1/6] Python
where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: install Python 3.10+ from https://www.python.org/downloads/ ^(tick "Add python.exe to PATH"^) and re-run.
  exit /b 1
)
for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PYV=%%v
python -c "import sys; exit(0 if sys.version_info>=(3,10) else 1)"
if errorlevel 1 (
  echo ERROR: Python %PYV% too old - need 3.10+. Install fresh from https://www.python.org/downloads/
  exit /b 1
)
echo   [ok] Python %PYV%

echo [2/6] Python environment
if not exist ".venv\Scripts\python.exe" python -m venv .venv
.venv\Scripts\python -m pip install -q -r requirements.txt
if errorlevel 1 (
  echo ERROR: dependency install failed - check the messages above.
  exit /b 1
)
echo   [ok] dependencies installed

echo [3/6] OCR engine (Tesseract)
set TESS=
where tesseract >nul 2>nul && set TESS=tesseract
if not defined TESS if exist "C:\Program Files\Tesseract-OCR\tesseract.exe" set "TESS=C:\Program Files\Tesseract-OCR\tesseract.exe"
if defined TESS (
  echo   [ok] Tesseract found
) else (
  echo   [warn] Tesseract not found - image OCR will use degraded mode.
  echo   Install from https://github.com/UB-Mannheim/tesseract/wiki then re-run setup.bat
)

echo [4/6] Local model server (Ollama)
where ollama >nul 2>nul
if errorlevel 1 (
  echo   [warn] Ollama not found - install OllamaSetup.exe from https://ollama.com/download
  echo   then re-run setup.bat (or use Groq cloud in Settings instead^).
) else (
  echo   [ok] Ollama found
)

echo [5/6] Model (qwen2.5:7b-instruct, ~4.7 GB one-time download)
where ollama >nul 2>nul
if errorlevel 1 (
  echo   [skip] no Ollama yet - skipping download.
) else (
  ollama list 2>nul | findstr /c:"qwen2.5" >nul
  if errorlevel 1 (
    echo   Downloading model (~4.7 GB, one time)...
    ollama pull qwen2.5:7b-instruct
  ) else (
    echo   [ok] model already downloaded
  )
)

echo [6/6] Config + database
if not exist ".env" (
  copy /y .env.example .env >nul
  echo   created .env
)
if defined TESS (
  findstr /b /c:"TESSERACT_CMD=" .env >nul 2>nul
  if errorlevel 1 (
    if not "!TESS!"=="tesseract" echo TESSERACT_CMD=!TESS!>> .env
  )
)
if not exist "data\aerchain.db" (
  .venv\Scripts\python -m app.pipeline
) else (
  echo   [ok] database present
)

echo.
echo Setup complete. Start the app with:  run.bat

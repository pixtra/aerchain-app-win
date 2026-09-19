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
REM Aerchain Kill-the-Quote - one-time Windows setup. Safe to re-run.
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo [1/6] Python
call :find_python
if defined PYOK goto :pyready
echo   Usable Python 3.10+ not found - trying to install it automatically...
where winget >nul 2>nul
if errorlevel 1 goto :pymanual
winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements --silent
for /d %%d in ("%LOCALAPPDATA%\Programs\Python\*") do (
  if exist "%%d\python.exe" set "PATH=%%d;%%d\Scripts;%PATH%"
  for /d %%e in ("%%d\*") do if exist "%%e\python.exe" set "PATH=%%e;%%e\Scripts;%PATH%"
)
call :find_python
if defined PYOK (
  echo   [ok] Python installed automatically
  goto :pyready
)
echo ERROR: automatic Python install failed. Install from https://www.python.org/downloads/ - tick "Add python.exe to PATH" - and re-run.
exit /b 1
:pymanual
echo ERROR: install Python 3.10+ from https://www.python.org/downloads/ - tick "Add python.exe to PATH" - and re-run.
exit /b 1
:pyready
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
  echo   [ok] Tesseract ready
) else (
  echo   Tesseract not found - trying to install it automatically...
  where winget >nul 2>nul
  if errorlevel 1 (
    echo   [warn] no winget and no Tesseract - image OCR will use degraded mode.
    echo   Install Tesseract from https://github.com/UB-Mannheim/tesseract/wiki then re-run setup.bat
  ) else (
    winget install -e --id UB-Mannheim.TesseractOCR --accept-source-agreements --accept-package-agreements --silent
    if exist "C:\Program Files\Tesseract-OCR\tesseract.exe" (
      set "TESS=C:\Program Files\Tesseract-OCR\tesseract.exe"
      echo   [ok] Tesseract installed automatically
    ) else (
      echo   [warn] automatic install did not finish - install Tesseract from https://github.com/UB-Mannheim/tesseract/wiki
      echo   then re-run setup.bat. Everything else works without it.
    )
  )
)

echo [4/6] Local model server (Ollama)
where ollama >nul 2>nul
if errorlevel 1 (
  echo   Ollama not found - trying to install it automatically...
  curl -sL -o "%TEMP%\OllamaSetup.exe" https://ollama.com/download/OllamaSetup.exe
  if errorlevel 1 (
    echo   [warn] download failed - install OllamaSetup.exe from https://ollama.com/download
    echo   then re-run setup.bat, or use Groq cloud in Settings instead.
  ) else (
    start "" /wait "%TEMP%\OllamaSetup.exe" /SILENT
    set "PATH=%LOCALAPPDATA%\Programs\Ollama;%PATH%"
    where ollama >nul 2>nul
    if errorlevel 1 (
      echo   [warn] automatic install didn't finish - run OllamaSetup.exe from https://ollama.com/download
      echo   then re-run setup.bat, or use Groq cloud in Settings instead.
    ) else (
      echo   [ok] Ollama installed automatically
    )
  )
) else (
  echo   [ok] Ollama found
)

echo [5/6] Model (qwen2.5:7b-instruct - installed later from Settings)
echo   [skip] models install in-demo: Settings - Local model - Install.
echo   Or switch to Groq cloud - no download at all.

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
exit /b 0

:find_python
set PYOK=
set PYV=
python --version >nul 2>nul
if errorlevel 1 exit /b 1
for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PYV=%%v
python -c "import sys; exit(0 if sys.version_info>=(3,10) else 1)" >nul 2>nul
if errorlevel 1 exit /b 1
set PYOK=1
exit /b 0

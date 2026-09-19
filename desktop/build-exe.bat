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
REM Build a single AerchainDesktop.exe (plus one auto-created data folder).
REM Run once on the Windows machine. Needs internet (pip + PyInstaller).
REM Optional: drop a portable Tesseract build in tess\ first and it gets
REM bundled too (tess\tesseract.exe + tessdata). Ollama + model stay external
REM (or use Groq/keyless cloud - the exe defaults to keyless demo mode).
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Run desktop.bat once first, it creates the environment.
  exit /b 1
)
.venv\Scripts\python -m pip install -q pyinstaller
if errorlevel 1 (
  echo ERROR: could not install PyInstaller.
  exit /b 1
)
set TESSDATA=
if exist "tess\tesseract.exe" (
  echo Bundling portable Tesseract...
  set TESSDATA=--add-data "tess;tess"
)
.venv\Scripts\python -m PyInstaller --noconfirm --clean --onefile --console --name AerchainDesktop --add-data "static;static" %TESSDATA% --collect-submodules app desktop.py
if errorlevel 1 (
  echo ERROR: build failed - see messages above.
  exit /b 1
)
echo.
echo Built: dist\AerchainDesktop.exe (~150-250 MB - single file, hand it over).
echo First launch creates %%APPDATA%%\AerchainDesktop (database + settings).
exit /b 0

@echo off
REM Build AerchainDesktop.exe (one folder, double-clickable).
REM Run once on the Windows machine. Needs internet (pip + PyInstaller).
REM Ollama, Tesseract and the model stay EXTERNAL (see DESKTOP.md).
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Run desktop.bat once first (creates the environment).
  exit /b 1
)
.venv\Scripts\python -m pip install -q pyinstaller
if errorlevel 1 (
  echo ERROR: could not install PyInstaller.
  exit /b 1
)
.venv\Scripts\python -m PyInstaller --noconfirm --clean --onedir --console --name AerchainDesktop --add-data "static;static" --collect-submodules app desktop.py
if errorlevel 1 (
  echo ERROR: build failed - see messages above.
  exit /b 1
)
echo.
echo Built: dist\AerchainDesktop\AerchainDesktop.exe
echo Ship the whole dist\AerchainDesktop folder. First launch builds its database next to the exe.

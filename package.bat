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
REM Pack the whole Windows tree for another computer: code + scripts + docs,
REM no secrets, no junk. Recipient extracts and runs web\setup.bat.
REM Usage: package.bat [output-dir]   (default: Desktop)
setlocal
cd /d "%~dp0"
if "%~1"=="" (set OUT=%USERPROFILE%\Desktop) else (set OUT=%~1)
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd" 2^>nul') do set VER=%%a
if not defined VER set VER=nodate
set TARBALL=%OUT%\aerchain-app-win-%VER%.tar.gz
where tar >nul 2>nul
if errorlevel 1 (
  echo ERROR: tar.exe not found, needs Windows 10 1803+.
  exit /b 1
)
tar -czf "%TARBALL%" --exclude=.venv --exclude=__pycache__ --exclude=.pytest_cache --exclude=.git --exclude=.run --exclude=*.db --exclude=uploads --exclude=*.log --exclude=dist --exclude=build --exclude=.env web desktop README.md WINDOWS.md .gitignore
if errorlevel 1 (
  echo ERROR: packing failed.
  exit /b 1
)
echo Packed: %TARBALL%
echo Recipient needs: Python 3.10+ (~8GB disk, internet), Tesseract/Ollama optional
echo Recipient runs:  extract, then web\setup.bat, then web\run.bat
exit /b 0

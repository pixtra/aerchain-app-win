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
REM Share Aerchain publicly via Cloudflare (app must run via run.bat first).
REM Usage: share.bat [PORT]   Ctrl-C closes the link.
setlocal
cd /d "%~dp0"
if "%~1"=="" (set PORT=8000) else (set PORT=%~1)
if not exist bin mkdir bin
if not exist "bin\cloudflared.exe" (
  echo Fetching cloudflared (one time)...
  curl -sL -o bin\cloudflared.exe https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
  if errorlevel 1 (
    echo ERROR: download failed - check internet and retry.
    exit /b 1
  )
)

curl -s -m 3 http://127.0.0.1:%PORT%/api/health 2>nul | findstr "ok" >nul
if errorlevel 1 (
  echo ERROR: app isn't running on :%PORT% - start it first: run.bat %PORT%
  exit /b 1
)

if not exist .run mkdir .run
echo Opening public link for http://localhost:%PORT% ... (Ctrl-C to close)
start "Aerchain tunnel" /min bin\cloudflared.exe tunnel --no-autoupdate --url http://localhost:%PORT% --logfile .run\share-%PORT%.log
echo Waiting for link (up to 60s)...
for /l %%i in (1,1,60) do (
  findstr /r /c:"https://.*trycloudflare\.com" ".run\share-%PORT%.log" >nul 2>nul
  if not errorlevel 1 goto :found
  timeout /t 1 /nobreak >nul
)
echo Tunnel didn't come up - see .run\share-%PORT%.log
exit /b 1
:found
echo.
echo Share this link:
findstr /r /c:"https://.*trycloudflare\.com" ".run\share-%PORT%.log"
echo.
echo Warning: no login - anyone with the link has full access.
echo To take the link down, close the separate "Aerchain tunnel" window.
exit /b 0

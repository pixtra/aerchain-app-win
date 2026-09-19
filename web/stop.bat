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
REM Stop a headless (or any) Aerchain server by port. Usage: stop.bat [PORT]
setlocal
cd /d "%~dp0"
if "%~1"=="" (set PORT=8000) else (set PORT=%~1)
set FOUND=
for /f "tokens=5" %%p in ('netstat -ano ^| findstr "TCP" ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
  set FOUND=1
  taskkill /PID %%p /F >nul
)
if not defined FOUND (
  echo Nothing listening on :%PORT%.
  exit /b 0
)
echo Server on :%PORT% stopped.
exit /b 0

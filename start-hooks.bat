@echo off
setlocal
set "ROOT=%~dp0"

set "ADB=%ROOT%tools\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"
set "SERVER=%ROOT%tools\frida-server-17.24.3-android-arm64"
set "DEV=/data/local/tmp/frida-server"

echo [1/4] adb server
"%ADB%" start-server >nul 2>&1

echo [2/4] frida-server
"%ADB%" shell "su -c 'pidof frida-server'" > "%TEMP%\frida_pid.txt" 2>nul
set /p FRIDA_PID=<"%TEMP%\frida_pid.txt"
if "%FRIDA_PID%"=="" (
    echo     pushing frida-server ^(first run, ~80 MB^)...
    "%ADB%" push "%SERVER%" %DEV%
    "%ADB%" shell "su -c 'chmod 755 %DEV%'"
    echo     starting...
    start "" /b "%ADB%" shell "su -c '%DEV% -D'"
    timeout /t 3 >nul
) else (
    echo     already running: %FRIDA_PID%
)

echo [3/4] port forward
"%ADB%" forward tcp:27042 tcp:27042

echo [4/4] hooks - keep this window open while flashing
echo.
where python >nul 2>&1
if errorlevel 1 (
    echo Python 3 not found in PATH. Install Python 3.8+ and retry.
    pause
    exit /b 1
)
set "PYTHONPATH=%ROOT%scripts\pylibs"
python "%ROOT%scripts\hooks_forever.py"

echo.
echo hooks stopped.
pause

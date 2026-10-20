@echo off
setlocal
set "ROOT=%~dp0"
set "ADB=%ROOT%tools\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"

echo [1/3] stop hooks client
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*hooks_forever.py*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1

echo [2/3] remove port forward
"%ADB%" forward --remove tcp:27042 >nul 2>&1

echo [3/3] stop frida-server on device
"%ADB%" shell "su -c 'pkill -f frida-server'" >nul 2>&1

echo.
echo hooks stopped. You can close the start-hooks window.
pause

@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean-generated.ps1" %*
exit /b %ERRORLEVEL%

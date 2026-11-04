@echo off
setlocal
where pwsh.exe >nul 2>&1
if errorlevel 1 (
 echo PowerShell 7.4 or newer is required. Install PowerShell 7 first.
 pause
 exit /b 1
)
pwsh.exe -NoProfile -File "%~dp0M365-Toolkit.ps1"
if errorlevel 1 pause

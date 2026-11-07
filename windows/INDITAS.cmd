@echo off
cd /d "%~dp0"
if not exist "%~dp0Otthon-TV-Kezelo.ps1" (
  echo A teljes ZIP-et csomagold ki, majd onnan inditsd a kezelot.
  pause
  exit /b 1
)
start "" powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Otthon-TV-Kezelo.ps1"

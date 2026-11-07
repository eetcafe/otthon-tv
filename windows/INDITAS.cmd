@echo off
cd /d "%~dp0"
if not exist "%~dp0Otthon-TV-Kezelo.ps1" (
  echo A teljes ZIP-et csomagold ki, majd onnan inditsd a kezelot.
  pause
  exit /b 1
)
rem A GUI közvetlenül indul. Hiba esetén a PowerShell-ablak nyitva marad.
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -NoExit -File "%~dp0Otthon-TV-Kezelo.ps1"

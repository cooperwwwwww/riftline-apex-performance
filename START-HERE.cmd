@echo off
title Riftline - Apex Performance Suite
if exist "%~dp0Riftline.exe" (
  start "" "%~dp0Riftline.exe"
  exit /b 0
)
if not exist "%~dp0Apex-Performance.ps1" (
  echo Apex-Performance.ps1 is missing. Extract the entire ZIP before starting.
  pause
  exit /b 1
)
start "Riftline" powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Apex-Performance.ps1" -Mode WebGui

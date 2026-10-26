@echo off
title Apply Apex Legends low-end 720p preset
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apex-Performance.ps1" -Mode LowEnd720
echo.
pause


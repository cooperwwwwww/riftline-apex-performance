@echo off
title Apply Apex Legends competitive performance preset
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apex-Performance.ps1" -Mode Competitive
echo.
pause


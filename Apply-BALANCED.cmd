@echo off
title Apply Apex Legends balanced preset
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apex-Performance.ps1" -Mode Balanced
echo.
pause


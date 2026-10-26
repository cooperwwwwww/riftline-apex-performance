@echo off
title Apply Apex Legends automatic performance preset
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apex-Performance.ps1" -Mode Auto
echo.
pause


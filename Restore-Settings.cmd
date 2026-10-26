@echo off
title Restore Apex Legends video settings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apex-Performance.ps1" -Mode Restore
echo.
pause


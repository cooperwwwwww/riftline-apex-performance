@echo off
title Apply Apex Legends turbo settings without changing resolution
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apex-Performance.ps1" -Mode TurboCurrent
echo.
pause


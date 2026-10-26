@echo off
setlocal
if not exist "%~dp0Riftline.exe" (
  echo Riftline.exe is missing. Extract the entire folder first.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Riftline.lnk'); $s.TargetPath='%~dp0Riftline.exe'; $s.WorkingDirectory='%~dp0'; $s.IconLocation='%~dp0Riftline.exe,0'; $s.Description='Riftline - Apex Performance Suite'; $s.Save()"
if errorlevel 1 (
  echo The desktop shortcut could not be created.
  pause
  exit /b 1
)
echo Riftline desktop shortcut created.
timeout /t 2 /nobreak >nul

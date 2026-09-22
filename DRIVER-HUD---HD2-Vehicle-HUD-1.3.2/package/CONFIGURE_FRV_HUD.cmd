@echo off
setlocal
set "SCRIPT=%~dp0Tools\FRV_HUD_Configurator.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: Missing Tools\FRV_HUD_Configurator.ps1
  echo Please extract the complete DRIVER HUD archive before running this file.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%SCRIPT%"
if errorlevel 1 (
  echo.
  echo DRIVER HUD FRV configurator closed with an error.
  pause
)
endlocal

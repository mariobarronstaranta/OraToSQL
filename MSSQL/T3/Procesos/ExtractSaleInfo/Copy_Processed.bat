@echo off
setlocal DisableDelayedExpansion
if "%~1"=="" exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0soporte\Copy_Processed.ps1" -Archivo "%~f1" -Directorio "%~dp0Processed"
exit /b %errorlevel%

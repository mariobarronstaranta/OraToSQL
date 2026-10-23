@echo off
setlocal DisableDelayedExpansion
call "%~dp0Configuracion.bat"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Exportar_CSV.ps1" -Reporte Diff %*
exit /b %errorlevel%

@echo off
setlocal DisableDelayedExpansion
call "%~dp0Configuracion.bat"
rem PBI incluye despues diferencias, como el BAT Oracle.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Exportar_CSV.ps1" -Reporte PBI %*
exit /b %errorlevel%

@echo off
setlocal DisableDelayedExpansion
rem Exporta MiReto; la configuracion de conexion esta en Configuracion.bat.
call "%~dp0Exportar_CSV.bat" "MIRETO" "HeaderMiReto.sql"
exit /b %errorlevel%


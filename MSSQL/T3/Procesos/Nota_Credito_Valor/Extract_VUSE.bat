@echo off
setlocal DisableDelayedExpansion
rem Exporta VUSE; la configuracion de conexion esta en Configuracion.bat.
call "%~dp0Exportar_CSV.bat" "VUSE" "HeaderVUSE.sql"
exit /b %errorlevel%


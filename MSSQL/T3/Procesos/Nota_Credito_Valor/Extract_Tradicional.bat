@echo off
setlocal DisableDelayedExpansion
rem Exporta Tradicional; la configuracion de conexion esta en Configuracion.bat.
call "%~dp0Exportar_CSV.bat" "TRADICIONAL" "HeaderTradicional.sql"
exit /b %errorlevel%


@echo off
setlocal DisableDelayedExpansion
rem Exporta KeyAccount; la configuracion de conexion esta en Configuracion.bat.
call "%~dp0Exportar_CSV.bat" "KEYACCOUNT" "HeaderKeyAccount.sql"
exit /b %errorlevel%


@echo off
setlocal DisableDelayedExpansion
rem Exporta Conecta2; la configuracion de conexion esta en Configuracion.bat.
call "%~dp0Exportar_CSV.bat" "CONECTA2" "HeaderConecta2.sql"
exit /b %errorlevel%


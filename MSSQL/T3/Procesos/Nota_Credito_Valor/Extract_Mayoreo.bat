@echo off
setlocal DisableDelayedExpansion
rem Exporta Mayoreo; la configuracion de conexion esta en Configuracion.bat.
call "%~dp0Exportar_CSV.bat" "MAYOREO" "HeaderMayoreo.sql"
exit /b %errorlevel%


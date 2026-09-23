@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0" || exit /b 1
call Config.bat
if errorlevel 1 goto failed
call Sql.bat -i "sql\01_Infraestructura.sql" -i "sql\02_Reporte.sql" -i "sql\03_Procesar.sql"
if errorlevel 1 goto failed
echo Instalacion completada en %WOT_SERVER% / %WOT_DATABASE%.
popd
exit /b 0
:failed
echo ERROR: instalacion incompleta. Revise los mensajes SQL.
popd
exit /b 1

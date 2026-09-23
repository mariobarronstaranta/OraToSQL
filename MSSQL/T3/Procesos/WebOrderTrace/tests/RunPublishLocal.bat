@echo off
setlocal DisableDelayedExpansion
set "WOT_SERVER=(localdb)\MSSQLLocalDB"
set "WOT_DATABASE=CodexWebOrderTraceTest"
set "WOT_TRUSTED=1"
set "WOT_SQL_EXTRA=-No"
set "WOT_CODEPAGE=65001"
set "WOT_BCP_EXTRA="
pushd "%~dp0work\publishclient" || exit /b 1
set "WOT_PUBLISH_DIR=%CD%\delivery"
if not exist delivery mkdir delivery
call Reporte.bat PUBLICAR
if errorlevel 1 goto failed
if not exist "delivery\PREVENTA_CANCELADA.csv" goto failed
sqlcmd -S "%WOT_SERVER%" -E -No -b -d "%WOT_DATABASE%" -Q "IF NOT EXISTS(SELECT 1 FROM EAI.CONTROL_REPORTE WHERE REPORTE='AUTO-NOT DELIVERED' AND FIN IS NOT NULL) THROW 52030,'Control no actualizado',1;"
if errorlevel 1 goto failed
popd
exit /b 0
:failed
popd
exit /b 1

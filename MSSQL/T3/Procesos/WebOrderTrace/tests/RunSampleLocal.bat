@echo off
setlocal DisableDelayedExpansion
rem Harness exclusivo LocalDB. Usa copias de los archivos, nunca T3QA.
set "WOT_SERVER=(localdb)\MSSQLLocalDB"
set "WOT_DATABASE=CodexWebOrderTraceTest"
set "WOT_TRUSTED=1"
set "WOT_SQL_EXTRA=-No"
set "WOT_CODEPAGE=65001"
set "WOT_BCP_EXTRA="
pushd "%~dp0.." || exit /b 1
if not exist "tests\work\client" mkdir "tests\work\client"
copy /y "*.bat" "tests\work\client\" >nul
copy /y "*.sql" "tests\work\client\" >nul
xcopy /e /i /y "soporte" "tests\work\client\soporte" >nul
if errorlevel 1 goto failed
copy /y "upload.fmt" "tests\work\client\" >nul
copy /y "..\..\..\..\ORA\T3\Procesos\WebOrderTrace\Order.csv" "tests\work\client\Order.csv" >nul
if errorlevel 1 goto failed
copy /y "..\..\..\..\ORA\T3\Procesos\WebOrderTrace\Invoice.csv" "tests\work\client\Invoice.csv" >nul
if errorlevel 1 goto failed
call "tests\work\client\Reporte.bat" LOCAL
if errorlevel 1 goto failed
sqlcmd -S "%WOT_SERVER%" -E -No -b -d "%WOT_DATABASE%" -Q "SET NOCOUNT ON; IF (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_ORDER)<>2339 THROW 52020,'Conteo de ordenes incorrecto',1; IF (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_INVOICE)<>2257 THROW 52021,'Conteo de facturas incorrecto',1; SELECT TOP(1) RunId,State,OrderRows,InvoiceRows FROM EAI_OWNER.WOT_RUN ORDER BY Started DESC;"
if errorlevel 1 goto failed
popd
exit /b 0
:failed
popd
exit /b 1

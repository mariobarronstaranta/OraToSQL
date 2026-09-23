@echo off
setlocal DisableDelayedExpansion
set "WOT_SERVER=(localdb)\MSSQLLocalDB"
set "WOT_DATABASE=CodexWebOrderTraceTest"
set "WOT_TRUSTED=1"
set "WOT_SQL_EXTRA=-No"
set "WOT_CODEPAGE=65001"
set "WOT_BCP_EXTRA="
pushd "%~dp0.." || exit /b 1
call soporte\Prevalidar.bat
if errorlevel 1 goto failed
call soporte\Instalar.bat
if errorlevel 1 goto failed
if not exist "tests\work\reportonlyclient" mkdir "tests\work\reportonlyclient"
copy /y "*.bat" "tests\work\reportonlyclient\" >nul
copy /y "*.sql" "tests\work\reportonlyclient\" >nul
xcopy /e /i /y "soporte" "tests\work\reportonlyclient\soporte" >nul
if errorlevel 1 goto failed
sqlcmd -S "%WOT_SERVER%" -E -No -b -d "%WOT_DATABASE%" -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*),MAX(INSERT_TS) FROM EAI_OWNER.WO_TMP_INVOICE; SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_ORDER;" -o "tests\work\before.txt"
if errorlevel 1 goto failed
call "tests\work\reportonlyclient\Reporte.bat" SOLO_REPORTE
if errorlevel 1 goto failed
sqlcmd -S "%WOT_SERVER%" -E -No -b -d "%WOT_DATABASE%" -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*),MAX(INSERT_TS) FROM EAI_OWNER.WO_TMP_INVOICE; SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_ORDER;" -o "tests\work\after.txt"
if errorlevel 1 goto failed
fc /b "tests\work\before.txt" "tests\work\after.txt"
if errorlevel 1 goto failed
popd
exit /b 0
:failed
popd
exit /b 1

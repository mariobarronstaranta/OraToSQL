@echo off
setlocal DisableDelayedExpansion
set "VTA_SERVER=(localdb)\MSSQLLocalDB"
set "VTA_DATABASE=CodexVentasMigrationTest"
set "VTA_TRUSTED=1"
set "VTA_SQL_EXTRA=-No"
pushd "%~dp0work\invalid" || exit /b 1
call ExtractVTAFG.bat
if not errorlevel 1 goto failed
if exist "VTA_*.CSV" goto failed
if exist "Processed\*.CSV" goto failed
if exist ".venta_lock" goto failed
echo OK: periodo invalido devuelve error, no publica CSV y libera el bloqueo.
popd
exit /b 0
:failed
popd
exit /b 1

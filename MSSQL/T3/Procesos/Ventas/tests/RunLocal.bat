@echo off
setlocal DisableDelayedExpansion
set "VTA_SERVER=(localdb)\MSSQLLocalDB"
set "VTA_DATABASE=CodexVentasMigrationTest"
set "VTA_TRUSTED=1"
set "VTA_SQL_EXTRA=-No"
pushd "%~dp0work" || exit /b 1
call "VentaAdrianG - CFDI\ExtractVTAAG.bat"
if errorlevel 1 goto failed
call "VentaFelipeG\ExtractVTAFG.bat"
if errorlevel 1 goto failed
call "VentaFelipeG - CFDI\ExtractVTAAG.bat"
if errorlevel 1 goto failed
popd
exit /b 0
:failed
popd
exit /b 1

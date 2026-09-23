@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0" || exit /b 1
set "MODE=%~1"
if not defined MODE set "MODE=LOCAL"
if /i "%MODE%"=="LOCAL" goto valid
if /i "%MODE%"=="PUBLICAR" goto valid
if /i "%MODE%"=="SOLO_REPORTE" goto valid
echo Uso: Reporte.bat [LOCAL^|PUBLICAR^|SOLO_REPORTE]
popd
exit /b 2
:valid
call soporte\Config.bat
if errorlevel 1 goto fail_early
rem Lock local: una segunda ejecucion no comparte archivos temporales.
mkdir ".wot_lock" 2>nul
if errorlevel 1 (
 echo ERROR: existe .wot_lock. Verifique que no haya otra ejecucion activa.
 goto fail_early
)
if not exist "Logs" mkdir "Logs"
if not exist "Processed" mkdir "Processed"
if /i "%MODE%"=="PUBLICAR" if not exist "%WOT_PUBLISH_DIR%\." (
 echo ERROR: no existe el destino %WOT_PUBLISH_DIR%.
 goto failed
)
if /i "%MODE%"=="SOLO_REPORTE" goto begin_run
if not exist "Order.csv" (
 echo ERROR: falta Order.csv junto al BAT.
 goto failed
)
if not exist "Invoice.csv" (
 echo ERROR: falta Invoice.csv junto al BAT.
 goto failed
)
:begin_run
call soporte\Sql.bat -Q "SET NOCOUNT ON; EXEC EAI_OWNER.WOT_BEGIN;" -h -1 -W -o ".wot_lock\run.txt"
if errorlevel 1 goto failed
set /p RUNID=<".wot_lock\run.txt"
if not defined RUNID goto failed
set "SUFFIX=%RUNID:-=%"
set "LOG=Logs\%RUNID%.log"
echo RunId=%RUNID% Mode=%MODE% >"%LOG%"
call soporte\Sql.bat -Q "SET NOCOUNT ON; SELECT CONVERT(char(6),Started,12)+'_'+REPLACE(CONVERT(char(5),Started,108),':','') FROM EAI_OWNER.WOT_RUN WHERE RunId='%RUNID%';" -h -1 -W -o ".wot_lock\stamp.txt" >>"%LOG%" 2>&1
if errorlevel 1 goto failed
set /p STAMP=<".wot_lock\stamp.txt"
set "OUT35=WebOrder_%STAMP%.CSV"
set "OUT370=WebOrder_370dias_%STAMP%.CSV"
if exist "%OUT35%" (
 echo ERROR: ya existe el reporte de este minuto. Espere al siguiente minuto.
 goto failed
)
if /i "%MODE%"=="SOLO_REPORTE" goto report_only
set "WOT_PHASE=LOAD"
call LoadSFWO_Invoices.Bat >>"%LOG%" 2>&1
if errorlevel 1 goto failed
call LoadSFWO_Orders.Bat >>"%LOG%" 2>&1
if errorlevel 1 goto failed
call soporte\Sql.bat -i "Header.sql" -v RunId="%RUNID%" Load=1 >>"%LOG%" 2>&1
if errorlevel 1 goto failed
goto export
:report_only
call soporte\Sql.bat -i "Header.sql" -v RunId="%RUNID%" Load=0 >>"%LOG%" 2>&1
if errorlevel 1 goto failed
:export
set "WOT_PHASE=EXPORT"
call ExtractWebOrder.bat >>"%LOG%" 2>&1
if errorlevel 1 goto failed
move /y ".wot_lock\35.csv" "%OUT35%" >nul
if errorlevel 1 goto failed
move /y ".wot_lock\370.csv" "%OUT370%" >nul
if errorlevel 1 goto failed
copy /y "%OUT35%" "Processed\%OUT35%" >nul
if errorlevel 1 goto failed
copy /y "%OUT370%" "Processed\%OUT370%" >nul
if errorlevel 1 goto failed
if /i not "%MODE%"=="PUBLICAR" goto done
copy /y "%OUT35%" "%WOT_PUBLISH_DIR%\PREVENTA_CANCELADA.%RUNID%.tmp" >nul
if errorlevel 1 goto failed
move /y "%WOT_PUBLISH_DIR%\PREVENTA_CANCELADA.%RUNID%.tmp" "%WOT_PUBLISH_DIR%\PREVENTA_CANCELADA.csv" >nul
if errorlevel 1 goto failed
call soporte\Sql.bat -Q "EXEC EAI_OWNER.WOT_MARK_PUBLISHED @RunId='%RUNID%';" >>"%LOG%" 2>&1
if errorlevel 1 goto failed
:done
call soporte\Sql.bat -Q "EXEC EAI_OWNER.WOT_CLEANUP @RunId='%RUNID%';" >>"%LOG%" 2>&1
if errorlevel 1 goto failed
rem Solo elimina archivos internos conocidos. Nunca borra CSV de entrada/historico.
del /q ".wot_lock\run.txt" ".wot_lock\stamp.txt" 2>nul
if exist ".wot_lock\eol.bin" del /q ".wot_lock\eol.bin"
if exist ".wot_lock\Order.upload" del /q ".wot_lock\Order.upload"
if exist ".wot_lock\Invoice.upload" del /q ".wot_lock\Invoice.upload"
rmdir ".wot_lock"
echo OK: %OUT35% y %OUT370%. Modo %MODE%. Log: %LOG%
popd
exit /b 0
:failed
echo ERROR: proceso detenido. Revise Logs y .wot_lock. No se reintenta automaticamente.
echo RunId=%RUNID%. Conserve el identificador para recuperar o limpiar esta ejecucion.
rem No limpia automaticamente: conserva evidencia y reportes para recuperacion.
:fail_early
popd
exit /b 1

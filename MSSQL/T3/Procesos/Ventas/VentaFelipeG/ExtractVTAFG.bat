@echo off
setlocal DisableDelayedExpansion
rem Coloque la contrasena entre el signo igual y la comilla final.
rem Si contiene un signo de porcentaje, escribalo dos veces (%%).
set "SQLCMDPASSWORD=avantechPrimeTime2"
pushd "%~dp0" || exit /b 1
if not defined VTA_SERVER set "VTA_SERVER=AZCRNMXNEVTD06"
if not defined VTA_DATABASE set "VTA_DATABASE=T3QA"
if not defined VTA_USER set "VTA_USER=AT85233588"
if not defined VTA_CODEPAGE set "VTA_CODEPAGE=65001"
where sqlcmd.exe >nul 2>&1
if errorlevel 1 (
 echo ERROR: no se encontro sqlcmd.exe.
 goto early_error
)
if not "%VTA_TRUSTED%"=="1" if not defined SQLCMDPASSWORD (
 echo ERROR: configure SQLCMDPASSWORD al inicio de este archivo BAT.
 goto early_error
)
mkdir ".venta_lock" 2>nul
if errorlevel 1 (
 echo ERROR: otra ejecucion esta activa o quedo .venta_lock de una interrupcion.
 goto early_error
)
if not exist "Logs" mkdir "Logs"
if not exist "Logs\." goto failed
if not exist "Processed" mkdir "Processed"
if not exist "Processed\." goto failed
set "LOG=Logs\Ejecucion.log"
call :sql -Q "SET NOCOUNT ON; SELECT CONVERT(char(6),GETDATE(),12)+'_'+REPLACE(CONVERT(char(5),GETDATE(),108),':','');" -h -1 -W -o ".venta_lock\stamp.txt" >"%LOG%" 2>&1
if errorlevel 1 goto stamp_failed
set "STAMP="
set /p STAMP=<".venta_lock\stamp.txt"
if not defined STAMP goto failed
set "OUTPUT=VTA_%STAMP%.CSV"
set "LOG=Logs\VTA_%STAMP%.log"
if exist "%OUTPUT%" (
 echo ERROR: ya existe %OUTPUT%. Espere al siguiente minuto para otra ejecucion.
 goto failed
)
if exist "Processed\%OUTPUT%" (
 echo ERROR: ya existe Processed\%OUTPUT%. No se sobrescribe el historico.
 goto failed
)
call :sql -i "Header.sql" -y 0 -w 65535 -f %VTA_CODEPAGE% -o ".venta_lock\reporte.tmp" >"%LOG%" 2>&1
if errorlevel 1 goto extract_failed
for %%F in (".venta_lock\reporte.tmp") do if %%~zF==0 goto failed
copy /b ".venta_lock\reporte.tmp" "Processed\%OUTPUT%.tmp" >nul
if errorlevel 1 goto failed
move /y "Processed\%OUTPUT%.tmp" "Processed\%OUTPUT%" >nul
if errorlevel 1 goto failed
move /y ".venta_lock\reporte.tmp" "%OUTPUT%" >nul
if errorlevel 1 goto failed
call :unlock
echo OK: %OUTPUT%
echo Historico: Processed\%OUTPUT%
echo Log: %LOG%
popd
exit /b 0
rem sqlcmd puede escribir sus errores en el archivo indicado por -o.
:stamp_failed
if exist ".venta_lock\stamp.txt" type ".venta_lock\stamp.txt" >>"%LOG%"
goto failed
:extract_failed
if exist ".venta_lock\reporte.tmp" type ".venta_lock\reporte.tmp" >>"%LOG%"
goto failed
:failed
echo ERROR: no se completo la extraccion. Revise "%CD%\%LOG%".
echo Para conservar este mensaje, ejecute el BAT desde una ventana de CMD abierta.
rem Ante un error conocido, libera solo los temporales propios para reintentar.
call :unlock
:early_error
popd
exit /b 1
:unlock
if exist ".venta_lock\stamp.txt" del /q ".venta_lock\stamp.txt"
if exist ".venta_lock\reporte.tmp" del /q ".venta_lock\reporte.tmp"
rmdir ".venta_lock" 2>nul
exit /b 0
:sql
if "%VTA_TRUSTED%"=="1" goto sql_trusted
sqlcmd.exe -S "%VTA_SERVER%" -d "%VTA_DATABASE%" -U "%VTA_USER%" -b -r1 %VTA_SQL_EXTRA% %*
exit /b %errorlevel%
:sql_trusted
sqlcmd.exe -S "%VTA_SERVER%" -d "%VTA_DATABASE%" -E -b -r1 %VTA_SQL_EXTRA% %*
exit /b %errorlevel%

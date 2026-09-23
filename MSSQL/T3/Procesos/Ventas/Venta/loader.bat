@echo off
setlocal DisableDelayedExpansion
if /i "%~1"=="__cargar" goto cargar
rem GUIA: colocar factura.ready.doc junto a este BAT. No es un archivo Word.
rem Completar la clave despues de =; escribir %% por cada porcentaje literal.
rem Una clave ya configurada en la sesion tiene prioridad.
if not defined SQLCMDPASSWORD set "SQLCMDPASSWORD="
if not defined VENTA_SERVER set "VENTA_SERVER=AZCRNMXNEVTD06"
if not defined VENTA_DATABASE set "VENTA_DATABASE=T3QA"
if not defined VENTA_USER set "VENTA_USER=AT85233588"
rem El origen Oracle utiliza ISO-8859-1. Cambiar a 65001 solo si el archivo es UTF-8.
if not defined VENTA_CODEPAGE set "VENTA_CODEPAGE=28591"
rem VENTA_SQL_EXTRA admite opciones de sqlcmd, por ejemplo -C si se autoriza.
rem VENTA_BCP_EXTRA es independiente: -C en bcp indica la pagina de codigos.
pushd "%~dp0" || exit /b 1
where sqlcmd.exe >nul 2>&1
if errorlevel 1 goto herramientas
where bcp.exe >nul 2>&1
if errorlevel 1 goto herramientas
if not "%VENTA_TRUSTED%"=="1" if not defined SQLCMDPASSWORD (
 echo ERROR: configure SQLCMDPASSWORD al inicio del BAT.
 goto salir_error
)
for %%F in (factura.ready.doc control.ctl truncate_ldr.sql moveDailyInfo.sql) do if not exist "%%F" (
 echo ERROR: falta %%F en la carpeta del BAT.
 goto salir_error
)
rem Bloqueo local: no retirar hasta confirmar que no hay otra ejecucion activa.
mkdir ".venta_loader_lock" 2>nul
if errorlevel 1 (
 echo ERROR: existe .venta_loader_lock o no hay permisos de escritura.
 goto salir_error
)
set "VENTA_RUN=%RANDOM%_%RANDOM%_%RANDOM%"
set "VENTA_STAGE=##Venta_%VENTA_RUN%"
set "STAMP=sin_fecha_%VENTA_RUN%"
set "RESULTADO=ERROR"
set "SALIDA=1"
>"process.log" echo Esperando carga bcp
>"moveDailyInfo.log" echo Inicio de carga de ventas
if exist "factura.ready.bad" del /q "factura.ready.bad"
if exist "factura.ready.bad" goto fallo
if not exist "processed" mkdir "processed"
if not exist "processed\." goto fallo
copy /b "factura.ready.doc" ".venta_loader_lock\original.doc" >nul
if errorlevel 1 goto fallo
copy /b ".venta_loader_lock\original.doc" ".venta_loader_lock\entrada.doc" >nul
if errorlevel 1 goto fallo
rem Asegurar fin de linea sin cambiar el original que se archiva.
echo.>>".venta_loader_lock\entrada.doc"
if errorlevel 1 goto fallo
>".venta_loader_lock\carga_estado.sql" echo THROW 51501,'Fallo de bcp. Revisar process.log.',1;
if errorlevel 1 goto fallo
rem Una sola sesion SQL protege el flujo completo, incluso la carga bcp.
if "%VENTA_TRUSTED%"=="1" goto ejecutar_windows
sqlcmd.exe -S "%VENTA_SERVER%" -d "%VENTA_DATABASE%" -U "%VENTA_USER%" -b -r1 -l 30 -h -1 -W %VENTA_SQL_EXTRA% -i "truncate_ldr.sql" -v StageTable="%VENTA_STAGE%" >>"moveDailyInfo.log" 2>&1
goto comprobar
:ejecutar_windows
sqlcmd.exe -S "%VENTA_SERVER%" -d "%VENTA_DATABASE%" -E -b -r1 -l 30 -h -1 -W %VENTA_SQL_EXTRA% -i "truncate_ldr.sql" -v StageTable="%VENTA_STAGE%" >>"moveDailyInfo.log" 2>&1
:comprobar
if errorlevel 1 goto fallo
set "RC="
if exist ".venta_loader_lock\resultado.txt" set /p RC=<".venta_loader_lock\resultado.txt"
if "%RC%"=="0" (
 set "RESULTADO=OK"
 set "SALIDA=0"
 goto archivar
)
if "%RC%"=="1" (
 set "RESULTADO=PARCIAL"
 set "SALIDA=2"
 goto archivar
)
:fallo
echo ERROR: revisar moveDailyInfo.log y process.log. Puede haber documentos ya confirmados.
:archivar
rem Archivar el archivo exacto utilizado y ambos logs; nunca usar comodines.
rem Solo una carga completa queda directamente bajo processed.
if exist ".venta_loader_lock\stamp.txt" set /p STAMP=<".venta_loader_lock\stamp.txt"
set "HIST=processed"
if "%RESULTADO%"=="PARCIAL" set "HIST=processed\parcial"
if "%RESULTADO%"=="ERROR" set "HIST=processed\error"
if not exist "%HIST%" mkdir "%HIST%"
if not exist "%HIST%\." goto error_archivo
set "BASE=%STAMP%_%VENTA_RUN%"
if exist "%HIST%\factura.processed.%BASE%.doc" goto error_archivo
if not exist ".venta_loader_lock\original.doc" goto error_archivo
copy /b ".venta_loader_lock\original.doc" "%HIST%\factura.processed.%BASE%.doc" >nul
if errorlevel 1 goto error_archivo
copy /b "process.log" "%HIST%\factura.log.%BASE%.txt" >nul
if errorlevel 1 goto error_archivo
copy /b "moveDailyInfo.log" "%HIST%\moveDailyInfo.%BASE%.log" >nul
if errorlevel 1 goto error_archivo
if exist "factura.ready.bad" copy /b "factura.ready.bad" "%HIST%\factura.%BASE%.bad" >nul
if errorlevel 1 goto error_archivo
echo %RESULTADO%: respaldo en %HIST%. Revisar moveDailyInfo.log.
if "%RESULTADO%"=="PARCIAL" echo Se conservaron documentos validos. Revisar EAI.ERROR_TABLE antes de reintentar.
call :limpiar
popd
exit /b %SALIDA%
:error_archivo
echo ERROR de respaldo. No repetir la carga sin revisar si ya se aplicaron datos.
echo Se conserva .venta_loader_lock para recuperar el archivo original y revisar el fallo.
popd
exit /b 3
:herramientas
echo ERROR: se requieren sqlcmd.exe y bcp.exe en PATH.
:salir_error
popd
exit /b 1
:limpiar
rem Solo eliminar archivos temporales conocidos de esta ejecucion.
for %%F in (original.doc entrada.doc carga_estado.sql carga_estado.ok stamp.txt resultado.txt) do if exist ".venta_loader_lock\%%F" del /q ".venta_loader_lock\%%F"
rmdir ".venta_loader_lock" 2>nul
exit /b 0
:cargar
rem Modo interno solicitado por sqlcmd; no ejecutarlo manualmente.
if not defined VENTA_STAGE exit /b 1
if not exist ".venta_loader_lock\carga_estado.sql" exit /b 1
if exist "factura.ready.bad" del /q "factura.ready.bad"
if "%VENTA_TRUSTED%"=="1" goto cargar_windows
bcp.exe "tempdb.dbo.%VENTA_STAGE%" in ".venta_loader_lock\entrada.doc" -S "%VENTA_SERVER%" -U "%VENTA_USER%" -P "%SQLCMDPASSWORD%" -f "control.ctl" -C %VENTA_CODEPAGE% -m 1 -e "factura.ready.bad" %VENTA_BCP_EXTRA% >"process.log" 2>&1
goto comprobar_bcp
:cargar_windows
bcp.exe "tempdb.dbo.%VENTA_STAGE%" in ".venta_loader_lock\entrada.doc" -S "%VENTA_SERVER%" -T -f "control.ctl" -C %VENTA_CODEPAGE% -m 1 -e "factura.ready.bad" %VENTA_BCP_EXTRA% >"process.log" 2>&1
:comprobar_bcp
if errorlevel 1 exit /b 1
if exist "factura.ready.bad" for %%F in ("factura.ready.bad") do if %%~zF GTR 0 exit /b 1
>".venta_loader_lock\carga_estado.ok" echo PRINT 'bcp completado. Validando archivo de ventas.';
if errorlevel 1 exit /b 1
move /y ".venta_loader_lock\carga_estado.ok" ".venta_loader_lock\carga_estado.sql" >nul
exit /b %errorlevel%

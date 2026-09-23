@echo off
setlocal DisableDelayedExpansion
rem Modo interno: sqlcmd conserva su sesion mientras bcp carga el archivo.
if /i "%~1"=="__cargar" goto cargar
rem Configuracion SQL Server. Puede sobreescribirse desde la sesion.
if not defined SQLCMDPASSWORD set "SQLCMDPASSWORD="
if not defined RE_SERVER set "RE_SERVER=AZCRNMXNEVTD06"
if not defined RE_DATABASE set "RE_DATABASE=T3QA"
if not defined RE_USER set "RE_USER=AT85233588"
if not defined RE_CODEPAGE set "RE_CODEPAGE=65001"
rem RE_SQL_EXTRA: opciones sqlcmd; -C solo si se autoriza confiar en el certificado.
rem RE_BCP_EXTRA: opciones adicionales del cliente bcp.
pushd "%~dp0" || exit /b 1
where sqlcmd.exe >nul 2>&1
if errorlevel 1 goto herramientas
where bcp.exe >nul 2>&1
if errorlevel 1 goto herramientas
if not "%RE_TRUSTED%"=="1" if not defined SQLCMDPASSWORD (
 echo ERROR: configure SQLCMDPASSWORD al inicio del BAT.
 goto salir_error
)
for %%F in (EvidenciaEntrega.csv control.ctl truncate_ldr.sql moveInfo.sql) do if not exist "%%F" (
 echo ERROR: falta %%F en la carpeta del BAT.
 goto salir_error
)
mkdir ".recepcion_lock" 2>nul
if errorlevel 1 (
 echo ERROR: existe .recepcion_lock o no hay permisos. Revisar ejecuciones activas.
 goto salir_error
)
copy /b "EvidenciaEntrega.csv" ".recepcion_lock\entrada.csv" >nul
if errorlevel 1 goto fallo
echo.>>".recepcion_lock\entrada.csv"
if errorlevel 1 goto fallo
set "RE_STAGE=##RecepcionEvidenciasTodos_%RANDOM%_%RANDOM%_%RANDOM%"
>".recepcion_lock\carga_estado.sql" echo THROW 51301,'No se completo la carga bcp. Revisar carga.log.',1;
if errorlevel 1 goto fallo
>"process.log" echo Inicio RecepcionEvidenciasTodos
>"carga.log" echo Esperando carga de archivo
if "%RE_TRUSTED%"=="1" goto ejecutar_windows
sqlcmd.exe -S "%RE_SERVER%" -d "%RE_DATABASE%" -U "%RE_USER%" -b -r1 -l 30 %RE_SQL_EXTRA% -i "truncate_ldr.sql" -v StageTable="%RE_STAGE%" >>"process.log" 2>&1
goto comprobar
:ejecutar_windows
sqlcmd.exe -S "%RE_SERVER%" -d "%RE_DATABASE%" -E -b -r1 -l 30 %RE_SQL_EXTRA% -i "truncate_ldr.sql" -v StageTable="%RE_STAGE%" >>"process.log" 2>&1
:comprobar
if errorlevel 1 goto fallo
call :limpiar
echo OK: evidencias aplicadas. Revisar contadores en process.log.
popd
exit /b 0
:herramientas
echo ERROR: se requieren sqlcmd.exe y bcp.exe disponibles en PATH.
goto salir_error
:fallo
echo ERROR: no se completo el proceso. Revisar process.log y carga.log.
call :limpiar
:salir_error
popd
exit /b 1
:limpiar
if exist ".recepcion_lock\entrada.csv" del /q ".recepcion_lock\entrada.csv"
if exist ".recepcion_lock\carga_estado.sql" del /q ".recepcion_lock\carga_estado.sql"
if exist ".recepcion_lock\carga_estado.ok" del /q ".recepcion_lock\carga_estado.ok"
rmdir ".recepcion_lock" 2>nul
exit /b 0
:cargar
if not defined RE_STAGE exit /b 1
if not exist ".recepcion_lock\carga_estado.sql" exit /b 1
if exist "RecepcionEvidenciasTodos.ready.bad" del /q "RecepcionEvidenciasTodos.ready.bad"
if "%RE_TRUSTED%"=="1" goto cargar_windows
bcp.exe "tempdb.dbo.%RE_STAGE%" in ".recepcion_lock\entrada.csv" -S "%RE_SERVER%" -U "%RE_USER%" -P "%SQLCMDPASSWORD%" -f "control.ctl" -C %RE_CODEPAGE% -m 1 -e "RecepcionEvidenciasTodos.ready.bad" %RE_BCP_EXTRA% >"carga.log" 2>&1
goto comprobar_carga
:cargar_windows
bcp.exe "tempdb.dbo.%RE_STAGE%" in ".recepcion_lock\entrada.csv" -S "%RE_SERVER%" -T -f "control.ctl" -C %RE_CODEPAGE% -m 1 -e "RecepcionEvidenciasTodos.ready.bad" %RE_BCP_EXTRA% >"carga.log" 2>&1
:comprobar_carga
if errorlevel 1 exit /b 1
if exist "RecepcionEvidenciasTodos.ready.bad" for %%F in ("RecepcionEvidenciasTodos.ready.bad") do if %%~zF GTR 0 exit /b 1
>".recepcion_lock\carga_estado.ok" echo PRINT 'Carga bcp completada; comienza validacion SQL.';
if errorlevel 1 exit /b 1
move /y ".recepcion_lock\carga_estado.ok" ".recepcion_lock\carga_estado.sql" >nul
exit /b %errorlevel%
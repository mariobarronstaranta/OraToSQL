@echo off
setlocal DisableDelayedExpansion
rem Recibe el prefijo del CSV y el archivo Header.sql desde Extract_*.bat.
pushd "%~dp0" || exit /b 1
call Configuracion.bat
if "%SQLCMDPASSWORD%"=="CAMBIAR_PASSWORD" (
  echo ERROR: configure SQLCMDPASSWORD en Configuracion.bat.
  goto error
)
where sqlcmd >nul 2>&1
if errorlevel 1 (
  echo ERROR: sqlcmd no esta instalado o no se encuentra en PATH.
  goto error
)
rem Carpeta temporal exclusiva: un fallo no deja un CSV incompleto.
set "NDC_WORK=%TEMP%\NDC_%RANDOM%_%RANDOM%"
if exist "%NDC_WORK%" goto error
mkdir "%NDC_WORK%" >nul 2>&1
if errorlevel 1 goto error
rem La fecha del servidor mantiene el formato original YYMMDD_HHMM.
rem -C permite el certificado del servidor; -b devuelve los errores al BAT.
sqlcmd -S "%NDC_SERVER%" -d "%NDC_DATABASE%" -U "%NDC_USER%" -C -b -r1 -h-1 -W -Q "SET NOCOUNT ON; SELECT CONVERT(char(6),GETDATE(),12)+'_'+REPLACE(CONVERT(char(5),GETDATE(),108),':','');" -o "%NDC_WORK%\fecha.txt"
if errorlevel 1 goto cleanup_error
set "NDC_STAMP="
set /p NDC_STAMP=<"%NDC_WORK%\fecha.txt"
if not defined NDC_STAMP goto cleanup_error
set "NDC_OUTPUT=%~1_%NDC_STAMP%.CSV"
rem -h-1 omite titulos de sqlcmd; el SELECT escribe el encabezado del CSV.
rem -w evita cortes de linea y -f 65001 escribe el archivo en UTF-8.
sqlcmd -S "%NDC_SERVER%" -d "%NDC_DATABASE%" -U "%NDC_USER%" -C -b -r1 -h-1 -W -w 65535 -f 65001 -i "%~2" -o "%NDC_WORK%\reporte.tmp"
if errorlevel 1 goto cleanup_error
rem Como en Oracle, una segunda ejecucion en el mismo minuto reemplaza el CSV.
move /y "%NDC_WORK%\reporte.tmp" "%NDC_OUTPUT%" >nul
if errorlevel 1 goto cleanup_error
echo Generado: %NDC_OUTPUT%
del /q "%NDC_WORK%\fecha.txt" >nul 2>&1
rmdir "%NDC_WORK%" >nul 2>&1
popd
exit /b 0
:cleanup_error
echo ERROR: no se publico el reporte. Archivos de diagnostico: %NDC_WORK%
:error
popd
exit /b 1


@echo off
if /i "%WOT_PHASE%"=="EXPORT" goto export
call "%~dp0Reporte.Bat" SOLO_REPORTE
exit /b %errorlevel%
:export
if not defined RUNID exit /b 2
rem Los SQL originales son los puntos de extraccion, con salida sin encabezado
rem automatico ni limite de ancho de columna. El CSV ya esta serializado en SQL.
call soporte\Sql.bat -i "Extract.sql" -v RunId="%RUNID%" -y 0 -w 65535 -f %WOT_CODEPAGE% -o ".wot_lock\35.csv"
if errorlevel 1 exit /b 1
call soporte\Sql.bat -i "Extract 370 dias.sql" -v RunId="%RUNID%" -y 0 -w 65535 -f %WOT_CODEPAGE% -o ".wot_lock\370.csv"
exit /b %errorlevel%

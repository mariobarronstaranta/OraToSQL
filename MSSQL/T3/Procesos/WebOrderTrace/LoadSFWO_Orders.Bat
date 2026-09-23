@echo off
rem Ejecucion directa: carga conjunta para no dejar tablas de lotes distintos.
if /i "%WOT_PHASE%"=="LOAD" goto upload
call "%~dp0Reporte.Bat" LOCAL
exit /b %errorlevel%
:upload
if not defined SUFFIX exit /b 2
echo(>".wot_lock\eol.bin"
copy /b "Order.csv"+".wot_lock\eol.bin" ".wot_lock\Order.upload" >nul
if errorlevel 1 exit /b 1
call soporte\Bcp.bat "EAI_OWNER.WOT_O_%SUFFIX%" in ".wot_lock\Order.upload" -f "upload.fmt" -C %WOT_CODEPAGE% -m 1
exit /b %errorlevel%

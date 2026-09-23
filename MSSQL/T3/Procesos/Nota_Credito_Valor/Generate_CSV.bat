@echo off
setlocal DisableDelayedExpansion
rem Trabajar siempre en la carpeta de este BAT.
pushd "%~dp0" || exit /b 1
rem Generar los cinco reportes originales. Detenerse si alguno falla.
call Extract_Conecta2.bat
if errorlevel 1 goto error
call Extract_KeyAccount.bat
if errorlevel 1 goto error
call Extract_Mayoreo.bat
if errorlevel 1 goto error
call Extract_MiReto.bat
if errorlevel 1 goto error
call Extract_Tradicional.bat
if errorlevel 1 goto error
echo Reportes generados correctamente.
popd
exit /b 0
:error
echo ERROR: el proceso se detuvo. Revise el mensaje anterior.
popd
exit /b 1


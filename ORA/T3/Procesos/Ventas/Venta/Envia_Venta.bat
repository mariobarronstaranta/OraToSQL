@ echo off
rem *----------------------------------------------------------
rem *  Bridge a Server de Integracion en Porto Allegre
rem *----------------------------------------------------------

set path=%path%;c:\winnt


> cet_wa_venta.err ftp -n -d -s:venta.dat 10.92.215.181

if errorlevel 1 goto error
  
goto :fin

:error
echo ********************************************
echo *                   E R R O R              *
echo *                                          *
echo *  Problemas en transmision de informacion *
echo *                                          *
echo ********************************************

:fin

echo ***************************************************
echo *                                                 *
echo *               Terminacion Normal                *
echo *                                                 *
echo ***************************************************

echo on

exit

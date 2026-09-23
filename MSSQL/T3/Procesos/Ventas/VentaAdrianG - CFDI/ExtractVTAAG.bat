@echo off
rem GUIA DEL OPERADOR - VENTA ADRIAN G CON CFDI
rem Este BAT consulta ventas en SQL Server y genera un CSV local.
rem ANTES DE EJECUTAR:
rem 1. Editar las dos fechas de Extract.sql con formato YYYY-MM-DD.
rem    Ejemplo: 2026-02-01 a 2026-03-01 para reportar febrero.
rem    El inicio se incluye y el fin se excluye.
rem 2. Revisar la contrasena configurada al inicio de este BAT.
rem 3. Mantener Header.sql y Extract.sql junto al BAT.
rem 4. Ejecutar una vez y esperar el mensaje OK o ERROR.
rem El tiempo depende del periodo, volumen de ventas y carga del servidor.
rem Si la ventana se cierra, abrir CMD en esta carpeta y ejecutar
rem ExtractVTAAG.bat desde alli para poder leer los mensajes.
rem No cambiar instrucciones tecnicas salvo indicacion del responsable.
rem INICIO: la configuracion siguiente se limita a esta ejecucion.
setlocal DisableDelayedExpansion
rem Confianza en el certificado del servidor autorizada por el usuario.
rem CERTIFICADO: -C omite la validacion de su cadena de confianza.
rem Esta configuracion fue autorizada para el servidor de este proceso.
set "VTA_SQL_EXTRA=-C"
rem Coloque la contrasena entre el signo igual y la comilla final.
rem Si contiene un signo de porcentaje, escribalo dos veces (%%).
set "SQLCMDPASSWORD=avantechPrimeTime2"
rem CARPETA DE TRABAJO: utiliza la ubicacion del BAT para todos los archivos.
pushd "%~dp0" || exit /b 1
rem CONEXION: servidor, base y usuario usados por el reporte.
rem Estos valores se usan si no hay otros definidos en la sesion.
rem La codificacion UTF-8 conserva acentos y caracteres especiales.
if not defined VTA_SERVER set "VTA_SERVER=AZCRNMXNEVTD06"
if not defined VTA_DATABASE set "VTA_DATABASE=T3QA"
if not defined VTA_USER set "VTA_USER=AT85233588"
if not defined VTA_CODEPAGE set "VTA_CODEPAGE=65001"
rem REQUISITOS: comprobar que sqlcmd este disponible y exista una clave.
rem Si falta sqlcmd, solicitar su instalacion o configuracion al responsable.
where sqlcmd.exe >nul 2>&1
if errorlevel 1 (
 echo ERROR: no se encontro sqlcmd.exe.
 goto early_error
)
if not "%VTA_TRUSTED%"=="1" if not defined SQLCMDPASSWORD (
 echo ERROR: configure SQLCMDPASSWORD al inicio de este archivo BAT.
 goto early_error
)
rem CONTROL: .venta_lock marca una ejecucion activa en esta carpeta.
rem Si ya existe, el BAT se detiene para evitar otra ejecucion simultanea.
rem No borrarla mientras haya un proceso activo. Si quedo por una
rem interrupcion, pedir al responsable que lo confirme antes de retirarla.
mkdir ".venta_lock" 2>nul
if errorlevel 1 (
 echo ERROR: otra ejecucion esta activa o quedo .venta_lock de una interrupcion.
 goto early_error
)
rem DIRECTORIOS: Logs guarda diagnosticos; Processed guarda el historico.
if not exist "Logs" mkdir "Logs"
if not exist "Logs\." goto failed
if not exist "Processed" mkdir "Processed"
if not exist "Processed\." goto failed
rem PRIMERA CONEXION: obtener fecha y hora del servidor para nombrar el CSV.
rem Si falla esta etapa, revisar Logs/Ejecucion.log.
rem La fecha del nombre identifica la ejecucion, no el periodo consultado.
set "LOG=Logs\Ejecucion.log"
call :sql -Q "SET NOCOUNT ON; SELECT CONVERT(char(6),GETDATE(),12)+'_'+REPLACE(CONVERT(char(5),GETDATE(),108),':','');" -h -1 -W -o ".venta_lock\stamp.txt" >"%LOG%" 2>&1
if errorlevel 1 goto stamp_failed
set "STAMP="
set /p STAMP=<".venta_lock\stamp.txt"
if not defined STAMP goto failed
rem SALIDA: VTA_CFDI seguido de fecha AAMMDD y hora HHMM.
set "OUTPUT=VTA_CFDI%STAMP%.CSV"
set "LOG=Logs\VTA_CFDI%STAMP%.log"
rem EVITAR REEMPLAZOS: no sobrescribir resultados del mismo minuto.
rem Esperar al siguiente minuto antes de repetir; no borrar el historico.
if exist "%OUTPUT%" (
 echo ERROR: ya existe %OUTPUT%. Espere al siguiente minuto para otra ejecucion.
 goto failed
)
if exist "Processed\%OUTPUT%" (
 echo ERROR: ya existe Processed\%OUTPUT%. No se sobrescribe el historico.
 goto failed
)
rem EXTRACCION: Header.sql llama a Extract.sql para consultar las ventas.
rem Estas consultas no modifican las ventas en la base de datos.
rem Se escribe un temporal; el CSV final se publica al terminar sin errores.
call :sql -i "Header.sql" -y 0 -w 65535 -f %VTA_CODEPAGE% -o ".venta_lock\reporte.tmp" >"%LOG%" 2>&1
if errorlevel 1 goto extract_failed
for %%F in (".venta_lock\reporte.tmp") do if %%~zF==0 goto failed
rem PUBLICACION: guardar primero la copia historica y luego el CSV final.
rem Si falla, revisar espacio libre y permisos de la carpeta.
rem Un fallo de archivos puede dejar una copia historica o un temporal.
copy /b ".venta_lock\reporte.tmp" "Processed\%OUTPUT%.tmp" >nul
if errorlevel 1 goto failed
move /y "Processed\%OUTPUT%.tmp" "Processed\%OUTPUT%" >nul
if errorlevel 1 goto failed
move /y ".venta_lock\reporte.tmp" "%OUTPUT%" >nul
if errorlevel 1 goto failed
call :unlock
rem FIN CORRECTO: estas son las rutas del CSV, historico y log.
rem Entregar el CSV despues del mensaje OK. El envio al consumidor es manual.
echo OK: %OUTPUT%
echo Historico: Processed\%OUTPUT%
echo Log: %LOG%
popd
exit /b 0
rem sqlcmd puede escribir sus errores en el archivo indicado por -o.
rem ERROR DE CONEXION: conservar el mensaje antes de borrar el temporal.
:stamp_failed
if exist ".venta_lock\stamp.txt" type ".venta_lock\stamp.txt" >>"%LOG%"
goto failed
rem ERROR DE CONSULTA: conservar el diagnostico en el log.
rem Puede contener filas parciales; no usarlo como reporte terminado.
:extract_failed
if exist ".venta_lock\reporte.tmp" type ".venta_lock\reporte.tmp" >>"%LOG%"
goto failed
rem ATENCION: abrir el log indicado y compartir el mensaje con el responsable.
rem No incluir la contrasena al solicitar ayuda.
rem Un error de certificado requiere revisar la configuracion de conexion.
rem Un error de inicio de sesion requiere revisar usuario, clave y acceso.
:failed
echo ERROR: no se completo la extraccion. Revise "%CD%\%LOG%".
echo Para conservar este mensaje, ejecute el BAT desde una ventana de CMD abierta.
rem Ante un error conocido, libera solo los temporales propios para reintentar.
call :unlock
rem SALIDA CON ERROR: el codigo 1 indica que no termino correctamente.
:early_error
popd
exit /b 1
rem LIMPIEZA: borrar los temporales propios y liberar el bloqueo.
rem Los CSV finales y las copias historicas se conservan.
:unlock
if exist ".venta_lock\stamp.txt" del /q ".venta_lock\stamp.txt"
if exist ".venta_lock\reporte.tmp" del /q ".venta_lock\reporte.tmp"
rmdir ".venta_lock" 2>nul
exit /b 0
rem CONEXION SQL: recibe la clave desde la variable SQLCMDPASSWORD.
rem No se imprime la clave ni se pasa como argumento al programa.
rem La opcion -b permite detectar errores SQL y detener el proceso.
:sql
if "%VTA_TRUSTED%"=="1" goto sql_trusted
sqlcmd.exe -S "%VTA_SERVER%" -d "%VTA_DATABASE%" -U "%VTA_USER%" -b -r1 %VTA_SQL_EXTRA% %*
exit /b %errorlevel%
rem MODO DE PRUEBAS: usa la cuenta Windows si VTA_TRUSTED vale 1.
rem La operacion habitual usa el usuario SQL configurado al inicio.
:sql_trusted
sqlcmd.exe -S "%VTA_SERVER%" -d "%VTA_DATABASE%" -E -b -r1 %VTA_SQL_EXTRA% %*
exit /b %errorlevel%

# Generacion de CSV de notas de credito

Ejecutar `Generate_CSV.bat` (nombre original) desde esta carpeta o mediante un acceso directo. Se conservan los nombres de los BAT y SQL originales. Los archivos se guardan junto al BAT, sin rutas absolutas ni PowerShell.

## Configuracion

En `Configuracion.bat` se indican AZCRNMXNEVTD06, T3QA y AT85233588. Sustituir CAMBIAR_PASSWORD por la clave vigente dentro de las comillas de la asignacion SQLCMDPASSWORD, o definir esa variable previamente en el entorno. Un porcentaje literal debe escribirse como %% dentro del BAT. No agregar comillas alrededor de la clave dentro de la asignacion. La clave no se incluye en los argumentos de sqlcmd.

Requiere sqlcmd en PATH, acceso al servidor, permiso SELECT sobre T3.X_PROPUESTA_NDC, T3.X_PROPUESTA_DETALLE y T3.MOV_CLIENTE, y escritura en esta carpeta y TEMP. Se utiliza -C para confiar en el certificado del servidor.

## Flujo

Generate_CSV.bat llama en orden a Extract_Conecta2.bat, Extract_KeyAccount.bat, Extract_Mayoreo.bat, Extract_MiReto.bat y Extract_Tradicional.bat. Cada BAT delega la exportacion a Exportar_CSV.bat, que ejecuta su Header*.sql mediante sqlcmd; Header incluye el Extract*.sql correspondiente.

Extract_VUSE.bat se ejecuta por separado, como en el flujo original. HeaderVUSE.sql ahora incluye ExtractVUSE.sql: el original apuntaba a Tradicional.

Los nombres mantienen PREFIJO_YYMMDD_HHMM.CSV y usan la fecha del servidor. El CSV contiene nueve columnas, separador punto y coma, fechas DD/MM/YYYY e importes con punto decimal y dos decimales. La codificacion es UTF-8; validar su aceptacion con el consumidor. Una ejecucion sin datos genera solo el encabezado. Una repeticion dentro del mismo minuto reemplaza el archivo del mismo nombre.

No se aplican filtros por fecha ni se eliminan duplicados de las uniones originales. Se conservan las coincidencias de area: Conecta2/Connecta2, KA/KeyAccount, WS/Mayoreo, MiReto, Tradicional y VUSE. Las comillas contenidas en campos entrecomillados se duplican para producir CSV valido.

Ante un error se devuelve codigo 1 y Generate_CSV se detiene. Los reportes anteriores ya terminados permanecen publicados. El archivo actual se publica solo si sqlcmd termina correctamente; los temporales de error quedan en la ruta indicada en pantalla.

## Alcance y validacion

Este flujo solo exporta propuestas existentes. No carga NDC_Ldr.txt, no llama PROC_NDC_PROPUESTA y no necesita SEQ_CFD. La preparacion de las propuestas sigue siendo un paso externo pendiente de identificar.

Se ejecutaron los seis SELECT en SQL Server LocalDB con tablas temporales y datos ficticios: encabezado, nueve columnas, filtros y alias de areas, fecha e importes correctos. No se ejecuto contra T3QA ni se compararon resultados con Oracle. Antes de uso operativo, configurar la clave y comprobar una exportacion con los datos reales y su consumidor.

/* Diagnostico de solo lectura. Ejecutar en la base donde se detecto el error.
   No ejecuta procedimientos, no reprocesa facturas ni cambia la cola.
   Fechas expresadas en la hora registrada por CREATED en la instancia.
   Conservar todos los resultados; el script no asume que sea T3QA o produccion.
*/
SET NOCOUNT ON;
DECLARE @Desde datetime2(0) = '2026-10-22T13:45:00';
DECLARE @Hasta datetime2(0) = '2026-10-22T14:10:00';
DECLARE @MostrarDefiniciones bit = 1;

SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@Desde AS Desde,@Hasta AS Hasta;

-- Resumen de los dos lotes reportados; limitado a la ventana para no recorrer
-- todo el historial. No equiparar JOB_PID con session_id/SPID de SQL Server.
SELECT JOB_PID,QUEUE_NAME,SIEBEL_ERROR_CODE,COUNT_BIG(*) AS Errores,
       MIN(CREATED) AS PrimeroEnVentana,MAX(CREATED) AS UltimoEnVentana,
       COUNT(DISTINCT REFERENCE) AS ReferenciasDistintas
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=@Desde AND CREATED<@Hasta
  AND JOB_PID IN (26515578,26515579)
GROUP BY JOB_PID,QUEUE_NAME,SIEBEL_ERROR_CODE
ORDER BY JOB_PID,PrimeroEnVentana;

-- Primeros registros de cada lote: TOP DESC del query original puede ocultar
-- precisamente el error inicial. El orden entre fechas iguales no es total.
SELECT TOP (200) CREATED,QUEUE_NAME,JOB_PID,REFERENCE,STATUS,
       SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=@Desde AND CREATED<@Hasta
  AND JOB_PID IN (26515578,26515579)
ORDER BY CREATED ASC;

-- Buscar causas anteriores distintas de 3930. Los hijos pueden registrar
-- JOB_PID NULL; por ello esta consulta no se restringe al PID ni a una cola.
-- Correlacionar referencia, tiempo y procedimiento; no todo resultado sera
-- necesariamente del mismo flujo. Puede no existir registro de la causa si
-- el INSERT de su CATCH fallo o si fue revertido junto con la transaccion.
SELECT TOP (200) CREATED,QUEUE_NAME,JOB_PID,REFERENCE,STATUS,
       SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=@Desde AND CREATED<@Hasta AND STATUS='Error'
  AND (SIEBEL_ERROR_CODE IS NULL OR SIEBEL_ERROR_CODE NOT LIKE '%3930%')
ORDER BY CREATED ASC;

-- Confirmar la version instalada: el repositorio no demuestra que el codigo
-- desplegado coincida, y ERROR_LINE se refiere a la definicion del servidor.
DECLARE @Objetos TABLE (Nombre nvarchar(256) COLLATE DATABASE_DEFAULT);
INSERT @Objetos VALUES(N'EAI_OWNER.RECV_INVOICE'),
 (N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'),(N'EAI_OWNER.INVOICE_TO_PREVENTA'),
 (N'EAI_OWNER.INVOICE_TO_FACTURA'),(N'EAI_OWNER.INVOICE_TO_ENTREGA_PO'),
 (N'T3.DELIVERY_WA_OXXO');

SELECT N.Nombre,O.object_id,O.type_desc,O.create_date,O.modify_date,
       M.uses_ansi_nulls,M.uses_quoted_identifier,
       CASE WHEN M.definition IS NULL THEN N'No visible, cifrado o no existe'
            ELSE N'Definicion disponible' END AS EstadoDefinicion
FROM @Objetos N LEFT JOIN sys.objects O ON O.object_id=OBJECT_ID(N.Nombre)
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id;

IF @MostrarDefiniciones=1
 SELECT N.Nombre,M.definition AS DefinicionInstalada
 FROM @Objetos N LEFT JOIN sys.sql_modules M ON M.object_id=OBJECT_ID(N.Nombre);

-- Estado de cabeceras temporales para algunas referencias reportadas.
-- No se solicitan XML completos ni datos fiscales.
-- Las filas pueden faltar porque el padre revirtio la carga temporal.
SELECT ReferenceID,Procesado
FROM EAI_OWNER.TMP_DOCUMENT_HEADER
WHERE ReferenceID IN ('1658406415','1658406656','1658415284','1658425763');

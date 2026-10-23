/* Solo lectura en T3QA. No ejecuta ni reintenta RECV_INVOICE.
   Ejecutar despues del script 01 y de la siguiente ejecucion normal del job.
*/
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51100,'Seleccionar T3QA.',1;
DECLARE @Desde datetime2(3);
IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_3930_BACKUP',N'U') IS NULL
    THROW 51101,'No existe el respaldo del script 01; confirmar su ejecucion.',1;
SELECT @Desde=MAX(FechaAplicacion)
FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP WHERE FechaReversion IS NULL;
IF @Desde IS NULL THROW 51102,'No hay una aplicacion vigente registrada.',1;
SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@Desde AS ErroresDesde;

SELECT SCHEMA_NAME(O.schema_id) AS Esquema,O.name AS Procedimiento,O.modify_date,
       CASE WHEN CHARINDEX(N'RI3930_PROPAGATE_V1',M.definition)>0
            THEN N'Guard presente' ELSE N'Revisar: guard ausente' END AS Estado,
       CASE WHEN O.object_id=OBJECT_ID(N'T3.DELIVERY_WA_OXXO') THEN
        CASE WHEN CHARINDEX(N'RI2628_REMISION_COLUMNAS_V1',M.definition)>0
             THEN N'Columnas explicitas presentes' ELSE N'Parche 04 pendiente' END
        ELSE N'No aplica' END AS EstadoRemision,
       CASE WHEN O.object_id=OBJECT_ID(N'EAI_OWNER.INVOICE_TO_FACTURA') THEN
        CASE WHEN CHARINDEX(N'RI8114_DETAILBASE_VACIO_V1',M.definition)>0
             THEN N'Detalle vacio por material invalido habilitado' ELSE N'Parche 08 pendiente' END
        ELSE N'No aplica' END AS EstadoMaterial
FROM sys.objects O JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id IN (OBJECT_ID(N'EAI_OWNER.INVOICE_TO_PREVENTA'),
 OBJECT_ID(N'EAI_OWNER.INVOICE_TO_FACTURA'),OBJECT_ID(N'EAI_OWNER.INVOICE_TO_ENTREGA_PO'),
 OBJECT_ID(N'T3.DELIVERY_WA_OXXO'));

SELECT TOP (100) CREATED,QUEUE_NAME,JOB_PID,REFERENCE,STATUS,
       SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=@Desde AND QUEUE_NAME IN ('PROC_PREINVOICE_IFC','RECV_INVOICE')
ORDER BY CREATED ASC;

-- Sin filas puede significar que aun no corrio el job; no prueba exito.
SELECT SIEBEL_ERROR_CODE,COUNT_BIG(*) AS Errores,
       MIN(CREATED) AS Primero,MAX(CREATED) AS Ultimo
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=@Desde AND QUEUE_NAME IN ('PROC_PREINVOICE_IFC','RECV_INVOICE')
  AND STATUS='Error'
GROUP BY SIEBEL_ERROR_CODE ORDER BY Errores DESC;

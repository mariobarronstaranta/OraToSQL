/*
  Solo lectura. Identifica candidatos a revision tras el fallo del PID 26516078.
  El delegado local marca PROCESSED antes de llamar INVOICE_TO_PREVENTA.
  No resetear PROCESSED ni cambiar estados masivamente: confirmar ROW_ID primero.
  El intervalo temporal NO prueba por si solo que un mensaje pertenezca al PID.
*/
USE [T3QA];
GO
SET NOCOUNT ON;
DECLARE @Inicio DATETIME2 = '2026-10-23T17:15:22',
        @FinVentana DATETIME2 = '2026-10-23T17:15:30';

SELECT '01_ERRORES_PID' AS Seccion, CREATED, JOB_PID, QUEUE_NAME,
       REFERENCE, SIEBEL_ERROR_CODE, SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE JOB_PID = '26516078'
ORDER BY CREATED;

-- Mensajes marcados durante la ventana del fallo: candidatos, no identificacion definitiva.
SELECT TOP (100) '02_MENSAJES_EN_VENTANA' AS Seccion,
       ROW_ID, CREATED, PROCESSED, QUEUE_NAME, REFERENCE, STATUS
FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
WHERE QUEUE_NAME = 'Invoice-Intercompany'
  AND PROCESSED >= @Inicio AND PROCESSED < @FinVentana
ORDER BY PROCESSED, ROW_ID;

-- Pendientes del selector del coordinador; no ejecuta ninguno.
SELECT TOP (100) '03_PENDIENTES' AS Seccion,
       ROW_ID, CREATED, PROCESSED, QUEUE_NAME, REFERENCE, STATUS
FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
WHERE QUEUE_NAME = 'Invoice-Intercompany'
  AND CREATED > DATEADD(DAY, -5, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
  AND PROCESSED IS NULL
ORDER BY CREATED, ROW_ID;

-- Logs secundarios sin PID pueden contener una referencia de factura util.
SELECT '04_ERRORES_DELEGADOS_EN_VENTANA' AS Seccion,
       CREATED, JOB_PID, QUEUE_NAME, REFERENCE,
       SIEBEL_ERROR_CODE, SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED >= @Inicio AND CREATED < @FinVentana
  AND QUEUE_NAME IN ('SF_PROC_PREINVOICE_INTER', 'Invoice to T3', 'Delivery to T3')
ORDER BY CREATED;

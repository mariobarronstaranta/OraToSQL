/* Solo lectura. No ejecuta generadores, desmarca ni reprocesa facturas. */
USE [T3QA];
SET NOCOUNT ON;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() Captura;
SELECT O.name,O.modify_date,M.uses_ansi_nulls,M.uses_quoted_identifier,
 CASE WHEN CHARINDEX('Correccion 2026-10-29: no acreditar',M.definition)>0
      AND CHARINDEX('THROW 53805',M.definition)>0
      AND CHARINDEX('SAVE TRANSACTION OTGeneralFactura',M.definition)>0
      THEN 'COORDINADOR CON VALIDACION DE SALIDA' ELSE 'REVISAR DEFINICION' END Validacion,
 CONVERT(varchar(64),HASHBYTES('SHA2_256',M.definition),2) HashModulo
FROM sys.objects O JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id=OBJECT_ID('T3.PROC_T3_OT_GENERAL');
SELECT CASE WHEN CHARINDEX('CAST(@Doc_tasa AS DECIMAL(38,12)) / 100.0',
 OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')))>0
 THEN 'PARCHE NUMERICO PRESENTE' ELSE 'REVISAR GENERADOR' END Generador;
IF OBJECT_ID('dbo.REPAIR_OT_GENERAL_20261029','U') IS NOT NULL
 EXEC sys.sp_executesql N'SELECT Id,Captura,Reversion,
 CONVERT(varchar(64),HASHBYTES(''SHA2_256'',DefinicionAntes),2) HashAntes,
 CONVERT(varchar(64),HASHBYTES(''SHA2_256'',DefinicionDespues),2) HashDespues
 FROM dbo.REPAIR_OT_GENERAL_20261029 ORDER BY Id DESC;';

-- Las seis referencias del incidente son historicas: esta revision no las
-- desmarca ni genera layouts ausentes. UUID/envio/timbre impiden regenerarlas.
SELECT G.Factura,G.Fecha_Proc_BATMD,D.Status,D.Folio_Fiscal,D.Fecha_Timbre,D.Fecha_Envio,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR E WHERE E.Nota_Venta=G.Factura) Layouts
FROM T3.OTROS_GENERAL G LEFT JOIN T3.CFDI_DOCUMENTOS D ON D.Nota_Venta=G.Factura
WHERE G.Factura IN ('1658507150','1658507151','1658516300','1658516520','1658520040','1658520050')
ORDER BY G.Factura;
SELECT TOP(30) Fecha,Rutina,Referencia,ERROR_DESC FROM T3.RF_ERROR_LOG
WHERE Rutina='PROC_T3_OT_GENERAL' ORDER BY Fecha DESC;

/* Solo lectura; no ejecuta generadores ni desmarca facturas.
   Guarda Resultados/Mensajes para las seis referencias del error.
*/
USE [T3QA]; SET NOCOUNT ON;
DECLARE @F table(Factura varchar(30) COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT @F VALUES('1658507150'),('1658507151'),('1658516300'),('1658516520'),('1658520040'),('1658520050');
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() Captura;
SELECT '01_ESTADO_CABECERAS' Seccion,G.Factura,G.Sociedad,G.Clase_Factura,
 G.Fecha_Trn,G.Fecha_Proc_BATMD,G.Valor_Subt,G.Valor_IVA,G.Retencion_IVA,
 E.Documentos,E.Layouts
FROM T3.OTROS_GENERAL G JOIN @F F ON F.Factura=G.Factura
OUTER APPLY(SELECT
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS D WHERE D.Nota_Venta=G.Factura) Documentos,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR D WHERE D.Nota_Venta=G.Factura) Layouts) E;

-- Mismo tipo y expresion que ScrDatos, conservando SUM(DECIMAL) de retenciones.
SELECT '02_CONVERSION_TASA' Seccion,G.Factura,G.Valor_Subt,G.Valor_IVA,R.Retenido,
 SQL_VARIANT_PROPERTY(X.Tasa,'Precision') PrecisionTasa,
 SQL_VARIANT_PROPERTY(X.Tasa,'Scale') EscalaTasa,
 CONVERT(varchar(100),X.Tasa) TextoAmplio,
 LEN(CONVERT(varchar(100),X.Tasa)) Caracteres,
 TRY_CONVERT(varchar(10),X.Tasa) ConversionActual,
 CONVERT(varchar(40),X.Tasa) ConversionCorregida,
 CONVERT(decimal(38,12),CONVERT(varchar(40),X.Tasa))/100.0 FraccionTasaCorregida
FROM T3.OTROS_GENERAL G JOIN @F F ON F.Factura=G.Factura
LEFT JOIN (SELECT Factura,SUM(ISNULL(Total_Condicion,0)) Retenido
 FROM T3.OTROS_CONDICIONES WHERE Condicion_ID='ZDD6'
 AND Factura IN (SELECT Factura FROM @F) GROUP BY Factura) R ON R.Factura=G.Factura
CROSS APPLY(SELECT ROUND(ISNULL(G.Valor_IVA,0)*100/
 NULLIF(ISNULL(R.Retenido,0)+ISNULL(G.Valor_Subt,0),0),0) Tasa) X;

SELECT '03_ERRORES' Seccion,E.* FROM T3.RF_ERROR_LOG E JOIN @F F ON F.Factura=E.Referencia
WHERE E.Fecha>='20261029' AND E.Rutina IN ('GENERAR_OTROS','PROC_CFDI_GENERAR_OTROS') ORDER BY E.Fecha DESC;
SELECT '04_FUNCION_FORMATO' Seccion,OBJECT_SCHEMA_NAME(P.object_id) Esquema,
 OBJECT_NAME(P.object_id) Funcion,P.name Parametro,TYPE_NAME(P.user_type_id) Tipo,
 P.max_length,P.precision,P.scale
FROM sys.parameters P WHERE P.object_id=OBJECT_ID('T3.FN_NUM_TO_CHAR_CFDI');
-- La salida XML puede abrirse en SSMS para conservar la definicion completa.
SELECT OBJECT_DEFINITION(OBJECT_ID('T3.FN_NUM_TO_CHAR_CFDI')) AS Definicion
FOR XML PATH('FuncionFormato'),TYPE;
SELECT '05_OPCIONES_MODULO' Seccion,O.name,O.modify_date,M.uses_ansi_nulls,M.uses_quoted_identifier
FROM sys.objects O JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id=OBJECT_ID('T3.PROC_V40_GENERAR_OTROS');

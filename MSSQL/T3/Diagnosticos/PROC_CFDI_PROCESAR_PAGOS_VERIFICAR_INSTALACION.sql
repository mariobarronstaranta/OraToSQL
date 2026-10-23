/* Ejecutar completo en la base donde se aplicaron los dos ALTER.
   Solo lectura de metadatos; no ejecuta PAGOS ni el control 889.
   Las marcas son indicios de version, no prueba de resultados del lote.
   Guardar todos los resultados para confirmar servidor/base/definiciones. */
SET NOCOUNT ON;

SELECT N'01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
 SYSDATETIMEOFFSET() AS FechaCaptura;

;WITH Objetos AS
(
 SELECT N'T3.PROC_CFDI_PROCESAR_PAGOS' AS Objeto,
  N'PAGOS_SAT_AMOUNT_V1' AS MarcaVersion,
  N'PAGOS_CURSOR_BIND_V1' AS MarcaCursor,
  N'Fiscal.Total_Factura' AS MarcaCalculo,
  N'SAVE TRANSACTION Pagos604' AS MarcaTransaccion
 UNION ALL
 SELECT N'T3.WA_CFDI_COBZA_ASIG_CTRL',N'COBZA_CTRL_ORACLE_V1',
  N'WHERE CURRENT OF ScrPagos',N'FOR UPDATE OF Fecha_Envio',N'SAVE TRANSACTION Cobza889'
)
SELECT N'02_PROCEDIMIENTOS' AS Seccion,X.Objeto,O.modify_date AS FechaUltimoAlter,
 CASE WHEN O.object_id IS NULL THEN N'NO ENCONTRADO O SIN VISIBILIDAD'
      WHEN M.definition IS NULL THEN N'DEFINICION NO VISIBLE'
      WHEN CHARINDEX(X.MarcaVersion,M.definition)=0
        OR CHARINDEX(X.MarcaCursor,M.definition)=0
        OR CHARINDEX(X.MarcaCalculo,M.definition)=0
        OR CHARINDEX(X.MarcaTransaccion,M.definition)=0
        OR (X.Objeto=N'T3.PROC_CFDI_PROCESAR_PAGOS'
            AND CHARINDEX(N'CAST(AP.Fecha_Proc_BATMD AS DATE)',M.definition)=0)
       THEN N'REVISAR: FALTA ALGUNA MARCA'
      ELSE N'MARCAS ESPERADAS PRESENTES' END AS EstadoVersion,
 CONVERT(bit,CASE WHEN CHARINDEX(X.MarcaVersion,M.definition)>0 THEN 1 ELSE 0 END) AS VersionOracle,
 CONVERT(bit,CASE WHEN CHARINDEX(X.MarcaCursor,M.definition)>0 THEN 1 ELSE 0 END) AS CursorCorregido,
 CONVERT(bit,CASE WHEN CHARINDEX(X.MarcaCalculo,M.definition)>0 THEN 1 ELSE 0 END) AS CalculoOActualizacion,
 CONVERT(bit,CASE WHEN CHARINDEX(X.MarcaTransaccion,M.definition)>0 THEN 1 ELSE 0 END) AS Savepoint,
 CASE WHEN X.Objeto=N'T3.PROC_CFDI_PROCESAR_PAGOS'
      THEN CONVERT(bit,CASE WHEN CHARINDEX(N'CAST(AP.Fecha_Proc_BATMD AS DATE)',M.definition)>0 THEN 1 ELSE 0 END)
      END AS FechaSoloDATE
FROM Objetos X
LEFT JOIN sys.objects O ON O.object_id=OBJECT_ID(X.Objeto,N'P')
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id
ORDER BY X.Objeto;

-- Informativo: sin una captura previa comparable, modify_date no prueba por si
-- sola que una funcion permanezca identica. Los dos ALTER entregados no las alteran.
SELECT N'03_FUNCIONES_COMPARTIDAS' AS Seccion,X.Objeto,O.modify_date AS FechaUltimoAlter,
 CASE WHEN O.object_id IS NULL THEN N'NO ENCONTRADA O SIN VISIBILIDAD'
      WHEN M.definition IS NULL THEN N'DEFINICION NO VISIBLE'
      ELSE N'VISIBLE; FUERA DEL CAMBIO ENTREGADO' END AS Estado
FROM (VALUES(N'EAI_OWNER.GETCONV'),(N'T3.FN_TOTAL_FACT')) X(Objeto)
LEFT JOIN sys.objects O ON O.object_id=OBJECT_ID(X.Objeto,N'FN')
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id
ORDER BY X.Objeto;

SELECT N'04_ALCANCE' AS Seccion,
 N'Esta consulta verifica indicios de las definiciones instaladas. La ejecucion e inserciones '
 +N'se validan por separado tras el siguiente lote normal, con su fecha BATMD y PID. '
 +N'No acredita timbrado ni paridad completa con Oracle.' AS Resultado;

/* Solo lectura de negocio en T3QA; usa dos tablas temporales de sesion.
   Revisa Invoice del prefijo y busca la referencia fallida fuera del grupo
   entre Invoice pendientes, sin fecha: RECV_INVOICE instalado tiene comentado
   su filtro de cinco dias. Esta ultima busqueda puede leer varios XML.
   No ejecuta el job ni cambia materiales, estados, fechas o reglas numericas.
*/
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51600,'Seleccionar T3QA.',1;
DECLARE @Patron varchar(32)='202610060%';
DECLARE @ReferenciaObjetivo varchar(50)='1658415284';
DECLARE @Desde datetime2(0)=CONVERT(date,SYSDATETIME());
DROP TABLE IF EXISTS #RI8114_Entrada;
DROP TABLE IF EXISTS #RI8114_Material;
DROP TABLE IF EXISTS #RI8114_Errores;

SELECT CREATED,REFERENCE INTO #RI8114_Errores
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=@Desde AND QUEUE_NAME='PROC_PREINVOICE_IFC'
  AND SIEBEL_ERROR_CODE='SQL-8114'
  AND SIEBEL_ERROR_MESSAGE LIKE '%INVOICE_TO_FACTURA%';

-- Materializar primero el grupo acotado para no abrir XML ajenos al prefijo.
SELECT ROW_ID,CREATED,PROCESSED,STATUS,REFERENCE,XML_CONTENT
INTO #RI8114_Entrada
FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
WHERE ROW_ID LIKE @Patron AND QUEUE_NAME='Invoice';

DECLARE @DelPrefijo bigint=(SELECT COUNT_BIG(*) FROM #RI8114_Entrada);
IF NOT EXISTS
 (SELECT 1 FROM #RI8114_Entrada
  WHERE XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                           'varchar(50)')=@ReferenciaObjetivo)
BEGIN
 -- Lectura adicional acotada por cola/pendientes y documento. No copiar ni
 -- abrir detalles de todo el historico: extraer solo coincidencias del header.
 INSERT #RI8114_Entrada
 SELECT TOP(100) ROW_ID,CREATED,PROCESSED,STATUS,REFERENCE,XML_CONTENT
 FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
 WHERE QUEUE_NAME='Invoice' AND PROCESSED IS NULL AND ROW_ID NOT LIKE @Patron
   AND XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                          'varchar(50)')=@ReferenciaObjetivo
 ORDER BY CREATED DESC;
END;

SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@Patron AS Patron,
       @DelPrefijo AS FacturasDelPrefijo,COUNT_BIG(*) AS MensajesAnalizados,
       COUNT_BIG(*)-@DelPrefijo AS CoincidenciasFueraDelPrefijo
FROM #RI8114_Entrada;

SELECT ROW_ID,CREATED,PROCESSED,STATUS,REFERENCE,
       XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                         'varchar(50)') AS DocumentoXML
FROM #RI8114_Entrada
WHERE XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                         'varchar(50)')=@ReferenciaObjetivo;

SELECT E.ROW_ID,
       E.XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                           'varchar(50)') AS DocumentoXML,
       I.N.value('(ItemNumber/text())[1]','nvarchar(100)') AS ItemNumber,
       D.N.value('(MaterialID/text())[1]','nvarchar(1000)') AS MaterialXML
INTO #RI8114_Material
FROM #RI8114_Entrada E
CROSS APPLY E.XML_CONTENT.nodes('/Invoice/Message/ItemData') I(N)
OUTER APPLY I.N.nodes('ItemID[ObjectIdentification="002"]') D(N);

-- NULL/vacio se reportan aparte: no equivalen por si solos a una conversion 8114.
SELECT COUNT_BIG(*) AS FilasMaterial,
       SUM(CONVERT(bigint,CASE WHEN NULLIF(TRIM(MaterialXML),N'') IS NOT NULL
                        AND TRY_CONVERT(numeric(38,0),TRIM(MaterialXML)) IS NULL
                        THEN 1 ELSE 0 END)) AS NoConvertibles,
       SUM(CONVERT(bigint,CASE WHEN NULLIF(TRIM(MaterialXML),N'') IS NULL
                        THEN 1 ELSE 0 END)) AS NulosOVacios,
       SUM(CONVERT(bigint,CASE WHEN LEN(MaterialXML)>18 THEN 1 ELSE 0 END)) AS Mayores18
FROM #RI8114_Material;

-- Casos candidatos; informacion suficiente para localizar el mensaje exacto.
SELECT M.ROW_ID,M.DocumentoXML,M.ItemNumber,
       CONVERT(nvarchar(180),M.MaterialXML) AS MaterialXML,
       LEN(M.MaterialXML) AS Caracteres,
       CONVERT(varchar(160),CONVERT(varbinary(80),M.MaterialXML),2) AS MaterialHexUnicode,
       TRY_CONVERT(numeric(38,0),TRIM(M.MaterialXML)) AS MaterialNumerico,
       CASE WHEN NULLIF(TRIM(M.MaterialXML),N'') IS NULL THEN N'Nulo/vacio: revisar, no prueba 8114'
            WHEN TRY_CONVERT(numeric(38,0),TRIM(M.MaterialXML)) IS NULL THEN N'NO convertible'
            ELSE N'Excede 18 caracteres' END AS Diagnostico,
       CASE WHEN EXISTS
        (SELECT 1 FROM #RI8114_Errores L
         WHERE L.REFERENCE COLLATE DATABASE_DEFAULT=M.DocumentoXML COLLATE DATABASE_DEFAULT)
        THEN 1 ELSE 0 END AS Tiene8114Hoy
FROM #RI8114_Material M
WHERE NULLIF(TRIM(M.MaterialXML),N'') IS NULL
   OR TRY_CONVERT(numeric(38,0),TRIM(M.MaterialXML)) IS NULL
   OR LEN(M.MaterialXML)>18
ORDER BY M.DocumentoXML,M.ROW_ID,M.ItemNumber;

-- Errores reales de hoy que SI corresponden a documentos del prefijo.
SELECT L.REFERENCE,COUNT_BIG(*) AS Errores8114,
       MIN(L.CREATED) AS Primero,MAX(L.CREATED) AS Ultimo
FROM #RI8114_Errores L
WHERE EXISTS(SELECT 1 FROM #RI8114_Material M
       WHERE M.DocumentoXML COLLATE DATABASE_DEFAULT=L.REFERENCE COLLATE DATABASE_DEFAULT)
GROUP BY L.REFERENCE ORDER BY Ultimo DESC;

-- Si no hay casos invalidos ni errores correlacionados, no asumir que este
-- grupo explica la referencia ausente; hace falta el mensaje origen del fallo.
SELECT TOP(20) M.ROW_ID,M.DocumentoXML,M.ItemNumber,
       CONVERT(nvarchar(180),M.MaterialXML) AS MaterialXML,
       TRY_CONVERT(numeric(38,0),TRIM(M.MaterialXML)) AS MaterialNumerico
FROM #RI8114_Material M ORDER BY M.ROW_ID,M.ItemNumber;

DROP TABLE #RI8114_Material;
DROP TABLE #RI8114_Entrada;
DROP TABLE #RI8114_Errores;

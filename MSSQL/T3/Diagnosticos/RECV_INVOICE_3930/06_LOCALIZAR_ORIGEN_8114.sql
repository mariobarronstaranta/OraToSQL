/* Solo lectura en T3QA. Referencia confirmada por captura 22/10/2026 14:44.
   Prioriza el prefijo ROW_ID aportado por el usuario. Busca DocumentNumber
   en la cola Invoice de ese grupo, sin limitar fecha ni estado. Si se deja
   @RowIdPatron NULL, utiliza REFERENCE y DOCNUM como alternativa. Si el
   prefijo no contiene el documento, intenta esas claves en la cola Invoice.
   No reintenta el proceso ni cambia transacciones, datos o reglas de material.
*/
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51500,'Seleccionar T3QA.',1;
DECLARE @Referencia varchar(50)='1658415284';
DECLARE @RowIdPatron varchar(32)='202610060%';
SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@Referencia AS ReferenciaBuscada,
       @RowIdPatron AS RowIdPatron;
DECLARE @Origen TABLE
 (ROW_ID varchar(32) COLLATE DATABASE_DEFAULT,CREATED datetime2(0),
  PROCESSED datetime2(0),STATUS varchar(10) COLLATE DATABASE_DEFAULT,
  REFERENCE varchar(50) COLLATE DATABASE_DEFAULT,Contenido xml,
  Busqueda varchar(20) COLLATE DATABASE_DEFAULT);

IF @RowIdPatron IS NOT NULL
BEGIN
 -- Primero comprobar si existen filas de ese grupo y su fecha real CREATED.
 SELECT QUEUE_NAME,COUNT_BIG(*) AS MensajesDelPrefijo,MIN(CREATED) AS PrimerCreated,
        MAX(CREATED) AS UltimoCreated
 FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG WHERE ROW_ID LIKE @RowIdPatron
 GROUP BY QUEUE_NAME ORDER BY QUEUE_NAME;
 INSERT @Origen
 SELECT TOP(100) ROW_ID,CREATED,PROCESSED,STATUS,REFERENCE,XML_CONTENT,'ROW_ID + XML'
 FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
 WHERE ROW_ID LIKE @RowIdPatron
   AND QUEUE_NAME='Invoice'
   AND XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                         'varchar(50)')=@Referencia
 ORDER BY CREATED DESC;
END;
IF NOT EXISTS(SELECT 1 FROM @Origen)
BEGIN
 INSERT @Origen
 SELECT TOP(100) ROW_ID,CREATED,PROCESSED,STATUS,REFERENCE,XML_CONTENT,'REFERENCE'
 FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
 WHERE QUEUE_NAME='Invoice' AND REFERENCE=@Referencia ORDER BY CREATED DESC;

-- DOCNUM puede no existir en otras versiones del esquema. SQL dinamico evita
-- compilar su referencia si esa columna no esta instalada.
IF NOT EXISTS(SELECT 1 FROM @Origen)
   AND COL_LENGTH(N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG',N'DOCNUM') IS NOT NULL
 INSERT @Origen
 EXEC sys.sp_executesql
 N'SELECT TOP(100) ROW_ID,CREATED,PROCESSED,STATUS,REFERENCE,XML_CONTENT,''DOCNUM''
   FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
   WHERE QUEUE_NAME=''Invoice'' AND DOCNUM=@R ORDER BY CREATED DESC;',N'@R varchar(50)',@R=@Referencia;
END;

SELECT ROW_ID,CREATED,PROCESSED,STATUS,REFERENCE,Busqueda,
       Contenido.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                       'varchar(50)') AS DocumentoXML
FROM @Origen ORDER BY CREATED DESC;

;WITH Materiales AS
(
 SELECT O.ROW_ID,
        I.N.value('(ItemNumber/text())[1]','nvarchar(100)') AS ItemNumber,
        D.N.value('(MaterialID/text())[1]','nvarchar(1000)') AS MaterialXML,
        I.N.value('(Quantity/text())[1]','nvarchar(100)') AS CantidadXML,
        I.N.value('(UnitOfMeasure/text())[1]','nvarchar(100)') AS UnidadXML
 FROM @Origen O CROSS APPLY O.Contenido.nodes('/Invoice/Message/ItemData') I(N)
 OUTER APPLY I.N.nodes('ItemID[ObjectIdentification="002"]') D(N)
)
SELECT ROW_ID,ItemNumber,CONVERT(nvarchar(180),MaterialXML) AS MaterialXML,
       LEN(MaterialXML) AS Caracteres,
       CONVERT(varchar(160),CONVERT(varbinary(80),MaterialXML),2) AS MaterialHexUnicode,
       TRY_CONVERT(numeric(38,0),TRIM(MaterialXML)) AS MaterialNumerico,
       CASE WHEN MaterialXML IS NULL THEN N'No hay MaterialID 002'
            WHEN TRIM(MaterialXML)=N'' THEN N'Vacio'
            WHEN TRY_CONVERT(numeric(38,0),TRIM(MaterialXML)) IS NULL
              THEN N'NO convertible: revisar dato'
            ELSE N'Convertible' END AS Diagnostico,
       CantidadXML,UnidadXML
FROM Materiales ORDER BY ROW_ID,ItemNumber;

IF NOT EXISTS(SELECT 1 FROM @Origen)
BEGIN
 SELECT N'No se encontro el documento. La muestra siguiente contiene solo Invoice del prefijo. Si esta vacia, se necesita el ROW_ID exacto de la factura; no usar Payment para diagnosticar este flujo.' AS Aviso;
 IF @RowIdPatron IS NOT NULL
  SELECT TOP(50) ROW_ID,CREATED,QUEUE_NAME,PROCESSED,STATUS,REFERENCE,
         XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                           'varchar(50)') AS DocumentoXML
  FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
  WHERE ROW_ID LIKE @RowIdPatron AND QUEUE_NAME='Invoice' ORDER BY ROW_ID;
END;

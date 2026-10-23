/* Solo lectura. Ejecutar completo en T3QA; no ejecuta el job ni los hijos.
   Busca el ultimo 8114 de INVOICE_TO_FACTURA de hoy; puede indicarse la
   referencia manualmente. Lee materiales del XML, porque el rollback puede
   haber eliminado TMP_DOCUMENT_DETAIL y revertido MX_RECEIVE_MESSAGE_LOG.Reference.
   Si no encuentra por Reference, busca DocumentNumber en los XML de mensajes
   Invoice pendientes dentro de los cinco dias que utiliza RECV_INVOICE.
   Esa busqueda puede leer varios XML; no modifica la cola ni datos de negocio.
*/
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51400,'Seleccionar T3QA.',1;
DECLARE @Referencia varchar(50)=NULL; -- Opcional: pegar REFERENCE del error.
DECLARE @InicioHoy datetime2(0)=CONVERT(date,SYSDATETIME());
DECLARE @InicioRecepcion datetime2(0)=DATEADD(DAY,-5,CONVERT(date,SYSDATETIME()));

IF @Referencia IS NULL
 SELECT TOP(1) @Referencia=REFERENCE
 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
 WHERE CREATED>=@InicioHoy AND SIEBEL_ERROR_CODE='SQL-8114'
   AND QUEUE_NAME='PROC_PREINVOICE_IFC'
   AND SIEBEL_ERROR_MESSAGE LIKE '%INVOICE_TO_FACTURA%'
 ORDER BY CREATED DESC;

SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@Referencia AS ReferenciaEvaluada;
IF @Referencia IS NULL
 THROW 51401,'No se encontro referencia de 8114 hoy. Indicar @Referencia manualmente.',1;

SELECT TOP(20) CREATED,JOB_PID,REFERENCE,SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=@InicioHoy AND REFERENCE=@Referencia
  AND QUEUE_NAME='PROC_PREINVOICE_IFC'
ORDER BY CREATED DESC;

-- Tipos instalados: otras conversiones de la sentencia pueden ser implicitas.
SELECT SCHEMA_NAME(T.schema_id) AS Esquema,T.name AS Tabla,C.column_id,
       C.name AS Columna,TY.name AS Tipo,C.max_length,C.precision,C.scale
FROM sys.tables T JOIN sys.columns C ON C.object_id=T.object_id
JOIN sys.types TY ON TY.user_type_id=C.user_type_id
WHERE T.object_id IN (OBJECT_ID('EAI_OWNER.TMP_DOCUMENT_DETAIL'),
 OBJECT_ID('T3.FACTURA_DETALLE'),OBJECT_ID('T3.MATERIAL'),OBJECT_ID('EAI_OWNER.MX_HASHTABLE'))
ORDER BY Esquema,Tabla,C.column_id;

-- Si queda detalle temporal, mostrar conversion de material sin provocar 8114.
SELECT ReferenceID,ItemID,Material,LEN(Material) AS Caracteres,
       CONVERT(varchar(160),CONVERT(varbinary(80),Material),2) AS MaterialHex,
       TRY_CONVERT(numeric(38,0),TRIM(Material)) AS MaterialNumerico,
       Cantidad,UnidadMedida,Valor_Subt,Valor_IVA,Bonif_Subt,Envio_Subt,Credito_Subt
FROM EAI_OWNER.TMP_DOCUMENT_DETAIL
WHERE ReferenceID=@Referencia;

DECLARE @Mensajes TABLE
 (Row_ID varchar(32) COLLATE DATABASE_DEFAULT,Creado datetime2(0),Contenido xml);
INSERT @Mensajes
SELECT R.ROW_ID,R.CREATED,R.XML_CONTENT
FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG R
WHERE R.QUEUE_NAME='Invoice' AND R.CREATED>@InicioRecepcion
  AND R.REFERENCE=@Referencia;

IF NOT EXISTS(SELECT 1 FROM @Mensajes)
BEGIN
 INSERT @Mensajes
 SELECT R.ROW_ID,R.CREATED,R.XML_CONTENT
 FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG R
 WHERE R.QUEUE_NAME='Invoice' AND R.CREATED>@InicioRecepcion
   AND R.PROCESSED IS NULL
   AND R.XML_CONTENT.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                          'varchar(50)')=@Referencia;
END;

SELECT Row_ID,Creado,
       Contenido.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                       'varchar(50)') AS DocumentoXML
FROM @Mensajes;

;WITH Materiales AS
(
 SELECT M.Row_ID,
        I.N.value('(ItemNumber/text())[1]','nvarchar(100)') AS ItemNumber,
        D.N.value('(MaterialID/text())[1]','nvarchar(1000)') AS MaterialXML,
        I.N.value('(Quantity/text())[1]','nvarchar(100)') AS CantidadXML,
        I.N.value('(UnitOfMeasure/text())[1]','nvarchar(100)') AS UnidadXML
 FROM @Mensajes M CROSS APPLY M.Contenido.nodes('/Invoice/Message/ItemData') I(N)
 OUTER APPLY I.N.nodes('ItemID[ObjectIdentification="002"]') D(N)
)
SELECT Row_ID,ItemNumber,
       -- Mostrar hasta 180 por celda evita el recorte de los errores/exportacion.
       CONVERT(nvarchar(180),MaterialXML) AS MaterialXML,
       LEN(MaterialXML) AS Caracteres,
       CONVERT(varchar(160),CONVERT(varbinary(80),MaterialXML),2) AS MaterialHexUnicode,
       TRY_CONVERT(numeric(38,0),TRIM(MaterialXML)) AS MaterialNumerico,
       CASE WHEN MaterialXML IS NULL THEN N'No existe ItemID 002 / MaterialID'
            WHEN TRIM(MaterialXML)=N'' THEN N'Vacio: revisar semantica Oracle NULL'
            WHEN TRY_CONVERT(numeric(38,0),TRIM(MaterialXML)) IS NULL
              THEN N'NO convertible: candidato al 8114'
            WHEN LEN(MaterialXML)>18 THEN N'Excede 18: revisar truncamiento al cargar temporal'
            ELSE N'Convertible: revisar otras expresiones del detalle' END AS Diagnostico,
       CantidadXML,UnidadXML
FROM Materiales ORDER BY Row_ID,ItemNumber;

IF NOT EXISTS(SELECT 1 FROM @Mensajes)
 SELECT N'No se encontro XML en la ventana. Compartir ROW_ID del mensaje origen o ampliar la ventana de recepcion; no reprocesar desde este script.' AS Aviso;

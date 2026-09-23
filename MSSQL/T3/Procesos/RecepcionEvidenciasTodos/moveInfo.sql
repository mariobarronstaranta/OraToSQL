-- Invocado por truncate_ldr.sql en la misma sesion. No ejecutar aisladamente.
SET NOCOUNT ON;
DECLARE @Cabecera nvarchar(1000)=N'Jefe territorial,Cliente,Sucursal,ID,Fecha de Entrega,Created,Attachments,Comentarios,Folio Ticket,NoSAP,Created By,Modified,Modified By,NoFactura,PedidoSAP,Status,Id,Tienda,Tienda_SF,FolioRecepcion_SF,VolumenTicket,VolumenNota,Volumen_SF,CoincideFolioRecepcion,CoincideTienda,CoincideVolumenNotavsVolumenTicket,CoincideVolumenNotavsVolumenSF,Revisar,Comentarios_comparativa,Refacturacion,FolioRefacturacion,VersionApp,ComentariosEntrega';
SELECT REPLACE(REPLACE(LTRIM(RTRIM(LINEA)),NCHAR(13),N''),NCHAR(65279),N'') AS Linea
INTO #Lineas FROM [$(StageTable)]
WHERE NULLIF(LTRIM(RTRIM(REPLACE(LINEA,NCHAR(13),N''))),N'') IS NOT NULL;
IF (SELECT COUNT_BIG(*) FROM #Lineas WHERE REPLACE(Linea,NCHAR(34),N'') COLLATE Latin1_General_100_BIN2=@Cabecera COLLATE Latin1_General_100_BIN2)<>1
 THROW 51304,'El CSV debe contener una sola cabecera con las 33 columnas esperadas.',1;
DELETE #Lineas WHERE REPLACE(Linea,NCHAR(34),N'') COLLATE Latin1_General_100_BIN2=@Cabecera COLLATE Latin1_General_100_BIN2;
IF NOT EXISTS (SELECT 1 FROM #Lineas) THROW 51305,'El CSV no contiene datos.',1;
IF EXISTS (SELECT 1 FROM #Lineas WHERE LEN(Linea)-LEN(REPLACE(Linea,N',',N''))<>32)
 THROW 51306,'Fila con numero de columnas distinto de 33. Revisar CSV.',1;
CREATE TABLE #Entrada
(
 ITEMINTERNALID varchar(100) NULL, FECHA varchar(100) NULL, TIENDA varchar(100) NULL,
 FOLIO_RECEPCION varchar(100) NULL, VOLUMEN_TICKET varchar(100) NULL,
 VOLUMEN_NOTA varchar(100) NULL, FOLIO_INTERNO varchar(100) NULL,
 COINCIDEVOLUMEN varchar(100) NULL
);
INSERT #Entrada(ITEMINTERNALID,FECHA,TIENDA,FOLIO_RECEPCION,VOLUMEN_TICKET,VOLUMEN_NOTA,FOLIO_INTERNO,COINCIDEVOLUMEN)
SELECT NULLIF(J.C3,N''),NULLIF(J.C4,N''),NULLIF(J.C17,N''),NULLIF(J.C19,N''),
 NULLIF(J.C20,N''),NULLIF(J.C21,N''),NULLIF(J.C13,N''),NULLIF(J.C25,N'')
FROM #Lineas L
CROSS APPLY OPENJSON(N'[["'+REPLACE(STRING_ESCAPE(REPLACE(L.Linea,NCHAR(34),N''),N'json'),N',',N'","')+'"]]')
WITH (C0 nvarchar(100) '$[0]',C1 nvarchar(100) '$[1]',C2 nvarchar(100) '$[2]',C3 nvarchar(100) '$[3]',C4 nvarchar(100) '$[4]',C13 nvarchar(100) '$[13]',C17 nvarchar(100) '$[17]',C19 nvarchar(100) '$[19]',C20 nvarchar(100) '$[20]',C21 nvarchar(100) '$[21]',C25 nvarchar(100) '$[25]') J;
IF EXISTS (SELECT 1 FROM #Entrada WHERE NULLIF(LTRIM(RTRIM(FOLIO_INTERNO)),'') IS NULL OR NULLIF(LTRIM(RTRIM(TIENDA)),'') IS NULL)
 THROW 51307,'Folio interno o tienda vacio.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 TRUNCATE TABLE EAI.LDR_EVIDENCIAS_ENTREGA;
 INSERT EAI.LDR_EVIDENCIAS_ENTREGA(ITEMINTERNALID,FECHA,TIENDA,FOLIO_RECEPCION,VOLUMEN_TICKET,VOLUMEN_NOTA,FOLIO_INTERNO,COINCIDEVOLUMEN)
 SELECT ITEMINTERNALID,FECHA,TIENDA,FOLIO_RECEPCION,TRY_CONVERT(int,VOLUMEN_TICKET),TRY_CONVERT(int,VOLUMEN_NOTA),FOLIO_INTERNO,COINCIDEVOLUMEN FROM #Entrada;
 EXEC EAI.MOVE_EVIDENCIA_ENTREGA;
 COMMIT TRANSACTION;
 SELECT COUNT_BIG(*) AS FilasCSV FROM #Entrada;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
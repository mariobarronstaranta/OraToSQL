/* Solo estas seis facturas. Primero revisar 01 y aplicar la correccion 02.
   @Ejecutar=0 muestra estado y termina. @Ejecutar=1 genera salida por factura.
   Ejecutar con consumidores/jobs detenidos para este alcance.
   No desmarca Fecha_Proc_BATMD ni ejecuta PROC_T3_OT_GENERAL completo.
   El 01B confirmo que las seis ya estan timbradas: deben OMITIRSE, incluso
   sin layout. No ejecutar para generar salidas nuevas de esas referencias.
*/
USE [T3QA]; SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
DECLARE @Ejecutar bit=0;
DECLARE @F table(Factura varchar(30) COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT @F VALUES('1658507150'),('1658507151'),('1658516300'),('1658516520'),('1658520040'),('1658520050');
SELECT F.Factura,
 (SELECT COUNT_BIG(*) FROM T3.OTROS_GENERAL G WHERE G.Factura=F.Factura) Cabeceras,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS D WHERE D.Nota_Venta=F.Factura) Documentos,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR E WHERE E.Nota_Venta=F.Factura) Layouts
FROM @F F;
IF @Ejecutar=0 BEGIN SELECT 'VISTA PREVIA; NO SE REPROCESO NINGUNA FACTURA' Resultado; RETURN; END;
IF @@TRANCOUNT<>0 THROW 53610,'Ejecutar sin transaccion externa.',1;
IF OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')) IS NULL
 OR CHARINDEX('CAST(@Doc_tasa AS DECIMAL(38,12)) / 100.0',
 OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')))=0
 THROW 53611,'Primero aplicar y verificar la correccion del modulo.',1;

DECLARE @Factura varchar(30),@D bigint,@E bigint,@ErroresAntes bigint,@ErroresDespues bigint,
 @DocumentoProtegido bit,
 @MapAntes bigint,@MapDespues bigint,
 @ErrorHijo nvarchar(250),@Msg nvarchar(2048),@Generadas int=0,@Omitidas int=0;
DECLARE Facturas CURSOR LOCAL STATIC READ_ONLY FOR SELECT Factura FROM @F ORDER BY Factura;
BEGIN TRY
 BEGIN TRANSACTION;
 OPEN Facturas; FETCH NEXT FROM Facturas INTO @Factura;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SELECT @D=COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS WITH(UPDLOCK,HOLDLOCK) WHERE Nota_Venta=@Factura;
  SELECT @E=COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR WITH(UPDLOCK,HOLDLOCK) WHERE Nota_Venta=@Factura;
  SET @DocumentoProtegido=CASE WHEN EXISTS(
   SELECT 1 FROM T3.CFDI_DOCUMENTOS WHERE Nota_Venta=@Factura
    AND (NULLIF(LTRIM(RTRIM(Folio_Fiscal)),'') IS NOT NULL
     OR Fecha_Timbre IS NOT NULL OR Fecha_Envio IS NOT NULL
     OR Fecha_Confirmacion IS NOT NULL
     OR NULLIF(LTRIM(RTRIM(Id_Envio)),'') IS NOT NULL
     OR NULLIF(LTRIM(RTRIM(Id_Confirmacion)),'') IS NOT NULL
     OR Status IN ('CONFIRMADO','CANCELLED','CANCELADO','TIMBRADO'))
  ) THEN 1 ELSE 0 END;
  IF @DocumentoProtegido=1
  BEGIN
   SET @Omitidas+=1;
   SELECT @Factura Factura,'DOCUMENTO CON ENVIO/TIMBRADO O ESTADO FINAL; NO SE REGENERO' Resultado;
  END
  ELSE IF @D=1 AND @E=1
  BEGIN
   SET @Omitidas+=1;
   SELECT @Factura Factura,'YA TIENE SALIDA; NO SE REGENERO' Resultado;
  END
  ELSE
  BEGIN
   IF @D<>0 OR @E<>0 THROW 53612,'Salida parcial o duplicada: revisar antes de regenerar.',1;
   IF (SELECT COUNT_BIG(*) FROM T3.OTROS_GENERAL WITH(UPDLOCK,HOLDLOCK) WHERE Factura=@Factura)<>1
    THROW 53613,'Se requiere una sola cabecera para esta factura.',1;
   IF (SELECT COUNT_BIG(*) FROM T3.OTROS_GENERAL G
       JOIN T3.RF_COMPLEMENTO C ON C.Factura=G.Factura
       JOIN EAI.ZSDFE_SOC S ON S.BUKRS=G.Sociedad AND S.KUNNR=G.Sociedad
       LEFT JOIN EAI_OWNER.TMP_DOCUMENT_PARTNERS P ON P.ReferenceID=G.Factura
       WHERE G.Factura=@Factura)<>1
    THROW 53614,'La cabecera del generador tiene coincidencias ausentes o multiples.',1;
   SELECT @ErroresAntes=COUNT_BIG(*) FROM T3.RF_ERROR_LOG
   WHERE Referencia=@Factura AND Rutina IN ('GENERAR_OTROS','PROC_CFDI_GENERAR_OTROS');
   SELECT @MapAntes=COUNT_BIG(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
   WHERE REFERENCE=@Factura AND QUEUE_NAME='GET_SAT_CLAVEPRODUCTO';
   EXEC T3.PROC_V40_GENERAR_OTROS @pFactura=@Factura;
   SELECT @ErroresDespues=COUNT_BIG(*) FROM T3.RF_ERROR_LOG
   WHERE Referencia=@Factura AND Rutina IN ('GENERAR_OTROS','PROC_CFDI_GENERAR_OTROS');
   IF @ErroresDespues<>@ErroresAntes
   BEGIN
    SELECT TOP(1) @ErrorHijo=ERROR_DESC FROM T3.RF_ERROR_LOG
    WHERE Referencia=@Factura AND Rutina IN ('GENERAR_OTROS','PROC_CFDI_GENERAR_OTROS') ORDER BY Fecha DESC;
    SET @Msg=N'El generador registro un error para '+@Factura+N': '+ISNULL(@ErrorHijo,N'consultar mensajes');
    THROW 53615,@Msg,1;
   END;
   SELECT @MapDespues=COUNT_BIG(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
   WHERE REFERENCE=@Factura AND QUEUE_NAME='GET_SAT_CLAVEPRODUCTO';
   IF @MapDespues<>@MapAntes THROW 53617,'El mapeo SAT registro errores; revisar antes de generar salidas.',1;
   IF (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS WHERE Nota_Venta=@Factura)<>1
      OR (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR WHERE Nota_Venta=@Factura)<>1
    THROW 53616,'No se acreditaron las dos salidas esperadas.',1;
   SET @Generadas+=1;
  END;
  FETCH NEXT FROM Facturas INTO @Factura;
 END;
 CLOSE Facturas; DEALLOCATE Facturas;
 COMMIT;
 SELECT 'REPROCESO TERMINADO' Resultado,@Generadas FacturasGeneradas,@Omitidas OmitidasPorSalidaExistente;
END TRY
BEGIN CATCH
 IF CURSOR_STATUS('local','Facturas')>=0 CLOSE Facturas;
 IF CURSOR_STATUS('local','Facturas')>=-1 DEALLOCATE Facturas;
 IF XACT_STATE()<>0 ROLLBACK;
 SELECT @Factura FacturaEnRevision,ERROR_MESSAGE() ErrorReproceso,
  'La transaccion revirtio las salidas nuevas y sus errores internos. Conservar este mensaje.' Observacion;
 THROW;
END CATCH;

SELECT F.Factura,D.Ctro,D.Fecha_Liberacion,D.Status,D.Folio_Fiscal,D.Fecha_Timbre,
 DATALENGTH(E.Informacion) BytesLayout
FROM @F F JOIN T3.CFDI_DOCUMENTOS D ON D.Nota_Venta=F.Factura
JOIN T3.CFDI_DOCUMENTOS_ENVIAR E ON E.Nota_Venta=F.Factura;

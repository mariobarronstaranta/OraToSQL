/*
  SOLO LECTURA de negocio. No llama RECV_PAYMENT, EOD, preparador ni liberador.
  Ejecutar completo en T3QA; guardar Resultados y Mensajes.

  FechaPago = fecha de compensacion/contabilizacion del XML; NO es BATMD.
  DesdeRecepcion/HastaRecepcion = cuando se cargaron los mensajes a la cola.
  Por defecto se revisan las ultimas 48 horas y hasta 200 mensajes Payment.
  Los limites se aplican ANTES de leer XML/relacionar tablas grandes.
  Es una muestra: cero filas NO demuestra ausencia en todo el historico.
*/
SET NOCOUNT ON;
DECLARE @FechaPago date='20261008', @Ahora datetime2(0)=SYSDATETIME(),
        @MaxMensajes int=200, @MaxRelacion int=2000;
DECLARE @DesdeRecepcion datetime2(0)=DATEADD(day,-2,@Ahora),
        @HastaRecepcion datetime2(0)=DATEADD(second,1,@Ahora),
        @MargenMinutos int=CASE WHEN DATEPART(hour,@Ahora) IN (1,2) THEN 0 ELSE 90 END;

SELECT '01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       @Ahora AS FechaCaptura,@FechaPago AS FechaPagoBuscada,
       @DesdeRecepcion AS DesdeRecepcion,@HastaRecepcion AS HastaRecepcion,
       @MaxMensajes AS MaxMensajes,@MargenMinutos AS MargenCentralMinutos;
IF DB_NAME()<>N'T3QA' THROW 52790,'Seleccionar T3QA, el ambiente de estas corridas.',1;

-- Son indicios de las versiones instaladas; no certifican su logica completa.
SELECT '02_MODULOS' AS Seccion,V.Objeto,O.modify_date,
       CASE WHEN M.definition IS NULL THEN 'NO VISIBLE/AUSENTE'
            ELSE 'DEFINICION VISIBLE' END AS Estado
FROM (VALUES (N'EAI_OWNER.RECV_PAYMENT'),(N'EAI_OWNER.SF_PROC_CENTRAL_PAYMENT'),
 (N'EAI_OWNER.SF_PROC_CENTRAL_EXECUTE'),(N'EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV'),
 (N'T3.PROC_T3_EOD'),(N'T3.PROC_CFDI_PROCESAR_PAGOS'),
 (N'T3.PROC_CFDI_LIBERACION_PAGO')) V(Objeto)
LEFT JOIN sys.objects O ON O.object_id=OBJECT_ID(V.Objeto)
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id;

-- Evitar repetir el recorrido masivo del diagnostico01. Solo continuar si
-- hay accesos iniciales por fecha/clave, activos y sin filtro. FORCESEEK en
-- las relaciones impide sustituir estos accesos por scans de todo el historico.
DECLARE @Accesos TABLE(Objeto sysname,Columna sysname,Disponible bit);
INSERT @Accesos(Objeto,Columna) VALUES
 (N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG',N'CREATED'),
 (N'EAI_OWNER.TMP_ACCOUNT_HEADER',N'IDOCNUMBER'),(N'T3.PAGO',N'PAGO_ID'),
 (N'T3.ASIGNACION_PAGO',N'PAGO_ID'),(N'T3.CFDI_COBRANZA',N'ASIGNACION_ID'),
 (N'T3.CFDI_DOCUMENTOS',N'NOTA_VENTA'),(N'T3.RF_ERROR_LOG',N'REFERENCIA');
UPDATE A SET Disponible=CASE WHEN EXISTS(
 SELECT 1 FROM sys.indexes I
 JOIN sys.index_columns K ON K.object_id=I.object_id AND K.index_id=I.index_id
 JOIN sys.columns C ON C.object_id=K.object_id AND C.column_id=K.column_id
 WHERE I.object_id=OBJECT_ID(A.Objeto) AND I.type IN (1,2)
 AND I.is_disabled=0 AND I.is_hypothetical=0 AND I.has_filter=0
 -- El catalogo y la variable de tabla pueden tener collations distintas.
 -- Homologar ambos textos aqui; son metadatos, no columnas de negocio.
 AND C.name COLLATE DATABASE_DEFAULT=A.Columna COLLATE DATABASE_DEFAULT AND
 (K.key_ordinal=1 OR (A.Objeto=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG'
   AND K.key_ordinal=2 AND EXISTS(
    SELECT 1 FROM sys.index_columns K1 JOIN sys.columns C1
      ON C1.object_id=K1.object_id AND C1.column_id=K1.column_id
    WHERE K1.object_id=I.object_id AND K1.index_id=I.index_id
      AND K1.key_ordinal=1 AND C1.name=N'QUEUE_NAME')))
) THEN 1 ELSE 0 END FROM @Accesos A;
SELECT '03_ACCESOS' AS Seccion,* FROM @Accesos;
IF EXISTS(SELECT 1 FROM @Accesos WHERE Disponible=0)
BEGIN
 SELECT '03_DETENIDO' AS Seccion,N'Enviar metadatos: falta un acceso inicial visible. No se consultaron datos de negocio.' AS Resultado;
 RETURN;
END;

DROP TABLE IF EXISTS #LP06R,#LP06M,#LP06I,#LP06H,#LP06K,#LP06P,#LP06AK,
 #LP06A,#LP06CK,#LP06C,#LP06NK,#LP06D,#LP06EK,#LP06E,#LP06RFC;

RAISERROR('R1: muestra acotada de mensajes Payment recientes.',10,1) WITH NOWAIT;
SELECT TOP(@MaxMensajes+1) R.ROW_ID,R.CREATED,R.PROCESSED,R.STATUS,R.REFERENCE,
 R.XML_CONTENT INTO #LP06R
FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG R WITH(FORCESEEK)
WHERE R.QUEUE_NAME='Payment' AND R.CREATED>=@DesdeRecepcion AND R.CREATED<@HastaRecepcion
ORDER BY R.CREATED DESC OPTION(RECOMPILE);
DECLARE @HayMas bit=CASE WHEN (SELECT COUNT(*) FROM #LP06R)>@MaxMensajes THEN 1 ELSE 0 END;
-- No eliminar por ROW_ID: puede repetirse. La siguiente seleccion acota filas.
SELECT TOP(@MaxMensajes) R.ROW_ID,R.CREATED,R.PROCESSED,R.STATUS,R.REFERENCE,
 SUBSTRING(R.XML_CONTENT.value('(/Payment/Header/Reference/ReferenceID/text())[1]','varchar(100)'),7,10) AS IDocNumber,
 R.XML_CONTENT.value('(/Payment/Message/ZTMDALLOCPAY/ClearingDocumentNumber/text())[1]','varchar(100)') AS ClearingDocNumber,
 R.XML_CONTENT.value('(/Payment/Message/ZTMDALLOCPAY/ClearingDate/text())[1]','varchar(100)') AS ClearingDate,
 R.XML_CONTENT.value('(/Payment/Message/ZTMDALLOCPAY/Postingdate/text())[1]','varchar(100)') AS PostingDate
INTO #LP06M FROM #LP06R R ORDER BY R.CREATED DESC;
SELECT '04_MUESTRA_RECEPCION' AS Seccion,COUNT(*) AS MensajesMuestreados,@HayMas AS HayMasEnVentana,
 SUM(CASE WHEN TRY_CONVERT(date,ClearingDate,112)=@FechaPago OR TRY_CONVERT(date,PostingDate,112)=@FechaPago THEN 1 ELSE 0 END) AS CoincidenFechaXML
FROM #LP06M;
SELECT '04B_FECHAS_XML' AS Seccion,ClearingDate,PostingDate,COUNT(*) AS Mensajes
FROM #LP06M GROUP BY ClearingDate,PostingDate;
DELETE FROM #LP06M WHERE
 ISNULL(TRY_CONVERT(date,ClearingDate,112),'19000101')<>@FechaPago
 AND ISNULL(TRY_CONVERT(date,PostingDate,112),'19000101')<>@FechaPago;
IF NOT EXISTS(SELECT 1 FROM #LP06M)
BEGIN
 SELECT '04_SIN_COINCIDENCIAS' AS Seccion,N'No hay mensajes de esa fecha XML en la muestra reciente. No demuestra ausencia global. Enviar esta salida antes de ampliar el alcance.' AS Resultado;
 RETURN;
END;

-- Heredar collation y longitud de la columna que se buscara en cada tabla.
-- Asi no aplicamos COLLATE/CONVERT a las columnas indexadas de negocio.
SELECT TOP(0) H.IDOCNUMBER INTO #LP06I FROM EAI_OWNER.TMP_ACCOUNT_HEADER H;
INSERT #LP06I SELECT DISTINCT IDocNumber FROM #LP06M WHERE LEN(IDocNumber)>6;
RAISERROR('R2: encabezados por IDoc; no se recorre TMP_ACCOUNT_HEADER por fecha.',10,1) WITH NOWAIT;
SELECT TOP(@MaxRelacion+1) H.IDOCNUMBER,H.CREATED,H.PROCESSED,H.STATUS,H.CLEARINGDOCNUMBER,
 H.CLEARINGDATE,H.POSTINGDATE,H.DC_INDICATOR,H.PAYMENTAMOUNT,H.PAYMETHSUPPLEMENT,H.REFERENCEDOCNUMBER
INTO #LP06H FROM #LP06I K
INNER LOOP JOIN EAI_OWNER.TMP_ACCOUNT_HEADER H WITH(FORCESEEK) ON H.IDOCNUMBER=K.IDOCNUMBER
OPTION(FORCE ORDER,RECOMPILE);
IF (SELECT COUNT(*) FROM #LP06H)>@MaxRelacion
BEGIN
 SELECT '05_DETENIDO_POR_LIMITE' AS Seccion,N'Mas de 2000 encabezados para los IDoc muestreados. Enviar esta salida; no se certifican etapas posteriores.' AS Resultado;
 RETURN;
END;
SELECT '05_RECEPCION' AS Seccion,M.ROW_ID,M.CREATED AS Recepcion,M.PROCESSED AS RecepcionProcesada,
 M.STATUS AS EstadoMensaje,M.IDocNumber,M.ClearingDate,M.PostingDate,
 (SELECT COUNT(*) FROM #LP06H H WHERE H.IDOCNUMBER COLLATE DATABASE_DEFAULT=M.IDocNumber COLLATE DATABASE_DEFAULT) AS Encabezados
FROM #LP06M M ORDER BY M.CREATED,M.ROW_ID;
SELECT '06_INTERMEDIOS' AS Seccion,H.*,
 CASE WHEN H.PROCESSED IS NOT NULL THEN 'YA MARCADO: REVISAR STATUS'
      WHEN H.CREATED IS NULL THEN 'CREATED NULL'
      WHEN H.CREATED>=DATEADD(minute,-@MargenMinutos,@Ahora) THEN 'AUN DENTRO DEL MARGEN'
      WHEN H.CREATED<=CONVERT(date,DATEADD(day,-2,@Ahora)) THEN 'FUERA DE VENTANA EOD DE 2 DIAS'
      WHEN H.CLEARINGDOCNUMBER IS NULL OR H.CLEARINGDOCNUMBER LIKE '11000%' THEN 'COMPENSACION EXCLUIDA'
      WHEN H.PAYMENTAMOUNT IS NULL THEN 'PAYMENTAMOUNT NULL'
      ELSE 'PASA FILTROS BASE CENTRAL; FALTA EVALUAR GRUPO S/H' END AS ObservacionCentral
FROM #LP06H H;
-- Margen/ventana corresponden al codigo del repositorio y a una evaluacion
-- a la hora de captura. No acreditan que EOD haya corrido ni su hora real.

SELECT TOP(0) P.PAGO_ID INTO #LP06K FROM T3.PAGO P;
-- Clave esperada en las rutas centrales ZV/PAYALLOC: anio de 2 digitos
-- tomado del texto ClearingDate + ClearingDocNumber. No es el IDoc.
-- Se conserva la formula del SP; no se inventan filas si faltan esas partes.
INSERT #LP06K SELECT DISTINCT CONCAT(SUBSTRING(M.ClearingDate,3,2),M.ClearingDocNumber)
FROM #LP06M M WHERE LEN(M.ClearingDate)>=4 AND LEN(M.ClearingDocNumber)>0
 AND LEN(M.ClearingDocNumber)<=20;
SELECT TOP(@MaxRelacion+1) P.* INTO #LP06P FROM #LP06K K
INNER LOOP JOIN T3.PAGO P WITH(FORCESEEK) ON P.PAGO_ID=K.PAGO_ID OPTION(FORCE ORDER,RECOMPILE);
SELECT TOP(0) A.PAGO_ID INTO #LP06AK FROM T3.ASIGNACION_PAGO A;
INSERT #LP06AK SELECT PAGO_ID FROM #LP06K;
SELECT TOP(@MaxRelacion+1) A.* INTO #LP06A FROM #LP06AK K
INNER LOOP JOIN T3.ASIGNACION_PAGO A WITH(FORCESEEK) ON A.PAGO_ID=K.PAGO_ID OPTION(FORCE ORDER,RECOMPILE);
IF (SELECT COUNT(*) FROM #LP06P)>@MaxRelacion OR (SELECT COUNT(*) FROM #LP06A)>@MaxRelacion
BEGIN
 SELECT '07_DETENIDO_POR_LIMITE' AS Seccion,N'La relacion de pagos/asignaciones supera 2000 filas. No se consultaron cobranzas.' AS Resultado;
 RETURN;
END;
SELECT '07_PAGOS' AS Seccion,* FROM #LP06P;
SELECT '08_ASIGNACIONES' AS Seccion,A.*,
 CASE WHEN A.FECHA_PROC_BATMD IS NULL THEN 'SIN FECHA BATMD: NO ENTRA AL PREPARADOR POR FECHA'
      ELSE 'USAR ESTA FECHA BATMD PARA ANALIZAR EL PREPARADOR; NO REEJECUTAR AUN' END AS Observacion
FROM #LP06A A;

SELECT TOP(0) C.ASIGNACION_ID INTO #LP06CK FROM T3.CFDI_COBRANZA C;
INSERT #LP06CK SELECT DISTINCT A.ASIGNACION_ID FROM #LP06A A
 WHERE A.ASIGNACION_ID IS NOT NULL AND DATALENGTH(A.ASIGNACION_ID)<=30;
SELECT '08B_CLAVES_LARGAS' AS Seccion,ASIGNACION_ID,DATALENGTH(ASIGNACION_ID) AS Bytes
FROM #LP06A WHERE DATALENGTH(ASIGNACION_ID)>30;
RAISERROR('R3: cobranzas y motivos de exclusion para las asignaciones de la muestra.',10,1) WITH NOWAIT;
SELECT TOP(@MaxRelacion+1) C.* INTO #LP06C FROM #LP06CK K
INNER LOOP JOIN T3.CFDI_COBRANZA C WITH(FORCESEEK) ON C.ASIGNACION_ID=K.ASIGNACION_ID
OPTION(FORCE ORDER,RECOMPILE);
IF (SELECT COUNT(*) FROM #LP06C)>@MaxRelacion
BEGIN
 SELECT '09_DETENIDO_POR_LIMITE' AS Seccion,N'Mas de 2000 cobranzas: enviar salida antes de ampliar. No se evaluaron los filtros restantes.' AS Resultado;
 RETURN;
END;
SELECT TOP(0) D.NOTA_VENTA INTO #LP06NK FROM T3.CFDI_DOCUMENTOS D;
INSERT #LP06NK SELECT DISTINCT NOTA_VENTA FROM #LP06C WHERE NOTA_VENTA IS NOT NULL;
SELECT TOP(@MaxRelacion+1) D.NOTA_VENTA,D.METODO_PAGO,D.STATUS,D.FOLIO_FISCAL
INTO #LP06D FROM #LP06NK K
INNER LOOP JOIN T3.CFDI_DOCUMENTOS D WITH(FORCESEEK) ON D.NOTA_VENTA=K.NOTA_VENTA
OPTION(FORCE ORDER,RECOMPILE);
SELECT TOP(0) E.REFERENCIA INTO #LP06EK FROM T3.RF_ERROR_LOG E;
INSERT #LP06EK SELECT ASIGNACION_ID FROM #LP06C WHERE ASIGNACION_ID IS NOT NULL
UNION SELECT FOLIO_ID FROM #LP06C WHERE FOLIO_ID IS NOT NULL;
SELECT TOP(@MaxRelacion+1) E.* INTO #LP06E FROM #LP06EK K
INNER LOOP JOIN T3.RF_ERROR_LOG E WITH(FORCESEEK) ON E.REFERENCIA=K.REFERENCIA
WHERE E.RUTINA LIKE '%GENERAR_PAGO%' OPTION(FORCE ORDER,RECOMPILE);
IF (SELECT COUNT(*) FROM #LP06D)>@MaxRelacion OR (SELECT COUNT(*) FROM #LP06E)>@MaxRelacion
BEGIN
 SELECT '09B_DETENIDO_POR_LIMITE' AS Seccion,N'Mas de 2000 documentos/errores relacionados. No se emite elegibilidad con informacion incompleta.' AS Resultado;
 RETURN;
END;
SELECT DISTINCT RFC,CONVERT(int,NULL) AS Retorno INTO #LP06RFC FROM #LP06C WHERE RFC IS NOT NULL;
IF OBJECT_ID(N'T3.FN_VALIDA_RFC') IS NULL
BEGIN
 SELECT '09C_DETENIDO_FUNCION' AS Seccion,N'FN_VALIDA_RFC no visible. No se sustituyo su regla por una validacion inventada.' AS Resultado;
 RETURN;
END;
EXEC sys.sp_executesql N'UPDATE #LP06RFC SET Retorno=T3.FN_VALIDA_RFC(RFC);';

SELECT '09_FILTROS_LIBERADOR' AS Seccion,C.ASIGNACION_ID,C.FOLIO_ID,C.FACTURA,C.NOTA_VENTA,
 C.FECHA_PAGO,C.FECHA_PROC_BATMD,C.FECHA_PROCESO,C.FECHA_ENVIO,C.VIA_PAGO,
 C.STATUS,C.CREATED_BY,C.UUID_VENTA,C.RFC,R.Retorno AS RetornoValidaRFC,
 D.DocumentosRelacionados,D.DocumentosNoPUE,
 CASE WHEN C.FECHA_ENVIO IS NULL THEN 0 ELSE 1 END AS ExcluyeYaEnviado,
 CASE WHEN C.VIA_PAGO='01' THEN 0 ELSE 1 END AS ExcluyeVia,
 CASE WHEN C.UUID_VENTA IS NULL THEN 1 ELSE 0 END AS ExcluyeUUID,
 CASE WHEN C.CREATED_BY<>'INTERFACE' THEN 0 ELSE 1 END AS ExcluyeCreatedBy,
 CASE WHEN C.FECHA_PAGO>='20200921' THEN 0 ELSE 1 END AS ExcluyeFechaPago,
 CASE WHEN ISNULL(C.STATUS,'EMPTY') IN ('PendienteT3','Canc Pago') THEN 1 ELSE 0 END AS ExcluyeStatus,
 CASE WHEN R.Retorno>0 THEN 0 ELSE 1 END AS ExcluyeRFC,
 CASE WHEN D.DocumentosNoPUE>0 THEN 0 ELSE 1 END AS ExcluyeDocumento,
 CASE WHEN EXISTS(SELECT 1 FROM #LP06E E WHERE E.REFERENCIA COLLATE DATABASE_DEFAULT=C.ASIGNACION_ID COLLATE DATABASE_DEFAULT) THEN 1 ELSE 0 END AS ExcluyeBitacora
FROM #LP06C C LEFT JOIN #LP06RFC R ON C.RFC=R.RFC
OUTER APPLY(SELECT COUNT(*) AS DocumentosRelacionados,
 COUNT(CASE WHEN X.METODO_PAGO<>'PUE' THEN 1 END) AS DocumentosNoPUE
 FROM #LP06D X WHERE X.NOTA_VENTA COLLATE DATABASE_DEFAULT=C.NOTA_VENTA COLLATE DATABASE_DEFAULT) D;
SELECT '10_ERRORES_RELACIONADOS' AS Seccion,* FROM #LP06E;
SELECT '11_RESUMEN_MUESTRA' AS Seccion,(SELECT COUNT(*) FROM #LP06M) AS MensajesFechaXML,
 (SELECT COUNT(*) FROM #LP06H) AS Encabezados,(SELECT COUNT(*) FROM #LP06K) AS ClavesEsperadas,
 (SELECT COUNT(*) FROM #LP06P) AS Pagos,(SELECT COUNT(*) FROM #LP06A) AS Asignaciones,
 (SELECT COUNT(*) FROM #LP06C) AS Cobranzas;
SELECT '12_ALCANCE' AS Seccion,
 N'Muestra de mensajes recientes con ClearingDate O PostingDate del 08/10/2026; no es el universo de pagos de ese dia. '
 +N'Las claves se derivan con la formula central ZV/PAYALLOC; otras rutas requieren otra conciliacion. '
 +N'Los flags de exclusion pueden coincidir. Version CFDI y datos fiscales del generador se revisan despues de localizar candidatos. '
 +N'No se ejecuto ningun proceso de negocio; no repetir EOD, el preparador ni el liberador solo para forzar filas.' AS Resultado;

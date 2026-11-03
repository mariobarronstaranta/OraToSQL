/*
  Sustituye al diagnostico exhaustivo 01 para la siguiente captura.
  SOLO MUESTRA de hasta 100 filas preseleccionadas; no certifica todo el lote.
  Solo lectura/temporales. No ejecuta SP de negocio, no consume secuencias.
  El TOP se aplica antes de validar RFC y leer relaciones. Se inspeccionan
  accesos por metadatos antes de consultar tablas grandes. Sin calculo fiscal.
  TOP no garantiza un tiempo maximo: enviar la ultima etapa si se demora.
*/
SET NOCOUNT ON;
DECLARE @MaxDetalle int=100;
DECLARE @MaxMuestra int=100;
SELECT '01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,ORIGINAL_LOGIN() AS LoginOriginal,
       SUSER_SNAME() AS LoginActual,USER_NAME() AS UsuarioBase,@@TRANCOUNT AS TranCount,
       D.compatibility_level,D.collation_name
FROM sys.databases D WHERE D.database_id=DB_ID();

DECLARE @Objetos table(Nombre nvarchar(256) COLLATE DATABASE_DEFAULT,Clase varchar(12),Id int);
INSERT @Objetos(Nombre,Clase) VALUES
 (N'T3.PROC_CFDI_LIBERACION_PAGO','SP'),(N'T3.PROC_V20_GENERAR_PAGO','SP'),
 (N'EAI_OWNER.LOG_START','SP'),(N'EAI_OWNER.GETCONV','FUNCION'),
 (N'T3.FN_VALIDA_RFC','FUNCION'),(N'T3.FN_TRIM_CFDI','FUNCION'),
 (N'T3.FN_ADJUST_GMT','FUNCION'),(N'T3.FN_NUM_TO_CHAR_CFDI','FUNCION'),
 (N'EAI_OWNER.ProcessID','SECUENCIA'),
 (N'T3.CFDI_COBRANZA','TABLA'),(N'T3.CFDI_DOCUMENTOS','TABLA'),
 (N'T3.CFDI_DOCUMENTOS_ENVIAR','TABLA'),(N'T3.CFDI_RFC_SETTING','TABLA'),
 (N'T3.CFDI_REPROCESO','TABLA'),(N'T3.CFDI_USOCFDI_CLIENTE','TABLA'),
 (N'T3.DISTRIBUIDOR_FISCAL','TABLA'),(N'T3.MOV_CLIENTE','TABLA'),
 (N'T3.TMD_EMAIL','TABLA'),(N'T3.REGISTRO_FISCAL','TABLA'),
 (N'T3.REGISTRO_FISCAL_DETALLE','TABLA'),(N'EAI.ZSDFE_SOC','TABLA'),
 (N'T3.RF_PROCESOS_LOG','TABLA'),(N'T3.RF_ERROR_LOG','TABLA'),
 (N'EAI_OWNER.MX_COMPONENTS','TABLA'),(N'EAI_OWNER.MX_HASHTABLE','TABLA'),
 (N'EAI_OWNER.MX_EAI_MESSAGE_LOG','TABLA');
UPDATE @Objetos SET Id=OBJECT_ID(Nombre);
SELECT '02_OBJETOS' AS Seccion,X.Nombre,X.Clase,O.type_desc,
       CASE WHEN X.Id IS NULL THEN N'NO VISIBLE O AUSENTE'
            WHEN X.Clase='FUNCION' AND O.type NOT IN('FN','FS') THEN N'REVISAR TIPO'
            WHEN X.Clase='SP' AND O.type NOT IN('P','PC') THEN N'REVISAR TIPO'
            WHEN X.Clase='TABLA' AND O.type NOT IN('U','V') THEN N'REVISAR TIPO'
            WHEN X.Clase='SECUENCIA' AND O.type<>'SO' THEN N'REVISAR TIPO'
            ELSE N'VISIBLE' END AS Estado,
       O.modify_date,
       HAS_PERMS_BY_NAME(X.Nombre,'OBJECT',CASE WHEN X.Clase IN('SP','FUNCION') THEN 'EXECUTE'
          WHEN X.Clase='SECUENCIA' THEN 'UPDATE' ELSE 'SELECT' END) AS PermisoDirectoSesion,
       CASE WHEN X.Clase IN('SP','FUNCION')
          THEN CONVERT(varchar(64),HASHBYTES('SHA2_256',M.definition),2) END AS HashDefinicion
FROM @Objetos X LEFT JOIN sys.objects O ON O.object_id=X.Id
LEFT JOIN sys.sql_modules M ON M.object_id=X.Id ORDER BY X.Clase,X.Nombre;
-- Permiso directo=0 no prueba fallo dentro del SP: puede existir cadena de
-- propiedad. Esta consulta no concede permisos ni simula otro login.

SELECT '03_FIRMAS' AS Seccion,X.Nombre,P.parameter_id,P.name,TYPE_NAME(P.user_type_id) AS Tipo,
       P.max_length,P.precision,P.scale,P.is_output
FROM @Objetos X INNER JOIN sys.parameters P ON P.object_id=X.Id
WHERE X.Clase IN('SP','FUNCION') ORDER BY X.Nombre,P.parameter_id;

DECLARE @Generador nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'T3.PROC_V20_GENERAR_PAGO'));
DECLARE @Normal nvarchar(max)=UPPER(REPLACE(REPLACE(REPLACE(REPLACE(@Generador,
 N' ',N''),CHAR(9),N''),CHAR(10),N''),CHAR(13),N''));
DECLARE @FacturaCorta bit=CASE WHEN @Normal IS NULL THEN NULL
 WHEN CHARINDEX(N'DECLARE@SFACTURAPAGADAVARCHAR(4)',@Normal)>0 THEN 1 ELSE 0 END;
SELECT '04_CODIGO_GENERADOR' AS Seccion,@FacturaCorta AS DeclaraFacturaPagadaVarchar4,
       CASE WHEN @Generador IS NULL THEN N'Definicion no visible; no se certifica el codigo.'
       WHEN @FacturaCorta=1 THEN N'Riesgo de truncar la factura usada para consultar impuestos. Revisar facturas de la muestra en 12.'
       ELSE N'No aparece la declaracion corta conocida; validar version/definicion.' END AS Resultado;
SELECT '04B_SECUENCIA_SIN_CONSUMIR' AS Seccion,S.name,S.current_value,S.last_used_value,S.start_value,
       S.increment,S.minimum_value,S.maximum_value,S.is_exhausted,
       N'Lectura de metadatos. No reserva PID; revisar limite NUMERIC(8,0) del coordinador.' AS Observacion
FROM sys.sequences S WHERE S.object_id=OBJECT_ID(N'EAI_OWNER.ProcessID');

IF EXISTS(SELECT 1 FROM @Objetos X LEFT JOIN sys.objects O ON O.object_id=X.Id
 WHERE X.Id IS NULL OR (X.Clase='FUNCION' AND O.type NOT IN('FN','FS'))
 OR (X.Clase='SP' AND O.type NOT IN('P','PC')) OR (X.Clase='TABLA' AND O.type NOT IN('U','V'))
 OR (X.Clase='SECUENCIA' AND O.type<>'SO'))
BEGIN
 SELECT '05_DIAGNOSTICO_DETENIDO' AS Seccion,
 N'Faltan objetos visibles o su tipo requiere revision. Enviar resultados; no ejecutar el SP aun.' AS Resultado;
 RETURN;
END;

-- La fase de datos se compila solo despues de revisar las dependencias.
-- Esto permite reportar una funcion ausente sin fallar al compilar su llamada.
BEGIN TRY
 EXEC sys.sp_executesql N'-- Solo metadatos: evitar relaciones contra tablas grandes sin un acceso
-- inicial visible. Esto no fuerza ni acredita el plan que elegira SQL Server.
DECLARE @Accesos table(Tabla nvarchar(256) COLLATE DATABASE_DEFAULT,
 Columna sysname COLLATE DATABASE_DEFAULT,Id int,FilasAprox bigint,Acceso bit);
INSERT @Accesos(Tabla,Columna) VALUES
 (N''T3.CFDI_COBRANZA'',N''FECHA_ENVIO''),(N''T3.CFDI_COBRANZA'',N''ASIGNACION_ID''),
 (N''T3.CFDI_DOCUMENTOS'',N''NOTA_VENTA''),(N''T3.CFDI_DOCUMENTOS_ENVIAR'',N''NOTA_VENTA''),
 (N''T3.MOV_CLIENTE'',N''CLIENTE_SAP''),(N''T3.TMD_EMAIL'',N''CLIENTE_SAP''),
 (N''T3.CFDI_USOCFDI_CLIENTE'',N''CLIENTE_SAP''),(N''T3.RF_ERROR_LOG'',N''REFERENCIA'');
UPDATE @Accesos SET Id=OBJECT_ID(Tabla);
UPDATE A SET FilasAprox=P.N FROM @Accesos A
OUTER APPLY(SELECT SUM(row_count) AS N FROM sys.dm_db_partition_stats
 WHERE object_id=A.Id AND index_id IN(0,1)) P;
UPDATE A SET Acceso=CASE WHEN EXISTS(
 SELECT 1 FROM sys.indexes I INNER JOIN sys.index_columns IC
  ON IC.object_id=I.object_id AND IC.index_id=I.index_id
 INNER JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
 WHERE I.object_id=A.Id AND I.type IN(1,2) AND I.is_disabled=0 AND I.is_hypothetical=0
 AND I.has_filter=0 AND IC.key_ordinal=1
 AND (C.name COLLATE DATABASE_DEFAULT=A.Columna OR
 (A.Tabla=N''T3.CFDI_COBRANZA'' AND A.Columna=N''FECHA_ENVIO'' AND C.name=N''VIA_PAGO'')))
 THEN 1 ELSE 0 END FROM @Accesos A;
SELECT ''05G_ACCESOS_MUESTRA'' AS Seccion,Tabla,Columna,FilasAprox,Acceso,
 CASE WHEN Acceso=1 THEN N''ACCESO DISPONIBLE; NO PLAN FORZADO''
 WHEN FilasAprox<=50000 THEN N''TABLA PEQUENA SEGUN METADATOS''
 ELSE N''REVISAR ANTES DE LEER'' END AS Estado FROM @Accesos;
IF EXISTS(SELECT 1 FROM @Accesos WHERE Acceso=0 AND (FilasAprox>50000 OR FilasAprox IS NULL))
BEGIN
 SELECT ''05G_DETENIDO'' AS Seccion,
 N''No se continua: falta acceso inicial reconocido en una tabla grande o no se pudo estimar su tamano. Enviar metadatos; no crea indices.'' AS Resultado;
 RETURN;
END;
RAISERROR(N''Modo muestra: validacion por etapas, sin calculo fiscal completo.'',10,1) WITH NOWAIT;

-- Fuente de mantenimiento: embebido en 01_VALIDAR_PRECONDICIONES.sql.
-- No ejecutar por separado; requiere @MaxDetalle y @FacturaCorta del wrapper.
SELECT ''05_COMPONENTE'' AS Seccion,Component,Name,Description,Status,Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component=613;
SELECT TOP(5) ''05B_ULTIMAS_CORRIDAS'' AS Seccion,PID,INICIO,FIN,PROCESO_1
FROM T3.RF_PROCESOS_LOG WHERE PROCESO=613 ORDER BY INICIO DESC;

SELECT K.Valor AS Clave,COUNT(H.[Source]) AS FilasConfiguracion,MAX(H.[Target]) AS TargetObservado,
       EAI_OWNER.GETCONV(''CFG Settings'',K.Valor) AS ValorQueDevuelveGETCONV
INTO #Config
FROM(VALUES(''VersionCFDI''),(''Regimen Fiscal''),(''Regimen Fiscal Cliente''),
 (''UsoCFDI_Payment''),(''UsoCFDI_Comercial''),(''Payment Default Time''),(''Metodo Pago'')) K(Valor)
LEFT JOIN EAI_OWNER.MX_HASHTABLE H ON H.[Type]=''CFG Settings'' AND H.[Source]=K.Valor
GROUP BY K.Valor;
SELECT ''06_CONFIG_GENERAL'' AS Seccion,*,
 CASE WHEN FilasConfiguracion=0 THEN N''SIN MAPEO: GETCONV conserva la clave''
      WHEN FilasConfiguracion>1 THEN N''DUPLICADO: TOP(1) de GETCONV no tiene orden''
      WHEN ValorQueDevuelveGETCONV IS NULL THEN N''TARGET NULL'' ELSE N''REVISAR VALOR'' END AS Estado
FROM #Config;

-- Muestra de filas que pasan los filtros baratos, sin buscar UUID/RFC por fila
-- en tablas grandes. TOP limita ANTES de ejecutar funciones o JOIN adicionales.
RAISERROR(N''Etapa M1: obtener hasta %d cobranzas para la muestra.'',10,1,@MaxMuestra) WITH NOWAIT;
SELECT TOP(@MaxMuestra) IDENTITY(int,1,1) AS Fila,
 C.Asignacion_ID,C.Folio_ID,C.Factura,C.Nota_Venta,C.RFC,C.Cliente_SAP,
 C.Ctro,C.Sociedad,C.Importe,C.Saldo_Anterior,C.Numero_Pago,C.Fecha_Pago,
 C.Fecha_Factura,C.Fecha_Asignacion,C.Fecha_Proc_BATMD,C.Fecha_Proceso,
 C.Created_By,C.Status,C.UUID_Venta
INTO #Muestra
FROM T3.CFDI_COBRANZA C
WHERE C.Fecha_Envio IS NULL AND C.Via_Pago=''01''
 AND C.UUID_Venta IS NOT NULL AND C.Created_By<>''INTERFACE''
 AND C.Fecha_Pago>=''20200921'' AND ISNULL(C.Status,''EMPTY'') NOT IN(''PendienteT3'',''Canc Pago'');
SELECT ''05M_ALCANCE_MUESTRA'' AS Seccion,@MaxMuestra AS Limite,
 (SELECT COUNT_BIG(*) FROM #Muestra) AS FilasPreseleccionadas,
 N''Muestra sin orden; no es conteo global ni garantiza todas las asignaciones elegibles.'' AS Alcance;

RAISERROR(N''Etapa M2: validar cada RFC distinto una vez y reutilizar la configuracion.'',10,1) WITH NOWAIT;
SELECT DISTINCT RFC INTO #RFCs FROM #Muestra;
SELECT RFC,T3.FN_VALIDA_RFC(RFC) AS ValidacionRFC INTO #RFCValidado FROM #RFCs;
DECLARE @VersionGeneral varchar(99);
SELECT @VersionGeneral=ValorQueDevuelveGETCONV FROM #Config WHERE Clave=''VersionCFDI'';
SELECT S.RFC,MAX(S.Valor) AS VerCFD INTO #VersionRFC
FROM T3.CFDI_RFC_SETTING S INNER JOIN #RFCs R ON R.RFC=S.RFC
WHERE S.Parametro=''VersionCFDI'' GROUP BY S.RFC;

RAISERROR(N''Etapa M3: obtener documentos de las notas de la muestra.'',10,1) WITH NOWAIT;
SELECT DISTINCT Nota_Venta INTO #Notas FROM #Muestra;
SELECT D.Nota_Venta,COUNT_BIG(*) AS Documentos,
 SUM(CASE WHEN D.Metodo_Pago<>''PUE'' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS DocumentosNoPUE
INTO #DocumentosMuestra FROM T3.CFDI_DOCUMENTOS D
INNER JOIN #Notas N ON N.Nota_Venta=D.Nota_Venta GROUP BY D.Nota_Venta;

RAISERROR(N''Etapa M4: materializar una vez las referencias de error y armar candidatos de la muestra.'',10,1) WITH NOWAIT;
-- Mantener el conjunto global de referencias no NULL conserva incluso la
-- semantica de NOT IN con Asignacion_ID NULL. Se lee una sola vez.
SELECT DISTINCT Referencia INTO #ReferenciasError FROM T3.RF_ERROR_LOG
WHERE Referencia IS NOT NULL AND RUTINA LIKE ''%GENERAR_PAGO%'';
SELECT C.*,R.ValidacionRFC,ISNULL(V.VerCFD,@VersionGeneral) AS VersionCFD,
 CAST(1 AS int) AS PasaUUID,CAST(1 AS int) AS PasaOrigen,
 CAST(1 AS int) AS PasaFecha,CAST(1 AS int) AS PasaStatus,
 CASE WHEN C.Asignacion_ID NOT IN(SELECT Referencia FROM #ReferenciasError) THEN 1 ELSE 0 END AS PasaBitacora,
 ISNULL(D.Documentos,0) AS Documentos,D.DocumentosNoPUE
INTO #Base FROM #Muestra C LEFT JOIN #RFCValidado R
 ON R.RFC=C.RFC OR (R.RFC IS NULL AND C.RFC IS NULL)
LEFT JOIN #VersionRFC V ON V.RFC=C.RFC
LEFT JOIN #DocumentosMuestra D ON D.Nota_Venta=C.Nota_Venta;

-- Mantener la multiplicidad del cursor: no usar DISTINCT aqui.
SELECT B.*,D.Metodo_Pago AS MetodoDocumento,D.Status AS StatusDocumento
INTO #Candidatos
FROM #Base B INNER JOIN T3.CFDI_DOCUMENTOS D ON D.Nota_Venta=B.Nota_Venta
WHERE B.PasaUUID=1 AND B.PasaOrigen=1 AND B.PasaFecha=1 AND B.PasaStatus=1
 AND B.ValidacionRFC>0 AND B.PasaBitacora=1 AND D.Metodo_Pago<>''PUE'';

SELECT ''07_RESUMEN_MUESTRA'' AS Seccion,
 (SELECT COUNT_BIG(*) FROM #Base) AS CobranzasPreseleccionadasMuestra,
 (SELECT COUNT_BIG(*) FROM #Candidatos) AS FilasDelCursor,
 (SELECT COUNT_BIG(*) FROM #Candidatos WHERE VersionCFD=''4.0'') AS LlamadasVersion40,
 (SELECT COUNT_BIG(*) FROM(SELECT DISTINCT Asignacion_ID FROM #Candidatos WHERE VersionCFD=''4.0'') X) AS AsignacionesVersion40,
 (SELECT COUNT_BIG(*) FROM #Candidatos WHERE VersionCFD<>''4.0'' OR VersionCFD IS NULL) AS FilasSinRamaGeneracion,
 @MaxDetalle AS LimiteSoloParaMostrar;
SELECT ''07B_FILTROS_MUESTRA'' AS Seccion,R.Motivo,COUNT_BIG(*) AS Filas
FROM #Base B CROSS APPLY(VALUES
 (''UUID NULL'',CASE WHEN PasaUUID=0 THEN 1 ELSE 0 END),
 (''Origen INTERFACE o NULL'',CASE WHEN PasaOrigen=0 THEN 1 ELSE 0 END),
 (''Fecha pago anterior al corte o NULL'',CASE WHEN PasaFecha=0 THEN 1 ELSE 0 END),
 (''Status excluido'',CASE WHEN PasaStatus=0 THEN 1 ELSE 0 END),
 (''RFC sin retorno positivo'',CASE WHEN ValidacionRFC<=0 OR ValidacionRFC IS NULL THEN 1 ELSE 0 END),
 (''Referencia excluida por bitacora'',CASE WHEN PasaBitacora=0 THEN 1 ELSE 0 END),
 (''Sin documento no PUE'',CASE WHEN ISNULL(DocumentosNoPUE,0)=0 THEN 1 ELSE 0 END)
) R(Motivo,NoPasa) WHERE R.NoPasa=1 GROUP BY R.Motivo;
-- Una fila puede incumplir varios filtros: estos conteos no se suman.
SELECT TOP(@MaxDetalle) ''08_CANDIDATOS'' AS Seccion,Asignacion_ID,Folio_ID,Factura,RFC,
 Cliente_SAP,Ctro,Sociedad,Fecha_Pago,Importe,Saldo_Anterior,Numero_Pago,VersionCFD,
 MetodoDocumento,Documentos,DocumentosNoPUE
FROM #Candidatos ORDER BY Asignacion_ID,Fila;

SELECT Asignacion_ID,COUNT_BIG(*) AS LlamadasEsperadas
INTO #Claves FROM #Candidatos WHERE VersionCFD=''4.0'' GROUP BY Asignacion_ID;
-- El generador vuelve a leer TODAS las cobranzas de cada Asignacion_ID.
SELECT TOP(1000) C.* INTO #Alcance FROM T3.CFDI_COBRANZA C INNER JOIN #Claves K ON K.Asignacion_ID=C.Asignacion_ID;

IF (SELECT COUNT_BIG(*) FROM #Alcance)>=1000
BEGIN
 SELECT ''08L_LIMITE_ALCANCE'' AS Seccion,N''La muestra alcanza 1000 cobranzas por sus IDs. Detenido antes de sus relaciones; no inferir cabeceras ausentes.'' AS Resultado;
 RETURN;
END;
RAISERROR(N''Etapa M5: revisar cabeceras y datos de las asignaciones de la muestra.'',10,1) WITH NOWAIT;
-- Reproducir los JOIN que alimentan ScrDatos, sin ejecutar funciones de
-- formato ni los calculos de division del generador.
SELECT TOP(2000) A.Asignacion_ID,A.Factura,A.Ctro,A.Sociedad,A.Importe,A.Saldo_Anterior,
 A.Folio_ID,A.Fecha_Asignacion,A.Numero_Pago,M.RFC AS RFCReceptor,
 ISNULL(RS.Valor,M.Nombre) AS NombreReceptor,
 ISNULL(CP.Valor,M.Codigo_Postal_3) AS CPReceptor,M.Codigo_Postal_2 AS CPRemitente,
 S.RFC AS RFCEmisor,S.Razon_Social_HH AS NombreEmisor,
 ISNULL(AL.Codigo_Postal,S.Codigo_Postal) AS CPEmisor,
 DF.Dif_GMT,DF.Ctro AS CentroDistribuidor
INTO #Cabeceras
FROM #Alcance A
INNER JOIN T3.DISTRIBUIDOR_FISCAL DF ON DF.Ctro=A.Ctro
INNER JOIN T3.MOV_CLIENTE M ON M.Cliente_SAP=A.Cliente_SAP
INNER JOIN EAI.ZSDFE_SOC S ON S.BUKRS=A.Sociedad AND ISNULL(S.KUNNR,''NULL'')=A.Sociedad
LEFT JOIN T3.TMD_EMAIL E ON E.Cliente_SAP=M.Cliente_SAP
LEFT JOIN T3.CFDI_USOCFDI_CLIENTE U ON U.Cliente_SAP=M.Cliente_SAP
LEFT JOIN(SELECT RFC,MAX(Valor) AS Valor FROM T3.CFDI_RFC_SETTING WHERE Parametro=''Nombre'' GROUP BY RFC) RS ON RS.RFC=M.RFC
LEFT JOIN(SELECT RFC,MAX(Valor) AS Valor FROM T3.CFDI_RFC_SETTING WHERE Parametro=''CodigoPostal'' GROUP BY RFC) CP ON CP.RFC=M.RFC
LEFT JOIN T3.DISTRIBUIDOR_FISCAL AL ON
 CASE AL.Ctro WHEN ''MX7A'' THEN ''MXAA'' WHEN ''MX7B'' THEN ''MXAB'' WHEN ''MX7D'' THEN ''MXAC'' ELSE AL.Ctro END=A.Ctro
 AND AL.Ctro LIKE ''MX%'';

IF (SELECT COUNT_BIG(*) FROM #Cabeceras)>=2000
BEGIN
 SELECT ''08L_LIMITE_CABECERAS'' AS Seccion,N''Las relaciones alcanzan 2000 cabeceras. Detenido sin diagnosticar ausencias sobre una lista truncada.'' AS Resultado;
 RETURN;
END;
CREATE TABLE #Hallazgos(Nivel varchar(30) COLLATE DATABASE_DEFAULT,Codigo varchar(50) COLLATE DATABASE_DEFAULT,
 Asignacion_ID varchar(50) COLLATE DATABASE_DEFAULT,Factura varchar(50) COLLATE DATABASE_DEFAULT,
 Detalle nvarchar(300) COLLATE DATABASE_DEFAULT);
INSERT #Hallazgos
SELECT ''REVISAR'',''LLAMADAS_REPETIDAS'',Asignacion_ID,NULL,N''El cursor llama mas de una vez al mismo Asignacion_ID.''
FROM #Claves WHERE LlamadasEsperadas>1;
INSERT #Hallazgos
SELECT ''REVISAR'',''COBRANZAS_MULTIPLES'',Asignacion_ID,NULL,N''El generador procesa mas de una fila por asignacion; revisar multiplicidad.''
FROM #Alcance GROUP BY Asignacion_ID HAVING COUNT_BIG(*)>1;
INSERT #Hallazgos
SELECT ''BLOQUEANTE_DATOS'',''SIN_DATOS_CABECERA'',K.Asignacion_ID,NULL,
 N''ScrDatos no obtiene filas: falta relacion de distribuidor, MOV_CLIENTE o sociedad.''
FROM #Claves K WHERE NOT EXISTS(SELECT 1 FROM #Cabeceras H WHERE H.Asignacion_ID=K.Asignacion_ID);
INSERT #Hallazgos
SELECT ''REVISAR'',''JOIN_MULTIPLICA_CABECERAS'',H.Asignacion_ID,NULL,
 N''ScrDatos devuelve mas cabeceras que cobranzas fuente; revisar duplicados en cliente, emisor y relaciones opcionales.''
FROM #Cabeceras H GROUP BY H.Asignacion_ID
HAVING COUNT_BIG(*)>(SELECT COUNT_BIG(*) FROM #Alcance A WHERE A.Asignacion_ID=H.Asignacion_ID);
INSERT #Hallazgos
SELECT DISTINCT ''REVISAR'',''UUID_NO_CONVERTIBLE'',A.Asignacion_ID,A.Factura,
 N''UUID_Venta no convierte a uniqueidentifier. Es comprobacion SQL de forma, no autenticidad ni validacion fiscal.''
FROM #Alcance A WHERE TRY_CONVERT(uniqueidentifier,A.UUID_Venta) IS NULL;
INSERT #Hallazgos
SELECT DISTINCT ''BLOQUEANTE_DATOS'',''FACTURA_SIN_GUION'',A.Asignacion_ID,A.Factura,
 N''CHARINDEX devuelve cero; SUBSTRING con longitud -1 falla al formar la serie.''
FROM #Alcance A WHERE CHARINDEX(''-'',A.Factura)=0;
INSERT #Hallazgos
SELECT DISTINCT ''RIESGO_CODIGO'',''FACTURA_TRUNCADA_A_4'',A.Asignacion_ID,A.Factura,
 N''La declaracion VARCHAR(4) instalada trunca la factura usada por ScrImpuestos.''
FROM #Alcance A WHERE @FacturaCorta=1 AND DATALENGTH(A.Factura)>4;
INSERT #Hallazgos
SELECT DISTINCT ''REVISAR'',''ID_O_FECHA_INCOMPLETOS'',A.Asignacion_ID,A.Factura,
 N''Revisar Factura/Folio_ID/Fecha_Asignacion/Numero_Pago faltantes o vacios.''
FROM #Alcance A WHERE NULLIF(TRIM(A.Factura),'''') IS NULL OR NULLIF(TRIM(A.Folio_ID),'''') IS NULL
 OR A.Fecha_Asignacion IS NULL OR A.Numero_Pago IS NULL;
INSERT #Hallazgos
SELECT DISTINCT ''BLOQUEANTE_DATOS'',''IMPORTE_NO_CABE_EN_STR'',A.Asignacion_ID,A.Factura,
 N''STR(...,12,2) produce asteriscos; el CAST posterior a NUMERIC falla.''
FROM #Alcance A WHERE CHARINDEX(''*'',STR(ISNULL(A.Importe,0),12,2))>0;
INSERT #Hallazgos
SELECT DISTINCT ''BLOQUEANTE_DATOS'',''SALDO_NO_CABE_EN_STR'',A.Asignacion_ID,A.Factura,
 N''STR del saldo anterior/final produce asteriscos; sus CAST a NUMERIC en el layout fallan.''
FROM #Alcance A WHERE CHARINDEX(''*'',STR(ISNULL(A.Saldo_Anterior,0),12,2))>0
 OR CHARINDEX(''*'',STR(ISNULL(A.Saldo_Anterior,0)-ISNULL(A.Importe,0),12,2))>0;
INSERT #Hallazgos
SELECT DISTINCT ''REVISAR'',''RFC_RECEPTOR_REVISAR'',H.Asignacion_ID,H.Factura,
 N''Revisar RFC receptor bruto: longitud o retorno no positivo del validador local. El generador solo exige LEN formateado >10.''
FROM #Cabeceras H WHERE H.RFCReceptor IS NULL OR LEN(TRIM(H.RFCReceptor))<=10
 OR ISNULL(T3.FN_VALIDA_RFC(H.RFCReceptor),0)<=0;
INSERT #Hallazgos
SELECT DISTINCT ''REVISAR'',''DATOS_FISCALES_INCOMPLETOS'',H.Asignacion_ID,H.Factura,
 N''Revisar RFC/nombre emisor o receptor, CP vacio o mayor a cinco caracteres y ajuste GMT.''
FROM #Cabeceras H WHERE NULLIF(TRIM(H.RFCEmisor),'''') IS NULL OR NULLIF(TRIM(H.NombreEmisor),'''') IS NULL
 OR NULLIF(TRIM(H.NombreReceptor),'''') IS NULL OR H.Dif_GMT IS NULL
 OR NULLIF(TRIM(CONVERT(varchar(35),H.CPEmisor)),'''') IS NULL
 OR LEN(CONVERT(varchar(35),H.CPEmisor))>5
 OR NULLIF(TRIM(H.CPReceptor),'''') IS NULL OR LEN(H.CPReceptor)>5
 OR NULLIF(TRIM(H.CPRemitente),'''') IS NULL OR LEN(H.CPRemitente)>5;

SELECT TOP(@MaxDetalle) ''09_RELACIONES_GENERADOR'' AS Seccion,A.Asignacion_ID,A.Factura,A.Cliente_SAP,A.Ctro,A.Sociedad,
 (SELECT COUNT_BIG(*) FROM T3.MOV_CLIENTE M WHERE M.Cliente_SAP=A.Cliente_SAP) AS FilasMovCliente,
 (SELECT COUNT_BIG(*) FROM T3.DISTRIBUIDOR_FISCAL D WHERE D.Ctro=A.Ctro) AS FilasDistribuidor,
 (SELECT COUNT_BIG(*) FROM EAI.ZSDFE_SOC S WHERE S.BUKRS=A.Sociedad AND ISNULL(S.KUNNR,''NULL'')=A.Sociedad) AS FilasSociedad,
 (SELECT COUNT_BIG(*) FROM #Cabeceras H WHERE H.Asignacion_ID=A.Asignacion_ID) AS FilasScrDatosPorAsignacion
FROM #Alcance A ORDER BY A.Asignacion_ID,A.Factura;
SELECT TOP(@MaxDetalle) ''10_BASELINE_ANTES'' AS Seccion,K.Asignacion_ID,K.LlamadasEsperadas,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR E WHERE E.Nota_Venta=K.Asignacion_ID) AS LayoutsAntes,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS D WHERE D.Nota_Venta=K.Asignacion_ID) AS DocumentosAntes,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_COBRANZA C WHERE C.Asignacion_ID=K.Asignacion_ID AND C.Fecha_Envio IS NOT NULL) AS CobranzasMarcadasAntes
FROM #Claves K ORDER BY K.Asignacion_ID;
SELECT ''12_RESUMEN_HALLAZGOS'' AS Seccion,Nivel,Codigo,COUNT_BIG(*) AS Casos
FROM #Hallazgos GROUP BY Nivel,Codigo ORDER BY Nivel,Codigo;
SELECT TOP(@MaxDetalle) ''12B_DETALLE_HALLAZGOS'' AS Seccion,*
FROM #Hallazgos ORDER BY Nivel,Codigo,Asignacion_ID;
SELECT ''13_ALCANCE_MUESTRA'' AS Seccion,
 N''MUESTRA: no es conteo global ni se verifican importes fiscales/impuestos de todo el lote. No ejecuta negocio. ''
 +N''El SP real procesaria TODOS sus candidatos. La muestra no autoriza afirmar que todo el lote esta listo. ''
 +N''Se conserva la multiplicidad de documentos de las notas muestreadas. Si no aparecen candidatos, no se concluye que no existan en el resto.'' AS Resultado;',N'@MaxDetalle int,@MaxMuestra int,@FacturaCorta bit',@MaxDetalle=@MaxDetalle,@MaxMuestra=@MaxMuestra,@FacturaCorta=@FacturaCorta;
END TRY
BEGIN CATCH
 SELECT '99_ERROR_DIAGNOSTICO' AS Seccion,ERROR_NUMBER() AS Numero,ERROR_LINE() AS Linea,ERROR_MESSAGE() AS Mensaje;
 THROW;
END CATCH;
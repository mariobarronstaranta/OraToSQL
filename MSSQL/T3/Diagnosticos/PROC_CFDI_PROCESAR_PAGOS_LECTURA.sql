/* Ejecutar completo en la base real seleccionada en SSMS (sin USE automatico).
   Solo SELECT sobre tablas reales. INSERT solo en variables locales de este lote.
   No ejecuta procedimientos/funciones de negocio, jobs, DDL ni cambios de estado.
   No usa NOLOCK: evitar muestras con lecturas sucias. No es una captura atomica.
   SQL Server 2022: exportacion de definiciones con STRING_SPLIT(...,1).
   Guardar TODOS los resultados como texto/archivo y compartirlos con el proyecto.
*/
SET NOCOUNT ON;

-- Elegir una fecha con asignaciones. NULL busca el ultimo dia de los ultimos 30.
DECLARE @FechaProc date=NULL;
DECLARE @Factura varchar(30)=NULL; -- Opcional: documento problematico concreto.
DECLARE @MaxFacturas int=8,@MaxHistorialPorFactura int=200;
DECLARE @Ahora datetime2(0)=SYSDATETIME(),@Desde date,@Hasta date;

SELECT N'01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
 SYSDATETIMEOFFSET() AS FechaCaptura,D.compatibility_level,D.collation_name,
 D.is_local_cursor_default,D.is_read_committed_snapshot_on,D.snapshot_isolation_state_desc,
 SERVERPROPERTY('ProductVersion') AS VersionSQL,SERVERPROPERTY('Edition') AS Edicion,
 @@LANGUAGE AS Idioma,@@OPTIONS AS OpcionesSesion
FROM sys.databases D WHERE D.database_id=DB_ID();

DECLARE @Objetos table(Nombre nvarchar(256) COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT @Objetos VALUES
 (N'T3.PROC_CFDI_PROCESAR_PAGOS'),(N'T3.FN_TOTAL_FACT'),
 (N'T3.WA_CFDI_COBZA_ASIG_CTRL'),(N'EAI_OWNER.GETCONV'),(N'EAI_OWNER.LOG_START'),
 (N'T3.ASIGNACION_PAGO'),(N'T3.PAGO'),(N'T3.CLIENTE'),(N'T3.REGISTRO_FISCAL'),
 (N'T3.REGISTRO_FISCAL_DETALLE'),(N'T3.TIPO_DOCUMENTO'),(N'T3.CFDI_COBRANZA'),
 (N'T3.FACTURA_GENERAL'),(N'T3.FACTURA_DETALLE'),(N'T3.PREVENTA_GENERAL'),
 (N'T3.PREVENTA_DETALLE'),(N'T3.CFDI_HISTORIA_DOCTO_PAC'),(N'T3.CFDI_DOCUMENTOS'),
 (N'T3.DEBIT_NOTE_IFC'),(N'T3.RF_PROCESOS_LOG'),(N'EAI_OWNER.MX_COMPONENTS'),
 (N'EAI_OWNER.MX_EAI_MESSAGE_LOG'),(N'EAI_OWNER.MX_HashTable'),(N'EAI_OWNER.ProcessID');

SELECT N'02_OBJETOS' AS Seccion,X.Nombre,O.type_desc,O.create_date,O.modify_date,
 M.uses_ansi_nulls,M.uses_quoted_identifier,
 CASE WHEN O.type IN ('P','FN','IF','TF') AND M.definition IS NULL
      THEN N'Definicion no visible: revisar VIEW DEFINITION/cifrado'
      WHEN O.object_id IS NULL THEN N'Objeto no visible o inexistente' ELSE N'Visible' END AS Estado
FROM @Objetos X LEFT JOIN sys.objects O ON O.object_id=OBJECT_ID(X.Nombre)
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id ORDER BY X.Nombre;

SELECT N'03_COLUMNAS' AS Seccion,X.Nombre,C.column_id,C.name AS Columna,
 TYPE_NAME(C.user_type_id) AS Tipo,C.max_length,C.precision,C.scale,C.is_nullable,
 C.collation_name,C.is_identity,C.is_computed
FROM @Objetos X JOIN sys.columns C ON C.object_id=OBJECT_ID(X.Nombre)
ORDER BY X.Nombre,C.column_id;

-- Fragmentos de 180 caracteres para evitar el truncamiento usual de SSMS a 256.
-- Conservar Nombre + Linea + Fragmento para reconstruir los modulos instalados.
;WITH N AS
 (SELECT TOP (2048) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n
  FROM sys.all_objects A CROSS JOIN sys.all_objects B)
SELECT N'04_DEFINICIONES' AS Seccion,X.Nombre,L.ordinal AS Linea,N.n AS Fragmento,
 SUBSTRING(L.value,(N.n-1)*180+1,180) AS Texto
FROM @Objetos X JOIN sys.sql_modules M ON M.object_id=OBJECT_ID(X.Nombre)
CROSS APPLY STRING_SPLIT(REPLACE(M.definition,CHAR(13),N''),CHAR(10),1) L
JOIN N ON N.n<=CASE WHEN LEN(L.value)=0 THEN 1 ELSE (LEN(L.value)+179)/180 END
ORDER BY X.Nombre,L.ordinal,N.n;

SELECT N'05_TRIGGERS' AS Seccion,X.Nombre AS Tabla,T.name AS TriggerNombre,
 T.is_disabled,T.is_instead_of_trigger,T.modify_date
FROM @Objetos X JOIN sys.triggers T ON T.parent_id=OBJECT_ID(X.Nombre)
ORDER BY X.Nombre,T.name;

-- Reproductor de enlace de variables: solo usa un valor constante en memoria.
-- No llama al procedimiento real ni consulta/modifica sus tablas.
DECLARE @Filtro varchar(10),@Resultado varchar(10),@Estado int;
DECLARE LecturaPagos_Antes CURSOR LOCAL FOR
 SELECT V.Id FROM (VALUES('PRUEBA')) V(Id) WHERE V.Id=@Filtro;
SET @Filtro='PRUEBA';
OPEN LecturaPagos_Antes;
FETCH NEXT FROM LecturaPagos_Antes INTO @Resultado;
SET @Estado=@@FETCH_STATUS;
CLOSE LecturaPagos_Antes; DEALLOCATE LecturaPagos_Antes;
SELECT N'06_CURSOR_ANTES_SET' AS Seccion,@Filtro AS FiltroAlAbrir,
 @Resultado AS Resultado,@Estado AS FetchStatus;
SET @Resultado=NULL;
DECLARE LecturaPagos_Despues CURSOR LOCAL FOR
 SELECT V.Id FROM (VALUES('PRUEBA')) V(Id) WHERE V.Id=@Filtro;
OPEN LecturaPagos_Despues;
FETCH NEXT FROM LecturaPagos_Despues INTO @Resultado;
SET @Estado=@@FETCH_STATUS;
CLOSE LecturaPagos_Despues; DEALLOCATE LecturaPagos_Despues;
SELECT N'07_CURSOR_DESPUES_SET' AS Seccion,@Filtro AS FiltroAlAbrir,
 @Resultado AS Resultado,@Estado AS FetchStatus;

IF @FechaProc IS NULL
 SELECT @FechaProc=CAST(MAX(A.Fecha_Proc_BATMD) AS date)
 FROM T3.Asignacion_Pago A
 WHERE A.Fecha_Proc_BATMD>=DATEADD(day,-30,CAST(@Ahora AS date))
   AND A.Fecha_Proc_BATMD<DATEADD(day,1,CAST(@Ahora AS date))
   AND (@Factura IS NULL OR A.Factura=@Factura);
IF @FechaProc IS NULL
BEGIN
 SELECT N'08_SIN_FECHA' AS Seccion,
 N'No hay lote en los ultimos 30 dias. Indicar @FechaProc y volver a ejecutar.' AS Accion;
 RETURN;
END;
SET @Desde=@FechaProc; SET @Hasta=DATEADD(day,1,@Desde);
SELECT N'08_PARAMETROS' AS Seccion,@FechaProc AS FechaProc,@Factura AS FacturaSolicitada,
 @MaxFacturas AS MaxFacturas,@MaxHistorialPorFactura AS MaxHistorialPorFactura;

SELECT N'09_RESUMEN_LOTE' AS Seccion,COUNT_BIG(*) AS Asignaciones,
 COUNT(DISTINCT A.Factura) AS Facturas,MIN(A.Fecha_Proc_BATMD) AS MinFechaBATMD,
 MAX(A.Fecha_Proc_BATMD) AS MaxFechaBATMD,
 SUM(CASE WHEN A.Fecha_Proc_BATMD=CONVERT(datetime2,@Desde) THEN CONVERT(bigint,1) ELSE 0 END) AS ExactamenteMedianoche,
 SUM(CASE WHEN A.Fecha_Asignacion IS NULL THEN CONVERT(bigint,1) ELSE 0 END) AS SinFechaAsignacion
FROM T3.Asignacion_Pago A WHERE A.Fecha_Proc_BATMD>=@Desde AND A.Fecha_Proc_BATMD<@Hasta
 AND (@Factura IS NULL OR A.Factura=@Factura);

DECLARE @Facturas table(Factura varchar(30) COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT @Facturas
SELECT TOP (@MaxFacturas) A.Factura FROM T3.Asignacion_Pago A
WHERE A.Fecha_Proc_BATMD>=@Desde AND A.Fecha_Proc_BATMD<@Hasta AND A.Factura IS NOT NULL
 AND (@Factura IS NULL OR A.Factura=@Factura)
GROUP BY A.Factura ORDER BY COUNT_BIG(*) DESC,A.Factura;

SELECT N'10_MUESTRA' AS Seccion,F.Factura,COUNT_BIG(*) AS AsignacionesDelLote
FROM @Facturas F JOIN T3.Asignacion_Pago A ON A.Factura=F.Factura
WHERE A.Fecha_Proc_BATMD>=@Desde AND A.Fecha_Proc_BATMD<@Hasta
GROUP BY F.Factura ORDER BY F.Factura;

-- Historial acotado por factura. Si se trunca, NO inferir un saldo completo.
DECLARE @Hist table
(Factura varchar(30) COLLATE DATABASE_DEFAULT,Asignacion_ID varchar(50) COLLATE DATABASE_DEFAULT,
 Pago_ID varchar(50) COLLATE DATABASE_DEFAULT,Cliente_SAP varchar(10) COLLATE DATABASE_DEFAULT,
 Nota_Credito varchar(30) COLLATE DATABASE_DEFAULT,Rep_ID varchar(10) COLLATE DATABASE_DEFAULT,
 Ctro varchar(4) COLLATE DATABASE_DEFAULT,Fecha_Asignacion datetime2(0),
 Fecha_Proc_BATMD datetime2(0),Fecha_Trn datetime2(0),Valor_Pago decimal(15,2));
INSERT @Hist
SELECT H.Factura,H.Asignacion_ID,H.Pago_ID,H.Cliente_SAP,H.Nota_Credito,H.Rep_ID,H.Ctro,
 H.Fecha_Asignacion,H.Fecha_Proc_BATMD,H.Fecha_Trn,H.Valor_Pago
FROM @Facturas F CROSS APPLY
 (SELECT TOP (@MaxHistorialPorFactura) A.* FROM T3.Asignacion_Pago A
  WHERE A.Factura=F.Factura
  ORDER BY A.Fecha_Asignacion DESC,A.Asignacion_ID DESC,A.Pago_ID DESC) H;

SELECT N'11_COBERTURA_HISTORIAL' AS Seccion,F.Factura,T.TotalHistorial,
 (SELECT COUNT_BIG(*) FROM @Hist H WHERE H.Factura=F.Factura) AS FilasCapturadas,
 CASE WHEN T.TotalHistorial>@MaxHistorialPorFactura THEN N'TRUNCADO: ampliar para reproducir saldo'
      ELSE N'COMPLETO al momento de la lectura' END AS Cobertura
FROM @Facturas F CROSS APPLY
 (SELECT COUNT_BIG(*) AS TotalHistorial FROM T3.Asignacion_Pago A WHERE A.Factura=F.Factura) T;
SELECT N'12_ASIGNACIONES_HISTORIAL' AS Seccion,H.* FROM @Hist H
ORDER BY H.Factura,H.Fecha_Asignacion,H.Asignacion_ID;

-- Muestra de elegibilidad con DATE frente a la condicion original con hora.
SELECT N'13_VIGENCIA' AS Seccion,H.Factura,H.Asignacion_ID,H.Cliente_SAP,
 H.Fecha_Asignacion,C.Fecha_Ini_Vig,C.Fecha_Fin_Vig,C.Dias_Cdto,C.RFC,
 CASE WHEN H.Fecha_Asignacion BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig THEN 1 ELSE 0 END AS CoincideConHora,
 CASE WHEN CAST(H.Fecha_Asignacion AS date) BETWEEN CAST(C.Fecha_Ini_Vig AS date)
       AND CAST(C.Fecha_Fin_Vig AS date) THEN 1 ELSE 0 END AS CoincideSoloFecha
FROM @Hist H LEFT JOIN T3.Cliente C ON C.Cliente_SAP=H.Cliente_SAP
WHERE H.Fecha_Proc_BATMD>=@Desde AND H.Fecha_Proc_BATMD<@Hasta
ORDER BY H.Factura,H.Asignacion_ID,C.Fecha_Ini_Vig;

SELECT N'14_PAGOS' AS Seccion,P.Pago_ID,P.Fecha_Trn,P.Fecha_Pago,P.Cliente_SAP,
 P.Rep_ID,P.Tipo_Pago,P.Metodo_Pago,P.Valor_Pago,P.Fecha_Proc_BATMD,P.Ctro
FROM T3.Pago P WHERE EXISTS(SELECT 1 FROM @Hist H WHERE H.Pago_ID=P.Pago_ID)
ORDER BY P.Pago_ID;
SELECT N'15_REGISTRO_FISCAL' AS Seccion,R.Factura,R.Tipo_Docto,R.Fecha_Factura
FROM T3.Registro_Fiscal R JOIN @Facturas F ON F.Factura=R.Factura ORDER BY R.Factura;
SELECT N'16_TIPOS' AS Seccion,T.Tipo_Documento,T.Origen
FROM T3.Tipo_Documento T WHERE EXISTS
 (SELECT 1 FROM T3.Registro_Fiscal R JOIN @Facturas F ON F.Factura=R.Factura WHERE R.Tipo_Docto=T.Tipo_Documento);
SELECT N'17_DETALLE_FISCAL' AS Seccion,R.Factura,R.Num_Linea,R.Valor_Subt,R.Valor_IVA,
 R.Envio_Subt,R.Envio_IVA,R.Credito_Subt,R.Credito_IVA
FROM T3.Registro_Fiscal_Detalle R JOIN @Facturas F ON F.Factura=R.Factura
ORDER BY R.Factura,R.Num_Linea;

SELECT N'18_FACTURA_GENERAL' AS Seccion,G.Factura,G.Fecha_Proc_BATMD
FROM T3.Factura_General G JOIN @Facturas F ON F.Factura=G.Factura;
SELECT N'19_FACTURA_DETALLE' AS Seccion,D.Factura,D.Num_Linea,D.Valor_Subt,D.Valor_IVA,
 D.Envio_Subt,D.Envio_IVA,D.Credito_Subt,D.Credito_IVA
FROM T3.Factura_Detalle D JOIN @Facturas F ON F.Factura=D.Factura ORDER BY D.Factura,D.Num_Linea;
DECLARE @Preventas table(Factura varchar(30) COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT @Preventas SELECT DISTINCT G.Factura FROM T3.Preventa_General G
WHERE G.Factura IS NOT NULL AND (EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=G.Factura)
 OR EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=G.Referencia));
SELECT N'20_PREVENTA_GENERAL' AS Seccion,G.Factura,G.Referencia,G.Fecha_Proc_BATMD
FROM T3.Preventa_General G JOIN @Preventas P ON P.Factura=G.Factura;
SELECT N'21_PREVENTA_DETALLE' AS Seccion,D.Factura,D.Num_Linea,D.Valor_Subt,D.Valor_IVA,
 D.Envio_Subt,D.Envio_IVA,D.Credito_Subt,D.Credito_IVA
FROM T3.Preventa_Detalle D JOIN @Preventas P ON P.Factura=D.Factura ORDER BY D.Factura,D.Num_Linea;
SELECT N'22_HISTORIA_PAC' AS Seccion,H.Nota_Venta,H.Nota_Venta_CFDI
FROM T3.CFDI_Historia_Docto_PAC H WHERE EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=H.Nota_Venta)
 OR EXISTS(SELECT 1 FROM @Preventas P WHERE P.Factura=H.Nota_Venta);
SELECT N'23_UUID' AS Seccion,D.Nota_Venta,D.Folio_Fiscal,D.Status
FROM T3.CFDI_Documentos D WHERE EXISTS(SELECT 1 FROM @Preventas P WHERE P.Factura=D.Nota_Venta)
 OR EXISTS(SELECT 1 FROM T3.CFDI_Historia_Docto_PAC H WHERE H.Nota_Venta_CFDI=D.Nota_Venta
 AND (EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=H.Nota_Venta)
 OR EXISTS(SELECT 1 FROM @Preventas P WHERE P.Factura=H.Nota_Venta)));
SELECT N'24_CANCELACIONES' AS Seccion,D.Debit_Note,D.Document_Date,D.Total_Amt
FROM T3.Debit_Note_IFC D JOIN @Facturas F ON F.Factura=D.Debit_Note;

-- Resultado existente, no resultado calculado por ejecutar el procedimiento.
-- Omite cuentas y bancos: no son necesarios para diagnosticar saldo/cursores.
SELECT N'25_COBRANZA_EXISTENTE' AS Seccion,C.Asignacion_ID,C.Folio_ID,C.Factura,C.Pago_ID,
 C.Fecha_Asignacion,C.Fecha_Proc_BATMD,C.Fecha_Proceso,C.Importe,C.Saldo_Anterior,
 C.Numero_Pago,C.Cant_Pagos,C.Abono_Pagos,C.Cant_CM,C.Abono_CM,C.Nota_Credito,
 C.Nota_Venta,C.UUID_Venta,C.Importe_Factura,C.Fecha_Factura,C.Dias_Cdto,C.Tasa_IVA,
 C.Via_Pago,C.Status,C.RFC,C.Asignacion_Central,C.Fecha_Envio,C.Cliente_SAP
FROM T3.CFDI_Cobranza C WHERE EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=C.Factura)
 OR EXISTS(SELECT 1 FROM @Hist H WHERE H.Asignacion_ID=C.Asignacion_ID)
ORDER BY C.Factura,C.Fecha_Asignacion,C.Asignacion_ID;

SELECT N'26_CATALOGOS' AS Seccion,H.Type,H.Source,
 CASE WHEN H.Type='CFG Settings' AND H.Source<>'CompanyCode'
 THEN CASE WHEN H.Target IS NULL THEN NULL ELSE N'VALOR_OMITIDO' END ELSE H.Target END AS Target,
 LEN(H.Target) AS LongitudTarget
FROM EAI_OWNER.MX_HashTable H
WHERE (H.Type='CFG Settings' AND H.Source IN ('CompanyCode','Banco Def - Directo','Cuenta Def - Directo'))
 OR (H.Type IN ('TMD_PAC Accnt Payment Type','TMD_PAC Accnt Payment Method') AND EXISTS
 (SELECT 1 FROM T3.Pago P WHERE P.Metodo_Pago=H.Source COLLATE DATABASE_DEFAULT
  AND EXISTS(SELECT 1 FROM @Hist A WHERE A.Pago_ID=P.Pago_ID)));
SELECT TOP (30) N'27_EJECUCIONES' AS Seccion,L.* FROM T3.RF_PROCESOS_LOG L
WHERE L.Proceso IN (604,889) AND L.Inicio>=DATEADD(day,-7,@Ahora) ORDER BY L.Inicio DESC;
SELECT TOP (50) N'28_ERRORES' AS Seccion,L.CREATED,L.QUEUE_NAME,L.JOB_PID,L.REFERENCE,
 L.SIEBEL_ERROR_CODE,L.SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG L
WHERE L.CREATED>=DATEADD(day,-7,@Ahora)
 AND L.QUEUE_NAME IN ('PROC_CFDI_PROCESAR_PAGOS','WA_CFDI_COBZA_ASIG_CTRL')
ORDER BY L.CREATED DESC;
SELECT N'29_FIN' AS Seccion,SYSDATETIMEOFFSET() AS FechaFin,
 N'Lectura finalizada. Muestra por factura; no prueba ausencia de errores en toda la base.' AS Alcance;

/*
  SOLO LECTURA. Enfocado en el UPDATE que consumio 107.03 s en la corrida
  29/10/2026 00:17 del reporte 01. No ejecuta el SP ni su UPDATE, no consume
  secuencias, no crea indices ni actualiza estadisticas/configuracion.

  Copiar los XML de plan a archivos .sqlplan desde SSMS. Los textos SQL se
  devuelven tambien como XML para evitar el truncamiento de 256 caracteres.
  @MedirVolumenes=0 evita consultas de conteo sobre las tablas grandes.
  La fecha de referencia conserva el corte de la corrida observada; los datos
  actuales pueden haber cambiado y no reconstruyen su estado previo.
*/
USE [T3QA]; SET NOCOUNT ON;
DECLARE @FechaReferencia datetime=CONVERT(datetime,'20261029',112);
DECLARE @nDias numeric(18,0)=30;
DECLARE @MedirVolumenes bit=0;
DECLARE @DesdeQS datetimeoffset='2026-10-28T00:00:00+00:00',
        @HastaQS datetimeoffset='2026-10-31T00:00:00+00:00';
-- Ventana UTC amplia: incluye intervalos alrededor de la corrida, sin asumir
-- la zona horaria historica del servidor. No representa un PID individual.
DECLARE @Objeto int=OBJECT_ID('T3.PROC_CFDI_PROCESA_PAGO_AGR'),
        @Limite date=CAST(DATEADD(DAY,-ISNULL(@nDias,0),@FechaReferencia) AS date);
SELECT '00_CONTEXTO_UPDATE' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,
       SYSDATETIMEOFFSET() CapturaConOffset,@FechaReferencia FechaReferenciaDelServidor,
       @nDias nDias,@Limite LimiteExclusivo,@DesdeQS DesdeQueryStoreUTC,@HastaQS HastaQueryStoreUTC;

-- La version instalada del CHECK ya muestra agregados en el reporte recibido.
-- Obtener ambas definiciones reales antes de proponer sustituciones.
SELECT '01_DEFINICIONES_INSTALADAS' Seccion,O.name,O.modify_date,
       (SELECT M.definition AS [text()] FOR XML PATH('Definicion'),TYPE) DefinicionXML
FROM sys.objects O JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id IN(@Objeto,OBJECT_ID('T3.PROC_CFDI_LIBERA_PAGO_CHECK'));

DECLARE @Cache table(PlanHandle varbinary(64) NULL,Inicio int NULL,Fin int NULL,
    UltimaEjecucion datetime NULL,Ejecuciones bigint NULL,Duracion_ms float NULL,CPU_ms float NULL,
    LecturasLogicas bigint NULL,LecturasFisicas bigint NULL,EscriturasLogicas bigint NULL,
    QueryHash binary(8) NULL,Sentencia nvarchar(max) NULL);
BEGIN TRY
    INSERT @Cache
    SELECT TOP(1) Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset,Q.last_execution_time,
        Q.execution_count,Q.last_elapsed_time/1000.0,Q.last_worker_time/1000.0,
        Q.last_logical_reads,Q.last_physical_reads,Q.last_logical_writes,Q.query_hash,X.Sentencia
    FROM sys.dm_exec_query_stats Q CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T
    CROSS APPLY(SELECT SUBSTRING(T.text,Q.statement_start_offset/2+1,
        (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text) ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1) Sentencia) X
    WHERE T.dbid=DB_ID() AND T.objectid=@Objeto
      AND X.Sentencia LIKE '%UPDATE Cobza%' AND X.Sentencia LIKE '%Asignacion_Central%'
    ORDER BY Q.last_execution_time DESC;
    SELECT '02_METRICAS_UPDATE_EN_CACHE' Seccion,C.UltimaEjecucion,C.Ejecuciones,C.Duracion_ms,C.CPU_ms,
        C.LecturasLogicas,C.LecturasFisicas,C.EscriturasLogicas,
        CONVERT(varchar(18),C.QueryHash,1) QueryHash,
        (SELECT C.Sentencia AS [text()] FOR XML PATH('Sentencia'),TYPE) SentenciaCompletaXML
    FROM @Cache C;
    SELECT '03_PLAN_UPDATE_EN_CACHE_NO_REAL' Seccion,
        TRY_CONVERT(xml,P.query_plan) PlanXML
    FROM @Cache C OUTER APPLY sys.dm_exec_text_query_plan(C.PlanHandle,C.Inicio,C.Fin) P;
    IF NOT EXISTS(SELECT 1 FROM @Cache)
        SELECT '02_CACHE_SIN_UPDATE' Seccion,'No se encontro el UPDATE por este patron; revisar definicion o Query Store. No se ejecuta para poblar cache.' Mensaje;
END TRY
BEGIN CATCH
    SELECT '02_03_CACHE_NO_DISPONIBLE' Seccion,ERROR_NUMBER() Error,ERROR_MESSAGE() Mensaje;
END CATCH;

DECLARE @QS table(QueryId bigint NOT NULL PRIMARY KEY,QueryHash binary(8) NULL,Texto nvarchar(max) NULL);
BEGIN TRY
    SELECT '04_ESTADO_QUERY_STORE' Seccion,actual_state_desc,desired_state_desc,wait_stats_capture_mode_desc
    FROM sys.database_query_store_options;
    INSERT @QS
    SELECT Q.query_id,Q.query_hash,T.query_sql_text
    FROM sys.query_store_query Q JOIN sys.query_store_query_text T ON T.query_text_id=Q.query_text_id
    WHERE Q.object_id=@Objeto AND T.query_sql_text LIKE '%UPDATE Cobza%'
      AND T.query_sql_text LIKE '%Asignacion_Central%';
    SELECT '04_QUERY_IDS_UPDATE' Seccion,Q.QueryId,CONVERT(varchar(18),Q.QueryHash,1) QueryHash,
        (SELECT Q.Texto AS [text()] FOR XML PATH('Sentencia'),TYPE) SentenciaCompletaXML FROM @QS Q;
    SELECT '05_HISTORIA_UPDATE_QUERY_STORE' Seccion,Q.QueryId,P.plan_id,R.execution_type_desc,
        SUM(R.count_executions) EjecucionesEnIntervalos,MAX(R.last_execution_time) UltimaFinalizacion,
        SUM(CONVERT(float,R.count_executions)*R.avg_duration)/1000.0 TiempoTotal_ms,
        SUM(CONVERT(float,R.count_executions)*R.avg_duration)/NULLIF(SUM(R.count_executions),0)/1000.0 Media_ms,
        SUM(CONVERT(float,R.count_executions)*R.avg_cpu_time)/NULLIF(SUM(R.count_executions),0)/1000.0 CPU_media_ms,
        SUM(CONVERT(float,R.count_executions)*R.avg_logical_io_reads)/NULLIF(SUM(R.count_executions),0) LecturasLogicasMedias
    FROM @QS Q JOIN sys.query_store_plan P ON P.query_id=Q.QueryId
    JOIN sys.query_store_runtime_stats R ON R.plan_id=P.plan_id
    JOIN sys.query_store_runtime_stats_interval I ON I.runtime_stats_interval_id=R.runtime_stats_interval_id
    WHERE I.end_time>=@DesdeQS AND I.start_time<@HastaQS
    GROUP BY Q.QueryId,P.plan_id,R.execution_type_desc ORDER BY TiempoTotal_ms DESC;
    SELECT '06_ESPERAS_UPDATE_QUERY_STORE' Seccion,Q.QueryId,W.plan_id,W.execution_type_desc,
        W.wait_category_desc,SUM(W.total_query_wait_time_ms) EsperasAcumuladas_ms
    FROM @QS Q JOIN sys.query_store_plan P ON P.query_id=Q.QueryId
    JOIN sys.query_store_wait_stats W ON W.plan_id=P.plan_id
    JOIN sys.query_store_runtime_stats_interval I ON I.runtime_stats_interval_id=W.runtime_stats_interval_id
    WHERE I.end_time>=@DesdeQS AND I.start_time<@HastaQS
    GROUP BY Q.QueryId,W.plan_id,W.execution_type_desc,W.wait_category_desc
    ORDER BY EsperasAcumuladas_ms DESC;
    SELECT '07_PLANES_HISTORICOS_QUERY_STORE' Seccion,Q.QueryId,P.plan_id,P.is_forced_plan,
        P.last_compile_start_time,TRY_CONVERT(xml,P.query_plan) PlanXML
    FROM @QS Q JOIN sys.query_store_plan P ON P.query_id=Q.QueryId
    WHERE EXISTS(SELECT 1 FROM sys.query_store_runtime_stats R
        JOIN sys.query_store_runtime_stats_interval I ON I.runtime_stats_interval_id=R.runtime_stats_interval_id
        WHERE R.plan_id=P.plan_id AND I.end_time>=@DesdeQS AND I.start_time<@HastaQS);
END TRY
BEGIN CATCH
    SELECT '04_07_QUERY_STORE_NO_DISPONIBLE' Seccion,ERROR_NUMBER() Error,ERROR_MESSAGE() Mensaje;
END CATCH;

-- Confirmar heap/clustered con metadatos, sin escanear paginas fisicas.
SELECT '08_ORGANIZACION_TABLAS' Seccion,OBJECT_SCHEMA_NAME(T.object_id) Esquema,T.name Tabla,
    I.type_desc Organizacion,I.name IndiceBase,
    (SELECT SUM(P.rows) FROM sys.partitions P WHERE P.object_id=T.object_id AND P.index_id=I.index_id) FilasAproximadas
FROM sys.tables T JOIN sys.indexes I ON I.object_id=T.object_id AND I.index_id IN(0,1)
WHERE T.object_id IN(OBJECT_ID('T3.CFDI_COBRANZA'),OBJECT_ID('T3.REGISTRO_FISCAL'),OBJECT_ID('EAI_OWNER.TMP_ACCOUNT_HEADER'));

SELECT '09_ESTADISTICAS_RELEVANTES' Seccion,OBJECT_SCHEMA_NAME(S.object_id) Esquema,
    OBJECT_NAME(S.object_id) Tabla,S.name Estadistica,C.name PrimeraColumna,
    P.last_updated,P.rows,P.rows_sampled,P.modification_counter
FROM sys.stats S JOIN sys.stats_columns SC ON SC.object_id=S.object_id AND SC.stats_id=S.stats_id AND SC.stats_column_id=1
JOIN sys.columns C ON C.object_id=SC.object_id AND C.column_id=SC.column_id
OUTER APPLY sys.dm_db_stats_properties(S.object_id,S.stats_id) P
WHERE (S.object_id=OBJECT_ID('T3.CFDI_COBRANZA') AND C.name IN('FECHA_PROCESO','ASIGNACION_CENTRAL','ASIGNACION_ID'))
   OR (S.object_id=OBJECT_ID('T3.REGISTRO_FISCAL') AND C.name='FACTURA')
   OR (S.object_id=OBJECT_ID('EAI_OWNER.TMP_ACCOUNT_HEADER') AND C.name='CLEARINGDOCNUMBER');

IF @MedirVolumenes=1
BEGIN
    -- Solo agregados: no materializa 56 millones de pendientes en tempdb.
    -- Aun puede ser una lectura costosa si el optimizador elige scan/lookups.
    SELECT '10_SELECTIVIDAD_UPDATE_ESTADO_ACTUAL' Seccion,COUNT_BIG(*) CobranzasRecientes,
        COUNT_BIG(CASE WHEN Asignacion_Central IS NULL THEN 1 END) RecientesSinAsignacion,
        COUNT_BIG(CASE WHEN Asignacion_Central IS NULL AND Factura IS NULL THEN 1 END) SinFactura,
        COUNT_BIG(CASE WHEN Asignacion_Central IS NULL AND Asignacion_ID IS NULL THEN 1 END) SinAsignacionID
    FROM T3.CFDI_COBRANZA WHERE Fecha_Proceso>@Limite;
END;
SELECT '11_ALCANCE' Seccion,'Planes compilados e intervalos historicos; no son un plan real ni una medicion de una nueva corrida. Las esperas pueden solaparse.' Mensaje;

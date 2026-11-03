/*
  SOLO LECTURA. Ejecutar despues de crear el indice y, para medir la mejora,
  despues de la siguiente corrida de negocio autorizada con carga comparable.
  Este script NO ejecuta el SP, no recompila, no limpia cache ni fuerza planes.
  Sin una corrida posterior solo se puede comprobar la definicion del indice.
  Query Store muestra agregados por plan y ventana, no un PID individual.
*/
USE [T3QA]; SET NOCOUNT ON;
DECLARE @Desde datetimeoffset=DATEADD(DAY,-1,SYSDATETIMEOFFSET());
DECLARE @Hasta datetimeoffset=SYSDATETIMEOFFSET();
-- Ajustar @Desde al momento de creacion que devuelve el 06 para aislar lo nuevo.
DECLARE @Objeto int=OBJECT_ID(N'T3.PROC_CFDI_PROCESA_PAGO_AGR');
DECLARE @Nombre sysname=N'IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC';
SELECT '00_CONTEXTO_MEDICION' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,
    SYSDATETIMEOFFSET() Captura,@Desde DesdeIntervalosQS,@Hasta HastaIntervalosQS;
SELECT '01_REFERENCIA_29_OCT' Seccion,CONVERT(decimal(18,3),107029.831) Duracion_ms,
    CONVERT(decimal(18,3),16456.611) CPU_ms,CONVERT(bigint,2701949) LecturasLogicas,
    CONVERT(bigint,1314995) LecturasFisicas,32735 QueryId,8889 PlanId,30 nDias;

SELECT '02_INDICE_ACTUAL' Seccion,I.name,I.is_disabled,I.has_filter,
    IC.key_ordinal OrdenClave,IC.is_included_column EsInclude,C.name Columna
FROM sys.indexes I JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE I.object_id=OBJECT_ID(N'T3.CFDI_COBRANZA') AND I.name=@Nombre
ORDER BY IC.index_column_id;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'T3.CFDI_COBRANZA') AND name=@Nombre)
    SELECT '02_NOMBRE_NO_ENCONTRADO' Seccion,
        'No aparece el nombre propuesto; el 06 puede haber detectado un equivalente con otro nombre. Revisar su resultado.' Mensaje;

BEGIN TRY
    ;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
    SELECT TOP(5) '03_UPDATE_EN_CACHE' Seccion,Q.last_execution_time UltimaEjecucion,
        Q.execution_count Ejecuciones,Q.last_elapsed_time/1000.0 Duracion_ms,
        Q.last_worker_time/1000.0 CPU_ms,Q.last_logical_reads LecturasLogicas,
        Q.last_physical_reads LecturasFisicas,
        P.XMLPlan.exist('//Object[@Index="[IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC]"]') UsaIndicePropuesto
    FROM sys.dm_exec_query_stats Q CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T
    CROSS APPLY(SELECT SUBSTRING(T.text,Q.statement_start_offset/2+1,
        (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text) ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1) Texto) X
    OUTER APPLY sys.dm_exec_text_query_plan(Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset) P0
    OUTER APPLY(SELECT TRY_CONVERT(xml,P0.query_plan) XMLPlan) P
    WHERE T.dbid=DB_ID() AND T.objectid=@Objeto
      AND X.Texto LIKE N'%UPDATE Cobza%' AND X.Texto LIKE N'%Asignacion_Central%'
    ORDER BY Q.last_execution_time DESC;
END TRY
BEGIN CATCH
    SELECT '03_CACHE_NO_DISPONIBLE' Seccion,ERROR_NUMBER() Error,LEFT(ERROR_MESSAGE(),180) Mensaje;
END CATCH;

BEGIN TRY
    DECLARE @Planes table(QueryId bigint,PlanId bigint,XMLPlan xml,UsaIndice bit);
    ;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
    INSERT @Planes
    SELECT Q.query_id,P.plan_id,X.XMLPlan,
        X.XMLPlan.exist('//Object[@Index="[IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC]"]')
    FROM sys.query_store_query Q JOIN sys.query_store_query_text T ON T.query_text_id=Q.query_text_id
    JOIN sys.query_store_plan P ON P.query_id=Q.query_id
    OUTER APPLY(SELECT TRY_CONVERT(xml,P.query_plan) XMLPlan) X
    WHERE Q.object_id=@Objeto AND T.query_sql_text LIKE N'%UPDATE Cobza%'
      AND T.query_sql_text LIKE N'%Asignacion_Central%';
    ;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
    SELECT '04_METRICAS_POR_PLAN_QS' Seccion,P.QueryId,P.PlanId,R.execution_type_desc,
        MIN(I.start_time) PrimerIntervalo,MAX(I.end_time) UltimoIntervalo,
        SUM(R.count_executions) Ejecuciones,MAX(R.last_execution_time) UltimaFinalizacion,
        SUM(CONVERT(float,R.count_executions)*R.avg_duration)/NULLIF(SUM(R.count_executions),0)/1000.0 DuracionMedia_ms,
        SUM(CONVERT(float,R.count_executions)*R.avg_cpu_time)/NULLIF(SUM(R.count_executions),0)/1000.0 CPUMedia_ms,
        SUM(CONVERT(float,R.count_executions)*R.avg_logical_io_reads)/NULLIF(SUM(R.count_executions),0) LecturasLogicasMedias,
        P.UsaIndice UsaIndicePropuesto
    FROM @Planes P JOIN sys.query_store_runtime_stats R ON R.plan_id=P.PlanId
    JOIN sys.query_store_runtime_stats_interval I ON I.runtime_stats_interval_id=R.runtime_stats_interval_id
    WHERE I.end_time>=@Desde AND I.start_time<@Hasta
    GROUP BY P.QueryId,P.PlanId,R.execution_type_desc,P.UsaIndice;
    ;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
    SELECT DISTINCT '05_INDICES_DE_PLANES_QS' Seccion,P.QueryId,P.PlanId,
        O.N.value('string((@Schema)[1])','nvarchar(128)') Esquema,
        O.N.value('string((@Table)[1])','nvarchar(128)') Tabla,
        O.N.value('string((@Index)[1])','nvarchar(128)') Indice
    FROM @Planes P CROSS APPLY P.XMLPlan.nodes('//Object[@Index]') O(N);
END TRY
BEGIN CATCH
    SELECT '04_05_QUERY_STORE_NO_DISPONIBLE' Seccion,ERROR_NUMBER() Error,LEFT(ERROR_MESSAGE(),180) Mensaje;
END CATCH;
SELECT '06_ALCANCE_MEDICION' Seccion,
    'Comparar fechas, parametros y carga. La cache puede seguir mostrando la corrida anterior. Intervalos QS pueden incluir ejecuciones previas al corte. Sin nueva corrida no hay mejora medida.' Mensaje;

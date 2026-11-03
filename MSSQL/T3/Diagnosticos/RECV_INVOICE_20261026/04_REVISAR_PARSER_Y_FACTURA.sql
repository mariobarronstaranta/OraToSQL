/*
  Solo lectura. Ejecutar en la misma base; NO requiere una nueva carga activa.
  Aprovecha cache y Query Store ya existentes; no habilita ni modifica nada.
  Objetivos: SF_PROC_PREINVOICE_IFC e INVOICE_TO_FACTURA.
  Guardar todos los resultados. Los tiempos de padres/hijos son inclusivos.
  Las estadisticas del hijo en cache pueden incluir ejecuciones anteriores;
  Query Store intenta separar intervalos posteriores a la modificacion del parser.
  Si no hay datos en Query Store, conservar ese resultado: no implica ausencia de costo.
*/
SET NOCOUNT ON;
DECLARE @Parser INT=OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',N'P'),
        @Modificacion DATETIME,@Desde DATETIMEOFFSET;
SELECT @Modificacion=modify_date FROM sys.objects WHERE object_id=@Parser;
IF @Modificacion IS NULL
 THROW 52650,'Verificar base seleccionada y visibilidad del parser.',1;
SET @Desde=TODATETIMEOFFSET(@Modificacion,DATEPART(TZOFFSET,SYSDATETIMEOFFSET()));

SELECT '01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@Desde AS DesdeModificacionParser,
       CASE WHEN OBJECT_DEFINITION(@Parser) IS NULL THEN NULL
            WHEN CHARINDEX(N'RI_SKU_SEEK_V1',OBJECT_DEFINITION(@Parser))>0 THEN 1 ELSE 0 END AS ParcheSku;

DECLARE @Objetos TABLE(Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT,Id INT);
INSERT INTO @Objetos VALUES
 (N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',@Parser),
 (N'EAI_OWNER.INVOICE_TO_FACTURA',OBJECT_ID(N'EAI_OWNER.INVOICE_TO_FACTURA',N'P'));
DECLARE @Planes TABLE
 (Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT,PlanHandle VARBINARY(64),
  SqlHandle VARBINARY(64),CachedTime DATETIME,UltimaEjecucion DATETIME,
  Ejecuciones BIGINT,PlanXML XML);
INSERT INTO @Planes
SELECT X.Nombre,P.plan_handle,P.sql_handle,P.cached_time,P.last_execution_time,
       P.execution_count,NULL
FROM sys.dm_exec_procedure_stats P
INNER JOIN @Objetos X ON X.Id=P.object_id WHERE P.database_id=DB_ID();

DECLARE @Sentencias TABLE
 (Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT,PlanHandle VARBINARY(64),
  QueryHash BINARY(8),Inicio INT,Fin INT,Creacion DATETIME,UltimaEjecucion DATETIME,
  Ejecuciones BIGINT,Tiempo_us BIGINT,Cpu_us BIGINT,Lecturas BIGINT,
  UltimoDop BIGINT,Texto NVARCHAR(200));
INSERT INTO @Sentencias
SELECT H.Nombre,Q.plan_handle,Q.query_hash,Q.statement_start_offset,Q.statement_end_offset,
       Q.creation_time,Q.last_execution_time,Q.execution_count,Q.total_elapsed_time,
       Q.total_worker_time,Q.total_logical_reads,Q.last_dop,
       CONVERT(NVARCHAR(200),SUBSTRING(T.text,Q.statement_start_offset/2+1,200))
FROM sys.dm_exec_query_stats Q
INNER JOIN (SELECT DISTINCT Nombre,SqlHandle FROM @Planes) H ON H.SqlHandle=Q.sql_handle
CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T;

SELECT '02_SENTENCIAS_CACHE' AS Seccion,S.Nombre,S.Creacion,S.UltimaEjecucion,
       CASE WHEN S.Creacion>=@Modificacion THEN 1 ELSE 0 END AS CompiladaDesdeCambioParser,
       S.Ejecuciones,S.Tiempo_us/1000.0 AS TiempoTotal_ms,
       S.Tiempo_us/1000.0/NULLIF(S.Ejecuciones,0) AS Media_ms,
       S.Cpu_us/1000.0/NULLIF(S.Ejecuciones,0) AS CPU_Media_ms,
       S.Lecturas*1.0/NULLIF(S.Ejecuciones,0) AS LecturasPorLlamada,
       S.UltimoDop,S.PlanHandle,S.Inicio,S.Fin,S.Texto
FROM
 (SELECT *,ROW_NUMBER() OVER(PARTITION BY Nombre ORDER BY Tiempo_us DESC) AS N
  FROM @Sentencias WHERE Ejecuciones>0) S
WHERE S.N<=15 ORDER BY S.Nombre,S.Tiempo_us DESC;

-- Agrupar todas las filas de un mismo intervalo (persistidas y en memoria).
-- Conservar solo intervalos cuyos registros de ejecuciones terminadas empiezan
-- despues del cambio: evita mezclar metricas previas dentro del mismo intervalo.
DECLARE @Runtime TABLE
 (Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT,QueryId BIGINT,PlanId BIGINT,
  Intervalo BIGINT,Primera DATETIMEOFFSET,Ultima DATETIMEOFFSET,N BIGINT,
  Tiempo_us FLOAT,Cpu_us FLOAT,Lecturas FLOAT);
IF EXISTS(SELECT 1 FROM sys.databases WHERE database_id=DB_ID() AND is_query_store_on=1)
BEGIN
 SELECT '03_QUERY_STORE_CONFIG' AS Seccion,actual_state_desc,query_capture_mode_desc,
        wait_stats_capture_mode_desc,interval_length_minutes
 FROM sys.database_query_store_options;

 INSERT INTO @Runtime
 SELECT X.Nombre,Q.query_id,P.plan_id,R.runtime_stats_interval_id,
        MIN(R.first_execution_time),MAX(R.last_execution_time),SUM(R.count_executions),
        SUM(R.avg_duration*R.count_executions),SUM(R.avg_cpu_time*R.count_executions),
        SUM(R.avg_logical_io_reads*R.count_executions)
 FROM sys.query_store_query Q
 INNER JOIN @Objetos X ON X.Id=Q.object_id
 INNER JOIN sys.query_store_plan P ON P.query_id=Q.query_id
 INNER JOIN sys.query_store_runtime_stats R ON R.plan_id=P.plan_id
 WHERE R.execution_type=0
 GROUP BY X.Nombre,Q.query_id,P.plan_id,R.runtime_stats_interval_id
 HAVING MIN(R.first_execution_time)>=@Desde AND SUM(R.count_executions)>0;
END;

;WITH Totales AS
 (SELECT Nombre,QueryId,PlanId,MIN(Primera) AS Primera,MAX(Ultima) AS Ultima,
         SUM(N) AS N,SUM(Tiempo_us) AS Tiempo_us,SUM(Cpu_us) AS Cpu_us,SUM(Lecturas) AS Lecturas
  FROM @Runtime GROUP BY Nombre,QueryId,PlanId)
SELECT TOP (20) '04_QUERY_STORE_POSTERIOR' AS Seccion,R.Nombre,R.QueryId,R.PlanId,
       R.Primera,R.Ultima,R.N AS Ejecuciones,R.Tiempo_us/1000.0 AS TiempoTotal_ms,
       R.Tiempo_us/1000.0/R.N AS Media_ms,R.Cpu_us/1000.0/R.N AS CPU_Media_ms,
       R.Lecturas/R.N AS LecturasPorLlamada,
       CONVERT(NVARCHAR(200),LEFT(T.query_sql_text,200)) AS InicioSentencia
FROM Totales R
INNER JOIN sys.query_store_query Q ON Q.query_id=R.QueryId
INNER JOIN sys.query_store_query_text T ON T.query_text_id=Q.query_text_id
ORDER BY R.Tiempo_us DESC;

;WITH Esperas AS
 (SELECT R.Nombre,R.QueryId,R.PlanId,W.wait_category_desc,
         SUM(W.total_query_wait_time_ms) AS Tiempo_ms
  FROM @Runtime R
  INNER JOIN sys.query_store_wait_stats W
   ON W.plan_id=R.PlanId AND W.runtime_stats_interval_id=R.Intervalo
  WHERE W.execution_type=0
  GROUP BY R.Nombre,R.QueryId,R.PlanId,W.wait_category_desc)
SELECT TOP (20) '05_ESPERAS_QUERY_STORE' AS Seccion,E.Nombre,E.QueryId,E.PlanId,
       E.wait_category_desc,E.Tiempo_ms,
       CONVERT(NVARCHAR(200),LEFT(T.query_sql_text,200)) AS InicioSentencia
FROM Esperas E
INNER JOIN sys.query_store_query Q ON Q.query_id=E.QueryId
INNER JOIN sys.query_store_query_text T ON T.query_text_id=Q.query_text_id
WHERE E.Tiempo_ms>0 ORDER BY E.Tiempo_ms DESC;

UPDATE P SET PlanXML=Q.query_plan
FROM @Planes P OUTER APPLY sys.dm_exec_query_plan(P.PlanHandle) Q;

-- Estas son las celdas XML que se pueden guardar como .sqlplan si se requieren.
SELECT '06_PLANES_PROCEDIMIENTOS' AS Seccion,Nombre,CachedTime,UltimaEjecucion,
       Ejecuciones,PlanHandle,PlanXML
FROM @Planes ORDER BY Nombre,CachedTime;

;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS p)
SELECT TOP (20) '07_CONVERSIONES_PLAN' AS Seccion,P.Nombre,
       S.N.value('(@StatementText)[1]','nvarchar(200)') AS InicioSentencia,
       W.N.value('(@ConvertIssue)[1]','nvarchar(100)') AS ConvertIssue,
       W.N.value('(@Expression)[1]','nvarchar(200)') AS Expresion,
       A.Llamadas AS LlamadasObservadasDelHash
FROM @Planes P
CROSS APPLY P.PlanXML.nodes('//p:StmtSimple') S(N)
CROSS APPLY S.N.nodes('.//p:PlanAffectingConvert') W(N)
OUTER APPLY
 (SELECT MAX(E.Ejecuciones) AS Llamadas FROM @Sentencias E
  WHERE E.PlanHandle=P.PlanHandle AND E.QueryHash=
    TRY_CONVERT(BINARY(8),S.N.value('(@QueryHash)[1]','varchar(18)'),1)) A
WHERE A.Llamadas>0;

;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS p)
SELECT TOP (20) '08_RECORRIDOS_PLAN_CON_LLAMADAS' AS Seccion,P.Nombre,
       S.N.value('(@StatementText)[1]','nvarchar(200)') AS InicioSentencia,
       R.N.value('(@PhysicalOp)[1]','nvarchar(60)') AS Operacion,
       O.N.value('(@Schema)[1]','nvarchar(128)') AS Esquema,
       O.N.value('(@Table)[1]','nvarchar(128)') AS Tabla,
       O.N.value('(@Index)[1]','nvarchar(128)') AS Indice,
       R.N.value('(@EstimatedTotalSubtreeCost)[1]','float') AS CostoEstimado,
       A.Llamadas AS LlamadasObservadasDelHash
FROM @Planes P
CROSS APPLY P.PlanXML.nodes('//p:StmtSimple') S(N)
CROSS APPLY S.N.nodes('./p:QueryPlan//p:RelOp[@PhysicalOp="Index Scan" or @PhysicalOp="Clustered Index Scan" or @PhysicalOp="Table Scan"]') R(N)
CROSS APPLY R.N.nodes('./*/p:Object') O(N)
OUTER APPLY
 (SELECT MAX(E.Ejecuciones) AS Llamadas FROM @Sentencias E
  WHERE E.PlanHandle=P.PlanHandle AND E.QueryHash=
    TRY_CONVERT(BINARY(8),S.N.value('(@QueryHash)[1]','varchar(18)'),1)) A
WHERE A.Llamadas>0
ORDER BY R.N.value('(@EstimatedTotalSubtreeCost)[1]','float') DESC;

SELECT '09_ALCANCE' AS Seccion,
 N'Solo lectura, sin nueva carga. Query Store usa solo intervalos sin ejecuciones previas al cambio. '
 +N'Cache del hijo puede incluir historia anterior. Conversion/scan no prueba por si solo lentitud. '
 +N'Plan estimado y hash compartido no acreditan filas leidas ni costo por invocacion.' AS Observacion;

/* SOLO LECTURA. No ejecuta SP de negocio, crea indices, actualiza estadisticas,
   cambia Query Store ni vacia cache. Cache/DMV puede requerir permisos de
   rendimiento; cada bloque protegido devuelve su error y permite continuar.
   No sumar duraciones inclusivas del padre con las de sus procedimientos hijos.
*/
USE [T3QA]; SET NOCOUNT ON;
DECLARE @Desde datetime=DATEADD(DAY,-7,GETDATE());
DECLARE @VerPlanes bit=0; -- 1 devuelve planes EN CACHE, no planes de ejecucion reales.
DECLARE @TopPorProcedimiento int=20;

SELECT '00_CONTEXTO' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() Captura,
       SERVERPROPERTY('ProductVersion') VersionSQL,D.compatibility_level,@Desde DesdeBitacora
FROM sys.databases D WHERE D.database_id=DB_ID();

DECLARE @Objetos table(Nombre nvarchar(256) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,Id int NULL);
INSERT @Objetos(Nombre) VALUES
(N'T3.CFDI_COBRANZA'),(N'T3.CFDI_AGRUPACION_CTRL'),(N'T3.CFDI_AGRUPACION_PAGO'),
(N'T3.REGISTRO_FISCAL'),(N'T3.REGISTRO_FISCAL_DETALLE'),(N'T3.WA_FACTORAJE'),
(N'T3.CFDI_DOCUMENTOS'),(N'T3.CFDI_RFC_SETTING'),(N'T3.CFDI_USOCFDI_CLIENTE'),
(N'EAI_OWNER.TMP_ACCOUNT_HEADER'),(N'T3.MOV_CLIENTE'),(N'EAI_OWNER.MX_HASHTABLE'),
(N'T3.TMD_EMAIL'),(N'T3.CFDI_REPROCESO'),(N'T3.DISTRIBUIDOR_FISCAL'),(N'EAI.ZSDFE_SOC');
UPDATE @Objetos SET Id=OBJECT_ID(Nombre,N'U');
SELECT '01_TABLAS' Seccion,O.Nombre,O.Id,
       (SELECT SUM(P.rows) FROM sys.partitions P WHERE P.object_id=O.Id AND P.index_id IN(0,1)) FilasAproximadas,
       CASE WHEN O.Id IS NULL THEN 'AUSENTE O NO VISIBLE' ELSE 'VISIBLE' END Visibilidad
FROM @Objetos O ORDER BY O.Nombre;

-- Los nombres de indices no certifican sus claves: se incluyen columnas, orden,
-- INCLUDE, unicidad, filtro y estado. No se presume ausencia por el DDL local.
SELECT '02_INDICES_ACTUALES' Seccion,O.Nombre Tabla,I.name Indice,I.type_desc,
       I.is_unique,I.is_primary_key,I.is_disabled,I.has_filter,I.filter_definition,
       STUFF((SELECT N','+QUOTENAME(C.name)+CASE WHEN IC.is_descending_key=1 THEN N' DESC' ELSE N' ASC' END
         FROM sys.index_columns IC JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
         WHERE IC.object_id=O.Id AND IC.index_id=I.index_id AND IC.key_ordinal>0
         ORDER BY IC.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'') ColumnasClave,
       STUFF((SELECT N','+QUOTENAME(C.name) FROM sys.index_columns IC
         JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
         WHERE IC.object_id=O.Id AND IC.index_id=I.index_id AND IC.is_included_column=1
         ORDER BY IC.index_column_id FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'') ColumnasInclude
FROM @Objetos O JOIN sys.indexes I ON I.object_id=O.Id AND I.index_id>0
ORDER BY O.Nombre,I.index_id;

SELECT '03_TIPOS_DE_CRUCE' Seccion,O.Nombre,C.name,TYPE_NAME(C.user_type_id) Tipo,
       C.max_length,C.precision,C.scale,C.is_nullable,C.collation_name,C.is_computed
FROM @Objetos O JOIN sys.columns C ON C.object_id=O.Id
WHERE C.name IN ('ASIGNACION_ID','ASIGNACION_CENTRAL','FACTURA','NOTA_VENTA','AGRUPACION',
    'FECHA_PROCESO','FECHA_PAGO','FECHA_ENVIO','FISCALYEAR','FYEAR','CLEARINGDOCNUMBER',
    'CLIENTE_SAP','RFC','PARAMETRO','VALOR')
ORDER BY O.Nombre,C.column_id;

SELECT '04_MODULOS_INSTALADOS' Seccion,S.name Esquema,O.name,O.modify_date,
       CONVERT(varchar(64),HASHBYTES('SHA2_256',M.definition),2) HashDefinicion
FROM sys.objects O JOIN sys.schemas S ON S.schema_id=O.schema_id
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id IN(OBJECT_ID('T3.PROC_CFDI_PROCESA_PAGO_AGR'),OBJECT_ID('T3.PROC_CFDI_LIBERA_PAGO_CENTRAL'),
    OBJECT_ID('T3.PROC_CFDI_LIBERA_PAGO_CHECK'),OBJECT_ID('T3.PROC_V20_GENERAR_PAGO_AGR'));

-- Las filas del 109 se cierran ANTES del EXEC al 614. Sus PID pertenecen a
-- secuencias diferentes; no unir ambos procesos por igualdad de PID.
SELECT '05_BITACORA_109_Y_614' Seccion,R.PID,R.Proceso,R.Inicio,R.Fin,
       DATEDIFF(SECOND,R.Inicio,R.Fin) DuracionSegundosBitacora,
       R.Proceso_1,R.Proceso_2,R.Proceso_3,R.Proceso_4,
       CASE WHEN R.Proceso=109 THEN 'SOLO AGRUPACION; EXCLUYE LA LLAMADA POSTERIOR AL 614'
            ELSE 'LIBERACION; CONTADOR NO CERTIFICA GENERACION/TIMBRADO' END Alcance
FROM T3.RF_PROCESOS_LOG R WHERE R.Proceso IN(109,614) AND R.Inicio>=@Desde
ORDER BY R.Inicio DESC;

BEGIN TRY
    EXEC sys.sp_executesql N'
    SELECT ''06_TIEMPOS_EN_CACHE'' Seccion,OBJECT_SCHEMA_NAME(P.object_id) Esquema,
       OBJECT_NAME(P.object_id) Procedimiento,P.cached_time,P.last_execution_time,P.execution_count,
       P.total_elapsed_time/1000.0 Total_ms,P.total_elapsed_time/1000.0/NULLIF(P.execution_count,0) Media_ms,
       P.last_elapsed_time/1000.0 Ultima_ms,P.last_worker_time/1000.0 UltimaCPU_ms,
       P.last_logical_reads UltimasLecturas,P.total_logical_reads LecturasAcumuladas,P.last_logical_writes UltimasEscrituras
    FROM sys.dm_exec_procedure_stats P WHERE P.database_id=DB_ID()
      AND P.object_id IN(OBJECT_ID(''T3.PROC_CFDI_PROCESA_PAGO_AGR''),OBJECT_ID(''T3.PROC_CFDI_LIBERA_PAGO_CENTRAL''),
          OBJECT_ID(''T3.PROC_CFDI_LIBERA_PAGO_CHECK''),OBJECT_ID(''T3.PROC_V20_GENERAR_PAGO_AGR''));

    ;WITH Q AS (
       SELECT T.objectid,Q.creation_time,Q.last_execution_time,Q.execution_count,
         Q.total_elapsed_time,Q.last_elapsed_time,Q.last_worker_time,Q.total_logical_reads,Q.last_logical_reads,
         SUBSTRING(T.text,Q.statement_start_offset/2+1,
           (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text) ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1) Sentencia,
         ROW_NUMBER() OVER(PARTITION BY T.objectid ORDER BY Q.total_elapsed_time DESC) Prioridad
       FROM sys.dm_exec_query_stats Q CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T
       WHERE T.dbid=DB_ID() AND T.objectid IN(OBJECT_ID(''T3.PROC_CFDI_PROCESA_PAGO_AGR''),
         OBJECT_ID(''T3.PROC_CFDI_LIBERA_PAGO_CENTRAL''),OBJECT_ID(''T3.PROC_CFDI_LIBERA_PAGO_CHECK''),
         OBJECT_ID(''T3.PROC_V20_GENERAR_PAGO_AGR''))
    )
    SELECT ''07_SENTENCIAS_EN_CACHE'' Seccion,OBJECT_NAME(objectid) Procedimiento,Prioridad,
       creation_time,last_execution_time,execution_count,total_elapsed_time/1000.0 Total_ms,
       total_elapsed_time/1000.0/NULLIF(execution_count,0) Media_ms,last_elapsed_time/1000.0 Ultima_ms,
       last_worker_time/1000.0 UltimaCPU_ms,total_logical_reads,last_logical_reads,Sentencia
    FROM Q WHERE Prioridad<=@Top ORDER BY Procedimiento,Prioridad;

    IF @Planes=1
       SELECT ''08_PLANES_EN_CACHE_NO_REALES'' Seccion,OBJECT_NAME(P.object_id) Procedimiento,
         P.cached_time,P.last_execution_time,QP.query_plan
       FROM sys.dm_exec_procedure_stats P OUTER APPLY sys.dm_exec_query_plan(P.plan_handle) QP
       WHERE P.database_id=DB_ID() AND P.object_id IN(OBJECT_ID(''T3.PROC_CFDI_PROCESA_PAGO_AGR''),
         OBJECT_ID(''T3.PROC_CFDI_LIBERA_PAGO_CENTRAL''),OBJECT_ID(''T3.PROC_CFDI_LIBERA_PAGO_CHECK''),
         OBJECT_ID(''T3.PROC_V20_GENERAR_PAGO_AGR''));',
      N'@Top int,@Planes bit',@Top=@TopPorProcedimiento,@Planes=@VerPlanes;
END TRY
BEGIN CATCH
    SELECT '06_08_CACHE_NO_DISPONIBLE' Seccion,ERROR_NUMBER() Error,ERROR_MESSAGE() Mensaje;
END CATCH;

BEGIN TRY
    SELECT '09_ESTADISTICAS_ACTUALES' Seccion,O.Nombre,S.name Estadistica,S.auto_created,S.user_created,
           S.has_filter,S.filter_definition,P.last_updated,P.rows,P.rows_sampled,P.modification_counter
    FROM @Objetos O JOIN sys.stats S ON S.object_id=O.Id
    OUTER APPLY sys.dm_db_stats_properties(S.object_id,S.stats_id) P
    ORDER BY O.Nombre,S.stats_id;
END TRY
BEGIN CATCH
    SELECT '09_ESTADISTICAS_NO_DISPONIBLES' Seccion,ERROR_NUMBER() Error,ERROR_MESSAGE() Mensaje;
END CATCH;

BEGIN TRY
    EXEC sys.sp_executesql N'SELECT ''10_ESTADO_QUERY_STORE'' Seccion,actual_state_desc,desired_state_desc,
       readonly_reason,query_capture_mode_desc FROM sys.database_query_store_options;';
END TRY
BEGIN CATCH
    SELECT '10_QUERY_STORE_NO_DISPONIBLE' Seccion,ERROR_NUMBER() Error,ERROR_MESSAGE() Mensaje;
END CATCH;

IF COL_LENGTH('sys.sql_modules','is_inlineable') IS NOT NULL
BEGIN TRY
    EXEC sys.sp_executesql N'SELECT ''11_FUNCIONES'' Seccion,OBJECT_SCHEMA_NAME(M.object_id) Esquema,
       OBJECT_NAME(M.object_id) Funcion,M.is_inlineable
    FROM sys.sql_modules M WHERE M.object_id IN(OBJECT_ID(''EAI_OWNER.GETCONV''),
       OBJECT_ID(''T3.FN_TRIM_CFDI''),OBJECT_ID(''T3.FN_NUM_TO_CHAR_CFDI''),OBJECT_ID(''T3.FN_CTRO_EDICOM_PAGO''));';
END TRY
BEGIN CATCH
    SELECT '11_FUNCIONES_NO_DISPONIBLES' Seccion,ERROR_NUMBER() Error,ERROR_MESSAGE() Mensaje;
END CATCH;

SELECT '12_LIMITES' Seccion,'Cache contiene solo lo retenido desde compilacion; ausencia de filas no prueba ausencia de ejecucion.' Mensaje
UNION ALL SELECT '12_LIMITES','No sumar tiempos de padre e hijos. La bitacora 109 excluye liberacion; el tiempo total del EXEC padre la incluye.'
UNION ALL SELECT '12_LIMITES','is_inlineable=1 no demuestra inlining efectivo; los planes en cache no aportan todas las metricas de un plan real.';

/* SOLO LECTURA de catalogos y cache. Ejecutar en la base de la corrida.
   No ejecuta pagos, cambia indices, limpia cache ni recompila el SP.
   Los acumulados abarcan todas las ejecuciones desde cada compilacion;
   no son un perfil exclusivo de la corrida de 90 segundos. Los cursores
   pueden tener estadisticas parciales: no sumar filas como un total exacto.
   Ultima_ms es la ultima ejecucion de la INSTRUCCION, no del procedimiento.
   Requiere permisos de lectura de DMV. Guardar todos los resultados.
*/
SET NOCOUNT ON;
DECLARE @Objeto int = OBJECT_ID(N'T3.PROC_CFDI_PROCESA_PAGO_AGR');
SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BaseDatos,
       SYSDATETIMEOFFSET() AS Captura, @Objeto AS ObjectId;
IF @Objeto IS NULL
BEGIN
    RAISERROR('No existe el procedimiento en la base seleccionada.', 16, 1);
    RETURN;
END;

-- Materializar las metricas una sola vez para mantener los identificadores
-- entre el resumen y los fragmentos de texto. Solo tabla variable de sesion.
DECLARE @Costo table
(
    Id int IDENTITY(1,1), Compilacion datetime, UltimaEjecucion datetime,
    Ejecuciones bigint, Total_ms decimal(24,3), CPU_ms decimal(24,3),
    Ultima_ms decimal(24,3), Maxima_ms decimal(24,3),
    Lecturas bigint, Escrituras bigint, Texto nvarchar(max),
    PlanHandle varbinary(64), Inicio int, Fin int
);
BEGIN TRY
    INSERT @Costo
    SELECT q.creation_time, q.last_execution_time, q.execution_count,
           q.total_elapsed_time / 1000.0, q.total_worker_time / 1000.0,
           q.last_elapsed_time / 1000.0, q.max_elapsed_time / 1000.0,
           q.total_logical_reads, q.total_logical_writes,
           SUBSTRING(t.text, q.statement_start_offset / 2 + 1,
               (CASE WHEN q.statement_end_offset = -1 THEN DATALENGTH(t.text)
                     ELSE q.statement_end_offset END
                - q.statement_start_offset) / 2 + 1),
           q.plan_handle, q.statement_start_offset, q.statement_end_offset
    FROM sys.dm_exec_query_stats q
    CROSS APPLY sys.dm_exec_sql_text(q.sql_handle) t
    WHERE t.dbid = DB_ID() AND t.objectid = @Objeto;

    SELECT Id, Compilacion, UltimaEjecucion, Ejecuciones,
           Total_ms, CPU_ms, Ultima_ms, Maxima_ms, Lecturas, Escrituras,
           LEFT(REPLACE(REPLACE(Texto, CHAR(13), ' '), CHAR(10), ' '), 180) AS Instruccion
    FROM @Costo ORDER BY Total_ms DESC;

    -- Texto completo en fragmentos para evitar truncamiento de SSMS a 256.
    ;WITH Fragmentos AS
    (
        SELECT Id, Texto, 1 AS Posicion FROM @Costo
        UNION ALL
        SELECT Id, Texto, Posicion + 180 FROM Fragmentos
        WHERE Posicion + 180 <= LEN(Texto)
    )
    SELECT Id, Posicion, SUBSTRING(Texto, Posicion, 180) AS Fragmento
    FROM Fragmentos ORDER BY Id, Posicion OPTION (MAXRECURSION 0);

    -- Planes estimados en cache de las cinco instrucciones mas costosas.
    -- Los planes no contienen mediciones reales por operador.
    SELECT c.Id, p.query_plan AS Plan_cache
    FROM (SELECT TOP (5) * FROM @Costo ORDER BY Total_ms DESC) c
    OUTER APPLY sys.dm_exec_text_query_plan(c.PlanHandle, c.Inicio, c.Fin) p
    ORDER BY c.Total_ms DESC;

    IF NOT EXISTS (SELECT 1 FROM @Costo)
        SELECT 'Sin estadisticas visibles: cache expirada, recompilacion o visibilidad limitada. No ejecutar pagos solo para repoblarla.' AS Aviso;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Detalle;
END CATCH;

-- Claves y cobertura reales de las tablas usadas por los UPDATE y sus JOIN.
SELECT OBJECT_SCHEMA_NAME(i.object_id) AS Esquema,
       OBJECT_NAME(i.object_id) AS Tabla, i.name AS Indice,
       i.type_desc, i.is_disabled, i.has_filter, i.filter_definition,
       ic.key_ordinal, ic.is_included_column, c.name AS Columna,
       TYPE_NAME(c.user_type_id) AS Tipo, c.max_length, c.collation_name
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id IN (OBJECT_ID(N'T3.CFDI_COBRANZA'),
                     OBJECT_ID(N'T3.CFDI_AGRUPACION_CTRL'),
                     OBJECT_ID(N'T3.CFDI_AGRUPACION_PAGO'),
                     OBJECT_ID(N'T3.REGISTRO_FISCAL'))
ORDER BY Tabla, i.index_id, ic.is_included_column, ic.key_ordinal, ic.index_column_id;

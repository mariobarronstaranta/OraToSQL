/* Ejecutar en la base donde se corrio el procedimiento (por ejemplo T3QA).
   Solo lectura: no ejecuta pagos ni modifica procedimientos.
   Ajustar @Desde/@Hasta a la ventana de la corrida de 90 segundos.
   Las horas corresponden al reloj del servidor SQL.
*/
SET NOCOUNT ON;
DECLARE @Desde datetime = DATEADD(HOUR, -4, GETDATE());
DECLARE @Hasta datetime = GETDATE();

-- 109 termina ANTES del EXEC del liberador; 614 mide la liberacion.
-- No unir por PID: cada procedimiento obtiene su propio identificador.
-- Correlacionar por horario; con corridas concurrentes no es una asociacion unica.
SELECT PID, Proceso,
       CASE Proceso WHEN 109 THEN 'Preparacion de agrupaciones'
                    WHEN 614 THEN 'Liberacion: CHECK y generador' END AS Etapa,
       Inicio, Fin,
       CONVERT(decimal(19,3), DATEDIFF_BIG(MILLISECOND, Inicio, Fin) / 1000.0) AS Segundos,
       Proceso_1, Proceso_2, Proceso_3, Proceso_4
FROM T3.RF_PROCESOS_LOG
WHERE Proceso IN (109, 614)
  AND Inicio >= @Desde AND Inicio <= @Hasta
ORDER BY Inicio DESC, Proceso;

-- Cache: incluye otras ejecuciones y planes. No representa exclusivamente
-- la corrida investigada. last_elapsed_time de cada hijo es su ULTIMA llamada,
-- no la suma de llamadas hechas por el padre. Tiempos inclusivos: NO sumarlos
-- entre padre e hijos. Ausencia de filas no demuestra ausencia de ejecucion.
BEGIN TRY
    SELECT OBJECT_SCHEMA_NAME(ps.object_id, ps.database_id) AS Esquema,
           OBJECT_NAME(ps.object_id, ps.database_id) AS Procedimiento,
           ps.cached_time, ps.last_execution_time, ps.execution_count,
           CONVERT(decimal(19,3), ps.last_elapsed_time / 1000.0) AS Ultima_ms,
           CONVERT(decimal(19,3), ps.total_elapsed_time / 1000.0) AS Total_cache_ms,
           CONVERT(decimal(19,3), ps.total_elapsed_time / 1000.0 /
                   NULLIF(ps.execution_count, 0)) AS Promedio_ms,
           CONVERT(decimal(19,3), ps.last_worker_time / 1000.0) AS Ultima_CPU_ms,
           ps.last_logical_reads, ps.last_logical_writes
    FROM sys.dm_exec_procedure_stats AS ps
    WHERE ps.database_id = DB_ID()
      AND ps.object_id IN
          (OBJECT_ID('T3.PROC_CFDI_PROCESA_PAGO_AGR'),
           OBJECT_ID('T3.PROC_CFDI_LIBERA_PAGO_CENTRAL'),
           OBJECT_ID('T3.PROC_CFDI_LIBERA_PAGO_CHECK'),
           OBJECT_ID('T3.PROC_V20_GENERAR_PAGO_AGR'),
           OBJECT_ID('EAI_OWNER.LOG_START'))
    ORDER BY ps.total_elapsed_time DESC;
END TRY
BEGIN CATCH
    SELECT 'No se pudo consultar cache; revisar permisos DMV.' AS Aviso,
           ERROR_MESSAGE() AS Detalle;
END CATCH;

-- Para usar DURANTE una corrida desde otra ventana: muestra instruccion
-- activa, bloqueo y espera. Es una muestra instantanea, no un perfil completo.
BEGIN TRY
    SELECT r.session_id, r.status, r.command, r.total_elapsed_time AS Solicitud_ms,
           r.cpu_time AS CPU_ms, r.logical_reads, r.writes,
           r.wait_type, r.wait_time AS Espera_actual_ms, r.blocking_session_id,
           OBJECT_SCHEMA_NAME(t.objectid, t.dbid) AS Esquema,
           OBJECT_NAME(t.objectid, t.dbid) AS Modulo,
           SUBSTRING(t.text, r.statement_start_offset / 2 + 1,
               (CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH(t.text)
                     ELSE r.statement_end_offset END
                - r.statement_start_offset) / 2 + 1) AS Instruccion_actual
    FROM sys.dm_exec_requests AS r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
    WHERE r.database_id = DB_ID() AND r.session_id <> @@SPID;
END TRY
BEGIN CATCH
    SELECT 'No se pudieron consultar solicitudes activas; revisar permisos DMV.' AS Aviso,
           ERROR_MESSAGE() AS Detalle;
END CATCH;

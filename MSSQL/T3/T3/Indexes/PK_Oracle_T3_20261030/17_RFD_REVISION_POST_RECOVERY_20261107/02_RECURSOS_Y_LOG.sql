/* Solo lectura. Ejecutar completo en conexion nueva, despues del 01.
   Algunas vistas requieren VIEW SERVER STATE / VIEW SERVER PERFORMANCE STATE
   o permisos de base/msdb. Un error de permisos NO significa recurso disponible.
   No otorgar permisos adicionales automaticamente. Pedir al DBA ese resultado.
   Instantanea: repetir durante una ventana representativa si fuera necesario.
*/
USE [master];
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2)=2
 THROW 56990,'Usar conexion nueva sin transaccion, IMPLICIT_TRANSACTIONS OFF.',1;
IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE name=N'T3QA' AND state_desc=N'ONLINE')
 THROW 56991,'T3QA no esta ONLINE o no es visible. Detener.',1;
DECLARE @Queries table(Id int PRIMARY KEY,Descripcion nvarchar(150),Consulta nvarchar(max));
INSERT @Queries VALUES
(1,N'Archivos y crecimiento',N'USE [T3QA]; SELECT DB_NAME() BaseDatos,name,type_desc,
 physical_name,CAST(size*8.0/1024 AS decimal(20,2)) TamanoMB,
 max_size MaxSizePaginas,growth Crecimiento,is_percent_growth FROM sys.database_files;
 SELECT DB_NAME(database_id) BaseDatos,name,type_desc,physical_name,
 CAST(size*8.0/1024 AS decimal(20,2)) TamanoMB,max_size,growth,is_percent_growth
 FROM sys.master_files WHERE database_id=2;'),
(2,N'Log usado T3QA',N'USE [T3QA]; SELECT * FROM sys.dm_db_log_space_usage;'),
(3,N'Volumenes T3QA y tempdb (mismo volumen repetido no se suma)',N'
 SELECT DB_NAME(f.database_id) BaseDatos,f.name,v.volume_mount_point,
 CAST(v.total_bytes/1073741824.0 AS decimal(20,2)) TotalGB,
 CAST(v.available_bytes/1073741824.0 AS decimal(20,2)) LibreGB
 FROM sys.master_files f CROSS APPLY sys.dm_os_volume_stats(f.database_id,f.file_id) v
 WHERE f.database_id IN (DB_ID(N''T3QA''),2);'),
(4,N'Memoria y configuracion',N'SELECT physical_memory_in_use_kb,
 process_physical_memory_low,process_virtual_memory_low FROM sys.dm_os_process_memory;
 SELECT total_physical_memory_kb,available_physical_memory_kb,system_memory_state_desc
 FROM sys.dm_os_sys_memory;
 SELECT name,value_in_use FROM sys.configurations WHERE name IN
 (N''max server memory (MB)'',N''min server memory (MB)'',N''max degree of parallelism'',N''cost threshold for parallelism'');'),
(5,N'Peticiones actuales (no historico del incidente)',N'
 SELECT session_id,status,command,blocking_session_id,wait_type,wait_time,
 wait_resource,percent_complete,cpu_time,total_elapsed_time,reads,writes,logical_reads
 FROM sys.dm_exec_requests WHERE database_id=DB_ID(N''T3QA'') AND session_id<>@@SPID;'),
(6,N'Transacciones T3QA y log retenido',N'
 SELECT t.transaction_id,t.database_transaction_begin_time,t.database_transaction_state,
 t.database_transaction_log_bytes_used,t.database_transaction_log_bytes_reserved,
 s.session_id
 FROM sys.dm_tran_database_transactions t
 LEFT JOIN sys.dm_tran_session_transactions s ON s.transaction_id=t.transaction_id
 WHERE t.database_id=DB_ID(N''T3QA'');'),
(7,N'Backups recientes: historial NO demuestra restauracion exitosa',N'
 SELECT TOP (12) database_name,type,backup_start_date,backup_finish_date,
 is_copy_only,has_backup_checksums,is_damaged
 FROM msdb.dbo.backupset WHERE database_name COLLATE DATABASE_DEFAULT=N''T3QA''
 ORDER BY backup_finish_date DESC;'),
(8,N'Espacio interno tempdb',N'USE [tempdb]; SELECT
 SUM(CONVERT(bigint,unallocated_extent_page_count))*8.0/1024 LibreInternoMB,
 SUM(CONVERT(bigint,user_object_reserved_page_count))*8.0/1024 ObjetosUsuarioMB,
 SUM(CONVERT(bigint,internal_object_reserved_page_count))*8.0/1024 ObjetosInternosMB,
 SUM(CONVERT(bigint,version_store_reserved_page_count))*8.0/1024 VersionesMB
 FROM sys.dm_db_file_space_usage;');
DECLARE @Id int=1,@Description nvarchar(150),@Sql nvarchar(max);
WHILE @Id<=8
BEGIN
 SELECT @Description=Descripcion,@Sql=Consulta FROM @Queries WHERE Id=@Id;
 SELECT @Id Seccion,@Description Descripcion,SYSDATETIMEOFFSET() Captura;
 BEGIN TRY
  SET @Sql=N'SET LOCK_TIMEOUT 5000; '+@Sql;
  EXEC sys.sp_executesql @Sql;
 END TRY
 BEGIN CATCH
  SELECT @Id SeccionNoDisponible,ERROR_NUMBER() NumeroError,ERROR_MESSAGE() Mensaje;
 END CATCH;
 SET @Id+=1;
END;
-- LOCK_TIMEOUT queda limitado al alcance de cada lote dinamico.


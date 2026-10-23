/*
 ATENCION: este archivo SI ejecuta RECV_REPLENISHMENT y procesa los pendientes.
 Usarlo EN LUGAR de la ejecucion manual habitual, una sola vez, sin otro lote
 simultaneo. No cambia estados para reprocesar documentos.
 Guardar la pestana Mensajes completa (IO/CPU/tiempo de sentencias y llamadas).
 Para estudiar remisiones, el lote debe contener documentos nuevos de esa ruta.
*/
USE [T3QA];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
 THROW 51961,'Ejecutar en una ventana sin transacciones externas o implicitas.',1;
DECLARE @Inicio datetime2(7)=SYSDATETIME();
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
BEGIN TRY
 EXEC EAI_OWNER.RECV_REPLENISHMENT;
END TRY
BEGIN CATCH
 SET STATISTICS IO OFF;
 SET STATISTICS TIME OFF;
 THROW;
END CATCH;
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
SELECT @Inicio Inicio,SYSDATETIME() Fin,
 DATEDIFF_BIG(MILLISECOND,@Inicio,SYSDATETIME()) Duracion_ms,
 @@TRANCOUNT TransaccionesSalida,XACT_STATE() EstadoTransaccion;
-- El coordinador puede registrar errores sin relanzarlos: comprobar estados
-- finales y logs de negocio. La duracion por si sola no prueba exito.

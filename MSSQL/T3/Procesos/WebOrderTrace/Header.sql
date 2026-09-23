-- Punto de procesamiento utilizado por Reporte.Bat (variables sqlcmd).
-- Load=1 valida y reemplaza ambos archivos; Load=0 utiliza las tablas actuales.
SET NOCOUNT ON;
EXEC EAI_OWNER.WOT_PROCESS @RunId='$(RunId)', @Load=$(Load);

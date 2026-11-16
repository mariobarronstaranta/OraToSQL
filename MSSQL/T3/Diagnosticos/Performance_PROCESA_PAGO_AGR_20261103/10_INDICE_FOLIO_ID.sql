/* Ejecutar en T3QA. Por defecto SOLO revisa y muestra la propuesta.
   Cambiar @Aplicar a 1 para crear el indice en una ventana de mantenimiento.
   La construccion lee la tabla, consume espacio/log y puede bloquear escrituras.
   Evidencia 09: UPDATE por FOLIO_ID: 59 ejecuciones, 74482.890 ms,
   37023798 lecturas logicas. Ningun indice reportado inicia por FOLIO_ID.
   No ejecuta pagos ni cambia el procedimiento. No exige folios unicos.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
DECLARE @Aplicar bit = 0;
DECLARE @Tabla int = OBJECT_ID(N'T3.CFDI_COBRANZA', N'U');
IF DB_NAME() <> N'T3QA' OR @Tabla IS NULL
BEGIN
    RAISERROR('Seleccionar T3QA y verificar T3.CFDI_COBRANZA.', 16, 1);
    RETURN;
END;

SELECT DB_NAME() AS BaseDatos, @Aplicar AS Aplicar,
       N'CREATE NONCLUSTERED INDEX IX_CFDI_COBRANZA_FOLIO_ID ON T3.CFDI_COBRANZA (FOLIO_ID);' AS Propuesta;

IF EXISTS
(
    SELECT 1 FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = @Tabla AND i.type IN (1, 2)
      AND i.is_disabled = 0 AND i.is_hypothetical = 0 AND i.has_filter = 0
      AND ic.key_ordinal = 1 AND c.name = N'FOLIO_ID'
)
BEGIN
    SELECT 'Ya existe un indice activo sin filtro que comienza por FOLIO_ID. No se crea otro.' AS Resultado;
    RETURN;
END;
IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE object_id = @Tabla AND name = N'IX_CFDI_COBRANZA_FOLIO_ID')
BEGIN
    RAISERROR('El nombre propuesto ya existe con otra configuracion. Revisarlo antes de continuar.', 16, 1);
    RETURN;
END;
IF @Aplicar = 0
BEGIN
    SELECT 'Revision solamente. Para crear el indice, cambiar @Aplicar a 1 y ejecutar en ventana de mantenimiento.' AS Resultado;
    RETURN;
END;

CREATE NONCLUSTERED INDEX IX_CFDI_COBRANZA_FOLIO_ID
    ON T3.CFDI_COBRANZA (FOLIO_ID);
SELECT 'Indice creado. Medir la siguiente corrida con pendientes; no repetir pagos solo para probar.' AS Resultado;

-- Validacion: ejecutar 08 y 09 despues de una corrida normal con pendientes.
-- Comparar tiempo y lecturas por ejecucion del UPDATE, ademas del total.
-- La creacion puede invalidar planes; usar Compilacion y Ejecuciones para
-- distinguir metricas anteriores y posteriores. No limpiar cache global.
-- No se promete una duracion final; el FETCH de detalle tambien cuesta tiempo.
-- El indice no hace FOLIO_ID unico: conserva el alcance actual del UPDATE.

CREATE PROCEDURE [EAI].[TRACE_PLSQL]
    @cProc VARCHAR(MAX),
    @cStep VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        INSERT INTO [EAI].[DEBUG_T3] 
            ([Fecha], [Pedido], [Comentario])
        VALUES 
            (GETDATE(), @cProc, @cStep);
    END TRY
    BEGIN CATCH
        -- Opcional: loguear el error para auditoría
        -- THROW;  -- Re-lanzar excepción si es crítico
    END CATCH
END;

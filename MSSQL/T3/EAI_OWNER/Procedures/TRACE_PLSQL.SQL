CREATE PROCEDURE [dbo].[TRACE_PLSQL]
    @cProc VARCHAR(MAX),
    @cStep VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        INSERT INTO [dbo].[DEBUG_T3] 
            ([Fecha], [Pedido], [Comentario])
        VALUES 
            (GETDATE(), @cProc, @cStep);
    END TRY
    BEGIN CATCH
        -- Opcional: loguear el error para auditoría
        -- THROW;  -- Re-lanzar excepción si es crítico
    END CATCH
END;

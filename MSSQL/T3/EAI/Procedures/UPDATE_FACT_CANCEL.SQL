CREATE PROCEDURE [T3].[UPDATE_FACT_CANCEL]
    @t_Factura VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Paso 1: Actualizar facturas
        UPDATE T3.Preventa_General
        SET 
            Anulada = 'S',
            Fecha_Cancelacion = GETDATE()
        WHERE 
            Factura = @t_Factura
            AND Fecha_Cancelacion IS NULL;
        
        -- Paso 2: Si es tipo CFDI, ejecutar procedimiento
        IF EXISTS (
            SELECT 1 FROM T3.Preventa_General
            WHERE Factura = @t_Factura
            AND Clase_Factura IN ('C019', 'C0FX', 'C020', 'C021', 'C022')
        )
        BEGIN
            EXEC T3.PROC_CFDI_INSERTAR_CANCEL @t_Factura;
        END;
        
        -- Paso 3: Auditoría
        INSERT INTO T3.DEBUG_T3 
            (Fecha, Factura, Pedido, Cliente_SAP, Comentario)
        VALUES 
            (GETDATE(), @t_Factura, 'UpdFactCanc', NULL, 'Cancelacion');
        
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

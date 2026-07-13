CREATE OR ALTER PROCEDURE EAI_OWNER.WA_CANTIDAD_UMV
(
      @pMaterial      VARCHAR(50)
    , @pCantidad      DECIMAL(18,6)
    , @pUnidadMedida  VARCHAR(20)
    , @pCantUMV       DECIMAL(18,6) OUTPUT
    , @pUMV           VARCHAR(20) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE
              @UOM_CD      VARCHAR(20)
            , @X_Pack_Size DECIMAL(18,6);

        ----------------------------------------------------
        -- Valores por default
        ----------------------------------------------------
        SET @pCantUMV = @pCantidad;
        SET @pUMV     = @pUnidadMedida;

        ----------------------------------------------------
        -- Conversión de unidad
        ----------------------------------------------------
        SELECT
            @pUMV = EAI_OWNER.GETCONV('ECC_V3 UOM', @pUnidadMedida);

        ----------------------------------------------------
        -- Obtener información del material
        ----------------------------------------------------
        SELECT TOP (1)
              @UOM_CD      = Unidad_Med_Vta
            , @X_Pack_Size = Cig_x_CLL
        FROM T3.Material
        WHERE Material = @pMaterial;

        ----------------------------------------------------
        -- Conversión MIL
        ----------------------------------------------------
        IF @pUnidadMedida = 'MIL'
        BEGIN
            IF ISNULL(@X_Pack_Size,0) > 0
            BEGIN
                SET @pUMV = @UOM_CD;

                SET @pCantUMV =
                    (@pCantidad * 1000.0)
                    / @X_Pack_Size;
            END
        END

        ----------------------------------------------------
        -- Conversión PZ/PCE
        ----------------------------------------------------
        ELSE IF @pUnidadMedida IN ('PZ','PCE')
        BEGIN
            IF ISNULL(@X_Pack_Size,0) > 0
            BEGIN
                SET @pUMV = @UOM_CD;

                SET @pCantUMV =
                    @pCantidad
                    / @X_Pack_Size;
            END
        END

    END TRY
    BEGIN CATCH

        ----------------------------------------------------
        -- Comportamiento idéntico a Oracle
        ----------------------------------------------------
        SET @pCantUMV = @pCantidad;
        SET @pUMV     = @pUnidadMedida;

        /*
        Opcional:
        INSERT INTO dbo.LogErrores
        (
            Procedimiento,
            NumeroError,
            Mensaje,
            Fecha
        )
        VALUES
        (
            'WA_CANTIDAD_UMV',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            GETDATE()
        );
        */

    END CATCH
END
GO
CREATE PROCEDURE EAI.UPDATE_711_RECEPCION
(
    @t_Factura VARCHAR(4000)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nInsert INT = 0;
    DECLARE @nUpdate INT = 0;

    BEGIN TRY

        BEGIN TRANSACTION;

        ------------------------------------------------------------------
        -- UPDATE EXISTENTES
        ------------------------------------------------------------------

        UPDATE F
           SET Modificacion = GETDATE()
        FROM EAI.IFC_Folios_FE F
        INNER JOIN EAI.LDR_SHAREPOINT S
            ON F.Var_1 = S.FolioInterno
        WHERE UPPER(S.Tienda) <> 'TIENDA';

        SET @nUpdate = @@ROWCOUNT;

        ------------------------------------------------------------------
        -- INSERT NUEVOS
        ------------------------------------------------------------------

        ;WITH Nuevos AS
        (
            SELECT
                S.FolioRecepcion AS Entrada,
                'INTERFACE'      AS CreadoPor,
                GETDATE()        AS Creacion,
                S.FolioInterno   AS Var_1
            FROM EAI.LDR_SHAREPOINT S
            WHERE UPPER(S.Tienda) <> 'TIENDA'
            AND NOT EXISTS
            (
                SELECT 1
                FROM EAI.IFC_Folios_FE F
                WHERE F.Var_1 = S.FolioInterno
            )
        )
        INSERT INTO EAI.IFC_Folios_FE
        (
            Row_ID,
            Entrada,
            CreadoPor,
            Creacion,
            Var_1
        )
        SELECT
            ROW_NUMBER() OVER(ORDER BY Var_1)
            +
            ISNULL(
                (
                    SELECT MAX(Row_ID)
                    FROM EAI.IFC_Folios_FE
                    WHERE Row_ID < 1000000000
                ),
                0
            ),
            Entrada,
            CreadoPor,
            Creacion,
            Var_1
        FROM Nuevos;

        SET @nInsert = @@ROWCOUNT;

        COMMIT TRANSACTION;

        ------------------------------------------------------------------
        -- Estadísticas
        ------------------------------------------------------------------

        PRINT 'Insert : ' + CAST(@nInsert AS VARCHAR(20));
        PRINT 'Update : ' + CAST(@nUpdate AS VARCHAR(20));

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorNumber INT;

        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorNumber = ERROR_NUMBER();

        RAISERROR(
            'UPDATE_711_RECEPCION Error [%d]: %s',
            16,
            1,
            @ErrorNumber,
            @ErrorMessage
        );

    END CATCH
END
GO
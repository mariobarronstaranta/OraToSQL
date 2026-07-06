CREATE PROCEDURE EAI.INSERT_FOLIOS_FE
(
      @v_ID            VARCHAR(50),
      @v_PO_NUMBER     VARCHAR(100),
      @v_DELIVERY_REF  VARCHAR(100)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nCount BIGINT;
    DECLARE @nDate BIGINT;
    DECLARE @sMsg VARCHAR(500);

    BEGIN TRY

        BEGIN TRAN;

        ----------------------------------------------------
        -- IFC_FOLIOS_FE
        ----------------------------------------------------
        UPDATE EAI.IFC_Folios_FE
           SET Entrada      = @v_DELIVERY_REF,
               Pedido       = @v_PO_NUMBER,
               Modificacion = GETDATE()
         WHERE Var_1 = @v_ID;

        SET @nCount = @@ROWCOUNT;

        IF @nCount = 0
        BEGIN

            SET @nDate =
                CAST(CONVERT(VARCHAR(6),GETDATE(),12) AS BIGINT)
                * 10000;

            SELECT
                @nCount = COUNT(*)
            FROM EAI.IFC_Folios_FE
            WHERE Row_ID > @nDate
              AND Row_ID < (@nDate + 9999);

            SET @nCount = ISNULL(@nCount,0) + 1;

            INSERT INTO EAI.IFC_Folios_FE
            (
                Row_ID,
                Entrada,
                Pedido,
                Var_1,
                CreadoPor,
                Creacion
            )
            VALUES
            (
                @nDate + @nCount,
                @v_DELIVERY_REF,
                @v_PO_NUMBER,
                @v_ID,
                'INTERFACE',
                GETDATE()
            );
        END

        ----------------------------------------------------
        -- ENTREGA
        ----------------------------------------------------

        MERGE T3.Entrega AS T
        USING
        (
            SELECT DISTINCT
                   PG.Entrega,
                   MC.Cliente_V3,
                   MC.Cliente_SAP,
                   '1' AS Status_Entrega,
                   '0000' AS Ubicacion,
                   'U000000' AS Rep_ID,
                   CAST(GETDATE() AS DATE) AS Fecha_Entrega
            FROM T3.Preventa_General PG
                 INNER JOIN T3.Mov_Cliente MC
                    ON PG.Cliente_SAP = MC.Cliente_SAP
            WHERE PG.Factura = @v_ID
        ) S
        ON T.Factura = @v_ID

        WHEN MATCHED THEN
            UPDATE SET
                T.Entrega = S.Entrega

        WHEN NOT MATCHED THEN
            INSERT
            (
                Factura,
                Entrega,
                Fecha_Trn,
                Status_Entrega,
                Cliente_V3,
                Cliente_SAP,
                Ubicacion,
                Rep_ID,
                Fecha_Entrega
            )
            VALUES
            (
                @v_ID,
                S.Entrega,
                GETDATE(),
                S.Status_Entrega,
                S.Cliente_V3,
                S.Cliente_SAP,
                S.Ubicacion,
                S.Rep_ID,
                S.Fecha_Entrega
            );

        COMMIT;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK;

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-' +
                ERROR_MESSAGE(),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            ID,
            CREATED,
            MESSAGE,
            REFERENCE,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'Invound',
            @v_ID,
            GETDATE(),
            @sMsg,
            @v_ID,
            'Error',
            'INSERT_FOLIOS_FE',
            NULL,
            'TSQL',
            NULL,
            NULL,
            NULL,
            NULL
        );

    END CATCH
END
GO

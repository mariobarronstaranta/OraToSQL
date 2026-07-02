CREATE PROCEDURE dbo.INSERT_DEBITNOTE
(
    @v_DebitNote        VARCHAR(255),
    @v_Fecha_Proc_BATMD VARCHAR(19),
    @Var                CHAR(1) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        INSERT INTO dbo.CANCELA_DEBIT_NOTE
        (
            DebitNote,
            Fecha_Proc_BATMD
        )
        VALUES
        (
            @v_DebitNote,
            TRY_CONVERT(DATETIME2(0), @v_Fecha_Proc_BATMD, 120)
        );

        SET @Var = 'Y';

    END TRY
    BEGIN CATCH

        SET @Var = 'N';

        THROW;

    END CATCH
END
GO

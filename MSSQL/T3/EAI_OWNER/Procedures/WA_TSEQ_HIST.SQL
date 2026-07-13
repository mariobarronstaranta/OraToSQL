/*
    Homologo SQL Server de EAI_OWNER.WA_TSEQ_HIST (Oracle).

    Objetivo:
      Crear una fotografia historica de EAI_OWNER.TRANSACTION_SEQUENCE.
      Cada ejecucion copia todos los registros validos y asigna la misma fecha
      de insercion al lote completo.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_TSEQ_HIST]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sErrorCode VARCHAR(30),
        @sMsg       VARCHAR(300),
        @v_ID       VARCHAR(50),
        @Now        DATETIME2(0);

    /*
        Se captura la fecha una sola vez para identificar el lote. El formato
        112 aporta YYYYMMDD y el formato 108 aporta HH:mm:ss.
    */
    SET @Now = SYSDATETIME();
    SET @v_ID =
        CONVERT(CHAR(8), @Now, 112)
        + REPLACE(CONVERT(CHAR(8), @Now, 108), ':', '');

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO [EAI_OWNER].[TRANSACTION_SEQUENCE_HIST]
        (
            Insert_Hist,
            ID,
            Name,
            Resource_R,
            Transaction_Type,
            Sequence_Number,
            Rule_Rugex,
            LastModifiedDate,
            Extract_dt
        )
        SELECT
            @Now,
            Seq.ID,
            Seq.Name,
            Seq.Resource_R,
            Seq.Transaction_Type,
            Seq.Sequence_Number,
            Seq.Rule_Rugex,
            Seq.LastModifiedDate,
            Seq.Extract_dt
        /*
            La fila cuyo Name es NAME corresponde al encabezado del archivo de
            origen y no es un dato de negocio; Oracle tambien la excluye.
        */
        FROM [EAI_OWNER].[TRANSACTION_SEQUENCE] Seq
        WHERE Seq.Name <> 'NAME';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- El INSERT...SELECT es una sola operacion logica. Si falla, se revierte
        -- el lote completo antes de registrar la incidencia tecnica.
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction,
            Reference,
            Created,
            Message,
            Status,
            Queue_Name,
            Siebel_Error_Message,
            Source,
            Siebel_Error_Code,
            Retry_Count,
            [Sequence],
            Parent_Row_ID
        )
        VALUES
        (
            'WA Transaction Seq',
            @v_ID,
            SYSDATETIME(),
            NULL,
            'Error',
            'WA_TSEQ_HIST',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra el error y termina sin relanzar la excepcion.
        RETURN;
    END CATCH;
END;
GO

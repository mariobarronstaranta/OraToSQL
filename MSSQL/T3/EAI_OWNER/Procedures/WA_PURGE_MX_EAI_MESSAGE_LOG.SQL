CREATE OR ALTER PROCEDURE [EAI_Owner].[WA_PURGE_MX_EAI_MESSAGE_LOG]
(
    @pDias INT = 2
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
        @sErrorCode NVARCHAR(30),
        @sMsg NVARCHAR(300),
        @nPedidos INT = 0,
        @nPID INT = NULL,
        @sRowID NVARCHAR(50) = NULL,
        @CutoffDate DATETIME2(0);

    /*
        Equivalente a:
        TRUNC(SYSDATE - pDias)

        En SQL Server:
        - DATEADD(DAY, -@pDias, GETDATE()) resta días.
        - CAST(... AS date) elimina la hora.
    */
    SET @CutoffDate = CAST(DATEADD(DAY, -COALESCE(@pDias, 2), GETDATE()) AS date);

    BEGIN TRY

        -------------------------------------------------------------------------
        -- 1. Actualización de referencias para VanReplenishment
        -- Oracle:
        -- DBMS_LOB.SUBSTR(Message, 10, 409)
        -- SQL Server:
        -- SUBSTRING(Message, 409, 10)
        -------------------------------------------------------------------------
        BEGIN TRAN;

        UPDATE Err
           SET [Reference]   = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 409, 10),
               Parent_Row_ID = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 245, 16)
        FROM [EAI_Owner].[MX_EAI_Message_Log] AS Err
        WHERE Err.Queue_Name = 'VanReplenishment'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @CutoffDate
          AND Err.Parent_Row_ID IS NULL;

        -------------------------------------------------------------------------
        -- 2. Product
        -------------------------------------------------------------------------
        UPDATE Err
           SET [Reference]   = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 408, 8),
               Parent_Row_ID = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 237, 16)
        FROM [EAI_Owner].[MX_EAI_Message_Log] AS Err
        WHERE Err.Queue_Name = 'Product'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @CutoffDate
          AND Err.Parent_Row_ID IS NULL;

        -------------------------------------------------------------------------
        -- 3. Customer
        -------------------------------------------------------------------------
        UPDATE Err
           SET [Reference]   = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 399, 10),
               Parent_Row_ID = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 238, 16)
        FROM [EAI_Owner].[MX_EAI_Message_Log] AS Err
        WHERE Err.Queue_Name = 'Customer'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @CutoffDate
          AND Err.Parent_Row_ID IS NULL;

        -------------------------------------------------------------------------
        -- 4. Invoice-Intercompany
        -------------------------------------------------------------------------
        UPDATE Err
           SET [Reference]   = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 362, 10),
               Parent_Row_ID = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 248, 16)
        FROM [EAI_Owner].[MX_EAI_Message_Log] AS Err
        WHERE Err.Queue_Name = 'Invoice-Intercompany'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @CutoffDate
          AND Err.Parent_Row_ID IS NULL;

        -------------------------------------------------------------------------
        -- 5. Payment
        -------------------------------------------------------------------------
        UPDATE Err
           SET [Reference]   = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 504, 10),
               Parent_Row_ID = SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 236, 16)
        FROM [EAI_Owner].[MX_EAI_Message_Log] AS Err
        WHERE Err.Queue_Name = 'Payment'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @CutoffDate
          AND Err.Parent_Row_ID IS NULL;

        COMMIT;

        -------------------------------------------------------------------------
        -- 6. Purga set-based
        --
        -- Reemplaza:
        -- FOR Rec IN ScrPurge LOOP
        --    DELETE ... WHERE ROWID = Rec.ROWID;
        -- END LOOP;
        --
        -- SQL Server no tiene ROWID.
        -- Se elimina por equivalencia de negocio usando EXISTS.
        -------------------------------------------------------------------------
        BEGIN TRAN;

        DELETE Err
        FROM [EAI_Owner].[MX_EAI_Message_Log] AS Err
        WHERE
            (
                Err.Queue_Name = 'VanReplenishment'
                AND EXISTS
                (
                    SELECT 1
                    FROM [EAI_Owner].[tmp_Document_Header] AS Delv
                    WHERE Delv.ReferenceID = Err.[Reference]
                )
            )
            OR
            (
                Err.Queue_Name = 'Invoice'
                AND EXISTS
                (
                    SELECT 1
                    FROM [T3].[Factura_General] AS Inv
                    WHERE Inv.Entrega = Err.[Reference]
                )
            )
            OR
            (
                Err.Queue_Name = 'Invoice'
                AND EXISTS
                (
                    SELECT 1
                    FROM [T3].[Preventa_General] AS Inv
                    WHERE Inv.Entrega = Err.[Reference]
                )
            )
            OR
            (
                Err.Queue_Name = 'Invoice-Intercompany'
                AND EXISTS
                (
                    SELECT 1
                    FROM [T3].[Preventa_General] AS Inv
                    WHERE Inv.Entrega = Err.[Reference]
                )
            )
            OR
            (
                Err.Queue_Name = 'Invoice-Intercompany'
                AND EXISTS
                (
                    SELECT 1
                    FROM [T3].[Otros_General] AS Inv
                    WHERE Inv.Factura = Err.[Reference]
                )
            );

        SET @nPedidos = @@ROWCOUNT;

        COMMIT;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        /*
            Equivalente funcional al logging del EXCEPTION de Oracle.
            Se conserva la misma tabla de log.
        */
        INSERT INTO [EAI_Owner].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            [REFERENCE],
            CREATED,
            [MESSAGE],
            JOB_PID,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            [SEQUENCE],
            PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging',
            @sRowID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_PURGE_MX_EAI_MESSAGE_LOG',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH
END;
GO
/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_TSEQ_PRESALES (Oracle).

    Objetivo:
      1. Revisar las secuencias de preventa ORD y AASR por TS_RowID.
      2. Clasificar cada transicion como retroceso, repeticion o avance.
      3. Registrar los retrocesos en TRANSACTION_SEQUENCE_ERRORS.
      4. Cerrar la bitacora del componente 928 con los conteos obtenidos.

    Se conserva un cursor LOCAL FAST_FORWARD porque Oracle mantiene valores de
    estado distintos: Rule_Rugex permanece con el valor de la primera fila del
    TS_RowID, mientras Resource y Sequence avanzan con cada fila. El recorrido
    explicito evita que una conversion con LAG cambie esa regla.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_TSEQ_PRESALES]
(
    /* NUMBER permite fracciones; DECIMAL conserva dias y horas parciales. */
    @pDays      DECIMAL(10,4) = 1,
    @pDiffHours DECIMAL(10,4) = 5
)
AS
BEGIN
    SET NOCOUNT ON;

    /* Oracle confirma el trabajo previo dentro de WHEN OTHERS. */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode       VARCHAR(30),
        @sMsg             VARCHAR(300),
        @v_ID             VARCHAR(50) = NULL,
        @nFailures        INT = 0,
        @nRows            INT = 0,
        @nNotUpdated      INT = 0,
        @nUpdated         INT = 0,
        @nRange           DECIMAL(8,0),
        @nFound           INT,
        @nComponent       INT = 928,
        @nPID             BIGINT = NULL,
        @FechaCorte       DATE,

        @sTSRowIDOld      VARCHAR(100) = 'Init',
        @sTSNameOld       VARCHAR(100),
        @sTSResourceOld   VARCHAR(100),
        @sTransactionOld  VARCHAR(100),
        @nSequenceOld     DECIMAL(8,0),
        @sRuleRugexOld    VARCHAR(100),
        @sModifiedDateOld VARCHAR(100),

        @sTSRowIDNew      VARCHAR(100),
        @sTSNameNew       VARCHAR(100),
        @sTSResourceNew   VARCHAR(100),
        @sTransactionNew  VARCHAR(100),
        @nSequenceNew     DECIMAL(8,0),
        @sRuleRugexNew    VARCHAR(100),
        @sModifiedDateNew VARCHAR(100),
        @sMXModifiedDate  VARCHAR(19);

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------------------
        -- 1. Inicio del componente y de su bitacora de proceso.
        ----------------------------------------------------------------------
        EXEC [EAI_OWNER].[LOG_START]
            @nComponent = @nComponent;

        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        INSERT INTO [T3].[RF_PROCESOS_LOG]
        (
            PID,
            Proceso,
            Fecha_Proc_BATMD,
            Inicio
        )
        VALUES
        (
            @nPID,
            @nComponent,
            NULL,
            SYSDATETIME()
        );

        /*
            Equivale a TRUNC(SYSDATE - NVL(pDays, 1)). Se usan segundos para
            conservar la parte fraccionaria de pDays antes de truncar la fecha.
        */
        SET @FechaCorte = CONVERT
        (
            date,
            DATEADD
            (
                SECOND,
                CONVERT(INT, -COALESCE(@pDays, 1) * 86400),
                SYSDATETIME()
            )
        );

        ----------------------------------------------------------------------
        -- 2. Recorrido ordenado: equivalente al cursor ScrInfo de Oracle.
        ----------------------------------------------------------------------
        DECLARE ScrInfo CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                TSH.ID AS TS_RowID,
                TSH.Name AS TS_Name,
                TSH.Resource_R AS TS_Resource,
                TSH.Transaction_Type,
                /*
                    La conversion estricta reproduce la asignacion a NUMBER(8):
                    una secuencia invalida debe activar CATCH, no ser ignorada.
                */
                CONVERT(DECIMAL(8,0), TSH.Sequence_Number) AS Sequence_Number,
                TSH.Rule_Rugex,
                D.ModifiedDate,
                CONVERT
                (
                    VARCHAR(19),
                    DATEADD
                    (
                        SECOND,
                        CONVERT(INT, -COALESCE(@pDiffHours, 0) * 3600),
                        CONVERT(DATETIME2(0), D.ModifiedDate, 120)
                    ),
                    120
                ) AS MX_ModifiedDate
            FROM [EAI_OWNER].[TRANSACTION_SEQUENCE_HIST] AS TSH
            CROSS APPLY
            (
                SELECT ModifiedDate = REPLACE
                (
                    REPLACE(TSH.LastModifiedDate, '.000Z', ''),
                    'T',
                    ' '
                )
            ) AS D
            WHERE TSH.Transaction_Type IN ('ORD', 'AASR')
              /*
                  En Oracle '[' es literal. En SQL Server se escapa como '[[]'
                  para que el patron siga significando "inicia con [OV".
              */
              AND TSH.Rule_Rugex NOT LIKE '[[]OV%'
              AND TSH.Insert_Hist > @FechaCorte
            ORDER BY
                TSH.ID,
                D.ModifiedDate,
                TSH.Extract_dt;

        OPEN ScrInfo;

        FETCH NEXT FROM ScrInfo INTO
            @sTSRowIDNew,
            @sTSNameNew,
            @sTSResourceNew,
            @sTransactionNew,
            @nSequenceNew,
            @sRuleRugexNew,
            @sModifiedDateNew,
            @sMXModifiedDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* Oracle conserva el ultimo ID leido para la bitacora de error. */
            SET @v_ID = @sTSRowIDNew;

            IF @sTSRowIDOld <> @sTSRowIDNew
            BEGIN
                SET @nRows = @nRows + 1;
                SET @sTSRowIDOld = @sTSRowIDNew;
                SET @sTSNameOld = @sTSNameNew;
                SET @sTSResourceOld = @sTSResourceNew;
                SET @sTransactionOld = @sTransactionNew;
                SET @nSequenceOld = @nSequenceNew;
                SET @sRuleRugexOld = @sRuleRugexNew;
                SET @sModifiedDateOld = @sModifiedDateNew;
            END
            ELSE
            BEGIN
                SET @nRange = @nSequenceNew - @nSequenceOld;

                IF @nRange < 0
                BEGIN
                    SET @nFailures = @nFailures + 1;

                    PRINT CONCAT
                    (
                        'Rule_Rugex -> ', SUBSTRING(@sRuleRugexOld, 2, 6), '. ',
                        'Sequence -> ',
                        RIGHT(REPLICATE(' ', 6)
                              + CONVERT(VARCHAR(20), @nSequenceOld), 6),
                        ' -> ',
                        RIGHT(REPLICATE(' ', 6)
                              + CONVERT(VARCHAR(20), @nSequenceNew), 6),
                        '. Updated -> ', @sMXModifiedDate, '. ',
                        'Resource -> ', @sTSResourceOld
                    );

                    /*
                        Se actualiza primero. Solo cuando no existe la llave
                        funcional se inserta una nueva falla, igual que Oracle.
                    */
                    UPDATE [EAI_OWNER].[TRANSACTION_SEQUENCE_ERRORS]
                       SET UpdatedOn = SYSDATETIME()
                    WHERE Rule_Rugex = SUBSTRING(@sRuleRugexOld, 2, 6)
                      AND LastUpdated = @sMXModifiedDate
                      AND ResourceName = @sTSResourceOld;

                    SET @nFound = @@ROWCOUNT;

                    IF @nFound = 0
                    BEGIN
                        INSERT INTO [EAI_OWNER].[TRANSACTION_SEQUENCE_ERRORS]
                        (
                            Rule_Rugex,
                            Seq_Prev,
                            Seq_Next,
                            LastUpdated,
                            ResourceName,
                            CreatedOn
                        )
                        VALUES
                        (
                            SUBSTRING(@sRuleRugexOld, 2, 6),
                            @nSequenceOld,
                            @nSequenceNew,
                            @sMXModifiedDate,
                            @sTSResourceOld,
                            SYSDATETIME()
                        );
                    END;
                END
                ELSE IF @nRange = 0
                    SET @nNotUpdated = @nNotUpdated + 1;
                ELSE
                    SET @nUpdated = @nUpdated + 1;

                /*
                    Rule_Rugex no se actualiza aqui: Oracle conserva el de la
                    primera fila. Resource, Sequence y ModifiedDate si avanzan.
                */
                SET @sTSResourceOld = @sTSResourceNew;
                SET @nSequenceOld = @nSequenceNew;
                SET @sModifiedDateOld = @sModifiedDateNew;
            END;

            FETCH NEXT FROM ScrInfo INTO
                @sTSRowIDNew,
                @sTSNameNew,
                @sTSResourceNew,
                @sTransactionNew,
                @nSequenceNew,
                @sRuleRugexNew,
                @sModifiedDateNew,
                @sMXModifiedDate;
        END;

        CLOSE ScrInfo;
        DEALLOCATE ScrInfo;

        ----------------------------------------------------------------------
        -- 3. Resumen y cierre de la bitacora del componente 928.
        ----------------------------------------------------------------------
        PRINT '--------------------------------';
        PRINT CONCAT('TSeq Reviewed -> ', @nRows);
        PRINT CONCAT('Failures      -> ', @nFailures);
        PRINT CONCAT('NotUpdated    -> ', @nNotUpdated);
        PRINT CONCAT('Updated Ok    -> ', @nUpdated);

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET Status = 1
        WHERE Component = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = SYSDATETIME(),
               Proceso_1 = @nRows,
               Proceso_2 = @nFailures,
               Proceso_3 = @nNotUpdated,
               Proceso_4 = @nUpdated
        WHERE PID = @nPID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        /*
            Si la transaccion no es confirmable se revierte antes de registrar
            el error. Si aun es valida, el COMMIT conserva el trabajo previo,
            reproduciendo el WHEN OTHERS de Oracle.
        */
        IF XACT_STATE() = -1
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
            'WA_ERR_TSEQ_PRESALES',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- Oracle registra el error y finaliza sin volver a lanzarlo.
        RETURN;
    END CATCH;
END;
GO

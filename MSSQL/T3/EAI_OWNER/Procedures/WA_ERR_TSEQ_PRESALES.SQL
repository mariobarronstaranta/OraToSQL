CREATE OR ALTER PROCEDURE [dbo].[WA_ERR_TSEQ_PRESALES]
(
    @pDays      INT = 1,
    @pDiffHours INT = 5
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
        @sErrorCode       VARCHAR(30),
        @sMsg             VARCHAR(300),
        @v_ID             VARCHAR(50),
        @nFailures        INT = 0,
        @nRows            INT = 0,
        @nNotUpdated      INT = 0,
        @nUpdated         INT = 0,N
        @nComponent       INT = 928,
        @nPID             BIGINT;

    /*
        Tabla temporal de fallas detectadas.
        Se conserva el identificador anterior de Rule_Rugex, Sequence_Number y Resource,
        porque la lógica Oracle registra la falla comparando el registro actual contra el previo.
    */
    DECLARE @Failures TABLE
    (
        FailureID              INT IDENTITY(1,1) PRIMARY KEY,
        TS_RowID               VARCHAR(100) NULL,
        Rule_Rugex             VARCHAR(100) NULL,
        Rule_Rugex_Key         VARCHAR(6)   NULL,
        Seq_Prev               INT          NULL,
        Seq_Next               INT          NULL,
        LastUpdated            VARCHAR(19)  NULL,
        ResourceName           VARCHAR(100) NULL,
        UpdatedRows            INT          NOT NULL DEFAULT 0
    );

    BEGIN TRY
        BEGIN TRAN;

        /*
            Equivalente a:
            Log_Start(nComponent);
        */
        EXEC [dbo].[Log_Start] @nComponent;

        /*
            Equivalente a:
            EAI_Owner.ProcessID.NextVal
        */
        SELECT @nPID = NEXT VALUE FOR [EAI_Owner].[ProcessID];

        INSERT INTO [T3].[RF_PROCESOS_LOG]
        (
            [PID],
            [Proceso],
            [Fecha_Proc_BATMD],
            [Inicio]
        )
        VALUES
        (
            @nPID,
            @nComponent,
            NULL,
            SYSDATETIME()
        );

        /*
            Fuente normalizada.
            Nota crítica:
            Oracle:
                TSH.Rule_Rugex NOT LIKE '[OV%'
            En Oracle '[' no es wildcard especial para LIKE.
            En SQL Server '[' inicia una expresión de patrón.
            Para preservar la lógica original se usa:
                NOT LIKE '[[]OV%'
            Esto significa: no inicia con el literal '[OV'.
        */
        ;WITH SourceInfo AS
        (
            SELECT
                CAST(TSH.[ID] AS VARCHAR(100))                  AS TS_RowID,
                CAST(TSH.[Name] AS VARCHAR(100))                AS TS_Name,
                CAST(TSH.[Resource_R] AS VARCHAR(100))          AS TS_Resource,
                CAST(TSH.[Transaction_Type] AS VARCHAR(100))    AS Transaction_Type,
                TRY_CONVERT(INT, TSH.[Sequence_Number])         AS Sequence_Number,
                CAST(TSH.[Rule_Rugex] AS VARCHAR(100))          AS Rule_Rugex,

                REPLACE(
                    REPLACE(CAST(TSH.[LastModifiedDate] AS VARCHAR(50)), '.000Z', ''),
                    'T',
                    ' '
                ) AS ModifiedDate,

                CONVERT
                (
                    VARCHAR(19),
                    DATEADD
                    (
                        HOUR,
                        -COALESCE(@pDiffHours, 0),
                        TRY_CONVERT
                        (
                            DATETIME2(0),
                            REPLACE
                            (
                                REPLACE(CAST(TSH.[LastModifiedDate] AS VARCHAR(50)), '.000Z', ''),
                                'T',
                                ' '
                            ),
                            120
                        )
                    ),
                    120
                ) AS MX_ModifiedDate,

                TSH.[Extract_dt]
            FROM [EAI_Owner].[Transaction_Sequence_Hist] AS TSH
            WHERE TSH.[Transaction_Type] IN ('ORD', 'AASR')
              AND TSH.[Rule_Rugex] NOT LIKE '[[]OV%'
              AND TSH.[Insert_Hist] > CAST(DATEADD(DAY, -COALESCE(@pDays, 1), SYSDATETIME()) AS DATE)
        ),
        OrderedInfo AS
        (
            SELECT
                SI.*,

                LAG(SI.TS_Resource) OVER
                (
                    PARTITION BY SI.TS_RowID
                    ORDER BY SI.ModifiedDate, SI.Extract_dt
                ) AS Prev_TS_Resource,

                LAG(SI.Sequence_Number) OVER
                (
                    PARTITION BY SI.TS_RowID
                    ORDER BY SI.ModifiedDate, SI.Extract_dt
                ) AS Prev_Sequence_Number,

                LAG(SI.Rule_Rugex) OVER
                (
                    PARTITION BY SI.TS_RowID
                    ORDER BY SI.ModifiedDate, SI.Extract_dt
                ) AS Prev_Rule_Rugex,

                LAG(SI.ModifiedDate) OVER
                (
                    PARTITION BY SI.TS_RowID
                    ORDER BY SI.ModifiedDate, SI.Extract_dt
                ) AS Prev_ModifiedDate
            FROM SourceInfo AS SI
        ),
        Compared AS
        (
            SELECT
                OI.*,
                OI.Sequence_Number - OI.Prev_Sequence_Number AS SeqRange
            FROM OrderedInfo AS OI
            WHERE OI.Prev_Sequence_Number IS NOT NULL
        )
        INSERT INTO @Failures
        (
            TS_RowID,
            Rule_Rugex,
            Rule_Rugex_Key,
            Seq_Prev,
            Seq_Next,
            LastUpdated,
            ResourceName
        )
        SELECT
            C.TS_RowID,
            C.Prev_Rule_Rugex,
            SUBSTRING(C.Prev_Rule_Rugex, 2, 6),
            C.Prev_Sequence_Number,
            C.Sequence_Number,
            C.MX_ModifiedDate,
            C.Prev_TS_Resource
        FROM Compared AS C
        WHERE C.SeqRange < 0;

        /*
            Conteos equivalentes a los acumuladores del cursor Oracle.
        */
        ;WITH SourceInfo AS
        (
            SELECT
                CAST(TSH.[ID] AS VARCHAR(100)) AS TS_RowID,
                TRY_CONVERT(INT, TSH.[Sequence_Number]) AS Sequence_Number,
                REPLACE(
                    REPLACE(CAST(TSH.[LastModifiedDate] AS VARCHAR(50)), '.000Z', ''),
                    'T',
                    ' '
                ) AS ModifiedDate,
                TSH.[Extract_dt]
            FROM [EAI_Owner].[Transaction_Sequence_Hist] AS TSH
            WHERE TSH.[Transaction_Type] IN ('ORD', 'AASR')
              AND TSH.[Rule_Rugex] NOT LIKE '[[]OV%'
              AND TSH.[Insert_Hist] > CAST(DATEADD(DAY, -COALESCE(@pDays, 1), SYSDATETIME()) AS DATE)
        ),
        OrderedInfo AS
        (
            SELECT
                SI.*,
                LAG(SI.Sequence_Number) OVER
                (
                    PARTITION BY SI.TS_RowID
                    ORDER BY SI.ModifiedDate, SI.Extract_dt
                ) AS Prev_Sequence_Number
            FROM SourceInfo AS SI
        ),
        Compared AS
        (
            SELECT
                OI.TS_RowID,
                OI.Sequence_Number - OI.Prev_Sequence_Number AS SeqRange
            FROM OrderedInfo AS OI
            WHERE OI.Prev_Sequence_Number IS NOT NULL
        )
        SELECT
            @nRows       = (SELECT COUNT(DISTINCT TS_RowID) FROM SourceInfo),
            @nFailures   = (SELECT COUNT(*) FROM Compared WHERE SeqRange < 0),
            @nNotUpdated = (SELECT COUNT(*) FROM Compared WHERE SeqRange = 0),
            @nUpdated    = (SELECT COUNT(*) FROM Compared WHERE SeqRange > 0);

        /*
            Referencia para logging en caso de error.
            Equivalente aproximado a v_ID := Seq.TS_RowID.
        */
        SELECT TOP (1)
            @v_ID = TS_RowID
        FROM @Failures
        ORDER BY FailureID DESC;

        /*
            Primero actualiza errores existentes.
            Equivalente a:
            UPDATE Transaction_Sequence_Errors
               SET UpdatedOn = SYSDATE
             WHERE Rule_Rugex = ...
               AND LastUpdated = ...
               AND ResourceName = ...
        */
        UPDATE E
            SET E.[UpdatedOn] = SYSDATETIME()
        FROM [EAI_Owner].[Transaction_Sequence_Errors] AS E
        INNER JOIN @Failures AS F
            ON E.[Rule_Rugex]   = F.Rule_Rugex_Key
           AND E.[LastUpdated]  = F.LastUpdated
           AND E.[ResourceName] = F.ResourceName;

        /*
            Inserta únicamente fallas que no existían.
            Se usa SELECT DISTINCT para evitar duplicados si el histórico trae eventos repetidos
            con la misma llave funcional.
        */
        INSERT INTO [EAI_Owner].[Transaction_Sequence_Errors]
        (
            [Rule_Rugex],
            [Seq_Prev],
            [Seq_Next],
            [LastUpdated],
            [ResourceName],
            [CreatedOn]
        )
        SELECT DISTINCT
            F.Rule_Rugex_Key,
            F.Seq_Prev,
            F.Seq_Next,
            F.LastUpdated,
            F.ResourceName,
            SYSDATETIME()
        FROM @Failures AS F
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [EAI_Owner].[Transaction_Sequence_Errors] AS E
            WHERE E.[Rule_Rugex]   = F.Rule_Rugex_Key
              AND E.[LastUpdated]  = F.LastUpdated
              AND E.[ResourceName] = F.ResourceName
        );

        /*
            Equivalente a DBMS_OUTPUT.PUT_LINE.
            PRINT es informativo; para auditoría formal ya existe RF_PROCESOS_LOG.
        */
        PRINT '--------------------------------';
        PRINT CONCAT('TSeq Reviewed -> ', @nRows);
        PRINT CONCAT('Failures      -> ', @nFailures);
        PRINT CONCAT('NotUpdated    -> ', @nNotUpdated);
        PRINT CONCAT('Updated Ok    -> ', @nUpdated);

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
            SET [Status] = 1
        WHERE [Component] = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
            SET [Fin]       = SYSDATETIME(),
                [Proceso_1] = @nRows,
                [Proceso_2] = @nFailures,
                [Proceso_3] = @nNotUpdated,
                [Proceso_4] = @nUpdated
        WHERE [PID] = @nPID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        /*
            Se registra el error fuera de la transacción principal,
            imitando el comportamiento Oracle que hace COMMIT en el EXCEPTION.
        */
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            [DIRECTION],
            [REFERENCE],
            [CREATED],
            [MESSAGE],
            [STATUS],
            [QUEUE_NAME],
            [SIEBEL_ERROR_MESSAGE],
            [SOURCE],
            [SIEBEL_ERROR_CODE],
            [RETRY_COUNT],
            [SEQUENCE],
            [PARENT_ROW_ID]
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

        /*
            Si se desea comportamiento idéntico a Oracle, no relanzar el error.
            Si se desea que el job falle en SQL Agent, descomentar THROW.
        */
        -- THROW;
    END CATCH;
END;
GO
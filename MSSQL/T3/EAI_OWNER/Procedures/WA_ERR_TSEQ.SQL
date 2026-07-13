CREATE OR ALTER PROCEDURE [dbo].[WA_ERR_TSEQ]
(
    @pDays      INT = 1,
    @pDiffHours INT = 5
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode       VARCHAR(30),
        @sMsg             VARCHAR(300),
        @v_ID             VARCHAR(50),
        @nFailures        INT = 0,
        @nRows            INT = 0,
        @nNotUpdated      INT = 0,
        @nUpdated         INT = 0,
        @nComponent       INT = 927,
        @nPID             BIGINT,
        @Now              DATETIME2(0) = SYSDATETIME();

    /*
        Tabla temporal de trabajo.
        Reemplaza el cursor Oracle ScrInfo y permite comparar secuencias
        con LAG() respetando el orden:
        TS_RowID, ModifiedDate, Extract_dt.
    */
    DECLARE @SeqWork TABLE
    (
        RowNum                    BIGINT IDENTITY(1,1) PRIMARY KEY,
        TS_RowID                  VARCHAR(100),
        TS_Name                   VARCHAR(100),
        TS_Resource               VARCHAR(100),
        Transaction_Type          VARCHAR(100),
        Sequence_Number           INT,
        Rule_Rugex                VARCHAR(100),
        ModifiedDateText          VARCHAR(19),
        ModifiedDateValue         DATETIME2(0),
        MX_ModifiedDate           VARCHAR(19),
        Extract_dt                DATETIME2(0) NULL,

        Prev_TS_RowID             VARCHAR(100) NULL,
        Prev_TS_Name              VARCHAR(100) NULL,
        Prev_TS_Resource          VARCHAR(100) NULL,
        Prev_Transaction_Type     VARCHAR(100) NULL,
        Prev_Sequence_Number      INT NULL,
        Prev_Rule_Rugex           VARCHAR(100) NULL,
        Prev_ModifiedDateText     VARCHAR(19) NULL,

        Seq_Range                 INT NULL
    );

    DECLARE @Failures TABLE
    (
        Rule_Rugex       VARCHAR(5),
        Seq_Prev         INT,
        Seq_Next         INT,
        LastUpdated      VARCHAR(19),
        ResourceName     VARCHAR(100),
        DetailMessage    VARCHAR(500)
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        /*
            Inicio de log de componente.
            Ajustar schema si Log_Start no vive en dbo.
        */
        EXEC [dbo].[Log_Start] @nComponent;

        /*
            Equivalente a:
            nPID := EAI_Owner.ProcessID.NextVal;
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
            @Now
        );

        /*
            Carga de datos fuente.
            Equivalente a cursor ScrInfo, pero con conversión explícita de fecha.
        */
        ;WITH SourceInfo AS
        (
            SELECT
                CAST(TSH.[ID] AS VARCHAR(100))                         AS TS_RowID,
                CAST(TSH.[Name] AS VARCHAR(100))                       AS TS_Name,
                CAST(TSH.[Resource_R] AS VARCHAR(100))                 AS TS_Resource,
                CAST(TSH.[Transaction_Type] AS VARCHAR(100))           AS Transaction_Type,
                CAST(TSH.[Sequence_Number] AS INT)                     AS Sequence_Number,
                CAST(TSH.[Rule_Rugex] AS VARCHAR(100))                 AS Rule_Rugex,

                REPLACE(
                    REPLACE(CAST(TSH.[LastModifiedDate] AS VARCHAR(50)), '.000Z', ''),
                    'T',
                    ' '
                )                                                       AS ModifiedDateText,

                TRY_CONVERT(
                    DATETIME2(0),
                    REPLACE(
                        REPLACE(CAST(TSH.[LastModifiedDate] AS VARCHAR(50)), '.000Z', ''),
                        'T',
                        ' '
                    ),
                    120
                )                                                       AS ModifiedDateValue,

                CAST(TSH.[Extract_dt] AS DATETIME2(0))                 AS Extract_dt
            FROM [EAI_Owner].[Transaction_Sequence_Hist] TSH
            WHERE TSH.[Transaction_Type] IN ('INV', 'SR')
              AND TSH.[Insert_Hist] >
                    CAST(
                        DATEADD(DAY, -COALESCE(@pDays, 1), SYSDATETIME())
                        AS DATE
                    )
        ),
        OrderedInfo AS
        (
            SELECT
                SI.TS_RowID,
                SI.TS_Name,
                SI.TS_Resource,
                SI.Transaction_Type,
                SI.Sequence_Number,
                SI.Rule_Rugex,
                SI.ModifiedDateText,
                SI.ModifiedDateValue,
                CONVERT(
                    VARCHAR(19),
                    DATEADD(HOUR, -COALESCE(@pDiffHours, 0), SI.ModifiedDateValue),
                    120
                )                                                       AS MX_ModifiedDate,
                SI.Extract_dt,

                LAG(SI.TS_RowID)
                    OVER
                    (
                        PARTITION BY SI.TS_RowID
                        ORDER BY SI.ModifiedDateValue, SI.Extract_dt
                    )                                                   AS Prev_TS_RowID,

                LAG(SI.TS_Name)
                    OVER
                    (
                        PARTITION BY SI.TS_RowID
                        ORDER BY SI.ModifiedDateValue, SI.Extract_dt
                    )                                                   AS Prev_TS_Name,

                LAG(SI.TS_Resource)
                    OVER
                    (
                        PARTITION BY SI.TS_RowID
                        ORDER BY SI.ModifiedDateValue, SI.Extract_dt
                    )                                                   AS Prev_TS_Resource,

                LAG(SI.Transaction_Type)
                    OVER
                    (
                        PARTITION BY SI.TS_RowID
                        ORDER BY SI.ModifiedDateValue, SI.Extract_dt
                    )                                                   AS Prev_Transaction_Type,

                LAG(SI.Sequence_Number)
                    OVER
                    (
                        PARTITION BY SI.TS_RowID
                        ORDER BY SI.ModifiedDateValue, SI.Extract_dt
                    )                                                   AS Prev_Sequence_Number,

                LAG(SI.Rule_Rugex)
                    OVER
                    (
                        PARTITION BY SI.TS_RowID
                        ORDER BY SI.ModifiedDateValue, SI.Extract_dt
                    )                                                   AS Prev_Rule_Rugex,

                LAG(SI.ModifiedDateText)
                    OVER
                    (
                        PARTITION BY SI.TS_RowID
                        ORDER BY SI.ModifiedDateValue, SI.Extract_dt
                    )                                                   AS Prev_ModifiedDateText
            FROM SourceInfo SI
            WHERE SI.ModifiedDateValue IS NOT NULL
        )
        INSERT INTO @SeqWork
        (
            TS_RowID,
            TS_Name,
            TS_Resource,
            Transaction_Type,
            Sequence_Number,
            Rule_Rugex,
            ModifiedDateText,
            ModifiedDateValue,
            MX_ModifiedDate,
            Extract_dt,
            Prev_TS_RowID,
            Prev_TS_Name,
            Prev_TS_Resource,
            Prev_Transaction_Type,
            Prev_Sequence_Number,
            Prev_Rule_Rugex,
            Prev_ModifiedDateText,
            Seq_Range
        )
        SELECT
            OI.TS_RowID,
            OI.TS_Name,
            OI.TS_Resource,
            OI.Transaction_Type,
            OI.Sequence_Number,
            OI.Rule_Rugex,
            OI.ModifiedDateText,
            OI.ModifiedDateValue,
            OI.MX_ModifiedDate,
            OI.Extract_dt,
            OI.Prev_TS_RowID,
            OI.Prev_TS_Name,
            OI.Prev_TS_Resource,
            OI.Prev_Transaction_Type,
            OI.Prev_Sequence_Number,
            OI.Prev_Rule_Rugex,
            OI.Prev_ModifiedDateText,
            CASE
                WHEN OI.Prev_Sequence_Number IS NULL THEN NULL
                ELSE OI.Sequence_Number - OI.Prev_Sequence_Number
            END AS Seq_Range
        FROM OrderedInfo OI
        ORDER BY
            OI.TS_RowID,
            OI.ModifiedDateValue,
            OI.Extract_dt;

        /*
            Equivalente a nRows:
            En Oracle se incrementa una vez por cada nuevo TS_RowID.
        */
        SELECT
            @nRows = COUNT(DISTINCT TS_RowID)
        FROM @SeqWork;

        /*
            Último ID procesado para usarlo en el log de error.
        */
        SELECT TOP (1)
            @v_ID = TS_RowID
        FROM @SeqWork
        ORDER BY RowNum DESC;

        /*
            Conteos equivalentes:
            nFailures   => Seq_Range < 0
            nNotUpdated => Seq_Range = 0
            nUpdated    => Seq_Range > 0
        */
        SELECT
            @nFailures =
                SUM(CASE WHEN Seq_Range < 0 THEN 1 ELSE 0 END),
            @nNotUpdated =
                SUM(CASE WHEN Seq_Range = 0 THEN 1 ELSE 0 END),
            @nUpdated =
                SUM(CASE WHEN Seq_Range > 0 THEN 1 ELSE 0 END)
        FROM @SeqWork
        WHERE Prev_Sequence_Number IS NOT NULL;

        SELECT
            @nFailures   = COALESCE(@nFailures, 0),
            @nNotUpdated = COALESCE(@nNotUpdated, 0),
            @nUpdated    = COALESCE(@nUpdated, 0);

        /*
            Preparar detalle de fallas.
            Preserva la lógica Oracle:
            Rule_Rugex   = SUBSTR(sRule_Rugex_Old, 2, 5)
            Seq_Prev     = nSequence_Number_Old
            Seq_Next     = nSequence_Number_New
            LastUpdated  = Seq.MX_ModifiedDate
            ResourceName = sTS_Resource_Old
        */
        INSERT INTO @Failures
        (
            Rule_Rugex,
            Seq_Prev,
            Seq_Next,
            LastUpdated,
            ResourceName,
            DetailMessage
        )
        SELECT
            SUBSTRING(SW.Prev_Rule_Rugex, 2, 5) AS Rule_Rugex,
            SW.Prev_Sequence_Number             AS Seq_Prev,
            SW.Sequence_Number                  AS Seq_Next,
            SW.MX_ModifiedDate                  AS LastUpdated,
            SW.Prev_TS_Resource                 AS ResourceName,
            CONCAT(
                'Rule_Rugex -> ', SUBSTRING(SW.Prev_Rule_Rugex, 2, 5), '. ',
                'Sequence -> ',
                    RIGHT(REPLICATE(' ', 6) + CAST(SW.Prev_Sequence_Number AS VARCHAR(20)), 6),
                    ' -> ',
                    RIGHT(REPLICATE(' ', 6) + CAST(SW.Sequence_Number AS VARCHAR(20)), 6),
                    '. ',
                'Updated -> ', SW.MX_ModifiedDate, '. ',
                'Resource -> ', SW.Prev_TS_Resource
            ) AS DetailMessage
        FROM @SeqWork SW
        WHERE SW.Seq_Range < 0;

        /*
            Primero actualiza errores existentes.
            Equivalente al UPDATE dentro del cursor.
        */
        UPDATE TSE
            SET TSE.[UpdatedOn] = SYSDATETIME()
        FROM [EAI_Owner].[Transaction_Sequence_Errors] TSE
        INNER JOIN @Failures F
            ON TSE.[Rule_Rugex]   = F.Rule_Rugex
           AND TSE.[LastUpdated]  = F.LastUpdated
           AND TSE.[ResourceName] = F.ResourceName;

        /*
            Inserta sólo los errores que no existían.
            Equivalente al IF SQL%ROWCOUNT = 0 THEN INSERT.
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
        SELECT
            F.Rule_Rugex,
            F.Seq_Prev,
            F.Seq_Next,
            F.LastUpdated,
            F.ResourceName,
            SYSDATETIME()
        FROM @Failures F
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [EAI_Owner].[Transaction_Sequence_Errors] TSE
            WHERE TSE.[Rule_Rugex]   = F.Rule_Rugex
              AND TSE.[LastUpdated]  = F.LastUpdated
              AND TSE.[ResourceName] = F.ResourceName
        );

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
            SET [Status] = 1
        WHERE [Component] = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
            SET
                [Fin]       = SYSDATETIME(),
                [Proceso_1] = @nRows,
                [Proceso_2] = @nFailures,
                [Proceso_3] = @nNotUpdated,
                [Proceso_4] = @nUpdated
        WHERE [PID] = @nPID;

        COMMIT TRANSACTION;

        /*
            Sustituto de DBMS_OUTPUT.
        */
        SELECT
            'WA_ERR_TSEQ' AS ProcedureName,
            @nRows        AS TSeq_Reviewed,
            @nFailures    AS Failures,
            @nNotUpdated  AS NotUpdated,
            @nUpdated     AS UpdatedOk;

        SELECT
            Rule_Rugex,
            Seq_Prev,
            Seq_Next,
            LastUpdated,
            ResourceName,
            DetailMessage
        FROM @Failures
        ORDER BY
            ResourceName,
            LastUpdated,
            Rule_Rugex;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        /*
            Equivalente al INSERT en MX_EAI_MESSAGE_LOG dentro de EXCEPTION.
            Se realiza fuera de la transacción fallida.
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
            'WA_ERR_TSEQ',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        /*
            Conserva el comportamiento Oracle de registrar el error.
            Se relanza para que scheduler/monitoring detecte falla.
            Si se desea imitar Oracle exactamente y NO relanzar,
            comentar el THROW.
        */
        THROW;
    END CATCH
END;
GO
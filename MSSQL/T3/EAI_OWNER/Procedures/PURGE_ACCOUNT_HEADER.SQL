/*
    Procedure : EAI_OWNER.PURGE_ACCOUNT_HEADER
    Objetivo  : Eliminar encabezados contables temporales por ventanas de días.
    Entradas  : Fecha inicial, fecha final y tamaño opcional de ventana (7 días).
    Auditoría : Cada ventana registra inicio, fin y número de filas eliminadas
                en MX_PURGE_LEGDB_LOG.
    Integridad: Cada ventana se procesa en una transacción independiente para
                que el DELETE y su bitácora se confirmen o reviertan juntos.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.PURGE_ACCOUNT_HEADER
(
      @dtStartingPurge DATE
    , @dtEndingPurge   DATE
    , @nDiasIntervalo  INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @dtStarting DATE
        , @dtEnding DATE
        , @nIteracion INT
        , @nPeriod INT
        , @nSequence BIGINT
        , @nRecords INT
        , @sPeriod VARCHAR(20)
        , @sStage VARCHAR(40)
        , @sMsg VARCHAR(500)
        , @sErrorCode VARCHAR(20);

    BEGIN TRY

        SET @nPeriod = COALESCE(@nDiasIntervalo, 7);
        SET @nIteracion = 0;

        -- Evita ciclos infinitos y garantiza que ningún DELETE se ejecute con
        -- una ventana incompleta o invertida por un intervalo inválido.
        IF @dtStartingPurge IS NULL OR @dtEndingPurge IS NULL OR @nPeriod <= 0
            THROW 50010, 'Las fechas son obligatorias y el intervalo debe ser mayor que cero.', 1;

        SET @dtStarting = DATEADD(DAY,-@nPeriod,@dtStartingPurge);

        WHILE (1 = 1)
        BEGIN

            SET @dtStarting = DATEADD(DAY,@nPeriod,@dtStarting);

            IF (@dtStarting > @dtEndingPurge)
                BREAK;

            SET @dtEnding = DATEADD(DAY,@nPeriod,@dtStarting);

            IF (@dtEnding > @dtEndingPurge)
                SET @dtEnding = @dtEndingPurge;

            SET @nIteracion += 1;

            SET @sPeriod =
                CONVERT(VARCHAR(8),@dtStarting,112)
                + '-'
                + CONVERT(VARCHAR(8),@dtEnding,112);

            SET @sStage = 'ACCOUNT_HEADER';

            -- La bitácora y la eliminación forman una sola unidad: no debe
            -- existir una purga sin su conteo final, ni una bitácora sin purga.
            BEGIN TRANSACTION;

            -- La secuencia pertenece a EAI_OWNER, igual que en Oracle.
            SET @nSequence =
                NEXT VALUE FOR EAI_OWNER.Seq_Purge_LEGDB;

            INSERT INTO EAI_OWNER.MX_PURGE_LEGDB_LOG
            (
                  PID
                , Time_Window
                , Process
                , Starting
                , Ending
            )
            VALUES
            (
                  @nSequence
                , @sPeriod
                , @sStage
                , GETDATE()
                , NULL
            );

            -- El límite superior incluye todo el último día de la ventana sin
            -- aplicar una función sobre Created, permitiendo usar un índice.
            DELETE FROM EAI_OWNER.TMP_ACCOUNT_HEADER
            WHERE Created >= @dtStarting
              AND Created < DATEADD(DAY,1,@dtEnding);

            SET @nRecords = @@ROWCOUNT;

            UPDATE EAI_OWNER.MX_PURGE_LEGDB_LOG
               SET Ending  = GETDATE(),
                   Records = @nRecords
             WHERE PID = @nSequence;

            COMMIT TRANSACTION;

        END;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CONCAT(
                    ERROR_NUMBER(),
                    '-',
                    ERROR_MESSAGE()
                ),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
              DIRECTION
            , ID
            , CREATED
            , MESSAGE
            , STATUS
            , QUEUE_NAME
            , SIEBEL_ERROR_MESSAGE
            , SOURCE
            , SIEBEL_ERROR_CODE
            , RETRY_COUNT
            , SEQUENCE
            , PARENT_ROW_ID
        )
        VALUES
        (
              'Purge'
            , NULL
            , GETDATE()
            , NULL
            , 'Error'
            , 'Account_Header'
            , @sMsg
            , 'Purge'
            , @sErrorCode
            , NULL
            , NULL
            , NULL
        );

    END CATCH
END;
GO

/*
    Homologo SQL Server de EAI_OWNER.WA_RUN_STATEMENTS (Oracle).

    Objetivo:
      Ejecutar, en orden, las instrucciones configuradas en WA_STATEMENTS a
      partir del nivel solicitado. Despues de cada ejecucion se registra el
      numero de filas afectadas en WA_LOGS y se confirma ese paso.

    Advertencia:
      Este procedimiento ejecuta SQL dinamico almacenado en una tabla. El
      acceso para modificar WA_STATEMENTS debe limitarse a personal autorizado.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_RUN_STATEMENTS]
    @pLevel INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    -- Se usa OFF para poder controlar y registrar el error del paso actual.
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode          VARCHAR(30),
        @sMsg                VARCHAR(300),
        @nPedidos            INT = 0,
        @nPID                BIGINT,
        @nProceso            INT = 831,
        @sReference          VARCHAR(50),
        @sStatement          NVARCHAR(2000),
        @nSQL_Rows           INT,
        @Execution_Step      NUMERIC(6, 0),
        @Execution_Statement VARCHAR(2000),
        @StepText            VARCHAR(20),
        @DynamicSql          NVARCHAR(MAX);

    BEGIN TRY
        ----------------------------------------------------------------------
        -- 1. Inicio y auditoria del proceso 831
        ----------------------------------------------------------------------
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, SYSDATETIME());

        ----------------------------------------------------------------------
        -- 2. Recuperar instrucciones desde el nivel solicitado
        ----------------------------------------------------------------------
        DECLARE ScrStatements CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                Execution_Step,
                Execution_Statement
            FROM [EAI_OWNER].[WA_STATEMENTS]
            WHERE Execution_Step >= ISNULL(@pLevel, 0)
            ORDER BY Execution_Step;

        OPEN ScrStatements;

        FETCH NEXT FROM ScrStatements
        INTO @Execution_Step, @Execution_Statement;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /*
                Equivalencia de 'Step-' || LPAD(Execution_Step, 4, '0').
                LPAD recorta por la derecha cuando el valor excede la longitud;
                por eso se utiliza LEFT para pasos de cinco o mas caracteres.
            */
            SET @StepText = CONVERT(VARCHAR(20), @Execution_Step);
            SET @sReference = CONCAT
            (
                'Step-',
                CASE
                    WHEN LEN(@StepText) >= 4 THEN LEFT(@StepText, 4)
                    ELSE RIGHT(CONCAT('0000', @StepText), 4)
                END
            );

            SET @sStatement = CONVERT(NVARCHAR(2000), @Execution_Statement);
            SET @nSQL_Rows = 0;

            -- Oracle considera una cadena vacia como NULL y EXECUTE IMMEDIATE
            -- genera error. Se valida expresamente para conservar esa regla.
            IF @sStatement IS NULL OR @sStatement = N''
                THROW 50001, 'WA_STATEMENTS contiene una instruccion vacia.', 1;

            BEGIN TRY
                /*
                    Cada paso tiene su propia transaccion, igual que el COMMIT
                    dentro del ciclo Oracle. Por tanto, un error posterior no
                    revierte los pasos que ya finalizaron correctamente.
                */
                BEGIN TRANSACTION;

                /*
                    @@ROWCOUNT debe capturarse dentro del mismo lote dinamico e
                    inmediatamente despues de la instruccion configurada.
                    El salto de linea evita que un comentario final -- oculte
                    la asignacion de @RowsOut.
                */
                SET @DynamicSql =
                    @sStatement
                    + NCHAR(13) + NCHAR(10)
                    + N';SET @RowsOut = @@ROWCOUNT;';

                EXEC sys.sp_executesql
                    @DynamicSql,
                    N'@RowsOut INT OUTPUT',
                    @RowsOut = @nSQL_Rows OUTPUT;

                INSERT INTO [EAI_OWNER].[WA_LOGS]
                    (Execution_Date, Execution_Step, Execution_Records)
                VALUES
                    (SYSDATETIME(), @Execution_Step, @nSQL_Rows);

                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                IF XACT_STATE() <> 0
                    ROLLBACK TRANSACTION;

                -- El CATCH externo registra el paso exacto que fallo.
                THROW;
            END CATCH;

            FETCH NEXT FROM ScrStatements
            INTO @Execution_Step, @Execution_Statement;
        END;

        CLOSE ScrStatements;
        DEALLOCATE ScrStatements;

        ----------------------------------------------------------------------
        -- 3. Cierre de auditoria
        ----------------------------------------------------------------------
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
        SET Status = 1
        WHERE Component = @nProceso;

        /*
            nPedidos permanece en cero porque el Oracle original nunca lo
            incrementa. Proceso_4 debe conservar ese valor por compatibilidad.
        */
        UPDATE [T3].[RF_PROCESOS_LOG]
        SET
            Fin       = SYSDATETIME(),
            Proceso_1 = 0,
            Proceso_2 = 0,
            Proceso_3 = 0,
            Proceso_4 = @nPedidos
        WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- Liberar el cursor sin provocar un segundo error durante el manejo de
        -- la excepcion. El estado -1 significa declarado pero cerrado.
        IF CURSOR_STATUS('local', 'ScrStatements') >= 0
            CLOSE ScrStatements;

        IF CURSOR_STATUS('local', 'ScrStatements') > -2
            DEALLOCATE ScrStatements;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction,
            Reference,
            Created,
            Message,
            Job_PID,
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
            'Job Logging',
            @sReference,
            SYSDATETIME(),
            NULL,
            @nPID,
            'Error',
            'WA_RUN_STATEMENTS',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra la excepcion y termina sin propagarla.
        RETURN;
    END CATCH;
END;
GO

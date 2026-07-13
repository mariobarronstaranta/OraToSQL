CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_JOB_MANAGE]
(
    @sAction VARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @dtNextRun        DATETIME2(0),
        @nJobInvoice      INT,
        @nJobIntercompany INT,
        @nJobDelivery     INT,
        @nJobPayment      INT,
        @nJobCustomer     INT;

    /*
        Objetivo del procedimiento Oracle
        ---------------------------------
        Suspender o reactivar en conjunto los cinco jobs de entrada T3
        configurados en MX_HashTable mediante GETCONV.

        Equivalencias principales
        -------------------------
        - DBMS_JOB.BROKEN(job, TRUE, fecha 4000-01-01): deshabilita el job.
        - DBMS_JOB.BROKEN(job, FALSE, SYSDATE + 30 segundos): habilita el job
          y establece la siguiente fecha base de ejecucion.
        - JOB_NEXT_RUN aplica esas reglas sobre SQL Server Agent mediante
          dbo.Job_Oracle_SQLAgent_Map, sp_update_job y sp_update_schedule.

        La accion Oracle es exacta: solamente 'Suspend' suspende. Cualquier
        otro valor, incluido NULL, reactiva los jobs.
    */

    BEGIN TRY
        -- GETCONV devuelve el numero historico DBMS_JOB almacenado como texto.
        SELECT
            @nJobInvoice = TRY_CONVERT
            (
                INT,
                [EAI_OWNER].[GETCONV]('CFG Settings', 'T3In-Job Invoice')
            ),
            @nJobIntercompany = TRY_CONVERT
            (
                INT,
                [EAI_OWNER].[GETCONV]('CFG Settings', 'T3In-Job Intercompany')
            ),
            @nJobDelivery = TRY_CONVERT
            (
                INT,
                [EAI_OWNER].[GETCONV]('CFG Settings', 'T3In-Job Delivery')
            ),
            @nJobPayment = TRY_CONVERT
            (
                INT,
                [EAI_OWNER].[GETCONV]('CFG Settings', 'T3In-Job Payment')
            ),
            @nJobCustomer = TRY_CONVERT
            (
                INT,
                [EAI_OWNER].[GETCONV]('CFG Settings', 'T3In-Job Customer')
            );

        -- Oracle fallaria al convertir a NUMBER una configuracion ausente o
        -- no numerica. Se genera un error explicito antes de modificar jobs.
        IF @nJobInvoice IS NULL
           OR @nJobIntercompany IS NULL
           OR @nJobDelivery IS NULL
           OR @nJobPayment IS NULL
           OR @nJobCustomer IS NULL
        BEGIN
            THROW 51020, 'La configuracion de uno o mas jobs T3In es nula o no contiene un numero DBMS_JOB valido.', 1;
        END;

        SET @dtNextRun =
            CASE
                WHEN DATALENGTH(@sAction) = 7
                 AND @sAction COLLATE Latin1_General_100_BIN2 = 'Suspend'
                    THEN CONVERT(DATETIME2(0), '4000-01-01T00:00:00', 126)
                ELSE DATEADD(SECOND, 30, SYSDATETIME())
            END;

        /*
            Una sola transaccion conserva la intencion del COMMIT final de
            Oracle: los cinco jobs cambian juntos o se revierte todo el grupo.
            JOB_NEXT_RUN valida que cada job y schedule tenga un mapeo activo.
        */
        BEGIN TRANSACTION;

            EXEC [EAI_OWNER].[JOB_NEXT_RUN]
                @pJOB = @nJobInvoice,
                @pNextRun = @dtNextRun;

            EXEC [EAI_OWNER].[JOB_NEXT_RUN]
                @pJOB = @nJobIntercompany,
                @pNextRun = @dtNextRun;

            EXEC [EAI_OWNER].[JOB_NEXT_RUN]
                @pJOB = @nJobDelivery,
                @pNextRun = @dtNextRun;

            EXEC [EAI_OWNER].[JOB_NEXT_RUN]
                @pJOB = @nJobPayment,
                @pNextRun = @dtNextRun;

            EXEC [EAI_OWNER].[JOB_NEXT_RUN]
                @pJOB = @nJobCustomer,
                @pNextRun = @dtNextRun;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

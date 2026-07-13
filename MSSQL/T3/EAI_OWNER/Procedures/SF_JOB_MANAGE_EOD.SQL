CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_JOB_MANAGE_EOD]
(
    @sAction VARCHAR(50)
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
        Reactivar, como parte del cierre de dia, solamente los jobs de:
            - Intercompany
            - Delivery
            - Customer

        El parametro sAction existe en la firma Oracle, pero no participa en
        su logica. Por compatibilidad se conserva @sAction y no se utiliza:
        toda ejecucion reactiva esos tres jobs, sin importar su valor.

        Aunque Invoice y Payment no se modifican, Oracle obtiene las cinco
        configuraciones en variables NUMBER. Se leen y validan tambien aqui
        para mantener el mismo comportamiento ante configuracion incompleta.

        JOB_NEXT_RUN sustituye DBMS_JOB.BROKEN(job, FALSE, dtNextRun) y usa
        dbo.Job_Oracle_SQLAgent_Map para resolver el numero DBMS_JOB hacia el
        job y schedule correspondientes de SQL Server Agent.
    */

    BEGIN TRY
        -- Oracle usa SYSDATE + (1 / 2880): iniciar aproximadamente 30
        -- segundos despues de la ejecucion de este procedimiento.
        SET @dtNextRun = DATEADD(SECOND, 30, SYSDATETIME());

        -- GETCONV devuelve los numeros historicos DBMS_JOB como texto.
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

        -- La asignacion Oracle a NUMBER fallaria para cualquiera de las cinco
        -- configuraciones si fuese nula o no numerica.
        IF @nJobInvoice IS NULL
           OR @nJobIntercompany IS NULL
           OR @nJobDelivery IS NULL
           OR @nJobPayment IS NULL
           OR @nJobCustomer IS NULL
        BEGIN
            THROW 51021, 'La configuracion de uno o mas jobs T3In es nula o no contiene un numero DBMS_JOB valido.', 1;
        END;

        /*
            El COMMIT final de Oracle abarca las tres llamadas. La transaccion
            exterior conserva esa atomicidad: se reactivan los tres jobs o se
            revierten todos los cambios si falla algun mapeo o schedule.
        */
        BEGIN TRANSACTION;

            EXEC [EAI_OWNER].[JOB_NEXT_RUN]
                @pJOB = @nJobIntercompany,
                @pNextRun = @dtNextRun;

            EXEC [EAI_OWNER].[JOB_NEXT_RUN]
                @pJOB = @nJobDelivery,
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

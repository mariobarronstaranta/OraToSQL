CREATE OR ALTER PROCEDURE [EAI_OWNER].[JOB_INTERVAL]
(
    @pJobNo    INT,
    @pInterval VARCHAR(4000)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        Developer notes
        ---------------
        Este procedure reemplaza el wrapper Oracle:

            DBMS_JOB.Interval(pJobNo, pInterval)

        En Oracle, DBMS_JOB guardaba el intervalo como una expresion PL/SQL que
        se evaluaba despues de cada ejecucion. SQL Server Agent no tiene ese
        mismo modelo: un job se vincula a uno o mas schedules con propiedades
        normalizadas. Por eso este procedure:

        1. Busca el job/schedule equivalente en dbo.Job_Oracle_SQLAgent_Map.
        2. Traduce expresiones Oracle conocidas a columnas de msdb schedules.
        3. Actualiza el schedule con msdb.dbo.sp_update_schedule.

        Si aparece una expresion Oracle no contemplada, se lanza error en vez de
        inventar una frecuencia, porque eso podria ejecutar procesos operativos
        en horarios incorrectos.
    */

    DECLARE
        @ScheduleId         INT,
        @SqlAgentJobId      UNIQUEIDENTIFIER,
        @IntervalClean      VARCHAR(4000),
        @IntervalExpr       VARCHAR(4000),
        @FreqType           INT = 4,
        @FreqInterval       INT = 1,
        @FreqSubdayType     INT = 1,
        @FreqSubdayInterval INT = 0,
        @ActiveStartTime    INT = 0,
        @Days               INT,
        @Hours              INT,
        @Minutes            INT,
        @Seconds            INT,
        @Numerator          INT,
        @Denominator        INT,
        @TotalSeconds       DECIMAL(18,6),
        @ReturnCode         INT,
        @ErrMsg             NVARCHAR(2048);

    /*
        Oracle:
            DBMS_JOB.Interval(pJobNo, pInterval);
            COMMIT;

        SQL Server:
            SQL Server Agent no guarda una expresion PL/SQL de intervalo.
            Esta migracion actualiza el schedule asociado al job mediante
            dbo.Job_Oracle_SQLAgent_Map.

        Equivalencias soportadas:
            SYSDATE+N                 -> cada N dias
            SYSDATE+N/24              -> cada N horas
            SYSDATE+N/1440            -> cada N minutos
            SYSDATE+N/86400           -> cada N segundos
            SYSDATE+1/2880            -> cada 30 segundos
            TRUNC(SYSDATE)+1          -> diario a las 00:00
            TRUNC(SYSDATE)+1+H/24     -> diario a las H:00
    */

    BEGIN TRY
        -- Validaciones defensivas: el wrapper Oracle era muy pequeno, pero en
        -- SQL Server necesitamos asegurar que exista el mapeo hacia SQL Agent.
        IF @pJobNo IS NULL
            THROW 51000, 'El parametro @pJobNo no puede ser NULL.', 1;

        IF NULLIF(LTRIM(RTRIM(@pInterval)), '') IS NULL
            THROW 51001, 'El parametro @pInterval no puede ser NULL o vacio.', 1;

        IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map', N'U') IS NULL
            THROW 51002, 'No existe dbo.Job_Oracle_SQLAgent_Map para mapear DBMS_JOB a SQL Server Agent.', 1;

        -- Tabla puente esperada por la migracion:
        --   Oracle_Job_No    = numero historico DBMS_JOB.JOB.
        --   SqlAgent_Job_Id  = msdb.dbo.sysjobs.job_id.
        --   Schedule_Id      = msdb.dbo.sysschedules.schedule_id.
        -- Mantener un solo schedule activo por job facilita reproducir el
        -- comportamiento DBMS_JOB.Interval.
        SELECT
            @ScheduleId    = M.Schedule_Id,
            @SqlAgentJobId = M.SqlAgent_Job_Id
        FROM dbo.Job_Oracle_SQLAgent_Map AS M
        WHERE M.Oracle_Job_No = @pJobNo
          AND M.Is_Active = 1;

        IF @SqlAgentJobId IS NULL OR @ScheduleId IS NULL
        BEGIN
            SET @ErrMsg = CONCAT(
                'No existe mapeo activo con job y schedule para Oracle Job No ',
                CONVERT(VARCHAR(20), @pJobNo),
                '.'
            );
            THROW 51003, @ErrMsg, 1;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysjobs AS J
            WHERE J.job_id = @SqlAgentJobId
        )
            THROW 51004, 'El SqlAgent_Job_Id mapeado no existe en msdb.dbo.sysjobs.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysschedules AS S
            WHERE S.schedule_id = @ScheduleId
        )
            THROW 51005, 'El Schedule_Id mapeado no existe en msdb.dbo.sysschedules.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysjobschedules AS JS
            WHERE JS.job_id = @SqlAgentJobId
              AND JS.schedule_id = @ScheduleId
        )
            THROW 51006, 'El Schedule_Id mapeado no esta asociado al SqlAgent_Job_Id.', 1;

        SET @IntervalClean = UPPER(LTRIM(RTRIM(@pInterval)));
        SET @IntervalClean = REPLACE(@IntervalClean, CHAR(9), '');
        SET @IntervalClean = REPLACE(@IntervalClean, ' ', '');
        SET @IntervalClean = REPLACE(@IntervalClean, '(', '');
        SET @IntervalClean = REPLACE(@IntervalClean, ')', '');

        -- TRUNC(SYSDATE)+1 significa "manana a medianoche"; en SQL Agent se
        -- modela como frecuencia diaria con una ejecucion al inicio del dia.
        IF @IntervalClean = 'TRUNCSYSDATE+1'
        BEGIN
            SET @FreqType = 4;
            SET @FreqInterval = 1;
            SET @FreqSubdayType = 1;
            SET @FreqSubdayInterval = 0;
            SET @ActiveStartTime = 0;
        END
        -- Variante con hora fija: TRUNC(SYSDATE)+1+6/24 => diario a las 06:00.
        ELSE IF @IntervalClean LIKE 'TRUNCSYSDATE+1+%/24'
        BEGIN
            SET @Hours = TRY_CONVERT(INT, REPLACE(REPLACE(@IntervalClean, 'TRUNCSYSDATE+1+', ''), '/24', ''));

            IF @Hours IS NULL OR @Hours < 0 OR @Hours > 23
                THROW 51007, 'Hora invalida. Formato esperado: TRUNC(SYSDATE)+1+H/24.', 1;

            SET @FreqType = 4;
            SET @FreqInterval = 1;
            SET @FreqSubdayType = 1;
            SET @FreqSubdayInterval = 0;
            SET @ActiveStartTime = @Hours * 10000;
        END
        -- SYSDATE+N es un intervalo de N dias entre ejecuciones.
        ELSE IF @IntervalClean LIKE 'SYSDATE+%' AND @IntervalClean NOT LIKE '%/%'
        BEGIN
            SET @Days = TRY_CONVERT(INT, REPLACE(@IntervalClean, 'SYSDATE+', ''));

            IF @Days IS NULL OR @Days <= 0
                THROW 51008, 'Intervalo diario invalido. Formato esperado: SYSDATE+N.', 1;

            SET @FreqType = 4;
            SET @FreqInterval = @Days;
            SET @FreqSubdayType = 1;
            SET @FreqSubdayInterval = 0;
            SET @ActiveStartTime = 0;
        END
        -- SYSDATE+N/D representa una fraccion de dia. Se convierte a segundos
        -- y luego se elige la granularidad mas natural de SQL Agent:
        -- horas, minutos o segundos.
        ELSE IF @IntervalClean LIKE 'SYSDATE+%/%'
        BEGIN
            SET @IntervalExpr = REPLACE(@IntervalClean, 'SYSDATE+', '');
            SET @Numerator = TRY_CONVERT(INT, LEFT(@IntervalExpr, CHARINDEX('/', @IntervalExpr) - 1));
            SET @Denominator = TRY_CONVERT(INT, SUBSTRING(@IntervalExpr, CHARINDEX('/', @IntervalExpr) + 1, 4000));

            IF @Numerator IS NULL OR @Denominator IS NULL OR @Numerator <= 0 OR @Denominator <= 0
                THROW 51009, 'Intervalo fraccionario invalido. Formato esperado: SYSDATE+N/D.', 1;

            SET @TotalSeconds = (CONVERT(DECIMAL(18,6), @Numerator) * 86400.0) / @Denominator;

            IF @TotalSeconds < 10 OR @TotalSeconds > 86399
                THROW 51010, 'El intervalo fraccionario debe estar entre 10 segundos y menos de 1 dia para SQL Server Agent.', 1;

            -- SQL Agent usa codigos: 8 = horas, 4 = minutos, 2 = segundos.
            -- Preferimos horas/minutos cuando la division es exacta para dejar
            -- schedules mas legibles en SSMS.
            IF @TotalSeconds = FLOOR(@TotalSeconds / 3600) * 3600
            BEGIN
                SET @Hours = CONVERT(INT, @TotalSeconds / 3600);
                SET @FreqType = 4;
                SET @FreqInterval = 1;
                SET @FreqSubdayType = 8;
                SET @FreqSubdayInterval = @Hours;
                SET @ActiveStartTime = 0;
            END
            ELSE IF @TotalSeconds = FLOOR(@TotalSeconds / 60) * 60
            BEGIN
                SET @Minutes = CONVERT(INT, @TotalSeconds / 60);
                SET @FreqType = 4;
                SET @FreqInterval = 1;
                SET @FreqSubdayType = 4;
                SET @FreqSubdayInterval = @Minutes;
                SET @ActiveStartTime = 0;
            END
            ELSE
            BEGIN
                SET @Seconds = CONVERT(INT, @TotalSeconds);

                IF @TotalSeconds <> @Seconds
                    THROW 51011, 'El intervalo fraccionario no produce segundos enteros.', 1;

                SET @FreqType = 4;
                SET @FreqInterval = 1;
                SET @FreqSubdayType = 2;
                SET @FreqSubdayInterval = @Seconds;
                SET @ActiveStartTime = 0;
            END;
        END
        ELSE
        BEGIN
            SET @ErrMsg = CONCAT(
                'Intervalo Oracle no soportado automaticamente: ',
                @pInterval,
                '. Ajustar manualmente el schedule o extender EAI_OWNER.JOB_INTERVAL.'
            );
            THROW 51012, @ErrMsg, 1;
        END;

        -- sp_update_schedule es la API soportada para cambiar schedules de SQL
        -- Agent. La actualizacion del mapeo queda en la misma transaccion para
        -- conservar trazabilidad del ultimo intervalo Oracle solicitado.
        BEGIN TRANSACTION;

            EXEC @ReturnCode = msdb.dbo.sp_update_schedule
                @schedule_id          = @ScheduleId,
                @enabled              = 1,
                @freq_type            = @FreqType,
                @freq_interval        = @FreqInterval,
                @freq_subday_type     = @FreqSubdayType,
                @freq_subday_interval = @FreqSubdayInterval,
                @active_start_time    = @ActiveStartTime;

            IF @ReturnCode <> 0
                THROW 51013, 'Error al actualizar el schedule en SQL Server Agent.', 1;

            UPDATE dbo.Job_Oracle_SQLAgent_Map
               SET Last_Interval = @pInterval,
                   Last_Update_Date = SYSDATETIME(),
                   Last_Update_User = SUSER_SNAME()
             WHERE Oracle_Job_No = @pJobNo
               AND Is_Active = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE EAI.CUSTOMER_LOG_UPDATE
(
      @v_Cliente_V3 VARCHAR(100)
    , @v_Opcion     VARCHAR(20)
    , @v_dtFecha    DATETIME = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @v_dtFecha IS NULL
        SET @v_dtFecha = GETDATE();

    DECLARE @dtFechaReplicacion DATETIME;
    DECLARE @dtFechaInsert DATETIME;
    DECLARE @sInsert VARCHAR(2) = 'NO';

    SELECT
        @dtFechaReplicacion = MAX(Fecha_Replicacion),
        @dtFechaInsert      = MAX(Fecha_Insert)
    FROM EAI.CUSTOMER_LOG
    WHERE Cliente_V3 = @v_Cliente_V3;

    IF @v_Opcion = 'Replicate'
    BEGIN
        INSERT INTO EAI.CUSTOMER_LOG
        (
            Cliente_V3,
            Fecha_Replicacion,
            Fecha_Insert
        )
        VALUES
        (
            @v_Cliente_V3,
            @v_dtFecha,
            GETDATE()
        );

        RETURN;
    END;

    IF @dtFechaInsert IS NULL
        SET @sInsert = 'SI';

    IF @v_Opcion = 'Sync'
    BEGIN
        IF @sInsert = 'SI'
        BEGIN
            INSERT INTO EAI.CUSTOMER_LOG
            (
                Cliente_V3,
                Fecha_Syncr,
                Fecha_Insert
            )
            VALUES
            (
                @v_Cliente_V3,
                @v_dtFecha,
                GETDATE()
            );
        END
        ELSE
        BEGIN
            UPDATE EAI.CUSTOMER_LOG
               SET Fecha_Syncr = @v_dtFecha
             WHERE Cliente_V3 = @v_Cliente_V3
               AND Fecha_Insert = @dtFechaInsert;
        END
    END
    ELSE IF @v_Opcion = 'ProcT3'
    BEGIN
        IF @sInsert = 'SI'
        BEGIN
            INSERT INTO EAI.CUSTOMER_LOG
            (
                Cliente_V3,
                Fecha_Proc_BATMD,
                Fecha_Insert
            )
            VALUES
            (
                @v_Cliente_V3,
                @v_dtFecha,
                GETDATE()
            );
        END
        ELSE
        BEGIN
            UPDATE EAI.CUSTOMER_LOG
               SET Fecha_Proc_BATMD = @v_dtFecha
             WHERE Cliente_V3 = @v_Cliente_V3
               AND Fecha_Insert = @dtFechaInsert;
        END
    END
    ELSE IF @v_Opcion = 'ConfSAP'
    BEGIN
        IF @sInsert = 'SI'
        BEGIN
            INSERT INTO EAI.CUSTOMER_LOG
            (
                Cliente_V3,
                Fecha_Update_SAP,
                Fecha_Insert
            )
            VALUES
            (
                @v_Cliente_V3,
                @v_dtFecha,
                GETDATE()
            );
        END
        ELSE
        BEGIN
            UPDATE EAI.CUSTOMER_LOG
               SET Fecha_Update_SAP = @v_dtFecha
             WHERE Cliente_V3 = @v_Cliente_V3
               AND Fecha_Insert = @dtFechaInsert;
        END
    END
    ELSE IF @v_Opcion = 'ConfERP'
    BEGIN
        IF @sInsert = 'SI'
        BEGIN
            INSERT INTO EAI.CUSTOMER_LOG
            (
                Cliente_V3,
                Fecha_Update_ERP,
                Fecha_Insert
            )
            VALUES
            (
                @v_Cliente_V3,
                @v_dtFecha,
                GETDATE()
            );
        END
        ELSE
        BEGIN
            UPDATE EAI.CUSTOMER_LOG
               SET Fecha_Update_ERP = @v_dtFecha
             WHERE Cliente_V3 = @v_Cliente_V3
               AND Fecha_Insert = @dtFechaInsert;
        END
    END
END;
GO

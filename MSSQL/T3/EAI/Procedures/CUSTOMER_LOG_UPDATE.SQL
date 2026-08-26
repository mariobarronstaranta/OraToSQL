CREATE PROCEDURE EAI.CUSTOMER_LOG_UPDATE
(
      @v_Cliente_V3 VARCHAR(100)
    , @v_Opcion     VARCHAR(20)
    , @v_dtFecha    DATETIME = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- @v_dtFecha es un valor DATETIME, no una cadena de texto. Si el proceso
    -- que llama al procedimiento no envia una fecha, se utiliza la fecha y
    -- hora actuales. No debe aplicarse formato YYYY-MM-DD porque las columnas
    -- de CUSTOMER_LOG son DATETIME2(0) y deben conservar tambien la hora.
    IF @v_dtFecha IS NULL
        SET @v_dtFecha = GETDATE();

    DECLARE @dtFechaInsert DATETIME;
    DECLARE @sInsert VARCHAR(2) = 'NO';

    -- Replicate siempre crea un registro nuevo: Fecha_Replicacion contiene la
    -- fecha recibida y Fecha_Insert registra cuando se ejecuto este INSERT.
    -- Se procesa antes de buscar registros anteriores porque esta opcion no
    -- necesita actualizar ninguna fila existente.
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

    /*
        Para Sync, ProcT3, ConfSAP y ConfERP se necesita la fila mas reciente
        del cliente. Se usa TOP (1) en lugar de MAX(Fecha_Insert) porque:

        1. Fecha_Insert permite NULL y MAX genera el warning
           "Null value is eliminated by an aggregate".
        2. El filtro IS NOT NULL evita considerar filas sin fecha de alta.
        3. El indice CUSTOMER_LOG_IX (Cliente_V3, Fecha_Insert) permite buscar
           la ultima fecha sin recorrer innecesariamente toda la tabla.

        Si no existe una fecha valida, @dtFechaInsert conserva NULL y el
        procedimiento insertara una nueva fila, igual que antes del ajuste.
    */
    SELECT TOP (1)
        @dtFechaInsert = Fecha_Insert
    FROM EAI.CUSTOMER_LOG
    WHERE Cliente_V3 = @v_Cliente_V3
      AND Fecha_Insert IS NOT NULL
    ORDER BY Fecha_Insert DESC;

    -- Si no existe un registro previo para el cliente, las demas opciones
    -- deben insertar una fila antes de guardar la fecha correspondiente.
    IF @dtFechaInsert IS NULL
        SET @sInsert = 'SI';

    -- Sync registra la fecha en que el cliente fue sincronizado.
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
    -- ProcT3 registra la fecha de procesamiento en BATMD/T3.
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
    -- ConfSAP registra la fecha en que SAP confirmo la actualizacion.
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
    -- ConfERP registra la fecha en que el ERP confirmo la actualizacion.
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

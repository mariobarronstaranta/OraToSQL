/*
    Procedure : EAI_OWNER.EXECUTE_TRUNCATE
    Objetivo  : Vaciar una tabla de trabajo autorizada mediante TRUNCATE TABLE.
    Entrada   : @pTableName acepta tabla o esquema.tabla.
    Seguridad : El nombre debe existir en EAI_TRUNC_TABLE. QUOTENAME delimita
                los identificadores y evita ejecutar texto SQL inyectado.
    Auditoría : Todo TRUNCATE exitoso queda registrado en EAI_TRUNC_LOG.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.EXECUTE_TRUNCATE
(
    @pTableName VARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @v_ID           VARCHAR(255),
        @SQL            NVARCHAR(MAX),
        @ErrorCode      VARCHAR(50),
        @ErrorMessage   VARCHAR(500);

    BEGIN TRY

        SET @v_ID = UPPER(@pTableName);

        ------------------------------------------------------------------
        -- Validar tabla autorizada
        ------------------------------------------------------------------
        -- Si la tabla no está en la lista blanca, no se ejecuta ninguna acción.
        IF EXISTS
        (
            SELECT 1
            FROM EAI_OWNER.EAI_TRUNC_TABLE
            WHERE UPPER(Table_Name) = @v_ID
        )
        BEGIN

            ------------------------------------------------------------------
            -- Construcción segura del TRUNCATE
            ------------------------------------------------------------------

            DECLARE
                @SchemaName SYSNAME,
                @TableOnly  SYSNAME;

            -- Oracle resuelve un nombre sin esquema dentro de EAI_OWNER.
            -- Se aplica la misma regla para evitar construir un comando NULL.
            SET @SchemaName = COALESCE(PARSENAME(@v_ID,2), 'EAI_OWNER');
            SET @TableOnly  = PARSENAME(@v_ID,1);

            -- La lista blanca ya validó el valor completo. Esta comprobación
            -- adicional rechaza nombres de tres o más partes (servidor/base).
            IF @TableOnly IS NULL OR PARSENAME(@v_ID,3) IS NOT NULL
                THROW 50001, 'El nombre de tabla autorizado debe tener una o dos partes.', 1;

            SET @SQL =
                N'TRUNCATE TABLE '
                + QUOTENAME(@SchemaName)
                + N'.'
                + QUOTENAME(@TableOnly);

            EXEC sp_executesql @SQL;

            ------------------------------------------------------------------
            -- Auditoría
            ------------------------------------------------------------------

            INSERT INTO EAI_OWNER.EAI_TRUNC_LOG
            (
                TABLE_NAME,
                EXECUTED,
                USER_SCHEMA,
                USER_ID,
                IP_ADDRESS,
                TERMINAL
            )
            VALUES
            (
                @v_ID,
                GETDATE(),
                SUSER_SNAME(),
                ORIGINAL_LOGIN(),
                CAST(CONNECTIONPROPERTY('client_net_address') AS VARCHAR(100)),
                HOST_NAME()
            );
        END

    END TRY

    BEGIN CATCH

        SET @ErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

        SET @ErrorMessage =
            LEFT
            (
                CONCAT
                (
                    ERROR_NUMBER(),
                    '-',
                    ERROR_MESSAGE()
                ),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'TRUNCATE',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'EXECUTE_TRUNCATE',
            @ErrorMessage,
            'T-SQL',
            @ErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- El procedimiento Oracle registra el error y no lo propaga al caller.
        -- Se conserva ese contrato para no alterar a los procesos consumidores.

    END CATCH

END
GO

/*
    Homologo SQL Server de EAI_OWNER.WA_REP_MASTERDATA (Oracle).

    Objetivo:
      1. Recorrer las vans vigentes cuyo nombre inicia con VAN.
      2. Completar correos faltantes de representantes existentes.
      3. Insertar representantes nuevos solamente cuando pInsert > 0.

    El origen procesa cada fila del LEFT JOIN, incluso si hay Cliente_SAP
    duplicados. Se conserva un cursor LOCAL FAST_FORWARD para no deduplicar ni
    cambiar el orden update/insert que tendria Oracle.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_REP_MASTERDATA]
(
    /* NUMBER admite valores fraccionarios; solo se evalua si es mayor que 0. */
    @pInsert DECIMAL(10,4) = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /* Oracle confirma el trabajo previo cuando entra en WHEN OTHERS. */
    SET XACT_ABORT OFF;

    DECLARE
        @sReference       VARCHAR(30) = NULL,
        @sErrorCode       VARCHAR(30),
        @sMsg             VARCHAR(300),
        @nPedidos         INT = 0,
        @nPID             BIGINT = NULL,
        @nProceso         INT = 0,
        @sClienteSAP      VARCHAR(1024),
        @sNombreRep       VARCHAR(1024),
        @sEmail           VARCHAR(100),
        @sCorreoExistente VARCHAR(100),
        @sAccion          VARCHAR(10);

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------------------
        -- Cursor ScrReps: vans vigentes relacionadas con CAT_REPS.
        ----------------------------------------------------------------------
        DECLARE ScrReps CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                A.Stock_Partner_Resource AS Cliente_SAP,
                A.Resource_Name AS Nombre_Rep,
                CASE
                    WHEN B.Cliente_SAP IS NOT NULL THEN 'UPDATE'
                    ELSE 'INSERT'
                END AS Accion,
                REPLACE
                (
                    REPLACE(A.IvyBase__Username__c, 'petra3.', ''),
                    'PETRA3.',
                    ''
                ) AS eMail,
                COALESCE(B.Correo_Electronico, 'NULL') AS Correo_Electronico
            FROM [EAI_OWNER].[VANS_VIGENTES] AS A
            LEFT JOIN [EAI_OWNER].[CAT_REPS] AS B
                ON B.Cliente_SAP = A.Stock_Partner_Resource
            WHERE A.Name LIKE 'VAN%'
              AND A.Stock_Partner_Resource NOT LIKE '%RESOURCE%';

        OPEN ScrReps;

        FETCH NEXT FROM ScrReps INTO
            @sClienteSAP,
            @sNombreRep,
            @sAccion,
            @sEmail,
            @sCorreoExistente;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            /* Referencia de la fila actual para una eventual bitacora de error. */
            SET @sReference = CONVERT(VARCHAR(30), @sClienteSAP);
            SET @nProceso = @nProceso + 1;

            IF @sAccion = 'UPDATE'
            BEGIN
                /*
                    Oracle actualiza solo cuando el correo existente tiene
                    menos de 5 caracteres y el nuevo no esta vacio.

                    NULLIF reproduce LENGTH(TRIM('   ')) = NULL de Oracle; una
                    cadena formada solo por espacios no satisface la condicion.
                */
                IF LEN(NULLIF(LTRIM(RTRIM(@sCorreoExistente)), '')) < 5
                   AND LEN(NULLIF(LTRIM(RTRIM(@sEmail)), '')) > 0
                BEGIN
                    UPDATE [EAI_OWNER].[CAT_REPS]
                       SET Correo_Electronico = @sEmail,
                           Ultima_Modificacion = SYSDATETIME(),
                           ModificadoPor = 'REPLICATE'
                    WHERE Cliente_SAP = @sClienteSAP;
                END;

                /* Oracle suma cero en la rama UPDATE. */
                SET @nPedidos = @nPedidos + 0;
            END
            ELSE
            BEGIN
                /* Equivale a NVL(pInsert, 0) > 0. */
                IF COALESCE(@pInsert, 0) > 0
                BEGIN
                    INSERT INTO [EAI_OWNER].[CAT_REPS]
                    (
                        Cliente_SAP,
                        Nombre,
                        Correo_Electronico,
                        Creacion,
                        CreadoPor
                    )
                    VALUES
                    (
                        @sClienteSAP,
                        @sNombreRep,
                        @sEmail,
                        SYSDATETIME(),
                        'REPLICATE'
                    );

                    SET @nPedidos = @nPedidos + 1;
                END;
            END;

            FETCH NEXT FROM ScrReps INTO
                @sClienteSAP,
                @sNombreRep,
                @sAccion,
                @sEmail,
                @sCorreoExistente;
        END;

        CLOSE ScrReps;
        DEALLOCATE ScrReps;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        IF CURSOR_STATUS('local', 'ScrReps') >= 0
            CLOSE ScrReps;

        IF CURSOR_STATUS('local', 'ScrReps') > -2
            DEALLOCATE ScrReps;

        /*
            Una transaccion condenada no puede confirmarse. Si sigue valida,
            el log y todo el trabajo previo se confirman juntos como en Oracle.
        */
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;

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
            'WA_REP_MASTERDATA',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- Oracle registra el error y finaliza sin volver a lanzarlo.
        RETURN;
    END CATCH;
END;
GO

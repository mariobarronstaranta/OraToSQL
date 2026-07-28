/*
    Procedure : EAI_OWNER.SF_PROC_CUSTOMER_MAIL
    Objetivo  : Registrar una dirección de correo por cliente SAP cuando aún no
                existe una fila válida en T3.TMD_EMAIL.
    Validaciones: Excluye el correo genérico, valores nulos/cortos y clientes
                  demasiado cortos; también evita duplicados por Cliente_SAP.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.SF_PROC_CUSTOMER_MAIL
(
      @sCliente_SAP VARCHAR(50)
    , @sMail        VARCHAR(1024)
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
          @v_ID         VARCHAR(30)
        , @sErrorCode   VARCHAR(500)
        , @sMsg         VARCHAR(500)
        , @sProcesar    VARCHAR(4)
        , @nRecords     INT;

    SET @v_ID       = @sCliente_SAP;
    SET @sProcesar  = 'YES';
    SET @nRecords   = 0;

    BEGIN TRY

        -- El destino admite 30 caracteres para Cliente_SAP y 350 para Email.
        -- Se reciben valores más amplios para validarlos sin truncamiento.
        IF LEN(@sCliente_SAP) > 30 OR LEN(@sMail) > 350
            THROW 50025, 'Cliente_SAP o Email excede la longitud permitida.', 1;

        ---------------------------------------------------
        -- Validaciones
        ---------------------------------------------------

        -- La existencia se valida antes del INSERT. Una restricción UNIQUE en
        -- Cliente_SAP sigue siendo recomendable para concurrencia simultánea.
        IF EXISTS
        (
            SELECT 1
            FROM T3.TMD_EMAIL
            WHERE Cliente_SAP = @sCliente_SAP
        )
        BEGIN
            SET @sProcesar = 'NO';
        END

        IF @sMail = 'contact@bat.com.mx'
        BEGIN
            SET @sProcesar = 'NO';
        END

        IF LEN(COALESCE(@sMail,'NULL')) <= 5
        BEGIN
            SET @sProcesar = 'NO';
        END

        IF LEN(COALESCE(@sCliente_SAP,'NULL')) <= 5
        BEGIN
            SET @sProcesar = 'NO';
        END

        ---------------------------------------------------
        -- Inserción
        ---------------------------------------------------

        IF @sProcesar <> 'NO'
        BEGIN

            INSERT INTO T3.TMD_EMAIL
            (
                Creado,
                Creado_Por,
                Cliente_SAP,
                Email
            )
            VALUES
            (
                GETDATE(),
                'INTERFACE',
                @sCliente_SAP,
                @sMail
            );

        END

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

        SET @sMsg =
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
            ID,
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
            'Receive',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'SF_PROC_CUSTOMER_MAIL',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

    END CATCH

END
GO

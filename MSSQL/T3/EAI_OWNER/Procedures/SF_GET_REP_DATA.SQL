CREATE OR ALTER PROCEDURE EAI_OWNER.SF_GET_REP_DATA
(
      @pInvoiceRef   VARCHAR(500)
    , @pCustomerRef  VARCHAR(500)

    , @rtRepName     VARCHAR(60) OUTPUT
    , @rtRFC         VARCHAR(50) OUTPUT
    , @rtLicencia    VARCHAR(50) OUTPUT
    , @rtPlacas      VARCHAR(50) OUTPUT
    , @rtModelo      VARCHAR(50) OUTPUT
    , @rtPesoMax     DECIMAL(18,2) OUTPUT
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
          @sInvoiceRef VARCHAR(500)
        , @sErrorCode  VARCHAR(100)
        , @sMsg        VARCHAR(500)
        , @v_ID        VARCHAR(30)
        , @sDoc_Num    VARCHAR(50)
        , @sDocType    VARCHAR(30);

    SET @v_ID = @pInvoiceRef;
    SET @sInvoiceRef = @pInvoiceRef;

    SET @rtRepName  = '';
    SET @rtRFC      = '';
    SET @rtLicencia = '';
    SET @rtPlacas   = '';
    SET @rtModelo   = '';
    SET @rtPesoMax  = 0;

    BEGIN TRY

        IF SUBSTRING(@sInvoiceRef,6,1) = '-'
        BEGIN
            SET @sDocType = 'Prompt';
            SET @sDoc_Num = SUBSTRING(@sInvoiceRef,2,4);
        END
        ELSE
        BEGIN
            SET @sDocType = 'Pre';
        END

        IF @sDocType = 'Prompt'
        BEGIN

            SELECT TOP (1)
                  @rtRepName  = COALESCE(Rep.Nombre, Van.Resource_Name)
                , @rtRFC      = Rep.RFC
                , @rtLicencia = COALESCE(Rep.Licencia,'12345678')
                , @rtPlacas   = REPLACE(COALESCE(Rep.Placas,'PLACAS'),'-','')
                , @rtModelo   = COALESCE(Rep.Modelo,'2020')
                , @rtPesoMax  = COALESCE(Rep.Peso_Maximo_Nom,3000)
            FROM EAI_OWNER.VANS_VIGENTES Van
            INNER JOIN EAI_OWNER.CAT_REPS Rep
                ON Van.Stock_Partner_Resource = Rep.Cliente_SAP
            WHERE Van.Name LIKE 'VAN%'
              AND Van.Name LIKE '%' + @sDoc_Num
            ORDER BY Van.Name;

        END

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

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
            , REFERENCE
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
              'Getting Info'
            , @v_ID
            , GETDATE()
            , NULL
            , 'Error'
            , 'GET_REP_DATA'
            , @sMsg
            , 'XML'
            , @sErrorCode
            , NULL
            , NULL
            , NULL
        );

        THROW;

    END CATCH

END
GO
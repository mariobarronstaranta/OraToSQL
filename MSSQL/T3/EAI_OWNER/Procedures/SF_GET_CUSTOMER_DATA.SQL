CREATE OR ALTER PROCEDURE EAI_OWNER.SF_GET_CUSTOMER_DATA
(
      @pCustomer_SAP      VARCHAR(500),
      @pDate              DATE = NULL,

      @rtCustomer_TMD     VARCHAR(20) OUTPUT,
      @rtCtro             VARCHAR(20) OUTPUT,
      @rtDistributor      INT OUTPUT,
      @rtRep_ID           VARCHAR(20) OUTPUT,
      @rtCustomer_Name    VARCHAR(1024) OUTPUT
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
          @v_ID             VARCHAR(15)
        , @dtDateRef        DATE
        , @sDoc_Type        VARCHAR(20)
        , @sMsg             VARCHAR(500)
        , @sErrorCode       VARCHAR(500);

    BEGIN TRY

        SET @v_ID = @pCustomer_SAP;

        SET @dtDateRef = COALESCE(@pDate, CAST(GETDATE() AS DATE));

        SET @rtCustomer_TMD  = '';
        SET @rtCtro          = '';
        SET @rtDistributor   = 0;
        SET @rtRep_ID        = '';
        SET @rtCustomer_Name = '';

        SET @sDoc_Type = 'None';

        ---------------------------------------------------
        -- HISTORIAL
        ---------------------------------------------------

        SELECT TOP (1)
               @rtCustomer_TMD  = C.Cliente_V3,
               @rtCtro          = C.Ctro,
               @rtDistributor   = dbo.CONV_PLANT_TO_DIST(C.Ctro),
               @rtRep_ID        = 'CENTRAL',
               @rtCustomer_Name = C.Nombre,
               @sDoc_Type       = 'History'
        FROM T3.Cliente C
        WHERE C.Cliente_SAP = @pCustomer_SAP
          AND @dtDateRef BETWEEN
              C.fecha_Ini_Vig AND C.Fecha_Fin_Vig;

        ---------------------------------------------------
        -- MOV_CLIENTE
        ---------------------------------------------------

        IF @sDoc_Type = 'None'
        BEGIN

            SELECT TOP (1)
                   @rtCustomer_TMD  = M.Cliente_V3,
                   @rtCtro          = M.Ctro,
                   @rtDistributor   = dbo.CONV_PLANT_TO_DIST(M.Ctro),
                   @rtRep_ID        = 'CENTRAL',
                   @rtCustomer_Name = M.Nombre,
                   @sDoc_Type       = 'History'
            FROM T3.Mov_Cliente M
            WHERE M.Cliente_SAP = @pCustomer_SAP;

        END

    END TRY

    BEGIN CATCH

        SET @rtCustomer_TMD = '';
        SET @rtCtro = '';
        SET @rtDistributor = 0;
        SET @rtRep_ID = '';
        SET @rtCustomer_Name = '';

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
            , 'GET_CUSTOMER_DATA'
            , @sMsg
            , 'XML'
            , @sErrorCode
            , NULL
            , NULL
            , NULL
        );

    END CATCH

END
GO
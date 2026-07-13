CREATE PROCEDURE EAI_OWNER.SF_PROC_PRODUCT
(
      @sROW_ID   VARCHAR(50)
    , @nROWNUM   INT
    , @nOutput   INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
          @v_ID VARCHAR(30)
        , @sErrorCode VARCHAR(500)
        , @sMsg VARCHAR(500)
        , @sProcesar VARCHAR(20)
        , @sStage VARCHAR(50)='Inicio';

    BEGIN TRY

        DECLARE
              @MaterialNumber VARCHAR(50)
            , @Description VARCHAR(50)
            , @PricingGroup VARCHAR(50)
            , @StartDate VARCHAR(50)
            , @EndDate VARCHAR(50)
            , @EAN VARCHAR(50)
            , @BaseUnitMeasure VARCHAR(50)
            , @ProductType VARCHAR(50)
            , @SalesUnitPerPack VARCHAR(50)
            , @ProductLine VARCHAR(50)
            , @Flag VARCHAR(50)
            , @LineProduct VARCHAR(50)
            , @DefaultProduct VARCHAR(50)
            , @CigarreteSize VARCHAR(50)
            , @FilterType VARCHAR(50)
            , @FlavourType VARCHAR(50)
            , @PackType VARCHAR(50)
            , @Manufacture VARCHAR(50)
            , @BlendingTobacco VARCHAR(50)
            , @UMV VARCHAR(50)
            , @ParentInternalProductName VARCHAR(50)
            , @BATParentBrandName VARCHAR(50)
            , @BATType VARCHAR(50)
            , @BATClass VARCHAR(50)
            , @SalesProductFlag VARCHAR(50);

        ;WITH XMLDATA AS
        (
            SELECT
                CAST(XML_CONTENT AS XML) AS XML_CONTENT
            FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
            WHERE ROW_ID = @sROW_ID
        )
        SELECT
              @MaterialNumber = X.C.value('(Message/GeneralData/MaterialNumber/text())[1]','varchar(50)')
            , @Description    = X.C.value('(Message/GeneralData/Description/text())[1]','varchar(50)')
            , @PricingGroup   = X.C.value('(Message/OrganizationData/PricingGroup/text())[1]','varchar(50)')
            , @StartDate      = X.C.value('(Message/OrganizationData/StartDate/text())[1]','varchar(50)')
            , @EndDate        = X.C.value('(Message/OrganizationData/EndDate/text())[1]','varchar(50)')
            , @EAN            = X.C.value('(Message/OrganizationData/EAN/text())[1]','varchar(50)')
            , @BaseUnitMeasure= X.C.value('(Message/OrganizationData/BaseUnitMeasure/text())[1]','varchar(50)')
            , @ProductType    = X.C.value('(Message/OrganizationData/ProductType/text())[1]','varchar(50)')
            , @SalesUnitPerPack = X.C.value('(Message/OrganizationData/SalesUnitPerPack/text())[1]','varchar(50)')
            , @ProductLine    = X.C.value('(Message/OrganizationData/ProductLine/text())[1]','varchar(50)')
            , @Flag           = X.C.value('(Message/OrganizationData/Flag/text())[1]','varchar(50)')
            , @LineProduct    = X.C.value('(Message/OrganizationData/LineProduct/text())[1]','varchar(50)')
            , @DefaultProduct = X.C.value('(Message/OrganizationData/DefaultProduct/text())[1]','varchar(50)')
            , @CigarreteSize  = X.C.value('(Message/CharacteristicData/CigarreteSize/text())[1]','varchar(50)')
            , @FilterType     = X.C.value('(Message/CharacteristicData/FilterType/text())[1]','varchar(50)')
            , @FlavourType    = X.C.value('(Message/CharacteristicData/FlavourType/text())[1]','varchar(50)')
            , @PackType       = X.C.value('(Message/CharacteristicData/PackType/text())[1]','varchar(50)')
            , @Manufacture    = X.C.value('(Message/CharacteristicData/Manufacture/text())[1]','varchar(50)')
            , @BlendingTobacco= X.C.value('(Message/CharacteristicData/BlendingTobacco/text())[1]','varchar(50)')
        FROM XMLDATA
        CROSS APPLY XML_CONTENT.nodes('/Product') X(C);

        SET @sStage='Validaciones';

        SET @v_ID = @MaterialNumber;

        IF @MaterialNumber IS NULL
            SET @sProcesar='NO';
        ELSE
            SET @sProcesar='SI';

        SET @MaterialNumber =
            CAST(TRY_CONVERT(BIGINT,@MaterialNumber) AS VARCHAR(50));

        IF @SalesUnitPerPack='Infinity'
            SET @SalesUnitPerPack='0';

        IF COALESCE(@PricingGroup,'')=''
            SET @PricingGroup='03';

        SET @FilterType =
            EAI_OWNER.GETCONV('ECC_V3 SKU Filter Type',@FilterType);

        SET @PricingGroup =
            EAI_OWNER.GETCONV('ECC_V3 SKU Price Group',@PricingGroup);

        SET @PackType =
            EAI_OWNER.GETCONV('ECC_V3 SKU Pack Type',@PackType);

        SET @CigarreteSize =
            EAI_OWNER.GETCONV('ECC_V3 SKU Cigarrete Size',@CigarreteSize);

        SET @BlendingTobacco =
            EAI_OWNER.GETCONV('ECC_V3 SKU Blend',@BlendingTobacco);

        SET @FlavourType =
            EAI_OWNER.GETCONV('ECC_V3 SKU Flavour',@FlavourType);

        IF COALESCE(@StartDate,'')=''
            SET @StartDate = CONVERT(VARCHAR(10),GETDATE(),101);

        IF COALESCE(@EndDate,'')=''
            SET @EndDate='12/31/4000';

        /* resto de reglas Merchandise,
           UMV,
           ProductLine,
           valores 99,
           exactamente igual al Oracle */

        SET @sProcesar =
            EAI_OWNER.GETCONV('CFG Settings','Send Product V3');

        UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
           SET Processed = GETDATE(),
               Status =
                    CASE
                        WHEN @sProcesar='SI'
                        THEN 'Processed'
                        ELSE 'Review'
                    END
        WHERE ROW_ID=@sROW_ID;

    END TRY

    BEGIN CATCH

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            CONCAT(@sStage,'. ',ERROR_MESSAGE());

        UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
        SET Processed=GETDATE(),
            Status='Error'
        WHERE ROW_ID=@sROW_ID;

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            ID,
            CREATED,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Processing PI',
            @v_ID,
            GETDATE(),
            'Error',
            'PROC_PRODUCT',
            @sMsg,
            'TSQL',
            @sErrorCode
        );

        THROW;

    END CATCH

END
GO
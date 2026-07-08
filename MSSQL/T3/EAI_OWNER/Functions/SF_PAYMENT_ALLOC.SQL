CREATE OR ALTER FUNCTION [EAI_OWNER].[SF_PAYMENT_ALLOC]
(
    @pIdocNumber VARCHAR(99)
)
RETURNS VARCHAR(4)
AS
BEGIN
    DECLARE @sReturn VARCHAR(4) = 'YES';

    IF @pIdocNumber IS NULL
        RETURN 'NO';

    IF NOT EXISTS
    (
        SELECT 1
        FROM [EAI_OWNER].[tmp_Account_Header] AS CC
        WHERE CC.IDocNumber = @pIdocNumber
    )
        RETURN 'YES';

    IF EXISTS
    (
        SELECT 1
        FROM [EAI_OWNER].[tmp_Account_Header] AS CC
        INNER JOIN [EAI_OWNER].[tmp_Account_Header] AS IDoc
            ON IDoc.ClearingDocNumber = CC.ClearingDocNumber
           AND IDoc.FiscalYear = CC.FiscalYear
           AND IDoc.IDocNumber <> CC.IDocNumber
        WHERE CC.IDocNumber = @pIdocNumber
          AND IDoc.DC_Indicator = 'S'
          AND IDoc.Processed IS NOT NULL
    )
        SET @sReturn = 'NO';

    RETURN @sReturn;
END;
GO

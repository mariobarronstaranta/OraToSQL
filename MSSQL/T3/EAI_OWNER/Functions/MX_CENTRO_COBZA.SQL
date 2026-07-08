CREATE OR ALTER FUNCTION [EAI_OWNER].[MX_CENTRO_COBZA]
(
    @p_Customer   VARCHAR(100),
    @p_Centro_Vta VARCHAR(100)
)
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @vReturn VARCHAR(100);

    SELECT TOP (1)
        @vReturn = HeadOffice.CTRO_COBZA
    FROM [EAI_OWNER].[MX_HEAD_OFFICE] AS HeadOffice
    WHERE HeadOffice.CUSTOMER = @p_Customer;

    IF @vReturn IS NULL
    BEGIN
        SELECT TOP (1)
            @vReturn = Distr.SUPL_VIA_PAGO
        FROM [T3].[DISTRIBUIDOR_FISCAL] AS Distr
        WHERE Distr.CTRO = @p_Centro_Vta;
    END;

    RETURN @vReturn;
END;
GO

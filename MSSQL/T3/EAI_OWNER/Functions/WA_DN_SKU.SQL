CREATE OR ALTER FUNCTION [EAI_OWNER].[WA_DN_SKU]
(
    @pDebitNote VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @sReturn VARCHAR(50) = '8800114';

    IF SUBSTRING(@pDebitNote, 1, 3) = 'CHP'
        SET @sReturn = '8800111';
    ELSE IF SUBSTRING(@pDebitNote, 1, 3) = 'CHD'
        SET @sReturn = '8800112';
    ELSE IF SUBSTRING(@pDebitNote, 1, 2) = 'KP'
        SET @sReturn = '8800113';
    ELSE IF SUBSTRING(@pDebitNote, 1, 4) IN ('FNAJ', 'FPAJ')
        SET @sReturn = '8800116';

    RETURN @sReturn;
END;
GO

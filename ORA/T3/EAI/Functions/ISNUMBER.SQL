CREATE OR ALTER FUNCTION EAI.ISNUMBER
(
    @sValue VARCHAR(8000)
)
RETURNS CHAR(1)
AS
BEGIN

    IF @sValue IS NULL
        RETURN 'F';

    RETURN
    (
        CASE
            WHEN @sValue NOT LIKE '%[^0-9]%'
                 AND LEN(@sValue) > 0
            THEN 'T'
            ELSE 'F'
        END
    );

END
GO
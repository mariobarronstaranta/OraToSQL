CREATE OR ALTER FUNCTION EAI.PORC_VENTA
(
      @nValor1 DECIMAL(38,10),
      @nValor2 DECIMAL(38,10),
      @nValor3 INT
)
RETURNS DECIMAL(38,10)
AS
BEGIN

    RETURN
    (
        CASE
            WHEN COALESCE(@nValor1,0) = 0 THEN 0
            WHEN COALESCE(@nValor2,0) = 0 THEN 0
            ELSE ROUND(@nValor1 / @nValor2, @nValor3)
        END
    );

END;
GO
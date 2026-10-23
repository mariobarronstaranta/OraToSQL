USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_TOTAL_FACT]    Script Date: 10/22/2026 10:47:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [T3].[FN_TOTAL_FACT]
(
    @sFactura VARCHAR(50)
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @nReturn DECIMAL(18, 2);
    DECLARE @sTotal_Factura DECIMAL(18, 2);

    SET @sFactura = NULLIF(@sFactura, '');
    SET @nReturn = NULL;

    SELECT @sTotal_Factura =
        SUM(
            ISNULL([VALOR_SUBT], 0)
          + ISNULL([VALOR_IVA], 0)
          + ISNULL([ENVIO_SUBT], 0)
          + ISNULL([ENVIO_IVA], 0)
          + ISNULL([CREDITO_SUBT], 0)
          + ISNULL([CREDITO_IVA], 0)
        )
    FROM [T3].[REGISTRO_FISCAL_DETALLE]
    WHERE [FACTURA] = @sFactura;

    SET @nReturn = @sTotal_Factura;

	if @nReturn is NULL
	begin 
		RETURN 0
	end

		RETURN @nReturn;

END;

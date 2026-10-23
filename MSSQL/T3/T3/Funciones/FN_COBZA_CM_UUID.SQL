USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_COBZA_CM_UUID]    Script Date: 10/9/2026 9:45:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   FUNCTION [T3].[FN_COBZA_CM_UUID]
(
    @p_CreditNote VARCHAR(255)
)
RETURNS NUMERIC(15,2)
AS
BEGIN
    DECLARE @v_Return NUMERIC(15,2);

    DECLARE @Asign_Amount_Assigned NUMERIC(15,2);

    DECLARE ScrAssigned CURSOR LOCAL FAST_FORWARD FOR
        SELECT 
               SUM( ISNULL( Cobza.Importe, 0 ) )  AS Amount_Assigned
        FROM T3.CFDI_Cobranza             Cobza,
             T3.CFDI_Historia_Docto_PAC   HDP  ,
             T3.CFDI_Documentos           CFD
        WHERE Cobza.Nota_Credito   = @p_CreditNote 
          AND Cobza.Nota_Credito   = HDP.Nota_Venta
          AND HDP.Nota_Venta_CFDI  = CFD.Nota_Venta
          AND CFD.Folio_Fiscal    IS NOT NULL;          

    SET @v_Return = 0;

    OPEN ScrAssigned;
    FETCH NEXT FROM ScrAssigned INTO @Asign_Amount_Assigned;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @v_Return = @Asign_Amount_Assigned;
        
        FETCH NEXT FROM ScrAssigned INTO @Asign_Amount_Assigned;
    END;

    CLOSE ScrAssigned;
    DEALLOCATE ScrAssigned;

    RETURN @v_Return;
END;

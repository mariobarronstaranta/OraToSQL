USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_COBZA_PAY]    Script Date: 10/9/2026 9:42:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   FUNCTION [T3].[FN_COBZA_PAY] 
( 
    @p_Invoice VARCHAR(255) 
)
RETURNS NUMERIC(15,2)
AS
BEGIN
    DECLARE @v_Return NUMERIC(15,2);

    DECLARE @Asign_Amount_Assigned NUMERIC(15,2);

    DECLARE ScrAssigned CURSOR LOCAL FAST_FORWARD FOR
        SELECT 
               SUM( ISNULL( Cobza.Importe, 0 ) )  AS Amount_Assigned
          FROM T3.CFDI_Cobranza Cobza
          WHERE Cobza.Factura = @p_Invoice;

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

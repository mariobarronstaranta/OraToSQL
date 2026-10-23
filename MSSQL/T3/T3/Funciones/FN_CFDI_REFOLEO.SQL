USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_CFDI_REFOLEO]    Script Date: 10/12/2026 10:59:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   FUNCTION [T3].[FN_CFDI_REFOLEO]
(
    @p_DocumentID VARCHAR(255),
    @p_Type       VARCHAR(255)
)
RETURNS VARCHAR(30)
AS
BEGIN
    DECLARE @v_Return VARCHAR(30)=0;

    DECLARE @Doc_Docto_SAP     VARCHAR(255);
    DECLARE @Doc_Docto_T3MX    VARCHAR(255);
    DECLARE @Doc_Tipo_Registro VARCHAR(255);

    DECLARE ScrVenta CURSOR LOCAL FAST_FORWARD FOR
        SELECT Docto_SAP, Docto_T3MX, Tipo_Registro
        FROM T3.CFDI_Refoleo
        WHERE Docto_T3MX      = @p_DocumentID
          AND Tipo_Registro   = 'Venta';

    DECLARE ScrDOI CURSOR LOCAL FAST_FORWARD FOR
        SELECT Docto_SAP        AS Factura_SAP, 
               Docto_T3MX       AS Docto_T3MX, 
               Tipo_Registro    AS Tipo_Registro
        FROM T3.CFDI_Refoleo
        WHERE Docto_SAP      = @p_DocumentID
          AND Tipo_Registro  = 'DOI' 
        UNION     
        SELECT Docto_SAP        AS Docto_SAP, 
               Docto_T3MX       AS Docto_T3MX,
               'DOI'            AS Tipo_Registro
        FROM T3.CFDI_Refoleo
        WHERE Docto_SAP      = @p_DocumentID
          AND Tipo_Registro  = 'Venta';

    SET @v_Return = @p_DocumentID;

    IF (@p_Type = 'Venta')
    BEGIN
        OPEN ScrVenta;
        FETCH NEXT FROM ScrVenta INTO @Doc_Docto_SAP, @Doc_Docto_T3MX, @Doc_Tipo_Registro;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @v_Return = @Doc_Docto_SAP;
            FETCH NEXT FROM ScrVenta INTO @Doc_Docto_SAP, @Doc_Docto_T3MX, @Doc_Tipo_Registro;
        END;

        CLOSE ScrVenta;
        DEALLOCATE ScrVenta;
    END
    ELSE IF (@p_Type = 'DOI')
    BEGIN
        OPEN ScrDOI;
        FETCH NEXT FROM ScrDOI INTO @Doc_Docto_SAP, @Doc_Docto_T3MX, @Doc_Tipo_Registro;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @v_Return = @Doc_Docto_T3MX;
            FETCH NEXT FROM ScrDOI INTO @Doc_Docto_SAP, @Doc_Docto_T3MX, @Doc_Tipo_Registro;
        END;

        CLOSE ScrDOI;
        DEALLOCATE ScrDOI;
    END;

    RETURN @v_Return;
END;

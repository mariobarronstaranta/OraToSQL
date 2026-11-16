USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_CTRO_EDICOM_PAGO]    Script Date: 11/12/2026 10:08:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   FUNCTION [T3].[FN_CTRO_EDICOM_PAGO]
(
    @sAccnt_ID VARCHAR(255)
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @sCtro_EDICOM VARCHAR(20);
    DECLARE @sCustomerSAP VARCHAR(20);
    DECLARE @nRecords     NUMERIC(3,0);

    DECLARE @Doc_Customer_SAP       VARCHAR(255);
    DECLARE @Doc_Centro_Cobza       VARCHAR(255);
    DECLARE @Doc_Visibilidad_EDICOM VARCHAR(255);
    DECLARE @Vta_Ctro               VARCHAR(255);
    
    DECLARE @Vta_Ant_Ctro           VARCHAR(255);

    DECLARE ScrPagos CURSOR LOCAL FAST_FORWARD FOR
        SELECT HO.Customer                         AS Customer_SAP,
               HO.Ctro_Cobza                       AS Centro_Cobza,
               ISNULL( HO.Ctro_EDICOM, '' )        AS Visibilidad_EDICOM
        FROM EAI_Owner.MX_Head_Office HO
        WHERE HO.Customer = @sAccnt_ID;

    DECLARE ScrCobzaLocal CURSOR LOCAL FAST_FORWARD FOR
        SELECT MAX( Ctro ) AS Ctro
        FROM T3.Mov_Cliente
        WHERE Cliente_SAP = @sAccnt_ID;        

    DECLARE ScrCobzaLocal_Ant CURSOR LOCAL FAST_FORWARD FOR
        SELECT MAX( SUBSTRING( Territorio_Delivery, 6, 4 ) ) AS Ctro
        FROM EAI.Cliente_Siebel
        WHERE Cliente_SAP = @sAccnt_ID;                


    SET @sCtro_EDICOM = 'MXAB';
    SET @nRecords     = 0;

    OPEN ScrPagos;
    FETCH NEXT FROM ScrPagos INTO @Doc_Customer_SAP, @Doc_Centro_Cobza, @Doc_Visibilidad_EDICOM;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nRecords     = @nRecords + 1;
        SET @sCustomerSAP = @Doc_Customer_SAP;

        IF ( @Doc_Customer_SAP = '0000000000' )
        BEGIN
            OPEN ScrCobzaLocal;
            FETCH NEXT FROM ScrCobzaLocal INTO @Vta_Ctro;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sCtro_EDICOM = @Vta_Ctro;
                FETCH NEXT FROM ScrCobzaLocal INTO @Vta_Ctro;
            END;
            
            CLOSE ScrCobzaLocal; 
         END
        ELSE IF ( LEN( @Doc_Visibilidad_EDICOM ) >= 4 )
        BEGIN
            SET @sCtro_EDICOM = @Doc_Visibilidad_EDICOM;
        END;

        FETCH NEXT FROM ScrPagos INTO @Doc_Customer_SAP, @Doc_Centro_Cobza, @Doc_Visibilidad_EDICOM;
    END;

    CLOSE ScrPagos;
    DEALLOCATE ScrPagos;   

    IF ( @nRecords = 0 )
    BEGIN
        OPEN ScrCobzaLocal;
        FETCH NEXT FROM ScrCobzaLocal INTO @Vta_Ctro;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sCtro_EDICOM = @Vta_Ctro;
            FETCH NEXT FROM ScrCobzaLocal INTO @Vta_Ctro;
        END;
        
        CLOSE ScrCobzaLocal;
    END;
    DEALLOCATE ScrCobzaLocal;
    DEALLOCATE ScrCobzaLocal_Ant;

    RETURN ( @sCtro_EDICOM );
END;

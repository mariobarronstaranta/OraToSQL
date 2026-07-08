CREATE OR ALTER FUNCTION EAI_OWNER.FN_GET_CLIENTE_TMD
(
    @P_SAP_CUSTOMER_ID VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @sCustomer_TMD VARCHAR(50);

    -- Oracle inicializa con cadena vacía.
    -- En SQL Server se conserva como '' para respetar la salida esperada.
    SET @sCustomer_TMD = '';

    /*
        Equivalente al cursor Oracle:
        
        FOR Cte IN ScrCustomer LOOP
            sCustomer_TMD := Cte.Cliente_V3;
        END LOOP;

        Si existen múltiples registros para el mismo Cliente_SAP,
        el resultado no es determinístico, igual que en Oracle
        al no existir ORDER BY.
    */
    SELECT 
        @sCustomer_TMD = MC.Cliente_V3
    FROM T3.Mov_Cliente AS MC
    WHERE MC.Cliente_SAP = @P_SAP_CUSTOMER_ID;

    RETURN @sCustomer_TMD;
END;
GO
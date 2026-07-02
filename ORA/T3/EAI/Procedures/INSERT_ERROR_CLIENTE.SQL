create or replace PROCEDURE     "INSERT_ERROR_CLIENTE" 
   ( pCliente_V3    IN VARCHAR2,
     pCliente_SAP   IN VARCHAR2,
     pErr_Msg       IN VARCHAR2 )
IS	 
   nContador    NUMBER        ;
   sMsg         VARCHAR2(500) ;
BEGIN
   nContador := 0 ;
--   SELECT COUNT( * )   INTO   nContador
--      FROM EAI.CUSTOMERS_T3_ERROR_LOG
--      WHERE CUST_ID                 = pCliente_V3
--       AND RTRIM( ERR_DESCRIPTION ) = RTRIM( pErr_Msg );   
   
--   IF ( NVL( nContador, 0 ) = 0 ) THEN
      INSERT INTO CUSTOMERS_T3_ERROR_LOG
         ( Cust_ID, SAP_Number, Err_Description, SYSTEM, LOG_DATE )
      VALUES
          ( pCliente_V3, pCliente_SAP, pErr_Msg, 'XML', SYSDATE );
--   END IF ;				
--
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250) ;
      INSERT INTO DEBUG_T3 ( Fecha, Factura, Pedido, Cliente_SAP, Comentario )
         VALUES ( SYSDATE, 'ErrCliente', pCliente_V3, SUBSTR( pCliente_SAP, 1, 10), sMsg ) ;
      COMMIT ;
END INSERT_ERROR_CLIENTE ;
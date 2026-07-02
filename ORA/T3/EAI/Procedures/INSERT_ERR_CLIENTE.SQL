create or replace PROCEDURE     "INSERT_ERR_CLIENTE" 
   ( Cliente_V3    IN VARCHAR2,
     Cliente_SAP   IN VARCHAR2,
     Distribuidora IN VARCHAR2,
     Err_Msg       IN VARCHAR2 )
IS	 

   nContador    NUMBER;	  
   sMsg         VARCHAR2(500);

BEGIN

   nContador := 0;

   SELECT COUNT(*) INTO nContador
   FROM CUSTOMERS_T3_ERROR_LOG
   WHERE CUST_ID = Cliente_V3
     --AND CTRO = Distribuidora
	   AND RTRIM( ERR_DESCRIPTION ) = RTRIM( Err_Msg );   
   
   IF NVL( nContador, 0 ) = 0 THEN
   	  	INSERT INTO CUSTOMERS_T3_ERROR_LOG
		 		( Cust_ID, SAP_Number, Ctro, Err_Description, SYSTEM, LOG_DATE )
		VALUES
        ( Cliente_V3, Cliente_SAP, Distribuidora, Err_Msg, 'XML', SYSDATE );
   ELSE
   	    UPDATE CUSTOMERS_T3_ERROR_LOG
		       SET LOG_DATE = SYSDATE,
               CTRO     = Distribuidora
         WHERE CUST_ID  = Cliente_V3
		       --AND CTRO    = Distribuidora
           AND RTRIM( ERR_DESCRIPTION ) = RTRIM( Err_Msg );   		  	
	
   END IF;				
--
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250) ;
      INSERT INTO DEBUG_T3 ( Fecha, Factura, Pedido, Cliente_SAP, Comentario )
           VALUES ( SYSDATE, 'ErrCliente', Cliente_V3, SUBSTR( Cliente_SAP, 1, 10), sMsg ) ;
      COMMIT ;

END Insert_Err_Cliente ;
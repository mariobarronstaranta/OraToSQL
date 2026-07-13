create or replace PROCEDURE           "WA_RESEND_CFDI" 
  ( pDias    IN NUMBER DEFAULT 4,
    pOutput  IN NUMBER DEFAULT 0 )
IS
--        
   nIndice       NUMBER(4)     ;
   sOrd_Row_ID   VARCHAR2(50)  ;
   sLogin        VARCHAR2(50)  ;
   sInvLoc_ID    VARCHAR2(50)  ;
   sMsg          VARCHAR2(500) ;   
   v_ID          VARCHAR2(020) ;
   sErrorCode    VARCHAR2(020) ;
   sUserRow_ID   VARCHAR2(030) ;
--
   CURSOR ScrDocuments IS
      SELECT * FROM T3.CFDI_Documentos
         WHERE Fecha_Liberacion   >= TRUNC( SYSDATE - pDias )
           AND Fecha_Envio        IS NOT NULL
           AND LENGTH( ID_Envio ) <= 4        ;
BEGIN
   nIndice := 0 ;
   FOR Doc IN ScrDocuments LOOP
      UPDATE T3.CFDI_Documentos SET Fecha_Envio = NULL, ID_Envio = NULL, Status = NULL
         WHERE Nota_Venta = Doc.Nota_Venta  ;
      INSERT INTO EAI_Owner.WA_Logging
             ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
         VALUES
             ( SYSDATE , USER, 
               SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
               SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
               SYS_CONTEXT( 'USERENV' , 'HOST'       ),
               Doc.Nota_Venta, 'EAI_Owner.WA_Resend_CFDI' ) ;         
   END LOOP ;
   COMMIT ;
   IF ( ( pOutput > 0 ) AND ( nIndice > 0 ) ) THEN
      DBMS_Output.Put_Line( 'Documentos -> ' || nIndice ) ;
   END IF ;   
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        ,
	        STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA_RESEND_CFDI'   , v_ID                  , SYSDATE             , NULL           ,
          'Error'            , 'WA_RESEND_CFDI'      , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;   
END WA_RESEND_CFDI ;
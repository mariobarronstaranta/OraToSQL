create or replace PROCEDURE       "INSERT_FOLIOS_FE" (
	 v_ID                    IN VARCHAR2, 
	 v_PO_NUMBER             IN VARCHAR2, 
	 v_DELIVERY_REF          IN VARCHAR2
   )
IS
   sMsg       VARCHAR2(500) ;  
   nCount     NUMBER(05)    ;
   nDate      NUMBER(10)    ;
-- sXML       SYS.XMLTYPE   ;
   CURSOR ScrPreventa IS
      SELECT DISTINCT
             PG.Entrega       AS Entrega       ,
             '1'              AS Status_Entrega,
             '0000'           AS Ubicacion     ,
             'U000000'        AS Rep_ID        ,
             TRUNC( SYSDATE ) AS Fecha_Entrega ,
             MC.Cliente_V3    AS Cliente_V3    ,
             MC.Cliente_SAP   AS Cliente_SAP
         FROM T3.Preventa_General PG,
              T3.Mov_Cliente      MC
         WHERE PG.Factura     = v_ID
           AND PG.Cliente_SAP = MC.Cliente_SAP ;
BEGIN
   UPDATE EAI.IFC_Folios_FE SET Entrada      = v_DELIVERY_REF,
                                Pedido       = v_PO_NUMBER   ,
                                Modificacion = SYSDATE
      WHERE Var_1 = V_ID ; 
   nCount := SQL%ROWCOUNT ;
   nDate  := TO_CHAR( SYSDATE, 'YYMMDD' ) * 10000 ;
   IF ( nCount = 0 ) THEN
      SELECT COUNT(*) AS Cnt_Records INTO nCount
         FROM EAI.IFC_Folios_FE
         WHERE Row_ID > nDate 
           AND ROW_ID < nDate + 9999 ; 
      IF ( NVL( nCount, 0 ) = 0 ) THEN
           nCount := 0 ;
      ELSIF ( nCount IS NULL ) THEN
           nCount := 0 ;
      END IF ;
      nCount := nCount + 1 ;
      INSERT INTO  EAI.IFC_Folios_FE
         ( Row_ID, Entrada, Pedido, Var_1, CreadoPor, Creacion )
      VALUES
         ( nDate + nCount, v_DELIVERY_REF, v_PO_NUMBER, V_ID, 'INTERFACE', SYSDATE ) ;
   END IF ;
   FOR Inv IN ScrPreventa LOOP
      UPDATE T3.Entrega SET Entrega = Inv.Entrega
         WHERE Factura = v_ID ;
      nCount := SQL%ROWCOUNT ;
      IF ( nCount = 0 ) THEN
         INSERT INTO T3.Entrega 
            ( Factura       , Entrega        , Fecha_Trn        , Status_Entrega   ,
              Cliente_V3    , Cliente_SAP    ,
              Ubicacion     , Rep_ID         , Fecha_Entrega     )
         VALUES
            ( v_ID          , Inv.Entrega    , SYSDATE          , Inv.Status_Entrega,
              Inv.Cliente_V3, Inv.Cliente_SAP,
              Inv.Ubicacion , Inv.Rep_ID     , Inv.Fecha_Entrega ) ;
      END IF ;   
   END LOOP ;
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                 , CREATED               , MESSAGE        ,
          REFERENCE          ,
          STATUS             , QUEUE_NAME         , SIEBEL_ERROR_MESSAGE  , SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT        , SEQUENCE              , PARENT_ROW_ID   )
      VALUES 
        ( 'Invound'          , v_ID               , SYSDATE               , sMsg           ,
          v_ID               ,
          'Error'            , 'INSERT_FOLIOS_FE' , NULL                  , 'PL/SQL'       ,
          NULL               , NULL               , NULL                  , NULL            ) ;
      COMMIT ;
END INSERT_FOLIOS_FE ;
create or replace PROCEDURE           "WA_BAT_PRODUCTORA" 
  ( pDays     NUMBER   DEFAULT 14  )
IS
--        
   nIndice       NUMBER(4)     ;
   sOrd_Row_ID   VARCHAR2(50)  ;
   sLogin        VARCHAR2(50)  ;
   sInvLoc_ID    VARCHAR2(50)  ;
   sMsg          VARCHAR2(500) ;   
   v_ID          VARCHAR2(020) ;
   sFactura      VARCHAR2(020) ;
   sUpdate       VARCHAR2(020) ;
   sErrorCode    VARCHAR2(020) ;
   sUserRow_ID   VARCHAR2(030) ;
--
   CURSOR ScrDocuments IS
      SELECT Factura, Entrega, Fecha_Trn, Fecha_Factura, Cliente_SAP, Valor_Subt, Valor_IVA, Fecha_Proc_BATMD, Fecha_Entrega
         FROM T3.Preventa_General
         WHERE SUBSTR( Factura, 1, 4 ) IN ( 'DPIN', 'DNIN', 'FPIN', 'FNIN'  )
           AND Fecha_Factura > ( SYSDATE - pDays )
           AND Fecha_Proc_BATMD IS NULL
         ORDER BY Fecha_Trn DESC ;        
--
   CURSOR ScrDetails IS
      SELECT PD.Factura, PD.Num_Linea, PD.Material, PD.Cantidad_Vta, PD.Unidad_Med_Vta, Prod.Nombre_Material, Prod.Unidad_Med_Vta AS UOM_CD, Prod.Cig_x_CLL, PD.Referencia_Pedido,
             PD.Cantidad_Vta      * 1000 / Prod.Cig_x_CLL    AS Cantidad_a_Facturar        ,
             PD.Referencia_Pedido * 1000 / Prod.Cig_x_CLL    AS Cantidad_a_Facturar_con_Dec,
             PD.RowID                                        AS Det_ROWID                  
         FROM T3.Preventa_Detalle PD, T3.Material Prod
         WHERE PD.Factura          = sFactura
           AND PD.Material         = Prod.Material
           AND PD.Unidad_Med_Vta  IN ( 'TH', 'MIL' )
           AND Prod.Material     NOT LIKE '50%' ;       
--
   CURSOR ScrFixIVA IS
      SELECT Factura, Num_Linea, Material, Valor_Subt, Valor_IVA, IVA_CFD
         FROM (
                SELECT Factura, Num_Linea, Material, Valor_Subt, Valor_IVA,
                       ROUND( Valor_Subt * ROUND( Valor_IVA * 100 / Valor_Subt, 0 ) / 100, 2 ) AS IVA_CFD
                FROM T3.Preventa_Detalle 
                WHERE Factura = sFactura
              )
      WHERE Valor_IVA != IVA_CFD ;                    
BEGIN
   FOR Doc in ScrDocuments LOOP
      sUpdate  := 'NO'        ; 
      sFactura := Doc.Factura ;
      v_ID     := Doc.Factura ; 
      IF ( ( Doc.Fecha_Proc_BATMD IS NULL ) OR ( TO_CHAR( Doc.Fecha_Proc_BATMD, 'YYYY' ) = '2999' ) ) THEN
         sUpdate := 'YES'     ;
      END IF ;
      IF ( sUpdate = 'YES' ) THEN
         nIndice := 0 ;
         FOR Det IN ScrDetails LOOP
            UPDATE T3.Preventa_Detalle  SET Cantidad_Vta   = Det.Cantidad_a_Facturar_con_Dec,
                                           Unidad_Med_Vta = Det.UOM_CD
               WHERE ROWID = Det.Det_ROWID ;
            nIndice := nIndice + 1 ;   
         END LOOP ;
         IF ( nIndice > 0 ) THEN
            UPDATE T3.Preventa_General SET Fecha_Proc_BATMD =  NULL
               WHERE Factura = sFactura ;               
         /* INSERT INTO EAI_Owner.WA_Logging
                   ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
                VALUES
                   ( SYSDATE , USER, 
                     SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
                     SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
                     SYS_CONTEXT( 'USERENV' , 'HOST'       ),
                     sFactura, 'EAI_Owner.WA_BAT_PRODUCTORA (' || TO_CHAR( nIndice ) || ' )' ) ;  */                            
            COMMIT ;
         END IF ;
         nIndice := 0 ;
         FOR Det IN ScrFixIVA LOOP
            nIndice := nIndice + 1 ;
            UPDATE T3.Preventa_Detalle SET Valor_IVA = Det.IVA_CFD 
               WHERE Factura = Det.Factura
                 AND Num_Linea = Det.Num_Linea
                 AND Material  = Det.Material ;
         END LOOP ;   
         IF ( nIndice > 0 ) THEN
             UPDATE T3.Preventa_General SET Valor_IVA = ( SELECT SUM( Valor_IVA ) FROM T3.Preventa_Detalle WHERE Factura = sFactura ) 
                WHERE Factura = sFactura ;
            INSERT INTO EAI_Owner.WA_Logging
                   ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
                VALUES
                   ( SYSDATE , USER, 
                     SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
                     SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
                     SYS_CONTEXT( 'USERENV' , 'HOST'       ),
                     sFactura, 'EAI_Owner.WA_BAT_PRODUCTORA ( IVA ' || TO_CHAR( nIndice ) || ' )' ) ;                                            
         END IF ;
      END IF ;   
   END LOOP ;   
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	      SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA_BAT_PRODUCTORA', v_ID                  , SYSDATE             , NULL           ,
          'Error'            , 'WA_BAT_PRODUCTORA'   , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;   
END WA_BAT_PRODUCTORA ;
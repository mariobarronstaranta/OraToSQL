create or replace PROCEDURE    "PROC_T3_OT_DOCTOS" IS
---
   sFACTURA             VARCHAR2(022) ;  
   sPROCESAR            VARCHAR2(022) ;  
--
   v_ID                 VARCHAR2(050) ;
   sErrorCode           VARCHAR2(030) ;      
   sMsg                 VARCHAR2(300) ;
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso3            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;      
--
   CURSOR PREVENTAS IS
      SELECT PG.FACTURA, PG.CTRO, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA,
             PG.VALOR_SUBT + PG.VALOR_IVA AS TOTAL, 
             SUM( PD.VALOR_SUBT + PD.VALOR_IVA ) AS TOTAL_DETALLE
         FROM PREVENTA_GENERAL PG, PREVENTA_DETALLE PD
         WHERE PG.FECHA_PROC_BATMD IS NULL
           AND PG.CLASE_FACTURA    IN ( 'C025', 'C0FX', 'C030', 'C031' ) 
--         AND PG.CLASE_FACTURA    IN ( 'Z019', 'Z0FX', 'C025', 'C019', 'C0FX' ) 
           AND PG.FACTURA          =  PD.FACTURA
       GROUP BY PG.FACTURA, PG.CTRO, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA, PG.VALOR_SUBT + PG.VALOR_IVA ;              
--       
   CURSOR PREVENTAS_MX06 IS
      SELECT PG.FACTURA, PG.CTRO, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA,
             PG.VALOR_SUBT + PG.VALOR_IVA AS TOTAL
         FROM T3.PREVENTA_GENERAL PG, 
              T3.CFDI_DOCUMENTOS  PAC
         WHERE PG.FECHA_PROC_BATMD   > TRUNC( SYSDATE )
           AND PG.CLASE_FACTURA     IN ( 'C005', 'C006' ) 
           AND PG.FECHA_CANCELACION IS NULL 
           AND PG.FACTURA           = PAC.NOTA_VENTA(+)
           AND PAC.FECHA_LIBERACION IS NULL ;
--
   CURSOR PEDIMENTOS IS
      SELECT PG.FACTURA, PG.CTRO, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA,
             PG.VALOR_SUBT + PG.VALOR_IVA AS TOTAL, 
             SUM( PD.VALOR_SUBT + PD.VALOR_IVA ) AS TOTAL_DETALLE
         FROM T3.PREVENTA_GENERAL      PG  , 
              T3.PREVENTA_DETALLE      PD  , 
              T3.CFDI_DOCUMENTOS       CFDI,
              T3.RF_Pedimento_Detalle  Ped
         WHERE PG.FECHA_PROC_BATMD    > TRUNC( SYSDATE - 1 )
           AND PG.CLASE_FACTURA      IN ( 'C020' ) 
           AND PG.FACTURA             =  PD.FACTURA
           AND PG.FACTURA             =  CFDI.NOTA_VENTA(+)
           AND CFDI.FECHA_LIBERACION IS NULL
           AND PG.FACTURA             =  Ped.Folio_Fiscal
           AND NVL( Ped.Pedimento, 'NO' ) != 'NO'
       GROUP BY PG.FACTURA, PG.CTRO, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA, PG.VALOR_SUBT + PG.VALOR_IVA ;              
--           
   CURSOR PREVENTAS_BLOQ IS           
      SELECT PG.FACTURA, PG.CTRO, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA,
             PG.VALOR_SUBT + PG.VALOR_IVA AS TOTAL, 
             SUM( PD.VALOR_SUBT + PD.VALOR_IVA ) AS TOTAL_DETALLE
         FROM PREVENTA_GENERAL PG, PREVENTA_DETALLE PD
         WHERE TO_CHAR( PG.FECHA_PROC_BATMD, 'YYYY' ) = '2999'
           AND PG.CLASE_FACTURA    IN ( 'Z019', 'Z0FX', 'Z020', 'Z021', 'Z022',
                                        'C019', 'C0FX', 'C020', 'C021', 'C022' ) 
           AND PG.FACTURA          =  PD.FACTURA
       GROUP BY PG.FACTURA, PG.CTRO, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA, PG.VALOR_SUBT + PG.VALOR_IVA ;              
--
   CURSOR ScrDetalle IS
      SELECT 
             PD.Factura      , PD.Num_Linea   , PD.Material    , PD.Cantidad_Vta    ,
             NVL( PD.Valor_Subt, 0 )                            AS Valor_Subt       ,
             NVL( PD.Valor_Subt, 0 ) + NVL( PD.Valor_IVA, 0 )   AS Valor_Tot        ,
             NULL                                               AS Valor_Desc       ,
             NVL( PD.Valor_IVA , 0 )                            AS Valor_IVA        ,
--       
             NVL( PD.Bonif_Subt, 0 )                            AS Bonif_Subt       , 
             NVL( PD.Bonif_IVA , 0 )                            AS Bonif_IVA        , 
             NVL( PD.Bonif_Porc, 0 )                            AS Bonif_Porc       , 
             NVL( PD.Bonif_Vol , 0 )                            AS Bonif_Vol        ,
             PD.Referencia_Pedido                               AS Referencia_Pedido,
             NVL( SKU.Nombre_Material , 'SKU-Vacio' )           AS SKU_Name
      FROM T3.Preventa_General   PG ,
           T3.Preventa_Detalle   PD ,
           T3.Material           SKU
      WHERE PG.Factura   = sFACTURA
        AND PG.Factura   = PD.Factura
        AND PD.Material  = SKU.Material(+) 
        AND ( ( SKU.Nombre_Material    IS NULL )
           OR ( ( PD.Referencia_Pedido IS NULL ) AND ( PD.Cantidad_Vta = 0 ) ) ) ;
--
   CURSOR Cancelaciones IS
      SELECT PG.Factura 
      FROM T3.Preventa_General PG
      WHERE PG.Clase_Factura IN ( 'C005', 'C006' )
        AND Fecha_Cancelacion > TRUNC( SYSDATE - 1 ) ;
BEGIN
   UPDATE T3.Preventa_General SET Fecha_Proc_BATMD = NULL
      WHERE Fecha_Trn         > SYSDATE - 7
        AND Fecha_Proc_BATMD  > SYSDATE + 7
        AND Clase_Factura    IN ( 'C019', 'C025', 'C0FX' ) ;
   nProceso  := 882 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso1 := 000 ;
   nProceso2 := 000 ;
   nProceso3 := 000 ;
   nProceso4 := 000 ;
--
   FOR REN IN PREVENTAS LOOP
      sPROCESAR := 'SI'        ;
      sFACTURA  := REN.Factura ;
      v_ID      := REN.Factura ;
      FOR DET IN ScrDetalle LOOP
         IF ( DET.SKU_Name = 'SKU-Vacio' ) THEN
            sPROCESAR := 'NO' ;
         END IF ;   
         IF ( ( DET.Referencia_Pedido IS NULL ) AND ( DET.Cantidad_Vta = 0 ) ) THEN
            sPROCESAR := 'NO' ;
         END IF ;   
      END LOOP ;
      IF ( sPROCESAR = 'SI' ) THEN
        sPROCESAR := FN_INTERCOMPANY_UM(  REN.Clase_Factura,  REN.Factura ) ;
      END IF ;
      IF ( ( ABS( REN.TOTAL - REN.TOTAL_DETALLE ) < 0.10 ) AND ( sPROCESAR = 'SI' ) ) THEN
--       DBMS_Output.Put_Line( 'PROC_CFDI_INSERTAR_IFC ->' || REN.Factura ) ;
         PROC_CFDI_INSERTAR_IFC( REN.Factura ) ;
      END IF ;   
      IF ( ( REN.Clase_Factura IN ( 'C019', 'C0FX', 'C020', 'C021', 'C022', 'C025', 'C030', 'C031' ) )  AND ( sPROCESAR = 'SI' ) ) THEN
--       DBMS_Output.Put_Line( 'PROC_CFDI_INSERTAR_PAC ->' || REN.Factura ) ;
         PROC_CFDI_INSERTAR_PAC( REN.Factura ) ;
         nProceso1 := nProceso1 + 1 ;
      END IF ;
   END LOOP ;
--
--   FOR REN IN PREVENTAS_MX06 LOOP
--      IF ( REN.Clase_Factura IN ( 'C005', 'C006' ) ) THEN
--         PROC_CFDI_INSERTAR_PAC( REN.Factura ) ;
--      END IF ;
--   END LOOP ;
--   
   FOR REN IN PEDIMENTOS LOOP
      IF ( ( ABS( REN.TOTAL - REN.TOTAL_DETALLE ) < 0.10 )  ) THEN
         PROC_CFDI_INSERTAR_PAC( REN.Factura ) ;
      END IF ;
   END LOOP ;
/*
   FOR REN IN PREVENTAS_BLOQ LOOP
      sPROCESAR := 'SI' ; 
      sFACTURA  := REN.Factura ;
      FOR DET IN ScrDetalle LOOP
         sPROCESAR := 'NO' ;
      END LOOP ;
      IF ( ( ABS( REN.TOTAL - REN.TOTAL_DETALLE ) < 0.10 ) AND ( sPROCESAR = 'SI' ) ) THEN
         PROC_CFDI_INSERTAR_IFC( REN.Factura ) ;
      END IF ;   
   END LOOP ; */
   FOR Canc IN Cancelaciones LOOP
       PROC_CFDI_INSERTAR_CANCEL( Canc.Factura ) ;
   END LOOP ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = nProceso4
       WHERE PID = nPID  ;         
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE           , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_T3_OT_DOCTOS' , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;
      COMMIT ;       
    
END; -- Procedure
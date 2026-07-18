create or replace PROCEDURE    PROC_CFDI_LIBERACION_NOTA
      ( pOutput  NUMBER DEFAULT 10 )
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(030) ;         
--   
   strID           VARCHAR2(050) ;
   dtInicio        DATE          ;
   nPID            NUMBER(08)    ;
   nProceso        NUMBER(08)    ;
   nProceso1       NUMBER(08)    ;
   nProceso2       NUMBER(08)    ;
   nProceso3       NUMBER(08)    ;
   nProceso4       NUMBER(08)    ;
   sFechaInicio    VARCHAR2(30)  ;
   sRTamount       NUMBER(13,3)  ;
   sRTPending      NUMBER(13,3)  ;
   sRTDoc_Num      VARCHAR2(50)  ;
   sRTCliente_SAP  VARCHAR2(50)  ; 
   nRTPaid         NUMBER(15,2)  ; 
--
   CURSOR ScrPrompt IS
       SELECT 
              Info.Factura
       FROM (
              SELECT Doc.Factura, Doc.Ctro, Doc.Fecha_Factura_T3, Doc.RFC_Factura, Doc.RFC_Cliente, Doc.VoidDoc, CFD.Fecha_Liberacion
                 FROM T3.CFDI_Documento_Paso Doc,
                      T3.CFDI_Documentos     CFD
                 WHERE Doc.Tipo_Docto        = 'C004'
                   AND Doc.RFC_Factura      != 'XAXX010101000'
                   AND Doc.Factura           = CFD.Nota_Venta(+)
                   AND DOc.VoidDoc          IS NULL
                   AND Doc.Fecha_Factura_T3 >= TO_DATE( sFechaInicio, 'YYYYMMDD' )
                   AND CFD.Fecha_Liberacion IS NULL
            ) Info
            WHERE Info.Factura NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_CFDI_GENERAR_MX06' AND Referencia IS NOT NULL ) 
              AND Info.Factura NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_V40_GENERAR_MX06'  AND Referencia IS NOT NULL )
      UNION
       SELECT 
              Info.Nota_Devolucion                  AS Factura         
          FROM (       
                 SELECT Vta.Ctro, Vta.Invc_dt, Vta.Doc_Num, Vta.Nota_Venta_CFDI, Vta.Ttl_Invc_Amt, Vta.RFC, Vta.Cliente_SAP, Vta.Nombre_Cliente, 
                        Dev.Doc_Num AS Nota_Devolucion,
                        Dev.VoidDoc AS Nota_Doc_Void
                 FROM (
                        SELECT * FROM EAI.CFDI_Bitacora Bit
                           WHERE Bit.Nota_Venta_CFDI IS NOT NULL
                             AND Bit.VoidDoc         IS NOT NULL
                             AND Bit.Tipo_Vta        = 'Vta'
                             AND Bit.Invc_dt         >= TO_DATE( sFechaInicio, 'YYYYMMDD' )
                      ) Vta,
                      EAI.CFDI_Bitacora      Dev,
                      T3.CFDI_Documentos     CFD
                 WHERE Vta.Cliente_SAP      = Dev.Cliente_SAP
                   AND TRUNC( Vta.Invc_dt ) = TRUNC( Dev.Invc_dt )
                   AND Vta.Ttl_Invc_Amt     = Dev.Ttl_Invc_Amt
                   AND Dev.Tipo_Vta         = 'Dev'
                   AND Dev.Nota_Venta_CFDI  IS NULL
                   AND Dev.VoidDoc          IS NOT NULL  
                   AND Dev.Doc_Num           = CFD.Nota_Venta(+)
                   AND CFD.Fecha_Liberacion IS NULL                       
               ) Info
            WHERE Info.Nota_Devolucion NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_CFDI_GENERAR_MX06' AND Referencia IS NOT NULL ) 
              AND Info.Nota_Devolucion NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_V40_GENERAR_MX06'  AND Referencia IS NOT NULL ) ;                             
--  
   CURSOR ScrPresales IS 
       SELECT 
              Info.Factura
       FROM (
              SELECT Doc.Factura, Doc.Ctro, Doc.Fecha_Factura
                 FROM T3.Preventa_General    Doc,
                      T3.CFDI_Documentos     CFD
                 WHERE Doc.Clase_Factura      = 'C006'
                   AND Doc.Factura            = CFD.Nota_Venta(+)
                   AND Doc.Fecha_Factura     >= TO_DATE( sFechaInicio, 'YYYYMMDD' )
                   AND Doc.Fecha_Proc_BATMD  IS NOT NULL
                   AND Doc.Fecha_Cancelacion IS NULL
                   AND CFD.Fecha_Liberacion  IS NULL
            ) Info
       WHERE Info.Factura NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_CFDI_GENERAR_MX06' AND Referencia IS NOT NULL ) 
         AND Info.Factura NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_V40_GENERAR_MX06'  AND Referencia IS NOT NULL ) ;
--  
   CURSOR ScrRebates IS   
       SELECT 
              Info.Factura, Info.Integration_ID
       FROM (
              SELECT Doc.Factura, Doc.Ctro, Doc.Fecha_Factura, 
                     Doc.Entrega || '-' || Doc.Referencia  AS Integration_ID
                 FROM T3.Preventa_General    Doc,
                      T3.CFDI_Documentos     CFD
                 WHERE Doc.Clase_Factura     IN ( 'C019', 'C025' )
                   AND Doc.Factura            = CFD.Nota_Venta(+)
                   AND Doc.Fecha_Factura     >= TO_DATE( sFechaInicio, 'YYYYMMDD' )
                   AND Doc.Fecha_Proc_BATMD  IS NOT NULL
                   AND Doc.Fecha_Cancelacion IS NULL
                   AND CFD.Fecha_Liberacion  IS NULL
            ) Info
       WHERE Info.Integration_ID NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_CFDI_GENERAR_MX06' AND Referencia IS NOT NULL ) 
         AND Info.Integration_ID NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_V40_GENERAR_MX06'  AND Referencia IS NOT NULL )
         AND Info.Factura        NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_CFDI_GENERAR_MX06' AND Referencia IS NOT NULL ) 
         AND Info.Factura        NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log WHERE Rutina = 'PROC_V40_GENERAR_MX06'  AND Referencia IS NOT NULL ) ;
--
BEGIN
--
   T3.WA_CFDI_RENV_CM(0);
   COMMIT ;
--
   dtInicio     := SYSDATE    ;
   nProceso     := 610        ;
   nProceso1    := 0          ;
   nProceso2    := 0          ;
   nProceso3    := 0          ;
   nProceso4    := 0          ;
   sFechaInicio := '20220101' ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;      
   FOR Doc IN ScrPrompt LOOP   
      strID     := Doc.Factura   ;
      nProceso1 := nProceso1 + 1 ;
      
      EAI_OWNER.SF_GET_CREDIT_DATA (strID, sRTDoc_Num, sRTCliente_SAP, sRTAmount, sRTPending, nRTPaid);

     
      IF ( NVL( sRTPending, 0 ) < 5.04) THEN
          IF ( NVL( pOutput, 0 ) <= 1 ) THEN
             DBMS_Output.Put_Line( Doc.factura ) ;
          ELSE
          -- T3.PROC_VSF_GENERAR_MX06_CM( Doc.Factura, NULL ) ;
             T3.PROC_V40_GENERAR_MX06_CM( Doc.Factura, NULL ) ;
          END IF ;   
      END IF;    
   
   END LOOP ;
   COMMIT ;
   FOR Doc IN ScrPresales LOOP   
      strID     := Doc.Factura   ;
      nProceso2 := nProceso2 + 1 ;
      
      EAI_OWNER.SF_GET_CREDIT_DATA (strID, sRTDoc_Num, sRTCliente_SAP, sRTAmount, sRTPending, nRTPaid);
     
      IF ( NVL( sRTPending, 0 ) < 5.04) THEN
          IF ( NVL( pOutput, 0 ) <= 1 ) THEN
             DBMS_Output.Put_Line( Doc.factura ) ;
          ELSE
          -- T3.PROC_VSF_GENERAR_MX06_CM( Doc.Factura, NULL ) ;
             T3.PROC_V40_GENERAR_MX06_CM( Doc.Factura, NULL ) ;
          END IF ;   
      END IF;  
            
   END LOOP ;
   COMMIT ;
   FOR Doc IN ScrRebates LOOP   
      strID     := Doc.Factura   ;
      nProceso3 := nProceso3 + 1 ;
      
      EAI_OWNER.SF_GET_CREDIT_DATA (strID, sRTDoc_Num, sRTCliente_SAP, sRTAmount, sRTPending, nRTPaid);
     
      IF ( NVL( sRTPending, 0 ) < 5.04) THEN
          IF ( NVL( pOutput, 0 ) <= 1 ) THEN
             DBMS_Output.Put_Line( Doc.factura ) ;
          ELSE
          -- T3.PROC_VSF_GENERAR_MX06_CM( Doc.Factura, NULL ) ;
             T3.PROC_V40_GENERAR_MX06_CM( Doc.Factura, NULL ) ;
          END IF ;   
      END IF;        
      
   END LOOP ;
   COMMIT ;
-- IF ( ( nProceso1 + nProceso2 + nProceso3 ) > 0 ) THEN
--    nPID := SEQ_CFD.Nextval ;  
--    INSERT INTO T3.RF_PROCESOS_LOG 
--       ( PID , Proceso , Fecha_Proc_BATMD, Inicio  , Fin    , Proceso_1, Proceso_2, Proceso_3, Proceso_4 )
--    VALUES 
--       ( nPID, nProceso, NULL, dtInicio, SYSDATE, nProceso1, nProceso2, nProceso3, nProceso4 ) ;   
-- END IF ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = nProceso4
       WHERE PID = nPID  ;         
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_LIBERACION_NOTA' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
--      INSERT INTO T3.RF_ERROR_LOG 
--         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
--      VALUES
--       ( SYSDATE, 'PROC_CFDI_LIBERACION_NOTA', strID, sMsg ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                  , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                 , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT                , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                      , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CFDI_LIBERACION_NOTA', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                       , NULL                , NULL            ) ;
         
      COMMIT ;
END PROC_CFDI_LIBERACION_NOTA ;
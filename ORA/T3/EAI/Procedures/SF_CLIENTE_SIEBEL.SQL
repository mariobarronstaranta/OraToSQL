create or replace PROCEDURE     "SF_CLIENTE_SIEBEL" 
IS
-- Define Variables
   v_ID                 VARCHAR2(050) ;
   sErrorCode           VARCHAR2(030) ;      
   sMsg                 VARCHAR2(300) ;
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;
--
BEGIN
   nProceso  := 816 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso1 := 000 ;
   nProceso2 := 000 ;
--
   UPDATE CONTROL_REPORTE SET Inicio = SYSDATE, Fin = NULL
      WHERE REPORTE = 'REPORTE CLIENTE_SIEBEL' ;
   EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.Cliente_Siebel' ) ;
   INSERT INTO EAI.CLIENTE_SIEBEL
        ( Cliente_V3, Cliente_SAP, Dias_Cdto, RFC, Lista_IVA, Lista_Precio, Territorio, Tipo_territorio, 
          Territorio_Delivery, Tipo_Territorio_Delivery, Dist_Cobza, forma_Pago, Canal )
   SELECT MC.Cliente_V3                  AS Cliente_V3              , 
          MC.Cliente_SAP                 AS Cliente_SAP             , 
          NVL( MC.Dias_Cdto, 0 )         AS Dias_Cdto               , 
          MC.RFC                         AS RFC                     , 
          MC.Lista_IVA                   AS Lista_IVA               , 
          MC.Lista_Precio                AS Lista_Precio            , 
          Territorio                     AS Territorio              , 
          Tipo_Territorio                AS Tipo_Territorio         ,
          Territorio                     AS Territorio_delivery     , 
          Tipo_Territorio                AS Tipo_Territorio_Delivery,
          '00'                           AS Dist_Cobza              ,
          CASE
             WHEN PC.Branch_Number IS NOT NULL THEN 'Pago Central'
             WHEN Ad.RFC           IS NOT NULL THEN 'Pago Central'
             ELSE
               'Pago Directo'
          END                            AS Forma_Pago              ,
          '00'                           AS Canal
      FROM T3.Mov_Cliente MC,
           (
             SELECT DISTINCT BRANCH_NUMBER FROM EAI.TAO_CARTERA_SAP_LDR
                WHERE BRANCH_NUMBER IS NOT NULL
           ) PC,
           T3.CFDI_Addenda Ad
      WHERE MC.Cliente_SAP IS NOT NULL
        AND LENGTH( MC.Cliente_SAP ) = 10
        AND MC.Cliente_SAP = PC.Branch_Number(+)
        AND MC.RFC         = Ad.RFC(+)
        AND ( ( NVL( MC.Siebel_Loc, MC.Cliente_V3 ) != MC.Cliente_V3 )
            OR ( MC.Fecha_Syncr > TO_DATE( '20200921', 'YYYYMMDD' ) ) ) ;
     nProceso4 := SQL%ROWCOUNT ;
--
   UPDATE CONTROL_REPORTE SET Fin = SYSDATE
      WHERE REPORTE = 'REPORTE CLIENTE_SIEBEL' ;
   COMMIT ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = 0        , Proceso_4 = nProceso4
       WHERE PID = nPID  ;   
   COMMIT ;       
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE            , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                 , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'SF_CLIENTE_SIEBEL'  , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;      
END ; -- Procedure
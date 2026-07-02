create or replace PROCEDURE     CCEA_DATA_UNLOAD
IS
    v_ID                VARCHAR2(050) ;       
    sMsg                VARCHAR2(500) ;   
    sErrorCode          VARCHAR2(020) ;
    nPID                NUMBER(08)    ;
    nProceso            NUMBER(08)    ;
    nProceso3           NUMBER(08)    ;
    nProceso4           NUMBER(08)    ;
 --
BEGIN
    nProceso  := 727 ;
    nPID      := EAI_Owner.ProcessID.NextVal ;
    EAI_Owner.Log_Start( nProceso ) ;
    INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
       VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
    nProceso3 := 0 ;
    nProceso4 := 0 ;

    EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.CC_DATA_UNLOAD' ) ;
      INSERT INTO EAI.CC_DATA_UNLOAD  (
         PLANT             , TERRITORY         , UNLOAD_DATE       , UNLOAD_REF_NUMBER ,
         MATERIAL          , UOM               , SAP_QTY           , ACTUAL_QTY        ,
         UMB               , UOM_1             , UOM_2              )
      SELECT 
             Plant                            AS PLANT             ,
             Territory                        AS TERRITORY         ,
             Document_Date                    AS UNLOAD_DATE       ,
             Document_Number                  AS UNLOAD_REF_NUMBER ,
             Material                         AS MATERIAL          ,
             UOM                              AS UOM               ,
             TRIM( TO_CHAR( SAP_QTY    ) )    AS SAP_QTY           ,
             TRIM( TO_CHAR( ACTUAL_QTY ) )    AS ACTUAL_QTY        ,
             UM                               AS UMB               ,
             TRIM( TO_CHAR( UOM_1      ) )    AS UOM_1             ,
             TRIM( TO_CHAR( UOM_2      ) )    AS UOM_2
         FROM (
                SELECT Doc.ShippingPoint                           AS Plant          ,
                       SUBSTR( Cte.Nombre, 15, 4 )                 AS Territory      ,
                       SUBSTR( Doc.DocumentDate, 1, 4 ) || '-' ||            
                       SUBSTR( Doc.DocumentDate, 5, 2 ) || '-' ||
                       SUBSTR( Doc.DocumentDate, 7, 2 )            AS Document_Date  ,
--            Doc.Order_Num                               AS Document_Number,
                       Det.MaterialDescripcion                     AS Document_Number,
                       Det.Material                                AS Material       ,
                       Det.Cantidad                                AS Actual_Qty     ,
                       Det.UnidadMedida                            AS UOM            ,
                       ( ( Det.Cantidad * Mat.Cig_x_CLL ) / NVL( Conv.SAP_UM_Conv, 1000 ) ) 
                                                                   AS SAP_Qty        ,
                       NVL( Conv.SAP_UM_Base, 'TH' )               AS UM             ,
                       NVL( Mat.Cig_x_CLL, 0 )                     AS UOM_1          ,
                       NVL( Mat.Cig_x_PAQ, 0 )                     AS UOM_2 
                   FROM 
                       ( SELECT TO_CHAR( ADD_MONTHS( TO_DATE( Start_Date, 'DD/MM/YYYY' ), - 1 ), 'YYYYMM' ) AS Begins
                            FROM EAI.FC__Time_Window ) TW  ,
                        EAI_Owner.tmp_Document_Header  Doc ,
                        EAI_Owner.tmp_Document_Detail  Det ,
                        T3.Material                    Mat ,
                        T3.Material_SAP                Conv,
                        T3.Mov_Cliente                 Cte
                   WHERE SUBSTR( Doc.DocumentDate, 1, 6 ) >= TW.Begins
                     AND Doc.DocumentDate >= '20200917'
                     AND Doc.MetodoPago   = 'Van Replenishment'
                     AND Doc.DeliveryType = 'Stock Discard'
                     AND Doc.Cust_to_SAP  LIKE '009%'
                     AND Doc.ReferenceID  = Det.ReferenceID
                     AND Det.Material     = Mat.Material      
                     AND Det.Material     = Conv.Material(+)
                     AND Doc.Cust_to_SAP  = Cte.Cliente_SAP
                     AND Cte.Nombre       LIKE 'VAN%'
             ) ;
          nProceso4 := SQL%ROWCOUNT ;
--
    UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
       WHERE Component = nProceso ;
    UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_3 = nProceso3,
                                                  Proceso_2 = 0, Proceso_4 = nProceso4
       WHERE PID = nPID  ;          
    COMMIT ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
          ( DIRECTION          , ID                    , CREATED             , MESSAGE        , JOB_PID,
            STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   ) 
        VALUES  
          ( 'Job Logging'      , v_ID                  , SYSDATE             , NULL           , nPID   ,
            'Error'            , 'CCEA_DATA_UNLOAD'    , sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL                  , NULL                , NULL            ) ;
        COMMIT ;   
END CCEA_DATA_UNLOAD ;
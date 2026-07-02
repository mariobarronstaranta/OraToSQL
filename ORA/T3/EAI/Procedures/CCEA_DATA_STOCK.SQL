create or replace PROCEDURE     CCEA_DATA_STOCK
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
    nProceso  := 722 ;
    nPID      := EAI_Owner.ProcessID.NextVal ;
    EAI_Owner.Log_Start( nProceso ) ;
    INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
       VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
    nProceso3 := 0 ;
    nProceso4 := 0 ;

    EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.CC_DATA_STOCK' ) ;
      INSERT INTO EAI.CC_DATA_STOCK  (
         PLANT          , TERRITORY      , STOCK_PARTNER  , PARTNER_NAME   ,
         MATERIAL       , UOM            , SAP_QTY        , ACTUAL_QTY     ,
         UMB            , UOM_1          , UOM_2           )
               SELECT
                   TRIM( T1.Planta )                          AS PLANT           ,
                   SUBSTR( T1.Partner_Name, 15, 4 )           AS TERRITORY       ,
                   LPAD( T1.Partner_ID, 10, '0' )             AS STOCK_PARTNER   ,
                   TRIM( T1.Partner_Name )                    AS PARTNER_NAME    ,
                   TRIM( T1.Material )                        AS MATERIAL        ,
                   TRIM( Mat.Unidad_Med_Vta )                 AS UOM             ,
                   TRIM( TO_CHAR( T1.Libre_Utilizacion )  )   AS SAP_QTY         ,
                   CASE
                       WHEN ( T1.UMB = 'TH' ) THEN TRIM( TO_CHAR( NVL( T1.Libre_Utilizacion, 0 ) * 1000 / DECODE( Mat.Unidad_Med_Vta, 'CAJ', NVL(  Mat.Cig_x_CLL, 1 ) , NVL( Mat.Cig_x_PAQ, 1 ) ) ) )
                       WHEN ( T1.UMB = 'PC' ) THEN TRIM( TO_CHAR( NVL( T1.Libre_Utilizacion, 0 ) * 1    / DECODE( Mat.Unidad_Med_Vta, 'CAJ', NVL(  Mat.Cig_x_CLL, 1 ) , NVL( Mat.Cig_x_PAQ, 1 ) ) ) )
                       WHEN ( T1.UMB = 'EA' ) THEN TRIM( TO_CHAR( NVL( T1.Libre_Utilizacion, 0 ) * 1    / DECODE( Mat.Unidad_Med_Vta, 'CAJ', NVL(  Mat.Cig_x_CLL, 1 ) , NVL( Mat.Cig_x_PAQ, 1 ) ) ) )
                       ELSE
                           TRIM( TO_CHAR( NVL( T1.Stock_NO_Libre, 0 ) ) ) 
                   END                                        AS ACTUAL_QTY     ,
                   TRIM( TO_CHAR( T1.UMB                  ) ) AS UMB            ,
                   TRIM( TO_CHAR( NVL( Mat.Cig_x_CLL, 1 ) ) ) AS UOM_1          ,
                   TRIM( TO_CHAR( NVL( Mat.Cig_x_PAQ, 1 ) ) ) AS UOM_2
               FROM EAI.T3R_REPORTE_STOCK_TaO T1,                               
                    T3.Material               Mat
               WHERE T1.Material = Mat.Material(+) ;
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
            'Error'            , 'CCEA_DATA_STOCK'     , sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL                  , NULL                , NULL            ) ;
        COMMIT ;   
END CCEA_DATA_STOCK ;
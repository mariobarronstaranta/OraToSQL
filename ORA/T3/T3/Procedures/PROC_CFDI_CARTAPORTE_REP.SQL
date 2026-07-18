create or replace PROCEDURE    "PROC_CFDI_CARTAPORTE_REP" 
    ( pRelease IN NUMBER DEFAULT 0 )
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
   nJobCartaPorte  NUMBER(08)    ;
   sOrder_Num      VARCHAR2(30)  ;
   sCadenaOriginal VARCHAR2(60)  ;
   sSelloDigital   VARCHAR2(60)  ;
--
   CURSOR ScrReps IS
       SELECT DISTINCT
              Van.Name                             AS Van_Name        ,
              Van.Stock_Partner_Van                AS Cliente_VAN_SAP ,
              Van.Resource_Name                    AS Nombre_Rep      ,
           -- NVL( Rep.Nombre, Van.Resource_Name ) AS Nombre_Rep      ,
              Van.Stock_Partner_Resource           AS Cliente_Rep_SAP ,
              Rep.RFC                              AS Rep_RFC         ,
              Rep.Licencia                         AS Rep_Licencia    ,
              Rep.Placas                           AS Rep_Placas      ,
              Rep.Modelo                           AS Rep_Modelo      ,
              CP.Cliente_SAP                       AS Habilitado_Job
          FROM EAI_Owner.Vans_Vigentes      Van,
               EAI_Owner.Cat_Reps           Rep,
               EAI_Owner.MX_PRINT_DELIVERY  CP
          WHERE Van.Location_Type          = 'Van'
            AND Van.Stock_Partner_Resource = Rep.Cliente_SAP(+)
            AND Van.Stock_Partner_Van      = CP.Cliente_SAP(+)
          --AND SUBSTR( Van.Name, 5, 4 )   = 'MX4A'
          ORDER BY Van.Name   ;   
BEGIN
   SELECT
          EAI_Owner.getConv( 'CFG Settings', 'Job Cartaporte'     ) AS CartaPorte
          INTO nJobCartaPorte
       FROM DUAL ;
   dtInicio  := SYSDATE ;
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
   FOR Doc IN ScrReps LOOP   
      strID     := Doc.Van_Name  ;
      nProceso1 := nProceso1 + 1 ;
      IF ( ( Doc.Rep_RFC IS NOT NULL ) AND ( Doc.Habilitado_Job IS NOT NULL ) ) THEN
         nProceso2 := nProceso2 + 1 ;
         IF ( NVL( pRelease, 0 ) > 0 ) THEN
         -- PROC_VCP_GENERAR_REMISION_INV( Doc.Cliente_VAN_SAP, 0, 0 ) ;
            PROC_V40_GENERAR_REMISION_INV3( Doc.Cliente_VAN_SAP, 11, 11 ) ;
         END IF ;
      END IF ;
   END LOOP ;
   IF ( NVL( pRelease, 0 ) = 0 ) THEN
      DBMS_Output.Put_Line( 'Reps : ' || nProceso2 || '/' || nProceso1 ) ;
   END IF ;
   IF ( TO_CHAR( SYSDATE, 'D' ) = '6' ) THEN
      nProceso4 := 0 ;
      COMMIT ;
      --EAI_Owner.JOB_NEXT_RUN( nJobCartaPorte, TRUNC( SYSDATE ) + 3 + 5/24 ) ;
   END IF ;
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_CARTAPORTE_REP' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
--      INSERT INTO T3.RF_ERROR_LOG 
--         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
--      VALUES
--         ( SYSDATE, 'PROC_CFDI_LIBERACION_PAC', strID, sMsg ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                     , SYSDATE             , NULL           , NULL   ,
          'Error'            , 'PROC_CFDI_CARTAPORTE_REP', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CFDI_CARTAPORTE_REP ;
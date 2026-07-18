create or replace PROCEDURE    "WA_SET_FECHA_EMISION" 
   ( nDias      IN NUMBER DEFAULT 90 ,
     nMaxRegistros IN NUMBER DEFAULT 10000 )
IS
   nDoctos           NUMBER(6)     ;
   v_ID              VARCHAR2(050) ;
   sErrorCode        VARCHAR2(500) ;
   sMsg              VARCHAR2(500) ;
   nProceso          NUMBER(08)    ;
   nPID              NUMBER(08)    ;
--   
   CURSOR Docto IS
      SELECT
            CFD.Factura,
            TO_NUMBER( EXTRACT( CFD.Anexo_CFD, '/cfdi:Comprobante/@Version'                                 , 'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"') ) AS CFD_Version        ,
            TO_NUMBER( EXTRACT( CFD.Anexo_CFD, '/cfdi:Comprobante/@Version'                                 , 'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"') ) AS CFD_Version_Upper  ,
                       EXTRACT( CFD.Anexo_CFD, '/cfdi:Comprobante/@Fecha'                                   , 'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"')   AS V40_Fecha_Documento
      FROM T3.CFDI_Documentos Doc,
           T3.RF_Documentos   CFD
      WHERE TO_CHAR( Doc.Fecha_Liberacion, 'YYYYMM' ) >= TO_CHAR( SYSDATE - NVL( nDias, 30), 'YYYYMM' )
        AND Doc.Folio_Fiscal                          IS NOT NULL 
        AND Doc.Fecha_Documento                       IS NULL
        AND Doc.Nota_Venta                             = CFD.Factura ;  
BEGIN
   DBMS_OUTPUT.PUT_LINE( 'Ini : ' || TO_CHAR( SYSDATE, 'HH24:MI:SS' ) ) ;
   nProceso  := 926 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;      
   nDoctos := 0 ;
   FOR Doc IN Docto LOOP
      v_ID := Doc.Factura ;
      IF ( ( Doc.CFD_Version = '4' ) OR ( Doc.CFD_Version_Upper = '4' ) ) THEN
         UPDATE T3.CFDI_Documentos SET 
                                       Fecha_Documento    = TO_DATE( REPLACE( Doc.V40_Fecha_Documento, 'T', ' '), 'YYYY-MM-DD HH24:MI:SS' )
                          WHERE Nota_Venta = Doc.Factura ;
      END IF ;                   
      nDoctos := nDoctos + 1 ;                 
      IF ( MOD( nDoctos, 1000 ) = 0 ) THEN
         COMMIT ;
      END IF ;
      IF ( nDoctos = nMaxRegistros ) THEN
        COMMIT ;
        EXIT ;
      END IF ;
   END LOOP ;
   DBMS_OUTPUT.PUT_LINE( 'Fin : ' || TO_CHAR( SYSDATE, 'HH24:MI:SS' ) ) ;
   DBMS_OUTPUT.PUT_LINE( 'Rec-> ' || nDoctos ) ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nDoctos      , Proceso_2 = nDias,
                                                 Proceso_3 = nMaxRegistros, Proceso_4 = 0
       WHERE PID = nPID  ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION             , ID                      , CREATED             , MESSAGE        , 
          STATUS                , QUEUE_NAME              , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE     , RETRY_COUNT             , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA_SET_FECHA_EMISION', v_ID                    , SYSDATE             , NULL           , 
          'Error'               , 'WA_SET_FECHA_EMISION'  , sMsg                , 'XML'          ,
          sErrorCode            , NULL                    , NULL                , NULL            ) ;
END ; -- Procedure
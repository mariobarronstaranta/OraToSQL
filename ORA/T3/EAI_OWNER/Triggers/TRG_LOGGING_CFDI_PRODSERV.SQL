create or replace TRIGGER EAI_OWNER.TRG_LOGGING_CFDI_PRODSERV
 AFTER INSERT OR UPDATE OR DELETE ON T3.CFDI_PRODSERV
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE
   sUserName              VARCHAR2(020) ;
   sLog_Action            VARCHAR2(010) ; 
   nLogging               NUMBER(02)    ;
   sNEW_MODULO            VARCHAR2(010) ;
   sNEW_MATERIAL          VARCHAR2(020) ;
   sNEW_NOMBREMATERIAL    VARCHAR2(200) ;
   sNEW_UNIDADMEDIDA      VARCHAR2(020) ;
   sNEW_SAT_CLAVE         VARCHAR2(020) ;
   sNEW_SAT_UNIDADMEDIDA  VARCHAR2(020) ;
   sOLD_MODULO            VARCHAR2(010) ;
   sOLD_MATERIAL          VARCHAR2(020) ;
   sOLD_NOMBREMATERIAL    VARCHAR2(200) ;
   sOLD_UNIDADMEDIDA      VARCHAR2(020) ;
   sOLD_SAT_CLAVE         VARCHAR2(020) ;
   sOLD_SAT_UNIDADMEDIDA  VARCHAR2(020) ;   
BEGIN   
    IF INSERTING THEN
       sLog_Action := 'Insert'  ;
    ELSIF UPDATING THEN
       sLog_Action := 'Update'  ;
    ELSIF DELETING THEN
       sLog_Action := 'Delete'  ;
    ELSE
       sLog_Action := 'Unknown' ;
    END IF ;
    SELECT User INTO sUserName FROM DUAL ;
    nLogging              := 1 ;
    sNEW_MODULO           := :NEW.MODULO           ;
    sNEW_MATERIAL         := :NEW.MATERIAL         ;
    sNEW_NOMBREMATERIAL   := :NEW.NOMBREMATERIAL   ;
    sNEW_UNIDADMEDIDA     := :NEW.UNIDADMEDIDA     ;
    sNEW_SAT_CLAVE        := :NEW.SAT_CLAVE        ;
    sNEW_SAT_UNIDADMEDIDA := :NEW.SAT_UNIDADMEDIDA ;
    sOLD_MODULO           := :OLD.MODULO           ;
    sOLD_MATERIAL         := :OLD.MATERIAL         ;
    sOLD_NOMBREMATERIAL   := :OLD.NOMBREMATERIAL   ;
    sOLD_UNIDADMEDIDA     := :OLD.UNIDADMEDIDA     ;
    sOLD_SAT_CLAVE        := :OLD.SAT_CLAVE        ;
    sOLD_SAT_UNIDADMEDIDA := :OLD.SAT_UNIDADMEDIDA ;
--    
    IF ( nLogging > 0 ) THEN
       INSERT INTO EAI_Owner.MX_CFDI_PRODSERV_Log 
          ( Fecha, Usuario, Action, Usuario_Red, IP, Terminal,
            NEW_MODULO           , NEW_MATERIAL         , NEW_NOMBREMATERIAL   , NEW_UNIDADMEDIDA     , NEW_SAT_CLAVE        , NEW_SAT_UNIDADMEDIDA ,
            OLD_MODULO           , OLD_MATERIAL         , OLD_NOMBREMATERIAL   , OLD_UNIDADMEDIDA     , OLD_SAT_CLAVE        , OLD_SAT_UNIDADMEDIDA  ) 
       VALUES
          ( SYSDATE , sUsername, sLog_Action,
            SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
            SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
	          SYS_CONTEXT( 'USERENV' , 'HOST'       ), 
            sNEW_MODULO          , sNEW_MATERIAL        , sNEW_NOMBREMATERIAL  , sNEW_UNIDADMEDIDA    , sNEW_SAT_CLAVE       , sNEW_SAT_UNIDADMEDIDA,
            sOLD_MODULO          , sOLD_MATERIAL        , sOLD_NOMBREMATERIAL  , sOLD_UNIDADMEDIDA    , sOLD_SAT_CLAVE       , sOLD_SAT_UNIDADMEDIDA ) ;
    END IF ;            
--    
END TRG_LOGGING_CFDI_PRODSERV ;
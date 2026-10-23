create or replace TRIGGER EAI_OWNER.TRG_LOGGING_HAWA
 AFTER INSERT OR UPDATE OR DELETE ON EAI_Owner.MX_CFG_Condition_HAWA
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE
   sUserName     VARCHAR2(020) ;
   sLog_Action   VARCHAR2(010) ; 
   nLogging      NUMBER(02)    ;
   sNew_LP       VARCHAR2(030) ;
   sNew_SKU      VARCHAR2(030) ;   
   sNew_Cond     VARCHAR2(030) ;   
   sOld_LP       VARCHAR2(030) ;
   sOld_SKU      VARCHAR2(030) ;   
   sOld_Cond     VARCHAR2(030) ;   
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
    nLogging    := 1 ;
    sNew_LP     := :NEW.LP     ;
    sNew_SKU    := :NEW.SKU    ;
    sNew_Cond   := :NEW.COND   ;
    sOld_LP     := :OLD.LP     ;
    sOld_SKU    := :OLD.SKU    ;
    sOld_Cond   := :OLD.COND   ;
--    
    IF ( nLogging > 0 ) THEN
       INSERT INTO EAI_Owner.MX_Condition_HAWA_Log 
          ( Fecha, Usuario, Action, Usuario_Red, IP, Terminal,
            New_LP, New_SKU, New_Cond, Old_LP, Old_SKU, Old_Cond )            
       VALUES
          ( SYSDATE , sUsername, sLog_Action,
            SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
            SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
	          SYS_CONTEXT( 'USERENV' , 'HOST'       ), 
            sNew_LP, sNew_SKU, sNew_Cond, sOld_LP, sOld_SKU, sOld_Cond  ) ;   
    END IF ;            
--    
END TRG_LOGGING_HAWA ;
create or replace TRIGGER EAI_OWNER.TRG_LOGGING_HASHTABLE
 AFTER INSERT OR UPDATE OR DELETE ON EAI_Owner.MX_Hashtable
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE
   sUserName     VARCHAR2(020) ;
   sLog_Action   VARCHAR2(010) ; 
   nLogging      NUMBER(02)    ;
   sNew_Type     VARCHAR2(030) ;
   sNew_Source   VARCHAR2(030) ;   
   sNew_Target   VARCHAR2(030) ;   
   sOld_Type     VARCHAR2(030) ;
   sOld_Source   VARCHAR2(030) ;   
   sOld_Target   VARCHAR2(030) ;   
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
    sNew_Type   := :NEW.TYPE   ;
    sNew_Source := :NEW.SOURCE ;
    sNew_Target := :NEW.TARGET ;
    sOld_Type   := :OLD.TYPE   ;
    sOld_Source := :OLD.SOURCE ;
    sOld_Target := :OLD.TARGET ;
--    
    IF ( nLogging > 0 ) THEN
       INSERT INTO EAI_Owner.MX_Hashtable_Log 
          ( Fecha, Usuario, Action, Usuario_Red, IP, Terminal,
            New_Type, New_Source, New_Target, Old_Type, Old_Source, Old_Target )            
       VALUES
          ( SYSDATE , sUsername, sLog_Action,
            SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
            SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
	          SYS_CONTEXT( 'USERENV' , 'HOST'       ), 
            sNew_Type, sNew_Source, sNew_Target, sOld_Type, sOld_Source, sOld_Target ) ;   
    END IF ;            
--    
END TRG_LOGGING_HASHTABLE ;
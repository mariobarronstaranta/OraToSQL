create or replace TRIGGER EAI_OWNER.TRG_LOGGING_USOCFDI_CLIENTE
 AFTER INSERT OR UPDATE OR DELETE ON T3.CFDI_USOCFDI_CLIENTE
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE
   sUserName     VARCHAR2(020) ;
   sLog_Action   VARCHAR2(010) ; 
   nLogging      NUMBER(02)    ;
   sNew_Cliente  VARCHAR2(030) ;
   sNew_Uso_Vta  VARCHAR2(030) ;   
   sNew_Uso_Dev  VARCHAR2(030) ;   
   sOld_Cliente  VARCHAR2(030) ;
   sOld_Uso_Vta  VARCHAR2(030) ;   
   sOld_Uso_Dev  VARCHAR2(030) ;   
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
    nLogging     := 1 ;
    sNew_Cliente := :NEW.CLIENTE_SAP    ;
    sNew_Uso_Vta := :NEW.USO_VENTA      ;
    sNew_Uso_Dev := :NEW.USO_DEVOLUCION ;
    sOld_Cliente := :OLD.CLIENTE_SAP    ;
    sOld_Uso_Vta := :OLD.USO_VENTA      ;
    sOld_Uso_Dev := :OLD.USO_DEVOLUCION ;
--    
    IF ( nLogging > 0 ) THEN
       INSERT INTO EAI_Owner.MX_USOCFDI_CLIENTE_Log 
          ( Fecha, Usuario, Action, Usuario_Red, IP, Terminal,
            New_Cliente, New_Uso_Vta, New_Uso_Dev, Old_Cliente, Old_Uso_Vta, Old_Uso_Dev )            
       VALUES
          ( SYSDATE , sUsername, sLog_Action,
            SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
            SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
	          SYS_CONTEXT( 'USERENV' , 'HOST'       ), 
            sNew_Cliente, sNew_Uso_Vta, sNew_Uso_Dev, sOld_Cliente, sOld_Uso_Vta, sOld_Uso_Dev ) ;   
    END IF ;            
--    
END TRG_LOGGING_USOCFDI_CLIENTE ;
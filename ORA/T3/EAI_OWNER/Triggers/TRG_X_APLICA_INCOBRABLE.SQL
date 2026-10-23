create or replace TRIGGER EAI_OWNER.TRG_X_APLICA_INCOBRABLE
 AFTER INSERT OR UPDATE OR DELETE ON EAI_OWNER.X_APLICA_INCOBRABLE
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE
   sUserName                 VARCHAR2(020) ;
   sLog_Action               VARCHAR2(010) ; 
   nLogging                  NUMBER(03)    ;
   sTIPO_WA                  VARCHAR2(05)  ;  
   sOLD_FACTURA              VARCHAR2(30)  ;
   sOLD_NOTA_CREDITO         VARCHAR2(30)  ;
   nOLD_IMPORTE              NUMBER(16,2)  ;
   sOLD_FECHA_ASIGNACION     VARCHAR2(10)  ;
   sOLD_CLEARING             VARCHAR2(20)  ;
   sNEW_FACTURA              VARCHAR2(30)  ;
   sNEW_NOTA_CREDITO         VARCHAR2(30)  ;
   nNEW_IMPORTE              NUMBER(16,2)  ;
   sNEW_FECHA_ASIGNACION     VARCHAR2(10)  ;
   sNEW_CLEARING             VARCHAR2(20)  ;
BEGIN
    nLogging := 0 ;
    IF INSERTING THEN
       sLog_Action := 'Insert'  ;
       nLogging    := 1 ;
    ELSIF UPDATING THEN
       sLog_Action := 'Update'  ;
    ELSIF DELETING THEN
       sLog_Action := 'Delete'  ;
       nLogging    := 1 ;
    ELSE
       sLog_Action := 'Unknown' ;
    END IF ;
    SELECT User INTO sUserName FROM DUAL ;
--
    sOLD_FACTURA           := NULL ;
    sOLD_NOTA_CREDITO      := NULL ;
    nOLD_IMPORTE           := NULL ;
    sOLD_FECHA_ASIGNACION  := NULL ;
    sOLD_CLEARING          := NULL ;
    sNEW_FACTURA           := NULL ;
    sNEW_NOTA_CREDITO      := NULL ;
    nNEW_IMPORTE           := NULL ;
    sNEW_FECHA_ASIGNACION  := NULL ;
    sNEW_CLEARING          := NULL ;
    sTIPO_WA               := 'Incob' ;
--    
    IF ( NVL( :NEW.FACTURA, 'NULO' ) != NVL( :OLD.FACTURA, 'NULO' ) ) THEN
       nLogging              := nLogging + 1       ;
       sNEW_FACTURA          := :NEW.FACTURA       ;
       sOLD_FACTURA          := :OLD.FACTURA       ;
    END IF ;
    IF ( NVL( :NEW.NOTA_CREDITO, 'NULO' ) != NVL( :OLD.NOTA_CREDITO, 'NULO' ) ) THEN
       nLogging              := nLogging + 1       ;
       sNEW_NOTA_CREDITO     := :NEW.NOTA_CREDITO  ;
       sOLD_NOTA_CREDITO     := :OLD.NOTA_CREDITO  ;    
    END IF ;
    IF ( NVL( :NEW.IMPORTE, 0 ) != NVL( :OLD.IMPORTE, 0 ) ) THEN
       nLogging              := nLogging + 1       ;
       nNEW_IMPORTE          := :NEW.IMPORTE       ;
       nOLD_IMPORTE          := :OLD.IMPORTE       ;
    END IF ; 
--    
    IF ( nLogging > 0 ) THEN
       INSERT INTO EAI_OWNER.WA_COBRANZA_LOG 
          ( Fecha, Usuario, Action, TIPO_WA, Usuario_Red, IP, Terminal,
            OLD_FACTURA          , OLD_NOTA_CREDITO     , OLD_IMPORTE          ,
            OLD_FECHA_ASIGNACION , OLD_CLEARING         ,
            NEW_FACTURA          , NEW_NOTA_CREDITO     , NEW_IMPORTE          ,
            NEW_FECHA_ASIGNACION , NEW_CLEARING          )
       VALUES
          ( SYSDATE , sUsername, sLog_Action, sTIPO_WA,
            SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
            SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
            SYS_CONTEXT( 'USERENV' , 'HOST'       ), 
            sOLD_FACTURA         , sOLD_NOTA_CREDITO    , nOLD_IMPORTE         ,
            sOLD_FECHA_ASIGNACION, sOLD_CLEARING        ,
            sNEW_FACTURA         , sNEW_NOTA_CREDITO    , nNEW_IMPORTE         ,
            sNEW_FECHA_ASIGNACION, sNEW_CLEARING         ) ;
    END IF ;            
--    
END TRG_X_APLICA_INCOBRABLE ;
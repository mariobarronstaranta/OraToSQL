create or replace TRIGGER T3R_SALES_DOCS_OLD_LOG
AFTER UPDATE
ON T3R_SALES_DOCS_OLD
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
DECLARE
    sUserName  VARCHAR2(0020);
    sLogging   VARCHAR2(2000);
    nLogging   NUMBER(2)    ;
BEGIN    
    nLogging :=  1 ;
    sLogging := '' ;
    SELECT User INTO sUserName FROM DUAL ;    
    IF    ( :New.Doc_Date   != :Old.Doc_Date ) THEN
       sLogging := sLogging || ' Date: ' || :Old.Doc_Date     || '->' || :New.Doc_Date    || '.'  ;
    END IF ;    
    IF ( :New.Distributor   != :Old.Distributor ) THEN
       sLogging := sLogging || ' Ctro: ' || :Old.Distributor  || '->' || :New.Distributor  || '.' ;
    END IF ;    
    IF ( :New.Customer      != :Old.Customer    ) THEN
       sLogging := sLogging || ' Cust: ' || :Old.Customer     || '->' || :New.Customer     || '.' ;
    END IF ;    
    IF ( :New.Doc_Num_R3  != :Old.Doc_Num_R3 ) THEN
       sLogging := sLogging || ' DocSAP: ' || :Old.Doc_Num_R3 || '->' || :New.Doc_Num_R3   || '.' ;
    END IF ;
    IF ( :New.Doc_Ord_R3  != :Old.Doc_Ord_R3 ) THEN
       sLogging := sLogging || ' PedSAP: ' || :Old.Doc_Ord_R3 || '->' || :New.Doc_Ord_R3   || '.' ;
    END IF ;
    IF ( :New.Doc_Num_Ref1  != :Old.Doc_Num_Ref1 ) THEN
       sLogging := sLogging || ' Ref1: ' || :Old.Doc_Num_Ref1 || '->' || :New.Doc_Num_Ref1 || '.' ;
    END IF ;
    IF ( :New.Doc_Num_Ref2  != :Old.Doc_Num_Ref2 ) THEN
       sLogging := sLogging || ' Ref2: ' || :Old.Doc_Num_Ref2 || '->' || :New.Doc_Num_Ref2 || '.' ;
    END IF ;
    IF ( :New.Doc_Type != :Old.Doc_Type ) THEN
       sLogging := sLogging || ' Type: ' || :Old.Doc_Type     || '->' || :New.Doc_Type     || '.' ;
    END IF ;
    IF ( :New.Doc_Status != :Old.Doc_Status ) THEN
       sLogging := sLogging || ' St: ' || :Old.Doc_Status     || '->' || :New.Doc_Status   || '.' ;
    END IF ;
    IF ( NVL( :New.Doc_Qty, 0 ) != NVL( :Old.Doc_Qty, 0 ) ) THEN
       sLogging := sLogging || ' Qty: ' || :Old.Doc_Qty       || '->' || :New.Doc_Qty      || '.' ;
    END IF ;
    IF ( NVL( :New.Doc_NetAmt, 0 ) != NVL( :Old.Doc_NetAmt, 0 ) ) THEN
       sLogging := sLogging || ' Subt: ' || :Old.Doc_NetAmt   || '->' || :New.Doc_NetAmt   || '.' ;
    END IF ;
    IF ( NVL( :New.Doc_TaxAmt, 0 ) != NVL( :Old.Doc_TaxAmt, 0 ) ) THEN
       sLogging := sLogging || ' Tax: ' || :Old.Doc_TaxAmt    || '->' || :New.Doc_TaxAmt   || '.' ;
    END IF ;
--    
    IF ( ( nLogging = 1 ) AND ( LENGTH( sLogging ) > 3 ) ) THEN
       INSERT INTO EAI.LOG_T3R_Sales_Docs_Old
          ( Fecha, Usuario, Usuario_Red, IP, Terminal, Doc_Num_R3, Cambio )
       VALUES
          ( SYSDATE , sUsername, 
            SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
            SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
	          SYS_CONTEXT( 'USERENV' , 'HOST'       ),
            :Old.Doc_Num_R3,
            SUBSTR( sLogging, 2, 2000 ) ) ;    
    END IF ;            
--   
END ;
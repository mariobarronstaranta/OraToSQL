create or replace PROCEDURE    "WA_V40_REGIMEN" 
IS
   nDoctos    NUMBER(6)      ;
   dtFecha    DATE           ;
   dtFactura  DATE           ;
   sMsg       VARCHAR2(0500) ;
   nItems     NUMBER(6)      ;
   dtFechaTrn DATE           ;
--
   CURSOR ScrClientes IS
      SELECT 
             Cte.RFC                 AS RFC        , 
             Cte.Tax_Jurisdiction    AS SF_Regimen ,
             CteReg.Regimen          AS IFC_Regimen
         FROM EAI_Owner.Client Cte,
             ( SELECT Target AS Regimen FROM EAI_Owner.MX_HashTable 
                   WHERE Source = 'Regimen Valido SAT'  ) Reg,
             ( SELECT RFC, Valor AS Regimen FROM T3.CFDI_RFC_Setting
                   WHERE Parametro = 'RegimenFiscal' ) CteReg
         WHERE Cte.RFC              != 'XAXX010101000'
           AND Cte.Tax_Jurisdiction IS NOT NULL
           AND Cte.Tax_Jurisdiction  = Reg.Regimen 
           AND Cte.RFC               = CteReg.RFC(+) 
           AND Cte.RFC          NOT IN (
                                         SELECT Source AS RFC
                                            FROM EAI_Owner.MX_HashTable 
                                            WHERE Type   = 'RegimenFiscal'
                                              AND Target = 'Excluir'           
                                        ) ;
BEGIN
      nDoctos := 0 ;
      FOR Cte IN ScrClientes LOOP
         IF ( Cte.IFC_Regimen IS NULL ) THEN
            nDoctos := nDoctos + 1 ;
            INSERT INTO T3.CFDI_RFC_Setting ( RFC, Parametro, Valor )
               VALUES ( Cte.RFC, 'RegimenFiscal', Cte.SF_Regimen ) ;
         ELSE
            IF ( Cte.IFC_Regimen != Cte.SF_Regimen ) THEN
               nDoctos := nDoctos + 1 ;
               UPDATE T3.CFDI_RFC_Setting SET Valor = Cte.SF_Regimen
                  WHERE RFC = Cte.RFC AND Parametro = 'RegimenFiscal' ;
            END IF ;
         END IF ;
      END LOOP ;
--
   IF ( nDoctos > 0 ) THEN
      DBMS_OUTPUT.Put_Line( 'WorkAround => ' || 'Regimen Fiscal' ) ;
      INSERT INTO EAI_Owner.WA_Logging
         ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
      VALUES
         ( SYSDATE , USER, 
           SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
           SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
           SYS_CONTEXT( 'USERENV' , 'HOST'       ),
           TO_CHAR( nDoctos, '9999' ), 'RegimenSF' ) ;           
      COMMIT ;
   END IF ;
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( 'ERROR ORACLE ' || TO_CHAR( SQLCODE ) || ' ' || SQLERRM, 1, 480 ) ;
      DBMS_Output.Put_Line( '************* Mensaje **************' ) ;
      DBMS_OUTPUT.Put_Line( '****  Error en WA_V40_REGIMEN  *****' ) ;
      DBMS_Output.Put_Line( sMsg ) ;         
END ; -- Procedure
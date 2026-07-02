create or replace PROCEDURE       "UPDATE_711_RECEPCION" 
   ( t_Factura IN VARCHAR2 ) IS
   CURSOR ScrDoc IS
      SELECT 'TBD'            AS Row_ID   ,
              FolioRecepcion  AS Entrada  ,
              'INTERFACE'     AS CreadoPor,
              SYSDATE         AS Creacion ,
              FolioInterno    AS Var_1
          FROM EAI.LDR_SHAREPOINT
          WHERE UPPER( Tienda ) != 'TIENDA' ;
   nUpdate   NUMBER(5) ;
   nCount    NUMBER(5) ;
   nInsert   NUMBER(5) ;
   nRowID    NUMBER(10) ;
BEGIN
   nUpdate := 0 ;       
   nCount  := 0 ;
   nInsert := 0 ;
   FOR Doc IN ScrDoc LOOP    
      UPDATE EAI.IFC_Folios_FE SET Modificacion = SYSDATE
         WHERE Var_1 = Doc.Var_1 ;
      nCount := SQL%ROWCOUNT ;
      IF ( nCount = 0 ) THEN 
         nInsert := nInsert + 1 ;
         SELECT MAX( Row_ID + 1 ) INTO nRowID
            FROM EAI.IFC_Folios_FE
            WHERE Row_ID < 1000000000 ;
         INSERT INTO EAI.IFC_Folios_FE  
            ( Row_ID, Entrada, CreadoPor, Creacion, Var_1 )
         VALUES
            ( nRowID, Doc.Entrada, Doc.CreadoPor, Doc.Creacion, Doc.Var_1 ) ;
      ELSE   
         nUpdate := nUpdate + 1 ;
      END IF ;
   END LOOP ;     
   DBMS_OUTPUT.PUT_LINE( 'Insert : ' || nInsert ) ;   
   DBMS_OUTPUT.PUT_LINE( 'Update : ' || nUpdate ) ;   
   COMMIT ;
END UPDATE_711_RECEPCION ;
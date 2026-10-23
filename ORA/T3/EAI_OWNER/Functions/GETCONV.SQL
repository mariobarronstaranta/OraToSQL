create or replace FUNCTION             "GETCONV" 
  ( sType      IN VARCHAR2,
    sValue     IN VARCHAR2 )
RETURN VARCHAR2 IS
   sReturn      VARCHAR2(99)  ;
--------------------------------------------------------------------------------
-- getConv
--    Determinar la tabla de Conversion entre V3/T3 y TaO
--    TaO - Febrero 2015
--
--------------------------------------------------------------------------------
--   
   CURSOR ScrValue IS
      SELECT HT.Target
         FROM EAI_OWNER.MX_HashTable HT
      WHERE HT.Type   = sType
        AND HT.Source = sValue ;
BEGIN
   sReturn := sValue ;
   FOR Item IN ScrValue LOOP
      sReturn := Item.Target ;
   END LOOP ;			
   RETURN sReturn    ;
--
END ;
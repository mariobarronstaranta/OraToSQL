create or replace FUNCTION    "FN_CFDI_REFOLEO" 
   ( p_DocumentID IN  VARCHAR2,
     p_Type       IN  VARCHAR2 )
RETURN VARCHAR2
IS
    v_Return         VARCHAR2(30) ;
    CURSOR ScrVenta IS
       SELECT Docto_SAP, Docto_T3MX, Tipo_Registro
          FROM T3.CFDI_Refoleo
          WHERE Docto_T3MX     = p_DocumentID
            AND Tipo_Registro  = 'Venta' ;
    CURSOR ScrDOI IS
       SELECT Docto_SAP        AS Factura_SAP   , 
              Docto_T3MX       AS Docto_T3MX    , 
              Tipo_Registro    AS Tipo_Registro
          FROM T3.CFDI_Refoleo
          WHERE Docto_SAP      = p_DocumentID
            AND Tipo_Registro  = 'DOI' 
       UNION     
       SELECT Docto_SAP        AS Docto_SAP     , 
              Docto_T3MX       AS Docto_T3MX    ,
              'DOI'            AS Tipo_Registro
          FROM T3.CFDI_Refoleo
          WHERE Docto_SAP      = p_DocumentID
            AND Tipo_Registro  = 'Venta'  ;
BEGIN
   v_Return := p_DocumentID ;
   IF    ( p_Type = 'Venta' ) THEN
         FOR Doc IN ScrVenta LOOP
            v_Return := Doc.Docto_SAP ;
         END LOOP ;
   ELSIF ( p_Type = 'DOI'   ) THEN
         FOR Doc IN ScrDOI LOOP
            v_Return := Doc.Docto_T3MX ;
         END LOOP ;   
   END IF ;         
   RETURN v_Return ;
EXCEPTION 
   WHEN OTHERS THEN 
      RETURN 0 ;   
END FN_CFDI_REFOLEO ;
create or replace PROCEDURE      "WA_ZZ_TRASH" AS
   nCantUMV              NUMBER(12)    ;
   sUMV                  VARCHAR2(005) ;
   nItems                NUMBER(10)    ;
   CURSOR ScrDocuments IS
       SELECT PG.Factura, PG.Entrega, PD.Num_Linea, PD.Material, PD.Cantidad_Vta, PD.Unidad_Med_Vta, SKU.Nombre_Material,
              SKU.Unidad_Med_Vta AS SKU_UOM, SKU.Cig_x_CLL, SKU.Cig_x_PAQ, SKU.Cig_x_CT
          FROM T3.Preventa_General PG ,
               T3.Preventa_Detalle PD ,
               T3.Material         SKU
          WHERE PG.Fecha_Factura >= TRUNC( SYSDATE - 7 )
            AND PG.Clase_Factura  = 'C005'
            AND PG.Factura        = PD.Factura
            AND PD.Material       = SKU.Material ;      
BEGIN
   nItems := 0 ;
   FOR Det IN ScrDocuments LOOP
      nCantUMV := 00 ;
      sUMV     := '' ;
      nItems   := nItems + 1 ;
      WA_QTY_SAP_BILLING( Det.Entrega, Det.Material, Det.Cantidad_Vta, Det.Unidad_Med_Vta, nCantUMV, sUMV ) ;
   END LOOP ;
   DBMS_OUTPUT.PUT_LINE( 'Items : ' || nItems ) ;
   COMMIT ;
END WA_ZZ_TRASH ;
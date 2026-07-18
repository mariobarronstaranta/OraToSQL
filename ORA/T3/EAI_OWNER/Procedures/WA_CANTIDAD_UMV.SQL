create or replace PROCEDURE           WA_CANTIDAD_UMV
   ( pMaterial      IN   VARCHAR2,    
     pCantidad      IN   NUMBER  ,
     pUnidadMedida  IN   VARCHAR2,
     pCantUMV       OUT  NUMBER  ,
     pUMV           OUT  VARCHAR )
IS
   sMsg             VARCHAR2(500) ;   
   sRow_ID          VARCHAR2(020) ;
   sErrorCode       VARCHAR2(020) ;
   nFolio           NUMBER(02)    ;
   sCalcular        VARCHAR2(030) ;
   sMes             VARCHAR2(030) ;
   sCentro          VARCHAR2(004) ;
   pFactor          NUMBER        ;
   sUnidad_Med_Vta  VARCHAR2(020) ;
--
   CURSOR ScrProducto IS
       SELECT SKU.Unidad_Med_Vta    AS UOM_CD     , 
              SKU.Cig_x_CLL         AS X_Pack_Size
          FROM T3.Material SKU
          WHERE SKU.Material = pMaterial ;
BEGIN
   pCantUMV  := pCantidad     ;
   pUMV      := pUnidadMedida ;
   SELECT EAI_Owner.GETCONV( 'ECC_V3 UOM', pUnidadMedida )  INTO  pUMV
       FROM DUAL ;
   FOR SKU IN ScrProducto LOOP
      IF ( pUnidadMedida IN ( 'MIL' ) ) THEN
         IF ( NVL( SKU.X_Pack_Size, 0 ) > 0 ) THEN
            pUMV     := SKU.UOM_CD ;
            pCantUMV := pCantidad * 1000 / NVL( SKU.X_Pack_Size, 0 ) ;
         END IF ;   
      ELSIF ( pUnidadMedida IN ( 'PZ', 'PCE' ) ) THEN
         IF ( NVL( SKU.X_Pack_Size, 0 ) > 0 ) THEN
            pUMV     := SKU.UOM_CD ;
            pCantUMV := pCantidad / NVL( SKU.X_Pack_Size, 0 ) ;
         END IF ;   
      END IF ;
   END LOOP ;

EXCEPTION
   WHEN OTHERS THEN
      pCantUMV  := pCantidad     ;
      pUMV      := pUnidadMedida ;
END WA_CANTIDAD_UMV ;
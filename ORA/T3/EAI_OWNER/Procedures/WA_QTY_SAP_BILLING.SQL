create or replace PROCEDURE           WA_QTY_SAP_BILLING
   ( pReference     IN   VARCHAR2,
     pMaterial      IN   VARCHAR2,    
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
   sWorkaround      VARCHAR2(500) ;
--
   CURSOR ScrProducto IS
      SELECT Info.Material                             AS Material       ,
             Info.Nombre_Material                      AS Nombre_Material,
             Info.Material_Group                       AS Material_Group ,
             Info.SAT_Clave                            AS SAT_Clave      ,
             Info.Unidad_Med_Vta                       AS Unidad_Med_Vta ,
             Info.Cig_x_CLL                            AS Cig_x_CLL      ,
             Info.Cig_x_PAQ                            AS Cig_x_PAQ      ,
             Info.Cig_x_CT                             AS Cig_x_CT       ,
             Info.Factor_PAQ                           AS Factor_PAQ     ,
             Info.Factor_CARTON                        AS Paq_x_Carton   ,
             Info.Fecha_Creacion                       AS Fecha_Creacion ,
             Info.Categoria                            AS Categoria      
      FROM (
             SELECT SKU.Material                       AS Material       ,
                    SKU.Nombre_Material                AS Nombre_Material,
                    SAT.SAT_Clave                      AS SAT_Clave      ,
                    SKU.Unidad_Med_Vta                 AS Unidad_Med_Vta ,
                    NVL( SKU.Cig_x_CLL, 0 )            AS Cig_x_CLL      ,
                    NVL( SKU.Cig_x_PAQ, 0 )            AS Cig_x_PAQ      ,
                    NVL( SKU.Cig_x_CT , 0 )            AS Cig_x_CT       ,
                    DECODE( NVL( SKU.Cig_x_CLL, 0 ), 0, 0,
                    NVL( SKU.Cig_x_PAQ, 0 ) / NVL( SKU.Cig_x_CLL, 0 ) )          
                                                       AS Factor_PAQ     ,
                    DECODE( NVL( SKU.Cig_x_PAQ, 0 ), 0, 0,
                    NVL( SKU.Cig_x_CT , 0 ) / NVL( SKU.Cig_x_PAQ, 0 ) )          
                                                       AS Factor_CARTON  ,
                    SKU.Creacion                       AS Fecha_Creacion ,
                    CASE
                       WHEN ( INSTR( UPPER( SKU.Nombre_Material ) , 'EPOD' ) > 0 )     THEN 'VAPOR'
                       WHEN ( INSTR( UPPER( SKU.Nombre_Material ) , 'VYPE' ) > 0 )     THEN 'VAPOR'
                       WHEN ( INSTR( UPPER( SKU.Nombre_Material ) , 'VUSE' ) > 0 )     THEN 'VAPOR'
                       WHEN ( INSTR( UPPER( SKU.Nombre_Material ) , 'VELO' ) > 0 )     THEN 'VELO'
                       WHEN SKU.Material LIKE '50%'                                    THEN 'PP'
                       WHEN NVL( SKU.Cig_x_CLL, 0 ) IN ( 14, 15, 16, 18, 20, 24, 25 )  THEN 'FMC'
                       ELSE
                          'TBD' 
                    END                                AS Categoria     ,
                    SKU.Nombre_Corto                   AS Material_Group
                FROM T3.Material SKU,
                     (
                       SELECT Material, MAX( SAT_Clave ) AS SAT_Clave
                          FROM T3.CFDI_ProdServ WHERE Modulo = 'VTA'
                          GROUP BY Material               
                     )   SAT   
                WHERE NVL( SKU.Creacion, SYSDATE ) > TO_DATE( '20150101', 'YYYYMMDD' )
                  AND SKU.Material = SAT.Material(+)
             ) Info     
      WHERE Info.Material = pMaterial ;
BEGIN
   pCantUMV  := pCantidad     ;
   pUMV      := pUnidadMedida ;
   SELECT EAI_Owner.GETCONV( 'ECC_V3 UOM', pUnidadMedida )  INTO  pUMV
       FROM DUAL ;
   FOR SKU IN ScrProducto LOOP
      IF ( pUnidadMedida IN ( 'MIL' ) ) THEN
         IF ( NVL( SKU.Cig_x_CLL, 0 ) > 0 ) THEN
            pUMV     := SKU.Unidad_Med_Vta ;
            pCantUMV := pCantidad * 1000 / NVL( SKU.Cig_x_CLL, 0 ) ;
         END IF ;   
      ELSIF ( pUnidadMedida IN ( 'PZ', 'PCE' ) ) THEN
         IF ( NVL( SKU.Cig_x_CLL, 0 ) > 0 ) THEN
            pUMV     := SKU.Unidad_Med_Vta ;
            pCantUMV := pCantidad / NVL( SKU.Cig_x_CLL, 0 ) ;
         END IF ;   
      END IF ;
--
      IF ( SKU.Categoria = 'FMC' ) THEN
         IF    ( pUMV = 'PAQ'   ) THEN
              IF ( SKU.Factor_PAQ > 0 ) THEN
                 pUMV     := SKU.Unidad_Med_Vta ;
                 pCantUMV := pCantidad * SKU.Factor_PAQ ;
                 INSERT INTO EAI_Owner.WA_Logging
                    ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
                 VALUES
                    ( SYSDATE , USER, 
                      SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
                      SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
                      SYS_CONTEXT( 'USERENV' , 'HOST'       ),
                      pReference, sWorkaround ) ;    
              END IF ;
         ELSIF ( pUMV = 'CASES' ) THEN
              IF ( ( SKU.Factor_PAQ > 0 ) AND ( SKU.Paq_x_Carton > 0 ) ) THEN
                 pUMV        := SKU.Unidad_Med_Vta ;
                 pCantUMV    := pCantidad * SKU.Factor_PAQ * SKU.Paq_x_Carton ;
                 sWorkaround := 'Conversion de '             ||
                                TRIM( TO_CHAR( pCantidad ) ) || ' ' || pUnidadMedida || ' -> ' ||
                                TRIM( TO_CHAR( pCantUMV  ) ) || ' ' || pUMV ;
                 INSERT INTO EAI_Owner.WA_Logging
                    ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
                 VALUES
                    ( SYSDATE , USER, 
                      SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
                      SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
                      SYS_CONTEXT( 'USERENV' , 'HOST'       ),
                      pReference, sWorkaround ) ;    
              END IF ;
         END IF ;     
      ELSIF ( SKU.Categoria = 'PP' ) THEN   
         IF ( pUMV = 'CASES' ) THEN
              IF ( ( SKU.Factor_PAQ > 0 ) AND ( SKU.Paq_x_Carton > 0 ) ) THEN
                 pUMV        := SKU.Unidad_Med_Vta ;
                 pCantUMV    := pCantidad * SKU.Paq_x_Carton ;
                 sWorkaround := 'Conversion de '             ||
                                TRIM( TO_CHAR( pCantidad ) ) || ' ' || pUnidadMedida || ' -> ' ||
                                TRIM( TO_CHAR( pCantUMV  ) ) || ' ' || pUMV ;
                 INSERT INTO EAI_Owner.WA_Logging
                    ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
                 VALUES
                    ( SYSDATE , USER, 
                      SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
                      SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
                      SYS_CONTEXT( 'USERENV' , 'HOST'       ),
                      pReference, sWorkaround ) ;    
              END IF ;
         END IF ;
      END IF ;
   END LOOP ;
EXCEPTION
   WHEN OTHERS THEN
      pCantUMV  := pCantidad     ;
      pUMV      := pUnidadMedida ;
END WA_QTY_SAP_BILLING ;
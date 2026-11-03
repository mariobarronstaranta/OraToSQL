create or replace PROCEDURE    "PROC_V40_GENERAR_OTROS" 
  ( pFactura        IN VARCHAR2 ) 
IS
   strID       VARCHAR2(0030) ;
   sMsg        VARCHAR2(0500) ; 
   sCtro       VARCHAR2(0004) ;
   sStepPLSQL  VARCHAR2(0060) ;   
--
   uHEADER     VARCHAR2(4000) ;
   uCABADD     VARCHAR2(4000) ;
   uCOMEXT     VARCHAR2(4000) ;
   uIMPFAC     VARCHAR2(4000) ;
   uLINFAC     CLOB           ;
   sCFDIREL    VARCHAR2(4000) ;
   nCFDIREL    NUMBER(03)     ;
   sUsoCFDI    VARCHAR2(0020) ;
---
   sReturn     VARCHAR2(4000) ;
   sCABCLIE    VARCHAR2(4000) ;
   sADULFAC    VARCHAR2(4000) ;
   sLeyMenor   VARCHAR2(4000) ;
   sLeyPriv    VARCHAR2(4000) ;   
   sSepLinea   VARCHAR2(0004) ;
   sSepCampo   VARCHAR2(0004) ;
   sTipoDocto  VARCHAR2(0004) ;
   sAgrupacion VARCHAR2(0060) ;
   sSociedad   VARCHAR2(0030) ;
   nLineas     NUMBER(03) ;
   nLineasImp  NUMBER(03) ;
   nLineasLey  NUMBER(03) ;
   nEnajenado  NUMBER(22) ;
   sFactura    VARCHAR2(0060) ;
   sMaterial   VARCHAR2(0060) ;
   nTotal      NUMBER(22,2)   ;
   nItems      NUMBER(22,2)   ;   
   sData       CLOB           ;
   nTasaRet    NUMBER(06,2)   ;
--
   sSoc_RFC             VARCHAR(030)   ;
   nDiasMX10            NUMBER(03)     ;
   spedidoV3            VARCHAR2(0400) ;
   ssucursalNombre      VARCHAR2(0400) ;
   spedidoSAP           VARCHAR2(0400) ;
   sfacturaSAP          VARCHAR2(0400) ;
   sRecibe_Nombre       VARCHAR2(0400) ;
   sRemite_Calle        VARCHAR2(0400) ;
   sRemite_noExterior   VARCHAR2(0400) ;
   sRemite_noInterior   VARCHAR2(0400) ;
   sRemite_colonia      VARCHAR2(0400) ;
   sRemite_municipio    VARCHAR2(0400) ;
   sRemite_estado       VARCHAR2(0400) ;
   sRemite_pais         VARCHAR2(0400) ;
   sRemite_codigoPostal VARCHAR2(0400) ;
   sTipo_Documento      VARCHAR2(0400) ;
   sRecibe_Cliente      VARCHAR2(0400) ;
   sRemite_Cliente      VARCHAR2(0400) ;
   sCentroExpedicion    VARCHAR2(0400) ;
   sLugarExpedicion     VARCHAR2(0400) ;
   seMail               VARCHAR2(0400) ;    
   sDetalleItem         VARCHAR2(0010) ;
   sIncoterms           VARCHAR2(0400) ;    
   nRetenciones         NUMBER(12,2 )  ;
   nDecimalesCFDI       NUMBER(03)     ;
   sMetodoDePago        VARCHAR2(0100) ;
   sNumCtaPago          VARCHAR2(0100) ;
   sDatosAdicionales    VARCHAR2(2000) ;
   sAddenda             VARCHAR2(0010) ;
   sSAT_ID              VARCHAR2(0030) ;
   sSAT_UM              VARCHAR2(0030) ;   
   sMetodoPago          VARCHAR2(0030) ;   
   nUSD_TipoCambio      NUMBER(16,6)   ;
   nDoc_TipoCambio      NUMBER(16,6)   ;
   sMonedaDoc           VARCHAR2(0006) ;
--
   CURSOR ScrDatos IS
       SELECT 
              NVL( Doc.Valor_Subt, 0 ) + 
              NVL( Doc.Valor_IVA , 0 )                           AS Doc_Total          ,
              'CTRL'                                             AS Ctro               ,
              Doc.Clase_Factura                                  AS Tipo_Docto         ,
              Doc.Factura                                        AS Factura            ,
              T3.FN_USD_TCAMBIO( Doc.Factura )                   AS USD_TipoCambio     ,
              TRIM( Doc.Complemento_CE )                         AS ComplementoCE      , 
--              
              '4.0'                                              AS versionCFDI        ,
--            Doc.Serie                                          AS serie              , 
--            'CTRL'                                             AS serie              ,
              Doc.Sociedad || '-' ||
              TO_CHAR( Doc.Fecha_Factura, 'YYYY' )               AS serie              ,
              Doc.FacturaSAP                                     AS folio              ,
              Doc.Referencia                                     AS pedidoV3           ,
              Doc.PedidoSAP                                      AS pedidoSAP          ,
              Doc.FacturaSAP                                     AS facturaSAP         ,
              ''                                                 AS repVentas          ,
              ''                                                 AS sucursalNombre     ,
              TO_CHAR( SYSDATE - nDiasMX10, 
                                'YYYYMMDDHH24MISS' )             AS fecha_Reenvio      ,
              TO_CHAR( Doc.Fecha_Factura - nDiasMX10, 'YYYYMMDD' ) 
                  || REPLACE( Comp.Hora_Factura, ':', '' )       AS fecha              ,                 
              DECODE( Doc.Clase_Factura, 
                     'ingreso', 'I', 
                     'VF'  , 'I',
                     'TC'  , 'I',
                     'YC'  , 'I',
                     'ZF2' , 'I',
                     'IV'  , 'I',
                     'ZI01', 'I',   -- TaO
                     'ZI03', 'I',   -- TaO
                     'ZL'  , 'I',   -- TaO
                     'C0FX', 'I',   -- TaO
                     'E' )                                      AS tipoDeComprobante  ,
--            'PAGO EN UNA SOLA EXHIBICION'                     AS formaDePago        ,
              NVL( FP.FormaPago,
                 DECODE( Doc.MetodoPago, '01', '01',
                                         '02', '02',
                                         '03', '03',
                    EAI_Owner.getConv( 'CFG Settings', 'Forma Pago' ) ) )
                                                                 AS formaDePago        ,              
              '0'                                                AS condicionesDePago  ,
              'Descuento'                                        AS motivoDescuento    ,
              0                                                  AS Descuento          ,
              NVL( Doc.Valor_Subt, 0 )                           AS subTotal           ,
                NVL( Doc.Valor_Subt   , 0 )  
              - NVL( Ret.Retenido     , 0 )
              - NVL( Doc.Retencion_IVA, 0 )
              + NVL( Doc.Valor_IVA    , 0 )                      AS total              ,
--
              NVL( MP.MetodoPago, 
                 DECODE( Doc.MetodoPago, '01', 'PUE',
                                         '02', 'PUE',
                                         '03', 'PUE',
                    EAI_Owner.getConv( 'CFG Settings', 'Metodo Pago' ) ) )
                                                                 AS metodoDePago       ,              
              Doc.ReferenciaBancaria                             AS NumCtaPago         ,                   
--                  
              Doc.TipoCambio                                     AS TipoCambio         ,
              Doc.Moneda                                         AS Moneda             ,
--            
--            'Monterrey, N.L.'                                  AS LugarExpedicion    ,
              T3.FN_TRIM_CFDI( Soc.Municipio     ) || '/'  ||            
              T3.FN_TRIM_CFDI(              
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Soc.Estado ) )               AS LugarExpedicion    ,
              T3.FN_TRIM_CFDI( Soc.RFC             )             AS Emisor_RFC         ,
              T3.FN_TRIM_CFDI( Soc.Razon_Social_HH )             AS Emisor_Nombre      ,
              T3.FN_TRIM_CFDI( Soc.Calle           )             AS Emisor_Calle       , 
              T3.FN_TRIM_CFDI( Soc.Numero_Ext      )             AS Emisor_NoExterior  ,
              T3.FN_TRIM_CFDI( Soc.Numero_Int      )             AS Emisor_NoInterior  ,
              T3.FN_TRIM_CFDI( Soc.Colonia         )             AS Emisor_Colonia     ,
              T3.FN_TRIM_CFDI( Soc.Localidad       )             AS Emisor_Localidad   ,
              T3.FN_TRIM_CFDI( Soc.Municipio       )             AS Emisor_Municipio   ,
--            T3.FN_TRIM_CFDI( Soc.Estado          )             AS Emisor_Estado      ,
              T3.FN_TRIM_CFDI(              
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Soc.Estado ) )               AS Emisor_Estado      ,              
              T3.FN_TRIM_CFDI( Soc.Pais          )               AS Emisor_Pais        ,
              T3.FN_TRIM_CFDI( Soc.Codigo_Postal )               AS Emisor_CodigoPostal,
--              
              T3.FN_TRIM_CFDI( Soc.Calle           )             AS Expide_Calle       , 
              T3.FN_TRIM_CFDI( Soc.Numero_Ext      )             AS Expide_noExterior  ,
              T3.FN_TRIM_CFDI( Soc.Numero_Ext      )             AS Expide_noInterior  ,
              T3.FN_TRIM_CFDI( Soc.Colonia         )             AS Expide_colonia     ,
              T3.FN_TRIM_CFDI( Soc.Municipio       )             AS Expide_municipio   ,
              T3.FN_TRIM_CFDI(              
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Soc.Estado ) )               AS Expide_estado      ,
              T3.FN_TRIM_CFDI( Soc.Pais          )               AS Expide_pais        ,
              T3.FN_TRIM_CFDI( Soc.Codigo_Postal )               AS Expide_codigoPostal,              
--
              EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal' )              
                                                                 AS RegimenFiscal      ,
--              
              NVL( Reg.Regimen_Fiscal,
                   EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal Cliente' ) ) 
                                                                 AS RegimenFiscal_Cte  ,
              NVL( Uso.UsoCFDI,                                   
                   EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Comercial' ) ) 
                                                                 AS UsoCFDI            ,
              NVL( UsoCM.UsoCFDI,                                   
                   EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_ImportExport_NC' ) ) 
                                                                 AS UsoCFDI_CM         ,
              Doc.RFC                                            AS Recibe_RFC         ,
              NVL( CteX.Nombre, Doc.Nombre )                     AS Recibe_Nombre      ,
              Doc.Direccion                                      AS Recibe_Calle       , 
              ''                                                 AS Recibe_NoExterior  ,
              ''                                                 AS Recibe_NoInterior  ,
              Doc.Colonia                                        AS Recibe_Colonia     ,
              ''                                                 AS Recibe_Localidad   ,
              Doc.Ciudad                                         AS Recibe_Municipio   ,
--            Doc.Estado                                         AS Recibe_Estado      ,
              EAI_Owner.getConv( 'CFDI Estado',
                 Doc.Estado )                                    AS Recibe_Estado      ,
              Doc.Pais                                           AS Recibe_Pais        ,
              DECODE( Doc.RFC, 'XAXX010101000', T3.FN_TRIM_CFDI( Soc.Codigo_Postal ),
                               'XEXX010101000', T3.FN_TRIM_CFDI( Soc.Codigo_Postal ),
                 NVL( CP.CP, Doc.CodigoPostal ) )                AS Recibe_CodigoPostal,
              NVL( CE_CP.CodigoPostal, 
                 NVL( CP.CP, Doc.CodigoPostal ) )                AS Doc_CodigoPostal   ,
--                    
              NVL( PF.Sold_to_Address, Doc.Direccion )           AS Remite_Calle       ,
              ''                                                 AS Remite_noExterior  ,
              ''                                                 AS Remite_noInterior  ,
              NVL( PF.Sold_to_District, Doc.Colonia  )           AS Remite_colonia     ,
              NVL( PF.Sold_to_City    , Doc.Ciudad   )           AS Remite_municipio   ,
              EAI_Owner.getConv( 'CFDI Estado',
                 NVL( PF.Sold_to_State, Doc.Estado ) )           AS Remite_estado      ,
              NVL( PF.Sold_to_Country, Doc.Pais     )            AS Remite_pais        ,
              NVL( PF.Sold_to_ZipCode, Doc.CodigoPostal )        AS Remite_codigoPostal,
--
              DECODE( Doc.Clase_Factura, 
                     'ingreso', 'FACTURA',
                     'VF'  , 'FACTURA',
                     'TC'  , 'FACTURA',
                     'YC'  , 'FACTURA',
                     'ZF2' , 'FACTURA',
                     'IV'  , 'FACTURA',
                     'ZI01', 'FACTURA',   -- TaO                     
                     'ZI03', 'FACTURA',   -- TaO
                     'ZL'  , 'FACTURA',   -- TaO
                     'C0FX', 'FACTURA',   -- TaO                               
                     'NOTA DE CREDITO'
                     )                                           AS Tipo_Documento     ,
              Doc.CLTE_FACTURA_SAP                               AS Recibe_Cliente     ,
              Doc.CLIENTE_SAP                                    AS Remite_Cliente     ,  
              Doc.Cliente_SAP                                    AS Cliente_SAP        ,
              T3.FN_CFDI_SERVICIOS( Doc.Factura )                AS CentroExpedicion   ,
              CASE
--               WHEN ( Doc.Nombre          = 'Imperial Tobacco Canada Limited' ) THEN 2
--               WHEN ( UPPER( Doc.Nombre ) = 'IMPERIAL TOBACCO CANADA LIMITED' ) THEN 2
                 WHEN ( Doc.Clte_Factura_SAP = 'IC-00-CO14' ) THEN 2
                 ELSE
                    0
              END                                                AS DecimalesCFDI      , 
              ''                                                 AS eMail              ,
--
              ''                                                 AS ConfirmacionPAC    ,
              EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_ImportExport' )
                                                                 AS UsoCFDI_Inv        ,
              EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_ImportExport_NC' )
                                                                 AS UsoCFDI_NC         ,
              DECODE( Doc.RFC, 'XEXX010101000',
                EAI_Owner.getConv( 'CFDI Pais', Doc.Pais ), '' )                                                                
                                                                 AS ResidenciaFiscal   ,
              DECODE( Doc.RFC, 'XEXX010101000', 
                 NVL( CE_NIF.NIF, NVL( Doc.NIF, '' ) ) )         AS RegTributarioExt   ,
              ''                                                 AS TipoRelacion       ,
              NVL( CE_Edo.Estado, Doc.Estado        )            AS CE_Estado          ,
              NVL( CE_Cd.Ciudad , Doc.Ciudad        )            AS CE_Ciudad          ,
--                  
              Doc.Sociedad                                       AS Sociedad           ,              
              Doc.Observaciones                                                                      AS Observaciones       ,
              NVL( Doc.Incoterms, '' )                                                               AS Incoterms           ,
              SUBSTR( NVL( Doc.Incoterms, ''), 1, 3 )                                                AS CE_Incoterms        ,
              TRIM( TO_CHAR( NVL( Doc.Valor_IVA, 0 ), '9999999999.99' ) )                            AS ImpuestosTrasladados,
              'IVA'                                                                                  AS impuesto            , 
              TRIM( TO_CHAR( ROUND( NVL( Doc.Valor_IVA , 0 ) * 100 / 
               ( NVL( Ret.Retenido, 0 ) + NVL( Doc.Valor_Subt, 0 ) ) )         ,           '999' ) ) AS tasa                ,
              TRIM( TO_CHAR( NVL( Doc.Valor_IVA, 0 )                           , '9999999999.99' ) ) AS importe             ,
              NVL( Doc.Retencion_IVA, 0 )                                                            AS Retencion_IVA
          FROM T3.Otros_General   Doc ,
                          ( SELECT RFC, MAX( Valor ) AS Regimen_Fiscal
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'RegimenFiscal' 
                                GROUP BY RFC ) Reg,
                          ( SELECT RFC, MAX( Valor ) AS UsoCFDI
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'UsoCFDI' 
                                GROUP BY RFC ) Uso,          
                          ( SELECT RFC, MAX( Valor ) AS UsoCFDI
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'UsoCFDI_Credito' 
                                GROUP BY RFC ) UsoCM,          
                          ( SELECT RFC, MAX( Valor ) AS Nombre
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'Nombre' 
                                GROUP BY RFC ) CteX,          
                          ( SELECT RFC, MAX( Valor ) AS FormaPago
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'FormaPago' 
                                GROUP BY RFC ) FP,          
                          ( SELECT RFC, MAX( Valor ) AS MetodoPago
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'MetodoPago' 
                                GROUP BY RFC ) MP,        
                          ( SELECT RFC, MAX( Valor ) AS CP
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'CodigoPostal' 
                                GROUP BY RFC ) CP,
                          ( SELECT RFC, MAX( Valor ) AS NIF
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'CE_NIF' 
                                GROUP BY RFC ) CE_NIF,                                
                          ( SELECT RFC, MAX( Valor ) AS CodigoPostal
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'CE_CP' 
                                GROUP BY RFC ) CE_CP,                             
                          ( SELECT RFC, MAX( Valor ) AS Estado
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'CE_Estado' 
                                GROUP BY RFC ) CE_Edo,                             
                          ( SELECT RFC, MAX( Valor ) AS Ciudad
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'CE_Ciudad' 
                                GROUP BY RFC ) CE_Cd,                             
               T3.RF_Complemento  Comp,
               ( SELECT Factura, SUM( NVL( Total_Condicion, 0 ) ) AS Retenido
                    FROM T3.Otros_Condiciones
                    WHERE Factura      = pFactura
                      AND Condicion_ID = 'ZDD6'
                 GROUP BY Factura  ) Ret ,
               EAI.ZSDFE_Soc      Soc ,
               EAI_Owner.TMP_DOCUMENT_PARTNERS PF
          WHERE Doc.Factura          = pFactura
            AND Doc.Factura          = Comp.Factura 
            AND Doc.Factura          = Ret.Factura(+) 
            AND Doc.Factura          = PF.ReferenceID(+)
            AND Doc.Sociedad         = Soc.BUKRS
            AND Doc.RFC              = Reg.RFC(+)
            AND Doc.RFC              = Uso.RFC(+)
            AND Doc.RFC              = UsoCM.RFC(+)
            AND Doc.RFC              = FP.RFC(+)
            AND Doc.RFC              = MP.RFC(+)
            AND Doc.RFC              = CP.RFC(+)
            AND Doc.Clte_Factura_SAP = CE_NIF.RFC(+)
            AND Doc.Clte_Factura_SAP = CE_CP.RFC(+)
            AND Doc.Clte_Factura_SAP = CE_Edo.RFC(+)
            AND Doc.Clte_Factura_SAP = CE_Cd.RFC(+)
            AND Doc.RFC              = CteX.RFC(+)
            AND Doc.Sociedad         = NVL( Soc.KUNNR, 'NULL' )            ;                         -- CFDI
--
   CURSOR ScrDetalle IS
                    SELECT
                                  TRIM( TO_CHAR( ROWNUM          , '999999999'     ) ) AS numLinea           ,
--                                TRIM( TO_CHAR( Item.Cantidad, '999999999'        ) ) AS cantidad           ,
--                                TRIM( TO_CHAR( Item.Cantidad, '999999999'        ) ) AS cantidad           ,
                                  T3.FN_NUM_TO_CHAR_CFDI( Item.Cantidad, 
                                                          nDecimalesCFDI )             AS cantidad           ,
                                  Item.UnidadMedida                                    AS unidad             ,
                                  EAI_Owner.getConv( 'CFDI SAT UM', Item.UnidadMedida )   
                                                                                       AS SAT_UM_Conv        ,
                                  Item.Material                                        AS noIdentificacion   ,
                                  0                                                    AS Cig_x_Unidad_Vta   ,
                                  TRIM( TO_CHAR( Item.PrecioUnitario , '999999999.99'  ) ) 
                                                                                       AS valorUnitario      ,
                                  TRIM( TO_CHAR( Item.Valor_Subt     , '999999999.99'  ) ) 
                                                                                       AS importe            ,
                                  'NO'                                                 AS SKU_importacion    ,
                                  NVL( Item.Valor_Subt , 0 )                           AS RFD_Valor_Subt     ,
                                  NVL( Item.Valor_IVA  , 0 )                           AS RFD_Valor_IVA      ,                                
                                  'BAT'                                                AS Channel            ,
                                  Item.SAT_ProdID                                      AS SAT_ProdID         ,
                                  Item.SAT_UM                                          AS SAT_UM             , 
--                                Item.MaterialDescripcion                             AS descripcion        ,
--                                T3.FN_CFDI_SKU_NAME( Item.MaterialDescripcion )      AS descripcion        ,
                                  T3.FN_CFDI_SKU_NAME( 
                                      NVL( Bill.Descripcion_Factura, Item.MaterialDescripcion )
                                      )                                                AS descripcion        ,        
                                  Bill.FraccionArancelaria                             AS FraccionArancelaria,
                                  NVL( Bill.Factor_Arancelario, 1 )                    AS Factor_Arancelario ,
                                  Item.Leyenda_ES                                      AS DatosAdicionales   ,
                                  Item.Leyenda_EN                                      AS DatosAdicionales_EN,
                                  TRIM( TO_CHAR( NVL( Item.Valor_Subt, 0 ),
                                                                   '999999999.99'  ) ) AS PDF_Valor_Subt     ,
                                  TRIM( TO_CHAR( NVL( Item.Valor_IVA , 0 ),
                                                                   '999999999.99'  ) ) AS PDF_Valor_IVA      ,
                                  TRIM( TO_CHAR( ROUND( Item.Valor_IVA * 100 / Item.Valor_Subt, 2 ),             
                                                                             '99'  ) ) AS PDF_TASA_IVA       ,                                             
                                  NVL( Item.Retencion_IVA, 0 )                         AS Retencion_IVA
--                                NVL( Item.Leyenda_ES, Item.Leyenda_EN )              AS DatosAdicionales
                     FROM T3.Otros_Detalle Item,
                          (
                            SELECT Material, MAX( Descripcion_Factura )          AS Descripcion_Factura, 
                                             MAX( FraccionArancelaria )          AS FraccionArancelaria,
                                             MAX( NVL( Factor_Arancelario, 1 ) ) AS Factor_Arancelario
                               FROM T3.CFDI_PRODSERV 
                               WHERE Modulo = 'EXPO' AND Descripcion_Factura IS NOT NULL
                               GROUP BY Material
                            ) Bill
                     WHERE Item.Factura    = pFactura 
                       AND Item.Material   = Bill.Material(+);                         -- CFDI
--
   CURSOR ScrCondiciones IS
                    SELECT
                                  TRIM( TO_CHAR( nLineas + ROWNUM, '999999999'     ) ) AS numLinea           ,
--                                TRIM( TO_CHAR( Item.Cantidad, '999999999'        ) ) AS cantidad           ,
                                  TRIM( TO_CHAR( NVL( Item.Cantidad, 0 ), '999999999'  
                                                                                   ) ) AS cantidad           ,
                                  NVL( Item.Unidad_Medida, '-' )                       AS unidad             ,
                                  Item.Condicion_ID                                    AS noIdentificacion   ,
                                  0                                                    AS Cig_x_Unidad_Vta   ,
--                                TRIM( TO_CHAR( NVL( Item.Precio, 0 ), '999999999.99'  ) ) 
                                  NVL( Item.Precio, 0 )
                                                                                       AS valorUnitario      ,
--                                TRIM( TO_CHAR( NVL( Item.Total_Monto, 0 ), '999999999.99'  ) ) 
                                  NVL( Item.Total_Monto, 0 )
                                                                                       AS importe            ,
                                  'NO'                                                 AS SKU_importacion    ,
                                  NVL( Item.Total_Monto, 0 )                           AS RFD_Valor_Subt     ,             
                                  0                                                    AS RFD_Valor_IVA      ,                                 
                                  'BAT'                                                AS Channel            ,
                                  Item.Condicion_Texto                                 AS descripcion        
                     FROM T3.Otros_Condiciones Item
                     WHERE Item.Factura       = pFactura 
                       AND Item.Condicion_ID != 'ZDD6'            -- Impuestos Retenidos
                     ORDER BY Num_Linea ;                         -- CFDI
--
   CURSOR ScrHeadAddenda IS   
       SELECT 
              '7504015884004'                    AS GLN_BAT          ,
              ''                                 AS Sucursal_EDI     ,
              ''                                 AS SucursalName     , 
              ''                                 AS Ref_Pedido       ,
              ''                                 AS Ref_Entrada      ,
              ''                                 AS Ref_Tienda       ,
              ''                                 AS Ref_Sucursal     ,
--              
              'CABADD'                           AS Label            ,
              'OR'                               AS Funcion          ,
              ''                                 AS Doc_Reemplazo    ,
              ''                                 AS Pedido           ,
              TO_CHAR( RF.Fecha_Factura, 'DDMMYYYY' )   
                || REPLACE( Comp.Hora_Factura, ':', '' )
                                                 AS FePedido         ,
              ''                                 AS NotaEnt          ,
              TO_CHAR( RF.Fecha_Factura, 'DDMMYYYY' )   
                                                 AS FeNotaEnt        ,
--              
              '7504015884004'                    AS VendedorGLN      ,
              ''                                 AS VendorNInt       , 
              ''                                 AS VendorIEPS       ,
              ''                                 AS CompradorGLN     ,
              ''                                 AS CompradorConti   ,
--              
              ''                                 AS CompradorNRef    ,
              ''                                 AS ReceptorGLN      ,
              ''                                 AS ReceptorNombre   ,
              ''                                 AS ReceptorCalle    ,
              ''                                 AS ReceptorColonia  ,
              ''                                 AS ReceptorLocal    ,
              ''                                 AS ReceptorMunicip  ,
              ''                                 AS ReceptorEstado   ,
              ''                                 AS ReceptorPais     ,
              ''                                 AS ReceptorCP       ,
              RF.Moneda                          AS MonedaPrecio     ,
--              
              RF.TipoCambio                      AS TCambioMPR       ,
              'MXN'                              AS MonedaPago       ,
              '1.00'                             AS TCambioMPY       ,
              'FE'                               AS RefPago          ,
              'BT'                               AS CondPago         ,
              '0'                                AS DPago            ,
              ''                                 AS NCheque          ,
--              
--            RF.Valor_Subtotal                  AS TotNeto          ,
              TRIM( TO_CHAR( 
                 RF.Valor_Subt
                 , '999999999.99' ) )            AS TotNeto          ,
              ''                                 AS CPredial         ,
              REPLACE(
              PR_NUM_A_LETRAS.DinTex( RF.Valor_Subt + RF.Valor_IVA ) , 'M.N.', 'M. N.' )
                                                 AS TotalconLetra    ,
              ''                                 AS Folio_Aviso_Pago ,                                                 
              ''                                 AS Plaza            ,
              ''                                 AS TipoProv         ,
              ''                                 AS TipoLoc          ,
--
              '1'                                AS TipoBulto        ,
              'true'                             AS CumpleReqFiscales,
              '1'                                AS CantBulto        ,
              '1'                                AS CantPedido       ,
              'SI'                               AS PedemiProv       ,
              ''                                 AS Pedido_Vend      ,
              ''                                 AS Factura_Nota     ,
              RF.Factura                         AS Remision         ,
              ''                                 AS DestinoBM        ,
              ''                                 AS CorreoProveedor  ,
              'PD'                               AS TipoPedido       ,              
              RF.Complemento_CE                  AS ComplementoCE        
          FROM T3.Otros_General       RF  ,
               T3.RF_Complemento      Comp
          WHERE RF.Factura          = pFactura 
            AND RF.Factura          = Comp.Factura ;      
--                      
   CURSOR ScrReenvio IS
      SELECT Folio_Fiscal, Fecha_Factura
         FROM T3.CFDI_Reproceso 
         WHERE Nota_Venta = pFactura
         ORDER BY Fecha DESC ;                   
BEGIN 
--
   SELECT Sociedad || '-' || RFC  AS Soc_RFC
      INTO sSoc_RFC
      FROM T3.Otros_General OG
      WHERE OG.Factura = pFactura ;
   IF ( sSoc_RFC = 'MX10-XEXX010101000' ) THEN
      nDiasMX10 := 7 ;
   ELSE
      nDiasMX10 := 0 ;
   END IF ;
--
   strID      := pFactura ;
   sReturn    := '' ; 
   sCABCLIE   := '' ;
   sADULFAC   := '' ;
   nTotal     := 00 ;
   nItems     := 00 ;   
   uHEADER    := '' ;
   uIMPFAC    := '' ;
   uLINFAC    := '' ;   
   uCABADD    := '' ;
   uCOMEXT    := '' ;
   sSepLinea  := CHR(13) || CHR(10) ;
   sSepCampo  := '|' ;
   sLeyMenor  := 'Le recordamos que las Leyes prohíben y sancionan la venta de cigarros a menores de 18 años de edad '  ||
                 'y en unidades sueltas. En caso de duda solicite identificación oficial. Ayúdenos a que los menores '  ||
                 'de edad no tengan acceso a los cigarros.' ;
   sLeyPriv   := 'British American Tobacco México S.A. de C.V. y subsidiarias protegen los datos personales de sus clientes ' ||
                 'que son tratados por nuestra empresa. Para mayor información consultar el aviso de privacidad en www.batmexico.com.mx' ;
   sLeyPriv   := 'British American Tobacco México, S.A. de C.V. y empresas relacionadas, con domicilio indicado arriba, utilizará los datos personales ' ||
                 'que usted entregue voluntariamente en este documento para cumplir con las políticas, procedimientos y requisitos legales aplicables, ' ||
                 'para llevar un registro adecuado de los proveedores y clientes, y para coordinar los servicios prestados por y para el Grupo. '        ||
                 'Para mayor información respecto al tratamiento de sus datos personales o al ejercicio de sus derechos ARCO consulte nuestro aviso '    ||
                 'de privacidad en www.batmexico.com.mx.' ;
   sLeyPriv   := 'British American Tobacco México, S.A. de C.V. y sus empresas relacionadas (el "Grupo"), con domicilio en Avenida Francisco I. Madero, ' ||
                 '2750 Pte., Centro de la Ciudad, Monterrey, N.L. C.P. 64000, utilizarán los datos personales que usted entregue voluntariamente mediante '    ||
                 'este documento para cumplir con las políticas, procedimientos operativos y requisitos legales aplicables y llevar un registro adecuado' || 
                 ' de los proveedores y clientes del Grupo. Para mayor información respecto al tratamiento de sus datos personales o al ejercicio de sus' || 
                 ' derechos ARCO consulte nuestro aviso de privacidad integral en www.batmexico.com.mx' ;
--
   sLeyPriv   := 'British American Tobacco México, S.A. de C.V. y subsidiarios protegen los datos personales de sus clientes ' ||
                 'que son tratados por nuestra empresa. Para mayor información puede consultar el aviso de privacidad en www.batmexico.com.mx / ' ||
                 'British American Tobacco México, S.A. de C.V. and its subsidiaries protect the Personal Data of their clients processed by ' ||
                 'our company. For further information you may consult our privacy notice at www.batmexico.com.mx' ;
   sLeyMenor  := '' ;
   sAddenda   := 'NO' ;
--      
      nCFDIREL := 00 ;
      sCFDIREL := '' ;
      FOR Env IN ScrReenvio LOOP 
         nCFDIREL := nCFDIREL + 1 ;
         sCFDIREL := sCFDIREL || 'BILLREF'        || sSepCampo ;
         sCFDIREL := sCFDIREL || Env.Folio_Fiscal || sSepCampo ;          -- 02 Folio UUID
         sCFDIREL := sCFDIREL || ''               || sSepCampo ;          -- 03 Tax ID
         sCFDIREL := sCFDIREL || ''               || sSepCampo ;          -- 04 Fecha Documento
         sCFDIREL := sCFDIREL || '04'             || sSepCampo ;          -- 05 Clave de Relacion
         sCFDIREL := sCFDIREL || ''               || sSepCampo ;          -- 06 Motivo Modificacion
         sCFDIREL := sCFDIREL || sSepLinea ;         
      END LOOP ;    
--
   FOR Doc IN ScrDatos LOOP
---------------------------------------
-- 
      sLeyMenor            := Doc.Observaciones       ;
      sIncoterms           := Doc.Incoterms           ;
      nDecimalesCFDI       := Doc.DecimalesCFDI       ;
      nUSD_TipoCambio      := Doc.USD_TipoCambio      ;
      nDoc_TipoCambio      := Doc.Tipocambio          ;
      sTipoDocto           := Doc.Tipo_Docto          ;
      sFactura             := Doc.Factura             ;
      sCtro                := Doc.Ctro                ;
      nTotal               := Doc.Doc_Total           ;
      sMetodoPago          := Doc.metodoDePago        ;
      sMonedaDoc           := Doc.moneda              ;
-- Variables para CABCLIE
      sPedidoV3            := Doc.PedidoV3            ;
      sSucursalNombre      := Doc.SucursalNombre      ;
      sPedidoSAP           := Doc.PedidoSAP           ;
      sFacturaSAP          := Doc.FacturaSAP          ;
      sRecibe_Nombre       := Doc.Recibe_Nombre       ;
      sRemite_Calle        := Doc.Remite_Calle        ;
      sRemite_noExterior   := Doc.Remite_noExterior   ;
      sRemite_noInterior   := Doc.Remite_noInterior   ;
      sRemite_colonia      := Doc.Remite_Colonia      ;
      sRemite_municipio    := Doc.Remite_Municipio    ;
      sRemite_estado       := Doc.Remite_Estado       ;
      sRemite_pais         := Doc.Remite_Pais         ;
      sRemite_codigoPostal := Doc.Remite_codigoPostal ;
      sTipo_Documento      := Doc.Tipo_Documento      ;
      sRecibe_Cliente      := Doc.Recibe_Cliente      ;
      sRemite_Cliente      := Doc.Remite_Cliente      ;
      sCentroExpedicion    := Doc.CentroExpedicion    ;
      sLugarExpedicion     := Doc.LugarExpedicion     ;
      seMail               := Doc.eMail               ;
      sSociedad            := Doc.Sociedad            ;
      sMetodoDePago        := Doc.metodoDePago        ;
      sNumCtaPago          := Doc.NumCtaPago          ;
      IF ( NVL( Doc.ComplementoCE, 'EMPTY' ) = 'CCE' ) THEN
         sAddenda := 'SI' ;
--         IF ( Doc.Cliente_SAP != 'PC-00-HN01' ) THEN
--            PROC_V33_GENERAR_OTROS( pFactura ) ;
--            COMMIT ;
--            RETURN ;
--         END IF ;  
      END IF ;   

-- Cabecera Factura
      SELECT SUM( NVL( Total_Condicion, 0 ) )  INTO nRetenciones
         FROM T3.Otros_Condiciones
         WHERE Factura      = pFactura
           AND Condicion_ID = 'ZDD6' ;
         nRetenciones := nRetenciones + 0 ;
         Doc.Retencion_IVA := Doc.Retencion_IVA + 0 ;
--
-- HEADER
      uHEADER  := uHEADER || 'HEADER'                                       || sSepCampo ;              
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 02 Codigo de Autorizacion
      uHEADER  := uHEADER || Doc.tipoDeComprobante                          || sSepCampo ;   -- 03 Tipo de Comprobante
      uHEADER  := uHEADER || Doc.folio                                      || sSepCampo ;   -- 04 Folio
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 05 Fecha de Vencimiento
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 06 Tipo de Ingreso
      uHEADER  := uHEADER || Doc.FormaDePago                                || sSepCampo ;   -- 07 Tipo de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 08 Fecha Limite de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 09 Tipo Cuenta de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 10 Numero Cuenta de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 11 Banco de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 12 Fecha Inicio Servicios
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 13 Fecha Inicio Servicios
      IF ( nCFDIREL = 0 ) THEN
         uHEADER  := uHEADER || Doc.fecha                                   || sSepCampo ;   -- 14 Fecha Emision Documento
      ELSE
         uHEADER  := uHEADER || Doc.fecha_Reenvio                           || sSepCampo ;   -- 14 Fecha Emision Documento
      END IF ;
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 15 Fecha Orden de Compra
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 16 Orden de Compra
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.Importe        , 2 )  || sSepCampo ;   -- 17 Monto Gravado Total
      uHEADER  := uHEADER || '0.00'                                         || sSepCampo ;   -- 18 Monto Exento
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.SubTotal       , 2 )  || sSepCampo ;   -- 19 Subtotal
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.Importe        , 2 )  || sSepCampo ;   -- 20 Total Impuestos Trasladados
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 21 Impuestos Retenidos
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.Total          , 2 )  || sSepCampo ;   -- 22 Monto Total
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 23 Monto No Facturable
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 24 Monto Periodo
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 25 Saldo Anterior
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 26 Monto Avance de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 27 Valor Cobrado
      uHEADER  := uHEADER || Doc.Factura                                    || sSepCampo ;   -- 28 Folio Interno Factura
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 29 Indicador Nota de Credito
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 30 Indicador Monto Gravado
      uHEADER  := uHEADER || Doc.condicionesDePago                          || sSepCampo ;   -- 31 Terminos de Pago
      uHEADER  := uHEADER || Doc.Moneda                                     || sSepCampo ;   -- 32 Moneda
      uHEADER  := uHEADER || Doc.Serie                                      || sSepCampo ;   -- 33 Serie      
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 34 Confirmation
      uHEADER  := uHEADER || 'C'                                            || sSepCampo ;   -- 35 Flag Addenda/Complemento
--
      IF ( Doc.Recibe_RFC = 'XEXX010101000' ) THEN
         IF ( sAddenda = 'SI' ) THEN
            uHEADER  := uHEADER || '02'                                     || sSepCampo ;   -- 36 Tipo Exportacion
         ELSE
            uHEADER  := uHEADER || '03'                                     || sSepCampo ;   -- 36 Tipo Exportacion
         END IF ;
      ELSE   
            uHEADER  := uHEADER || '01'                                     || sSepCampo ;   -- 36 Tipo Exportacion
      END IF ;   
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 37 Peridiocidad
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 38 Mes de Documento
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 39 Anio
      uHEADER  := uHEADER || Doc.versionCFDI                                || sSepCampo ;   -- 40 Version
-- PARTIES - Emisor
      uHEADER  := uHEADER || sSepLinea                             ;
      uHEADER  := uHEADER || 'PARTIES'                || sSepCampo ;              
      uHEADER  := uHEADER || 'E'                      || sSepCampo ;              
      uHEADER  := uHEADER || Doc.Emisor_RFC           || sSepCampo ;   -- 03 TaxID
      uHEADER  := uHEADER || Doc.Emisor_Nombre        || sSepCampo ;   -- 04 Legal Entity Name
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 05 Trade Name
      uHEADER  := uHEADER || Doc.LugarExpedicion      || sSepCampo ;   -- 06 Branch Name
      uHEADER  := uHEADER || Doc.Emisor_Calle         || ' ' ||
                             Doc.Emisor_NoExterior    || sSepCampo ;   -- 07 Address
      uHEADER  := uHEADER || Doc.Emisor_Colonia       || sSepCampo ;   -- 08 Colonia
      uHEADER  := uHEADER || Doc.Emisor_Municipio     || sSepCampo ;   -- 09 Municipality
      uHEADER  := uHEADER || Doc.Emisor_Estado        || sSepCampo ;   -- 10 Country Subdivision
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 11 Telephone
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 12 Telephone_2
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 13 Telephone_3
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 14 eMail
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 15 Web Site
      uHEADER  := uHEADER || Doc.RegimenFiscal        || sSepCampo ;   -- 16 Business_Activity
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 17 Seller Internal Code
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 18 Seller Area
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 19 Sales Route
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 20 Additional Info
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 21 Foreign_Tax_ID
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 22 Contac_Details
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 23 Buyer_Internal_Code
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 24 Payer_ID
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 25 City
      uHEADER  := uHEADER || Doc.Emisor_CodigoPostal  || sSepCampo ;   -- 26 Postal Code
      uHEADER  := uHEADER || 'MEX'                    || sSepCampo ;   -- 27 Country Code
--
-- PARTIES - Receptor
      uHEADER  := uHEADER || sSepLinea                             ;
      uHEADER  := uHEADER || 'PARTIES'                || sSepCampo ;              
      uHEADER  := uHEADER || 'R'                      || sSepCampo ;              
      uHEADER  := uHEADER || Doc.Recibe_RFC           || sSepCampo ;   -- 03 TaxID
      uHEADER  := uHEADER || Doc.Recibe_Nombre        || sSepCampo ;   -- 04 Legal Entity Name
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 05 Trade Name
      uHEADER  := uHEADER || Doc.SucursalNombre       || sSepCampo ;   -- 06 Branch Name
      uHEADER  := uHEADER || Doc.Recibe_Calle         || sSepCampo ;   -- 07 Address
      uHEADER  := uHEADER || Doc.Recibe_Colonia       || sSepCampo ;   -- 08 Colonia
      uHEADER  := uHEADER || Doc.Recibe_Municipio     || sSepCampo ;   -- 09 Municipality
      uHEADER  := uHEADER || Doc.Recibe_Estado        || sSepCampo ;   -- 10 Country Subdivision
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 11 Telephone
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 12 Telephone_2
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 13 Telephone_3
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 14 eMail
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 15 Web Site
      uHEADER  := uHEADER || Doc.RegimenFiscal_Cte    || sSepCampo ;   -- 16 Business_Activity
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 17 Seller Internal Code
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 18 Seller Area
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 19 Sales Route
      IF ( Doc.tipoDeComprobante = 'I' ) THEN
         uHEADER  := uHEADER || Doc.UsoCFDI           || sSepCampo ;   -- 20 Additional Info
      ELSE
         uHEADER  := uHEADER || Doc.UsoCFDI_CM        || sSepCampo ;   -- 20 Additional Info
      END IF ;      
      uHEADER  := uHEADER || Doc.RegTributarioExt     || sSepCampo ;   -- 21 Foreign_Tax_ID
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 22 Contac_Details
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 23 Buyer_Internal_Code
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 24 Payer_ID
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 25 City
      uHEADER  := uHEADER || Doc.Recibe_CodigoPostal  || sSepCampo ;   -- 26 Postal Code
      uHEADER  := uHEADER || Doc.ResidenciaFiscal     || sSepCampo ;   -- 27 Country Code      
      sUsoCFDI := Doc.UsoCFDI ;
--
-- Addenda para ComercioExterior
--      
      IF ( sAddenda = 'SI' ) THEN
         FOR Inf IN ScrHeadAddenda LOOP
            sStepPLSQL := 'A_HEADER' ;
            uCABADD := uCABADD || sSepLinea                          ;
            uCABADD := uCABADD || 'A_HEADER'            || sSepCampo ;
            uCABADD := uCABADD || Inf.Funcion           || sSepCampo ;          -- 02 Funcion
            uCABADD := uCABADD || Inf.Doc_Reemplazo     || sSepCampo ;          -- 03 Numero Documento
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 04 Pedido
            uCABADD := uCABADD || Inf.FePedido          || sSepCampo ;          -- 05 Fecha de Pedido
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 06 Nota Entrada
            uCABADD := uCABADD || Inf.FeNotaEnt         || sSepCampo ;          -- 07 Fecha Entrada
            uCABADD := uCABADD || Inf.VendedorGLN       || sSepCampo ;          -- 08 Codigo EAN
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 09 Numero Interno
            uCABADD := uCABADD || Inf.VendorIEPS        || sSepCampo ;          -- 10 Referencia Proveedor
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 11 Comprador GLN
            uCABADD := uCABADD || Inf.CompradorConti    || sSepCampo ;          -- 12 Info Comprador
            uCABADD := uCABADD || Inf.CompradorNRef     || sSepCampo ;          -- 13 ID Cobro IEPS
            uCABADD := uCABADD || Inf.ReceptorGLN       || sSepCampo ;          -- 14 Receptor GLN
            uCABADD := uCABADD || Inf.ReceptorNombre    || sSepCampo ;          -- 15 Receptor Nombre
            uCABADD := uCABADD || Inf.ReceptorCalle     || sSepCampo ;          -- 16 Receptor Calle
            uCABADD := uCABADD || Inf.ReceptorColonia   || sSepCampo ;          -- 17 Receptor Colonia
            uCABADD := uCABADD || Inf.ReceptorLocal     || sSepCampo ;          -- 18 Receptor Localidad
            uCABADD := uCABADD || Inf.ReceptorMunicip   || sSepCampo ;          -- 19 Receptor Ciudad
            uCABADD := uCABADD || Inf.ReceptorEstado    || sSepCampo ;          -- 20 Receptor Estado
            uCABADD := uCABADD || Inf.ReceptorPais      || sSepCampo ;          -- 21 Receptor Pais
            uCABADD := uCABADD || Inf.ReceptorCP        || sSepCampo ;          -- 22 Receptor Codigo Postal
            uCABADD := uCABADD || Inf.MonedaPrecio      || sSepCampo ;          -- 23 Moneda
            uCABADD := uCABADD || Inf.TCambioMPR        || sSepCampo ;          -- 24 Tipo de Cambio
            uCABADD := uCABADD || Inf.MonedaPago        || sSepCampo ;          -- 25 Moneda de Pago
            uCABADD := uCABADD || Inf.TCambioMPY        || sSepCampo ;          -- 26 Tipo de Cambio de Pago
            uCABADD := uCABADD || Inf.RefPago           || sSepCampo ;          -- 27 Ref Pago
            uCABADD := uCABADD || Inf.CondPago          || sSepCampo ;          -- 28 Condicion Pago
            uCABADD := uCABADD || Inf.DPago             || sSepCampo ;          -- 29 Dias de Pago
            uCABADD := uCABADD || Inf.NCheque           || sSepCampo ;          -- 30 Numero de Cheque
            uCABADD := uCABADD || Inf.TotNeto           || sSepCampo ;          -- 31 Total Neto
            uCABADD := uCABADD || Inf.CPredial          || sSepCampo ;          -- 32 Predial
            uCABADD := uCABADD || Inf.TotalconLetra     || sSepCampo ;          -- 33 Total con Letra
            uCABADD := uCABADD || Inf.Folio_Aviso_Pago  || sSepCampo ;          -- 34 Aviso de Pago
            uCABADD := uCABADD || Inf.Plaza             || sSepCampo ;          -- 35 Plaza
            uCABADD := uCABADD || Inf.TipoProv          || sSepCampo ;          -- 36 Tipo de Proveedor
            uCABADD := uCABADD || Inf.TipoLoc           || sSepCampo ;          -- 37 Tipo de Localizacion
            uCABADD := uCABADD || Inf.TipoBulto         || sSepCampo ;          -- 38 Tipo de Bulto
            uCABADD := uCABADD || Inf.CumpleReqFiscales || sSepCampo ;          -- 39 Condicion Requerimiento
            uCABADD := uCABADD || Inf.CantBulto         || sSepCampo ;          -- 40 Cantidad Bultos
            uCABADD := uCABADD || Inf.CantPedido        || sSepCampo ;          -- 41 Cantidad Pedido
            uCABADD := uCABADD || Inf.PedemiProv        || sSepCampo ;          -- 42 
            uCABADD := uCABADD || Inf.Pedido_Vend       || sSepCampo ;          -- 43 Pedido Vendedor
            uCABADD := uCABADD || Inf.Factura_Nota      || sSepCampo ;          -- 44 Factura Nota
            uCABADD := uCABADD || Inf.Remision          || sSepCampo ;          -- 45 Remision
            uCABADD := uCABADD || Inf.DestinoBM         || sSepCampo ;          -- 46 Destino BM
            uCABADD := uCABADD || Inf.CorreoProveedor   || sSepCampo ;          -- 47 Correo Proveedor
            uCABADD := uCABADD || Inf.TipoPedido        || sSepCampo ;          -- 48 Tipo Pedido
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 49 Cajas
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 50 Tarimas
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 51 Cajas x Tarima
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 52 Vendedor Codigo Postal
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 53 Tipo de Addenda
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 54 Sucursal
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 55 Folio Referencia
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 56 Codigo Moneda
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 57 Tipo de Cambio
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 58 Emisor Nombre
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 59 Emisor Domicilio
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 60 Emisor Ciudad            
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 61 Emisor Codigo Postal
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 62 Numero Aprobacion
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 63 Tipo Documento Electronico
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 64 Serie CFDI
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 65 Documento Electronico
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 66 Sumatoria Importes
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 67 Fecha de Emision
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 68 Monto Total
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 69 Numero de Pedido
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 70 Numero Interno Proveedor
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 71 ID Tributario
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 72 Ubicacion Emisor Factura
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 73 Folio Recibo Mercancias
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 74 Condicion de Pago
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 75 Info Pedimientos           
            uCABADD := uCABADD || ''                    || sSepCampo ;          -- 76 Info Compras
            uCABADD := uCABADD || Inf.ComplementoCE     || sSepCampo ;          -- Campo para Comercio Exterior
--            
            uCOMEXT := uCOMEXT || sSepLinea ;
            uCOMEXT := uCOMEXT || 'C_COMEXT'                                    || sSepCampo ;
            uCOMEXT := uCOMEXT || '2'                                           || sSepCampo ;          -- 02 Tipo Operacion
            uCOMEXT := uCOMEXT || 'A1'                                          || sSepCampo ;          -- 03 Clave Pedimento
            uCOMEXT := uCOMEXT || '0'                                           || sSepCampo ;          -- 04 Certificado Origen
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 05 Numero Certificador
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 06 Numero Exportador
            uCOMEXT := uCOMEXT || Doc.CE_Incoterms                              || sSepCampo ;          -- 07 Incoterm
            uCOMEXT := uCOMEXT || '0'                                           || sSepCampo ;          -- 08 Subdivision
            uCOMEXT := uCOMEXT || sLeyMenor                                     || sSepCampo ;          -- 09 Observaciones
--
            uCOMEXT := uCOMEXT || FN_NUM_TO_CHAR_CFDI( Doc.USD_TipoCambio, 5 )  || sSepCampo ;          -- 10 Tipo Cambio USD
            uCOMEXT := uCOMEXT || FN_NUM_TO_CHAR_CFDI( 
              ROUND( Doc.Total * Doc.TipoCambio / Doc.USD_TipoCambio, 2 )
                                                                         , 2 )  || sSepCampo ;          -- 11 Total USD
--
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 12 CURP Emisor
            uCOMEXT := uCOMEXT || 'AV. FRANCISCO I. MADERO'                     || sSepCampo ;          -- 13 Calle Emisor
            uCOMEXT := uCOMEXT || '2750'                                        || sSepCampo ;          -- 14 Num Exterior Emisor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 15 Num Interior Emisor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 16 Colonia Emisor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 17 Localidad Emisor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 18 Referencia Emisor
            uCOMEXT := uCOMEXT || '039'                                         || sSepCampo ;          -- 19 Municipio Emisor
            uCOMEXT := uCOMEXT || 'NLE'                                         || sSepCampo ;          -- 20 Estado Emisor
            uCOMEXT := uCOMEXT || 'MEX'                                         || sSepCampo ;          -- 21 Pais Emisor
            uCOMEXT := uCOMEXT || '64000'                                       || sSepCampo ;          -- 22 Codigo Postal Emisor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 23 ID Receptor
            uCOMEXT := uCOMEXT || Doc.Recibe_Calle                              || sSepCampo ;          -- 24 Calle Receptor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 25 Num Exterior Receptor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 26 Num Interior Receptor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 27 Colonia Receptor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 28 Localidad Receptor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 29 Referencia Receptor
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 30 Municipio Receptor
            uCOMEXT := uCOMEXT || Doc.CE_Estado                                 || sSepCampo ;          -- 31 Estado Receptor
            uCOMEXT := uCOMEXT || Doc.ResidenciaFiscal                          || sSepCampo ;          -- 32 Pais Receptor
            uCOMEXT := uCOMEXT || Doc.Doc_CodigoPostal                          || sSepCampo ;          -- 33 Codigo Postal Receptor            
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 34 ID Destinatario
            uCOMEXT := uCOMEXT || Doc.Recibe_Nombre                             || sSepCampo ;          -- 35 Nombre Destinatario
            uCOMEXT := uCOMEXT || Doc.Recibe_Calle                              || sSepCampo ;          -- 36 Calle Destinatario
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 37 Num Exterior Destinatario
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 38 Num Interior Destinatario
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 39 Colonia Destinatario
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 40 Localidad Destinatario
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 41 Referencia Destinatario
            uCOMEXT := uCOMEXT || Doc.CE_Ciudad                                 || sSepCampo ;          -- 42 Municipio Destinatario
            uCOMEXT := uCOMEXT || Doc.CE_Estado                                 || sSepCampo ;          -- 43 Estado Destinatario
            uCOMEXT := uCOMEXT || Doc.ResidenciaFiscal                          || sSepCampo ;          -- 44 Pais Destinatario
            uCOMEXT := uCOMEXT || Doc.Doc_CodigoPostal                          || sSepCampo ;          -- 45 Codigo Postal Destinatario
            --uCOMEXT := uCOMEXT || '1.1'                                         || sSepCampo ;          -- 46 Version
            uCOMEXT := uCOMEXT || '2.0'                                         || sSepCampo ;          -- 46 Version
            uCOMEXT := uCOMEXT || ''                                            || sSepCampo ;          -- 47 Motivo Traslado
            uCOMEXT := uCOMEXT || Doc.RegTributarioExt                          || sSepCampo ;          -- 48 NumID Tributario Pais
            uCOMEXT := uCOMEXT || Doc.ResidenciaFiscal                          || sSepCampo ;          -- 49 Residencia Fiscal
         END LOOP ;
      END IF ; 
--      
-- Impuestos
--
         uIMPFAC  := uIMPFAC  || 'TAX'                                          || sSepCampo ;
         uIMPFAC  := uIMPFAC  || '002'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.subtotal        , 2 ) || sSepCampo ;      -- 03 Base Imponible
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.importe         , 2 ) || sSepCampo ;      -- 04 Monto de Impuesto
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.tasa / 100      , 6 ) || sSepCampo ;      -- 05 Porcentaje de Impuesto
         uIMPFAC  := uIMPFAC  || 'Tasa'                                         || sSepCampo ;      -- 06 Factor de Impuesto
         uIMPFAC  := uIMPFAC  || 'T'                                            || sSepCampo ;      -- 07 Calificador
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 08               
--      
      IF ( NVL( nRetenciones, 0 ) > 0 ) THEN      
         uIMPFAC  := uIMPFAC  || sSepLinea ;
         uIMPFAC  := uIMPFAC  || 'TAX'                                          || sSepCampo ;
         uIMPFAC  := uIMPFAC  || '002'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 03 Base Imponible
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nRetenciones        , 2 ) || sSepCampo ;      -- 04 Monto de Impuesto
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 05 Porcentaje de Impuesto
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 06 Factor de Impuesto
         uIMPFAC  := uIMPFAC  || 'R'                                            || sSepCampo ;      -- 07 Calificador
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 08               
      END IF ; 
--
      IF ( Doc.Retencion_IVA > 0 ) THEN
         nTasaRet := ROUND( Doc.Retencion_IVA * 100 / Doc.subTotal, 0 ) ;
--
         uIMPFAC  := uIMPFAC  || sSepLinea ;
         uIMPFAC  := uIMPFAC  || 'TAX'                                          || sSepCampo ;
         uIMPFAC  := uIMPFAC  || '002'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 03 Base Imponible
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.Retencion_IVA   , 2 ) || sSepCampo ;      -- 04 Monto de Impuesto
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nTasaRet / 100      , 6 ) || sSepCampo ;      -- 05 Porcentaje de Impuesto
         uIMPFAC  := uIMPFAC  || 'Tasa'                                         || sSepCampo ;      -- 06 Factor de Impuesto
         uIMPFAC  := uIMPFAC  || 'R'                                            || sSepCampo ;      -- 07 Calificador
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 08               
      END IF ;      
--       
   END LOOP ;
--
   nLineas    := 0 ;
   nEnajenado := 0 ;
   nLineasImp := 0 ;
   FOR Item IN ScrDetalle LOOP
      sDetalleItem := 'NO' ;
      nLineas      := nLineas + 1 ; 
      nItems       := nItems + Item.RFD_Valor_Subt + Item.RFD_Valor_IVA ;
      sMaterial    := Item.noIdentificacion ;
      IF ( nLineas = 1 ) THEN
         uLINFAC := '' ;
      ELSE
         uLINFAC := uLINFAC || sSepLinea ;
      END IF ;
      T3.GET_SAT_CLAVEPRODUCTO( 'EXPO', pFactura, Item.noIdentificacion, Item.descripcion, Item.unidad, sSAT_ID, sSAT_UM ) ;      
      IF ( LENGTH( NVL( Item.SAT_ProdID, '' ) ) > 3 ) THEN
         sSAT_ID := Item.SAT_ProdID ;         
      END IF ;
      nLineasLey := Item.numLinea ;
--      
         sStepPLSQL := 'LINE (' || Item.numLinea || ').' ;
         uLINFAC := uLINFAC || 'LINE'                                                || sSepCampo ;
         uLINFAC := uLINFAC || Item.numLinea                                         || sSepCampo ;   -- 02 Linea de Factura
         uLINFAC := uLINFAC || sSAT_ID                                               || sSepCampo ;   -- 03 Codigo SAT
         uLINFAC := uLINFAC || Item.descripcion                                      || sSepCampo ;   -- 04 Descripcion
         uLINFAC := uLINFAC || Item.noIdentificacion                                 || sSepCampo ;   -- 05 No Interno
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 06 Agente de Retencion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 07 Monto Impuesto Retenido
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 08 Monto Impuesto Retenido
         uLINFAC := uLINFAC || Item.cantidad                                         || sSepCampo ;   -- 09 Cantidad
         uLINFAC := uLINFAC || Item.unidad                                           || sSepCampo ;   -- 10 UdeM Interna
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 11 Cantidad UdeM Referenciada
         uLINFAC := uLINFAC || Item.SAT_UM_Conv                                      || sSepCampo ;   -- 12 UdeM SAT
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 13 Precio Unitario Referencia
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 14 Grados de Alcohol
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 15 Fecha de Elaboracion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 16 Fecha de Vencimiento
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 17 Monto de Descuento
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.valorUnitario , 2 )         || sSepCampo ;   -- 18 Precio Unitario
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.importe       , 2 )         || sSepCampo ;   -- 19 Monto de Cargo
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 20 Codigo de Impuesto Adicional
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 21 Precio Unitario en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 22 Codigo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 23 Descuento Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 24 Recargo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 25 Monto Item en otra Moneda
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.importe       , 2 )         || sSepCampo ;   -- 26 Total Amount
         uLINFAC := uLINFAC || '1'                                                   || sSepCampo ;   -- 27 Facturable
         uLINFAC := uLINFAC || '02'                                                  || sSepCampo ;   -- 28 Objeto de Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.importe       , 2 )         || sSepCampo ;   -- 29 Precio Neto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.importe       , 2 )         || sSepCampo ;   -- 30 Precio Bruto
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 31 Pedimiento
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 32 Predial      
--
         IF ( sAddenda = 'SI' ) THEN
            sStepPLSQL := 'C_MERC (' || Item.numLinea || ').' ;
            uCOMEXT := uCOMEXT || sSepLinea ;                 
            uCOMEXT := uCOMEXT || 'C_MERC'                                      || sSepCampo ;        
            uCOMEXT := uCOMEXT || Item.noIdentificacion                         || sSepCampo ;  -- 02 Num Identificacion
            uCOMEXT := uCOMEXT || Item.FraccionArancelaria                      || sSepCampo ;  -- 03 Fraccion Arancelaria  
            IF ( Item.Factor_Arancelario = 1 ) THEN
               uCOMEXT := uCOMEXT || Item.cantidad                              || sSepCampo ;  -- 04 Cantidad Aduana
            ELSE
               uCOMEXT := uCOMEXT || FN_NUM_TO_CHAR_CFDI( 
                    Item.cantidad / Item.Factor_Arancelario, 2 )                || sSepCampo ;  -- 04 Cantidad Aduana
            END IF ;
            uCOMEXT := uCOMEXT || '01'                                          || sSepCampo ;  -- 05 Unidad Aduana 
            uCOMEXT := uCOMEXT || FN_NUM_TO_CHAR_CFDI( 
              ROUND( Item.valorUnitario * nDoc_TipoCambio / nUSD_TipoCambio, 2 )
                                                                         , 2 )  || sSepCampo ;  -- 06 Valor Unidad Aduana USD
            uCOMEXT := uCOMEXT || FN_NUM_TO_CHAR_CFDI(       
              ROUND( Item.importe       * nDoc_TipoCambio / nUSD_TipoCambio, 2 )
                                                                         , 2 )  || sSepCampo ;  -- 07 Valor Total USD
         END IF ;
         sStepPLSQL := 'LINETAX IVA (' || Item.numLinea || ').' ;
         uLINFAC := uLINFAC || sSepLinea ;                 
         uLINFAC := uLINFAC || 'LINETAX'                                      || sSepCampo ;        
         uLINFAC := uLINFAC || '1'                                            || sSepCampo ;  -- 02 Numero de Impuesto
         uLINFAC := uLINFAC || '002'                                          || sSepCampo ;  -- 03 Tipo de Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.PDF_Valor_Subt, 2 )  || sSepCampo ;  -- 04 Base Imponible
         IF ( Item.RFD_Valor_IVA > 0 ) THEN
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.PDF_Valor_IVA      , 2 ) || sSepCampo ;  -- 05 Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.PDF_Tasa_IVA  / 100, 6 ) || sSepCampo ;  -- 06 Tasa
         ELSE
            uLINFAC := uLINFAC || '0.00'                                      || sSepCampo ;  -- 05 Impuesto
            uLINFAC := uLINFAC || '0.000000'                                  || sSepCampo ;  -- 06 Tasa
         END IF ;
         uLINFAC := uLINFAC || 'Tasa'                                         || sSepCampo ;  -- 07 Factor de Impuesto
         uLINFAC := uLINFAC || 'T'                                            || sSepCampo ;  -- 08 Calificador 
--
      IF ( Item.Retencion_IVA > 0 ) THEN
         nTasaRet := ROUND( Item.Retencion_IVA * 100 / Item.RFD_Valor_Subt, 0 ) ;
--         
         uLINFAC  := uLINFAC || sSepLinea ;                 
         sStepPLSQL := 'LINETAX IVA (' || Item.numLinea || ').' ;
         uLINFAC := uLINFAC || sSepLinea ;                 
         uLINFAC := uLINFAC || 'LINETAX'                                      || sSepCampo ;        
         uLINFAC := uLINFAC || '2'                                            || sSepCampo ;  -- 02 Numero de Impuesto
         uLINFAC := uLINFAC || '002'                                          || sSepCampo ;  -- 03 Tipo de Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.PDF_Valor_Subt, 2 )  || sSepCampo ;  -- 04 Base Imponible
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.Retencion_IVA , 2 )  || sSepCampo ;  -- 05 Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nTasaRet / 100     , 6 )  || sSepCampo ;  -- 06 Tasa
         uLINFAC := uLINFAC || 'Tasa'                                         || sSepCampo ;  -- 07 Factor de Impuesto
         uLINFAC := uLINFAC || 'R'                                            || sSepCampo ;  -- 08 Calificador          
      END IF ;      
--
-- Agregar Observacioneslas a Items
--
      IF ( Item.DatosAdicionales IS NOT NULL ) THEN
         sDetalleItem      := 'SI' ;
         sDatosAdicionales := Item.DatosAdicionales ;
      ELSE
         IF ( ( sCentroExpedicion != 'EXPO' ) AND ( LENGTH( Item.DatosAdicionales_EN ) > 2 ) ) THEN
            sDetalleItem      := 'SI' ;
            sDatosAdicionales := Item.DatosAdicionales_EN ; 
         END IF ;  
      END IF ;
      IF ( sDetalleItem = 'SI' ) THEN
         nLineas := nLineas + 1 ; 
         uLINFAC := uLINFAC || sSepLinea ;
         uLINFAC := uLINFAC || 'LINCLIE'                  || sSepCampo ;
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nLineas ) ) || sSepCampo ;
         uLINFAC := uLINFAC || sDatosAdicionales          || sSepCampo ;                   
      END IF ;
   END LOOP ;                                                                   -- Ciclo Datos de Cliente    
--
-- Agregar Incoterms
   IF ( ( LENGTH( TRIM( sIncoterms ) ) > 02 ) AND ( sAddenda = 'NO' ) ) THEN
      nLineas := nLineas + 1 ; 
      uLINFAC := uLINFAC || sSepLinea ;
      uLINFAC := uLINFAC || 'LINCLIE'       || sSepCampo ;
      uLINFAC := uLINFAC || nLineas         || sSepCampo ;
      uLINFAC := uLINFAC || sIncoterms      || sSepCampo ;
   END IF ; 
--      
-- Cabecera Cliente
--
      sCABCLIE := sCABCLIE || 'CABCLIE'               || sSepCampo ;
      sCABCLIE := sCABCLIE || sRecibe_Nombre          || sSepCampo ;
      sCABCLIE := sCABCLIE || sRemite_Calle           || sSepCampo ;
      sCABCLIE := sCABCLIE || sRemite_Colonia         || sSepCampo ;
      sCABCLIE := sCABCLIE || sRemite_Municipio       || sSepCampo ;
      sCABCLIE := sCABCLIE || ''                      || sSepCampo ;
      sCABCLIE := sCABCLIE || sRemite_Estado          || sSepCampo ;
      sCABCLIE := sCABCLIE || sRemite_Pais            || sSepCampo ;
      sCABCLIE := sCABCLIE || sRemite_codigoPostal    || sSepCampo ;
      sCABCLIE := sCABCLIE || sPedidoV3               || sSepCampo ;
      sCABCLIE := sCABCLIE || sSucursalNombre         || sSepCampo ;
      sCABCLIE := sCABCLIE || sPedidoSAP              || sSepCampo ;
      sCABCLIE := sCABCLIE || sFacturaSAP             || sSepCampo ;
      sCABCLIE := sCABCLIE || sTipo_Documento         || sSepCampo ;
      sCABCLIE := sCABCLIE || sCentroExpedicion       || sSepCampo ;
   -- BAT Servicios no Enviar Codigos de Clientes       
      IF ( sSociedad = 'MX15' ) THEN 
         sCABCLIE := sCABCLIE || '' || sSepCampo ;
         sCABCLIE := sCABCLIE || '' || sSepCampo ;
      ELSE
         sCABCLIE := sCABCLIE || sRecibe_Cliente      || sSepCampo ;
         sCABCLIE := sCABCLIE || sRemite_Cliente      || sSepCampo ;
      END IF ;   
      sCABCLIE := sCABCLIE || sLugarExpedicion        || sSepCampo ;
      IF ( nEnajenado > 0 ) THEN
         sCABCLIE := sCABCLIE || TRIM( TO_CHAR( nEnajenado ) )
                                                      || sSepCampo ;
      ELSE   
         sCABCLIE := sCABCLIE || ''                   || sSepCampo ;
      END IF ;   
      sCABCLIE := sCABCLIE || sLeyMenor               || sSepCampo ;
      sCABCLIE := sCABCLIE || sLeyPriv                || sSepCampo ;
      sCABCLIE := sCABCLIE || seMail                  || sSepCampo ;
      sCABCLIE := sCABCLIE || sSepLinea                            ;
--
      sCABCLIE := sCABCLIE || sCFDIREL                             ;
      sCABCLIE := sCABCLIE || 'PAYMET'                || sSepCampo ;              
      sCABCLIE := sCABCLIE || sMetodoDePago           || sSepCampo ;   
      sCABCLIE := sCABCLIE || uCABADD                              ;
--
      IF ( sMonedaDoc != 'MXN' ) THEN
         uIMPFAC := uIMPFAC || sSepLinea ;
         uIMPFAC := uIMPFAC || 'OTCUR'                                        || sSepCampo ;
         uIMPFAC := uIMPFAC || sMonedaDoc                                     || sSepCampo ;      -- 02 Codigo Moneda
         uIMPFAC := uIMPFAC || FN_NUM_TO_CHAR_CFDI( nDoc_TipoCambio, 4 )      || sSepCampo ;      -- 03 Tipo de Cambio
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 04 Total_Taxable_Amount
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 05 Total_Taxable_Amount_1
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 06 Total_Taxable_Amount_2
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 07 Total_Taxable_Amount_3
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 08 Exempt_Amount
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 09 Total_Tax_Amount
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 10 Total_Tax_Amount_1
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 11 Total_Tax_Amount_2
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 12 Total_Tax_Amount_3
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 13 Addition_Tax_Amount
         uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 14 Total_Amount
      END IF ;
--
      sReturn := sReturn || uHEADER  || sSepLinea ;
      sReturn := sReturn || sCABCLIE || sSepLinea ;
      sReturn := sReturn || uIMPFAC  || sSepLinea ;
--
   IF ( ( LENGTH( sReturn ) > 10 ) AND ( LENGTH( uLINFAC ) > 10 ) AND ( ABS( nTotal - nItems ) < 0.50 ) ) THEN
      sData := sReturn ;
      sData := CONCAT( sData, uLINFAC ) ;   
      sData := CONCAT( sData, uCOMEXT ) ;
      INSERT INTO CFDI_DOCUMENTOS_ENVIAR ( Nota_Venta, Informacion )
         VALUES ( strID, sData ) ;
      INSERT INTO T3.CFDI_Documentos ( Nota_Venta, Ctro, Fecha_Liberacion )
         VALUES ( strID, 'CTRL', SYSDATE ) ;                          
   ELSE         
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'GENERAR_OTROS', strID, 'Doc=>' || nTotal || ' vs Items=> ' || nItems ) ;   
   END IF ;      
   COMMIT ;
--   
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_GENERAR_OTROS' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'PROC_CFDI_GENERAR_OTROS', strID, sMsg ) ;
      COMMIT ;      
END ;
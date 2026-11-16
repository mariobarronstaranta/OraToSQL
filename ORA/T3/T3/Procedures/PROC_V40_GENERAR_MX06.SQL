create or replace PROCEDURE    "PROC_V40_GENERAR_MX06" 
  ( pFactura        IN Factura_General.FACTURA%TYPE,
    pAccnt_ID       IN VARCHAR2  DEFAULT NULL,
    pOutput         IN NUMBER    DEFAULT 0   ,
    pFechaDocto     IN VARCHAR2  DEFAULT NULL ) 
IS
   strID                VARCHAR2(0030) ;
   sMsg                 VARCHAR2(0500) ;   
   sCtro                VARCHAR2(0004) ;   
   sStepPLSQL           VARCHAR2(0060) ;
   sUsoCFDI             VARCHAR2(0004) ;
   sRegimen             VARCHAR2(0004) ;
   nHDP                 NUMBER(03)     ;
--   
   sReturn              VARCHAR2(4000) ;
--
   uHEADER              VARCHAR2(4000) ;
   uIMPFAC              VARCHAR2(4000) ;
   uLINFAC              CLOB           ;
   uCABADD              VARCHAR2(4000) ;
   sCFDIREL             VARCHAR2(4000) ;
   nCFDIREL             NUMBER(03)     ;   
   sREL_Facturas        CLOB           ;   
   nCFDI_CM             NUMBER(03)     ;   
   nTimbrados           NUMBER(04)     ;
   nTtl_CreditMemo      NUMBER(15,2)   ;
   nTtl_Assigned        NUMBER(15,2)   ;   
   dtFecha_Docto        DATE           ;
   sRefFactura          VARCHAR2(0030) ;   
   sSwitchEAN           VARCHAR2(0030) ;
--   
   nIMPFAC              NUMBER(3)      ;
   nImpSubtot_TASAIVA   NUMBER(22,2)   ;
   nImpSubtot_TASA00    NUMBER(22,2)   ;
   nValor_IEPS          NUMBER(22,2)   ; 
   nEnvio_Subt          NUMBER(22,2)   ; 
   nEnvio_IVA           NUMBER(22,2)   ;
   nDocto_IVA           NUMBER(22,2)   ;
   nAjusteIVA_DistFee   NUMBER(22,2)   ;
   nEnvio_TASA          NUMBER(05,2)   ;
   nCredito_Subt        NUMBER(22,2)   ; 
   nCredito_IVA         NUMBER(22,2)   ;
   nCredito_TASA        NUMBER(05,2)   ;
   nTotalAmt            NUMBER(15,2)   ;
   sCantidad_Vta        VARCHAR2(0030) ;
   sUnidad_Vta          VARCHAR2(0030) ;
   nFactor_PAQ          NUMBER(15,2)   ;
   nCantidad_PAQ        NUMBER(15,2)   ;
   nGramosNicotina      NUMBER(15,2)   ;
--
   sEnvio_ID_Code       VARCHAR2(0010) ;
   sEnvio_ID_UPC        VARCHAR2(0010) ;
   sEnvio_UM            VARCHAR2(0010) ;
   sEnvio_Descrip       VARCHAR2(0100) ;
   sEnvio_SAT_ID        VARCHAR2(0010) ;
   sEnvio_SAT_IDDet     VARCHAR2(0010) ;
   sEnvio_SAT_IDMay     VARCHAR2(0010) ;
   sEnvio_SAT_UM        VARCHAR2(0010) ;
   sCredito_ID_Code     VARCHAR2(0010) ;
   sCredito_ID_UPC      VARCHAR2(0010) ;
   sCredito_UM          VARCHAR2(0010) ;
   sCredito_Descrip     VARCHAR2(0100) ;
   sCredito_SAT_ID      VARCHAR2(0010) ;
   sCredito_SAT_UM      VARCHAR2(0010) ;
   sLista_Precio        VARCHAR2(0010) ;
   nTasa_LP             NUMBER(03)     ;
   nTasa_IEPS           NUMBER(03)     ;   
   dtFecha_Factura      DATE           ;
   sMaterial            VARCHAR2(0020) ;    
--   
--   
   sCABCLIE             VARCHAR2(4000) ;
   sLeyMenor            VARCHAR2(4000) ;
   sLeyPriv             VARCHAR2(4000) ;
   sLeyVype             VARCHAR2(4000) ;
   sSepLinea            VARCHAR2(0004) ;
   sSepCampo            VARCHAR2(0004) ;
   sFactura             VARCHAR2(0030) ;
   sRecibe_RFC          VARCHAR2(0030) ;
   sAdd_Migrar          VARCHAR2(0030) ;
   sAccnt_ID            VARCHAR2(0040) ;
   sAddenda             VARCHAR2(0002) ;
   nLineas              NUMBER(03)     ;
   nNum_Linea           NUMBER(06)     ;
   nNumLinea            NUMBER(06)     ;   
   nTotal               NUMBER(22,2)   ;
   nItems               NUMBER(22,2)   ;
   nEDICOM              NUMBER(22,2)   ;
   nLineaTax            NUMBER(06)     ;
   nCantPedimento       NUMBER(06)     ;
   sPedimentos          VARCHAR2(1000) ;
   nDescuento           NUMBER(22,2)   ;
   sData                CLOB           ;
   sFormaDePago         VARCHAR2(0060) ;
   sMetodoDePago        VARCHAR2(0060) ;
   sNumCtaPago          VARCHAR2(0060) ;
   dtFechaRollout       DATE           ;
   sPedido              VARCHAR2(0060) ;
   sNotaEnt             VARCHAR2(0060) ;
   sVendorNInt          VARCHAR2(0060) ;
   sCompradorGLN        VARCHAR2(0060) ;
   sLocalidadEmisor     VARCHAR2(0060) ;
   sLocalidadReceptor   VARCHAR2(0060) ;
   sOrdenCompra         VARCHAR2(0060) ;
   sSAT_ID              VARCHAR2(0030) ;
   sSAT_UM              VARCHAR2(0030) ;   
   sIdentificacion      VARCHAR2(0030) ;
   nItemValorUnitario   NUMBER(22,2)   ;
   nItemImporte         NUMBER(22,2)   ;
   nItemDescuento       NUMBER(22,2)   ;
   nDoc_Descuento       NUMBER(22,2)   ;
   nDoc_Valor_sin_IVA   NUMBER(22,2)   ;
   nDoc_Valor_con_IVA   NUMBER(22,2)   ;
   nDoc_Valor_IEPS      NUMBER(22,2)   ;
   nDoc_Valor_IVA       NUMBER(22,2)   ;
   nDoc_Total           NUMBER(22,2)   ;
   sConv_Paquete        VARCHAR2(030)  ;
   sTextoVELO           VARCHAR2(200)  ;
   sA_Header53          VARCHAR2(030)  ;
--
   CURSOR ScrDatos IS
       SELECT /*+Driving_Site(Cte) Parallel(Cte,20)*/           
--            NVL( AD.Venta     , 'NO' )                         AS Addenda_Venta      ,
--            NVL( AD.Devolucion, 'NO' )                         AS Addenda_Devol      ,
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'VENTA' ) AS Addenda_Venta      ,
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'DEVOL' ) AS Addenda_Devol      ,
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'MIGRAR' ) 
                                                                 AS Addenda_Migrar     ,
              RF.Tipo_Docto                                      AS Addenda_Tipo_Docto ,
              RF.Ctro                                            AS Ctro               ,
              CteX_Attrib_34                                     AS Fecha_Rollout      ,
--            NVL( AD.Revisar_Fecha, 'NO' )                      AS Addenda_Fases      ,
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'FASES' ) AS Addenda_Fases      ,
              RF.Fecha_Factura                                   AS Fecha_Documento    ,
              RF.Fecha_Factura                                   AS Fecha_Factura      ,
              SUBSTR( Cad_Ou_Num, 1, 2 )                         AS Cadena_Comercial   ,
              T3.FN_TRIM_CFDI( Cte.Tax_Exempt_Num )              AS RFC_Cliente        ,
--       
              RF.Factura                                         AS Factura            ,
              T3.FN_FOLIO_SORIANA( RF.Factura )                  AS Factura_Edicom     ,
--            Cte.Row_ID                                         AS Accnt_ID           ,
              Cte.VersionCFDI                                    AS versionCFDI        ,
              SUBSTR( T3.FN_FOLIO_SORIANA( RF.Factura ), 1, 
                  INSTR( T3.FN_FOLIO_SORIANA( RF.Factura ), '-' ) - 1 )                 
                                                                 AS Serie_Edicom       ,
              TRIM( 
                SUBSTR( T3.FN_FOLIO_SORIANA( RF.Factura ), 
                  INSTR( T3.FN_FOLIO_SORIANA( RF.Factura ), '-' ) + 1, 30 ) )           
                                                                 AS Folio_Edicom       ,
              T3.FN_FOLIO_SORIANA( RF.Referencia )               AS pedidoV3           ,
              RF.Pedido                                          AS pedidoSAP          ,
              RF.Entrega                                         AS facturaSAP         ,
              Comp.Rep_ID                                        AS repVentas          ,
              T3.FN_TRIM_CFDI( Cte.X_Route_Ref_1 )               AS sucursalNombre     ,
              SUBSTR( LP_Name, 1, 2 )                            AS Lista_Precio       ,
              TO_CHAR( SYSDATE, 'YYYYMMDD' )                 
                  || REPLACE( T3.FN_ADJUST_GMT( TO_CHAR( SYSDATE, 'HH24:MI:SS' ), DF.Dif_GMT ), ':', '' )       
                                                                 AS fecha_Reenvio      ,                 
              TO_CHAR( RF.Fecha_Factura, 'YYYYMMDD' )                 
                  || REPLACE( T3.FN_ADJUST_GMT( Comp.Hora_Factura, DF.Dif_GMT ), ':', '' )       
                                                                 AS fecha              ,                 
              DECODE( RF.Tipo_Docto, 'Z003', 'I'
                                   , 'Z005', 'I'
                                   , 'Z007', 'I'
                                   , 'Z014', 'I'
                                   , 'Z0FX', 'I'
                                   , 'Z020', 'I'
                                   , 'C003', 'I'
                                   , 'C005', 'I'
                                   , 'C007', 'I'
                                   , 'C014', 'I'
                                   , 'C0FX', 'I'
                                   , 'C020', 'I'
                                   , 'C030', 'I'
                                           , 'E' )              AS tipoDeComprobante  ,
              EAI_Owner.getConv( 'CFG Settings', 'Forma Pago' )              
                                                                 AS formaDePago        ,
              LPAD( NVL( Comp.Dias_Pago, 0), 3, '0' )            AS condicionesDePago  ,     
              'Descuento'                                        AS motivoDescuento    ,
              NVL( CFD.Descuento, 0 )                            AS Descuento          ,
              T3.FN_DIST_FEE_TAX_ADJ( RF.Factura )               AS ajusteEnvio        ,
              TRIM( TO_CHAR( CFD.Valor_Subtotal + CFD.Subtotal_noIVA       
                   + NVL( CFD.Descuento, 0 )
                   + DECODE( RF.Desglose_IVA, 'N', CFD.Valor_IVA, 0 )
                            , '999999999.99' ) )                 AS subTotal           ,
              TRIM( TO_CHAR( CFD.Valor_Subtotal + CFD.Valor_IVA + CFD.Subtotal_noIVA + NVL( T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ), 0 )
                            , '999999999.99' ) )                 AS total              ,
              T3.FN_DIST_FEE_TAX_ADJ( RF.Factura )               AS ajusteIVA_DistFee  ,               
              EAI_Owner.getConv( 'CFG Settings', 'Metodo Pago' )
                                                                 AS metodoDePago       ,                     
              DECODE( Cte.Pay_Type_CD, 'Efectivo', '',
                  NVL( CteX_X_EM_Field_18, 'No identificado' ) ) AS NumCtaPago         , 
              '1'                                                AS TipoCambio         ,
              'MXN'                                              AS Moneda             ,
--            
              Alm.Almacen_Lugar_Expide                           AS LugarExpedicion    ,   
              T3.FN_TRIM_CFDI( Soc.RFC             )             AS Emisor_RFC         ,
              T3.FN_TRIM_CFDI( Soc.Razon_Social_HH )             AS Emisor_Nombre      ,
              T3.FN_TRIM_CFDI( Soc.Calle           )             AS Emisor_Calle       , 
              T3.FN_TRIM_CFDI( Soc.Numero_Ext      )             AS Emisor_NoExterior  ,
              T3.FN_TRIM_CFDI( Soc.Numero_Int      )             AS Emisor_NoInterior  ,
              T3.FN_TRIM_CFDI( Soc.Colonia         )             AS Emisor_Colonia     ,
              T3.FN_TRIM_CFDI( Soc.Localidad       )             AS Emisor_Localidad   ,
              T3.FN_TRIM_CFDI( Soc.Municipio       )             AS Emisor_Municipio   ,
              T3.FN_TRIM_CFDI(              
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Soc.Estado ) )               AS Emisor_Estado      ,
              T3.FN_TRIM_CFDI( Soc.Pais          )               AS Emisor_Pais        ,
              T3.FN_TRIM_CFDI( Soc.Codigo_Postal )               AS Emisor_CodigoPostal,
--              
              T3.FN_TRIM_CFDI( Alm.Almacen_Calle      )          AS Expide_calle       , 
              T3.FN_TRIM_CFDI( Alm.Almacen_NoExterior )          AS Expide_noExterior  ,
              T3.FN_TRIM_CFDI( Alm.Almacen_NoInterior )          AS Expide_noInterior  ,
              T3.FN_TRIM_CFDI( Alm.Almacen_Colonia    )          AS Expide_colonia     ,
              T3.FN_TRIM_CFDI( Alm.Almacen_Municipio  )          AS Expide_municipio   ,
              T3.FN_TRIM_CFDI( Alm.Almacen_Estado     )          AS Expide_estado      ,
              T3.FN_TRIM_CFDI( Alm.Almacen_Pais       )          AS Expide_pais        ,
              T3.FN_TRIM_CFDI( 
                 LPAD( Alm.Almacen_codigoPostal, 5, '0' )  )     AS Expide_codigoPostal,
              EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal' )              
                                                                 AS RegimenFiscal      ,
--              
              Cte.RegimenFiscal                                  AS Regimen_Fiscal_Cte ,
              T3.FN_TRIM_CFDI( Cte.Tax_Exempt_Num )              AS Recibe_RFC         ,
              T3.FN_TRIM_CFDI( Cte.Name           )              AS Recibe_Nombre      ,
              T3.FN_TRIM_CFDI( Bill_Addr          )              AS Recibe_Calle       ,
              ''                                                 AS Recibe_NoExterior  ,
              ''                                                 AS Recibe_NoInterior  ,
              T3.FN_TRIM_CFDI( Bill_Addr_Line_2   )              AS Recibe_Colonia     ,
              T3.FN_TRIM_CFDI( Bill_City          )              AS Recibe_Municipio   ,
              T3.FN_TRIM_CFDI( 
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Bill_State  ) )              AS Recibe_Estado      ,
              T3.FN_TRIM_CFDI( Bill_Country       )              AS Recibe_Pais        , 
              T3.FN_TRIM_CFDI( 
                    LPAD( NVL( Bill_ZipCode, '99999' )
                                      , 5, '0' )  )              AS Recibe_codigoPostal,
--                    
              T3.FN_TRIM_CFDI( Ship_Addr          )              AS Remite_Calle       ,
              T3.FN_TRIM_CFDI( Ship_Addr_Line_2   )              AS Remite_Colonia     ,
              T3.FN_TRIM_CFDI( Ship_City          )              AS Remite_Municipio   ,
              T3.FN_TRIM_CFDI( 
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Ship_State ) )               AS Remite_Estado      ,
              T3.FN_TRIM_CFDI( Ship_Country       )              AS Remite_Pais        , 
              T3.FN_TRIM_CFDI( 
                    LPAD( NVL( Ship_ZipCode, '99999' )
                                      , 5, '0' )  )              AS Remite_codigoPostal,
--
              DECODE( RF.Tipo_Docto, 
                     'Z003', 'FACTURA',
                     'Z005', 'FACTURA',
                     'Z007', 'FACTURA',
                     'Z014', 'FACTURA',
                     'Z0FX', 'FACTURA',
                     'Z020', 'FACTURA',
                     'Z024', 'NOTA DE CREDITO',
                     'Z022', 'NOTA DE CREDITO',
                     'C003', 'FACTURA',
                     'C005', 'FACTURA',
                     'C007', 'FACTURA',
                     'C014', 'FACTURA',
                     'C0FX', 'FACTURA',
                     'C020', 'FACTURA',
                     'C030', 'FACTURA',
                     'C024', 'NOTA DE CREDITO',
                     'C022', 'NOTA DE CREDITO',
                     'NOTA DE CREDITO'
                     )                                           AS Tipo_Documento     ,
              Cte.Integration_ID                                 AS Recibe_Cliente     ,  
              Cte.Integration_ID                                 AS Remite_Cliente     ,              
              Alm.Almacen_Ctro                                   AS CentroExpedicion   ,
            --Cte.Pr_Con_ID                                      AS eMail              ,         -- Contacto Principal
              T3.FN_INVOICE_EMAIL( RF.Factura, Cte.Pr_Con_ID )   AS eMail              ,         -- Contacto Principal
--
              ''                                                 AS ConfirmacionPAC    ,
              DECODE( RF.Tipo_Docto, 'C003', Cte.UsoCFDI
                                   , 'C005', Cte.UsoCFDI
                   , NVL( UsoC.Uso_Devolucion, EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Comercial_NC' ) ) )
                                                                 AS UsoCFDI            ,
              ''                                                 AS ResidenciaFiscal   ,
              ''                                                 AS RegTributarioExt   ,
              ''                                                 AS TipoRelacion       ,              
--              
              TRIM( TO_CHAR( CFD.Valor_IVA + T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ), '9999999.99' ) )
                                                                                                  AS ImpuestosTrasladados,
              'IVA'                                                                               AS impuesto            , 
              CASE
                 WHEN ( CFD.Valor_Subtotal = 0 ) THEN '0'
                 ELSE
                    TRIM( TO_CHAR( ROUND( CFD.Valor_IVA * 100 / CFD.Valor_Subtotal, 0 ), '99' ) )
              END                                                                                 AS tasa                ,
              TRIM( TO_CHAR( ( CFD.Valor_IVA + T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ) )
                                                                            , '9999999999.99' ) ) AS importe_IVA         ,                                         
              TRIM( TO_CHAR( ( CFD.Valor_IVA + T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ) + ( CFD.Valor_IEPS * NVL( UsoC.Desglose_IEPS, 0 ) ) )
                                                                            , '9999999999.99' ) ) AS importe             ,
              TRIM( TO_CHAR( CFD.Valor_Subtotal                             , '9999999999.99' ) ) AS subtotal_TasaIVA    ,
              TRIM( TO_CHAR( CFD.Subtotal_noIVA                             , '9999999999.99' ) ) AS subtotal_Tasa00     ,
              CFD.Valor_Subtotal                                                                  AS impSubtot_TASAIVA   ,
              CFD.Subtotal_noIVA                                                                  AS impSubtot_TASA00    ,
              CFD.Subt_sin_IEPS * NVL( UsoC.Desglose_IEPS, 0 )                                    AS Valor_Subt_IEPS     ,        
              CFD.Valor_IEPS    * NVL( UsoC.Desglose_IEPS, 0 )                                    AS Valor_IEPS                            
          FROM T3.Registro_Fiscal     RF  ,
              (
                SELECT 
                       SUM( NVL( RFD.Valor_Subt, 0 ) + NVL( RFD.Envio_Subt, 0 ) + NVL( RFD.Credito_Subt, 0 ) )  AS Valor_Subt    ,
                       SUM( NVL( RFD.Valor_IVA , 0 ) + NVL( RFD.Envio_IVA , 0 ) + NVL( RFD.Credito_IVA , 0 ) )  AS Valor_IVA     ,
                       SUM( NVL( RFD.Bonif_Subt, 0 ) )                                                          AS Descuento     , 
                       SUM( DECODE( RF.Tipo_Venta, 'VD', NVL( RFD.Bonif_Subt, 0 ), 0 ) )                        AS Descuento_VD  ,
                       SUM( DECODE( Tax.Fecha_Registro, NULL, 0, RFD.Valor_Subt + NVL( RFD.Envio_Subt, 0 ) + NVL( RFD.Credito_Subt, 0 )
                                                                                                           ) )  AS Subtotal_noIVA,
                       SUM( NVL( RFD.Valor_Subt, 0 ) + NVL( RFD.Envio_Subt, 0 ) + NVL( RFD.Credito_Subt, 0 )
                          - DECODE( Tax.Fecha_Registro, NULL, 0, RFD.Valor_Subt + NVL( RFD.Envio_Subt, 0 ) + NVL( RFD.Credito_Subt, 0 ) ) 
                                                                                                              )  AS Valor_Subtotal,
                       SUM( DECODE( NVL( RFD.Valor_IEPS, 0 ), 0, 0, RFD.Valor_Subt - NVL( RFD.Valor_IEPS, 0 ))) AS Subt_sin_IEPS  ,  
                     SUM( NVL( RFD.Valor_IEPS, 0 ) )                                                            AS Valor_IEPS                          
                   FROM T3.Registro_Fiscal_Detalle RFD,
                        T3.Registro_Fiscal         RF ,
                        T3.SKU_TASA_CERO           Tax
                   WHERE RFD.Factura  = pFactura
                     AND RFD.Factura  = RF.Factura
                     AND RFD.Material = Tax.Material(+)              
              )                         CFD ,
               T3.RF_Complemento        Comp,
              (
                  SELECT 
--                       Cte.Row_ID                          AS Row_ID            , 
                         Cte.Cliente_SAP                     AS Ou_Num            , 
                         CteX.Email                          AS Pr_Con_ID         ,
                         Cte.Cliente_SAP                     AS Integration_ID    ,
                         NVL( Cte.RFC, 'XAXX010101000' )     AS Tax_Exempt_Num    ,
                         NVL( RS.Razon_Social, Cte.Nombre )  AS Name              ,
                         CteX.X_Route_Ref_1                  AS X_Route_Ref_1     ,
                         Cte.Metodo_pago                     AS Pay_Type_CD       ,
                         NVL( Reg.Regimen_Fiscal,
                      --NVL( CteX.Regimen_Fiscal,
                             EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal Cliente' ) ) 
                                                             AS RegimenFiscal      ,
                         NVL( CFD.Ver_CFDi,
                             EAI_Owner.getConv( 'CFG Settings', 'VersionCFDI' ) ) 
                                                             AS VersionCFDI       ,  
                          NVL( Uso.UsoCFDI,                                   
                             NVL( UsoC.Uso_Venta,
                             EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Comercial' ) ) )
                                                             AS UsoCFDI           ,
--
                         CteX.X_EM_Field_18                  AS CteX_X_EM_Field_18,
                         CteX.Attrib_34                      AS CteX_Attrib_34    ,
                         Cte.Lista_Precio                    AS LP_Name           ,
                         CteX.SAP_Cadena                     AS Cad_OU_NUM        ,
--
                         Cte.Codigo_Postal_2                 AS Ship_ZipCode      ,
                         Cte.Pais_2                          AS Ship_Country      ,
                         Cte.Estado_2                        AS Ship_State        ,
                         Cte.Ciudad_2                        AS Ship_City         ,
                         Cte.Direccion_2                     AS Ship_Addr         ,
                         Cte.Colonia_2                       AS Ship_Addr_Line_2  ,
--
                         NVL( CP.CP, Cte.Codigo_Postal_3 )  AS Bill_ZipCode      ,
                         Cte.Pais_3                         AS Bill_Country      ,
                         Cte.Estado_3                       AS Bill_State        ,
                         Cte.Ciudad_3                       AS Bill_City         ,
                         Cte.Direccion_3                    AS Bill_Addr         ,
                         Cte.Colonia_3                      AS Bill_Addr_Line_2  
                       --Cte.Fecha_Ini_Vig                  AS Fecha_Ini_Vig     ,
                       --Cte.Fecha_Fin_Vig                  AS Fecha_Fin_Vig     
                     FROM T3.Mov_Cliente           Cte ,
                          T3.TMD_Email             CteX,
                          T3.CFDI_USOCFDI_CLIENTE  UsoC,
                          ( SELECT RFC, MAX( Valor ) AS Regimen_Fiscal
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'RegimenFiscal' 
                                GROUP BY RFC ) Reg,
                          ( SELECT RFC, MAX( Valor ) AS Ver_CFDI
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'VersionCFDI'  
                                GROUP BY RFC ) CFD,
                          ( SELECT RFC, MAX( Valor ) AS UsoCFDI
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'UsoCFDI' 
                                GROUP BY RFC ) Uso,
                          ( SELECT RFC, MAX( Valor ) AS CP
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'CodigoPostal' 
                                GROUP BY RFC ) CP,
                          ( SELECT RFC, MAX( Valor ) AS Razon_Social
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'Nombre'
                                GROUP BY RFC ) RS
                    WHERE Cte.Cliente_SAP      = sAccnt_ID
                      AND Cte.Cliente_SAP      = CteX.Cliente_SAP(+) 
                      AND Cte.Cliente_SAP      = UsoC.Cliente_SAP(+)
                      AND Cte.RFC              = Reg.RFC(+)
                      AND Cte.RFC              = CFD.RFC(+)
                      AND Cte.RFC              = CP.RFC(+)
                      AND Cte.RFC              = Uso.RFC(+)
                      AND Cte.RFC              = RS.RFC(+)
              )                         Cte ,
               EAI.ZSDFE_Soc            Soc ,
--             T3.CFDI_Addenda          AD  ,
               T3.Tipo_Documento        TD  ,
               T3.Distribuidor_Fiscal   DF  ,
               T3.CFDI_USOCFDI_CLIENTE  UsoC,
               ( 
                   SELECT
                        CASE
                            WHEN ( Alm.Ctro = 'MX7A' ) THEN 'MXAA'
                            WHEN ( Alm.Ctro = 'MX7B' ) THEN 'MXAB'
                            WHEN ( Alm.Ctro = 'MX7D' ) THEN 'MXAC'
                            ELSE
                               Alm.Ctro                
                        END                                                AS Almacen_Ctro        ,                        
                        Alm.Municipio || ', ' || 
                            EAI_Owner.getConv( 'CFDI Estado', Alm.Estado ) AS Almacen_Lugar_Expide,    
                        T3.SeparaDireccion( Alm.Calle, 'Calle' )   
                                                                           AS Almacen_Calle       , 
                        Alm.Numero_Exterior                                AS Almacen_NoExterior  ,
                        ''                                                 AS Almacen_NoInterior  ,                                                      
                        T3.SeparaDireccion( Alm.Colonia, 'Col' )           AS Almacen_Colonia     ,
                        T3.FN_TRIM_CFDI( Alm.Municipio         )           AS Almacen_Municipio   ,
                        T3.FN_TRIM_CFDI(                        
                           EAI_Owner.getConv( 'CFDI Estado',
                                               Alm.Estado )    )           AS Almacen_Estado      ,
                        T3.FN_TRIM_CFDI( Alm.Pais              )           AS Almacen_Pais        , 
                        T3.FN_TRIM_CFDI( Alm.CODIGO_POSTAL     )           AS Almacen_codigoPostal             
                   FROM T3.Distribuidor_Fiscal Alm
                   WHERE Ctro LIKE 'MX%') Alm          
          WHERE RF.Factura           = pFactura
            AND RF.Factura           = Comp.Factura
          --AND RF.Fecha_Factura     BETWEEN Cte.Fecha_Ini_Vig and Cte.Fecha_Fin_Vig
            AND RF.Ctro              = DF.Ctro
            AND Cte.Ou_Num           = sAccnt_ID
            AND RF.Cliente_SAP       = UsoC.Cliente_SAP(+)
            AND Comp.Sociedad        = Soc.BUKRS
            AND Comp.Sociedad        = NVL( Soc.KUNNR, 'NULL' )
            AND RF.Ctro              = Alm.Almacen_Ctro 
            AND RF.Tipo_Docto        = TD.Tipo_Documento
            AND RF.Tipo_Docto       IN ( 'C003', 'C004', 'C005', 'C006', 'C0FX', 'C019', 'C024', 'C025', 'C030', 'C031' ) 
            AND TD.CFD               = 'NO'           ;                         -- CFDI            
--
   CURSOR ScrDetalle IS
                    SELECT
                                  TRIM( TO_CHAR( RFD.Num_Linea   , '999999999'     ) ) AS numLinea           ,
                                  TRIM( TO_CHAR( RFD.Cantidad_Vta, '999999999'     ) ) AS cantidad           ,  
                                  DECODE( RF.Tipo_Docto, 'Z024', 'DCTO',
                                                         'Z022', 'DCTO',
                                                         'Z019', 'UA'  ,
                                                         'Z0FX', 'UA'  ,
                                                         'C025', 'DCTO',
                                                         'C024', 'DCTO',
                                                         'C022', 'DCTO',
                                                         'C019', 'DCTO',
                                                         'C0FX', 'UA'  ,
                                      Prod.Unidad_Med_Vta  )                           AS unidad             ,
--                                RFD.Material                                         AS noIdentificacion   ,    
                                  T3.FN_SAP_SKU( RFD.Material )                        AS noIdentificacion   , 
                                  TRIM( NVL( Prod.Codigo_Barras_Pres_2, '' ) )         AS codigoBarras       ,
                                  T3.FN_CFDI_SKU_NAME( Prod.Nombre_Material )          AS descripcion        ,
                                  RFD.Cantidad_Vta                                     AS Cantidad_Vta       ,
                                  NVL( Prod.Cig_x_CLL, 0 )                             AS Cig_x_CLL          ,
                                  NVL( Prod.Cig_x_PAQ, 0 )                             AS Cig_x_PAQ          ,
                                  INSTR( UPPER( Prod.Nombre_Material ) , 'VELO' )      AS Is_VELO            ,
                                  NVL( Prod.Nicotina, 0 )                              AS mg_Pieza           ,
                                  NVL( Prod.Nicotina, 0 ) * NVL( Prod.Cig_x_CLL, 0 )   AS Grs_Nicotina       ,
--                                  
--                                TRIM( TO_CHAR( RFD.Precio_Unit , '999999999.99'  ) ) AS valorUnitario      ,
--                                TRIM( TO_CHAR( RFD.Precio_Unit
--                                             * RFD.Cantidad_Vta, '999999999.99'  ) ) AS importe            ,
--
--
                                  DECODE( RF.Tipo_Venta, 'VD',
                                     TRIM( TO_CHAR( ROUND( ( RFD.Valor_Subt + NVL( RFD.Bonif_Subt, 0 ) )
                                               / RFD.Cantidad_Vta, 2 )
                                                               , '999999999.99'  ) ),
                                     TRIM( TO_CHAR( RFD.Precio_Unit , '999999999.99' ) )
                                                                                     ) AS valorUnitario      ,
--                                                                                     
                                  DECODE( RF.Tipo_Venta, 'VD',
                                     TRIM( TO_CHAR( ( RFD.Valor_Subt + NVL( RFD.Bonif_Subt, 0 ) ), '999999999.99'  ) ),                                                                                     
                                     TRIM( TO_CHAR( RFD.Precio_Unit
                                               * RFD.Cantidad_Vta, '999999999.99'  ) ) )
                                                                                       AS importeAnterior    ,
                                  DECODE( RF.Tipo_Venta, 'VD',
                                     TRIM( TO_CHAR( ( RFD.Valor_Subt + NVL( RFD.Bonif_Subt, 0 ) ), '999999999.99'  ) ),

                                     TRIM( TO_CHAR( DECODE( NVL( RFD.Bonif_Subt, 0), 0,
                                                               ( RFD.Valor_Subt  + NVL( RFD.Bonif_Subt, 0 ) ), 
                                                                 RFD.Precio_Unit * RFD.Cantidad_Vta ), 
                                           '999999999.99'  ) ) ) 
                                                                                       AS importe            ,                                                                                       
--
                                  TRIM( TO_CHAR( NVL( RFD.Bonif_Subt, 0 ), '999999999.99' ) )
                                                                                       AS Descuento          ,                                                                                     
--                                               
                                  NVL( RFD.Valor_Subt, 0 )                             AS RFD_Valor_Subt     ,             
                                  NVL( RFD.Valor_IVA , 0 )                             AS RFD_Valor_IVA      ,
                                  TRIM( TO_CHAR( 
                                      ROUND( RFD.Valor_IVA * 100 / RFD.Valor_Subt, 0 ), 
                                      '99.99' ) )                                      AS RFD_Tasa_IVA       ,
                                  TRIM( TO_CHAR( NVL( RFD.Valor_Subt, 0 ),
                                                                   '999999999.99'  ) ) AS PDF_Valor_Subt     ,
                                  TRIM( TO_CHAR( NVL( RFD.Valor_IVA , 0 ),
                                                                   '999999999.99'  ) ) AS PDF_Valor_IVA      ,
                                  TRIM( TO_CHAR( ROUND( RFD.Valor_IVA * 100 / RFD.Valor_Subt, 2 ),             
                                                                             '99'  ) ) AS PDF_TASA_IVA       ,
                                  NVL( RFD.Envio_Subt  , 0 )                           AS Envio_Subt         ,
                                  NVL( RFD.Envio_IVA   , 0 )                           AS Envio_IVA          ,
                                  NVL( RFD.Credito_Subt, 0 )                           AS Credito_Subt       ,
                                  NVL( RFD.Credito_IVA , 0 )                           AS Credito_IVA        ,
                                  NVL( UsoC.Desglose_IEPS, 0 ) * ( 
                                  NVL( RFD.Valor_Subt, 0 ) - NVL( RFD.Valor_IEPS, 0 )) AS Subt_sin_IEPS      ,                                   
                                  NVL( RFD.Valor_IEPS, 0 ) * NVL( UsoC.Desglose_IEPS, 0 )
                                                                                       AS Valor_IEPS                                  
                     FROM T3.Registro_Fiscal         RF  ,
                          T3.Registro_Fiscal_Detalle RFD ,
                          T3.CFDI_USOCFDI_CLIENTE    UsoC,
--                        T3.Material                Mat ,
--                        T3.Material_Hist           MatH,
                          T3.Material                Prod
                     WHERE RF.Factura   = pFactura 
                       AND RF.Factura   = RFD.Factura
                       AND RF.Cliente_SAP = UsoC.Cliente_SAP(+)
--                     AND RFD.Material = Mat.Material
--                     AND RFD.Material = MatH.Material
--                     AND RF.Fecha_Factura BETWEEN MatH.Fecha_Ini_Vig AND MatH.Fecha_Fin_Vig
                       AND RFD.Material = Prod.Material 
                     ORDER BY RFD.Num_Linea ;
--
   CURSOR ScrHeadAddenda IS
       SELECT 
              '7504015884004'                    AS GLN_BAT          ,
              T3.FN_TRIM_CFDI( 
                   CteX.X_EM_Field_5 )           AS Sucursal_EDI     ,
              T3.FN_TRIM_CFDI( 
                   CteX.X_Route_Ref_1 )          AS SucursalName     , 
              T3.FN_TRIM_CFDI( CFD.Pedido  )     AS Ref_Pedido       ,
              T3.FN_TRIM_CFDI( CFD.Entrada )     AS Ref_Entrada      ,
--            CFD.Int_2                          AS Ref_Tienda       ,
--            TRIM( TO_CHAR( CFD.Int_2 ) )       AS Ref_Sucursal     ,
              T3.FN_TRIM_CFDI( 
                   CteX.X_EM_Field_5 )           AS Ref_Tienda       ,
              T3.FN_TRIM_CFDI( 
                   CteX.X_EM_Field_5 )           AS Ref_Sucursal     ,

--              
              'CABADD'                           AS Label            ,
              'OR'                               AS Funcion          ,
              ''                                 AS Doc_Reemplazo    ,
              T3.FN_TRIM_CFDI( CFD.Pedido  )     AS Pedido           ,
              TO_CHAR( RF.Fecha_Factura, 'DDMMYYYY' )   
                || REPLACE( Comp.Hora_Factura, ':', '' )
                                                 AS FePedido         ,
              TRIM( CFD.Entrada )                AS NotaEnt          ,
              TO_CHAR( RF.Fecha_Factura, 'DDMMYYYY' )   
                                                 AS FeNotaEnt        ,
--              
              '7504015884004'                    AS VendedorGLN      ,
              NVL( Addenda.Num_Proveedor, '' )   AS VendorNInt       , 
              ''                                 AS VendorIEPS       ,
              NVL( Addenda.GLN_Comprador, '' )   AS CompradorGLN     ,
              ''                                 AS CompradorConti   ,
--              
              ''                                 AS CompradorNRef    ,
--            TRIM( DECODE( CFD.Int_2, NULL, CteX.X_EM_Field_5,
--                   TO_CHAR( CFD.Int_2 ) ) )    AS ReceptorGLN      ,
              CteX.X_EM_Field_5                  AS ReceptorGLN      ,
              T3.FN_TRIM_CFDI( 
              CteX.X_Route_Ref_1 )               AS ReceptorNombre   ,
              T3.FN_TRIM_CFDI( 
                    Cte.Direccion_1     )        AS ReceptorCalle    ,
              T3.FN_TRIM_CFDI( 
                    Cte.Colonia_1   )            AS ReceptorColonia  ,
--              
              ''                                 AS ReceptorLocal    ,
              T3.FN_TRIM_CFDI(
                 Cte.Ciudad_1       )            AS ReceptorMunicip  ,
--            T3.FN_TRIM_CFDI(
--               Addr.State       )              AS ReceptorEstado   ,
              T3.FN_TRIM_CFDI(
                 EAI_Owner.getConv( 'CFDI Estado',
                 Cte.Estado_1        ) )           AS ReceptorEstado   ,
              T3.FN_TRIM_CFDI(
                 Cte.Pais_1        )               AS ReceptorPais     , 
              T3.FN_TRIM_CFDI(  
                LPAD( Cte.Codigo_Postal_1, 5, '0' ) )   AS ReceptorCP       ,
              'MXN'                              AS MonedaPrecio     ,
--              
              '1.00'                             AS TCambioMPR       ,
              'MXN'                              AS MonedaPago       ,
              '1.00'                             AS TCambioMPY       ,
              'FE'                               AS RefPago          ,
              'BT'                               AS CondPago         ,
              NVL( Cte.Dias_CDTO, '0' )          AS DPago            ,
              ''                                 AS NCheque          ,
--              
--            RF.Valor_Subtotal                  AS TotNeto          ,
              TRIM( TO_CHAR( 
                 RF.Valor_Subtotal
                 , '999999999.99' ) )            AS TotNeto          ,
              ''                                 AS CPredial         ,
              REPLACE(
              REPLACE(
              REPLACE(
              PR_NUM_A_LETRAS.DinTex( RF.Valor_Subtotal + RF.Valor_IVA ) , 'M.N.', 'M. N.' )
                            , '(', '' )
                            , ')', '' )
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
              T3.FN_FOLIO_SORIANA( RF.Factura )  AS Remision         ,
              ''                                 AS DestinoBM        ,
              ''                                 AS CorreoProveedor  ,
              'PD'                               AS TipoPedido       ,
              ''                                 AS ComplementoCE       
          FROM T3.Cliente             Cte ,
               T3.TMD_Email           CteX,
             --T3.Registro_Fiscal     RF  ,
               ( 
                 SELECT RF.Factura                         AS Factura       ,
                        RF.Fecha_Factura                   AS Fecha_Factura ,
                        SUM( NVL( RFD.Valor_Subt  , 0 )    +
                             NVL( RFD.Envio_Subt  , 0 )    +
                             NVL( RFD.Credito_Subt, 0 ) )  AS Valor_Subtotal,
                        SUM( NVL( RFD.Valor_IVA   , 0 )    +
                             NVL( RFD.Envio_IVA   , 0 )    +
                             NVL( RFD.Credito_IVA , 0 ) )  AS Valor_IVA
                   FROM T3.Registro_Fiscal         RF ,
                        T3.Registro_Fiscal_Detalle RFD
                   WHERE RF.Factura = sFactura 
                     AND RF.Factura = RFD.Factura
                   GROUP BY RF.Factura, RF.Fecha_Factura
               )                      RF  ,             
               T3.RF_Complemento      Comp,
               EAI.IFC_Folios_FE      CFD ,
               T3.CFDI_Addenda        Addenda
          WHERE Cte.Cliente_SAP     = sAccnt_ID
            AND Cte.Cliente_SAP     = CteX.Cliente_SAP(+)
            AND Cte.RFC             = Addenda.RFC
            AND RF.Factura          = sFactura 
            AND RF.Factura          = Comp.Factura
            AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig and Cte.Fecha_Fin_Vig
            AND RF.Factura          = CFD.Var_1(+);
--
   CURSOR ScrItemAddenda IS
       SELECT  
              'LINADD'                           AS Label            ,
              RFD.Num_Linea                      AS NumLin           ,
--            RFD.Material                       AS RefCliente       ,
              T3.FN_SAP_SKU( RFD.Material )      AS RefCliente       ,
              Prod.Codigo_Barras_Pres_2          AS RefProvee        ,
              ''                                 AS RefSerieArt      ,
              'ES'                               AS IdiomaDesc       ,
              RFD.Cantidad_Vta                   AS Cantidad_Vta     ,
              RFD.Unidad_Med_Vta                 AS Unidad_Med_Vta   ,
              '1'                                AS CantConsum       ,
--              
              ''                                 AS CantFree         ,
              ''                                 AS CantComer        ,
--            ''                                 AS NOrdenC          ,
              sOrdenCompra                       AS NOrdenC          ,
              'SRV'                              AS CalifIdentity    ,
              ''                                 AS SerieContenedor  ,
              ''                                 AS NumPaq           ,
--            'CS'                               AS TipPaq           , 
              'PCE'                              AS TipPaq           , 
              ''                                 AS DescripPaq       ,
--              
              ''                                 AS PaqMetodoPago    ,
--            NVL( RFD.Valor_Subt, 0 ) -
--            DECODE( RF.Tipo_Venta, 'VD', 0, 
--               NVL( RFD.Bonif_Subt, 0 ) )      AS MontoBruLin      ,
--            NVL( RFD.Precio_Unit, 0 )          AS PrecioBruto      ,
              TRIM( TO_CHAR( 
              NVL( RFD.Valor_Subt, 0 ) -
              DECODE( RF.Tipo_Venta, 'VD', 0, 
                 NVL( RFD.Bonif_Subt, 0 ) )      
                 , '999999999.99' ) )
                                                 AS MontoBruLin      ,
              TRIM( TO_CHAR( 
              NVL( RFD.Precio_Unit, 0 )          
                 , '999999999.99' ) )
                                                 AS PrecioBruto      ,
              TRIM( TO_CHAR( 
              NVL( RFD.Precio_Unit * nFactor_PAQ, 0 )          
                 , '999999999.99' ) )
                                                 AS PrecioBrutoPAQ   ,
--            TO_CHAR( RF.Fecha_Factura,
--              'YYYYMMDD' )                     AS FechaEntrega     ,
              ''                                 AS FechaEntrega     ,
              ''                                 AS CRTienda         ,
              ''                                 AS Tienda           ,
              ''                                 AS FacturaInterna   ,
              ''                                 AS LineaInterna     ,
              ''                                 AS PlantaReceptora  ,
              ''                                 AS NRecipiente      ,
              ''                                 AS Release          ,
              ''                                 AS Remision         ,
--            
              RFD.Valor_Subt + RFD.Valor_IVA     AS Linea_con_IVA    ,
              ROUND( ( RFD.Valor_Subt + RFD.Valor_IVA )
                    / RFD.Cantidad_Vta, 2 )      AS Precio_con_IVA             

          FROM T3.Registro_Fiscal         RF  ,
               T3.Registro_Fiscal_Detalle RFD ,
               T3.Material                Prod
          WHERE RF.Factura    = sFactura
            AND RF.Factura    = RFD.Factura
            AND RFD.Num_Linea = nNumLinea
            AND RFD.Material  = Prod.Material;
--               
--
   CURSOR ScrPedimento IS
      SELECT SAT.Aduana_Numero, SAT.Pedimento,
             DECODE( SAT.Fecha_Pedimento, NULL, '',
                      TO_CHAR( SAT.Fecha_Pedimento, 'DDMMYYYY' ) ) AS FecPedimento         
         FROM T3.CFDI_PEDIMENTO_SKU  SAT
         WHERE sMaterial       = SAT.Material
           AND dtFecha_Factura BETWEEN SAT.Fecha_Inicio AND SAT.Fecha_Final ;   
--                      
   CURSOR ScrReenvio IS
      SELECT Folio_Fiscal, Fecha_Factura
         FROM T3.CFDI_Reproceso 
         WHERE Nota_Venta = sFactura
         ORDER BY Fecha DESC ;  
--
   CURSOR ScrTextoAdicional IS
       SELECT 1000 + Linea AS Linea, Texto
          FROM T3.CFDI_TEXTO_ADICIONAL
          WHERE Nota_Venta = sFactura
          ORDER BY Created, Linea ;         
--
   CURSOR ScrAllocation IS
       SELECT Cobza.Fecha_Asignacion as Created, Cobza.Importe AS Paid_Amt, Cobza.Fecha_Factura AS Invc_dt, 
       --Inv.Vendr_Invoice_Num, 
              CASE
                  WHEN ( WA.Fecha_Liberacion IS NULL ) AND ( CFD.Fecha_Liberacion IS NOT NULL ) THEN CFD.Nota_Venta
                  WHEN ( WA.Fecha_Liberacion IS NOT NULL )                                      THEN WA.Nota_Venta
                  ELSE
                     Cobza.Referencia
              END                         AS Doc_Num,
              CASE
                  WHEN ( WA.Fecha_Liberacion IS NULL ) AND ( CFD.Fecha_Liberacion IS NOT NULL ) THEN 'Otro'
                  WHEN ( WA.Fecha_Liberacion IS NOT NULL )                                      THEN 'Nota de Venta'
                  ELSE
                     'Debit Note'
              END                         AS Sub_Type_CD,
              CASE
                  WHEN ( WA.Fecha_Liberacion IS NULL ) AND ( CFD.Fecha_Liberacion IS NOT NULL ) THEN CFD.Folio_Fiscal
                  WHEN ( WA.Fecha_Liberacion IS NOT NULL )                                      THEN WA.Folio_Fiscal
                  ELSE
                     Cobza.UUID_VENTA
              END                         AS Folio_Fiscal
       FROM T3.CFDI_Cobranza           Cobza,
            T3.CFDI_Documentos         CFD ,
            T3.CFDI_Documentos         WA
       WHERE Cobza.Nota_Credito    = pFactura
         AND Cobza.Nota_Venta      = CFD.Nota_Venta(+)
         AND Cobza.Nota_Venta      = WA.Nota_Venta(+) ;
BEGIN 
   strID      := pFactura ;
   sStepPLSQL := 'Inicio' ;
   IF ( pAccnt_ID IS NULL ) THEN
      SELECT Cte.Cliente_SAP  INTO sAccnt_ID
         FROM T3.Registro_Fiscal   RF ,
              T3.Cliente           Cte
         WHERE RF.Factura       = pFactura
           AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig and Cte.Fecha_Fin_Vig
           AND RF.Cliente_SAP    = Cte.Cliente_SAP ;
   ELSE
       sAccnt_ID  := pAccnt_ID ;   
   END IF ;   
--   
   uHEADER       := '' ;
   uIMPFAC       := '' ;
   uLINFAC       := '' ;
   uCABADD       := '' ;
--
   sReturn       := '' ; 
   sCABCLIE      := '' ;
   sSepLinea     := CHR(13) || CHR(10) ;
   sSepCampo     := '|'  ;
   sAddenda      := 'NO' ;
   nTotal        := 0000 ;
   nItems        := 0000 ;
   nEDICOM       := 0000 ;
   nEnvio_Subt   := 0000 ;
   nEnvio_IVA    := 0000 ;
   nDocto_IVA    := 0000 ;
   nCredito_Subt := 0000 ;
   nCredito_IVA  := 0000 ;
   nGramosNicotina := 00 ;

   sLeyVype   := 'Le recordamos que la venta de vaporizadores y cartuchos de líquido vaporizable es exclusiva para mayores de edad. En caso de duda, solicite identificación oficial. ' ||
                 'Ayúdenos a que los menores de edad no tengan acceso a este tipo de productos. ' ;   
   sLeyMenor  := 'Le recordamos que las leyes prohíben y sancionan la venta de cigarros a menores de 18 años de edad '  ||
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
--
-- Document Header
--   
   IF ( T3.CHECK_VYPE_DOC( pFactura ) > 0 ) THEN
      sLeyMenor := sLeyVype ;
   END IF ;
   sStepPLSQL := 'Before ScrDatos' ;
   FOR Doc IN ScrDatos LOOP
      sFactura           := Doc.Factura           ;
      sRecibe_RFC        := Doc.Recibe_RFC        ;    
      sAdd_Migrar        := Doc.Addenda_Migrar    ;
--    sAccnt_ID          := Doc.Accnt_ID          ;
      sCtro              := Doc.Ctro              ;
      nTotal             := Doc.total             ;
      nImpSubtot_TASAIVA := Doc.impSubtot_TASAIVA ;
      nImpSubtot_TASA00  := Doc.impSubtot_TASA00  ; 
      sLista_Precio      := Doc.Lista_Precio      ;
      nAjusteIVA_DistFee := Doc.ajusteIVA_DistFee ;
      dtFecha_Factura    := Doc.Fecha_Factura     ;
      sLista_Precio      := '10'                  ;      
      SELECT MAX( NVL( Porc_IVA, 0 ) )  INTO nTasa_LP
         FROM T3.Conv_Lista_Grupo_Precio
         WHERE Lista_Precio = sLista_Precio ;
--
      SELECT EAI_Owner.getConv( 'SwitchEAN', sRecibe_RFC ) AS SwitchEAN
           INTO sSwitchEAN
          FROM DUAL ;
      IF ( sSwitchEAN = sRecibe_RFC ) THEN
          sSwitchEAN := 'NO' ;
      ELSE
         IF ( UPPER( sSwitchEAN ) != 'NO' ) THEN 
            sSwitchEAN := 'EAN' ;
         ELSE
            sSwitchEAN := 'NO'  ;
         END IF ;
      END IF ;
-- Admon de Addenda
      IF ( ( Doc.tipoDeComprobante = 'I' ) AND ( Doc.Addenda_Venta = 'SI' ) ) THEN
         sAddenda := 'SI' ;
      END IF ;
      IF ( ( Doc.tipoDeComprobante = 'E' ) AND ( Doc.Addenda_Devol = 'SI' ) ) THEN
         sAddenda := 'SI' ;
      END IF ;      
      IF ( ( sAddenda = 'SI' ) AND ( Doc.Addenda_Fases = 'SI' ) ) THEN
            IF ( INSTR( Doc.Fecha_Rollout, '/' ) > 0 ) THEN
               dtFechaRollout := TO_DATE( Doc.Fecha_Rollout, 'DD/MM/YYYY' ) ;
               IF ( Doc.Fecha_Documento >= dtFechaRollout ) THEN
                  sAddenda := 'SI' ;
               ELSE
                  sAddenda := 'NO' ;               
               END IF ;   
            ELSE
               sAddenda := 'NO' ;               
            END IF ;
      END IF ;      
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
      sREL_Facturas   := ''  ;
      nCFDI_CM        := 500 ;
      IF ( ( Doc.tipoDeComprobante = 'E' ) ) THEN
         sREL_Facturas   := ''     ;
         nCFDI_CM        := 500    ;
         nTtl_CreditMemo := nTotal ;
         nTtl_Assigned   := 00     ;   
         IF ( Doc.Recibe_RFC != 'XAXX010101000' ) THEN
            sStepPLSQL     := 'ScrCreditMemo'   ;
            FOR CMA IN ScrAllocation LOOP
               nCFDI_CM      := nCFDI_CM + 1 ;
               dtFecha_Docto := CMA.Invc_dt  ;
               sRefFactura   := CMA.Doc_Num  ;
               IF ( LENGTH( NVL( CMA.Folio_Fiscal, ' ' ) ) > 20 ) THEN
                  sCFDIREL := sCFDIREL || 'BILLREF'        || sSepCampo ;
                  sCFDIREL := sCFDIREL || CMA.Folio_Fiscal || sSepCampo ;          -- 02 Folio UUID
                  sCFDIREL := sCFDIREL || ''               || sSepCampo ;          -- 03 Tax ID
                  sCFDIREL := sCFDIREL || ''               || sSepCampo ;          -- 04 Fecha Documento
                  sCFDIREL := sCFDIREL || '01'             || sSepCampo ;          -- 05 Clave de Relacion
                  sCFDIREL := sCFDIREL || ''               || sSepCampo ;          -- 06 Motivo Modificacion
                  sCFDIREL := sCFDIREL || sSepLinea ;         
                  nTimbrados    := nTimbrados + 1 ;
                  nTtl_Assigned := nTtl_Assigned + CMA.Paid_Amt ;
               ELSE
                  IF ( CMA.Sub_Type_CD != 'Nota de Venta' ) THEN
                     nTtl_Assigned := nTtl_Assigned + CMA.Paid_Amt ;
                  END IF ;   
               END IF ;    
               sREL_Facturas := sREL_Facturas || sSepLinea ;
               sREL_Facturas := sREL_Facturas || 'LINCLIE'                   || sSepCampo ;
               sREL_Facturas := sREL_Facturas || TRIM( TO_CHAR( nCFDI_CM ) ) || sSepCampo ;
               sREL_Facturas := sREL_Facturas || 'Abono a documento ' || CMA.Doc_Num || ' del ' || TO_CHAR( dtFecha_Docto, 'DD/MM/YYYY' ) || 
                          ' por ' || TRIM ( TO_CHAR( CMA.Paid_Amt, '999,999,999.99' ) )  || sSepCampo ;
            END LOOP ;
            IF ( TRUNC( Doc.Fecha_Factura ) != TRUNC( SYSDATE ) ) THEN
               sREL_Facturas := sREL_Facturas || sSepLinea ;
               sREL_Facturas := sREL_Facturas || 'LINCLIE'                       || sSepCampo ;
               sREL_Facturas := sREL_Facturas || TRIM( TO_CHAR( nCFDI_CM + 1 ) ) || sSepCampo ;
               sREL_Facturas := sREL_Facturas || 'Fecha de documento interno ' || TO_CHAR( Doc.Fecha_Factura, 'DD/MM/YYYY' ) || sSepCampo ;
            END IF ;   
            IF ( ABS( nTtl_CreditMemo - nTtl_Assigned ) > 5.03 ) THEN
                INSERT INTO T3.CFDI_LIBERA_NOTA_CREDITO ( Factura, Fecha, Pendiente )
                   VALUES ( sFactura, SYSDATE,  nTtl_CreditMemo - nTtl_Assigned ) ;     
                RETURN ;            
            END IF ;
         END IF ;      -- Credit Memo NO Generico
--         
         UPDATE T3.CFDI_Historia_Docto_PAC SET Fecha_Factura = Fecha_Factura + 0
            WHERE Nota_Venta = sFactura ;
         nHDP := SQL%ROWCOUNT ;
         IF ( nHDP = 0 ) THEN         
            INSERT INTO T3.CFDI_Historia_Docto_PAC      
               ( Nota_Venta, Nota_Venta_CFDI, Ctro, Fecha_Factura )
            SELECT Factura, Factura, Ctro, Fecha_Factura
               FROM T3.Registro_Fiscal
               WHERE Factura = sFactura ;
         END IF ;               
         UPDATE T3.Registro_Fiscal SET Fecha_Factura = TRUNC( SYSDATE - 1 ) 
             WHERE Factura = sFactura
               AND Factura LIKE 'DESC%' 
               AND Fecha_Factura = TRUNC( SYSDATE ) ;
      END IF ;      
--
-- Addendas con 3.3
      IF ( sAddenda = 'SI' ) AND ( sAdd_Migrar = 'NO' ) THEN
         PROC_VSF_GENERAR_MX06( sFactura, sAccnt_ID ) ;
         COMMIT ;
         RETURN ;
      END IF ;
--
--------------------------------------------------------------------------------------------------------------------
-- Begin: Item Segment
--
      nDoc_Descuento       := 0 ;
      nDoc_Valor_sin_IVA   := 0 ;
      nDoc_Valor_con_IVA   := 0 ;
      nDoc_Valor_IEPS      := 0 ;
      nDoc_Valor_IVA       := 0 ;
      nLineas              := 0 ;
      nNum_Linea           := 0 ;
      sStepPLSQL := 'Before ScrDetalle' ;
      FOR Item IN ScrDetalle LOOP
         nNumLinea  := Item.numLinea ;
         nNum_Linea := nNum_Linea + 1 ;
         nLineas    := nLineas    + 1 ; 
         nItems     := nItems + Item.RFD_Valor_Subt + Item.RFD_Valor_IVA ;
         IF ( NVL( pOutput, 0 ) > 10 ) THEN
            DBMS_Output.Put_Line( Item.numLinea || ' - ' || Item.descripcion ) ;
         END IF ;
         sStepPLSQL := 'Item (' || Item.numLinea || ').' ;
         IF ( nLineas = 1 ) THEN
            uLINFAC := '' ;
         ELSE
            uLINFAC := uLINFAC || sSepLinea ;
         END IF ;
         T3.GET_SAT_CLAVEPRODUCTO( 'VTA', pFactura, Item.noIdentificacion, Item.descripcion, Item.unidad, sSAT_ID, sSAT_UM ) ;      
         sIdentificacion := REPLACE( Item.noIdentificacion, '.', '' ) ;
--
         IF ( Item.Is_VELO > 0 ) THEN
            nGramosNicotina := nGramosNicotina + ( Item.Grs_Nicotina * Item.Cantidad_Vta ) ;
         END IF ;
--      
--  WA para manejo de IEPS
         IF ( Item.Valor_IEPS > 0 ) THEN
            nEDICOM := nEDICOM + Item.Subt_sin_IEPS + Item.RFD_Valor_IVA + Item.Valor_IEPS ;
            nItemImporte       := Item.Subt_sin_IEPS + Item.Descuento ;
            nItemValorUnitario := ROUND( nItemImporte / Item.Cantidad, 2 ) ;  
            nItemDescuento     := Item.Descuento ;
         ELSE      
            nEDICOM := nEDICOM + Item.importe + Item.RFD_Valor_IVA ;
            nItemValorUnitario := Item.valorUnitario ;
            nItemImporte       := Item.importe       ;
            nItemDescuento     := Item.Descuento     ;
         END IF ; 
--
         sMaterial := sIdentificacion ;
--      
           nDoc_Descuento     := nDoc_Descuento     + nItemDescuento     ;
           nDoc_Valor_IEPS    := nDoc_Valor_IEPS    + Item.Valor_IEPS    ;
         IF ( Item.RFD_Valor_IVA > 0 ) THEN
           nDoc_Valor_con_IVA := nDoc_Valor_con_IVA + nItemImporte       ; 
           nDoc_Valor_IVA     := nDoc_Valor_IVA     + Item.RFD_Valor_IVA ;
         ELSE
           nDoc_Valor_sin_IVA := nDoc_Valor_sin_IVA + nItemImporte       ;
         END IF ;
-- Pedimentos de Importacion         
         IF ( sAddenda != 'SI' ) THEN
            nCantPedimento := 00 ;
            sPedimentos   := '';         
            FOR Ped IN ScrPedimento LOOP
               nCantPedimento := nCantPedimento + 1 ;
               IF ( nCantPedimento > 1 ) THEN
                  sPedimentos := sPedimentos || '*' ;
               END IF ;
               sPedimentos := sPedimentos || Ped.Pedimento ;
            END LOOP ;
         END IF ;              
--
         sCantidad_Vta := Item.Cantidad ;
         sUnidad_Vta   := Item.Unidad   ;
         SELECT EAI_Owner.getConv( 'Conv Paquete', sRecibe_RFC ) AS Conv_Paquete
            INTO sConv_Paquete
            FROM DUAL ;
       --IF ( ( sRecibe_RFC = 'CCM010710UU1' ) AND ( sIdentificacion IN ( '10138364', '10137874' ) ) ) THEN
         IF ( ( sConv_Paquete = 'SI' )                                                       ) THEN
            IF ( ( Item.Cig_x_PAQ > 0 ) AND ( Item.Cig_x_CLL  > 0 ) ) THEN
               nFactor_PAQ   := Item.Cig_x_PAQ / Item.Cig_x_CLL ;
            -- HardCode : ADUERO con Encendedor TOKAI   
               IF ( ( sRecibe_RFC = 'ADU800131T10' ) AND ( sIdentificacion = '50060752' ) ) THEN               
                  nFactor_PAQ := 40 ;
               END IF ;
               nCantidad_PAQ := Item.Cantidad_Vta / nFactor_PAQ ;
               IF ( MOD( nCantidad_PAQ, 1 ) = 0 ) THEN
                  sCantidad_Vta := TRIM( TO_CHAR( nCantidad_PAQ ) ) ;
                  sUnidad_Vta   := 'PAQ'         ;
                  sSAT_UM       := 'NMP'         ;
                  IF ( ( sRecibe_RFC = 'ADU800131T10' ) AND ( sIdentificacion = '50060752' ) ) THEN               
                     sUnidad_Vta   := 'CS'          ;
                     sSAT_UM       := 'NMP'         ;
                  END IF ;                  
                  nItemValorUnitario := nItemValorUnitario * nFactor_PAQ ;
               END IF ;   
            ELSE
               sConv_Paquete := 'NO' ;
            END IF ;
         END IF ;
--
         sTextoVELO := '' ;
         IF ( ( sAddenda = 'SI' ) AND ( Item.Is_VELO > 0 ) ) THEN
            sTextoVELO := '( ' || Item.mg_Pieza || 'mg de nicotina por saco, ' || Item.Grs_Nicotina || 'mg en total )' ;
         END IF ;
--
         sStepPLSQL := 'LINE (' || Item.numLinea || ').' ;
         uLINFAC := uLINFAC || 'LINE'                                                || sSepCampo ;
         uLINFAC := uLINFAC || nNum_Linea                                            || sSepCampo ;   -- 02 Linea de Factura
         uLINFAC := uLINFAC || sSAT_ID                                               || sSepCampo ;   -- 03 Codigo SAT
         uLINFAC := uLINFAC || Item.descripcion || sTextoVELO                        || sSepCampo ;   -- 04 Descripcion
         IF ( sSwitchEAN = 'EAN' ) THEN
            uLINFAC := uLINFAC || Item.codigoBarras                                  || sSepCampo ;   -- 05 No Interno
         ELSE
            uLINFAC := uLINFAC || sIdentificacion                                    || sSepCampo ;   -- 05 No Interno
         END IF ;   
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 06 Agente de Retencion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 07 Monto Impuesto Retenido
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 08 Monto Impuesto Retenido
         uLINFAC := uLINFAC || sCantidad_Vta                                         || sSepCampo ;   -- 09 Cantidad
         uLINFAC := uLINFAC || sUnidad_Vta                                           || sSepCampo ;   -- 10 UdeM Interna
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 11 Cantidad UdeM Referenciada
         uLINFAC := uLINFAC || sSAT_UM                                               || sSepCampo ;   -- 12 UdeM SAT
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 13 Precio Unitario Referencia
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 14 Grados de Alcohol
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 15 Fecha de Elaboracion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 16 Fecha de Vencimiento
         IF ( Item.Descuento > 0 ) THEN
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.Descuento    , 2 )       || sSepCampo ;   -- 17 Monto de Descuento
         ELSE
            uLINFAC := uLINFAC || ''                                                 || sSepCampo ;   -- 17 Monto de Descuento
         END IF ;
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nItemValorUnitario, 2 )          || sSepCampo ;   -- 18 Precio Unitario
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nItemImporte      , 2 )          || sSepCampo ;   -- 19 Monto de Cargo
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 20 Codigo de Impuesto Adicional
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 21 Precio Unitario en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 22 Codigo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 23 Descuento Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 24 Recargo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 25 Monto Item en otra Moneda
         nTotalAmt := nItemImporte - Item.Descuento ; 
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nItemImporte      , 2 )          || sSepCampo ;   -- 26 Total Amount
         uLINFAC := uLINFAC || '1'                                                   || sSepCampo ;   -- 27 Facturable
         uLINFAC := uLINFAC || '02'                                                  || sSepCampo ;   -- 28 Objeto de Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nItemImporte      , 2 )          || sSepCampo ;   -- 29 Precio Bruto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nTotalAmt         , 2 )          || sSepCampo ;   -- 30 Precio Neto
         uLINFAC := uLINFAC || sPedimentos                                           || sSepCampo ;   -- 31 Pedimiento
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 32 Predial
--
-- Inicio de Segmento para Addenda
--
         IF ( sAddenda = 'SI' ) THEN
            FOR Reg IN ScrItemAddenda LOOP
            -- A_LINE
               sStepPLSQL := 'A_LINE (' || Item.numLinea || ').' ;
               uLINFAC := uLINFAC || sSepLinea ;
               uLINFAC := uLINFAC || 'A_LINE'             || sSepCampo ;
            -- uLINFAC := uLINFAC || Reg.NumLin           || sSepCampo ;        
               uLINFAC := uLINFAC || Reg.RefCliente       || sSepCampo ;        -- 02 Codigo interno del Cliente
               uLINFAC := uLINFAC || Reg.RefProvee        || sSepCampo ;        -- 03 Referencia Articulo Proveedor
               uLINFAC := uLINFAC || Reg.RefSerieArt      || sSepCampo ;        -- 04 Numero de Serie
               uLINFAC := uLINFAC || Reg.IdiomaDesc       || sSepCampo ;        -- 05 Idioma
               uLINFAC := uLINFAC || Reg.CantConsum       || sSepCampo ;        -- 06 Cantidad en Unidades de Compra
               uLINFAC := uLINFAC || Reg.CantFree         || sSepCampo ;        -- 07 Cantidad Libres de Cargo
               uLINFAC := uLINFAC || Reg.CantComer        || sSepCampo ;        -- 08 Cantidad Comercializada
               uLINFAC := uLINFAC || Reg.NOrdenC          || sSepCampo ;        -- 09 Orden de Compra
               uLINFAC := uLINFAC || Reg.CalifIdentity    || sSepCampo ;        -- 10 ID Logistica
               uLINFAC := uLINFAC || Reg.SerieContenedor  || sSepCampo ;        -- 11 Serie del Contenedor
               uLINFAC := uLINFAC || Reg.NumPaq           || sSepCampo ;        -- 12 Numero Paquete
               uLINFAC := uLINFAC || Reg.TipPaq           || sSepCampo ;        -- 13 Tipo Paquete
               uLINFAC := uLINFAC || Reg.DescripPaq       || sSepCampo ;        -- 14 Descripcion Paquete
               uLINFAC := uLINFAC || Reg.PaqMetodoPago    || sSepCampo ;        -- 15 Codigo de quien Transporta
         -- Extra ocupa linea con IVA
               IF ( ( sRecibe_RFC = 'TEX9302097F3' ) ) THEN
                  uLINFAC := uLINFAC || Reg.Linea_con_IVA  || sSepCampo ;       -- 16 Importe Bruto
               ELSE
                  uLINFAC := uLINFAC || Reg.MontoBruLin    || sSepCampo ;       -- 16 Importe Bruto
               END IF ;   
             --uLINFAC := uLINFAC || Reg.Cantidad_Vta      || sSepCampo ;       -- 17 Cantidad Item
             --uLINFAC := uLINFAC || Reg.Unidad_Med_Vta    || sSepCampo ;       -- 18 Unidad de Medida
               uLINFAC := uLINFAC || sCantidad_Vta         || sSepCampo ;       -- 17 Cantidad Item
               IF ( sRecibe_RFC = 'ADU800131T10' ) THEN
                  IF    ( sUnidad_Vta = 'CAJ' ) THEN
                     sUnidad_Vta := 'PZ'  ;
                  ELSIF ( sUnidad_Vta = 'PAQ' ) THEN   
                     sUnidad_Vta := 'EXH' ;
                  ELSIF ( sUnidad_Vta = 'CS'  ) THEN   
                     sUnidad_Vta := 'CJ'  ;
                  END IF ;
               END IF ;               
               uLINFAC := uLINFAC || sUnidad_Vta           || sSepCampo ;       -- 18 Unidad de Medida               
         -- Extra ocupa linea con IVA
               IF ( ( sRecibe_RFC = 'TEX9302097F3' ) ) THEN
                  uLINFAC := uLINFAC || Reg.Precio_con_IVA || sSepCampo ;       -- 19 Precio bruto del articulo
                  uLINFAC := uLINFAC || ''                 || sSepCampo ;       -- 20 Descripcion Adicional
                  uLINFAC := uLINFAC || Reg.Precio_con_IVA || sSepCampo ;       -- 21 Precio Unitario
                  uLINFAC := uLINFAC || Reg.Linea_con_IVA  || sSepCampo ;       -- 22 Total Amount
               ELSE
                  IF ( sConv_Paquete = 'SI' )  THEN
                     uLINFAC := uLINFAC || Reg.PrecioBrutoPAQ || sSepCampo ;       -- 19 Precio bruto del articulo
                     uLINFAC := uLINFAC || ''                 || sSepCampo ;       -- 20 Descripcion Adicional
                     uLINFAC := uLINFAC || Reg.PrecioBrutoPAQ || sSepCampo ;       -- 21 Precio Unitario
                     uLINFAC := uLINFAC || Reg.MontoBruLin    || sSepCampo ;       -- 22 TotalAmount
                  ELSE
                     uLINFAC := uLINFAC || Reg.PrecioBruto    || sSepCampo ;       -- 19 Precio bruto del articulo
                     uLINFAC := uLINFAC || ''                 || sSepCampo ;       -- 20 Descripcion Adicional
                     uLINFAC := uLINFAC || Reg.PrecioBruto    || sSepCampo ;       -- 21 Precio Unitario
                     uLINFAC := uLINFAC || Reg.MontoBruLin    || sSepCampo ;       -- 22 TotalAmount
                  END IF ;
               END IF ;   
               uLINFAC := uLINFAC || Reg.FechaEntrega     || sSepCampo ;        -- 23 Fecha Entrega
               uLINFAC := uLINFAC || Reg.CRTienda         || sSepCampo ;        -- 24 CR Tienda
               uLINFAC := uLINFAC || Reg.Tienda           || sSepCampo ;        -- 25 Lugar de Entrega
               uLINFAC := uLINFAC || Reg.FacturaInterna   || sSepCampo ;        -- 26 Factura Interna
               uLINFAC := uLINFAC || Reg.LineaInterna     || sSepCampo ;        -- 27 Linea Interna
               uLINFAC := uLINFAC || Reg.PlantaReceptora  || sSepCampo ;        -- 28 Planta Receptora
               uLINFAC := uLINFAC || Reg.NRecipiente      || sSepCampo ;        -- 29 Numero Recipiente
               uLINFAC := uLINFAC || Reg.Release          || sSepCampo ;        -- 30 Release
               uLINFAC := uLINFAC || Reg.Remision         || sSepCampo ;        -- 31 Remision
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 32 Fecha de Lote
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 33 Numero de Indentificador
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 34 fecha de Lote
               uLINFAC := uLINFAC || sIdentificacion      || sSepCampo ;        -- 35 Codigo Item               
            END LOOP ;      
--
            sStepPLSQL := 'A_ADUANA (' || Item.numLinea || ').' ;
            FOR Ped IN ScrPedimento LOOP
               uLINFAC := uLINFAC || sSepLinea ;
               uLINFAC := uLINFAC || 'A_ADUANA'            || sSepCampo ;
               uLINFAC := uLINFAC || Ped.Aduana_Numero     || sSepCampo ;       -- 02 EAN Aduana
               uLINFAC := uLINFAC || ''                    || sSepCampo ;       -- 03 Nombre Aduana
               uLINFAC := uLINFAC || Ped.Pedimento         || sSepCampo ;       -- 04 Pedimento
               uLINFAC := uLINFAC || Ped.FecPedimento      || sSepCampo ;       -- 05 Fecha Pedimento
               uLINFAC := uLINFAC || ''                    || sSepCampo ;       -- 06 Tipo Pediimento
               uLINFAC := uLINFAC || ''                    || sSepCampo ;       -- 07 Fecha Recibo 
               uLINFAC := uLINFAC || ''                    || sSepCampo ;       -- 08 Fecha Bill of Lading
            END LOOP ;         
-- 
            sStepPLSQL := 'A_LINETAX (' || Item.numLinea || ').' ;
            uLINFAC := uLINFAC || sSepLinea ;
            uLINFAC := uLINFAC || 'A_LINETAX'                                          || sSepCampo ;
            uLINFAC := uLINFAC || '1'                                                  || sSepCampo ;  -- 02 Numero Impuesto
            uLINFAC := uLINFAC || '002'                                                || sSepCampo ;  -- 03 Tipo Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.RFD_Valor_IVA        , 2 ) || sSepCampo ;  -- 04 Monto Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.RFD_Tasa_IVA  / 100  , 6 ) || sSepCampo ;  -- 05 Tasa Impuesto
            uLINFAC := uLINFAC || 'T'                                                  || sSepCampo ;  -- 06 Calificador Impuesto
-- 
            uLINFAC := uLINFAC || sSepLinea ;
            uLINFAC := uLINFAC || 'A_LINETAX'                                          || sSepCampo ;
            uLINFAC := uLINFAC || '2'                                                  || sSepCampo ;  -- 02 Numero Impuesto
            uLINFAC := uLINFAC || '003'                                                || sSepCampo ;  -- 03 Tipo Impuesto
            uLINFAC := uLINFAC || '0'                                                  || sSepCampo ;  -- 04 Monto Impuesto
            uLINFAC := uLINFAC || '0'                                                  || sSepCampo ;  -- 05 Tasa Impuesto
            uLINFAC := uLINFAC || 'T'                                                  || sSepCampo ;  -- 06 Calificador Impuesto
         END IF ;  
--
-- Fin de Segmento para Addenda - Item
--         
--
         nLineaTax := 0 ;
         IF ( Item.Valor_IEPS > 0 ) THEN
            nLineaTax := nLineaTax + 1 ;
            nTasa_IEPS := ROUND( Item.Valor_IEPS * 100 / Item.Subt_sin_IEPS ) ; 
         --
            sStepPLSQL := 'LINETAX IEPS (' || Item.numLinea || ').' ;
            uLINFAC := uLINFAC || sSepLinea ;                 
            uLINFAC := uLINFAC || 'LINETAX'                                      || sSepCampo ;        
            uLINFAC := uLINFAC || nLineaTax                                      || sSepCampo ;  -- 02 Numero de Impuesto
            uLINFAC := uLINFAC || '003'                                          || sSepCampo ;  -- 03 Tipo de Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.Subt_sin_IEPS, 2 )   || sSepCampo ;  -- 04 Base Imponible
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.Valor_IEPS   , 2 )   || sSepCampo ;  -- 05 Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nTasa_IEPS / 100  , 6 )   || sSepCampo ;  -- 06 Tasa
            uLINFAC := uLINFAC || 'Tasa'                                         || sSepCampo ;  -- 07 Factor de Impuesto
            uLINFAC := uLINFAC || 'T'                                            || sSepCampo ;  -- 08 Calificador
         END IF ;      
         IF ( Item.RFD_Valor_IVA >= 0 ) THEN
            nLineaTax := nLineaTax + 1 ;
            nTasa_IEPS := ROUND( Item.PDF_Valor_IVA * 100 / Item.PDF_Valor_Subt ) ; 
            IF ( nTasa_IEPS > 0 ) THEN
               nTasa_IEPS := nTasa_LP ;
            ELSE
               nTasa_IEPS := 0 ;
            END IF ;            
         --
            sStepPLSQL := 'LINETAX IVA (' || Item.numLinea || ').' ;
            uLINFAC := uLINFAC || sSepLinea ;                 
            uLINFAC := uLINFAC || 'LINETAX'                                      || sSepCampo ;        
            uLINFAC := uLINFAC || nLineaTax                                      || sSepCampo ;  -- 02 Numero de Impuesto
            uLINFAC := uLINFAC || '002'                                          || sSepCampo ;  -- 03 Tipo de Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.PDF_Valor_Subt, 2 )  || sSepCampo ;  -- 04 Base Imponible
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.PDF_Valor_IVA , 2 )  || sSepCampo ;  -- 05 Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nTasa_IEPS / 100   , 6 )  || sSepCampo ;  -- 06 Tasa
            uLINFAC := uLINFAC || 'Tasa'                                         || sSepCampo ;  -- 07 Factor de Impuesto
            uLINFAC := uLINFAC || 'T'                                            || sSepCampo ;  -- 08 Calificador
         ELSE
            sStepPLSQL := 'LINETAX IVA (' || Item.numLinea || ').' ;
            uLINFAC := uLINFAC || sSepLinea ;                 
            uLINFAC := uLINFAC || 'LINETAX'                                      || sSepCampo ;        
            uLINFAC := uLINFAC || nLineaTax                                      || sSepCampo ;  -- 02 Numero de Impuesto
            uLINFAC := uLINFAC || '002'                                          || sSepCampo ;  -- 03 Tipo de Impuesto
            uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( Item.PDF_Valor_Subt, 2 )  || sSepCampo ;  -- 04 Base Imponible
            uLINFAC := uLINFAC || '0.00'                                         || sSepCampo ;  -- 05 Impuesto
            uLINFAC := uLINFAC || '0.000000'                                     || sSepCampo ;  -- 06 Tasa
            uLINFAC := uLINFAC || 'Tasa'                                         || sSepCampo ;  -- 07 Factor de Impuesto
            uLINFAC := uLINFAC || 'T'                                            || sSepCampo ;  -- 08 Calificador         
         END IF ;
         nEnvio_Subt   := nEnvio_Subt   + Item.Envio_Subt   ;
         nEnvio_IVA    := nEnvio_IVA    + Item.Envio_IVA    ;
         nDocto_IVA    := nDocto_IVA    + Item.Envio_IVA    ;
         nCredito_Subt := nCredito_Subt + Item.Credito_Subt ;
         nCredito_IVA  := nCredito_IVA  + Item.Credito_IVA  ;
--         
         IF ( pOutput > 10 ) THEN
             DBMS_Output.Put_Line( '-------------------' ) ;
             DBMS_Output.Put_Line( 'SKU              : ' || sIdentificacion     ) ;
             DBMS_Output.Put_Line( 'Subtotal s/IEPS  : ' || Item.Subt_sin_IEPS  ) ;
             DBMS_Output.Put_Line( 'Descuento        : ' || Item.Descuento      ) ;
             DBMS_Output.Put_Line( 'IEPS             : ' || Item.Valor_IEPS     ) ;
             DBMS_Output.Put_Line( 'Subtotal         : ' || Item.PDF_Valor_Subt ) ;
             DBMS_Output.Put_Line( 'IVA              : ' || Item.PDF_Valor_IVA  ) ;
         END IF ;            
      END LOOP ;
--
-- Desglosar Costo de Distribucion   
      IF ( nEnvio_Subt > 0 ) THEN
         nLineas    := nLineas    + 1 ; 
         nNum_Linea := nNum_Linea + 1 ;      
         SELECT EAI_Owner.getConv( 'CFG Settings', 'Envio-SKU-ID'         ) AS Envio_ID_Code,
                EAI_Owner.getConv( 'CFG Settings', 'Envio-SKU-UPC'        ) AS Envio_ID_UPC ,
                EAI_Owner.getConv( 'CFG Settings', 'Envio-UnidadMedida'   ) AS Envio_UM     ,  
                EAI_Owner.getConv( 'CFG Settings', 'Envio-Descripcion'    ) AS Envio_Descrip,  
                EAI_Owner.getConv( 'CFG Settings', 'Envio-SAT-ID'         ) AS Envio_SAT_IDDet,
                EAI_Owner.getConv( 'CFG Settings', 'Envio-SAT-ID-Mayoreo' ) AS Envio_SAT_IDMay, 
                EAI_Owner.getConv( 'CFG Settings', 'Envio-SAT-UM'         ) AS Envio_SAT_UM   
            INTO sEnvio_ID_Code, sEnvio_ID_UPC, sEnvio_UM, sEnvio_Descrip, sEnvio_SAT_IDDet, sEnvio_SAT_IDMay, sEnvio_SAT_UM
            FROM DUAL ;
            SELECT MAX( SKU_SAT ) AS SKU_SAT_Distribucion  INTO  sEnvio_SAT_ID 
              FROM T3.Conv_Lista_Grupo_Precio
              WHERE Lista_Precio = sLista_Precio ;
            IF ( NVL( sEnvio_SAT_ID, 'Det' ) = 'Det' ) THEN
                sEnvio_SAT_ID := sEnvio_SAT_IDDet ;
            ELSE
                sEnvio_SAT_ID := sEnvio_SAT_IDMay ;
            END IF ; 
--
         sStepPLSQL := 'LINE Dist Fee' ;
         uLINFAC := uLINFAC || sSepLinea ;
         uLINFAC := uLINFAC || 'LINE'                                                || sSepCampo ;
         uLINFAC := uLINFAC || nNum_Linea                                            || sSepCampo ;   -- 02 Linea de Factura
         uLINFAC := uLINFAC || sEnvio_SAT_ID                                         || sSepCampo ;   -- 03 Codigo SAT
         uLINFAC := uLINFAC || sEnvio_Descrip                                        || sSepCampo ;   -- 04 Descripcion
         uLINFAC := uLINFAC || sEnvio_ID_Code                                        || sSepCampo ;   -- 05 No Interno
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 06 Agente de Retencion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 07 Monto Impuesto Retenido
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 08 Monto Impuesto Retenido
         uLINFAC := uLINFAC || '1'                                                   || sSepCampo ;   -- 09 Cantidad
         uLINFAC := uLINFAC || sEnvio_UM                                             || sSepCampo ;   -- 10 UdeM Interna
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 11 Cantidad UdeM Referenciada
         uLINFAC := uLINFAC || sEnvio_SAT_UM                                         || sSepCampo ;   -- 12 UdeM SAT
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 13 Precio Unitario Referencia
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 14 Grados de Alcohol
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 15 Fecha de Elaboracion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 16 Fecha de Vencimiento
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 17 Monto de Descuento
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )                 || sSepCampo ;   -- 18 Precio Unitario
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )                 || sSepCampo ;   -- 19 Monto de Cargo
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 20 Codigo de Impuesto Adicional
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 21 Precio Unitario en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 22 Codigo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 23 Descuento Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 24 Recargo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 25 Monto Item en otra Moneda
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )                 || sSepCampo ;   -- 26 Total Amount
         uLINFAC := uLINFAC || '1'                                                   || sSepCampo ;   -- 27 Facturable
         uLINFAC := uLINFAC || '02'                                                  || sSepCampo ;   -- 28 Objeto de Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )                 || sSepCampo ;   -- 29 Precio Neto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )                 || sSepCampo ;   -- 30 Precio Bruto
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 31 Pedimiento
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 32 Predial
--
         nEnvio_TASA := ROUND( nEnvio_IVA * 100 / nEnvio_Subt, 0 )  ;
         nEnvio_TASA := 16 ;
         nEnvio_IVA  := ROUND( nEnvio_Subt * nEnvio_TASA / 100, 2 ) ;
--
         nDoc_Valor_con_IVA := nDoc_Valor_con_IVA + nEnvio_Subt ; 
         nDoc_Valor_IVA     := nDoc_Valor_IVA     + nEnvio_IVA  ;
--
         nItems  := nItems  + nEnvio_Subt + nEnvio_IVA ;
         nEDICOM := nEDICOM + nEnvio_Subt + nEnvio_IVA ;
      --    
         IF ( sAddenda = 'SI-Pend' ) THEN
         --
         -- Agregar linea de Distribucion
               sStepPLSQL := 'A_LINE (DistFee' ;
               uLINFAC := uLINFAC || sSepLinea ;
               uLINFAC := uLINFAC || 'A_LINE'             || sSepCampo ;
               uLINFAC := uLINFAC || 'DISTR'              || sSepCampo ;        -- 02 Codigo interno del Cliente
               uLINFAC := uLINFAC || 'DISTR'              || sSepCampo ;        -- 03 Referencia Articulo Proveedor
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 04 Numero de Serie
               uLINFAC := uLINFAC || 'ES'                 || sSepCampo ;        -- 05 Idioma
               uLINFAC := uLINFAC || '1'                  || sSepCampo ;        -- 06 Cantidad en Unidades de Compra
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 07 Cantidad Libres de Cargo
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 08 Cantidad Comercializada
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 09 Orden de Compra
               uLINFAC := uLINFAC || 'SRV'                || sSepCampo ;        -- 10 ID Logistica
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 11 Serie del Contenedor
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 12 Numero Paquete
               uLINFAC := uLINFAC || 'SRV'                || sSepCampo ;        -- 13 Tipo Paquete
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 14 Descripcion Paquete
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 15 Codigo de quien Transporta
               uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )   
                                                          || sSepCampo ;        -- 16 Importe Bruto
               uLINFAC := uLINFAC || '1'                  || sSepCampo ;        -- 17 Cantidad Item
               uLINFAC := uLINFAC || 'SRV'                || sSepCampo ;        -- 18 Unidad de Medida
               uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )   
                                                          || sSepCampo ;        -- 19 Precio bruto del articulo
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 20 Descripcion Adicional
               uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )   
                                                          || sSepCampo ;        -- 21 Precio Unitario
               uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt, 2 )   
                                                          || sSepCampo ;        -- 22 TotalAmount
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 23 Fecha Entrega
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 24 CR Tienda
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 25 Lugar de Entrega
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 26 Factura Interna
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 27 Linea Interna
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 28 Planta Receptora
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 29 Numero Recipiente
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 30 Release
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 31 Remision
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 32 Fecha de Lote
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 33 Numero de Indentificador
               uLINFAC := uLINFAC || ''                   || sSepCampo ;        -- 34 fecha de Lote
               uLINFAC := uLINFAC || 'DISTR'              || sSepCampo ;        -- 35 Codigo Item               
--
               uLINFAC := uLINFAC || sSepLinea ;
               uLINFAC := uLINFAC || 'A_LINETAX'                                          || sSepCampo ;
               uLINFAC := uLINFAC || '1'                                                  || sSepCampo ;  -- 02 Numero Impuesto
               uLINFAC := uLINFAC || '002'                                                || sSepCampo ;  -- 03 Tipo Impuesto
               uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_IVA                , 2 ) || sSepCampo ;  -- 04 Monto Impuesto
               uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_TASA / 100         , 6 ) || sSepCampo ;  -- 05 Tasa Impuesto
               uLINFAC := uLINFAC || 'T'                                                  || sSepCampo ;  -- 06 Calificador Impuesto
-- 
               uLINFAC := uLINFAC || sSepLinea ;
               uLINFAC := uLINFAC || 'A_LINETAX'                                          || sSepCampo ;
               uLINFAC := uLINFAC || '2'                                                  || sSepCampo ;  -- 02 Numero Impuesto
               uLINFAC := uLINFAC || '003'                                                || sSepCampo ;  -- 03 Tipo Impuesto
               uLINFAC := uLINFAC || '0'                                                  || sSepCampo ;  -- 04 Monto Impuesto
               uLINFAC := uLINFAC || '0'                                                  || sSepCampo ;  -- 05 Tasa Impuesto
               uLINFAC := uLINFAC || 'T'                                                  || sSepCampo ;  -- 06 Calificador Impuesto         
         END IF ;   
      -- 
         uLINFAC := uLINFAC || sSepLinea ;                 
         uLINFAC := uLINFAC || 'LINETAX'                                      || sSepCampo ;        
         uLINFAC := uLINFAC || '1'                                            || sSepCampo ;  -- 02 Numero de Impuesto
         uLINFAC := uLINFAC || '002'                                          || sSepCampo ;  -- 03 Tipo de Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_Subt        , 2 )  || sSepCampo ;  -- 04 Base Imponible
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_IVA         , 2 )  || sSepCampo ;  -- 05 Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nEnvio_TASA / 100  , 6 )  || sSepCampo ;  -- 06 Tasa
         uLINFAC := uLINFAC || 'Tasa'                                         || sSepCampo ;  -- 07 Factor de Impuesto
         uLINFAC := uLINFAC || 'T'                                            || sSepCampo ;  -- 08 Calificador      
      END IF ;
--
--
-- Desglosar Costo de Credito
      IF ( nCredito_Subt > 0 ) THEN
         nLineas    := nLineas    + 1 ; 
         nNum_Linea := nNum_Linea + 1 ;      
         SELECT EAI_Owner.getConv( 'CFG Settings', 'Credito-SKU-ID'         ) AS Credito_ID_Code,
                EAI_Owner.getConv( 'CFG Settings', 'Credito-SKU-UPC'        ) AS Credito_ID_UPC ,
                EAI_Owner.getConv( 'CFG Settings', 'Credito-UnidadMedida'   ) AS Credito_UM     ,  
                EAI_Owner.getConv( 'CFG Settings', 'Credito-Descripcion'    ) AS Credito_Descrip,  
                EAI_Owner.getConv( 'CFG Settings', 'Credito-SAT-ID'         ) AS Credito_SAT_ID ,
                EAI_Owner.getConv( 'CFG Settings', 'Credito-SAT-UM'         ) AS Credito_SAT_UM   
            INTO sCredito_ID_Code, sCredito_ID_UPC, sCredito_UM, sCredito_Descrip, sCredito_SAT_ID, sCredito_SAT_UM
            FROM DUAL ;
--
         sStepPLSQL := 'LINE Credit Fee' ;
         uLINFAC := uLINFAC || sSepLinea ;
         uLINFAC := uLINFAC || 'LINE'                                                || sSepCampo ;
         uLINFAC := uLINFAC || nNum_Linea                                            || sSepCampo ;   -- 02 Linea de Factura
         uLINFAC := uLINFAC || sCredito_SAT_ID                                       || sSepCampo ;   -- 03 Codigo SAT
         uLINFAC := uLINFAC || sCredito_Descrip                                      || sSepCampo ;   -- 04 Descripcion
         uLINFAC := uLINFAC || sCredito_ID_Code                                      || sSepCampo ;   -- 05 No Interno
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 06 Agente de Retencion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 07 Monto Impuesto Retenido
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 08 Monto Impuesto Retenido
         uLINFAC := uLINFAC || '1'                                                   || sSepCampo ;   -- 09 Cantidad
         uLINFAC := uLINFAC || sCredito_UM                                           || sSepCampo ;   -- 10 UdeM Interna
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 11 Cantidad UdeM Referenciada
         uLINFAC := uLINFAC || sCredito_SAT_UM                                       || sSepCampo ;   -- 12 UdeM SAT
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 13 Precio Unitario Referencia
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 14 Grados de Alcohol
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 15 Fecha de Elaboracion
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 16 Fecha de Vencimiento
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 17 Monto de Descuento
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nCredito_Subt, '999999999.99' ) )      || sSepCampo ;   -- 18 Precio Unitario
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nCredito_Subt, '999999999.99' ) )      || sSepCampo ;   -- 19 Monto de Cargo
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 20 Codigo de Impuesto Adicional
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 21 Precio Unitario en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 22 Codigo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 23 Descuento Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 24 Recargo Item en otra Moneda
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 25 Monto Item en otra Moneda
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nCredito_Subt, 2 )               || sSepCampo ;   -- 26 Total Amount
         uLINFAC := uLINFAC || '1'                                                   || sSepCampo ;   -- 27 Facturable
         uLINFAC := uLINFAC || '02'                                                  || sSepCampo ;   -- 28 Objeto de Impuesto
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nCredito_Subt     , '999999999.99' ) ) || sSepCampo ;   -- 29 Precio Neto
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nCredito_Subt     , '999999999.99' ) ) || sSepCampo ;   -- 30 Precio Bruto
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 31 Pedimiento
         uLINFAC := uLINFAC || ''                                                    || sSepCampo ;   -- 32 Predial
--
         nCredito_TASA := ROUND( nCredito_IVA * 100 / nCredito_Subt, 0 )  ;
         nCredito_TASA := 16 ;
         nCredito_IVA  := ROUND( nCredito_Subt * nCredito_TASA / 100, 2 ) ;
--
         nDoc_Valor_con_IVA := nDoc_Valor_con_IVA + nCredito_Subt ; 
         nDoc_Valor_IVA     := nDoc_Valor_IVA     + nCredito_IVA  ;
--
         nItems  := nItems  + nCredito_Subt + nCredito_IVA ;
         nEDICOM := nEDICOM + nCredito_Subt + nCredito_IVA ;
       --
         uLINFAC := uLINFAC || sSepLinea ;                 
         uLINFAC := uLINFAC || 'LINETAX'                                      || sSepCampo ;        
         uLINFAC := uLINFAC || '1'                                            || sSepCampo ;  -- 02 Numero de Impuesto
         uLINFAC := uLINFAC || '002'                                          || sSepCampo ;  -- 03 Tipo de Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nCredito_Subt      , 2 )  || sSepCampo ;  -- 04 Base Imponible
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nCredito_IVA       , 2 )  || sSepCampo ;  -- 05 Impuesto
         uLINFAC := uLINFAC || FN_NUM_TO_CHAR_CFDI( nCredito_TASA / 100, 6 )  || sSepCampo ;  -- 06 Tasa
         uLINFAC := uLINFAC || 'Tasa'                                         || sSepCampo ;  -- 07 Factor de Impuesto
         uLINFAC := uLINFAC || 'T'                                            || sSepCampo ;  -- 08 Calificador
      END IF ;
--
      IF ( ( nGramosNicotina > 0 ) AND ( Doc.tipoDeComprobante = 'I' ) ) THEN
         nLineas := nLineas + 1 ; 
         uLINFAC := uLINFAC || sSepLinea ;
         uLINFAC := uLINFAC || 'LINCLIE'                  || sSepCampo ;
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nLineas ) ) || sSepCampo ;
         uLINFAC := uLINFAC || 'Total de miligramos de nicotina contenida en este comprobante: ' || TRIM( TO_CHAR( nGramosNicotina, '999,999,999' ) ) || sSepCampo ;       
      END IF ;
--
      IF ( ( nImpSubtot_TASA00 > 0 ) AND ( nImpSubtot_TASAIVA > 0 ) ) THEN
         nLineas := nLineas + 1 ; 
         uLINFAC := uLINFAC || sSepLinea ;
         uLINFAC := uLINFAC || 'LINCLIE'                  || sSepCampo ;
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nLineas ) ) || sSepCampo ;
         uLINFAC := uLINFAC || 'Este documento contiene:' || sSepCampo ; 
         nLineas := nLineas + 1 ; 
         uLINFAC := uLINFAC || sSepLinea ;
         uLINFAC := uLINFAC || 'LINCLIE'                  || sSepCampo ;
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nLineas ) ) || sSepCampo ;
         uLINFAC := uLINFAC || 'Ingreso base 16% ' || 
                    TRIM ( TO_CHAR( ( nDoc_Valor_con_IVA ) , '999,999,999.99' ) )  
                                                          || sSepCampo ;
--    
         nLineas := nLineas + 1 ; 
         uLINFAC := uLINFAC || sSepLinea ;
         uLINFAC := uLINFAC || 'LINCLIE'                  || sSepCampo ;
         uLINFAC := uLINFAC || TRIM( TO_CHAR( nLineas ) ) || sSepCampo ;
         uLINFAC := uLINFAC || 'Ingreso base 0% ' || 
                    TRIM ( TO_CHAR( nDoc_Valor_sin_IVA , '999,999,999.99' ) )  
                                                          || sSepCampo ;
      END IF ;   
-- End: Item Segment
--------------------------------------------------------------------------------------------------------------------   
      IF ( pOutput > 0 ) THEN
          DBMS_Output.Put_Line( 'Factura          : ' || pFactura           ) ;
          DBMS_Output.Put_Line( 'Subtotal con IVA : ' || nDoc_Valor_con_IVA ) ;
          DBMS_Output.Put_Line( 'Subtotal sin IVA : ' || nDoc_Valor_sin_IVA ) ;
          DBMS_Output.Put_Line( 'Descuento        : ' || nDoc_Descuento     ) ;
          DBMS_Output.Put_Line( 'IEPS             : ' || nDoc_Valor_IEPS    ) ;
          DBMS_Output.Put_Line( 'IVA              : ' || nDoc_Valor_IVA     ) ;
          DBMS_Output.Put_Line( 'Total            : ' || ( nDoc_Valor_con_IVA + nDoc_Valor_sin_IVA - nDoc_Descuento + nDoc_Valor_IEPS + nDoc_Valor_IVA ) ) ;
          DBMS_Output.Put_Line( '-------------------' ) ;
          DBMS_Output.Put_Line( 'Subtotal         : ' || Doc.subtotal       ) ;
          DBMS_Output.Put_Line( 'Descuento        : ' || Doc.Descuento      ) ;
          DBMS_Output.Put_Line( 'IEPS             : ' || Doc.Valor_IEPS     ) ;
          DBMS_Output.Put_Line( 'IVA              : ' || Doc.importe_IVA    ) ;
          DBMS_Output.Put_Line( 'Total            : ' || Doc.total          ) ;
          DBMS_Output.Put_Line( 'Ajuste Envio IVA : ' || Doc.ajusteEnvio    ) ;
      END IF ;   
--
      IF ( ( Doc.Recibe_RFC = 'TCH850701RM1' ) ) THEN
         sLocalidadEmisor   := 'Monterrey' ;
         sLocalidadReceptor := 'México' ;
      ELSE
         sLocalidadEmisor   := '' ;
         sLocalidadReceptor := '' ;
      END IF ;      
--      
-- Cabecera Factura
--
--    WA cambio entre formaDePago y Metodo de Pago
      T3.PROC_CFDI_GET_PAYMETHOD( pFactura, Doc.formaDePago, Doc.NumCtaPago, sMetodoDePago, sNumCtaPago ) ;
      IF ( sMetodoDePago != '99' ) THEN
         sFormaDePago  := sMetodoDePago ; 
         sMetodoDePago := 'PUE' ;  
      ELSE
         sFormaDePago  := Doc.formaDePago  ;
         sMetodoDePago := Doc.metodoDePago ;   
      END IF ;
      IF ( Doc.Ctro != 'MX2J' ) THEN
         IF ( Doc.Recibe_RFC = 'XAXX010101000' ) THEN
            sFormaDePago  := '01' ; 
            sMetodoDePago := 'PUE' ;        
         END IF ;   
      END IF ;
--      
-- Hard Code 
--   Solicitado por Boni/Nuria/FGuerrero
--       14/Agosto/2023
--     
      IF ( Doc.tipoDeComprobante = 'E' ) THEN    
         sFormaDePago  := '15'  ; 
         sMetodoDePago := 'PUE' ; 
      END IF ;
--
      nDoc_Total := nDoc_Valor_sin_IVA + nDoc_Valor_con_IVA ;
      IF ( nDoc_Descuento > 0 ) THEN
         nDescuento := nDoc_Descuento ;
      ELSE
         nDescuento := 0 ;
         IF ( sAddenda = 'SI' ) THEN
            nDescuento := 0 ;
         END IF ;   
      END IF ;
--      
      nDoc_Total := nDoc_Total - nDoc_Descuento ;
      nDoc_Total := nDoc_Total + nDoc_Valor_IEPS + nDoc_Valor_IVA ;
--
-- HEADER
      uHEADER  := uHEADER || 'HEADER'                                       || sSepCampo ;              
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 02 Codigo de Autorizacion
      uHEADER  := uHEADER || Doc.tipoDeComprobante                          || sSepCampo ;   -- 03 Tipo de Comprobante
      uHEADER  := uHEADER || Doc.folio_Edicom                               || sSepCampo ;   -- 04 Folio
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 05 Fecha de Vencimiento
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 06 Tipo de Ingreso
      uHEADER  := uHEADER || sFormaDePago                                   || sSepCampo ;   -- 07 Tipo de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 08 Fecha Limite de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 09 Tipo Cuenta de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 10 Numero Cuenta de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 11 Banco de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 12 Fecha Inicio Servicios
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 13 Fecha Inicio Servicios
      IF ( ( nCFDIREL = 0 ) AND ( Doc.tipoDeComprobante = 'I' ) ) THEN
         uHEADER  := uHEADER || Doc.fecha                                   || sSepCampo ;   -- 14 Fecha Emision Documento
      ELSE
         uHEADER  := uHEADER || Doc.fecha_Reenvio                           || sSepCampo ;   -- 14 Fecha Emision Documento
      END IF ;
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 15 Fecha Orden de Compra
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 16 Orden de Compra
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.Importe        , 2 )  || sSepCampo ;   -- 17 Monto Gravado Total
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.SubTotal_Tasa00, 2 )  || sSepCampo ;   -- 18 Monto Exento
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.SubTotal -
                                                      Doc.Valor_IEPS , 2 )  || sSepCampo ;   -- 19 Subtotal
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( Doc.Importe        , 2 )  || sSepCampo ;   -- 20 Total Impuestos Trasladados
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 21 Impuestos Retenidos
      uHEADER  := uHEADER || FN_NUM_TO_CHAR_CFDI( nDoc_Total         , 2 )  || sSepCampo ;   -- 22 Monto Total
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 23 Monto No Facturable
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 24 Monto Periodo
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 25 Saldo Anterior
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 26 Monto Avance de Pago
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 27 Valor Cobrado
      uHEADER  := uHEADER || Doc.Factura_Edicom                             || sSepCampo ;   -- 28 Folio Interno Factura
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 29 Indicador Nota de Credito
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 30 Indicador Monto Gravado
      uHEADER  := uHEADER || Doc.condicionesDePago                          || sSepCampo ;   -- 31 Terminos de Pago
      uHEADER  := uHEADER || Doc.Moneda                                     || sSepCampo ;   -- 32 Moneda
      uHEADER  := uHEADER || Doc.Serie_Edicom                               || sSepCampo ;   -- 33 Serie      
      uHEADER  := uHEADER || ''                                             || sSepCampo ;   -- 34 Confirmation
      IF ( sAddenda = 'NO' ) THEN
         uHEADER  := uHEADER || 'C'                                         || sSepCampo ;   -- 35 Flag Addenda/Complemento
      ELSE
         uHEADER  := uHEADER || 'A'                                         || sSepCampo ;   -- 35 Flag Addenda/Complemento
      END IF ;
      uHEADER  := uHEADER || '01'                                           || sSepCampo ;   -- 36 Tipo Exportacion
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
   -- uHEADER  := uHEADER || Doc.Emisor_CodigoPostal  || sSepCampo ;   -- 26 Postal Code
      uHEADER  := uHEADER || Doc.Expide_codigoPostal  || sSepCampo ;   -- 26 Postal Code
      uHEADER  := uHEADER || 'MEX'                    || sSepCampo ;   -- 27 Country Code
--
-- PARTIES - Receptor
      sRegimen := Doc.Regimen_Fiscal_Cte ;
      sUsoCFDI := Doc.UsoCFDI            ;
      IF ( Doc.Recibe_RFC = 'XAXX010101000' ) THEN
         sRegimen := '616' ;
         sUsoCFDI := 'S01' ;
      END IF ;
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
      uHEADER  := uHEADER || sRegimen                 || sSepCampo ;   -- 16 Business_Activity
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 17 Seller Internal Code
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 18 Seller Area
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 19 Sales Route
      uHEADER  := uHEADER || sUsoCFDI                 || sSepCampo ;   -- 20 Additional Info
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 21 Foreign_Tax_ID
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 22 Contac_Details
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 23 Buyer_Internal_Code
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 24 Payer_ID
      uHEADER  := uHEADER || ''                       || sSepCampo ;   -- 25 City
      IF ( Doc.Recibe_RFC = 'XAXX010101000' ) THEN
         uHEADER  := uHEADER || Doc.Expide_codigoPostal  || sSepCampo ;   -- 26 Postal Code
      ELSE
         uHEADER  := uHEADER || Doc.Recibe_CodigoPostal  || sSepCampo ;   -- 26 Postal Code
      END IF ;
      uHEADER  := uHEADER || 'MEX'                    || sSepCampo ;   -- 27 Country Code                   
--
      IF ( sAddenda = 'SI' ) THEN
         FOR Inf IN ScrHeadAddenda LOOP
--
            sPedido       := Inf.Pedido       ;
            sNotaEnt      := Inf.NotaEnt      ;
            sVendorNInt   := Inf.VendorNInt   ;
            sCompradorGLN := Inf.CompradorGLN ;
--
            IF ( Doc.Recibe_RFC = 'NWM9709244W4' ) THEN
               IF    ( Doc.Cadena_Comercial  = '78' )  THEN   -- Bodega Aurera
                  sVendorNInt   := '001781012'     ;
                  sCompradorGLN := '7507003100001' ;                
               ELSIF ( Doc.Cadena_Comercial  = 'W7' )  THEN   -- Bodega Aurera Express
                  sVendorNInt   := '472592012'     ;
                  sCompradorGLN := '7507003100001' ;
               ELSIF ( Doc.Cadena_Comercial  = '76' )  THEN   -- Nueva Walmaet
                  sVendorNInt   := '001781019'     ;
                  sCompradorGLN := '7507003100001' ;
               ELSIF ( Doc.Cadena_Comercial  = '77' )  THEN   -- SAMS
                  sVendorNInt   := '001776640'     ;
                  sCompradorGLN := '7507003100001' ;
               ELSIF ( Doc.Cadena_Comercial  = '75' )  THEN   -- SUPERAMA
                  sVendorNInt   := '001781014'     ;
                  sCompradorGLN := '7507003100001' ;
               END IF ;   
            END IF ;
--
            IF ( ( Doc.Recibe_RFC = 'TSO991022PB6' ) AND ( Doc.Cadena_Comercial  = 'M8' ) ) THEN   -- TCM
                  sVendorNInt   := '907676'     ;
                  sCompradorGLN := '7505000099632' ;
            END IF ;
--
            IF ( ( Doc.Recibe_RFC = 'TSO991022PB6' ) AND ( Doc.Cadena_Comercial  = 'U5' ) ) THEN   -- SuperCity
               sVendorNInt := '142844' ;
               IF ( ( ( sPedido IS NULL ) OR ( LENGTH( sPedido ) = 0 ) ) AND ( sNotaEnt IS NOT NULL ) ) THEN
                  sPedido  := sNotaEnt ;
                  sNotaEnt := ''       ;
               END IF ;
            END IF ;
            IF ( ( Doc.Recibe_RFC = 'TSO991022PB6' ) AND ( Doc.Cadena_Comercial != 'U5' ) ) THEN
               IF ( ( sPedido IS NULL ) OR ( LENGTH( sPedido ) = 0 ) ) THEN
                  sPedido := '0' ;
               END IF ;   
            END IF ;
            IF ( ( Doc.Recibe_RFC = 'FGU830930PD3' ) ) THEN
               IF ( ( sPedido IS NULL ) OR ( LENGTH( sPedido ) = 0 ) ) THEN
                  sPedido := '0' ;
               END IF ;   
               IF ( ( sNotaEnt IS NULL ) OR ( LENGTH( sNotaEnt ) = 0 ) ) THEN
                  sNotaEnt := '0' ;
               END IF ;   
            END IF ;
            IF ( ( Doc.Recibe_RFC = 'SEM980701STA' ) ) THEN
               IF ( ( sPedido IS NULL ) OR ( LENGTH( sPedido ) = 0 ) ) THEN
                  sPedido := '0' ;
               END IF ;   
               IF ( ( sNotaEnt IS NULL ) OR ( LENGTH( sNotaEnt ) = 0 ) ) THEN
                  sNotaEnt := '0' ;
               END IF ;   
            END IF ;
            IF ( ( Doc.Recibe_RFC = 'TCM951030A17' ) ) THEN
               IF ( ( sNotaEnt IS NULL ) OR ( LENGTH( sNotaEnt ) = 0 ) ) THEN
                  sNotaEnt := '000000' ;
               END IF ;   
            END IF ;
            IF ( Doc.Recibe_RFC = 'OSA840206MK6' ) THEN
               sOrdenCompra  := Inf.Pedido       ;
               sOrdenCompra  := ''               ;
            ELSE
               sOrdenCompra  := ''               ;
            END IF ;
--            
            IF ( Doc.Recibe_RFC = 'TSO991022PB6' ) THEN
               IF ( sFactura != Doc.folio_Edicom ) THEN
                  sPedido  := '' ;
                  sNotaEnt := '' ;
               END IF ;
            END IF ;
--
            sStepPLSQL := 'A_HEADER' ;
            uCABADD := uCABADD || sSepLinea                          ;
            uCABADD := uCABADD || 'A_HEADER'            || sSepCampo ;
            uCABADD := uCABADD || Inf.Funcion           || sSepCampo ;          -- 02 Funcion
            uCABADD := uCABADD || Inf.Doc_Reemplazo     || sSepCampo ;          -- 03 Numero Documento
            uCABADD := uCABADD || sPedido               || sSepCampo ;          -- 04 Pedido
            uCABADD := uCABADD || Inf.FePedido          || sSepCampo ;          -- 05 Fecha de Pedido
            uCABADD := uCABADD || sNotaEnt              || sSepCampo ;          -- 06 Nota Entrada
            uCABADD := uCABADD || Inf.FeNotaEnt         || sSepCampo ;          -- 07 Fecha Entrada
            uCABADD := uCABADD || Inf.VendedorGLN       || sSepCampo ;          -- 08 Codigo EAN
            uCABADD := uCABADD || sVendorNInt           || sSepCampo ;          -- 09 Numero Interno
            uCABADD := uCABADD || Inf.VendorIEPS        || sSepCampo ;          -- 10 Referencia Proveedor
            uCABADD := uCABADD || sCompradorGLN         || sSepCampo ;          -- 11 Comprador GLN
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
            sA_Header53 := '' ;
            IF ( Doc.Recibe_RFC = 'SEM980701STA' ) THEN
               T3.GET_CHECK_LIB_711( sFactura, sA_Header53 ) ;
            END IF ;            
            uCABADD := uCABADD || sA_Header53           || sSepCampo ;          -- 53 Tipo de Addenda                        
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
         --            
         END LOOP ;
      END IF ; 
--      
-- Cabecera Cliente
--
      sCABCLIE := sCABCLIE || 'CABCLIE'               || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Recibe_Nombre       || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Remite_Calle        || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Remite_Colonia      || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Remite_Municipio    || sSepCampo ;
      sCABCLIE := sCABCLIE || ''                      || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Remite_Estado       || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Remite_Pais         || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Remite_codigoPostal || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.pedidoV3            || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.sucursalNombre      || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.pedidoSAP           || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.facturaSAP          || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Tipo_Documento      || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.CentroExpedicion    || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Recibe_Cliente      || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.Remite_Cliente      || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.LugarExpedicion     || sSepCampo ;
      sCABCLIE := sCABCLIE || ''                      || sSepCampo ;
      sCABCLIE := sCABCLIE || sLeyMenor               || sSepCampo ;
      sCABCLIE := sCABCLIE || sLeyPriv                || sSepCampo ;
      sCABCLIE := sCABCLIE || Doc.eMail               || sSepCampo ;
      sCABCLIE := sCABCLIE || sSepLinea                            ;
--
      sCABCLIE := sCABCLIE || sCFDIREL                             ;
      sCABCLIE := sCABCLIE || 'PAYMET'                || sSepCampo ;              
      sCABCLIE := sCABCLIE || sMetodoDePago           || sSepCampo ;
      sCABCLIE := sCABCLIE || uCABADD                              ;
--      
-- Impuestos
--
      sStepPLSQL := 'A_TAX' ;
      IF ( sAddenda = 'SI' ) THEN
            uIMPFAC  := uIMPFAC  || 'A_TAX'                                        || sSepCampo ;
            uIMPFAC  := uIMPFAC  || '002'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.importe_IVA     , 2 ) || sSepCampo ;      -- 03 Monto de Impuesto
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nTasa_LP / 100      , 6 ) || sSepCampo ;      -- 04 Porcentaje de Impuesto
            uIMPFAC  := uIMPFAC  || 'T'                                            || sSepCampo ;      -- 05 Calificador
            uIMPFAC  := uIMPFAC  || sSepLinea ;
         IF ( Doc.Valor_IEPS = 0 ) THEN
            uIMPFAC  := uIMPFAC  || 'A_TAX'                                        || sSepCampo ;
            uIMPFAC  := uIMPFAC  || '003'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
            uIMPFAC  := uIMPFAC  || '0.00'                                         || sSepCampo ;      -- 03 Monto de Impuesto
            uIMPFAC  := uIMPFAC  || '0.000000'                                     || sSepCampo ;      -- 04 Porcentaje de Impuesto
            uIMPFAC  := uIMPFAC  || 'T'                                            || sSepCampo ;      -- 05 Calificador
            uIMPFAC  := uIMPFAC  || sSepLinea ;
         END IF ;
      END IF ;      
--
      sStepPLSQL := 'TAX' ;
      nIMPFAC  := 0 ;
      nValor_IEPS := Doc.Valor_IEPS ;
      IF ( Doc.Valor_IEPS > 0 ) THEN
         nTasa_IEPS := ROUND( Doc.Valor_IEPS * 100 / Doc.Valor_Subt_IEPS ) ; 
         nIMPFAC  := nIMPFAC + 1 ;  
--
         IF ( sAddenda = 'SI' ) THEN
            uIMPFAC  := uIMPFAC  || 'A_TAX'                                        || sSepCampo ;
            uIMPFAC  := uIMPFAC  || '003'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.Valor_IEPS      , 2 ) || sSepCampo ;      -- 03 Monto de Impuesto
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nTasa_IEPS / 100    , 6 ) || sSepCampo ;      -- 04 Porcentaje de Impuesto
            uIMPFAC  := uIMPFAC  || 'T'                                            || sSepCampo ;      -- 05 Calificador
            uIMPFAC  := uIMPFAC  || sSepLinea ;
         END IF ;   
      -- TAX Segment
         uIMPFAC  := uIMPFAC  || 'TAX'                                          || sSepCampo ;
         uIMPFAC  := uIMPFAC  || '003'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.Valor_Subt_IEPS, 2 )  || sSepCampo ;      -- 03 Base Imponible
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.Valor_IEPS     , 2 )  || sSepCampo ;      -- 04 Monto de Impuesto
         uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nTasa_IEPS / 100   , 6 )  || sSepCampo ;      -- 05 Porcentaje de Impuesto
         uIMPFAC  := uIMPFAC  || 'Tasa'                                         || sSepCampo ;      -- 06 Factor de Impuesto
         uIMPFAC  := uIMPFAC  || 'T'                                            || sSepCampo ;      -- 07 Calificador
         uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 08         
      END IF ;
      IF ( ( Doc.subtotal_TasaIVA > 0 ) OR ( nCredito_Subt > 0 ) ) THEN 
         IF ( nIMPFAC > 0 ) THEN
            uIMPFAC  := uIMPFAC || sSepLinea ;
         END IF ;      
         nIMPFAC  := nIMPFAC + 1 ;  
      -- TAX Segment
            uIMPFAC  := uIMPFAC  || 'TAX'                                          || sSepCampo ;
            uIMPFAC  := uIMPFAC  || '002'                                          || sSepCampo ;      -- 02 Tipo de Impuesto
         IF ( Doc.subtotal_TasaIVA > 0 ) THEN
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.subtotal_TasaIVA, 2 ) || sSepCampo ;      -- 03 Base Imponible
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.importe_IVA     , 2 ) || sSepCampo ;      -- 04 Monto de Impuesto
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nTasa_LP / 100      , 6 ) || sSepCampo ;      -- 05 Porcentaje de Impuesto
         ELSE
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nCredito_Subt       , 2 ) || sSepCampo ;      -- 03 Base Imponible
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( nCredito_IVA        , 2 ) || sSepCampo ;      -- 04 Monto de Impuesto
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( 16 / 100            , 6 ) || sSepCampo ;      -- 05 Porcentaje de Impuesto
         END IF ;
            uIMPFAC  := uIMPFAC  || 'Tasa'                                         || sSepCampo ;      -- 06 Factor de Impuesto
            uIMPFAC  := uIMPFAC  || 'T'                                            || sSepCampo ;      -- 07 Calificador
            uIMPFAC  := uIMPFAC  || ''                                             || sSepCampo ;      -- 08         
      END IF ;   
      IF ( Doc.impSubtot_TASA00 > 0 ) THEN
         IF ( nIMPFAC > 0 ) THEN
            uIMPFAC  := uIMPFAC || sSepLinea ;
         END IF ;   
         nIMPFAC  := nIMPFAC + 1 ;  
      -- TAX Segment
         uIMPFAC  := uIMPFAC  || 'TAX'                                             || sSepCampo ;
         uIMPFAC  := uIMPFAC  || '002'                                             || sSepCampo ;      -- 02 Tipo de Impuesto
         IF ( Doc.subtotal_TasaIVA  = 0 ) AND ( nCredito_Subt > 0 ) THEN
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.impSubtot_TASA00
                                                          - nCredito_Subt    , 2 ) || sSepCampo ;      -- 03 Base Imponible
         ELSE
            uIMPFAC  := uIMPFAC  || FN_NUM_TO_CHAR_CFDI( Doc.impSubtot_TASA00, 2 ) || sSepCampo ;      -- 03 Base Imponible
         END IF ;
         uIMPFAC  := uIMPFAC  || '0.00'                                            || sSepCampo ;      -- 04 Monto de Impuesto
         uIMPFAC  := uIMPFAC  || '0.000000'                                        || sSepCampo ;      -- 05 Porcentaje de Impuesto
         uIMPFAC  := uIMPFAC  || 'Tasa'                                            || sSepCampo ;      -- 06 Factor de Impuesto
         uIMPFAC  := uIMPFAC  || 'T'                                               || sSepCampo ;      -- 07 Calificador
         uIMPFAC  := uIMPFAC  || ''                                                || sSepCampo ;      -- 08         
      END IF ;      
   END LOOP ;
--
   IF ( nDoc_Descuento > 0 ) THEN
       uIMPFAC := uIMPFAC || sSepLinea ;
       uIMPFAC := uIMPFAC || 'ALLOCHARGE'                                   || sSepCampo ;
       uIMPFAC := uIMPFAC || '1'                                            || sSepCampo ;      -- 02 No Sequencia
       uIMPFAC := uIMPFAC || 'Descuento'                                    || sSepCampo ;      -- 03 Cargo o Descuento
       uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 04 Cargo / Descuento
       uIMPFAC := uIMPFAC || 'Descuento'                                    || sSepCampo ;      -- 05 Cargo o Descuento
       uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 06 Porcentaje
       uIMPFAC := uIMPFAC || FN_NUM_TO_CHAR_CFDI( nDoc_Descuento, 2 )       || sSepCampo ;      -- 07 Monto de Descuento
       uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 08 Monto en otra moneda
       uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 09 Indicador de Facturacion
       uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 10 Comprador conooce Descuento
       uIMPFAC := uIMPFAC || ''                                             || sSepCampo ;      -- 11 Base del porcentaje
   END IF ;
   FOR Info IN ScrTextoAdicional LOOP
      nLineas := nLineas + 1 ; 
      uLINFAC := uLINFAC || sSepLinea ;
      uLINFAC := uLINFAC || 'LINCLIE'                  || sSepCampo ;
      uLINFAC := uLINFAC || TRIM( TO_CHAR( nLineas ) ) || sSepCampo ;
      uLINFAC := uLINFAC || Info.Texto                 || sSepCampo ;       
   END LOOP ;
--
   IF ( ( LENGTH( uLINFAC ) > 10 ) 
      AND ( ABS( nTotal - nItems  ) < 0.10 ) 
      AND ( ABS( nTotal - ( nEDICOM - nDescuento ) ) < 0.10 ) ) THEN
      sData := uHeader ;
      sData := CONCAT( sData, sSepLinea || sCABCLIE ) ;
      sData := CONCAT( sData, sSepLinea || uIMPFAC  ) ;
      sData := CONCAT( sData, sSepLinea || uLINFAC  ) ;
      IF ( ABS( ( nDocto_IVA - nEnvio_IVA ) ) < 0.10 ) THEN
         INSERT INTO T3.CFDI_DOCUMENTOS_ENVIAR ( Nota_Venta, Informacion )
            VALUES ( pFactura, sData ) ;
         INSERT INTO T3.CFDI_Documentos ( Nota_Venta, Ctro, Fecha_Liberacion, Metodo_Pago )
            VALUES ( pFactura, sCtro, SYSDATE, sMetodoDePago ) ;      
         nAjusteIVA_DistFee := nDoc_Total - nTotal ;   
         IF ( nAjusteIVA_DistFee != 0 ) THEN
            INSERT INTO T3.CFDI_Agrupado_DIF ( Nota_VENTA_CFDI, Ajuste, Fecha )
               VALUES ( pFactura, nAjusteIVA_DistFee * -1, SYSDATE ) ;    
         END IF ;      
      ELSE   
         INSERT INTO T3.RF_ERROR_LOG 
            ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
         VALUES
            ( SYSDATE, 'GENERAR_MX06', pFactura, 'Revisar IVA en Distribution Fee' ) ;
      END IF ;
--    
   ELSE         
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'GENERAR_MX06', pFactura, 'Doc=>' || nTotal || ' vs Items=> ' || nItems || ' vs EDICOM=> ' || nEDICOM || ', ' || nDescuento ) ;
      INSERT INTO T3.CFDI_DOCUMENTOS_ENVIAR_ADD ( Nota_Venta, Informacion )
         VALUES ( pFactura, sData ) ;            
   END IF ;      
--   
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_V40_GENERAR_MX06' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID      ) ;
      DBMS_Output.Put_Line( 'Secuencia     : ' || sStepPLSQL ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg       ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'PROC_V40_GENERAR_MX06', strID, sMsg ) ;
      COMMIT ;   
END ;
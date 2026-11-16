create or replace PROCEDURE    "PROC_V20_GENERAR_PAGO" 
  ( pFactura        IN VARCHAR2,
    pAccnt_ID       IN VARCHAR2 DEFAULT NULL,
    pOutput         IN NUMBER   DEFAULT 0  )
IS
   strID                VARCHAR2(0030) ;
   sMsg                 VARCHAR2(0500) ;   
   sCtro                VARCHAR2(0004) ;
   uCABCLIE             CLOB           ;
   sFacturaPagada       VARCHAR2(0040) ;
----   
   sReturn              VARCHAR2(4000) ;
   sCABCLIE             CLOB           ;
-- sLINFAC              VARCHAR2(4000) ;
   sLeyMenor            VARCHAR2(4000) ;
   sLeyPriv             VARCHAR2(4000) ;
   sSepLinea            VARCHAR2(0004) ;
   sSepCampo            VARCHAR2(0004) ;
   sRFC                 VARCHAR2(0030) ;
   sAccnt_ID            VARCHAR2(0040) ;
   sData                CLOB           ;
   sCFDIREL             VARCHAR2(4000) ;
   nCount               NUMBER(03)     ;
   nAmtImporte          NUMBER(22,3)   ;
   nAmtValor_Subt_16    NUMBER(22,3)   ;
   nAmtValor_Subt_00    NUMBER(22,3)   ;
   nAmtValor_IVA_16     NUMBER(22,3)   ;
   nAmtValor_IEPS       NUMBER(22,3)   ;
   nPagoFactor          NUMBER(12,6)   ;
   nPagoValor_Subt_16   NUMBER(24,6)   ;
   nPagoValor_Subt_00   NUMBER(24,6)   ;
   nPagoValor_IVA_16    NUMBER(24,6)   ;
   nPagoValor_IEPS      NUMBER(24,6)   ;
   nPagoValor_IVA_Calc  NUMBER(24,6)   ;
--
   nIVA_Calculado       NUMBER(24,6)   ;
   nDec_Calculo         NUMBER(03)     ;
   nDec_Layout          NUMBER(03)     ;
--
   CURSOR ScrDatos IS
       SELECT 
              CFD.Folio_ID                                        AS Folio_ID           ,
              CFD.Ctro                                            AS Ctro               ,
--                                   
              'CPAGOS'                                            AS tagCPAGOS          ,
              '2.0'                                               AS VersionCFDI        ,
--            'HH'                                                AS Serie              ,
              DECODE( CFD.Created_BY, 'INTERFACE',
                  'CTRL', 'HH'     )                              AS Serie              ,
              CFD.Folio_ID                                        AS Folio              ,
--            TO_CHAR( CFD.Fecha_Asignacion, 'DDMMYYYYHH24MISS' ) AS Fecha_Comprobante  ,
--            TO_CHAR( CFD.Fecha_Asignacion, 'DDMMYYYY' ) ||
--              REPLACE( T3.FN_ADJUST_GMT( TO_CHAR( CFD.Fecha_Asignacion, 'HH24:MI:SS') , DF.Dif_GMT ), ':', '' ) 
              TO_CHAR( SYSDATE, 'DDMMYYYY' ) ||
                REPLACE( T3.FN_ADJUST_GMT( TO_CHAR( SYSDATE, 'HH24:MI:SS') , DF.Dif_GMT ), ':', '' ) 
                                                                  AS Fecha_Comprobante  ,
              EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal' )                
                                                                  AS Regimen_Fiscal     ,
              T3.FN_TRIM_CFDI( Soc.RFC             )              AS Emisor_RFC         ,
              T3.FN_TRIM_CFDI( Soc.Razon_Social_HH )              AS Emisor_Nombre      ,
              T3.FN_TRIM_CFDI( Soc.Calle           )              AS Emisor_Calle       , 
              T3.FN_TRIM_CFDI( Soc.Numero_Ext      )              AS Emisor_NoExterior  ,
              T3.FN_TRIM_CFDI( Soc.Numero_Int      )              AS Emisor_NoInterior  ,
              T3.FN_TRIM_CFDI( Soc.Colonia         )              AS Emisor_Colonia     ,
              T3.FN_TRIM_CFDI( Soc.Localidad       )              AS Emisor_Localidad   ,
              ''                                                  AS Emisor_Referencia  ,
              T3.FN_TRIM_CFDI( Soc.Municipio       )              AS Emisor_Municipio   ,
              T3.FN_TRIM_CFDI(              
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Soc.Estado ) )                AS Emisor_Estado      ,
              T3.FN_TRIM_CFDI( Soc.Pais          )                AS Emisor_Pais        ,
              T3.FN_TRIM_CFDI( Soc.Codigo_Postal )                AS Emisor_CodigoPostal,
--            T3.FN_TRIM_CFDI( 
--               LPAD( Alm.Almacen_codigoPostal, 5, '0' )  )      AS LugarExpedicion    ,
              T3.FN_TRIM_CFDI( 
                 LPAD( NVL( Alm.Almacen_codigoPostal, Soc.Codigo_Postal ),  
                                                 5, '0' )  )      AS Emisor_Expedicion  ,
              Alm.Almacen_Lugar_Expide                            AS Emisor_LugarExpide ,
              Cte.RegimenFiscal                                   AS Regimen_Fiscal_Cte ,
              T3.FN_TRIM_CFDI( Cte.Tax_Exempt_Num )               AS Recibe_RFC         ,
              T3.FN_TRIM_CFDI( Cte.Name           )               AS Recibe_Nombre      ,
              T3.FN_TRIM_CFDI( Bill_Addr          )               AS Recibe_Calle       ,
              ''                                                  AS Recibe_NoExterior  ,
              ''                                                  AS Recibe_NoInterior  ,
              T3.FN_TRIM_CFDI( Bill_Addr_Line_2   )               AS Recibe_Colonia     ,
              ''                                                  AS Recibe_Localidad   ,
              ''                                                  AS Recibe_Referencia  ,
              T3.FN_TRIM_CFDI( Bill_City          )               AS Recibe_Municipio   ,
--            T3.FN_TRIM_CFDI( Bill.State         )               AS Recibe_Estado      ,
              T3.FN_TRIM_CFDI( 
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Bill_State  ) )               AS Recibe_Estado      ,
              DECODE (UPPER(T3.FN_TRIM_CFDI( Bill_Country)),
                           'MX','Mexico',
                            T3.FN_TRIM_CFDI( Bill_Country)    )   AS Recibe_Pais        , 
              T3.FN_TRIM_CFDI( 
                    LPAD( NVL( Bill_ZipCode, '99999' )
                                      , 5, '0' )  )               AS Recibe_codigoPostal,
              ''                                                  AS Recibe_PaisReside  ,
              ''                                                  AS Recibe_RegTributa  ,
--
              T3.FN_TRIM_CFDI( Ship_Addr          )               AS Remite_Calle       ,
              T3.FN_TRIM_CFDI( Ship_Addr_Line_2   )               AS Remite_Colonia     ,
              T3.FN_TRIM_CFDI( Ship_City          )               AS Remite_Municipio   ,
              T3.FN_TRIM_CFDI( 
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Ship_State ) )                AS Remite_Estado      ,
              DECODE (UPPER(T3.FN_TRIM_CFDI( Ship_Country)),
                           'MX','Mexico',
                            T3.FN_TRIM_CFDI( Ship_Country)    )   AS Remite_Pais        , 
              T3.FN_TRIM_CFDI( 
                    LPAD( NVL( Ship_ZipCode, '99999' )
                                      , 5, '0' )  )               AS Remite_codigoPostal,
              ''                                                  AS pedidoV3           ,
              ''                                                  AS sucursalNombre     ,
              ''                                                  AS pedidoSAP          ,
              ''                                                  AS facturaSAP         ,
              EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Payment' )
                                                                  AS UsoCFDI_Payment    ,
              'PAGO'                                              AS Tipo_Documento     ,
              CFD.Ctro                                            AS CentroExpedicion   ,
              Cte.Ou_Num                                          AS Recibe_Cliente     ,
              Cte.Ou_Num                                          AS Remite_Cliente     ,
              Cte.Pr_Con_ID                                       AS eMail              ,
              Cte.UsoCFDI                                         AS UsoCFDI            ,
--
              'CPAGO'                                             AS tagCPAGO           ,
              CFD.Numero_Pago                                     AS Numero_Pago        ,
--            TO_CHAR( CFD.Fecha_Asignacion, 'DDMMYYYYHH24MISS' ) AS Fecha_Pago         ,
              TO_CHAR( CFD.Fecha_Asignacion, 'DDMMYYYY' ) || 
              EAI_Owner.getConv( 'CFG Settings', 'Payment Default Time' )
                                                                  AS Fecha_Pago         ,
              CFD.Via_Pago                                        AS Forma_Pago         ,
              'MXN'                                               AS Moneda_Pago        ,
              '1.00'                                              AS Tipo_Cambio_Pago   ,
              TRIM( TO_CHAR( NVL( CFD.Importe, 0 ), '9999999990.99' ) ) 
                                                                  AS Importe_Pago       ,
--            CFD.Numero_Cheque                                   AS Numero_Cheque      , 
--            CFD.Banco_Nombre                                    AS Origen_Banco       ,
              ''                                                  AS Numero_Cheque      , 
              ''                                                  AS Origen_Banco       ,
              ''                                                  AS Banco_Extranjero   ,
--            CFD.Banco_Num_Cuenta                                AS Origen_Num_Cuenta  ,
              ''                                                  AS Origen_Num_Cuenta  ,
              CFD.Receptor_Banco                                  AS Destino_RFC_Banco  ,
              CFD.Receptor_Cuenta                                 AS Destino_Num_Cuenta ,
              ''                                                  AS Tipo_Cadena_Pago   ,
              ''                                                  AS Certificado_Pago   ,
              ''                                                  AS Cad_Original_Pago  ,
              ''                                                  AS Sello_Digital_Pago ,
--
              'CPAGODIR'                                          AS tagCPAGODR         ,
              CFD.UUID_Venta                                      AS ID_Documento       ,
              SUBSTR( CFD.Factura, 1, 
                  INSTR( CFD.Factura, '-' ) - 1 )                 AS Serie_Venta        ,
              TRIM( 
              SUBSTR( CFD.Factura, 
                  INSTR( CFD.Factura, '-' ) + 1, 20 ) )           AS Folio_Venta        ,     
              EAI_Owner.getConv( 'CFG Settings', 'Metodo Pago' )
                                                                  AS metodo_Pago        ,                     

              CFD.Numero_Pago                                     AS Parcialidad        ,
              TRIM( TO_CHAR( NVL( CFD.Saldo_Anterior, 0 ), '9999999999.99' ) ) 
                                                                  AS Saldo_Anterior     ,   
              CFD.Factura                                         AS FacturaPagada      ,
--
-- Marian Gonzalez  13.11.2017
--       Enviar importe pagado
--            TRIM( TO_CHAR( ( NVL( CFD.Abono_Pagos, 0 ) + NVL( CFD.Abono_CM, 0 ) )
--                   , '9999999999.99' ) )                        AS Importe_Abonado    ,
              TRIM( TO_CHAR( ( NVL( CFD.Importe, 0 ) )
                   , '9999999999.99' ) ) 
                                                                  AS Importe_Abonado    ,
              TRIM( TO_CHAR( NVL( CFD.Saldo_Anterior, 0 ) - NVL( CFD.Importe, 0 ), '9999999999.99' ) ) 
                                                                  AS Saldo_Final              
          FROM T3.CFDI_Cobranza       CFD ,
               T3.Distribuidor_Fiscal DF  ,
              (
                  SELECT 
--                       Cte.Row_ID                          AS Row_ID            , 
                         Cte.Cliente_SAP                     AS Ou_Num            , 
                         CteX.Email                          AS Pr_Con_ID         ,
                         Cte.Cliente_SAP                     AS Integration_ID    ,
                         Cte.RFC                             AS Tax_Exempt_Num    ,
                         NVL( RS.Razon_Social, Cte.Nombre )  AS Name              ,                         
                         CteX.X_Route_Ref_1                  AS X_Route_Ref_1     ,
                         Cte.Metodo_Pago                     AS Pay_Type_CD       ,
                         NVL( Reg.Regimen_Fiscal,
--                       NVL( CteX.Regimen_Fiscal,
                             EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal Cliente' ) ) 
                                                             AS RegimenFiscal      ,
                         NVL( Uso.UsoCFDI,                                   
                             NVL( UsoC.Uso_Venta,
                             EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Comercial' ) ) )
                                                             AS UsoCFDI           ,                         
--
                         CteX.X_EM_Field_18                  AS CteX_X_EM_Field_18,
                         CteX.Attrib_34                      AS CteX_Attrib_34    ,
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
                      AND Cte.RFC              = Uso.RFC(+)
                      AND Cte.RFC              = CP.RFC(+)
                      AND Cte.RFC              = RS.RFC(+)
              )                       Cte ,
               EAI.ZSDFE_Soc          Soc ,
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
                        Alm.Calle                                          AS Almacen_Calle       , 
                        Alm.Numero_Exterior                                AS Almacen_NoExterior  ,
                        ''                                                 AS Almacen_NoInterior  ,                                                      
                        Alm.Colonia                                        AS Almacen_Colonia     ,
                        T3.FN_TRIM_CFDI( Alm.Municipio         )           AS Almacen_Municipio   ,
                        T3.FN_TRIM_CFDI(                        
                           EAI_Owner.getConv( 'CFDI Estado',
                                               Alm.Estado )    )           AS Almacen_Estado      ,
                        T3.FN_TRIM_CFDI( Alm.Pais              )           AS Almacen_Pais        , 
                        T3.FN_TRIM_CFDI( Alm.CODIGO_POSTAL     )           AS Almacen_codigoPostal                  
                   FROM T3.Distribuidor_Fiscal Alm
                   WHERE Ctro LIKE 'MX%' ) Alm
          WHERE CFD.Asignacion_ID    = pFactura
          --AND AP.Fecha_Asignacion  BETWEEN Cte.Fecha_Ini_Vig and Cte.Fecha_Fin_Vig
            AND CFD.Ctro             = DF.Ctro
            AND CFD.Cliente_SAP      = Cte.Ou_Num
            AND CFD.Sociedad         = Soc.BUKRS
            AND CFD.Sociedad         = NVL( Soc.KUNNR, 'NULL' )
            AND CFD.Ctro             = Alm.Almacen_Ctro(+) ; 
--
   CURSOR ScrReenvio IS
      SELECT Folio_Fiscal, Fecha_factura
         FROM T3.CFDI_Reproceso 
         WHERE Nota_Venta = pFactura
         ORDER BY Fecha DESC ;    
--
   CURSOR ScrLock IS
      SELECT Asignacion_ID, Fecha_Envio
          FROM T3.CFDI_Cobranza
          WHERE Asignacion_ID = pFactura ; 
--
   CURSOR ScrImpuestos IS
       SELECT 
              SUM( DECODE( Tasa, 16, Valor_Subt - Desglose_IEPS, 0 ) ) AS Valor_Subt_16,
              SUM( DECODE( Tasa,  0, Valor_Subt                , 0 ) ) AS Valor_Subt_00,
              SUM( DECODE( Tasa, 16, Valor_IVA                 , 0 ) ) AS Valor_IVA_16 ,
              SUM( Desglose_IEPS )                                     AS Valor_IEPS
       FROM (       
              SELECT 
                      RFD.Material, RFD.Cantidad_Vta,
                      NVL( RFD.Valor_Subt  , 0 ) + NVL( RFD.Envio_Subt  , 0 ) + NVL( RFD.Credito_Subt, 0 )    AS Valor_Subt   ,
                      NVL( RFD.Valor_IVA   , 0 ) + NVL( RFD.Envio_IVA   , 0 ) + NVL( RFD.Credito_IVA , 0 )    AS Valor_IVA    ,
                      DECODE( NVL( RFD.Valor_IVA, 0 ), 0, 0, 16 )                                             AS Tasa         ,
                      NVL( RFD.Bonif_Subt  , 0 )                                                              AS Bonif_Subt   ,
                      NVL( RFD.Valor_IEPS  , 0 )                                                              AS Valor_IEPS   ,
                      NVL( Uso.Desglose_IEPS, 0 ) * NVL( RFD.Valor_IEPS  , 0 )                                AS Desglose_IEPS
                 FROM T3.Registro_Fiscal         RF ,
                      T3.Registro_Fiscal_Detalle RFD,
                      T3.CFDI_USOCFDI_CLIENTE    Uso
                 WHERE RF.Factura     = sFacturaPagada
                   AND RF.Factura     = RFD.Factura
                   AND RF.Cliente_SAP = Uso.Cliente_SAP(+)
             )  ;
BEGIN 
   nIVA_Calculado := 0 ;
   nDec_Calculo   := 2 ;
   nDec_Layout    := 2 ;
   strID      := pFactura ;
   IF ( pAccnt_ID IS NULL ) THEN
      SELECT MAX( Cfdi.Cliente_SAP ) INTO sAccnt_ID
         FROM T3.CFDI_Cobranza CFDI
         WHERE Cfdi.Asignacion_ID = pFactura ;
   ELSE
      sAccnt_ID  := pAccnt_ID ;
   END IF ;   
   sReturn    := '' ; 
   sCABCLIE   := '' ;
   nCount     := 00 ;
   sSepLinea  := CHR(13) || CHR(10) ;
   sSepCampo  := '|'  ;  
   sRFC       := ''   ;
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
   IF ( NVL( pOutput, 0 ) > 0 ) THEN
      DBMS_Output.Put_Line( 'Asignacion_ID ->' || pFactura  || '<-'  ) ;
      DBMS_Output.Put_Line( 'Accnt_ID      ->' || sAccnt_ID || '<-'  ) ;
   END IF ;
   FOR Chk IN ScrLock LOOP
      nCount := nCount + 1 ;
      FOR Doc IN ScrDatos LOOP
         strID              := Doc.Folio_ID          ;
         sRFC               := Doc.Recibe_RFC        ;    
         sCtro              := Doc.Ctro              ;
         sFacturaPagada     := Doc.FacturaPagada     ;
         IF ( NVL( pOutput, 0 ) > 10 ) THEN
            DBMS_Output.Put_Line( 'RFC ->' || sRFC || '<-'  ) ;
         END IF ;
--
         nAmtImporte := Doc.Importe_Abonado ;
         FOR Imp IN ScrImpuestos LOOP
            nAmtValor_Subt_16   := Imp.Valor_Subt_16 ;
            nAmtValor_Subt_00   := Imp.Valor_Subt_00 ;
            nAmtValor_IVA_16    := Imp.Valor_IVA_16  ;
            nAmtValor_IEPS      := Imp.Valor_IEPS    ;
            nPagoFactor         := nAmtImporte / ( nAmtValor_Subt_16 + nAmtValor_Subt_00 + nAmtValor_IVA_16 + nAmtValor_IEPS ) ;
            nPagoValor_IEPS     := ROUND( nAmtValor_IEPS    * nPagoFactor, 2 ) ;
            nPagoValor_IVA_16   := ROUND( nAmtValor_IVA_16  * nPagoFactor, 2 ) ;
            nPagoValor_Subt_00  := ROUND( nAmtValor_Subt_00 * nPagoFactor, 2 ) ;
            nPagoValor_Subt_16  := nAmtImporte - nPagoValor_IEPS - nPagoValor_IVA_16 - nPagoValor_Subt_00 ;
            IF ( NVL( pOutput, 0 ) > 0 ) THEN
               DBMS_Output.Put_Line( 'Inicial            : ' || nPagoValor_Subt_16  ) ;
            END IF ;
            IF ( nAmtValor_IVA_16 = nPagoValor_IVA_16 ) THEN
               nPagoValor_IVA_Calc := nPagoValor_IVA_16 ;
            ELSE
               nPagoValor_IVA_Calc := ROUND( nPagoValor_Subt_16 * 0.16, 2 ) ;
            END IF ;   
            nPagoValor_Subt_16  := nPagoValor_Subt_16 + ( nPagoValor_IVA_16 - nPagoValor_IVA_Calc ) ;
            IF ( NVL( pOutput, 0 ) > 0 ) THEN
               DBMS_Output.Put_Line( 'AmtValor_Subt_16   : ' || nAmtValor_Subt_16   ) ;
               DBMS_Output.Put_Line( 'AmtValor_Subt_00   : ' || nAmtValor_Subt_00   ) ;
               DBMS_Output.Put_Line( 'AmtValor_IVA_16    : ' || nAmtValor_IVA_16    ) ;
               DBMS_Output.Put_Line( 'AmtValor_IEPS      : ' || nAmtValor_IEPS      ) ;
               DBMS_Output.Put_Line( 'AmtImporte         : ' || nAmtImporte         ) ;
               DBMS_Output.Put_Line( 'PagoFactor         : ' || nPagoFactor         ) ;
               DBMS_Output.Put_Line( 'PagoValor_IEPS     : ' || nPagoValor_IEPS     ) ;
               DBMS_Output.Put_Line( 'PagoValor_IVA_16   : ' || nPagoValor_IVA_16   ) ;
               DBMS_Output.Put_Line( 'nPagoValor_IVA_Calc: ' || nPagoValor_IVA_Calc ) ;
               DBMS_Output.Put_Line( 'PagoValor_Subt_00  : ' || nPagoValor_Subt_00  ) ;
               DBMS_Output.Put_Line( 'PagoValor_Subt_16  : ' || nPagoValor_Subt_16  ) ;
            END IF ;
            IF ( nPagoValor_IVA_16 != nPagoValor_IVA_Calc ) THEN
               nPagoValor_IVA_16 := nPagoValor_IVA_Calc ;
               IF ( NVL( pOutput, 0 ) > 0 ) THEN
                  DBMS_Output.Put_Line( 'IVA Ajustado' ) ;
               END IF ;
            END IF ;   
         END LOOP ;
--
         uCABCLIE  := uCABCLIE  || 'CABPAGOS'                                        || sSepCampo ;
         uCABCLIE  := uCABCLIE  || Doc.VersionCFDI                                   || sSepCampo ;   -- 02 Version
         uCABCLIE  := uCABCLIE  || Doc.Serie                                         || sSepCampo ;   -- 03 Serie
         uCABCLIE  := uCABCLIE  || Doc.Folio                                         || sSepCampo ;   -- 04 Folio
         uCABCLIE  := uCABCLIE  || Doc.Fecha_Comprobante                             || sSepCampo ;   -- 05 Fecha Comprobante
         uCABCLIE  := uCABCLIE  || Doc.Regimen_Fiscal                                || sSepCampo ;   -- 06 Emisor Regimen Fiscal
         uCABCLIE  := uCABCLIE  || Doc.Emisor_RFC                                    || sSepCampo ;   -- 07 Emisor RFC
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Nombre                                 || sSepCampo ;   -- 08 Emisor Nombre
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Calle                                  || sSepCampo ;   -- 09 Emisor Calle
         uCABCLIE  := uCABCLIE  || Doc.Emisor_NoExterior                             || sSepCampo ;   -- 10 Emisor Num Exterior
         uCABCLIE  := uCABCLIE  || Doc.Emisor_NoInterior                             || sSepCampo ;   -- 11 Emisor Num Interior
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Colonia                                || sSepCampo ;   -- 12 Emisor Colonia
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Localidad                              || sSepCampo ;   -- 13 Emisor Localidad
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Referencia                             || sSepCampo ;   -- 14 Emisor Refeencia
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Municipio                              || sSepCampo ;   -- 15 Emisor Ciudad
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Estado                                 || sSepCampo ;   -- 16 Emisor Estado
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Pais                                   || sSepCampo ;   -- 17 Emisor Pais
         uCABCLIE  := uCABCLIE  || Doc.Emisor_codigoPostal                           || sSepCampo ;   -- 18 Emisor Codigo Postal
         uCABCLIE  := uCABCLIE  || Doc.Emisor_Expedicion                             || sSepCampo ;   -- 19 Expedicion Codigo Postal
         uCABCLIE  := uCABCLIE  || Doc.Recibe_RFC                                    || sSepCampo ;   -- 20 Receptor RFC
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Nombre                                 || sSepCampo ;   -- 21 Receptor Nombre
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Calle                                  || sSepCampo ;   -- 22 Receptor Calle
         uCABCLIE  := uCABCLIE  || Doc.Recibe_NoExterior                             || sSepCampo ;   -- 23 Receptor Num Exterior
         uCABCLIE  := uCABCLIE  || Doc.Recibe_NoInterior                             || sSepCampo ;   -- 24 Receptor Num Interior
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Colonia                                || sSepCampo ;   -- 25 Receptor Colonia
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Localidad                              || sSepCampo ;   -- 26 Receptor Localidad
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Referencia                             || sSepCampo ;   -- 27 Receptor Referencia
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Municipio                              || sSepCampo ;   -- 28 Receptor Ciudad
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Estado                                 || sSepCampo ;   -- 29 Receptor Estado
         uCABCLIE  := uCABCLIE  || Doc.Recibe_Pais                                   || sSepCampo ;   -- 30 Receptor Pais
         uCABCLIE  := uCABCLIE  || Doc.Recibe_codigoPostal                           || sSepCampo ;   -- 31 Receptor Codigo Postal
         uCABCLIE  := uCABCLIE  || Doc.Recibe_PaisReside                             || sSepCampo ;   -- 32 Receptor Pais Residencia 
         uCABCLIE  := uCABCLIE  || Doc.Recibe_RegTributa                             || sSepCampo ;   -- 33 Receptor ID Tributario
         uCABCLIE  := uCABCLIE  || ''                                                || sSepCampo ;   -- 34 Confirmacion PAC
         uCABCLIE  := uCABCLIE  || Doc.eMail                                         || sSepCampo ;   -- 35 Destino BM
         uCABCLIE  := uCABCLIE  || Doc.Regimen_Fiscal_Cte                            || sSepCampo ;   -- 36 Receptr Regimen Fiscal
         uCABCLIE  := uCABCLIE  || Doc.UsoCFDI_Payment                               || sSepCampo ;   -- 37 Uso de CFDI
         uCABCLIE  := uCABCLIE  || ''                                                || sSepCampo ;   -- 38 Total Impuestos Retenidos de IVA
         uCABCLIE  := uCABCLIE  || ''                                                || sSepCampo ;   -- 39 Total Impuestos Retenidos de ISR
         uCABCLIE  := uCABCLIE  || ''                                                || sSepCampo ;   -- 40 Total Impuestos Retenidos de IEPS
         IF ( nPagoValor_Subt_16 > 0 ) THEN
            uCABCLIE  := uCABCLIE  || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_16 , 2 )  || sSepCampo ;   -- 41 Total Base de IVA Trasladado de Tasa 16%
            nPagoValor_IVA_16 := ROUND( nPagoValor_Subt_16 * 0.16, 2 ) ;
            uCABCLIE  := uCABCLIE  || FN_NUM_TO_CHAR_CFDI( nPagoValor_IVA_16  , 2 )  || sSepCampo ;   -- 42 Total Impuestos de IVA Trasladado de Tasa 16%
         ELSE
            uCABCLIE  := uCABCLIE  || ''                                             || sSepCampo ;   -- 41 Total Base de IVA Trasladado de Tasa 16%
            uCABCLIE  := uCABCLIE  || ''                                             || sSepCampo ;   -- 42 Total Impuestos de IVA Trasladado de Tasa 16%
         END IF ;
         uCABCLIE  := uCABCLIE  || ''                                                || sSepCampo ;   -- 43 Total Base de IVA Trasladado de Tasa 8%
         uCABCLIE  := uCABCLIE  || ''                                                || sSepCampo ;   -- 44 Total Impuestos de IVA Trasladado de Tasa 8%
         IF ( nPagoValor_Subt_00 > 0 ) THEN
            uCABCLIE  := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_00, 2 )    || sSepCampo ;   -- 45 Total Base de IVA Trasladado de Tasa 0%
            uCABCLIE  := uCABCLIE || '0.00'                                          || sSepCampo ;   -- 46 Total Impuestos de IVA Trasladado de Tasa 0%
         ELSE         
            uCABCLIE  := uCABCLIE || ''                                              || sSepCampo ;   -- 45 Total Base de IVA Trasladado de Tasa 0%
            uCABCLIE  := uCABCLIE || ''                                              || sSepCampo ;   -- 46 Total Impuestos de IVA Trasladado de Tasa 0%
         END IF ;            
         uCABCLIE  := uCABCLIE  || ''                                                || sSepCampo ;   -- 47 Total Base de IVA Exento
         uCABCLIE  := uCABCLIE  || FN_NUM_TO_CHAR_CFDI( Doc.Importe_Abonado, 2 )     || sSepCampo ;   -- 48 Total de Pagos
         uCABCLIE  := uCABCLIE  || sSepLinea ;
--
         uCABCLIE := uCABCLIE || 'CABCLIE'               || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Recibe_Nombre       || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Remite_Calle        || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Remite_Colonia      || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Remite_Municipio    || sSepCampo ;
         uCABCLIE := uCABCLIE || ''                      || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Remite_Estado       || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Remite_Pais         || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Remite_codigoPostal || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.pedidoV3            || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.sucursalNombre      || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.pedidoSAP           || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.facturaSAP          || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Tipo_Documento      || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.CentroExpedicion    || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Recibe_Cliente      || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Remite_Cliente      || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Emisor_LugarExpide  || sSepCampo ;
         uCABCLIE := uCABCLIE || ''                      || sSepCampo ;
         uCABCLIE := uCABCLIE || sLeyMenor               || sSepCampo ;
         uCABCLIE := uCABCLIE || sLeyPriv                || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.eMail               || sSepCampo ;
         uCABCLIE := uCABCLIE || sSepLinea ;         
--
         sCFDIREL := '' ;
         FOR Env IN ScrReenvio LOOP 
            sCFDIREL := 'CFDIREL' || sSepCampo || Env.Folio_Fiscal || sSepCampo || sSepLinea ;         
         END LOOP ;      
         uCABCLIE := uCABCLIE || sCFDIREL ;   
--
         uCABCLIE := uCABCLIE || 'CPAGO'                 || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Numero_Pago         || sSepCampo ;         -- 02 Numero Pago
         uCABCLIE := uCABCLIE || Doc.Fecha_Pago          || sSepCampo ;         -- 03 Fecha Pago
         uCABCLIE := uCABCLIE || Doc.Forma_Pago          || sSepCampo ;         -- 04 Forma Pago
         uCABCLIE := uCABCLIE || Doc.Moneda_Pago         || sSepCampo ;         -- 05 Moneda
         uCABCLIE := uCABCLIE || '1'                     || sSepCampo ;         -- 06 Tipo de Cambio
         uCABCLIE := uCABCLIE || Doc.Importe_Pago        || sSepCampo ;         -- 07 Importe Pago
         uCABCLIE := uCABCLIE || Doc.Numero_Cheque       || sSepCampo ;         -- 08 Numero Cheque
         uCABCLIE := uCABCLIE || Doc.Origen_Banco        || sSepCampo ;         -- 09 Origen Banco
         uCABCLIE := uCABCLIE || Doc.Banco_Extranjero    || sSepCampo ;         -- 10 Banco Extranjero
         uCABCLIE := uCABCLIE || Doc.Origen_Num_Cuenta   || sSepCampo ;         -- 11 Origen Cuenta
         uCABCLIE := uCABCLIE || ''                      || sSepCampo ;         -- 12 Destino RFC Banco
         uCABCLIE := uCABCLIE || ''                      || sSepCampo ;         -- 13 Destino Num Cuente
         uCABCLIE := uCABCLIE || Doc.Tipo_Cadena_Pago    || sSepCampo ;         -- 14 Tipo Cadena Pago
         uCABCLIE := uCABCLIE || Doc.Certificado_Pago    || sSepCampo ;         -- 15 Certificado Pago
         uCABCLIE := uCABCLIE || Doc.Cad_Original_Pago   || sSepCampo ;         -- 16 Cadena Original
         uCABCLIE := uCABCLIE || Doc.Sello_Digital_Pago  || sSepCampo ;         -- 17 Sello Digital
         uCABCLIE := uCABCLIE || sSepLinea ;
--
         uCABCLIE := uCABCLIE || 'CPAGODR'                                      || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.Numero_Pago                                || sSepCampo ;         -- 02 Numero Pago
         uCABCLIE := uCABCLIE || Doc.ID_Documento                               || sSepCampo ;         -- 03 UUID Documento
         uCABCLIE := uCABCLIE || Doc.Serie_Venta                                || sSepCampo ;         -- 04 Serie Documento
         uCABCLIE := uCABCLIE || Doc.Folio_Venta                                || sSepCampo ;         -- 05 Folio Documento
         uCABCLIE := uCABCLIE || Doc.Moneda_Pago                                || sSepCampo ;         -- 06 Moneda
         uCABCLIE := uCABCLIE || '1'                                            || sSepCampo ;         -- 07 Tipo de Cambio
         uCABCLIE := uCABCLIE || Doc.Metodo_Pago                                || sSepCampo ;         -- 08 Metodo de Pago
         uCABCLIE := uCABCLIE || Doc.Parcialidad                                || sSepCampo ;         -- 09 Parcialidad
         uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( Doc.Saldo_Anterior , 2 )  || sSepCampo ;         -- 10 Saldo Anterior
         uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( Doc.Importe_Abonado, 2 )  || sSepCampo ;         -- 11 Importe
         uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( Doc.Saldo_Final    , 2 )  || sSepCampo ;         -- 12 Saldo Nuevo
         uCABCLIE := uCABCLIE || ''                                             || sSepCampo ;         -- 13 Objeto Impuesto
--
         IF ( nPagoValor_Subt_16 > 0 ) THEN
            uCABCLIE := uCABCLIE || sSepLinea ;
            uCABCLIE := uCABCLIE || 'IMPUESTOSDR'                                  || sSepCampo ;
            uCABCLIE := uCABCLIE || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_16, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uCABCLIE := uCABCLIE || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uCABCLIE := uCABCLIE || 'Tasa'                                         || sSepCampo ;         -- 05 Tasa o Cuota
            uCABCLIE := uCABCLIE || '0.160000'                                     || sSepCampo ;         -- 06 Tipo Factor de Impuesto
--          uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_16 * 0.16
--                                                                         , 6 )   || sSepCampo ;         -- 07 Importe del Impuesto
            nIVA_Calculado := ROUND( nPagoValor_Subt_16 * 0.16, nDec_Calculo ) ;
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nIVA_Calculado
                                                                 , nDec_Layout )   || sSepCampo ;         -- 07 Importe del Impuesto
         END IF ;                                                                  
         IF ( nPagoValor_Subt_00 > 0 ) THEN
            uCABCLIE := uCABCLIE || sSepLinea ;
            uCABCLIE := uCABCLIE || 'IMPUESTOSDR'                                  || sSepCampo ;
            uCABCLIE := uCABCLIE || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_00, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uCABCLIE := uCABCLIE || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uCABCLIE := uCABCLIE || 'Tasa'                                         || sSepCampo ;         -- 05 Tasa o Cuota
            uCABCLIE := uCABCLIE || '0.000000'                                     || sSepCampo ;         -- 06 Tipo Factor de Impuesto
            uCABCLIE := uCABCLIE || '0.000000'                                     || sSepCampo ;         -- 07 Importe del Impuesto
         END IF ;                                                                  
      END LOOP ;         
--
         IF ( nPagoValor_Subt_16 > 0 ) THEN
            uCABCLIE := uCABCLIE || sSepLinea ;
            uCABCLIE := uCABCLIE || 'IMPUESTOSP'                                   || sSepCampo ;
            uCABCLIE := uCABCLIE || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_16, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uCABCLIE := uCABCLIE || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uCABCLIE := uCABCLIE || 'Tasa'                                         || sSepCampo ;         -- 06 Tasa o Cuota
            uCABCLIE := uCABCLIE || '0.160000'                                     || sSepCampo ;         -- 05 Tipo Factor de Impuesto
--          uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_16 * 0.16
--                                                                         , 6 )   || sSepCampo ;         -- 07 Importe del Impuesto
            nIVA_Calculado := ROUND( nPagoValor_Subt_16 * 0.16, nDec_Calculo ) ;
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nIVA_Calculado
                                                                 , nDec_Layout )   || sSepCampo ;         -- 07 Importe del Impuesto                                                                           
         END IF ;                                                                  
         IF ( nPagoValor_Subt_00 > 0 ) THEN
            uCABCLIE := uCABCLIE || sSepLinea ;
            uCABCLIE := uCABCLIE || 'IMPUESTOSP'                                   || sSepCampo ;
            uCABCLIE := uCABCLIE || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_00, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uCABCLIE := uCABCLIE || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uCABCLIE := uCABCLIE || 'Tasa'                                         || sSepCampo ;         -- 06 Tasa o Cuota
            uCABCLIE := uCABCLIE || '0.000000'                                     || sSepCampo ;         -- 05 Tipo Factor de Impuesto
            uCABCLIE := uCABCLIE || '0.000000'                                     || sSepCampo ;         -- 07 Importe del Impuesto
         END IF ;                                                                  

   END LOOP ;
   IF ( nCount = 0 ) THEN
         IF ( NVL( pOutput, 0 ) > 0 ) THEN
            DBMS_Output.Put_Line( 'Cobranza con Bloqueo'  ) ;
         END IF ;      
   END IF ;         
--
   IF ( LENGTH( sRFC ) > 10 ) THEN
      sReturn := sReturn || uCABCLIE || sSepLinea ;      
      sData   := sReturn ;
      INSERT INTO T3.CFDI_DOCUMENTOS_ENVIAR ( Nota_Venta, Informacion )
         VALUES ( pFactura, sData ) ;
      INSERT INTO T3.CFDI_Documentos ( Nota_Venta, Ctro, Fecha_Liberacion )
         VALUES ( pFactura, sCtro, SYSDATE ) ;   
      UPDATE T3.CFDI_Cobranza SET Fecha_Envio = SYSDATE
         WHERE Asignacion_ID    = pFactura ;
   ELSE
         IF ( NVL( pOutput, 0 ) > 0 ) THEN
            DBMS_Output.Put_Line( pFactura || '_' || sAccnt_ID || ' - Archivo NO Generado'  ) ;
            DBMS_Output.Put_Line( 'RFC ->' || sRFC || '<-'  ) ;
         END IF ;         
   END IF ;      
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_GENERAR_PAGO' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'PROC_CFDI_GENERAR_PAGO', strID, sMsg ) ;
      COMMIT ;
END ;
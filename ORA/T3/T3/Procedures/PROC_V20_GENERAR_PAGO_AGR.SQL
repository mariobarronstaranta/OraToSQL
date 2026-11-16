create or replace PROCEDURE    "PROC_V20_GENERAR_PAGO_AGR" 
  ( pFactura        IN NUMBER,
    pOutput         IN NUMBER   DEFAULT 0 ) 
IS
   strID                VARCHAR2(0030) ;
   strStage             VARCHAR2(0030) ;
   sMsg                 VARCHAR2(0500) ;   
   sCtro                VARCHAR2(0004) ;   
----   
   sReturn              CLOB           ;    
   uLINPAGOS            CLOB           ;
   uCABCLIE             VARCHAR2(4000) ;
-- sLINFAC              VARCHAR2(4000) ;
   sLeyMenor            VARCHAR2(4000) ;
   sLeyPriv             VARCHAR2(4000) ;
   sSepLinea            VARCHAR2(0004) ;
   sSepCampo            VARCHAR2(0004) ;
   sFactura             VARCHAR2(0030) ;
   sRecibe_RFC          VARCHAR2(0030) ;
   sRFC                 VARCHAR2(0030) ;
   sAccnt_ID            VARCHAR2(0040) ;
   sAddenda             VARCHAR2(0002) ;
   nLineas              NUMBER(06)     ;
   sData                CLOB           ;
   sCFDIREL             VARCHAR2(2000) ;
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
   sFacturaPagada       VARCHAR2(040)  ;
   nAcumValor_Subt_16   NUMBER(24,6)   ;
   nAcumValor_Subt_00   NUMBER(24,6)   ;
   nAcumValor_IVA_16    NUMBER(24,6)   ;
   nAcumValor_IVA_164D  NUMBER(24,6)   ;
   nAcumValor_IEPS      NUMBER(24,6)   ;
   nAcumImp_Abonado     NUMBER(24,6)   ;
--
   nAcumImp_Calculado   NUMBER(24,6)   ; 
   nIVA_Calculado       NUMBER(24,6)   ;
   nDec_Calculo         NUMBER(3)      ;
   nDec_Layout          NUMBER(3)      ;   
--
   CURSOR ScrDatos IS
       SELECT
              TRIM( TO_CHAR( CFD.Folio_ID ) )                     AS Folio_ID           ,
              CFD.Ctro                                            AS Ctro               ,
--                                   
              'CPAGOS'                                            AS tagCPAGOS          ,
              '2.0'                                               AS VersionCFDI        ,
              'CTRL'                                              AS Serie              ,
              CFD.Folio_ID                                        AS Folio              ,
--            TO_CHAR( CFD.Fecha_Asignacion, 'DDMMYYYYHH24MISS' ) AS Fecha_Comprobante  ,
              TO_CHAR( SYSDATE, 'DDMMYYYYHH24MISS' )              AS Fecha_Comprobante  ,
              EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal' ) 
                                                                  AS Regimen_Fiscal     ,
              NVL( Reg.Regimen_Fiscal,
                 EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal Cliente' ) )
                                                                  AS Regimen_Fiscal_Cte ,
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
                                    Soc.Estado )   )              AS Emisor_Estado      ,
              T3.FN_TRIM_CFDI( Soc.Pais            )              AS Emisor_Pais        ,
              T3.FN_TRIM_CFDI( Soc.Codigo_Postal   )              AS Emisor_CodigoPostal,
--            T3.FN_TRIM_CFDI( 
--               LPAD( Alm.Almacen_codigoPostal, 5, '0' )  )      AS LugarExpedicion    ,
              '64000'                                             AS Emisor_Expedicion  ,
              'Monterrey, N.L.'                                   AS Emisor_LugarExpide ,                                                 
              T3.FN_TRIM_CFDI( Cte.RFC            )               AS Recibe_RFC         ,
              TRIM( NVL( RS.Razon_Social, Cte.Nombre ) )          AS Recibe_Nombre      ,
              T3.FN_TRIM_CFDI( Cte.Direccion_3    )               AS Recibe_Calle       ,
              ''                                                  AS Recibe_NoExterior  ,
              ''                                                  AS Recibe_NoInterior  ,
              T3.FN_TRIM_CFDI( Cte.Colonia_3      )               AS Recibe_Colonia     ,
              ''                                                  AS Recibe_Localidad   ,
              ''                                                  AS Recibe_Referencia  ,
              T3.FN_TRIM_CFDI( Cte.Ciudad_3       )               AS Recibe_Municipio   ,
--            T3.FN_TRIM_CFDI( Bill.State         )               AS Recibe_Estado      ,
              T3.FN_TRIM_CFDI( 
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Cte.Estado_3  ) )             AS Recibe_Estado      ,
              DECODE (UPPER(T3.FN_TRIM_CFDI( Cte.Pais_3)),
                           'MX','Mexico',
                            T3.FN_TRIM_CFDI( Cte.Pais_3)    )     AS Recibe_Pais        , 
              T3.FN_TRIM_CFDI(  
                    LPAD( NVL( NVL( CP.CP, Cte.Codigo_Postal_3 ), '99999' )
                                      , 5, '0' )  )               AS Recibe_codigoPostal,
              ''                                                  AS Recibe_PaisReside  ,
              ''                                                  AS Recibe_RegTributa  ,
--
              T3.FN_TRIM_CFDI( Cte.Direccion_2    )               AS Remite_Calle       ,
              T3.FN_TRIM_CFDI( Cte.Colonia_2      )               AS Remite_Colonia     ,
              T3.FN_TRIM_CFDI( Cte.Ciudad_2       )               AS Remite_Municipio   ,
              T3.FN_TRIM_CFDI( 
                 EAI_Owner.getConv( 'CFDI Estado',
                                    Cte.Estado_2 ) )              AS Remite_Estado      ,
              DECODE (UPPER(T3.FN_TRIM_CFDI( Cte.Pais_2)),
                           'MX','Mexico',
                            T3.FN_TRIM_CFDI( Cte.Pais_2)    )     AS Remite_Pais        , 
              T3.FN_TRIM_CFDI( 
                    LPAD( NVL( Cte.Codigo_Postal_2, '99999' )
                                      , 5, '0' )  )               AS Remite_codigoPostal,
              ''                                                  AS pedidoV3           ,
              ''                                                  AS sucursalNombre     ,
              ''                                                  AS pedidoSAP          ,
              CFD.Asignacion_Central                              AS facturaSAP         ,
              EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Payment' )
                                                                  AS UsoCFDI_Payment    ,              
              'PAGO'                                              AS Tipo_Documento     ,
              CFD.Ctro                                            AS CentroExpedicion   ,
              Cte.Cliente_SAP                                     AS Recibe_Cliente     ,
              Cte.Cliente_SAP                                     AS Remite_Cliente     ,
--              T3.FN_MAIL_CONTACTO( Cte.Pr_Con_ID )                AS eMail              ,
              Mail.eMail                                          AS eMail              ,
--
              'CPAGO'                                             AS tagCPAGO           ,
              CFD.Numero_Pago                                     AS Numero_Pago        ,
--            TO_CHAR( CFD.Fecha_Asignacion, 'DDMMYYYYHH24MISS' ) AS Fecha_Pago         ,
              TO_CHAR( CFD.Fecha_Asignacion, 'DDMMYYYY' ) || 
              EAI_Owner.getConv( 'CFG Settings', 'Payment Default Time' )     
                                                                  AS Fecha_Pago         ,         
              CFD.Via_Pago                                        AS Forma_Pago         ,
              'MXN'                                               AS Moneda_Pago        ,
              ''                                                  AS Tipo_Cambio_Pago   ,
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
              ''                                                  AS Sello_Digital_Pago            
          FROM 
               --T3.CFDI_Cobranza       CFD ,
               (
                 SELECT Agr.Via_Pago, Agr.RFC, 
                        Agr.Banco_Nombre, Agr.Banco_Num_Cuenta, Agr.Importe, Agr.Cantidad_Pagos, Agr.Cliente_SAP,
                        Agr.Agrupacion                                                AS Asignacion_ID     ,
                        Agr.Agrupacion                                                AS Folio_ID          ,
                        Agr.Fecha_Pago                                                AS Fecha_Asignacion  ,
--                      'MXAB'                                                        AS Ctro              ,
                        NVL( T3.FN_CTRO_EDICOM_PAGO( Agr.Cliente_SAP ), 'MXAB' )      AS Ctro              ,
                        'MX16'                                                        AS Sociedad          ,
                        1                                                             AS Numero_Pago       ,
                        ''                                                            AS Numero_Cheque     ,
                        EAI_Owner.getConv( 'CFG Settings', 'Banco Def - Central'  )   AS Receptor_Banco    ,
                        EAI_Owner.getConv( 'CFG Settings', 'Cuenta Def - Central'  )  AS Receptor_Cuenta   ,
                        NVL( Agr.Asignacion_Central, '' )                             AS Asignacion_Central
                    FROM T3.CFDI_Agrupacion_CTRL Agr
                    WHERE Agr.Agrupacion = pFactura
               )                      CFD ,
               T3.Mov_Cliente         Cte ,
               T3.TMD_EMAIL           Mail,
               EAI.ZSDFE_Soc          Soc ,
                          ( SELECT RFC, MAX( Valor ) AS Regimen_Fiscal
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'RegimenFiscal'
                                GROUP BY RFC ) Reg,                  
                          ( SELECT RFC, MAX( Valor ) AS Razon_Social
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'Nombre'
                                GROUP BY RFC ) RS,                
                          ( SELECT RFC, MAX( Valor ) AS CP
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'CodigoPostal' 
                                GROUP BY RFC ) CP,                                
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
          WHERE CFD.Cliente_SAP      = Cte.Cliente_SAP
            AND Cte.Cliente_SAP      = Mail.Cliente_SAP(+) 
            AND Cte.RFC              = Reg.RFC(+)
            AND Cte.RFC              = RS.RFC(+)            
            AND Cte.RFC              = CP.RFC(+)
          --AND CFD.Fecha_Asignacion BETWEEN Cte.FECHA_INI_VIG and FECHA_FIN_VIG
            AND CFD.Sociedad         = Soc.BUKRS
            AND CFD.Sociedad         = NVL( Soc.KUNNR, 'NULL' )
            AND CFD.Ctro             = Alm.Almacen_Ctro(+) ; 
--
   CURSOR ScrDetallePagos IS
       SELECT
              'CPAGODIR'                                          AS tagCPAGODR         ,
              CFD.Factura                                         AS Factura            ,
              CFD.UUID_Venta                                      AS ID_Documento       ,
              SUBSTR( CFD.Factura, 1, 
                  INSTR( CFD.Factura, '-' ) - 1 )                 AS Serie_Venta        ,
              TRIM( 
              SUBSTR( CFD.Factura, 
                  INSTR( CFD.Factura, '-' ) + 1, 20 ) )           AS Folio_Venta        ,     
              EAI_Owner.getConv( 'CFG Settings', 'Metodo Pago' )
                                                                  AS metodo_Pago        ,                     
              'MXN'                                               AS Moneda_Pago        ,
              TRIM( TO_CHAR( CFD.Numero_Pago, '9999999' ) )       AS Parcialidad        ,
              TRIM( TO_CHAR( NVL( CFD.Saldo_Anterior, 0 ), '9999999999999.99' ) ) 
                                                                  AS Saldo_Anterior     ,                            
              TRIM( TO_CHAR( ( NVL( CFD.Importe, 0 ) )
                   , '9999999999999.99' ) ) 
                                                                  AS Importe_Abonado    ,
              TRIM( TO_CHAR( NVL( CFD.Saldo_Anterior, 0 ) - NVL( CFD.Importe, 0 ), '9999999999999.99' ) ) 
                                                                  AS Saldo_Final                
          FROM T3.CFDI_AGRUPACION_PAGO Agr,
               T3.CFDI_Cobranza        CFD
          WHERE Agr.Agrupacion    = pFactura
            AND Agr.Asignacion_ID = CFD.Asignacion_ID
          ORDER BY Agr.Asignacion_ID ;                     
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
--
   CURSOR ScrReenvio IS
      SELECT Folio_Fiscal, Fecha_factura
         FROM T3.CFDI_Reproceso 
         WHERE Nota_Venta = sFactura
         ORDER BY Fecha DESC ;    
BEGIN 
   strID      := pFactura ;
   sReturn    := '' ; 
   sSepLinea  := CHR(13) || CHR(10) ;
   sSepCampo  := '|'  ;
   sAddenda   := 'NO' ;  
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
   nAcumValor_Subt_16   := 0 ;
   nAcumValor_Subt_00   := 0 ;
   nAcumValor_IVA_16    := 0 ;
   nAcumValor_IVA_164D  := 0 ;
   nAcumValor_IEPS      := 0 ;
   nAcumImp_Abonado     := 0 ;
   nIVA_Calculado       := 0 ;
   nAcumImp_Calculado   := 0 ;
   nDec_Calculo         := 2 ;
   nDec_Layout          := 2 ;
   strStage := 'ScrDatos' ;
   FOR Doc IN ScrDatos LOOP
      sFactura           := Doc.Folio_ID          ; 
      sRFC               := Doc.Recibe_RFC        ;
      sRecibe_RFC        := Doc.Recibe_RFC        ;       
      sCtro              := Doc.Ctro              ;
--
      nLineas  := 00 ;
      sCFDIREL := '' ;
      strStage  := 'CFDIREL' ;
      FOR Env IN ScrReenvio LOOP 
         nLineas := nLineas + 1 ;
         IF ( nLineas = 1 ) THEN
            sCFDIREL := 'CFDIREL' || sSepCampo || Env.Folio_Fiscal || sSepCampo || sSepLinea ;         
         END IF ;
      END LOOP ;    
--      
      strStage  := 'ScrDetallePagos' ;
      nLineas   := 00 ;
      uLINPAGOS := '' ;
      FOR Det IN ScrDetallePagos LOOP
         nLineas        := nLineas + 1 ;
         sFacturaPagada := Det.Factura ;
         IF ( nLineas > 1 ) THEN
            uLINPAGOS := uLINPAGOS || sSepLinea ;   
         END IF ;
         uLINPAGOS := uLINPAGOS || 'CPAGODR'                                      || sSepCampo ;
         uLINPAGOS := uLINPAGOS || TRIM( TO_CHAR( nLineas ) )                     || sSepCampo ;         -- 02 Numero Pago
         uLINPAGOS := uLINPAGOS || Det.ID_Documento                               || sSepCampo ;         -- 03 UUID Documento
         uLINPAGOS := uLINPAGOS || Det.Serie_Venta                                || sSepCampo ;         -- 04 Serie Documento
         uLINPAGOS := uLINPAGOS || Det.Folio_Venta                                || sSepCampo ;         -- 05 Folio Documento
         uLINPAGOS := uLINPAGOS || Det.Moneda_Pago                                || sSepCampo ;         -- 06 Moneda
         uLINPAGOS := uLINPAGOS || '1'                                            || sSepCampo ;         -- 07 Tipo de Cambio
         uLINPAGOS := uLINPAGOS || Det.Metodo_Pago                                || sSepCampo ;         -- 08 Metodo de Pago
         uLINPAGOS := uLINPAGOS || Det.Parcialidad                                || sSepCampo ;         -- 09 Parcialidad
         uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( Det.Saldo_Anterior , 2 )  || sSepCampo ;         -- 10 Saldo Anterior
         uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( Det.Importe_Abonado, 2 )  || sSepCampo ;         -- 11 Importe
         uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( Det.Saldo_Final    , 2 )  || sSepCampo ;         -- 12 Saldo Nuevo
         uLINPAGOS := uLINPAGOS || ''                                             || sSepCampo ;         -- 13 Objeto Impuesto
--
         nAmtImporte := Det.Importe_Abonado ;
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
--
            IF ( nAmtValor_IVA_16 = nPagoValor_IVA_16 ) THEN
               nPagoValor_IVA_Calc := nPagoValor_IVA_16 ;
            ELSE
               nPagoValor_IVA_Calc := ROUND( nPagoValor_Subt_16 * 0.16, 2 ) ;
            END IF ;
--            
            nPagoValor_Subt_16  := nPagoValor_Subt_16 + ( nPagoValor_IVA_16 - nPagoValor_IVA_Calc ) ;
            IF ( NVL( pOutput, 0 ) > 10 ) THEN
               DBMS_Output.Put_Line( Det.Serie_Venta || '-' || Det.Folio_Venta ) ;
               DBMS_Output.Put_Line( 'AmtValor_Subt_16   : ' || nAmtValor_Subt_16   ) ;
               DBMS_Output.Put_Line( 'AmtValor_Subt_00   : ' || nAmtValor_Subt_00   ) ;
               DBMS_Output.Put_Line( 'AmtValor_IVA_16    : ' || nAmtValor_IVA_16    ) ;
               DBMS_Output.Put_Line( 'AmtValor_IEPS      : ' || nAmtValor_IEPS      ) ;
               DBMS_Output.Put_Line( 'AmtImporte         : ' || nAmtImporte         ) ;
               DBMS_Output.Put_Line( 'PagoFactor         : ' || nPagoFactor         ) ;
               DBMS_Output.Put_Line( 'PagoValor_IEPS     : ' || nPagoValor_IEPS     ) ;
               DBMS_Output.Put_Line( 'PagoValor_IVA_16   : ' || nPagoValor_IVA_16   ) ;
               DBMS_Output.Put_Line( 'PagoValor_Subt_00  : ' || nPagoValor_Subt_00  ) ;
               DBMS_Output.Put_Line( 'PagoValor_Subt_16  : ' || nPagoValor_Subt_16  ) ;
            END IF ;
            IF ( nPagoValor_IVA_16 != nPagoValor_IVA_Calc ) THEN
               nPagoValor_IVA_16 := nPagoValor_IVA_Calc ;
               IF ( NVL( pOutput, 0 ) > 10 ) THEN
                  DBMS_Output.Put_Line( 'IVA Ajustado' ) ;
               END IF ;
            END IF ;   
         END LOOP ;
         IF ( nPagoValor_Subt_16 > 0 ) THEN
            uLINPAGOS := uLINPAGOS || sSepLinea ;
            uLINPAGOS := uLINPAGOS || 'IMPUESTOSDR'                                  || sSepCampo ;
            uLINPAGOS := uLINPAGOS || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_16, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uLINPAGOS := uLINPAGOS || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uLINPAGOS := uLINPAGOS || 'Tasa'                                         || sSepCampo ;         -- 05 Tasa o Cuota
            uLINPAGOS := uLINPAGOS || '0.160000'                                     || sSepCampo ;         -- 06 Tipo Factor de Impuesto
--          uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_16 * 0.16
--                                                                           , 6 )   || sSepCampo ;         -- 07 Importe del Impuesto
--          nAcumValor_IVA_164D := nAcumValor_IVA_164D + ( nPagoValor_Subt_16 * 0.16 ) ;
--
            nIVA_Calculado := ROUND( nPagoValor_Subt_16 * 0.16, nDec_Calculo ) ;
--          nIVA_Calculado := nPagoValor_IVA_Calc ;
            uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nIVA_Calculado
                                                                   , nDec_Layout )   || sSepCampo ;         -- 07 Importe del Impuesto
            nAcumValor_IVA_164D := nAcumValor_IVA_164D + nIVA_Calculado ;
            nAcumImp_Calculado  := nAcumImp_Calculado  + nIVA_Calculado ;
         END IF ;                                                                  
         IF ( nPagoValor_Subt_00 > 0 ) THEN
            uLINPAGOS := uLINPAGOS || sSepLinea ;
            uLINPAGOS := uLINPAGOS || 'IMPUESTOSDR'                                  || sSepCampo ;
            uLINPAGOS := uLINPAGOS || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nPagoValor_Subt_00, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uLINPAGOS := uLINPAGOS || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uLINPAGOS := uLINPAGOS || 'Tasa'                                         || sSepCampo ;         -- 05 Tasa o Cuota
            uLINPAGOS := uLINPAGOS || '0.000000'                                     || sSepCampo ;         -- 06 Tipo Factor de Impuesto
            uLINPAGOS := uLINPAGOS || '0.000000'                                     || sSepCampo ;         -- 07 Importe del Impuesto
         END IF ;
--
         nAcumValor_Subt_16   := nAcumValor_Subt_16 + nPagoValor_Subt_16 ;
         nAcumValor_Subt_00   := nAcumValor_Subt_00 + nPagoValor_Subt_00 ;
         nAcumValor_IVA_16    := nAcumValor_IVA_16  + nPagoValor_IVA_16  ;
         nAcumValor_IEPS      := nAcumValor_IEPS    + nPagoValor_IEPS    ;
         nAcumImp_Abonado     := nAcumImp_Abonado   + nAmtImporte        ;
      END LOOP ;                                                                -- Loop de Pagos
--      
         uCABCLIE := uCABCLIE || 'CABPAGOS'                                       || sSepCampo ;
         uCABCLIE := uCABCLIE || Doc.VersionCFDI                                  || sSepCampo ;   -- 02 Version
         uCABCLIE := uCABCLIE || Doc.Serie                                        || sSepCampo ;   -- 03 Serie
         uCABCLIE := uCABCLIE || Doc.Folio                                        || sSepCampo ;   -- 04 Folio
         uCABCLIE := uCABCLIE || Doc.Fecha_Comprobante                            || sSepCampo ;   -- 05 Fecha Comprobante
         uCABCLIE := uCABCLIE || Doc.Regimen_Fiscal                               || sSepCampo ;   -- 06 Emisor Regimen Fiscal
         uCABCLIE := uCABCLIE || Doc.Emisor_RFC                                   || sSepCampo ;   -- 07 Emisor RFC
         uCABCLIE := uCABCLIE || Doc.Emisor_Nombre                                || sSepCampo ;   -- 08 Emisor Nombre
         uCABCLIE := uCABCLIE || Doc.Emisor_Calle                                 || sSepCampo ;   -- 09 Emisor Calle
         uCABCLIE := uCABCLIE || Doc.Emisor_NoExterior                            || sSepCampo ;   -- 10 Emisor Num Exterior
         uCABCLIE := uCABCLIE || Doc.Emisor_NoInterior                            || sSepCampo ;   -- 11 Emisor Num Interior
         uCABCLIE := uCABCLIE || Doc.Emisor_Colonia                               || sSepCampo ;   -- 12 Emisor Colonia
         uCABCLIE := uCABCLIE || Doc.Emisor_Localidad                             || sSepCampo ;   -- 13 Emisor Localidad
         uCABCLIE := uCABCLIE || Doc.Emisor_Referencia                            || sSepCampo ;   -- 14 Emisor Refeencia
         uCABCLIE := uCABCLIE || Doc.Emisor_Municipio                             || sSepCampo ;   -- 15 Emisor Ciudad
         uCABCLIE := uCABCLIE || Doc.Emisor_Estado                                || sSepCampo ;   -- 16 Emisor Estado
         uCABCLIE := uCABCLIE || Doc.Emisor_Pais                                  || sSepCampo ;   -- 17 Emisor Pais
         uCABCLIE := uCABCLIE || Doc.Emisor_codigoPostal                          || sSepCampo ;   -- 18 Emisor Codigo Postal
         uCABCLIE := uCABCLIE || Doc.Emisor_Expedicion                            || sSepCampo ;   -- 19 Expedicion Codigo Postal
         uCABCLIE := uCABCLIE || Doc.Recibe_RFC                                   || sSepCampo ;   -- 20 Receptor RFC
         uCABCLIE := uCABCLIE || Doc.Recibe_Nombre                                || sSepCampo ;   -- 21 Receptor Nombre
         uCABCLIE := uCABCLIE || Doc.Recibe_Calle                                 || sSepCampo ;   -- 22 Receptor Calle
         uCABCLIE := uCABCLIE || Doc.Recibe_NoExterior                            || sSepCampo ;   -- 23 Receptor Num Exterior
         uCABCLIE := uCABCLIE || Doc.Recibe_NoInterior                            || sSepCampo ;   -- 24 Receptor Num Interior
         uCABCLIE := uCABCLIE || Doc.Recibe_Colonia                               || sSepCampo ;   -- 25 Receptor Colonia
         uCABCLIE := uCABCLIE || Doc.Recibe_Localidad                             || sSepCampo ;   -- 26 Receptor Localidad
         uCABCLIE := uCABCLIE || Doc.Recibe_Referencia                            || sSepCampo ;   -- 27 Receptor Referencia
         uCABCLIE := uCABCLIE || Doc.Recibe_Municipio                             || sSepCampo ;   -- 28 Receptor Ciudad
         uCABCLIE := uCABCLIE || Doc.Recibe_Estado                                || sSepCampo ;   -- 29 Receptor Estado
         uCABCLIE := uCABCLIE || Doc.Recibe_Pais                                  || sSepCampo ;   -- 30 Receptor Pais
         uCABCLIE := uCABCLIE || Doc.Recibe_codigoPostal                          || sSepCampo ;   -- 31 Receptor Codigo Postal
         uCABCLIE := uCABCLIE || Doc.Recibe_PaisReside                            || sSepCampo ;   -- 32 Receptor Pais Residencia 
         uCABCLIE := uCABCLIE || Doc.Recibe_RegTributa                            || sSepCampo ;   -- 33 Receptor ID Tributario
         uCABCLIE := uCABCLIE || ''                                               || sSepCampo ;   -- 34 Confirmacion PAC
         uCABCLIE := uCABCLIE || Doc.eMail                                        || sSepCampo ;   -- 35 Destino BM
         uCABCLIE := uCABCLIE || Doc.Regimen_Fiscal_Cte                           || sSepCampo ;   -- 36 Receptr Regimen Fiscal
         uCABCLIE := uCABCLIE || Doc.UsoCFDI_Payment                              || sSepCampo ;   -- 37 Uso de CFDI
         uCABCLIE := uCABCLIE || ''                                               || sSepCampo ;   -- 38 Total Impuestos Retenidos de IVA
         uCABCLIE := uCABCLIE || ''                                               || sSepCampo ;   -- 39 Total Impuestos Retenidos de ISR
         uCABCLIE := uCABCLIE || ''                                               || sSepCampo ;   -- 40 Total Impuestos Retenidos de IEPS
         IF ( nAcumValor_Subt_16 > 0 ) THEN
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nAcumValor_Subt_16 , 2 ) || sSepCampo ;   -- 41 Total Base de IVA Trasladado de Tasa 16%
            nAcumValor_IVA_164D := ROUND( nAcumValor_Subt_16 * 0.16, 2 ) ;
--          uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nAcumValor_IVA_164D, 2 ) || sSepCampo ;   -- 42 Total Impuestos de IVA Trasladado de Tasa 16%
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nAcumImp_Calculado , 2 ) || sSepCampo ;   -- 42 Total Impuestos de IVA Trasladado de Tasa 16%
         ELSE
            uCABCLIE := uCABCLIE || ''                                            || sSepCampo ;   -- 41 Total Base de IVA Trasladado de Tasa 16%
            uCABCLIE := uCABCLIE || ''                                            || sSepCampo ;   -- 42 Total Impuestos de IVA Trasladado de Tasa 16%
         END IF ;
         uCABCLIE := uCABCLIE || ''                                               || sSepCampo ;   -- 43 Total Base de IVA Trasladado de Tasa 8%
         uCABCLIE := uCABCLIE || ''                                               || sSepCampo ;   -- 44 Total Impuestos de IVA Trasladado de Tasa 8%
         IF ( nAcumValor_Subt_00 > 0 ) THEN
            uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nAcumValor_Subt_00, 2 )  || sSepCampo ;  -- 45 Total Base de IVA Trasladado de Tasa 0%
            uCABCLIE := uCABCLIE || '0.00'                                        || sSepCampo ;  -- 46 Total Impuestos de IVA Trasladado de Tasa 0%
         ELSE
            uCABCLIE := uCABCLIE || ''                                            || sSepCampo ;  -- 45 Total Base de IVA Trasladado de Tasa 0%
            uCABCLIE := uCABCLIE || ''                                            || sSepCampo ;  -- 46 Total Impuestos de IVA Trasladado de Tasa 0%
         END IF ;
         uCABCLIE := uCABCLIE || ''                                               || sSepCampo ;   -- 47 Total Base de IVA Exento
         uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( nAcumImp_Abonado, 2 )       || sSepCampo ;   -- 48 Total de Pagos
--       uCABCLIE := uCABCLIE || FN_NUM_TO_CHAR_CFDI( 
--                  ROUND( nAcumValor_Subt_16 + nAcumValor_IVA_164D, 2 ), 2 )     || sSepCampo ;   -- 48 Total de Pagos
         uCABCLIE := uCABCLIE || sSepLinea ;
         IF ( NVL( pOutput, 0 ) > 0 ) THEN
            DBMS_Output.Put_Line( 'nAcumImp_Abonado     : ' || nAcumImp_Abonado     ) ;
            DBMS_Output.Put_Line( 'nAcumValor_Subt_16   : ' || nAcumValor_Subt_16   ) ;
            DBMS_Output.Put_Line( 'nAcumValor_IVA_164D  : ' || nAcumValor_IVA_164D  ) ;
            DBMS_Output.Put_Line( 'Doc.Importe_Pago     : ' || Doc.Importe_Pago     ) ;
            DBMS_Output.Put_Line( 'Acum_Subt + Acum_IVA : ' || ROUND( nAcumValor_Subt_16 + nAcumValor_IVA_164D, 2 ) ) ;
         END IF ;
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
         uCABCLIE := uCABCLIE || sSepLinea                            ;
--
         IF ( LENGTH( sCFDIREL ) > 10 ) THEN
            uCABCLIE := uCABCLIE || sCFDIREL ;
         END IF ;
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
         uCABCLIE := uCABCLIE || sSepLinea                            ;
--
         IF ( NVL( pOutput, 0 ) > 0 ) THEN
            DBMS_Output.Put_Line( 'Base Total : ' || nAcumValor_Subt_16  ) ;
            DBMS_Output.Put_Line( 'Importe    : ' || nAcumImp_Calculado  ) ;
         END IF ;
--
         IF ( nAcumValor_Subt_16 > 0 ) THEN
            uLINPAGOS := uLINPAGOS || sSepLinea ;
            uLINPAGOS := uLINPAGOS || 'IMPUESTOSP'                                   || sSepCampo ;
            uLINPAGOS := uLINPAGOS || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nAcumValor_Subt_16, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uLINPAGOS := uLINPAGOS || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uLINPAGOS := uLINPAGOS || 'Tasa'                                         || sSepCampo ;         -- 06 Tasa o Cuota
            uLINPAGOS := uLINPAGOS || '0.160000'                                     || sSepCampo ;         -- 05 Tipo Factor de Impuesto
--          uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nAcumValor_Subt_16 * 0.16
--                                                                           , 6 )   || sSepCampo ;         -- 07 Importe del Impuesto
--          nIVA_Calculado := ROUND( nAcumValor_Subt_16 * 0.16, nDec_Calculo ) ;
            uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nAcumImp_Calculado
                                                                   , nDec_Layout )   || sSepCampo ;         -- 07 Importe del Impuesto
         END IF ;                                                                  
         IF ( nAcumValor_Subt_00 > 0 ) THEN
            uLINPAGOS := uLINPAGOS || sSepLinea ;
            uLINPAGOS := uLINPAGOS || 'IMPUESTOSP'                                   || sSepCampo ;
            uLINPAGOS := uLINPAGOS || 'T'                                            || sSepCampo ;         -- 02 Calificador de Impuesto
            uLINPAGOS := uLINPAGOS || FN_NUM_TO_CHAR_CFDI( nAcumValor_Subt_00, 6 )   || sSepCampo ;         -- 03 Base Imponible
            uLINPAGOS := uLINPAGOS || '002'                                          || sSepCampo ;         -- 04 Tipo de Impuesto
            uLINPAGOS := uLINPAGOS || 'Tasa'                                         || sSepCampo ;         -- 06 Tasa o Cuota
            uLINPAGOS := uLINPAGOS || '0.000000'                                     || sSepCampo ;         -- 05 Tipo Factor de Impuesto
            uLINPAGOS := uLINPAGOS || '0.000000'                                     || sSepCampo ;         -- 07 Importe del Impuesto
         END IF ;  
   END LOOP ; 
--
   IF ( LENGTH( uCABCLIE ) > 10 ) THEN
      strStage := 'Final'  ;
      sReturn  := uCABCLIE ;
      sData    := sReturn  ;
      sData    := CONCAT( sData, uLINPAGOS ) ;
      INSERT INTO T3.CFDI_DOCUMENTOS_ENVIAR ( Nota_Venta, Informacion )
         VALUES ( pFactura, sData ) ;
      INSERT INTO T3.CFDI_Documentos ( Nota_Venta, Ctro, Fecha_Liberacion )
         VALUES ( pFactura, sCtro, SYSDATE ) ;
      UPDATE T3.CFDI_Agrupacion_CTRL SET Fecha_Envio = SYSDATE, Ctro = sCtro
         WHERE Agrupacion = pFactura ;
   END IF ;                
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_V20_GENERAR_PAGO_AGR' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID || '-' || strStage ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'PROC_V20_GENERAR_PAGO_AGR', strID, sMsg ) ;
      COMMIT ;   
END ;
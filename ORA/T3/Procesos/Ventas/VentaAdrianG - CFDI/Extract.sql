SELECT 'FACTURA,DOC_FACTURA,ENTREGA,FECHA_FACTURA,TIPODOCTO,NOMBRE,RFC,CLIENTE_SAP,NOTA_VENTA_CFDI,FECHA_ENVIO,FECHA_TIMBRE,FOLIO_FISCAL,SUBTOTAL,VALOR_IVA,ENVIO_SUBTOTAL,ENVIO_IVA,CREDITO_SUBTOTAL,CREDITO_IVA,TOTAL,INCOBRABLE_NC'
   FROM DUAL
UNION ALL
SELECT 
DOC.FACTURA 		|| ',' || 
''''||DOC.FACTURA 	|| ',' || 
DOC.ENTREGA		|| ',' ||  
TO_CHAR(DOC.FECHA_FACTURA,'DD/MM/YYYY') 	|| ',' || 
DOC.TIPO_DOCTO		|| ',' || 
DOC.NOMBRE		|| ',' || 
DOC.RFC			|| ',' ||  
DOC.CLIENTE_SAP		|| ',' ||  
DOC.NOTA_VENTA_CFDI	|| ',' ||  
TO_CHAR(DOC.FECHA_ENVIO,'DD/MM/YYYY HH24:MI:SS') 	|| ',' ||
TO_CHAR(DOC.FECHA_TIMBRE,'DD/MM/YYYY HH24:MI:SS') 	|| ',' ||
DOC.FOLIO_FISCAL	|| ',' ||  
DOC.SUBTOTAL		|| ',' ||  
DOC.VALOR_IVA		|| ',' ||
DOC.ENVIO_SUBTOTAL	|| ',' ||  
DOC.ENVIO_IVA		|| ',' ||  
DOC.CREDITO_SUBTOTAL	|| ',' ||  
DOC.CREDITO_IVA		|| ',' ||  
DOC.TOTAL		|| ',' || 
NVL(INC.IMPORTE_APLICADO_INCOBRABLE, 0 ) AS INCOBRABLE_NC
FROM
(   SELECT 
        RFD.FACTURA                                 AS FACTURA,
        RF.ENTREGA                                  AS ENTREGA, 
        RF.FECHA_FACTURA                            AS FECHA_FACTURA,
        RF.TIPO_DOCTO                               AS TIPO_DOCTO,
        REPLACE(C.NOMBRE,',',' ')                                    AS NOMBRE, 
        C.RFC                                       AS RFC,
        C.CLIENTE_SAP                               AS CLIENTE_SAP, 
        PAC.NOTA_VENTA_CFDI                         AS NOTA_VENTA_CFDI, 
        CD.FECHA_ENVIO                              AS FECHA_ENVIO, 
        CD.FECHA_TIMBRE                             AS FECHA_TIMBRE, 
        CD.FOLIO_FISCAL                             AS FOLIO_FISCAL,
        PASO.VOIDDOC                                AS VOID,
        SUM(NVL(RFD.VALOR_SUBT,0))                  AS SUBTOTAL, 
        SUM(NVL(RFD.VALOR_IVA,0))                   AS VALOR_IVA,                
        SUM(NVL(RFD.ENVIO_SUBT,0))                  AS ENVIO_SUBTOTAL, 
        SUM(NVL(RFD.ENVIO_IVA,0))                   AS ENVIO_IVA, 
        SUM(NVL(RFD.CREDITO_SUBT,0))                AS CREDITO_SUBTOTAL, 
        SUM(NVL(RFD.CREDITO_IVA,0))                 AS CREDITO_IVA, 
        SUM(NVL(RFD.VALOR_SUBT,0)+ NVL(RFD.VALOR_IVA,0) +NVL(RFD.ENVIO_SUBT,0) + NVL(RFD.ENVIO_IVA,0) + NVL(RFD.CREDITO_SUBT,0) + NVL(RFD.CREDITO_IVA,0))   AS TOTAL 
        FROM T3.REGISTRO_FISCAL RF, T3.REGISTRO_FISCAL_DETALLE RFD, T3.CLIENTE C, T3.CFDI_HISTORIA_DOCTO_PAC PAC, T3.CFDI_DOCUMENTOS CD, T3.CFDI_DOCUMENTO_PASO PASO
        WHERE RF.FECHA_FACTURA >= TO_DATE ('01/02/2026','dd/mm/yyyy')
        AND RF.FECHA_FACTURA  < TO_DATE ('01/03/2026','dd/mm/yyyy')
        AND RF.FACTURA = RFD.FACTURA
        AND RF.TIPO_DOCTO IN ('C003','C005')
        AND RF.STATUS != 'Cancelled'
        AND RF.CLIENTE_SAP = C.CLIENTE_SAP
        AND RF.FECHA_FACTURA                        BETWEEN C.FECHA_INI_VIG AND C.FECHA_FIN_VIG
        AND RF.FACTURA = PAC.NOTA_VENTA (+)
        AND PAC.NOTA_VENTA_CFDI = CD.NOTA_VENTA (+)
        AND RF.FACTURA = PASO.FACTURA (+)
    GROUP BY RFD.FACTURA, RF.ENTREGA, RF.FECHA_FACTURA,RF.TIPO_DOCTO,   C.NOMBRE, C.RFC,C.CLIENTE_SAP, PAC.NOTA_VENTA_CFDI, CD.FECHA_ENVIO,CD.FECHA_TIMBRE, CD.FOLIO_FISCAL, PASO.VOIDDOC
        UNION ALL
        SELECT 
        RFD.FACTURA                                 AS FACTURA, 
        RF.ENTREGA                                  AS ENTREGA,
        RF.FECHA_FACTURA                             AS FECHA_FACTURA,
        RF.TIPO_DOCTO                               AS TIPO_DOCTO,
        REPLACE(C.NOMBRE,',',' ')                                    AS NOMBRE, 
        C.RFC                                       AS RFC,
        C.CLIENTE_SAP                               AS CLIENTE_SAP,        
        PAC.NOTA_VENTA_CFDI                         AS NOTA_VENTA_CFDI,
        CD.FECHA_ENVIO                              AS FECHA_ENVIO,
        CD.FECHA_TIMBRE                             AS FECHA_TIMBRE,
        CD.FOLIO_FISCAL                            AS FOLIO_FISCAL,
        PASO.VOIDDOC                               AS VOID,
        SUM(NVL(RFD.VALOR_SUBT,0))      *-1         AS SUBTOTAL, 
        SUM(NVL(RFD.VALOR_IVA,0))       *-1         AS VALOR_IVA,
        SUM(NVL(RFD.ENVIO_SUBT,0))      *-1         AS ENVIO_SUBTOTAL, 
        SUM(NVL(RFD.ENVIO_IVA,0))       *-1         AS ENVIO_IVA, 
        SUM(NVL(RFD.CREDITO_SUBT,0))    *-1         AS CREDITO_SUBTOTAL, 
        SUM(NVL(RFD.CREDITO_IVA,0))     *-1         AS CREDITO_IVA, 
        SUM((NVL(RFD.VALOR_SUBT,0)+ NVL(RFD.VALOR_IVA,0) +NVL(RFD.ENVIO_SUBT,0) + NVL(RFD.ENVIO_IVA,0) + NVL(RFD.CREDITO_SUBT,0) + NVL(RFD.CREDITO_IVA,0)) * -1)   AS TOTAL 
        FROM T3.REGISTRO_FISCAL RF, T3.REGISTRO_FISCAL_DETALLE RFD, T3.CLIENTE C, T3.CFDI_HISTORIA_DOCTO_PAC PAC, T3.CFDI_DOCUMENTOS CD, T3.CFDI_DOCUMENTO_PASO PASO
        WHERE RF.FECHA_FACTURA >= TO_DATE ('01/02/2026','dd/mm/yyyy')
        AND RF.FECHA_FACTURA  < TO_DATE ('01/03/2026','dd/mm/yyyy')
        AND RF.FACTURA = RFD.FACTURA
        AND RF.TIPO_DOCTO IN ('C004','C006', 'C025', 'C0FX')
        AND RF.STATUS != 'Cancelled'
        AND RF.CLIENTE_SAP = C.CLIENTE_SAP
        AND RF.FECHA_FACTURA                        BETWEEN C.FECHA_INI_VIG AND C.FECHA_FIN_VIG
        AND RF.FACTURA = PAC.NOTA_VENTA (+)
        AND PAC.NOTA_VENTA_CFDI = CD.NOTA_VENTA (+)
        AND RF.FACTURA = PASO.FACTURA (+)
        GROUP BY RFD.FACTURA, RF.ENTREGA, RF.FECHA_FACTURA,RF.TIPO_DOCTO,  C.NOMBRE,C.RFC, C.CLIENTE_SAP, PAC.NOTA_VENTA_CFDI, CD.FECHA_ENVIO,CD.FECHA_TIMBRE, CD.FOLIO_FISCAL,PASO.VOIDDOC) 
            DOC , 
            (   SELECT CC.NOTA_CREDITO AS NOTA_CREDITO, SUM (CC.IMPORTE) AS IMPORTE_APLICADO_INCOBRABLE
                FROM T3.CFDI_COBRANZA CC
                WHERE CC.FACTURA = 'INCOBRABLE'
                AND CC.VIA_PAGO = 'AI'
                AND CC.NOTA_CREDITO IS NOT NULL
                GROUP BY CC.NOTA_CREDITO) INC
        WHERE DOC.FACTURA = INC.NOTA_CREDITO (+)
                ;
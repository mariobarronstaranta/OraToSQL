create or replace PROCEDURE    "PROC_T3_OT_GENERAL" IS
--
   sFACTURA              VARCHAR2(012);  
   sPROCESAR             VARCHAR2(012);  
--
   CURSOR PREVENTAS IS
      SELECT PG.FACTURA, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA,
             NVL( PG.VALOR_SUBT, 0 ) + NVL( PG.VALOR_IVA, 0 )        AS TOTAL, 
             SUM( NVL( PD.VALOR_SUBT, 0 ) + NVL( PD.VALOR_IVA, 0 ) ) AS TOTAL_DETALLE
         FROM T3.OTROS_GENERAL PG, T3.OTROS_DETALLE PD
         WHERE PG.FECHA_TRN         > SYSDATE - 4
           AND PG.FECHA_PROC_BATMD IS NULL
           AND PG.FACTURA          =  PD.FACTURA
       GROUP BY PG.FACTURA, PG.FECHA_FACTURA, PG.FECHA_CANCELACION, PG.CLIENTE_SAP, PG.CLASE_FACTURA, NVL( PG.VALOR_SUBT, 0 ) + NVL( PG.VALOR_IVA, 0 ) ;             
--           
BEGIN
   UPDATE T3.Otros_General OG SET Fecha_Proc_BATMD = TO_DATE( '29991231', 'YYYYMMDD' )
      WHERE OG.Fecha_Trn         > SYSDATE - 4
        AND OG.Fecha_Proc_BATMD IS NULL
        AND OG.Factura IN ( SELECT DISTINCT OG.Factura
                               FROM T3.Otros_General OG, T3.Otros_Detalle OD, T3.Material Cig
                               WHERE OG.Fecha_Trn > SYSDATE - 30
                                 AND OG.Sociedad  = 'MX10'
                                 AND OG.RFC       = 'BAT030325CE9'
                                 AND OG.Factura   = OD.Factura
                                 AND OD.Material  = Cig.Material  ) ;
   COMMIT ;                           
   WA_ERR_INVOICE_PAYMETHOD(4) ;
   FOR REN IN PREVENTAS LOOP
      sPROCESAR := 'SI' ;
      sFACTURA  := REN.Factura ;
--
      IF ( ( ABS( REN.TOTAL - REN.TOTAL_DETALLE ) < 0.10 ) AND ( sPROCESAR = 'SI' ) ) THEN
--       PROC_CFDI_GENERAR_OTROS( REN.FACTURA ) ;
         PROC_V40_GENERAR_OTROS( REN.FACTURA ) ;
         UPDATE T3.OTROS_GENERAL PG SET Fecha_Proc_BATMD = SYSDATE
            WHERE Factura = REN.FACTURA ;
      END IF ;
   END LOOP ;
   COMMIT ;
END; -- Procedure
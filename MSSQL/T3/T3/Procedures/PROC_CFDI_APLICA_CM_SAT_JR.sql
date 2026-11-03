--------------------------------------------------------
--  DDL for Procedure PROC_CFDI_APLICA_CM_SAT_JR
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "T3"."PROC_CFDI_APLICA_CM_SAT_JR" 
   ( pFactura  IN  VARCHAR2 DEFAULT NULL,
     pFechaIni IN  VARCHAR2 DEFAULT TO_CHAR( SYSDATE, 'YYYY' ) || '0101',
     sPeriodo  IN  VARCHAR2 DEFAULT NULL,
     sRFC      IN  VARCHAR2 DEFAULT NULL )
IS
   sMsg                 VARCHAR2(0500) ;
   sFactura             VARCHAR2(0030) ;
   sNotaCredito         VARCHAR2(0030) ;
   sFolio_Fiscal        VARCHAR2(0040) ;
   sNota_Venta          VARCHAR2(4000) ;
   sLinea_Texto         VARCHAR2(2000) ;
   nImporte             NUMBER(18,2)   ;
--
   strID                VARCHAR2(050) ;
   sErrorCode           VARCHAR2(030) ;
   dtInicio             DATE          ;
   nPID                 NUMBER(10)    ; 
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso3            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;
   nPor_Procesar        NUMBER(08)    ;
   sFechaInicio         VARCHAR2(010) ;
--
   CURSOR ScrDocumentos IS
         SELECT RF.Factura, RF.Referencia, RF.Fecha_Factura, RF.Cliente_SAP, Cte.RFC,
                TO_CHAR( RF.Fecha_Factura, 'YYYY' ) AS Periodo
            FROM T3.Registro_Fiscal RF ,
                 T3.Cliente         Cte,
                 T3.CFDI_Documentos CFD,
                 T3.RF_Documentos   XML
            WHERE RF.Tipo_Docto    IN ( 'C004', 'C006', 'C019', 'C025' )
              AND RF.Fecha_Factura >= TO_DATE( sFechaInicio, 'YYYYMMDD' )
            --AND RF.Fecha_Factura  < TO_DATE( '20200101', 'YYYYMMDD' )
              AND RF.Cliente_SAP    = Cte.Cliente_SAP
              AND RF.Fecha_Factura  BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
              AND RF.Factura        = CFD.Nota_Venta
              AND RF.Factura        = XML.Factura
              AND Cte.RFC          != 'XAXX010101000' ;  
--
   CURSOR ScrAplicaciones IS
     SELECT       
            Extract( VALUE( Lista ) , '/cfdi:CfdiRelacionado/@UUID', 'xmlns:cfdi="http://www.sat.gob.mx/cfd/4", xmlns:xs="http://www.w3.org/2001/XMLSchema", xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"').Getstringval() AS UUID            
        FROM T3.RF_Documentos CFD,
             TABLE( XMLSequence( Extract ( Anexo_CFD, '/cfdi:Comprobante/cfdi:CfdiRelacionados/cfdi:CfdiRelacionado',
                   'xmlns:cfdi="http://www.sat.gob.mx/cfd/4", xmlns:xs="http://www.w3.org/2001/XMLSchema", xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' ) ) ) Lista
        WHERE Factura = sNotaCredito 
     UNION ALL   
     SELECT       
            Extract( VALUE( Lista ) , '/cfdi:CfdiRelacionado/@UUID', 'xmlns:cfdi="http://www.sat.gob.mx/cfd/3", xmlns:xs="http://www.w3.org/2001/XMLSchema", xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"').Getstringval() AS UUID            
        FROM T3.RF_Documentos CFD,
             TABLE( XMLSequence( Extract ( Anexo_CFD, '/cfdi:Comprobante/cfdi:CfdiRelacionados/cfdi:CfdiRelacionado',
                   'xmlns:cfdi="http://www.sat.gob.mx/cfd/3", xmlns:xs="http://www.w3.org/2001/XMLSchema", xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' ) ) ) Lista
        WHERE Factura = sNotaCredito ;   
--
   CURSOR ScrTextos IS
       SELECT (Linea).getStringVal() AS Linea
          FROM (   
                 SELECT VALUE( Lista ) AS Linea
                    FROM T3.RF_Documentos CFD,
                         TABLE( XMLSequence( Extract ( Anexo_CFD, '/cfdi:Comprobante/cfdi:Addenda/customized/BATEMISION/conceptos',
                         'xmlns="http://repository.edicomnet.com/schemas/mx/cfd/addenda" xmlns:cfdi="http://www.sat.gob.mx/cfd/4", xmlns:xs="http://www.w3.org/2001/XMLSchema", xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' ) ) ) Lista
                    WHERE Factura = sNotaCredito 
                UNION ALL
                SELECT VALUE( Lista ) AS Linea
                   FROM T3.RF_Documentos CFD,
                        TABLE( XMLSequence( Extract ( Anexo_CFD, '/cfdi:Comprobante/cfdi:Addenda/customized/BATEMISION/conceptos',
                        'xmlns="http://repository.edicomnet.com/schemas/mx/cfd/addenda" xmlns:cfdi="http://www.sat.gob.mx/cfd/3", xmlns:xs="http://www.w3.org/2001/XMLSchema", xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' ) ) ) Lista
                WHERE Factura = sNotaCredito 
             ) ;   
--
   CURSOR ScrInvoice IS
     SELECT Info.Nota_Venta
        FROM (
               SELECT Doc.Nota_Venta  , 11 AS Orden
                  FROM T3.CFDI_Documentos Doc
                  WHERE Doc.Folio_Fiscal = sFolio_Fiscal
               UNION ALL
               SELECT Repro.Nota_Venta, 01 AS Orden
                  FROM T3.CFDI_Reproceso Repro
                  WHERE Repro.Folio_Fiscal = sFolio_Fiscal
             ) Info
       ORDER BY Info.Orden ;     
--
BEGIN
   IF ( pFactura IS NOT NULL ) THEN
         sFactura     := pFactura   ;
         strID        := pFactura   ;
         sNotaCredito := pFactura   ;
               DELETE T3.CFDI_APLICA_CM_SAT
                  WHERE Nota_Credito = sNotaCredito ;
               FOR Item IN ScrAplicaciones LOOP
                  sFolio_Fiscal := Item.UUID ;
                  sNota_Venta   := '' ;
                  FOR Vta IN ScrInvoice LOOP
                     sNota_Venta := Vta.Nota_Venta ;
                  END LOOP ;
                  INSERT INTO T3.CFDI_APLICA_CM_SAT 
                     ( NOTA_CREDITO, FOLIO_FISCAL, NOTA_VENTA )
                  VALUES
                     ( sNotaCredito, sFolio_Fiscal, sNota_Venta ) ;
               END LOOP ;
               FOR Texto IN ScrTextos LOOP
                  sLinea_Texto := Texto.Linea ;
                  IF ( INSTR( sLinea_Texto, 'interno' ) = 0 ) THEN
                     SELECT 
                                     SUBSTR( Texto.Texto, Texto.PosDESCR + 7 + 18, Texto.Pos_del   - Texto.PosDESCR - 26 )            AS Factura  ,
                            DECODE( Texto.Pos_idLin, 0,
                            REPLACE( SUBSTR( Texto.Texto, Texto.Pos_por  + 4     , Texto.Pos_fin   - Texto.Pos_por  -  4 ), ',', '' ),    
                            REPLACE( SUBSTR( Texto.Texto, Texto.Pos_por  + 4     , Texto.Pos_idLin - Texto.Pos_por  -  6 ), ',', '' ) 
                                                                                                                                    ) AS Monto   
                            INTO sNota_Venta, nImporte
                        FROM (
                               SELECT sLinea_Texto                   AS Texto    ,
                                      INSTR( sLinea_Texto, 'DESCR' ) AS PosDESCR ,
                                      INSTR( sLinea_Texto, 'del'   ) AS Pos_del  ,
                                      INSTR( sLinea_Texto, 'por'   ) AS Pos_por  ,
                                      INSTR( sLinea_Texto, 'idLin' ) AS Pos_idLin,
                                      INSTR( sLinea_Texto, '"/>'   ) AS Pos_fin
                                      
                                  FROM DUAL
                             ) Texto ;     
                     DBMS_OUTPUT.PUT_LINE( sNota_Venta || ', ' || nImporte ) ;        
                     UPDATE T3.CFDI_APLICA_CM_SAT SET CM_Aplicado = nImporte
                        WHERE Nota_Credito = sNotaCredito
                          AND Nota_Venta   = sNota_Venta ;
                  END IF ;        
               END LOOP ;
   ELSE
      dtInicio  := SYSDATE ;
      nProceso  := 924 ;
      nPID      := EAI_Owner.ProcessID.NextVal ;
      EAI_Owner.Log_Start( nProceso ) ;
      INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Inicio )
         VALUES ( nPID, nProceso, SYSDATE ) ;        
      nProceso1 := 0 ;
      nProceso2 := 0 ;
      nProceso3 := 0 ;
      nProceso4 := 0 ;
      nProceso4 := TO_NUMBER( NVL( sPeriodo, '0' ) ) ;
      DBMS_OUTPUT.PUT_LINE( 'Inicio : ' || TO_CHAR( SYSDATE, 'HH24:MI:SS') ) ;
      IF ( pFechaIni IS NULL ) THEN
         sFechaInicio := TO_CHAR( SYSDATE, 'YYYYMM' ) || '01' ;
      ELSE
         sFechaInicio := pFechaIni ;
      END IF ;
      FOR Doc IN ScrDocumentos LOOP
         nProceso1     := nProceso1 + 1 ;
         sNotaCredito  := Doc.Factura   ;
         strID         := Doc.Factura   ;
         nPor_Procesar := 0             ;
         IF ( NVL( sPeriodo, Doc.Periodo ) = Doc.Periodo ) THEN
            nPor_Procesar := nPor_Procesar  + 1 ;
         END IF ;
         IF ( NVL( sRFC, Doc.RFC ) = Doc.RFC ) THEN
            nPor_Procesar := nPor_Procesar  + 1 ;
         END IF ;
         --
            IF ( nPor_Procesar > 0 ) THEN
               nProceso2 := nProceso2 + 1 ;
               DELETE T3.CFDI_APLICA_CM_SAT
                  WHERE Nota_Credito = sNotaCredito ;
               FOR Item IN ScrAplicaciones LOOP
                  sFolio_Fiscal := Item.UUID ;
                  sNota_Venta   := '' ;
                  FOR Vta IN ScrInvoice LOOP
                     sNota_Venta := Vta.Nota_Venta ;
                  END LOOP ;
                  INSERT INTO T3.CFDI_APLICA_CM_SAT 
                     ( NOTA_CREDITO, FOLIO_FISCAL, NOTA_VENTA )
                  VALUES
                     ( sNotaCredito, sFolio_Fiscal, sNota_Venta ) ;
               END LOOP ;
            END IF ;   
         --
         IF ( MOD( nProceso1, 500 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
         WHERE Component = nProceso ;
      UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                    Proceso_3 = nProceso3, Proceso_4 = nProceso4
          WHERE PID = nPID  ;        
      DBMS_OUTPUT.PUT_LINE( 'Documentos   ' || nProceso1    ) ;
      DBMS_OUTPUT.PUT_LINE( 'Por procesar ' || nProceso2    ) ;
      DBMS_OUTPUT.PUT_LINE( 'Periodo      ' || sPeriodo     ) ;
      DBMS_OUTPUT.PUT_LINE( 'RFC Cliente  ' || sRFC         ) ;
      DBMS_OUTPUT.PUT_LINE( 'Inicio al    ' || sFechaInicio ) ;
      DBMS_OUTPUT.PUT_LINE( 'Final : ' || TO_CHAR( SYSDATE, 'HH24:MI:SS') ) ;
      COMMIT ;
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
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_APLICA_CM_SAT' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                  , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                 , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT                , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                      , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CFDI_APLICA_CM_SAT'  , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                       , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CFDI_APLICA_CM_SAT_JR ;

/

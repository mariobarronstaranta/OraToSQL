create or replace PROCEDURE           WA_DEPURA_MESSAGE_LOG
   ( pDias    IN  NUMBER DEFAULT 4,
     pOutput  IN  NUMBER DEFAULT 1 )
IS
   sMsg            VARCHAR2(500) ;   
   sRow_ID         VARCHAR2(030) ;
   sErrorCode      VARCHAR2(020) ;
   nRegistros      NUMBER(10)    ;
   sCalcular       VARCHAR2(030) ;
   sMes            VARCHAR2(030) ;
   sCentro         VARCHAR2(004) ;
   nPID            NUMBER(08)    ;
   nProceso        NUMBER(08)    ;   
   nProceso4       NUMBER(08)    ;
--
   CURSOR ErrReceivePayment IS
       SELECT Info.Err_ROWID, Info.Created,
              CASE
                 WHEN ( Info.CloseDocType > 0 ) THEN SUBSTR( Info.Message, Info.CloseDocType - 2, 2 ) 
                 ELSE
                  '  '
              END   AS DocumentType
       FROM (
              SELECT Err.ROWID                                              AS Err_ROWID    ,
                     Err.Created                                            AS Created      ,
                     CAST( SUBSTR( Message, 1, 2000 ) AS VARCHAR2(2000) )   AS Message      ,
                     INSTR( SUBSTR( Message, 1, 2000 ), '</DocumentType>' ) AS CloseDocType
                 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG Err
                 WHERE Created     > TRUNC( SYSDATE - pDias )
                   AND Direction   = 'Receive'
                   AND Queue_Name  = 'Payment'
                   AND Status     != 'Processed'
             ) Info     ;
--
   CURSOR ErrTaOPaymentInbound IS
       SELECT Info.Err_RowID, Info.Reference_Send, Cobza.Factura
       FROM (
              SELECT Send.Reference                          AS Reference_Send,
                     ELog.RowID                              AS Err_ROWID     ,
                     ELog.Created                            AS Created
              FROM EAI_Owner.MX_EAI_Message_Log    ELog, 
                   EAI_Owner.MX_Send_Message_Log   Send
              WHERE ELog.Created     > TRUNC( SYSDATE - pDias ) 
                AND ELog.Status     != 'Processed'
                AND ELog.Reference   = Send.Row_ID(+)
                AND ELog.Queue_Name  = 'TaO Payment Inbound'
            ) Info,
            (
              SELECT 
                     NVL( PG.Factura, AccHead.ReferenceDocNumber ) AS Factura
              FROM ( 
                     SELECT ReferenceDocNumber              AS ReferenceDocNumber,
                            ClearingDocNumber               AS ClearingDocNumber ,
                            TRUNC( Created )                AS Created           ,
                            COUNT( IDocNumber )             AS Count_Send
                        FROM EAI_Owner.tmp_Account_Header
                        WHERE Created > TRUNC( SYSDATE - pDias )
                          AND Status  = 'Sent'
                        GROUP BY ReferenceDocNumber, ClearingDocNumber, TRUNC( Created )
                        HAVING COUNT( IDocNumber ) > 1
                   ) AccHead,
                   T3.Preventa_General PG
              WHERE AccHead.ReferenceDocNumber = PG.Referencia(+)     
           ) Cobza
       WHERE Info.Reference_Send = Cobza.Factura ;       
--
   CURSOR ErrInsertingT3 IS
       SELECT Info.Err_RowID, Info.Reference_Send, FG.Factura
       FROM (
              SELECT Send.Reference                          AS Reference_Send,
                     ELog.RowID                              AS Err_ROWID     ,
                     ELog.ID                                 AS FG_Row_ID     ,
                     ELog.Created                            AS Created
              FROM EAI_Owner.MX_EAI_Message_Log    ELog, 
                   EAI_Owner.MX_Send_Message_Log   Send
              WHERE ELog.Created     > TRUNC( SYSDATE - pDias ) 
                AND ELog.Status     != 'Processed'
                AND ELog.Reference   = Send.Row_ID(+)
                AND ELog.Direction   = 'Inserting'
                AND ELog.Queue_Name  = 'Invoice'
           ) Info,
           (
             SELECT Factura, Row_ID 
                FROM T3.Factura_General 
                WHERE Fecha_Trn > TRUNC( SYSDATE - pDias )    
           ) FG
       WHERE Info.FG_Row_ID = FG.Row_ID ;
--
   CURSOR ErrBankDeposit_I IS
       SELECT Info.Err_RowID, Info.DocNumber
       FROM (
              SELECT Send.Reference                          AS Reference_Send,
                     ELog.RowID                              AS Err_ROWID     ,
                     ELog.Created                            AS Created       ,
                     ELog.Reference                          AS DocNumber
              FROM EAI_Owner.MX_EAI_Message_Log    ELog, 
                   EAI_Owner.MX_Send_Message_Log   Send
              WHERE ELog.Created     > TRUNC( SYSDATE - pDias ) 
                AND ELog.Status     != 'Processed'
                AND ELog.Reference   = Send.Row_ID(+)
                AND ELog.Queue_Name  = 'PROC_CENTRAL_PAYMENT'
            ) Info,
            (
                     SELECT DISTINCT
                            ClearingDocNumber               AS ClearingDocNumber 
                        FROM EAI_Owner.tmp_Account_Header
                        WHERE Created       > TRUNC( SYSDATE - pDias )
                          AND DocumentType  = 'BK'
           ) BK
       WHERE Info.DocNumber = BK.ClearingDocNumber 
       UNION ALL
       SELECT Info.Err_RowID, Recv.DocNum
       FROM (
              SELECT Send.Reference                          AS Reference_Send,
                     ELog.RowID                              AS Err_ROWID     ,
                     ELog.Created                            AS Created       ,
                     ELog.Reference                          AS ROW_ID
              FROM EAI_Owner.MX_EAI_Message_Log    ELog, 
                   EAI_Owner.MX_Send_Message_Log   Send
              WHERE ELog.Created     > TRUNC( SYSDATE - pDias ) 
                AND ELog.Status     != 'Processed'
                AND ELog.Reference   = Send.Row_ID(+)
                AND ELog.Queue_Name  = 'PROC_CENTRAL_PAYMENT'
            ) Info,
            EAI_Owner.MX_Receive_Message_Log Recv
       WHERE Info.ROW_ID = Recv.Row_ID   
         AND extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/DocumentType' ) = 'BK' ;                           
--
   CURSOR ErrT3RF_Error_Log IS
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.Registro_Fiscal RF
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'PROC_CFDI_INSERTAR_IFC'
         AND Err.Referencia = RF.Factura
       UNION ALL
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.CFDI_Documentos CFD
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'GENERAR_MX06'
         AND Err.Referencia = CFD.Nota_Venta
       UNION ALL
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.CFDI_Documentos CFD
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'GENERAR_AGR'
         AND Err.Referencia = CFD.Nota_Venta
       UNION ALL
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.RF_Complemento CFD
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'Proc_T3_CFD_Complemento'
         AND Err.Referencia = CFD.Factura         
       UNION ALL
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.CFDI_Documentos CFD
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'PROC_CFDI_GENERAR_REMISION'
         AND Err.Referencia = CFD.Nota_Venta     
       UNION ALL
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.CFDI_Documentos CFD
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'PROC_CFDI_GENERAR_OTROS'
         AND Err.Referencia = CFD.Nota_Venta     
       UNION ALL
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.CFDI_Documentos CFD
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'PROC_V40_GENERAR_MX06'
         AND Err.Referencia = CFD.Nota_Venta     
       UNION ALL
       SELECT Err.ROWID    AS Err_ROWID, Err.*
       FROM T3.RF_Error_Log Err, T3.CFDI_Documentos CFD
       WHERE Err.Fecha      > TRUNC( SYSDATE - pDias )
         AND Err.Rutina     = 'PROC_CFDI_GENERAR_MX06'
         AND Err.Referencia = CFD.Nota_Venta ; 
--
   CURSOR ErrT3Bitacora_Error IS
       SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje
       FROM T3.Bitacora_Error BE
       WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
         AND Mensaje LIKE 'EL CLIENTE: PC-00-%'
       UNION ALL
       SELECT DISTINCT Info.Err_ROWID, Info.Fecha, Info.Mensaje
          FROM (
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        SUBSTR( Err.Mensaje, 102 , 
                                Err.PosPagoID - 103 )       AS Cliente_SAP
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje,
                               INSTR( BE.Mensaje, 'Pago_ID' ) AS PosPagoID
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE '<Proc_T3_Pagos> El Cliente SAP no existe en Historia_Cliente_SAP en Interfase de pagos Cliente_Sap%'
                      ) Err    
                 WHERE Err.PosPagoID > 0     
              ) Info,
              T3.Historia_Cliente_SAP HCP
          WHERE Info.Cliente_SAP = HCP.Cliente_SAP
       UNION ALL
       SELECT Info.Err_ROWID, Info.Fecha, Info.Mensaje
          FROM (
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        SUBSTR( Err.Mensaje, Err.PosIgual + 2,  20 )  AS Factura
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje,
                               INSTR( BE.Mensaje, '=', 1, 3 )     AS PosIgual
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE '<Proc_T3_Factura> El Cliente SAP es Nulo en la interfase de Facturas Distribuidor%'
                      ) Err    
                 WHERE Err.PosIgual > 0     
              ) Info,
              T3.Factura_General FG
          WHERE Info.Factura = FG.Factura
            AND TO_CHAR( NVL( FG.Fecha_Proc_BATMD, SYSDATE + 366 ), 'YYYY' ) = TO_CHAR( SYSDATE, 'YYYY' )         
       UNION ALL
       SELECT Info.Err_ROWID, Info.Fecha, Info.Mensaje
          FROM (
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        Err.PosFactura, Err.PosFecha,
                        SUBSTR( Err.Mensaje, Err.PosFactura + 17 , 
                                Err.PosFecha - Err.PosFactura - 19 )  AS Factura
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje,
                               INSTR( BE.Mensaje, 'Para la factura' ) AS PosFactura,
                               INSTR( BE.Mensaje, 'de fecha' )        AS PosFecha
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE '<proc_ifc_carga_facturas> No se localizo registro vigente del cliente%'
                      ) Err    
                 WHERE Err.PosFecha > 0     
              ) Info,
              T3.Factura_General FG
          WHERE Info.Factura = FG.Factura
            AND TO_CHAR( NVL( FG.Fecha_Proc_BATMD, SYSDATE + 366 ), 'YYYY' ) = TO_CHAR( SYSDATE, 'YYYY' )                            
       UNION ALL
       SELECT Info.Err_ROWID, Info.Fecha, Info.Mensaje
          FROM (
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        SUBSTR( Err.Mensaje, 39 , 
                                Err.PosCliente - 41 )       AS Factura
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje,
                               INSTR( BE.Mensaje, 'del cliente V3' ) AS PosCliente
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE '<proc_ifc_carga_facturas> La factura <%'
                      ) Err    
                 WHERE Err.PosCliente > 0     
              ) Info,
              T3.Factura_General FG
          WHERE Info.Factura = FG.Factura
            AND TO_CHAR( NVL( FG.Fecha_Proc_BATMD, SYSDATE + 366 ), 'YYYY' ) = TO_CHAR( SYSDATE, 'YYYY' )  
       UNION ALL
       SELECT Info.Err_ROWID, Info.Fecha, Info.Mensaje
          FROM (
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        SUBSTR( Err.Mensaje, Err.PosSpace2 + 1,  
                                Err.PosSpace3 - Err.PosSpace2 - 1 )  AS Factura
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje,
                               INSTR( BE.Mensaje, ' ', 1, 2 )     AS PosSpace2,
                               INSTR( BE.Mensaje, ' ', 1, 3 )     AS PosSpace3
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE 'LA FACTURA%'
                          AND Mensaje LIKE '%NO TIENE VALORES IGUALES EN HEADER Y DETALLE%'
                      ) Err    
                 UNION ALL    
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        SUBSTR( Err.Mensaje, Err.PosSpace2 + 1,  
                                Err.PosSpace3 - Err.PosSpace2 - 1 )  AS Factura
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, REPLACE( BE.Mensaje, '  ', ' ' ) AS Mensaje,
                               INSTR( REPLACE( BE.Mensaje, '  ', ' ' ), ' ', 1, 2 )     AS PosSpace2,
                               INSTR( REPLACE( BE.Mensaje, '  ', ' ' ), ' ', 1, 3 )     AS PosSpace3
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE 'LA FACTURA%'
                          AND Mensaje LIKE '%NO TIENE DETALLE%'
                      ) Err    
              ) Info,
              T3.Factura_General FG
          WHERE Info.Factura = FG.Factura
            AND TO_CHAR( NVL( FG.Fecha_Proc_BATMD, SYSDATE + 366 ), 'YYYY' ) = TO_CHAR( SYSDATE, 'YYYY' )
       UNION ALL
       SELECT Info.Err_ROWID, Info.Fecha, Info.Mensaje
          FROM (
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        SUBSTR( Err.Mensaje, Err.PosSpace2 + 1,  
                                Err.PosSpace3 - Err.PosSpace2 - 1 )  AS Cliente_V3
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje,
                               INSTR( BE.Mensaje, ' ', 1, 2 )     AS PosSpace2,
                               INSTR( BE.Mensaje, ' ', 1, 3 )     AS PosSpace3
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE 'EL CLIENTE%'
                          AND Mensaje LIKE '%tiene distribuidor diferente%'
                      ) Err    
              ) Info,
              T3.Mov_Cliente MC
          WHERE Info.Cliente_V3 = MC.Cliente_V3
            AND TO_CHAR( NVL( MC.Fecha_Proc_BATMD, SYSDATE + 366 ), 'YYYY' ) = TO_CHAR( SYSDATE, 'YYYY' )                                                 
       UNION ALL   
       SELECT Info.Err_ROWID, Info.Fecha, Info.Mensaje
          FROM (
                 SELECT Err.Err_ROWID, Err.Fecha, Err.Mensaje,
                        SUBSTR( Err.Mensaje, PosIgual + 2, 
                                PosArea - PosIgual - 3 )       AS Distribuidor ,
                        SUBSTR( Err.Mensaje, PosArea  + 7, 3 ) AS Area         ,
                        SUBSTR( Err.Mensaje, PosCanal + 8, 2 ) AS Canal
                 FROM (
                        SELECT BE.ROWID AS Err_ROWID, BE.Fecha, BE.Mensaje,
                               INSTR( BE.Mensaje, '='     ) AS PosIgual,
                               INSTR( BE.Mensaje, 'area'  ) AS PosArea ,
                               INSTR( BE.Mensaje, 'canal' ) AS PosCanal
                        FROM T3.Bitacora_Error BE
                        WHERE BE.Fecha > TRUNC( SYSDATE - pDias )
                          AND Mensaje LIKE '<proc_ifc_carga_clientes> No se Encontro Cliente_Agrupado Distribuidor%'
                      ) Err    
              ) Info,
              T3.Cliente_Agrupado Agr
          WHERE Info.Distribuidor = Agr.Distribuidor
            AND Info.Area         = Agr.Area_Mgr
            AND Info.Canal        = Agr.Canal ;
--
   CURSOR ErrIntercompany IS
              SELECT Err.ERR_ROWID, Err.DocumentoSAP
                 FROM (
                        SELECT Err.ERR_ROWID, 
                               NVL( Err.SD_Reference,
                               SUBSTR( Err.Message, Err.DocNumberIni + 16,
                                         Err.DocNumberFin - Err.DocNumberIni - 16 ) ) AS DocumentoSAP
                           FROM (    
                                  SELECT Err.ERR_ROWID, Err.Message,
                                         INSTR( Err.Message, '<DocumentNumber>'  )  AS DocNumberIni,
                                         INSTR( Err.Message, '</DocumentNumber>' )  AS DocNumberFin,
                                         Err.SD_Reference
                                      FROM (   
                                             SELECT Err.ROWID                                                        AS Err_RowID ,
                                                    DBMS_LOB.SUBSTR( Err.Message, 3900,    1 )                       AS Message   ,
                                                    Err.Reference                                                    AS SD_Reference
                                                FROM EAI_Owner.MX_EAI_Message_Log Err
                                                WHERE Queue_Name   = 'Invoice-Intercompany'
                                                  AND Status      != 'Processed'
--                                                AND Siebel_Error_Message LIKE '%-ORA-31011%'
                                                  AND Created      > TRUNC( SYSDATE - pDias )
                                             UNION       
                                             SELECT Err.ROWID                                                        AS Err_RowID ,
                                                    DBMS_LOB.SUBSTR( Err.Message, 3900,    1 )                       AS Message   ,
                                                    Err.Reference                                                    AS SD_Reference
                                                FROM EAI_Owner.MX_EAI_Message_Log Err
                                                WHERE Queue_Name   = 'SF_PROC_PREINVOICE_INTER'
                                                  AND Status      != 'Processed'
--                                                AND Siebel_Error_Message LIKE '%-ORA-31011%'
                                                  AND Created      > TRUNC( SYSDATE - pDias )                                                  
                                           ) Err
                                  ) Err     
                         ) Err, T3.Otros_General OG
               WHERE Err.DocumentoSAP = OG.Factura ;       
--
   CURSOR ErrInvoiceAmpersand IS
              SELECT Err.ERR_ROWID, Err.DocumentoSAP
                 FROM (
                        SELECT Err.ERR_ROWID, 
                               SUBSTR( Err.Message, Err.DocNumberIni + 16,
                                         Err.DocNumberFin - Err.DocNumberIni - 16 ) AS DocumentoSAP
                           FROM (    
                                  SELECT Err.ERR_ROWID, Err.Message,
                                         INSTR( Err.Message, '<DocumentNumber>'  )  AS DocNumberIni,
                                         INSTR( Err.Message, '</DocumentNumber>' )  AS DocNumberFin
                                      FROM (   
                                             SELECT Err.ROWID                                                        AS Err_RowID ,
                                                    DBMS_LOB.SUBSTR( Err.Message, 3900,    1 )                       AS Message
                                                FROM EAI_Owner.MX_EAI_Message_Log Err
                                                WHERE Queue_Name   = 'Invoice'
                                                  AND Status      != 'Processed'
--                                                AND Siebel_Error_Message LIKE '%-ORA-31011%'
                                                  AND Created      > TRUNC( SYSDATE - pDias  )
                                           ) Err
                                  ) Err     
                         ) Err, T3.Preventa_General PG
               WHERE Err.DocumentoSAP = PG.Entrega   
              UNION    
               SELECT Err.ERR_ROWID, Err.DocumentoSAP
                 FROM (
                        SELECT Err.ERR_ROWID, 
                               SUBSTR( Err.Message, Err.DocNumberIni + 16,
                                         Err.DocNumberFin - Err.DocNumberIni - 16 ) AS DocumentoSAP
                           FROM (    
                                  SELECT Err.ERR_ROWID, Err.Message,
                                         INSTR( Err.Message, '<DocumentNumber>'  )  AS DocNumberIni,
                                         INSTR( Err.Message, '</DocumentNumber>' )  AS DocNumberFin
                                      FROM (   
                                             SELECT Err.ROWID                                                        AS Err_RowID ,
                                                    DBMS_LOB.SUBSTR( Err.Message, 3900,    1 )                       AS Message
                                                FROM EAI_Owner.MX_EAI_Message_Log Err
                                                WHERE Queue_Name   = 'Invoice'
                                                  AND Status      != 'Processed'
--                                                AND Siebel_Error_Message LIKE '%-ORA-31011%'
                                                  AND Created      > TRUNC( SYSDATE - pDias  )
                                           ) Err
                                  ) Err     
                         ) Err, T3.Factura_General PG
               WHERE Err.DocumentoSAP = PG.Entrega ;  
--
   CURSOR ErrPromptDocuments IS                                               
       SELECT Factura, Row_ID 
       FROM T3.Factura_General 
       WHERE Fecha_Trn > SYSDATE - 7 
         AND Row_ID IN ( SELECT DISTINCT ID
                           FROM EAI_Owner.MX_EAI_Message_Log
                           WHERE Queue_Name IN ( 'REP_INVOICE', 'SEND_INVOICE', 'REP_CREDIT_NOTE', 'SEND_CREDIT_NOTE', 'PROC_PREINVOICE_IFC' )
                             AND Created     > SYSDATE - 7
                             AND ID         IS NOT NULL ) ;       
--
    CURSOR ErrDeliveryRepl IS
       SELECT Err.ROWID AS Err_ROWID
          FROM EAI_Owner.MX_EAI_Message_Log Err ,
               EAI_Owner.tmp_Document_Header Delv
          WHERE Queue_Name    = 'VanReplenishment'
            AND Err.Reference = Delv.ReferenceID
            AND Err.Created   > TRUNC( SYSDATE - pDias  ) ;
BEGIN
   nProceso  := 828 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso4 := 000 ;      
--
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'Iniciando Depuracion de EAI_Owner.MX_EAI_Message_Log' ) ;
      DBMS_Output.Put_Line( 'Inicio '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   sRow_ID    := 'ErrReceivePayment' ;
   nRegistros := 0                   ;
   FOR Err IN ErrReceivePayment LOOP
      IF ( Err.DocumentType = 'BK' ) THEN
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ROWID = Err.Err_ROWID ;
      END IF ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrReceivePayment : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;
--   
   sRow_ID    := 'ErrTaOPaymentInbound' ;
   nRegistros := 0                   ;
   FOR Err IN ErrTaOPaymentInbound LOOP
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrTaOPaymentInbound : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;   
--   
   sRow_ID    := 'ErrInsertingT3' ;
   nRegistros := 0                   ;
   FOR Err IN ErrInsertingT3 LOOP
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrInsertingT3 : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;   
--   
   sRow_ID    := 'ErrBankDeposit_I' ;
   nRegistros := 0                   ;
   FOR Err IN ErrBankDeposit_I LOOP
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrBankDeposit_I : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;   
--   
   sRow_ID    := 'ErrT3RF_Error_Log' ;
   nRegistros := 0                   ;
   FOR Err IN ErrT3RF_Error_Log LOOP
         nRegistros := nRegistros + 1 ;
         DELETE T3.RF_Error_Log
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrT3RF_Error_Log : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;   
--   
   sRow_ID    := 'ErrT3Bitacora_Error' ;
   nRegistros := 0                   ;
   FOR Err IN ErrT3Bitacora_Error LOOP
         nRegistros := nRegistros + 1 ;
         DELETE T3.Bitacora_Error
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrT3Bitacora_Error : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;   
--   
   sRow_ID    := 'ErrIntercompany' ;
   nRegistros := 0                   ;
   FOR Err IN ErrIntercompany LOOP
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrIntercompany : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;   
--   
   sRow_ID    := 'ErrInvoice' ;
   nRegistros := 0                   ;
   FOR Err IN ErrInvoiceAmpersand LOOP
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrInvoice  : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;   
--
   sRow_ID    := 'ErrReplenishment' ;
   nRegistros := 0                   ;
   FOR Err IN ErrDeliveryRepl LOOP
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ROWID = Err.Err_ROWID ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrReplenishment  : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
   nProceso4 := nProceso4 + nRegistros ;  
--
   sRow_ID    := 'ErrPromptDocuments' ;
   nRegistros := 0              ;
   FOR Err IN ErrPromptDocuments LOOP
         nRegistros := nRegistros + 1 ;
         DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE ID          = Err.Row_ID 
              AND Queue_Name IN ( 'REP_INVOICE', 'SEND_INVOICE', 'REP_CREDIT_NOTE', 'SEND_CREDIT_NOTE' )
              AND Created     > SYSDATE - 7 ;
      IF ( MOD( nRegistros, 500 ) = 0 ) THEN
         COMMIT ;
      END IF ;      
   END LOOP ;
   COMMIT ;
   IF ( pOutput > 0 ) THEN
      DBMS_Output.Put_Line( 'ErrPromptDocuments : ' || TO_CHAR( nRegistros, '999,999' ) ) ;
      DBMS_Output.Put_Line( 'Termino '  || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;   
   nProceso4 := nProceso4 + nRegistros ;   
--
   IF ( pDias < 10 ) THEN
      EAI_Owner.WA_RESEND_CFDI( pDias, pOutput ) ;
   END IF ;   
--   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                 Proceso_3 = 0, Proceso_4 = nProceso4
       WHERE PID = nPID  ;   
   COMMIT ;          
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION           , REFERENCE              , CREATED             , MESSAGE        , JOB_PID,
          STATUS              , QUEUE_NAME             , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT            , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Depura ERR_MSG_LOG', sRow_ID                , SYSDATE             , NULL           , nPID   ,
          'Error'             , 'WA_DEPURA_MESSAGE_LOG', sMsg                , 'WA'           ,
          sErrorCode          , NULL                   , NULL                , NULL            ) ;
      COMMIT ;
END WA_DEPURA_MESSAGE_LOG ;
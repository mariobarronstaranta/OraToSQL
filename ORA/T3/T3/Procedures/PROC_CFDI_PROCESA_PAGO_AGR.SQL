create or replace PROCEDURE    "PROC_CFDI_PROCESA_PAGO_AGR" 
   ( nDias  IN  NUMBER DEFAULT NULL )
IS
   sMsg                 VARCHAR2(0500) ;
   sCadena              VARCHAR2(4000) ;
   sChar                VARCHAR2(0001) ;
   nDoctos              NUMBER(06)     ;
   nNotas               NUMBER(06)     ;
   sEtapa               VARCHAR2(0020) ;
   sPorEjecucion        VARCHAR2(0002) ;
   nGen_Agrupacion      NUMBER(08)     ;
--
   strID                VARCHAR2(050) ;
   dtInicio             DATE          ;
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso3            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;
--
   nAgrupacion          NUMBER(10)   ;  
   dtFecha_Pago         DATE         ;
   sRFC                 VARCHAR2(30) ;
   sVia_Pago            VARCHAR2(10) ;
   sBanco_Nombre        VARCHAR2(60) ;
   sBanco_Num_Cuenta    VARCHAR2(60) ;
   sAsignacion          VARCHAR2(60) ;
   sInsert_Nombre       VARCHAR2(60) ;
   sInsert_Num_Cuenta   VARCHAR2(60) ;
   sInsert_Asignacion   VARCHAR2(60) ;
   nImportePago         NUMBER(15,2) ;
   nCantidadPagos       NUMBER(04)   ;
   sAccnt_ID            VARCHAR2(20) ;
   sCliente_SAP         VARCHAR2(20) ;
--
   nCtrl_Pagos          NUMBER(06)   ;
   nCtrl_Importe        NUMBER(15,2) ;
--
   CURSOR ScrWA_Allocation IS
       SELECT Cobza.Asignacion_ID, Cobza.Fecha_Proc_BATMD, Cobza.Fecha_Proceso, Cobza.Factura, Acc.Assignment, RF.Entrega, 
              'UPDATE T3.CFDI_Cobranza SET Asignacion_Central = ' || CHR(39) || Acc.Assignment      || CHR(39) || 
                                        ' WHERE Asignacion_ID = ' || CHR(39) || Cobza.Asignacion_ID || CHR(39) || ' ; ' AS executeScript
          FROM T3.CFDI_Cobranza              Cobza,
               EAI_Owner.tmp_Account_Header  Acc  ,
               T3.Registro_Fiscal            RF
          WHERE Cobza.Fecha_Proceso                   > TRUNC( SYSDATE - NVL( nDias, 0 ) )
            AND SUBSTR( Cobza.Asignacion_ID, 3, 10 )  = Acc.ClearingDocNumber
            AND Acc.FiscalYear                        = TO_CHAR( SYSDATE, 'YYYY' )
            AND Cobza.Factura                         = RF.Factura
            AND NVL( Acc.Assignment, RF.Entrega )    != RF.Entrega
            AND NVL( Acc.Assignment, RF.Entrega )    != 'B001 - Bank I'
            AND NVL( Acc.Assignment, RF.Entrega )    != Cobza.Factura || ','
            AND NVL( Acc.Assignment, RF.Entrega )     NOT LIKE '1-1%'
            AND NVL( Acc.Assignment, RF.Entrega )    != RF.Referencia
            AND Cobza.Asignacion_Central             IS NULL ;   
--
   CURSOR ScrAgrPagoCentral IS
       SELECT TRUNC( Cobza.Fecha_Pago  )                    AS Fecha_Pago        ,
              Cobza.RFC                                     AS RFC               ,
              DECODE( Cobza.Via_Pago, 'NA', '03',
                      Cobza.Via_Pago )                      AS Via_Pago          ,
              NVL( Cobza.Banco_Nombre    , 'NoBanco'  )     AS Banco_Nombre      ,
              NVL( Cobza.Banco_Num_Cuenta, 'NoCuenta' )     AS Banco_Num_Cuenta  ,
              NVL( Cobza.Asignacion_Central, 'NoAsigna' )   AS Asignacion_Central,
              SUM( Cobza.Importe )                          AS Importe           ,
              COUNT( Cobza.Importe )                        AS Pagos             ,
              MAX( Cobza.Accnt_ID )                         AS Accnt_ID          ,
              MAX( Cobza.Cliente_SAP )                      AS Cliente_SAP
          FROM T3.CFDI_Cobranza Cobza
          WHERE NVL( TO_CHAR( Cobza.Fecha_Envio, 'YYYYMMDD' ), 'null' ) = 'null'
            AND Cobza.Created_By        != 'INTERFACE'
            AND Cobza.Via_Pago          != '01'
            AND Cobza.Via_Pago          != 'CM'
            AND Cobza.Via_Pago          != 'AI'
            AND NVL(Cobza.Status,1)     != 'Debit Note'
            AND NVL(Cobza.Status,1)     != 'Canc Pago'
            AND Cobza.Fecha_Proceso     > TRUNC( SYSDATE - NVL( nDias, 0 ) )
--            AND Cobza.Fecha_Proc_BATMD IS NULL
            AND Cobza.RFC != 'XAXX010101000'
            AND Cobza.Factura NOT IN ( SELECT Factura FROM T3.WA_Factoraje )
          GROUP BY TRUNC( Cobza.Fecha_Pago  ), Cobza.RFC, DECODE( Cobza.Via_Pago, 'NA', '03',
                                                                  Cobza.Via_Pago ), Cobza.Banco_Nombre, Cobza.Banco_Num_Cuenta, Cobza.Asignacion_Central ;
--
   CURSOR ScrDetalle IS
       SELECT Cobza.RowID          AS Cobza_ROWID  ,
              Cobza.Folio_ID       AS Folio_ID     ,
              Cobza.Asignacion_ID  AS Asignacion_ID,
              Cobza.Importe        AS Importe
          FROM T3.CFDI_Cobranza Cobza
          WHERE NVL( TO_CHAR( Cobza.Fecha_Envio, 'YYYYMMDD' ), 'null' ) = 'null'
            AND Cobza.Created_By                            != 'INTERFACE'
            AND Cobza.Via_Pago                              != '01'
            AND Cobza.Via_Pago                              != 'CM'
            AND NVL(Cobza.Status,1)                        != 'Debit Note'
            AND NVL(Cobza.Status,1)                        != 'Canc Pago'
            AND TRUNC( Cobza.Fecha_Pago  )                   = dtFecha_Pago
            AND Cobza.RFC                                    = sRFC
--          AND Cobza.Via_Pago                               = sVia_Pago
            AND DECODE( Cobza.Via_Pago, 'NA', '03',
                      Cobza.Via_Pago )                       = sVia_Pago
--            AND Cobza.Fecha_Proc_BATMD                      IS NULL
            AND Cobza.Factura NOT IN ( SELECT Factura FROM T3.WA_Factoraje )
            AND NVL( Cobza.Banco_Nombre    , 'NoBanco'  )    = sBanco_Nombre
            AND NVL( Cobza.Banco_Num_Cuenta, 'NoCuenta' )    = sBanco_Num_Cuenta
            AND NVL( Cobza.Asignacion_Central, 'NoAsigna' )  = sAsignacion ;
--  
BEGIN
   dtInicio  := SYSDATE ;
   nProceso  := 109 ;
   nPID      := SEQ_CFD.Nextval ;
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := nDias ;
-- DBMS_OUTPUT.PUT_LINE( TO_CHAR( dtFechaProcBATMD, 'YYYYMMDD HH24:MI:SS' ) ) ;
   sChar   := '|' ;
   nDoctos := 000 ;
   sEtapa  := 'I' ;
--
   FOR WA IN ScrWA_Allocation LOOP
      UPDATE T3.CFDI_Cobranza SET Asignacion_Central = WA.Assignment
         WHERE Asignacion_ID = WA.Asignacion_ID ;
   END LOOP ;
   COMMIT ;   
--
-- Documentos Agrupados de Prompt Sales
--
      FOR Doc IN ScrAgrPagoCentral LOOP
         nAgrupacion        := SEQ_PAGO_CENTRAL_AGR.Nextval ;
         nProceso1          := nProceso1 + 1          ;         
         dtFecha_Pago       := Doc.Fecha_Pago         ;
         sRFC               := Doc.RFC                ;
         sVia_Pago          := Doc.Via_Pago           ;
         sBanco_Nombre      := Doc.Banco_Nombre       ;
         sBanco_Num_Cuenta  := Doc.Banco_Num_Cuenta   ;
         sAsignacion        := Doc.Asignacion_Central ;     
         nImportePago       := Doc.Importe            ;
         nCantidadPagos     := Doc.Pagos              ;
         sAccnt_ID          := Doc.Accnt_ID           ;
         sCliente_SAP       := Doc.Cliente_SAP        ;
         sInsert_Nombre     := Doc.Banco_Nombre       ;
         sInsert_Num_Cuenta := Doc.Banco_Num_Cuenta   ;
         sInsert_Asignacion := Doc.Asignacion_Central ;     
         IF ( sInsert_Nombre = 'NoBanco' ) THEN
            sInsert_Nombre := '' ;
         END IF ; 
         IF ( sInsert_Num_Cuenta = 'NoCuenta' ) THEN
            sInsert_Num_Cuenta := '' ;
         END IF ; 
         IF ( sInsert_Asignacion = 'NoAsigna' ) THEN
            sInsert_Asignacion := '' ;
         END IF ; --         
         INSERT INTO T3.CFDI_Agrupacion_CTRL 
            ( Agrupacion        , Fecha_Pago        , Via_Pago          , RFC               ,
              Banco_Nombre      , Banco_Num_Cuenta  , Importe           , Cantidad_Pagos    ,
              Accnt_ID          , Fecha_Registro    , Asignacion_Central, Cliente_SAP )
         VALUES 
            ( nAgrupacion       , dtFecha_Pago      , sVia_Pago         , sRFC              ,
              sInsert_Nombre    , sInsert_Num_Cuenta, nImportePago      , nCantidadPagos    ,
              sAccnt_ID         , SYSDATE           , sInsert_Asignacion, sCliente_SAP      ) ;
         nCtrl_Pagos    := 0 ;
         nCtrl_Importe  := 0 ;              
         FOR Det IN ScrDetalle LOOP
            nProceso2 := nProceso2 + 1 ;
            INSERT INTO T3.CFDI_AGRUPACION_PAGO
               ( Agrupacion, Fecha_Pago, Asignacion_ID )
            VALUES
               ( nAgrupacion, dtFecha_Pago, Det.Asignacion_ID ) ;
            UPDATE T3.CFDI_Cobranza Cobza SET Cobza.Fecha_Envio = SYSDATE
               WHERE Cobza.ROWID = Det.Cobza_ROWID ;
            nCtrl_Pagos    := nCtrl_Pagos   + 1 ;
            nCtrl_Importe  := nCtrl_Importe + Det.Importe ;     
         END LOOP ;
         UPDATE T3.CFDI_Agrupacion_CTRL SET Cantidad_Pagos = nCtrl_Pagos,
                                            Importe        = nCtrl_Importe
            WHERE Agrupacion = nAgrupacion ;
         UPDATE T3.CFDI_Agrupacion_Ctrl AC    SET Cliente_SAP =
                          ( SELECT MAX( NVL( RF.Clte_Factura_SAP, RF.Cliente_SAP ) )
                               FROM T3.CFDI_Agrupacion_Pago AP   ,
                                    T3.CFDI_Cobranza        Cobza,
                                    T3.Registro_Fiscal      RF
                               WHERE AP.Agrupacion    = AC.Agrupacion
                                 AND AP.Asignacion_ID = Cobza.Asignacion_ID
                                 AND Cobza.Factura    = RF.Factura )
            WHERE AC.Agrupacion    = nAgrupacion ;            
      END LOOP ;
--
   INSERT INTO T3.RF_PROCESOS_LOG 
      ( PID , Proceso , Fecha_Proc_BATMD, Inicio  , Fin    , Proceso_1, Proceso_2, Proceso_3, Proceso_4 )
   VALUES 
      ( nPID, nProceso, NULL, dtInicio, SYSDATE, nProceso1, nProceso2, nProceso3, nProceso4 ) ;   
   COMMIT ;
   T3.PROC_CFDI_LIBERA_PAGO_CENTRAL ;
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_PROCESA_PAGO_AGR' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'PROC_CFDI_PROCESA_PAGO_AGR', strID, sMsg ) ;
      COMMIT ;
END PROC_CFDI_PROCESA_PAGO_AGR ;
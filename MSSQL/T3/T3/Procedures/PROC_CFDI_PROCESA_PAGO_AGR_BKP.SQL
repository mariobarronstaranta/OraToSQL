USE [T3QA]
GO
/****** Object:  StoredProcedure [T3].[PROC_CFDI_PROCESA_PAGO_AGR_RESP]    Script Date: 11/3/2026 4:26:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [T3].[PROC_CFDI_PROCESA_PAGO_AGR_BKP] 
    @nDias NUMERIC = NULL
AS
BEGIN
	print 'PROC_CFDI_PROCESA_PAGO_AGR--------------------------'
    DECLARE @sMsg VARCHAR(500);
    DECLARE @sCadena VARCHAR(4000);
    DECLARE @sChar VARCHAR(1);
    DECLARE @nDoctos NUMERIC(6,0);
    DECLARE @nNotas NUMERIC(6,0);
    DECLARE @sEtapa VARCHAR(20);
    DECLARE @sPorEjecucion VARCHAR(2);
    DECLARE @nGen_Agrupacion NUMERIC(8,0);
--
    DECLARE @strID VARCHAR(50);
    DECLARE @dtInicio DATETIME;
    DECLARE @nPID NUMERIC(8,0);
    DECLARE @nProceso NUMERIC(8,0);
    DECLARE @nProceso1 NUMERIC(8,0);
    DECLARE @nProceso2 NUMERIC(8,0);
    DECLARE @nProceso3 NUMERIC(8,0);
    DECLARE @nProceso4 NUMERIC(8,0);
--
    DECLARE @nAgrupacion NUMERIC(10,0);  
    DECLARE @dtFecha_Pago DATETIME;
    DECLARE @sRFC VARCHAR(30);
    DECLARE @sVia_Pago VARCHAR(10);
    DECLARE @sBanco_Nombre VARCHAR(60);
    DECLARE @sBanco_Num_Cuenta VARCHAR(60);
    DECLARE @sAsignacion VARCHAR(60);
    DECLARE @sInsert_Nombre VARCHAR(60);
    DECLARE @sInsert_Num_Cuenta VARCHAR(60);
    DECLARE @sInsert_Asignacion VARCHAR(60);
    DECLARE @nImportePago NUMERIC(15,2);
    DECLARE @nCantidadPagos NUMERIC(4,0);
    DECLARE @sAccnt_ID VARCHAR(20);
    DECLARE @sCliente_SAP VARCHAR(20);
--
    DECLARE @nCtrl_Pagos NUMERIC(6,0);
    DECLARE @nCtrl_Importe NUMERIC(15,2);

	--variabkles cursores
    DECLARE @WA_Asignacion_ID VARCHAR(50);
    DECLARE @WA_Fecha_Proc_BATMD DATETIME;
    DECLARE @WA_Fecha_Proceso DATETIME;
    DECLARE @WA_Factura VARCHAR(50);
    DECLARE @WA_Assignment VARCHAR(60);
    DECLARE @WA_Entrega VARCHAR(50);
    DECLARE @WA_executeScript VARCHAR(MAX);

    DECLARE @Doc_Fecha_Pago DATETIME;
    DECLARE @Doc_RFC VARCHAR(30);
    DECLARE @Doc_Via_Pago VARCHAR(10);
    DECLARE @Doc_Banco_Nombre VARCHAR(60);
    DECLARE @Doc_Banco_Num_Cuenta VARCHAR(60);
    DECLARE @Doc_Asignacion_Central VARCHAR(60);
    DECLARE @Doc_Importe NUMERIC(15,2);
    DECLARE @Doc_Pagos NUMERIC(6,0);
    DECLARE @Doc_Accnt_ID VARCHAR(20);
    DECLARE @Doc_Cliente_SAP VARCHAR(20);

    DECLARE @Det_Cobza_ROWID VARCHAR(50); 
    DECLARE @Det_Folio_ID VARCHAR(50);
    DECLARE @Det_Asignacion_ID VARCHAR(50);
    DECLARE @Det_Importe NUMERIC(15,2);

    DECLARE ScrWA_Allocation CURSOR LOCAl FOR 
        SELECT Cobza.Asignacion_ID, Cobza.Fecha_Proc_BATMD, Cobza.Fecha_Proceso, Cobza.Factura, Acc.Assignment, RF.Entrega, 
               'UPDATE T3.CFDI_Cobranza SET Asignacion_Central = ' + CHAR(39) + Acc.Assignment       + CHAR(39) + 
                                        ' WHERE Asignacion_ID = ' + CHAR(39) + Cobza.Asignacion_ID + CHAR(39) + ' ; ' AS executeScript
          FROM T3.CFDI_Cobranza              Cobza,
               EAI_Owner.tmp_Account_Header  Acc  ,
               T3.Registro_Fiscal            RF
          WHERE Cobza.Fecha_Proceso                   > CAST(DATEADD(DAY, -ISNULL(@nDias, 0), GETDATE()) AS DATE)
            AND SUBSTRING( Cobza.Asignacion_ID, 3, 10 ) = Acc.ClearingDocNumber
            AND Acc.FiscalYear                        = CAST(YEAR(GETDATE()) AS VARCHAR(4))
            AND Cobza.Factura                         = RF.Factura
            AND ISNULL( Acc.Assignment, RF.Entrega ) != RF.Entrega
            AND ISNULL( Acc.Assignment, RF.Entrega ) != 'B001 - Bank I'
            AND ISNULL( Acc.Assignment, RF.Entrega ) != Cobza.Factura + ','
            AND ISNULL( Acc.Assignment, RF.Entrega )  NOT LIKE '1-1%'
            AND ISNULL( Acc.Assignment, RF.Entrega ) != RF.Referencia
            AND Cobza.Asignacion_Central             IS NULL ;   
--
    DECLARE ScrAgrPagoCentral CURSOR LOCAl FOR 
        SELECT CAST( Cobza.Fecha_Pago AS DATE )                         AS Fecha_Pago        ,
               Cobza.RFC                                                AS RFC               ,
               CASE Cobza.Via_Pago WHEN 'NA' THEN '03' ELSE Cobza.Via_Pago END AS Via_Pago          ,
               ISNULL( Cobza.Banco_Nombre    , 'NoBanco'  )             AS Banco_Nombre      ,
               ISNULL( Cobza.Banco_Num_Cuenta, 'NoCuenta' )             AS Banco_Num_Cuenta  ,
               ISNULL( Cobza.Asignacion_Central, 'NoAsigna' )           AS Asignacion_Central,
               SUM( Cobza.Importe )                                     AS Importe           ,
               COUNT( Cobza.Importe )                                   AS Pagos             ,
               MAX( Cobza.Accnt_ID )                                    AS Accnt_ID          ,
               MAX( Cobza.Cliente_SAP )                                 AS Cliente_SAP
          FROM T3.CFDI_Cobranza Cobza
          WHERE ISNULL( CONVERT(VARCHAR(8), Cobza.Fecha_Envio, 112), 'null' ) = 'null'
            AND Cobza.Created_By        != 'INTERFACE'
            AND Cobza.Via_Pago          != '01'
            AND Cobza.Via_Pago          != 'CM'
            AND Cobza.Via_Pago          != 'AI'
            AND ISNULL(Cobza.Status,'1')      != 'Debit Note'
            AND ISNULL(Cobza.Status,'1')      != 'Canc Pago'
            AND Cobza.Fecha_Proceso     > CAST(DATEADD(DAY, -ISNULL(@nDias, 0), GETDATE()) AS DATE)
            AND Cobza.RFC != 'XAXX010101000'
            AND Cobza.Factura NOT IN ( SELECT Factura FROM T3.WA_Factoraje )
          GROUP BY CAST( Cobza.Fecha_Pago AS DATE ), Cobza.RFC, CASE Cobza.Via_Pago WHEN 'NA' THEN '03' ELSE Cobza.Via_Pago END, Cobza.Banco_Nombre, Cobza.Banco_Num_Cuenta, Cobza.Asignacion_Central ;
--
		DECLARE ScrDetalle CURSOR LOCAL FORWARD_ONLY FOR 
		SELECT Cobza.Folio_ID       AS Folio_ID     ,
            Cobza.Asignacion_ID  AS Asignacion_ID,
            Cobza.Importe        AS Importe
        FROM T3.CFDI_Cobranza Cobza
        WHERE ISNULL( CONVERT(VARCHAR(8), Cobza.Fecha_Envio, 112), 'null' ) = 'null'
        AND Cobza.Created_By                            != 'INTERFACE'
        AND Cobza.Via_Pago                              != '01'
        AND Cobza.Via_Pago                              != 'CM'
        AND ISNULL(Cobza.Status,'1')                         != 'Debit Note'
        AND ISNULL(Cobza.Status,'1')                         != 'Canc Pago'
        AND CAST( Cobza.Fecha_Pago AS DATE )                 = CAST(@dtFecha_Pago AS DATE)
        AND Cobza.RFC                                    = @sRFC
        AND CASE Cobza.Via_Pago WHEN 'NA' THEN '03' ELSE Cobza.Via_Pago END = @sVia_Pago
        AND Cobza.Factura NOT IN ( SELECT Factura FROM T3.WA_Factoraje )
        AND ISNULL( Cobza.Banco_Nombre    , 'NoBanco'  )    = @sBanco_Nombre
        AND ISNULL( Cobza.Banco_Num_Cuenta, 'NoCuenta' )    = @sBanco_Num_Cuenta
        AND ISNULL( Cobza.Asignacion_Central, 'NoAsigna' )  = @sAsignacion ;

    BEGIN TRY
        SET @dtInicio  = GETDATE();
        SET @nProceso  = 109;
        SET @nPID      = NEXT VALUE FOR SEQ_CFD;
        SET @nProceso1 = 0;
        SET @nProceso2 = 0;
        SET @nProceso3 = 0;
        SET @nProceso4 = @nDias;
        
        SET @sChar   = '|';
        SET @nDoctos = 000;
        SET @sEtapa  = 'I';
        
		--begin tran

        OPEN ScrWA_Allocation;
        FETCH NEXT FROM ScrWA_Allocation INTO @WA_Asignacion_ID, @WA_Fecha_Proc_BATMD, @WA_Fecha_Proceso, @WA_Factura, @WA_Assignment, @WA_Entrega, @WA_executeScript;
        WHILE @@FETCH_STATUS = 0
        BEGIN
		PRINT 'ScrWA_Allocation'
		
           UPDATE T3.CFDI_Cobranza 
           SET Asignacion_Central = @WA_Assignment
           WHERE Asignacion_ID = @WA_Asignacion_ID;
          
           FETCH NEXT FROM ScrWA_Allocation INTO @WA_Asignacion_ID, @WA_Fecha_Proc_BATMD, @WA_Fecha_Proceso, @WA_Factura, @WA_Assignment, @WA_Entrega, @WA_executeScript;
        END;
        CLOSE ScrWA_Allocation;
        DEALLOCATE ScrWA_Allocation;

-- Documentos Agrupados de Prompt Sales
--
        OPEN ScrAgrPagoCentral;
        FETCH NEXT FROM ScrAgrPagoCentral INTO @Doc_Fecha_Pago, @Doc_RFC, @Doc_Via_Pago, @Doc_Banco_Nombre, @Doc_Banco_Num_Cuenta, @Doc_Asignacion_Central, @Doc_Importe, @Doc_Pagos, @Doc_Accnt_ID, @Doc_Cliente_SAP;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
		PRINT 'ENTRA ScrAgrPagoCentral'
           SET @nAgrupacion        = NEXT VALUE FOR SEQ_PAGO_CENTRAL_AGR;
           SET @nProceso1          = @nProceso1 + 1;         
           SET @dtFecha_Pago       = @Doc_Fecha_Pago;
           SET @sRFC               = @Doc_RFC;
           SET @sVia_Pago          = @Doc_Via_Pago;
           SET @sBanco_Nombre      = @Doc_Banco_Nombre;
           SET @sBanco_Num_Cuenta  = @Doc_Banco_Num_Cuenta;
           SET @sAsignacion        = @Doc_Asignacion_Central;     
           SET @nImportePago       = @Doc_Importe;
           SET @nCantidadPagos     = @Doc_Pagos;
           SET @sAccnt_ID          = @Doc_Accnt_ID;
           SET @sCliente_SAP       = @Doc_Cliente_SAP;
           SET @sInsert_Nombre     = @Doc_Banco_Nombre;
           SET @sInsert_Num_Cuenta = @Doc_Banco_Num_Cuenta;
           SET @sInsert_Asignacion = @Doc_Asignacion_Central;     
           
           IF ( @sInsert_Nombre = 'NoBanco' ) 
           BEGIN
               SET @sInsert_Nombre = '';
           END; 
           IF ( @sInsert_Num_Cuenta = 'NoCuenta' ) 
           BEGIN
               SET @sInsert_Num_Cuenta = '';
           END; 
           IF ( @sInsert_Asignacion = 'NoAsigna' ) 
           BEGIN
               SET @sInsert_Asignacion = '';
           END; --          
           
		  
           INSERT INTO T3.CFDI_Agrupacion_CTRL 
               ( Agrupacion        , Fecha_Pago        , Via_Pago          , RFC               ,
                 Banco_Nombre      , Banco_Num_Cuenta  , Importe           , Cantidad_Pagos    ,
                 Accnt_ID          , Fecha_Registro    , Asignacion_Central, Cliente_SAP )
           VALUES 
               ( @nAgrupacion      , @dtFecha_Pago     , @sVia_Pago        , @sRFC             ,
                 @sInsert_Nombre   , @sInsert_Num_Cuenta, @nImportePago    , @nCantidadPagos   ,
                 @sAccnt_ID        , GETDATE()         , @sInsert_Asignacion, @sCliente_SAP    );
                 
           SET @nCtrl_Pagos   = 0;
           SET @nCtrl_Importe = 0;             
	
           OPEN ScrDetalle;
           FETCH NEXT FROM ScrDetalle INTO @Det_Folio_ID, @Det_Asignacion_ID, @Det_Importe;
           
           WHILE @@FETCH_STATUS = 0
           BEGIN
		  PRINT 'ENTRA ScrDetalle'
              SET @nProceso2 = @nProceso2 + 1;
             
              INSERT INTO T3.CFDI_AGRUPACION_PAGO
                 ( Agrupacion, Fecha_Pago, Asignacion_ID )
              VALUES
                 ( @nAgrupacion, @dtFecha_Pago, @Det_Asignacion_ID );
                 
              -- Se actualiza explícitamente usando la columna ROWID de la tabla Cobranza
              UPDATE T3.CFDI_Cobranza 
              SET Fecha_Envio = GETDATE()
              WHERE FOLIO_ID = @Det_Folio_ID;
            
              SET @nCtrl_Pagos   = @nCtrl_Pagos   + 1;
              SET @nCtrl_Importe = @nCtrl_Importe + @Det_Importe;     
              
              FETCH NEXT FROM ScrDetalle INTO  @Det_Folio_ID, @Det_Asignacion_ID, @Det_Importe;
           END;
           CLOSE ScrDetalle;
 		 
           UPDATE T3.CFDI_Agrupacion_CTRL 
           SET Cantidad_Pagos = @nCtrl_Pagos,
               Importe        = @nCtrl_Importe
           WHERE Agrupacion = @nAgrupacion;
           
           UPDATE AC 
           SET Cliente_SAP =
                    ( SELECT MAX( ISNULL( RF.Clte_Factura_SAP, RF.Cliente_SAP ) )
                         FROM T3.CFDI_Agrupacion_Pago AP   ,
                              T3.CFDI_Cobranza        Cobza,
                              T3.Registro_Fiscal      RF
                         WHERE AP.Agrupacion    = AC.Agrupacion
                           AND AP.Asignacion_ID = Cobza.Asignacion_ID
                           AND Cobza.Factura    = RF.Factura )
           FROM T3.CFDI_Agrupacion_Ctrl AC
           WHERE AC.Agrupacion = @nAgrupacion;            
           
           FETCH NEXT FROM ScrAgrPagoCentral INTO @Doc_Fecha_Pago, @Doc_RFC, @Doc_Via_Pago, @Doc_Banco_Nombre, @Doc_Banco_Num_Cuenta, @Doc_Asignacion_Central, @Doc_Importe, @Doc_Pagos, @Doc_Accnt_ID, @Doc_Cliente_SAP;
        END;
        CLOSE ScrAgrPagoCentral;
        DEALLOCATE ScrAgrPagoCentral;
		
		DEALLOCATE ScrDetalle;
--

        INSERT INTO T3.RF_PROCESOS_LOG 
           ( PID , Proceso , Fecha_Proc_BATMD, Inicio  , Fin    , Proceso_1, Proceso_2, Proceso_3, Proceso_4 )
        VALUES 
           ( @nPID, @nProceso, NULL, @dtInicio, GETDATE(), @nProceso1, @nProceso2, @nProceso3, @nProceso4 ) ;   
		   
        EXEC T3.PROC_CFDI_LIBERA_PAGO_CENTRAL ;

    END TRY
    BEGIN CATCH
       
		IF CURSOR_STATUS('local', 'ScrDetalle') <> -3
		BEGIN
			IF CURSOR_STATUS('local', 'ScrDetalle') >= 0
				CLOSE ScrDetalle;

			DEALLOCATE ScrDetalle;
		END;
		IF CURSOR_STATUS('local', 'ScrAgrPagoCentral') <> -3
		BEGIN
			IF CURSOR_STATUS('local', 'ScrAgrPagoCentral') >= 0
				CLOSE ScrAgrPagoCentral;

			DEALLOCATE ScrAgrPagoCentral;
		END;
		IF CURSOR_STATUS('local', 'ScrWA_Allocation') <> -3
		BEGIN
			IF CURSOR_STATUS('local', 'ScrWA_Allocation') >= 0
				CLOSE ScrWA_Allocation;

			DEALLOCATE ScrWA_Allocation;
		END;

		  
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR) + '-' + ERROR_MESSAGE(), 1, 250);
        SET @sMsg = SUBSTRING(ERROR_MESSAGE(), 1, 250);
        
        PRINT REPLICATE('-', 80);
        PRINT 'Problemas en la ejecucion del Procedimiento';
        PRINT 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :';
        PRINT 'Procedimiento : PROC_CFDI_PROCESA_PAGO_AGR';
        PRINT 'Fecha         : ' + CONVERT(VARCHAR, GETDATE(), 112) + ' ' + CONVERT(VARCHAR, GETDATE(), 108);
        PRINT 'Referencia    : ' + ISNULL(@strID, '');
        PRINT 'Error         : ' + ISNULL(@sMsg, '');
        PRINT REPLICATE('-', 80);
        
        INSERT INTO T3.RF_ERROR_LOG 
           ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
        VALUES
           ( GETDATE(), 'PROC_CFDI_PROCESA_PAGO_AGR', @strID, @sMsg ) ;

    END CATCH
END;

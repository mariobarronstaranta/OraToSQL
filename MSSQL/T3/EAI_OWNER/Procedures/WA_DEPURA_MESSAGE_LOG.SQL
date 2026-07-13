/*
    Homologo SQL Server del procedimiento Oracle WA_DEPURA_MESSAGE_LOG.

    Objetivo:
      Eliminar registros de error recientes cuando la informacion relacionada
      ya existe y demuestra que el documento fue procesado correctamente.

    Importante:
      @pDias no representa una antiguedad minima. Igual que en Oracle, limita
      la revision a registros creados DESPUES del inicio del dia calculado.
      Las eliminaciones se realizan por conjuntos; @@ROWCOUNT sustituye el
      conteo fila por fila realizado por los cursores de Oracle.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_DEPURA_MESSAGE_LOG]
    @pDias   INT = 4,
    @pOutput INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @sMsg        NVARCHAR(500),
        @sRow_ID     VARCHAR(30),
        @sErrorCode  VARCHAR(20),
        @nRegistros  INT,
        @nPID        BIGINT,
        @nProceso    INT = 828,
        @nProceso4   INT = 0,
        @FechaCorte  DATETIME2(0),
        @Fecha7Dias  DATETIME2(0);

    SET @FechaCorte = CAST(CAST(DATEADD(DAY, -@pDias, SYSDATETIME()) AS date) AS datetime2(0));
    SET @Fecha7Dias = DATEADD(DAY, -7, SYSDATETIME());

    BEGIN TRY
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, SYSDATETIME());

        IF @pOutput > 0
        BEGIN
            PRINT 'Iniciando Depuracion de EAI_OWNER.MX_EAI_MESSAGE_LOG';
            PRINT CONCAT('Inicio ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 1. ErrReceivePayment
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrReceivePayment';

        DELETE Err
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err
        CROSS APPLY
        (
            SELECT
                Message2000 = CAST(SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 1, 2000) AS NVARCHAR(2000))
        ) M
        CROSS APPLY
        (
            SELECT CloseDocType = CHARINDEX('</DocumentType>', M.Message2000)
        ) P
        CROSS APPLY
        (
            SELECT DocumentType =
                CASE
                    WHEN P.CloseDocType > 0
                        THEN SUBSTRING(M.Message2000, P.CloseDocType - 2, 2)
                    ELSE '  '
                END
        ) D
        WHERE Err.Created    > @FechaCorte
          AND Err.Direction  = 'Receive'
          AND Err.Queue_Name = 'Payment'
          AND Err.Status    <> 'Processed'
          AND D.DocumentType = 'BK';

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrReceivePayment : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 2. ErrTaOPaymentInbound
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrTaOPaymentInbound';

        ;WITH Cobza AS
        (
            SELECT COALESCE(PG.Factura, AccHead.ReferenceDocNumber) AS Factura
            FROM
            (
                SELECT
                    ReferenceDocNumber,
                    ClearingDocNumber,
                    CAST(Created AS date) AS CreatedDate,
                    COUNT(IDocNumber) AS Count_Send
                FROM [EAI_OWNER].[tmp_Account_Header]
                WHERE Created > @FechaCorte
                  AND Status = 'Sent'
                GROUP BY ReferenceDocNumber, ClearingDocNumber, CAST(Created AS date)
                HAVING COUNT(IDocNumber) > 1
            ) AccHead
            LEFT JOIN [T3].[Preventa_General] PG
                ON AccHead.ReferenceDocNumber = PG.Referencia
        )
        DELETE ELog
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] ELog
        LEFT JOIN [EAI_OWNER].[MX_SEND_MESSAGE_LOG] SendLog
            ON ELog.Reference = SendLog.Row_ID
        INNER JOIN Cobza
            ON SendLog.Reference = Cobza.Factura
        WHERE ELog.Created    > @FechaCorte
          AND ELog.Status    <> 'Processed'
          AND ELog.Queue_Name = 'TaO Payment Inbound';

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrTaOPaymentInbound : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 3. ErrInsertingT3
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrInsertingT3';

        DELETE ELog
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] ELog
        LEFT JOIN [EAI_OWNER].[MX_SEND_MESSAGE_LOG] SendLog
            ON ELog.Reference = SendLog.Row_ID
        INNER JOIN [T3].[Factura_General] FG
            ON ELog.ID = FG.Row_ID
        WHERE ELog.Created    > @FechaCorte
          AND ELog.Status    <> 'Processed'
          AND ELog.Direction  = 'Inserting'
          AND ELog.Queue_Name = 'Invoice'
          AND FG.Fecha_Trn    > @FechaCorte;

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrInsertingT3 : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 4. ErrBankDeposit_I
        -- El error se considera resuelto si existe un encabezado BK con el
        -- mismo numero de compensacion o si el XML recibido indica tipo BK.
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrBankDeposit_I';

        DELETE ELog
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] ELog
        WHERE ELog.Created    > @FechaCorte
          AND ELog.Status    <> 'Processed'
          AND ELog.Queue_Name = 'PROC_CENTRAL_PAYMENT'
          AND
          (
                EXISTS
                (
                    SELECT 1
                    FROM [EAI_OWNER].[tmp_Account_Header] AccHead
                    WHERE AccHead.Created > @FechaCorte
                      AND AccHead.DocumentType = 'BK'
                      AND AccHead.ClearingDocNumber = ELog.Reference
                )
             OR EXISTS
                (
                    SELECT 1
                    FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] Recv
                    CROSS APPLY
                    (
                        -- TRY_CAST evita abortar toda la depuracion si un
                        -- mensaje historico contiene XML mal formado.
                        SELECT XmlValue = TRY_CAST(Recv.XML_Content AS XML)
                    ) X
                    WHERE Recv.Row_ID = ELog.Reference
                      AND X.XmlValue.value(
                              '(/Payment/Message/ZTMDALLOCPAY/DocumentType/text())[1]',
                              'varchar(10)'
                          ) = 'BK'
                )
          );

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrBankDeposit_I : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 5. ErrT3RF_Error_Log
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrT3RF_Error_Log';

        DELETE Err
        FROM [T3].[RF_Error_Log] Err
        WHERE Err.Fecha > @FechaCorte
          AND
          (
                (
                    Err.Rutina = 'PROC_CFDI_INSERTAR_IFC'
                    AND EXISTS
                    (
                        SELECT 1
                        FROM [T3].[Registro_Fiscal] RF
                        WHERE RF.Factura = Err.Referencia
                    )
                )
             OR (
                    Err.Rutina IN
                    (
                        'GENERAR_MX06',
                        'GENERAR_AGR',
                        'PROC_CFDI_GENERAR_REMISION',
                        'PROC_CFDI_GENERAR_OTROS',
                        'PROC_V40_GENERAR_MX06',
                        'PROC_CFDI_GENERAR_MX06'
                    )
                    AND EXISTS
                    (
                        SELECT 1
                        FROM [T3].[CFDI_Documentos] CFD
                        WHERE CFD.Nota_Venta = Err.Referencia
                    )
                )
             OR (
                    Err.Rutina = 'Proc_T3_CFD_Complemento'
                    AND EXISTS
                    (
                        SELECT 1
                        FROM [T3].[RF_Complemento] CFD
                        WHERE CFD.Factura = Err.Referencia
                    )
                )
          );

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrT3RF_Error_Log : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 6. ErrT3Bitacora_Error
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrT3Bitacora_Error';

        DELETE BE
        FROM [T3].[Bitacora_Error] BE
        WHERE BE.Fecha > @FechaCorte
          AND
          (
                BE.Mensaje LIKE 'EL CLIENTE: PC-00-%'

             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Historia_Cliente_SAP] HCP
                    CROSS APPLY
                    (
                        SELECT PosPagoID = CHARINDEX('Pago_ID', BE.Mensaje)
                    ) P
                    CROSS APPLY
                    (
                        SELECT Cliente_SAP =
                            CASE
                                WHEN P.PosPagoID > 103
                                    THEN SUBSTRING(BE.Mensaje, 102, P.PosPagoID - 103)
                                ELSE NULL
                            END
                    ) X
                    WHERE BE.Mensaje LIKE '<Proc_T3_Pagos> El Cliente SAP no existe en Historia_Cliente_SAP en Interfase de pagos Cliente_Sap%'
                      AND P.PosPagoID > 0
                      AND X.Cliente_SAP = HCP.Cliente_SAP
                )

             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Factura_General] FG
                    CROSS APPLY
                    (
                        SELECT
                            P1 = CHARINDEX('=', BE.Mensaje),
                            P2 = CHARINDEX('=', BE.Mensaje, CHARINDEX('=', BE.Mensaje) + 1)
                    ) A
                    CROSS APPLY
                    (
                        SELECT P3 = CHARINDEX('=', BE.Mensaje, A.P2 + 1)
                    ) B
                    CROSS APPLY
                    (
                        SELECT Factura =
                            CASE
                                WHEN B.P3 > 0
                                    THEN SUBSTRING(BE.Mensaje, B.P3 + 2, 20)
                                ELSE NULL
                            END
                    ) X
                    WHERE BE.Mensaje LIKE '<Proc_T3_Factura> El Cliente SAP es Nulo en la interfase de Facturas Distribuidor%'
                      AND X.Factura = FG.Factura
                      AND YEAR(COALESCE(FG.Fecha_Proc_BATMD, DATEADD(DAY, 366, SYSDATETIME()))) = YEAR(SYSDATETIME())
                )

             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Factura_General] FG
                    CROSS APPLY
                    (
                        SELECT
                            PosFactura = CHARINDEX('Para la factura', BE.Mensaje),
                            PosFecha   = CHARINDEX('de fecha', BE.Mensaje)
                    ) P
                    CROSS APPLY
                    (
                        SELECT Factura =
                            CASE
                                WHEN P.PosFecha > 0 AND P.PosFactura > 0
                                    THEN SUBSTRING(BE.Mensaje, P.PosFactura + 17, P.PosFecha - P.PosFactura - 19)
                                ELSE NULL
                            END
                    ) X
                    WHERE BE.Mensaje LIKE '<proc_ifc_carga_facturas> No se localizo registro vigente del cliente%'
                      AND P.PosFecha > 0
                      AND X.Factura = FG.Factura
                      AND YEAR(COALESCE(FG.Fecha_Proc_BATMD, DATEADD(DAY, 366, SYSDATETIME()))) = YEAR(SYSDATETIME())
                )

             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Factura_General] FG
                    CROSS APPLY
                    (
                        SELECT PosCliente = CHARINDEX('del cliente V3', BE.Mensaje)
                    ) P
                    CROSS APPLY
                    (
                        SELECT Factura =
                            CASE
                                WHEN P.PosCliente > 41
                                    THEN SUBSTRING(BE.Mensaje, 39, P.PosCliente - 41)
                                ELSE NULL
                            END
                    ) X
                    WHERE BE.Mensaje LIKE '<proc_ifc_carga_facturas> La factura <%'
                      AND P.PosCliente > 0
                      AND X.Factura = FG.Factura
                      AND YEAR(COALESCE(FG.Fecha_Proc_BATMD, DATEADD(DAY, 366, SYSDATETIME()))) = YEAR(SYSDATETIME())
                )

             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Factura_General] FG
                    CROSS APPLY
                    (
                        SELECT MsgNormal = REPLACE(BE.Mensaje, '  ', ' ')
                    ) N
                    CROSS APPLY
                    (
                        SELECT
                            PosSpace1 = CHARINDEX(' ', N.MsgNormal)
                    ) S1
                    CROSS APPLY
                    (
                        SELECT
                            PosSpace2 = CHARINDEX(' ', N.MsgNormal, S1.PosSpace1 + 1)
                    ) S2
                    CROSS APPLY
                    (
                        SELECT
                            PosSpace3 = CHARINDEX(' ', N.MsgNormal, S2.PosSpace2 + 1)
                    ) S3
                    CROSS APPLY
                    (
                        SELECT Factura =
                            CASE
                                WHEN S2.PosSpace2 > 0 AND S3.PosSpace3 > S2.PosSpace2
                                    THEN SUBSTRING(N.MsgNormal, S2.PosSpace2 + 1, S3.PosSpace3 - S2.PosSpace2 - 1)
                                ELSE NULL
                            END
                    ) X
                    WHERE BE.Mensaje LIKE 'LA FACTURA%'
                      AND
                      (
                            BE.Mensaje LIKE '%NO TIENE VALORES IGUALES EN HEADER Y DETALLE%'
                         OR BE.Mensaje LIKE '%NO TIENE DETALLE%'
                      )
                      AND X.Factura = FG.Factura
                      AND YEAR(COALESCE(FG.Fecha_Proc_BATMD, DATEADD(DAY, 366, SYSDATETIME()))) = YEAR(SYSDATETIME())
                )

             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Mov_Cliente] MC
                    CROSS APPLY
                    (
                        SELECT PosSpace1 = CHARINDEX(' ', BE.Mensaje)
                    ) S1
                    CROSS APPLY
                    (
                        SELECT PosSpace2 = CHARINDEX(' ', BE.Mensaje, S1.PosSpace1 + 1)
                    ) S2
                    CROSS APPLY
                    (
                        SELECT PosSpace3 = CHARINDEX(' ', BE.Mensaje, S2.PosSpace2 + 1)
                    ) S3
                    CROSS APPLY
                    (
                        SELECT Cliente_V3 =
                            CASE
                                WHEN S2.PosSpace2 > 0 AND S3.PosSpace3 > S2.PosSpace2
                                    THEN SUBSTRING(BE.Mensaje, S2.PosSpace2 + 1, S3.PosSpace3 - S2.PosSpace2 - 1)
                                ELSE NULL
                            END
                    ) X
                    WHERE BE.Mensaje LIKE 'EL CLIENTE%'
                      AND BE.Mensaje LIKE '%tiene distribuidor diferente%'
                      AND X.Cliente_V3 = MC.Cliente_V3
                      AND YEAR(COALESCE(MC.Fecha_Proc_BATMD, DATEADD(DAY, 366, SYSDATETIME()))) = YEAR(SYSDATETIME())
                )

             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Cliente_Agrupado] Agr
                    CROSS APPLY
                    (
                        SELECT
                            PosIgual = CHARINDEX('=', BE.Mensaje),
                            PosArea  = CHARINDEX('area', BE.Mensaje),
                            PosCanal = CHARINDEX('canal', BE.Mensaje)
                    ) P
                    CROSS APPLY
                    (
                        SELECT
                            Distribuidor =
                                CASE
                                    WHEN P.PosArea > P.PosIgual
                                        THEN SUBSTRING(BE.Mensaje, P.PosIgual + 2, P.PosArea - P.PosIgual - 3)
                                    ELSE NULL
                                END,
                            Area =
                                CASE
                                    WHEN P.PosArea > 0
                                        THEN SUBSTRING(BE.Mensaje, P.PosArea + 7, 3)
                                    ELSE NULL
                                END,
                            Canal =
                                CASE
                                    WHEN P.PosCanal > 0
                                        THEN SUBSTRING(BE.Mensaje, P.PosCanal + 8, 2)
                                    ELSE NULL
                                END
                    ) X
                    WHERE BE.Mensaje LIKE '<proc_ifc_carga_clientes> No se Encontro Cliente_Agrupado Distribuidor%'
                      AND X.Distribuidor = Agr.Distribuidor
                      AND X.Area         = Agr.Area_Mgr
                      AND X.Canal        = Agr.Canal
                )
          );

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrT3Bitacora_Error : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 7. ErrIntercompany
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrIntercompany';

        DELETE Err
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err
        CROSS APPLY
        (
            SELECT Message3900 = CAST(SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 1, 3900) AS NVARCHAR(3900))
        ) M
        CROSS APPLY
        (
            SELECT
                DocNumberIni = CHARINDEX('<DocumentNumber>', M.Message3900),
                DocNumberFin = CHARINDEX('</DocumentNumber>', M.Message3900)
        ) P
        CROSS APPLY
        (
            SELECT DocumentoSAP =
                COALESCE
                (
                    Err.Reference,
                    CASE
                        WHEN P.DocNumberIni > 0 AND P.DocNumberFin > P.DocNumberIni
                            THEN SUBSTRING(M.Message3900, P.DocNumberIni + 16, P.DocNumberFin - P.DocNumberIni - 16)
                        ELSE NULL
                    END
                )
        ) X
        INNER JOIN [T3].[Otros_General] OG
            ON X.DocumentoSAP = OG.Factura
        WHERE Err.Queue_Name IN ('Invoice-Intercompany', 'SF_PROC_PREINVOICE_INTER')
          AND Err.Status <> 'Processed'
          AND Err.Created > @FechaCorte;

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrIntercompany : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 8. ErrInvoiceAmpersand
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrInvoice';

        DELETE Err
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err
        CROSS APPLY
        (
            SELECT Message3900 = CAST(SUBSTRING(CAST(Err.[Message] AS NVARCHAR(MAX)), 1, 3900) AS NVARCHAR(3900))
        ) M
        CROSS APPLY
        (
            SELECT
                DocNumberIni = CHARINDEX('<DocumentNumber>', M.Message3900),
                DocNumberFin = CHARINDEX('</DocumentNumber>', M.Message3900)
        ) P
        CROSS APPLY
        (
            SELECT DocumentoSAP =
                CASE
                    WHEN P.DocNumberIni > 0 AND P.DocNumberFin > P.DocNumberIni
                        THEN SUBSTRING(M.Message3900, P.DocNumberIni + 16, P.DocNumberFin - P.DocNumberIni - 16)
                    ELSE NULL
                END
        ) X
        WHERE Err.Queue_Name = 'Invoice'
          AND Err.Status <> 'Processed'
          AND Err.Created > @FechaCorte
          AND
          (
                EXISTS
                (
                    SELECT 1
                    FROM [T3].[Preventa_General] PG
                    WHERE PG.Entrega = X.DocumentoSAP
                )
             OR EXISTS
                (
                    SELECT 1
                    FROM [T3].[Factura_General] FG
                    WHERE FG.Entrega = X.DocumentoSAP
                )
          );

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrInvoice : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 9. ErrDeliveryRepl
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrReplenishment';

        DELETE Err
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err
        INNER JOIN [EAI_OWNER].[tmp_Document_Header] Delv
            ON Err.Reference = Delv.ReferenceID
        WHERE Err.Queue_Name = 'VanReplenishment'
          AND Err.Created > @FechaCorte;

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrReplenishment : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 10. ErrPromptDocuments
        -- Aunque el cursor Oracle consulta tambien PROC_PREINVOICE_IFC, su
        -- DELETE final limita la limpieza a las cuatro colas indicadas abajo.
        -- Se conserva expresamente esa regla para no borrar mensajes extra.
        ----------------------------------------------------------------------
        SET @sRow_ID = 'ErrPromptDocuments';

        DELETE ELog
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] ELog
        INNER JOIN [T3].[Factura_General] FG
            ON ELog.ID = FG.Row_ID
        WHERE FG.Fecha_Trn > @Fecha7Dias
          AND ELog.Queue_Name IN
              (
                  'REP_INVOICE',
                  'SEND_INVOICE',
                  'REP_CREDIT_NOTE',
                  'SEND_CREDIT_NOTE'
              )
          AND ELog.Created > @Fecha7Dias
          AND ELog.ID IS NOT NULL;

        SET @nRegistros = @@ROWCOUNT;
        SET @nProceso4 += @nRegistros;

        IF @pOutput > 0
        BEGIN
            PRINT CONCAT('ErrPromptDocuments : ', FORMAT(@nRegistros, 'N0'));
            PRINT CONCAT('Termino ', FORMAT(SYSDATETIME(), 'yyyyMMdd HH:mm:ss'));
        END;

        ----------------------------------------------------------------------
        -- 11. Reenvío CFDI condicionado
        ----------------------------------------------------------------------
        IF @pDias < 10
        BEGIN
            EXEC [EAI_OWNER].[WA_RESEND_CFDI]
                @pDias = @pDias,
                @pOutput = @pOutput;
        END;

        ----------------------------------------------------------------------
        -- 12. Cierre de proceso
        ----------------------------------------------------------------------
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
        SET Status = 1
        WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
        SET
            Fin       = SYSDATETIME(),
            Proceso_1 = 0,
            Proceso_2 = 0,
            Proceso_3 = 0,
            Proceso_4 = @nProceso4
        WHERE PID = @nPID;

    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- No se hace ROLLBACK: este procedimiento no abre una transaccion y
        -- revertir aqui podria afectar la transaccion del proceso invocador.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction,
            Reference,
            Created,
            Message,
            Job_PID,
            Status,
            Queue_Name,
            Siebel_Error_Message,
            Source,
            Siebel_Error_Code,
            Retry_Count,
            Sequence,
            Parent_Row_ID
        )
        VALUES
        (
            'Depura ERR_MSG_LOG',
            @sRow_ID,
            SYSDATETIME(),
            NULL,
            @nPID,
            'Error',
            'WA_DEPURA_MESSAGE_LOG',
            @sMsg,
            'WA',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;
    END CATCH;
END;
GO

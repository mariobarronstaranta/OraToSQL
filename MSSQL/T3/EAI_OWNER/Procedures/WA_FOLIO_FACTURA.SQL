CREATE OR ALTER PROCEDURE [EAI_Owner].[WA_FOLIO_FACTURA]
(
    @pFolioSAP       VARCHAR(50),
    @pCentro         VARCHAR(10),
    @pClaseFactura   VARCHAR(10),
    @dtFechaFactura  DATE,
    @nOutput         INT = 0,
    @sFolioT3        VARCHAR(30) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @sMsg          VARCHAR(500),
        @sRow_ID       VARCHAR(20),
        @sErrorCode    VARCHAR(20),
        @nFolio        INT,
        @sCalcular     VARCHAR(30),
        @sMes          VARCHAR(30),
        @sCentro       VARCHAR(4),
        @SeriePar      VARCHAR(30),
        @FolioPar      INT,
        @SerieNon      VARCHAR(30),
        @FolioNon      INT,
        @StartedTran   BIT = 0;

    BEGIN TRY
        SET @sRow_ID   = LEFT(@pFolioSAP, 20);
        SET @sCalcular = 'NO';
        SET @nFolio    = 0;
        SET @sFolioT3  = NULL;

        /*
            Determinación de clases que requieren cálculo de folio.
            Se conserva la lógica original del procedure Oracle.
        */
        IF @pClaseFactura IN ('C005', 'C006') -- Preventa
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = LEFT(@pCentro, 4);
        END
        ELSE IF @pClaseFactura IN ('C0FX', 'C019') -- Gastos Admtvos / Bonificación
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = 'MX99';
        END
        ELSE IF @pClaseFactura IN ('C025') -- Rebates
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = 'MX99';
        END
        ELSE IF @pClaseFactura IN ('C030', 'C031') -- Cargos y Créditos por Ajuste de Inventario
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = 'MX99';
        END
        ELSE IF @pClaseFactura IN ('C020', 'C021', 'C022') -- Intercompany
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = 'MX99';
        END
        ELSE IF @pClaseFactura = 'DN' -- Debit Note to V3
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = 'MX99';
        END
        ELSE IF @pClaseFactura = 'SUBD' -- Traslados a Subdepósitos
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = 'MX99';
        END
        ELSE IF @pClaseFactura = 'REM' -- Remisión
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = LEFT(@pCentro, 4);
        END
        ELSE IF @pClaseFactura = 'INVT' -- Traslado de Factura
        BEGIN
            SET @sCalcular = 'SI';
            SET @sCentro   = LEFT(@pCentro, 4);
        END;

        IF @sCalcular = 'SI'
        BEGIN
            /*
                Se abre transacción para proteger:
                1. Consulta de relación existente.
                2. Lectura del consecutivo.
                3. Incremento del consecutivo.
                4. Inserción de relación.
            */
            IF @@TRANCOUNT = 0
            BEGIN
                BEGIN TRANSACTION;
                SET @StartedTran = 1;
            END;

            /*
                Mes Non: enero, marzo, mayo, julio, septiembre, noviembre.
                Mes Par: febrero, abril, junio, agosto, octubre, diciembre.
            */
            IF MONTH(@dtFechaFactura) IN (1, 3, 5, 7, 9, 11)
                SET @sMes = 'Non';
            ELSE
                SET @sMes = 'Par';

            /*
                Clases que siempre aplican serie Non.
            */
            IF @pClaseFactura IN ('DN', 'SUBD', 'C025', 'REM', 'INVT')
                SET @sMes = 'Non';

            /*
                Primero valida si ya existe relación.
                UPDLOCK + HOLDLOCK evita que dos sesiones intenten insertar
                la misma relación simultáneamente.
            */
            SELECT TOP (1)
                @sFolioT3 = R.FacturaT3,
                @nFolio = 1
            FROM [EAI_Owner].[MX_NRIV_RELACION] AS R WITH (UPDLOCK, HOLDLOCK)
            WHERE R.FacturaSAP    = @pFolioSAP
              AND R.Clase_Factura = @pClaseFactura;

            /*
                Si no existe relación, se genera nuevo folio.
            */
            IF @nFolio = 0
            BEGIN
                /*
                    Se bloquea la fila de configuración de NRIV para evitar
                    duplicidad de folios bajo concurrencia.
                */
                SELECT TOP (1)
                    @SeriePar = N.Serie_Par,
                    @FolioPar = N.Folio_Par,
                    @SerieNon = N.Serie_Non,
                    @FolioNon = N.Folio_Non,
                    @nFolio   = 1
                FROM [EAI_Owner].[MX_NRIV] AS N WITH (UPDLOCK, HOLDLOCK)
                WHERE N.Centro        = @sCentro
                  AND N.Clase_Factura = @pClaseFactura;

                IF @nFolio = 1
                BEGIN
                    IF @sMes = 'Non'
                    BEGIN
                        SET @sFolioT3 =
                            CONCAT(
                                @SerieNon,
                                '-',
                                RIGHT(REPLICATE('0', 6) + CONVERT(VARCHAR(20), @FolioNon), 6)
                            );

                        UPDATE [EAI_Owner].[MX_NRIV]
                        SET Folio_Non = Folio_Non + 1
                        WHERE Centro        = @sCentro
                          AND Clase_Factura = @pClaseFactura;
                    END
                    ELSE
                    BEGIN
                        SET @sFolioT3 =
                            CONCAT(
                                @SeriePar,
                                '-',
                                RIGHT(REPLICATE('0', 6) + CONVERT(VARCHAR(20), @FolioPar), 6)
                            );

                        UPDATE [EAI_Owner].[MX_NRIV]
                        SET Folio_Par = Folio_Par + 1
                        WHERE Centro        = @sCentro
                          AND Clase_Factura = @pClaseFactura;
                    END;

                    INSERT INTO [EAI_Owner].[MX_NRIV_RELACION]
                    (
                        FacturaSAP,
                        FacturaT3,
                        Clase_Factura
                    )
                    VALUES
                    (
                        @pFolioSAP,
                        @sFolioT3,
                        @pClaseFactura
                    );
                END
                ELSE
                BEGIN
                    /*
                        No hay rango configurado en NRIV.
                        Se conserva comportamiento Oracle:
                        regresar el folio SAP como folio T3 y registrar error.
                    */
                    SET @sFolioT3 = @pFolioSAP;

                    INSERT INTO [EAI_Owner].[MX_EAI_MESSAGE_LOG]
                    (
                        DIRECTION,
                        REFERENCE,
                        CREATED,
                        MESSAGE,
                        STATUS,
                        QUEUE_NAME,
                        SIEBEL_ERROR_MESSAGE,
                        SOURCE,
                        SIEBEL_ERROR_CODE,
                        RETRY_COUNT,
                        SEQUENCE,
                        PARENT_ROW_ID
                    )
                    VALUES
                    (
                        'FolioFactura',
                        CONCAT(@sCentro, '/', @pClaseFactura),
                        SYSDATETIME(),
                        NULL,
                        'Error',
                        'Folio Interno',
                        NULL,
                        'PL/SQL',
                        'No hay NRIV',
                        NULL,
                        NULL,
                        NULL
                    );
                END;
            END;

            IF @StartedTran = 1 AND XACT_STATE() = 1
            BEGIN
                COMMIT TRANSACTION;
                SET @StartedTran = 0;
            END;

            IF @nOutput > 0
            BEGIN
                PRINT CONCAT('FacturaSAP   => ', @pFolioSAP);
                PRINT CONCAT('FacturaT3    => ', @sFolioT3);
            END;
        END
        ELSE
        BEGIN
            SET @sFolioT3 = @pFolioSAP;
        END;
    END TRY
    BEGIN CATCH
        /*
            Se revierte sólo si este procedure inició la transacción.
            Si venía dentro de una transacción externa, no se hace COMMIT.
        */
        IF @StartedTran = 1 AND XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @StartedTran = 0;
        END;

        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(
                       CONCAT(
                           CONVERT(VARCHAR(20), ERROR_NUMBER()),
                           '-',
                           ERROR_MESSAGE()
                       ),
                       250
                   );

        /*
            Se intenta registrar el error técnico.
            Se conserva el comportamiento Oracle: registrar y no relanzar.
        */
        BEGIN TRY
            INSERT INTO [EAI_Owner].[MX_EAI_MESSAGE_LOG]
            (
                DIRECTION,
                REFERENCE,
                CREATED,
                MESSAGE,
                STATUS,
                QUEUE_NAME,
                SIEBEL_ERROR_MESSAGE,
                SOURCE,
                SIEBEL_ERROR_CODE,
                RETRY_COUNT,
                SEQUENCE,
                PARENT_ROW_ID
            )
            VALUES
            (
                'FolioFactura',
                @sRow_ID,
                SYSDATETIME(),
                NULL,
                'Error',
                'Folio Interno',
                @sMsg,
                'WA',
                @sErrorCode,
                NULL,
                NULL,
                NULL
            );
        END TRY
        BEGIN CATCH
            /*
                Si también falla el log, se evita romper el comportamiento
                silencioso del Oracle original.
            */
        END CATCH;
    END CATCH;
END;
GO
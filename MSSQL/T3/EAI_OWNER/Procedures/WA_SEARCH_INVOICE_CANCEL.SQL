/*
    Homologo SQL Server de EAI_OWNER.WA_SEARCH_INVOICE_CANCEL (Oracle).

    Objetivo:
      Buscar facturas intercompany FPIN/FNIN asociadas al pedido SAP recibido.
      Cada factura que aun no tiene fecha de cancelacion se envia a
      EAI.UPDATE_FACT_CANCEL y la ultima factura recorrida se devuelve mediante
      @sFolioFiscal.

    Compatibilidad:
      @sSAPInvoice existe en la firma Oracle pero no participa en ninguna regla
      del procedimiento. Se conserva para no romper los procesos llamadores.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_SEARCH_INVOICE_CANCEL]
    @sSAPOrder    VARCHAR(50),
    @sSAPInvoice  VARCHAR(50),
    @sFolioFiscal VARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @Docto              CHAR(2),
        @Factura            VARCHAR(50),
        @Fecha_Cancelacion  DATETIME2(0);

    -- Un parametro OUT de Oracle inicia sin valor para quien invoca. Si el
    -- cursor no encuentra documentos, SQL Server tambien devolvera NULL.
    SET @sFolioFiscal = NULL;

    /*
        Se conserva la estructura del cursor Oracle:
          1. UNION obtiene pares Factura/Pedido FPIN y FNIN sin duplicados.
          2. El pedido se filtra sobre ese conjunto.
          3. La tabla vuelve a unirse solamente por Factura.

        No se simplifica a PG.Pedido = @sSAPOrder porque eso cambiaria el
        resultado si una misma factura apareciera relacionada con otro pedido.
    */
    DECLARE ScrDoctos CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            'PG' AS Docto,
            PG.Factura,
            PG.Fecha_Cancelacion
        FROM
        (
            SELECT P.Factura, P.Pedido
            FROM [T3].[Preventa_General] P
            WHERE P.Factura LIKE 'FPIN%'

            UNION

            SELECT P.Factura, P.Pedido
            FROM [T3].[Preventa_General] P
            WHERE P.Factura LIKE 'FNIN%'
        ) Doc
        INNER JOIN [T3].[Preventa_General] PG
            ON PG.Factura = Doc.Factura
        WHERE Doc.Pedido = @sSAPOrder;

    BEGIN TRY
        BEGIN TRANSACTION;

        OPEN ScrDoctos;

        FETCH NEXT FROM ScrDoctos
        INTO @Docto, @Factura, @Fecha_Cancelacion;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Oracle sobrescribe el parametro OUT en cada iteracion; por eso
            -- al finalizar contiene la ultima factura recorrida.
            SET @sFolioFiscal = @Factura;

            IF @Fecha_Cancelacion IS NULL
            BEGIN
                -- Todos los registros actuales son de tipo PG. La condicion se
                -- conserva porque forma parte explicita de la regla Oracle.
                IF @Docto = 'PG'
                BEGIN
                    EXEC [EAI].[UPDATE_FACT_CANCEL]
                        @t_Factura = @sFolioFiscal;
                END;
            END;

            FETCH NEXT FROM ScrDoctos
            INTO @Docto, @Factura, @Fecha_Cancelacion;
        END;

        CLOSE ScrDoctos;
        DEALLOCATE ScrDoctos;

        -- Confirma en una sola unidad las cancelaciones y auditorias generadas
        -- por EAI.UPDATE_FACT_CANCEL, igual que el COMMIT final de Oracle.
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- CLOSE solo es valido cuando el cursor se encuentra abierto.
        IF CURSOR_STATUS('local', 'ScrDoctos') >= 0
            CLOSE ScrDoctos;

        IF CURSOR_STATUS('local', 'ScrDoctos') > -2
            DEALLOCATE ScrDoctos;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        -- El procedimiento Oracle no oculta excepciones.
        THROW;
    END CATCH;
END;
GO

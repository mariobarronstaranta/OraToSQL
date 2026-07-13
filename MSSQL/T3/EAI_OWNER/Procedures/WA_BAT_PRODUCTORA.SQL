CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_BAT_PRODUCTORA]
(
    @pDays INT = 14
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        WA_BAT_PRODUCTORA
        =================
        Corrige documentos recientes de preventa provenientes de productora.

        Para cada factura pendiente realiza dos pasos:
        1. Convierte cantidades TH/MIL usando Referencia_Pedido y Cig_x_CLL,
           y cambia la unidad a la unidad maestra del material.
        2. Recalcula el IVA de cada linea a partir del porcentaje entero y
           vuelve a sumar el IVA total del encabezado.

        Solo se consideran documentos DPIN, DNIN, FPIN y FNIN dentro de la
        ventana indicada por @pDays y aun no procesados por BATMD.
    */

    DECLARE @Factura      VARCHAR(20);
    DECLARE @v_ID         VARCHAR(20);
    DECLARE @nIndice      INT;
    DECLARE @sMsg         VARCHAR(250);
    DECLARE @sErrorCode   VARCHAR(20);

    BEGIN TRY

        DECLARE curFacturas CURSOR LOCAL FAST_FORWARD FOR

        SELECT Factura
        FROM [T3].[Preventa_General]
        WHERE LEFT(Factura,4) IN ('DPIN','DNIN','FPIN','FNIN')
          AND Fecha_Factura > DATEADD(DAY,-@pDays,GETDATE())
          AND Fecha_Proc_BATMD IS NULL
        ORDER BY Fecha_Trn DESC;

        OPEN curFacturas;

        FETCH NEXT FROM curFacturas INTO @Factura;

        WHILE @@FETCH_STATUS = 0
        BEGIN

            SET @v_ID = @Factura;

            BEGIN TRANSACTION;

            /*
                Cantidad_a_Facturar_con_Dec en Oracle:
                    Referencia_Pedido * 1000 / Cig_x_CLL

                No se usa NULLIF. Si Cig_x_CLL es cero, el error señala un dato
                maestro inválido y evita guardar una cantidad NULL silenciosa.
            */

            UPDATE PD
               SET Cantidad_Vta =
                    PD.Referencia_Pedido * 1000.0 / M.Cig_x_CLL,

                   Unidad_Med_Vta =
                    M.Unidad_Med_Vta
            FROM T3.Preventa_Detalle PD
            INNER JOIN T3.Material M
                ON PD.Material = M.Material
            WHERE PD.Factura = @Factura
              AND PD.Unidad_Med_Vta IN ('TH','MIL')
              AND M.Material NOT LIKE '50%';

            SET @nIndice = @@ROWCOUNT;

            IF @nIndice > 0
            BEGIN

                UPDATE T3.Preventa_General
                   SET Fecha_Proc_BATMD = NULL
                 WHERE Factura = @Factura;

            END

            /*
                Oracle obtiene primero el porcentaje entero de IVA:
                    ROUND(Valor_IVA * 100 / Valor_Subt, 0)
                y luego recalcula el importe con dos decimales.
            */

            ;WITH IVA_FIX AS
            (
                SELECT
                    Factura,
                    Num_Linea,
                    Material,

                    ROUND(
                        Valor_Subt *
                        ROUND(
                            Valor_IVA * 100.0 /
                            Valor_Subt,
                            0
                        ) / 100.0,
                        2
                    ) AS IVA_CFD

                FROM T3.Preventa_Detalle
                WHERE Factura = @Factura
            )
            UPDATE PD
               SET Valor_IVA = F.IVA_CFD
            FROM T3.Preventa_Detalle PD
            INNER JOIN IVA_FIX F
                 ON PD.Factura = F.Factura
                AND PD.Num_Linea = F.Num_Linea
                AND PD.Material = F.Material
            WHERE PD.Valor_IVA <> F.IVA_CFD;

            SET @nIndice = @@ROWCOUNT;

            IF @nIndice > 0
            BEGIN

                UPDATE PG
                   SET Valor_IVA =
                   (
                       SELECT SUM(Valor_IVA)
                       FROM T3.Preventa_Detalle D
                       WHERE D.Factura = PG.Factura
                   )
                FROM T3.Preventa_General PG
                WHERE PG.Factura = @Factura;

                -- El log solo se genera cuando al menos una linea de IVA cambia.
                INSERT INTO [EAI_OWNER].[WA_Logging]
                (
                    Fecha,
                    Usuario,
                    Usuario_Red,
                    IP,
                    Terminal,
                    Documento,
                    Comentario
                )
                VALUES
                (
                    GETDATE(),
                    SUSER_SNAME(),
                    ORIGINAL_LOGIN(),
                    -- CONNECTIONPROPERTY devuelve sql_variant. La columna IP
                    -- es VARCHAR(30), por lo que la conversion es obligatoria.
                    CONVERT(VARCHAR(30), CONNECTIONPROPERTY('client_net_address')),
                    HOST_NAME(),
                    @Factura,
                    'WA_BAT_PRODUCTORA ( IVA '
                    + CAST(@nIndice AS VARCHAR(10))
                    + ' )'
                );

            END

            COMMIT TRANSACTION;

            FETCH NEXT FROM curFacturas INTO @Factura;
        END

        CLOSE curFacturas;
        DEALLOCATE curFacturas;

    END TRY

    BEGIN CATCH

        -- El error puede ocurrir antes de cerrar el cursor principal.
        IF CURSOR_STATUS('local', 'curFacturas') >= 0
            CLOSE curFacturas;

        IF CURSOR_STATUS('local', 'curFacturas') >= -1
            DEALLOCATE curFacturas;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-' +
                ERROR_MESSAGE(),
                250
            );

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            ID,
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
            'WA_BAT_PRODUCTORA',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'WA_BAT_PRODUCTORA',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH
END
GO

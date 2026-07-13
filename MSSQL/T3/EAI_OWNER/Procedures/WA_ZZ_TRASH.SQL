/*
    Homologo SQL Server de EAI_OWNER.WA_ZZ_TRASH (Oracle).

    Objetivo:
      Recorrer los detalles de facturas C005 de los ultimos siete dias y
      ejecutar WA_QTY_SAP_BILLING para probar/calcular la conversion de unidad
      de medida de cada material.

    Aunque los valores calculados no se guardan en este procedimiento, la
    llamada puede generar registros en EAI_OWNER.WA_Logging. Por ese motivo no
    debe sustituirse el cursor por un simple COUNT.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ZZ_TRASH]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        -- Los tipos coinciden con la firma SQL Server de WA_QTY_SAP_BILLING.
        @nCantUMV       DECIMAL(38, 10),
        @sUMV           VARCHAR(30),
        @nItems         BIGINT = 0,
        @Entrega        VARCHAR(100),
        @Material       VARCHAR(100),
        @Cantidad_Vta   DECIMAL(38, 10),
        @Unidad_Med_Vta VARCHAR(30);

    /*
        Solo se recuperan las columnas utilizadas por la llamada dependiente.
        Los joins son los mismos de Oracle, por lo que se conserva exactamente
        el conjunto y la cantidad de renglones procesados.

        CONVERT(date, DATEADD(...)) equivale a TRUNC(SYSDATE - 7): incluye
        desde las 00:00:00 del dia situado siete dias antes de la ejecucion.
    */
    DECLARE ScrDocuments CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            PG.Entrega,
            PD.Material,
            PD.Cantidad_Vta,
            PD.Unidad_Med_Vta
        FROM [T3].[Preventa_General] PG
        INNER JOIN [T3].[Preventa_Detalle] PD
            ON PD.Factura = PG.Factura
        INNER JOIN [T3].[Material] SKU
            ON SKU.Material = PD.Material
        WHERE PG.Fecha_Factura >= CONVERT(date, DATEADD(DAY, -7, SYSDATETIME()))
          AND PG.Clase_Factura = 'C005';

    BEGIN TRY
        BEGIN TRANSACTION;

        OPEN ScrDocuments;

        FETCH NEXT FROM ScrDocuments
        INTO @Entrega, @Material, @Cantidad_Vta, @Unidad_Med_Vta;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Oracle reinicia ambas salidas antes de procesar cada renglon.
            SET @nCantUMV = 0;
            SET @sUMV = '';
            SET @nItems += 1;

            EXEC [EAI_OWNER].[WA_QTY_SAP_BILLING]
                @pReference    = @Entrega,
                @pMaterial     = @Material,
                @pCantidad     = @Cantidad_Vta,
                @pUnidadMedida = @Unidad_Med_Vta,
                @pCantUMV      = @nCantUMV OUTPUT,
                @pUMV          = @sUMV OUTPUT;

            FETCH NEXT FROM ScrDocuments
            INTO @Entrega, @Material, @Cantidad_Vta, @Unidad_Med_Vta;
        END;

        CLOSE ScrDocuments;
        DEALLOCATE ScrDocuments;

        PRINT CONCAT('Items : ', @nItems);

        -- Confirma tambien cualquier registro de WA_Logging generado por la
        -- rutina de conversion, igual que el COMMIT final de Oracle.
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- El cursor debe liberarse aun cuando falle una llamada dependiente.
        IF CURSOR_STATUS('local', 'ScrDocuments') >= 0
            CLOSE ScrDocuments;

        IF CURSOR_STATUS('local', 'ScrDocuments') > -2
            DEALLOCATE ScrDocuments;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        -- Oracle no define EXCEPTION en este procedimiento; por lo tanto, un
        -- error debe regresar al invocador en lugar de ocultarse.
        THROW;
    END CATCH;
END;
GO

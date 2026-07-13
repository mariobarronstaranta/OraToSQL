/*
    Homologo SQL Server de EAI_OWNER.WA_RESEND_CFDI (Oracle).

    Objetivo:
      Preparar para reenvio los CFDI liberados recientemente cuyo ID_ENVIO
      tiene como maximo cuatro caracteres. Para hacerlo se limpian los datos
      del envio anterior y se genera una entrada de auditoria por cada fila
      seleccionada por el cursor original.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_RESEND_CFDI]
    @pDias   INT = 4,
    @pOutput INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @nIndice    INT = 0,
        @sMsg       VARCHAR(500),
        @v_ID       VARCHAR(20),
        @sErrorCode VARCHAR(20),
        @FechaInicio DATE;

    /*
        Equivale a TRUNC(SYSDATE - pDias). No se aplica ISNULL a @pDias:
        en Oracle, enviar NULL explicitamente produce un corte NULL y no
        selecciona documentos; el valor 4 solo aplica cuando se omite.
    */
    SET @FechaInicio = CONVERT(date, DATEADD(DAY, -@pDias, SYSDATETIME()));

    /*
        No se usa DISTINCT ni llave primaria. El cursor Oracle puede contener
        varias filas con la misma Nota_Venta y genera una bitacora por cada una.
        Nota_Venta tambien puede ser NULL: en ese caso Oracle registra el intento
        pero su UPDATE por igualdad no modifica filas.
    */
    DECLARE @Documentos TABLE
    (
        Selection_ID BIGINT IDENTITY(1, 1) NOT NULL,
        Nota_Venta   VARCHAR(30) NULL
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO @Documentos (Nota_Venta)
        SELECT CFDI.Nota_Venta
        FROM [T3].[CFDI_Documentos] CFDI
        WHERE CFDI.Fecha_Liberacion >= @FechaInicio
          AND CFDI.Fecha_Envio IS NOT NULL
          -- Oracle LENGTH(NULL) y LENGTH('') no cumplen <= 4. DATALENGTH
          -- distingue la cadena realmente vacia de una cadena con espacios.
          AND CFDI.ID_Envio IS NOT NULL
          AND DATALENGTH(CFDI.ID_Envio) > 0
          -- Agregar un marcador permite que LEN cuente espacios finales,
          -- igual que LENGTH de Oracle para una columna VARCHAR2.
          AND LEN(CFDI.ID_Envio + '#') - 1 <= 4;

        /*
            Oracle actualiza por Nota_Venta, no por la fila fisica del cursor.
            Por ello, si una nota aparece en @Documentos, se limpian todas las
            filas de CFDI_Documentos que comparten esa nota.
        */
        UPDATE CFDI
        SET
            CFDI.Fecha_Envio = NULL,
            CFDI.ID_Envio    = NULL,
            CFDI.Status      = NULL
        FROM [T3].[CFDI_Documentos] CFDI
        WHERE EXISTS
        (
            SELECT 1
            FROM @Documentos D
            WHERE D.Nota_Venta = CFDI.Nota_Venta
        );

        /*
            Se conserva una entrada por fila seleccionada, incluidos duplicados.
            CONNECTIONPROPERTY devuelve sql_variant; CONVERT evita el error 257
            de conversion implicita y ajusta el dato al VARCHAR(30) de la tabla.
        */
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
        SELECT
            SYSDATETIME(),
            SUSER_SNAME(),
            ORIGINAL_LOGIN(),
            CONVERT(VARCHAR(30), CONNECTIONPROPERTY('client_net_address')),
            HOST_NAME(),
            D.Nota_Venta,
            'EAI_Owner.WA_Resend_CFDI'
        FROM @Documentos D;

        COMMIT TRANSACTION;

        /*
            nIndice se conserva en cero porque el procedimiento Oracle nunca lo
            incrementa. En consecuencia, este bloque no produce salida; mantener
            la condicion evita cambiar el contrato existente de @pOutput.
        */
        IF @pOutput > 0 AND @nIndice > 0
            PRINT CONCAT('Documentos -> ', @nIndice);
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction,
            ID,
            Created,
            Message,
            Status,
            Queue_Name,
            Siebel_Error_Message,
            Source,
            Siebel_Error_Code,
            Retry_Count,
            [Sequence],
            Parent_Row_ID
        )
        VALUES
        (
            'WA_RESEND_CFDI',
            @v_ID,
            SYSDATETIME(),
            NULL,
            'Error',
            'WA_RESEND_CFDI',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra la excepcion y termina sin propagarla.
        RETURN;
    END CATCH;
END;
GO

/*
    Procedure : EAI_OWNER.PURGE_TEMPORAL_SAP
    Objetivo  : Depurar tablas temporales SAP por periodo YYYYMM o eliminar
                documentos incompletos mediante la opción DOCUMENT-NULL.
    Integridad: En DOCUMENT se eliminan primero hijos y al final el encabezado,
                respetando las relaciones lógicas del documento.
    Errores   : Se registran en MX_EAI_MESSAGE_LOG sin propagarse, como Oracle.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.PURGE_TEMPORAL_SAP
(
      @sPeriod      VARCHAR(50),
      @sTableName   VARCHAR(50)
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sEtapa       VARCHAR(40),
        @sMsg         VARCHAR(500),
        @sErrorCode   VARCHAR(20);

    BEGIN TRY

        -- El parámetro se recibe más ancho para poder validarlo antes de usarlo.
        -- Declararlo VARCHAR(6) truncaría, por ejemplo, 20260199 a 202601 y
        -- podría borrar enero aunque el valor original fuera inválido.
        IF UPPER(@sTableName) IN ('ACCOUNTING', 'DOCUMENT')
           AND
           (
               @sPeriod IS NULL
               OR LEN(@sPeriod) <> 6
               OR @sPeriod LIKE '%[^0-9]%'
               OR TRY_CONVERT(DATE, @sPeriod + '01', 112) IS NULL
           )
            THROW 50011, 'El periodo debe tener el formato YYYYMM y representar un mes válido.', 1;

        -- Una modalidad completa se confirma como unidad. Si falla la limpieza
        -- de un hijo, el rollback evita dejar un documento parcialmente borrado.
        BEGIN TRANSACTION;

        -----------------------------------------------------------------
        -- ACCOUNTING
        -----------------------------------------------------------------
        IF UPPER(@sTableName) = 'ACCOUNTING'
        BEGIN

            SET @sEtapa = 'TMP_ACCOUNT_HEADER';

            DELETE A
            FROM EAI_OWNER.TMP_ACCOUNT_HEADER A
            WHERE CONVERT(CHAR(6),A.Created,112) = @sPeriod;

        END

        -----------------------------------------------------------------
        -- DOCUMENT
        -----------------------------------------------------------------
        ELSE IF UPPER(@sTableName) = 'DOCUMENT'
        BEGIN

            SET @sEtapa = 'TMP_DOCUMENT_HEADER';

            -- Se toma la misma lista de documentos para eliminar primero las
            -- condiciones; el encabezado se conserva hasta limpiar sus hijos.
            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE CONVERT(CHAR(6),Created,112) = @sPeriod
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL_COND D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE CONVERT(CHAR(6),Created,112) = @sPeriod
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE CONVERT(CHAR(6),Created,112) = @sPeriod
            )

            DELETE P
            FROM EAI_OWNER.TMP_DOCUMENT_PARTNERS P
            INNER JOIN Docs X
                ON X.ReferenceID = P.ReferenceID;

            DELETE H
            FROM EAI_OWNER.TMP_DOCUMENT_HEADER H
            WHERE CONVERT(CHAR(6),H.Created,112) = @sPeriod;

        END

        -----------------------------------------------------------------
        -- DOCUMENT-NULL
        -----------------------------------------------------------------
        ELSE IF UPPER(@sTableName) = 'DOCUMENT-NULL'
        BEGIN

            SET @sEtapa = 'TMP_DOCUMENT_HEADER';

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE Created IS NULL
                AND DeliveryType IS NULL
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL_COND D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE Created IS NULL
                AND DeliveryType IS NULL
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            DELETE H
            FROM EAI_OWNER.TMP_DOCUMENT_HEADER H
            WHERE Created IS NULL
            AND DeliveryType IS NULL;

        END

        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CONCAT(
                    ERROR_NUMBER(),
                    '-',
                    ERROR_MESSAGE()
                ),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
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
            'Purge',
            NULL,
            GETDATE(),
            NULL,
            'Error',
            @sEtapa,
            @sMsg,
            'Purge',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- El caller puede consultar la bitácora; Oracle no devuelve excepción.

    END CATCH

END
GO

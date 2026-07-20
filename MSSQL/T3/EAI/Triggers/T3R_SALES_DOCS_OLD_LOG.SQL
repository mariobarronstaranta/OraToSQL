SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Objeto  : [EAI].[T3R_SALES_DOCS_OLD_LOG]
Origen  : ORA/T3/EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL
Evento  : UPDATE sobre [EAI].[T3R_SALES_DOCS_OLD]
Proposito:
    Crear una entrada de auditoria por cada documento que cambie en alguna
    de las columnas supervisadas por el trigger Oracle.

Notas de migracion:
    - El trigger es set-based: una sola sentencia puede actualizar muchas
      filas y cada una genera su propio texto de cambios.
    - [DOC_NUM_R3] es la clave logica utilizada por los procesos del
      repositorio para localizar documentos. El DDL no impone una PK o un
      indice UNIQUE; DuplicateOrdinal evita productos cartesianos si hay
      valores repetidos.
    - No se debe modificar [DOC_NUM_R3] con este trigger activo. inserted y
      deleted no ofrecen una identidad comun cuando cambia esa clave. Para
      soportar ese escenario correctamente se requiere una llave tecnica
      inmutable en [EAI].[T3R_SALES_DOCS_OLD].
    - Las comparaciones de texto usan <> sin normalizar NULL, igual que el
      operador != de Oracle. Las tres columnas numericas conservan NVL(x, 0)
      mediante ISNULL(x, 0).
*/
CREATE OR ALTER TRIGGER [EAI].[T3R_SALES_DOCS_OLD_LOG]
ON [EAI].[T3R_SALES_DOCS_OLD]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH PreviousRows AS
    (
        SELECT
            d.[DOC_DATE],
            d.[DISTRIBUTOR],
            d.[CUSTOMER],
            d.[DOC_NUM_R3],
            d.[DOC_ORD_R3],
            d.[DOC_NUM_REF1],
            d.[DOC_NUM_REF2],
            d.[DOC_TYPE],
            d.[DOC_STATUS],
            d.[DOC_QTY],
            d.[DOC_NETAMT],
            d.[DOC_TAXAMT],
            d.[CREATED],
            ROW_NUMBER() OVER
            (
                PARTITION BY d.[DOC_NUM_R3]
                ORDER BY
                    d.[DOC_DATE], d.[DISTRIBUTOR], d.[CUSTOMER],
                    d.[DOC_ORD_R3], d.[DOC_NUM_REF1], d.[DOC_NUM_REF2],
                    d.[DOC_TYPE], d.[DOC_STATUS], d.[DOC_QTY],
                    d.[DOC_NETAMT], d.[DOC_TAXAMT], d.[CREATED]
            ) AS DuplicateOrdinal
        FROM deleted AS d
    ),
    CurrentRows AS
    (
        SELECT
            i.[DOC_DATE],
            i.[DISTRIBUTOR],
            i.[CUSTOMER],
            i.[DOC_NUM_R3],
            i.[DOC_ORD_R3],
            i.[DOC_NUM_REF1],
            i.[DOC_NUM_REF2],
            i.[DOC_TYPE],
            i.[DOC_STATUS],
            i.[DOC_QTY],
            i.[DOC_NETAMT],
            i.[DOC_TAXAMT],
            i.[CREATED],
            ROW_NUMBER() OVER
            (
                PARTITION BY i.[DOC_NUM_R3]
                ORDER BY
                    i.[DOC_DATE], i.[DISTRIBUTOR], i.[CUSTOMER],
                    i.[DOC_ORD_R3], i.[DOC_NUM_REF1], i.[DOC_NUM_REF2],
                    i.[DOC_TYPE], i.[DOC_STATUS], i.[DOC_QTY],
                    i.[DOC_NETAMT], i.[DOC_TAXAMT], i.[CREATED]
            ) AS DuplicateOrdinal
        FROM inserted AS i
    ),
    PairedRows AS
    (
        SELECT
            PreviousRows.[DOC_DATE] AS Old_DOC_DATE,
            CurrentRows.[DOC_DATE] AS New_DOC_DATE,
            PreviousRows.[DISTRIBUTOR] AS Old_DISTRIBUTOR,
            CurrentRows.[DISTRIBUTOR] AS New_DISTRIBUTOR,
            PreviousRows.[CUSTOMER] AS Old_CUSTOMER,
            CurrentRows.[CUSTOMER] AS New_CUSTOMER,
            PreviousRows.[DOC_NUM_R3] AS Old_DOC_NUM_R3,
            CurrentRows.[DOC_NUM_R3] AS New_DOC_NUM_R3,
            PreviousRows.[DOC_ORD_R3] AS Old_DOC_ORD_R3,
            CurrentRows.[DOC_ORD_R3] AS New_DOC_ORD_R3,
            PreviousRows.[DOC_NUM_REF1] AS Old_DOC_NUM_REF1,
            CurrentRows.[DOC_NUM_REF1] AS New_DOC_NUM_REF1,
            PreviousRows.[DOC_NUM_REF2] AS Old_DOC_NUM_REF2,
            CurrentRows.[DOC_NUM_REF2] AS New_DOC_NUM_REF2,
            PreviousRows.[DOC_TYPE] AS Old_DOC_TYPE,
            CurrentRows.[DOC_TYPE] AS New_DOC_TYPE,
            PreviousRows.[DOC_STATUS] AS Old_DOC_STATUS,
            CurrentRows.[DOC_STATUS] AS New_DOC_STATUS,
            PreviousRows.[DOC_QTY] AS Old_DOC_QTY,
            CurrentRows.[DOC_QTY] AS New_DOC_QTY,
            PreviousRows.[DOC_NETAMT] AS Old_DOC_NETAMT,
            CurrentRows.[DOC_NETAMT] AS New_DOC_NETAMT,
            PreviousRows.[DOC_TAXAMT] AS Old_DOC_TAXAMT,
            CurrentRows.[DOC_TAXAMT] AS New_DOC_TAXAMT
        FROM PreviousRows
        INNER JOIN CurrentRows
            ON
            (
                CurrentRows.[DOC_NUM_R3] = PreviousRows.[DOC_NUM_R3]
                OR
                (
                    CurrentRows.[DOC_NUM_R3] IS NULL
                    AND PreviousRows.[DOC_NUM_R3] IS NULL
                )
            )
            AND CurrentRows.DuplicateOrdinal = PreviousRows.DuplicateOrdinal
    ),
    ChangeRows AS
    (
        SELECT
            PairedRows.Old_DOC_NUM_R3,
            CONCAT(
                CASE WHEN PairedRows.New_DOC_DATE <> PairedRows.Old_DOC_DATE
                    THEN CONCAT(' Date: ', PairedRows.Old_DOC_DATE, '->', PairedRows.New_DOC_DATE, '.') ELSE '' END,
                CASE WHEN PairedRows.New_DISTRIBUTOR <> PairedRows.Old_DISTRIBUTOR
                    THEN CONCAT(' Ctro: ', PairedRows.Old_DISTRIBUTOR, '->', PairedRows.New_DISTRIBUTOR, '.') ELSE '' END,
                CASE WHEN PairedRows.New_CUSTOMER <> PairedRows.Old_CUSTOMER
                    THEN CONCAT(' Cust: ', PairedRows.Old_CUSTOMER, '->', PairedRows.New_CUSTOMER, '.') ELSE '' END,
                CASE WHEN PairedRows.New_DOC_NUM_R3 <> PairedRows.Old_DOC_NUM_R3
                    THEN CONCAT(' DocSAP: ', PairedRows.Old_DOC_NUM_R3, '->', PairedRows.New_DOC_NUM_R3, '.') ELSE '' END,
                CASE WHEN PairedRows.New_DOC_ORD_R3 <> PairedRows.Old_DOC_ORD_R3
                    THEN CONCAT(' PedSAP: ', PairedRows.Old_DOC_ORD_R3, '->', PairedRows.New_DOC_ORD_R3, '.') ELSE '' END,
                CASE WHEN PairedRows.New_DOC_NUM_REF1 <> PairedRows.Old_DOC_NUM_REF1
                    THEN CONCAT(' Ref1: ', PairedRows.Old_DOC_NUM_REF1, '->', PairedRows.New_DOC_NUM_REF1, '.') ELSE '' END,
                CASE WHEN PairedRows.New_DOC_NUM_REF2 <> PairedRows.Old_DOC_NUM_REF2
                    THEN CONCAT(' Ref2: ', PairedRows.Old_DOC_NUM_REF2, '->', PairedRows.New_DOC_NUM_REF2, '.') ELSE '' END,
                CASE WHEN PairedRows.New_DOC_TYPE <> PairedRows.Old_DOC_TYPE
                    THEN CONCAT(' Type: ', PairedRows.Old_DOC_TYPE, '->', PairedRows.New_DOC_TYPE, '.') ELSE '' END,
                CASE WHEN PairedRows.New_DOC_STATUS <> PairedRows.Old_DOC_STATUS
                    THEN CONCAT(' St: ', PairedRows.Old_DOC_STATUS, '->', PairedRows.New_DOC_STATUS, '.') ELSE '' END,
                CASE WHEN ISNULL(PairedRows.New_DOC_QTY, 0) <> ISNULL(PairedRows.Old_DOC_QTY, 0)
                    THEN CONCAT(' Qty: ', CONVERT(VARCHAR(50), PairedRows.Old_DOC_QTY), '->', CONVERT(VARCHAR(50), PairedRows.New_DOC_QTY), '.') ELSE '' END,
                CASE WHEN ISNULL(PairedRows.New_DOC_NETAMT, 0) <> ISNULL(PairedRows.Old_DOC_NETAMT, 0)
                    THEN CONCAT(' Subt: ', CONVERT(VARCHAR(50), PairedRows.Old_DOC_NETAMT), '->', CONVERT(VARCHAR(50), PairedRows.New_DOC_NETAMT), '.') ELSE '' END,
                CASE WHEN ISNULL(PairedRows.New_DOC_TAXAMT, 0) <> ISNULL(PairedRows.Old_DOC_TAXAMT, 0)
                    THEN CONCAT(' Tax: ', CONVERT(VARCHAR(50), PairedRows.Old_DOC_TAXAMT), '->', CONVERT(VARCHAR(50), PairedRows.New_DOC_TAXAMT), '.') ELSE '' END
            ) AS ChangeText
        FROM PairedRows
    )
    INSERT INTO [EAI].[LOG_T3R_SALES_DOCS_OLD]
    (
        [FECHA],
        [USUARIO],
        [USUARIO_RED],
        [IP],
        [TERMINAL],
        [DOC_NUM_R3],
        [CAMBIO]
    )
    SELECT
        SYSDATETIME(),
        CONVERT(VARCHAR(30), SUSER_SNAME()),
        CONVERT(VARCHAR(30), ORIGINAL_LOGIN()),
        CONVERT(VARCHAR(30), CONNECTIONPROPERTY('client_net_address')),
        CONVERT(VARCHAR(40), HOST_NAME()),
        ChangeRows.Old_DOC_NUM_R3,
        /* Oracle elimina el primer espacio con SUBSTR(sLogging, 2, 2000). */
        SUBSTRING(ChangeRows.ChangeText, 2, 2000)
    FROM ChangeRows
    WHERE LEN(ChangeRows.ChangeText) > 3;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* Origen: ORA/T3/EAI_OWNER/Triggers/Z_MX_RECV_MESSAGE.SQL
   INSTEAD OF INSERT sustituye la asignacion a :NEW.DOCNUM de BEFORE INSERT.
   XML_CONTENT ya es xml: XML mal formado es rechazado antes del trigger.
   No existe PRAGMA AUTONOMOUS_TRANSACTION en T-SQL: el log participa en
   la transaccion del INSERT y tambien se pierde si esta se revierte.
   Ver README.md para las diferencias operativas. */
CREATE OR ALTER TRIGGER [EAI_OWNER].[Z_MX_RECV_MESSAGE]
ON [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Rows TABLE
    (
        ROW_ID varchar(32), CREATED datetime2(0), XML_CONTENT xml,
        QUEUE_NAME varchar(30), REFERENCE varchar(50), PROCESSED datetime2(0),
        STATUS varchar(10), DOCNUM varchar(20),
        Extracted varchar(max), ErrorMessage varchar(250)
    );

    INSERT INTO @Rows
    SELECT i.ROW_ID, i.CREATED, i.XML_CONTENT, i.QUEUE_NAME, i.REFERENCE,
           i.PROCESSED, i.STATUS, i.DOCNUM, x.Extracted,
           CASE
             WHEN i.XML_CONTENT.value('count(/*/Header/Reference/ReferenceID)', 'int') > 1
               THEN 'ReferenceID contiene mas de un nodo.'
             WHEN i.XML_CONTENT.exist('/*/Header/Reference/ReferenceID/*') = 1
               OR i.XML_CONTENT.value('count(/*/Header/Reference/ReferenceID/text())', 'int') > 1
               THEN 'ReferenceID no contiene un valor escalar unico.'
             WHEN DATALENGTH(x.Extracted) > 20
               THEN 'ReferenceID excede la longitud de DOCNUM (20 bytes).'
           END
    FROM inserted AS i
    CROSS APPLY (VALUES
        (i.XML_CONTENT.value('string((/*/Header/Reference/ReferenceID)[1])', 'varchar(max)'))
    ) AS x(Extracted);

    INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        ([DIRECTION], [ID], [CREATED], [MESSAGE], [REFERENCE], [STATUS],
         [QUEUE_NAME], [SIEBEL_ERROR_MESSAGE], [SOURCE], [SIEBEL_ERROR_CODE],
         [RETRY_COUNT], [SEQUENCE], [PARENT_ROW_ID])
    SELECT 'Receive', ROW_ID, SYSDATETIME(), NULL, DOCNUM, 'Error',
           'Message', ErrorMessage, 'Trigger', 'SQL-XML-DOCNUM', NULL, NULL, NULL
    FROM @Rows
    WHERE ErrorMessage IS NOT NULL;

    -- El INSERT interno ejecuta la escritura real sin llamar otra vez a este trigger.
    INSERT INTO [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        ([ROW_ID], [CREATED], [XML_CONTENT], [QUEUE_NAME], [REFERENCE],
         [PROCESSED], [STATUS], [DOCNUM])
    SELECT ROW_ID, CREATED, XML_CONTENT, QUEUE_NAME, REFERENCE,
           PROCESSED, STATUS,
           CASE WHEN ErrorMessage IS NOT NULL THEN DOCNUM
                WHEN DATALENGTH(Extracted) = 0 THEN NULL ELSE Extracted END
    FROM @Rows;
END;
GO

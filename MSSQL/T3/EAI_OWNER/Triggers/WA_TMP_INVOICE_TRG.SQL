SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* Origen: ORA/T3/EAI_OWNER/Triggers/WA_TMP_INVOICE_TRG.SQL
   AFTER DELETE conserva el historico en la misma transaccion.
   Si falla el historico se revierte tambien el borrado.
   No requiere clave: deleted conserva todas las filas, incluso duplicadas. */
CREATE OR ALTER TRIGGER [EAI_OWNER].[WA_TMP_INVOICE_TRG]
ON [EAI_OWNER].[WO_TMP_INVOICE]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [EAI_OWNER].[WO_TMP_INVOICE_HIST]
        ([INSERT_HIST], [MOBILE_INVOICE_NUMBER__C], [DELIVERY_STATUS__C], [INSERT_TS])
    SELECT SYSDATETIME(), [MOBILE_INVOICE_NUMBER__C], [DELIVERY_STATUS__C], [INSERT_TS]
    FROM deleted;
END;
GO

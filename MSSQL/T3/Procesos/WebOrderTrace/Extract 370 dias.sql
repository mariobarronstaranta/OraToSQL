-- Reporte de 370 dias ya calculado por Header.sql, con encabezado CSV incluido.
SET NOCOUNT ON;
SELECT CsvLine
FROM EAI_OWNER.WOT_OUTPUT
WHERE RunId=CONVERT(uniqueidentifier,'$(RunId)') AND Days=370
ORDER BY Seq;

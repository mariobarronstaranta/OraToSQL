-- Reporte de 35 dias ya calculado por Header.sql, con encabezado CSV incluido.
SET NOCOUNT ON;
SELECT CsvLine
FROM EAI_OWNER.WOT_OUTPUT
WHERE RunId=CONVERT(uniqueidentifier,'$(RunId)') AND Days=35
ORDER BY Seq;

/* Solo lectura. Casos observados en el reporte del PID 26517156.
   Devuelve fragmentos cortos para evitar el recorte de columnas del .rpt.
   No ejecuta el generador ni modifica registros.
*/
USE [T3QA];
SET NOCOUNT ON;

SELECT C.Asignacion_ID, C.Folio_ID, C.Factura, C.Nota_Venta,
       C.Status, C.Importe, C.Saldo_Anterior, C.Importe_Factura,
       C.UUID_Venta, C.Fecha_Proceso, C.Fecha_Envio
FROM T3.CFDI_Cobranza C
WHERE C.Asignacion_ID IN ('262201997560','262201997736','262201997738')
ORDER BY C.Asignacion_ID, C.Fecha_Proceso;

SELECT E.Nota_Venta, DATALENGTH(E.Informacion) AS BytesLayout,
       RIGHT(E.Informacion, 200) AS Ultimos200Caracteres
FROM T3.CFDI_DOCUMENTOS_ENVIAR E
WHERE E.Nota_Venta IN ('262201997560','262201997736','262201997738');

-- Fragmentos de 200 caracteres: conservar orden para reconstruir el texto.
;WITH Numeros AS (
    SELECT 1 AS N
    UNION ALL SELECT N + 1 FROM Numeros WHERE N < 20
)
SELECT E.Nota_Venta, N.N AS Fragmento,
       SUBSTRING(E.Informacion, (N.N - 1) * 200 + 1, 200) AS Texto
FROM T3.CFDI_DOCUMENTOS_ENVIAR E
CROSS JOIN Numeros N
WHERE E.Nota_Venta IN ('262201997560','262201997736','262201997738')
  AND (N.N - 1) * 200 < LEN(E.Informacion)
ORDER BY E.Nota_Venta, N.N;

-- Comprobar la definicion instalada; el repositorio usa @sReturn VARCHAR(4000).
SELECT OBJECT_DEFINITION(OBJECT_ID(N'T3.PROC_V20_GENERAR_PAGO')) AS DefinicionInstalada;

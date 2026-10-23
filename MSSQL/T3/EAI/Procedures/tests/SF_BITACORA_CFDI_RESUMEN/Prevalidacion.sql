/* Solo lectura. Seleccionar la base destino y ajustar el mismo periodo
   que se usara en el procedimiento. Una fila por LP candidata conflictiva.
   Sin resultados = sin ambiguedad de LP para este corte, no certificacion total.
*/
DECLARE @Inicio date = '20260801', @Fin date = '20260831';
;WITH LP AS
(
    SELECT H.Nota_Venta_CFDI, NULLIF(F.Grupo_Precio, '') AS Grupo_Precio
    FROM T3.CFDI_Historia_Docto_PAC AS H
    INNER JOIN T3.Fact_T3 AS F ON F.Factura = H.Nota_Venta
    UNION
    SELECT H.Nota_Venta_CFDI, NULLIF(N.Grupo_Precio, '')
    FROM T3.CFDI_Historia_Docto_PAC AS H
    INNER JOIN T3.Nota_T3 AS N ON N.Factura = H.Nota_Venta
), Candidatas AS
(
    SELECT LP.*, COUNT_BIG(*) OVER (PARTITION BY LP.Nota_Venta_CFDI) AS ValoresDistintos
    FROM LP
    WHERE EXISTS
    (
        SELECT 1 FROM T3.CFDI_Historia_Docto_PAC AS P
        WHERE P.Nota_Venta_CFDI = LP.Nota_Venta_CFDI
          AND P.Fecha_Factura >= @Inicio
          AND P.Fecha_Factura < DATEADD(day, 1, CONVERT(datetime2, @Fin))
    )
      AND EXISTS (SELECT 1 FROM T3.CFDI_Agrupado AS A
                  WHERE A.Nota_Venta_CFDI = LP.Nota_Venta_CFDI)
)
SELECT * FROM Candidatas WHERE ValoresDistintos > 1
ORDER BY Nota_Venta_CFDI, Grupo_Precio;

SELECT OBJECT_SCHEMA_NAME(object_id) AS Esquema, name, modify_date
FROM sys.procedures
WHERE object_id IN (OBJECT_ID(N'EAI.SF_BITACORA_CFDI_RESUMEN'),
                   OBJECT_ID(N'EAI.SF_BITACORA_CFDI_RESUMEN_OPTIMIZADO'));
GO

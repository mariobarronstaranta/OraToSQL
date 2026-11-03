/* Solo lectura. Revision separada: no crea componentes ni ejecuta negocio.
   Reparar estas cuatro asignaciones no certifica los otros pendientes. */
USE [T3QA];
SET NOCOUNT ON;
SELECT Component,Name,Status,Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component IN (109,613,614);
SELECT A.Agrupacion,COUNT_BIG(*) ControlesRepetidos
FROM T3.CFDI_AGRUPACION_CTRL A
WHERE A.Agrupacion IN (514957,514969,514981,514984,529050,529096,529120,529179)
GROUP BY A.Agrupacion HAVING COUNT_BIG(*)>1;
SELECT TOP(100) Agrupacion,Fecha_Pago,Accnt_ID,Cliente_SAP,Importe,Fecha_Registro
FROM T3.CFDI_AGRUPACION_CTRL
WHERE Fecha_Envio IS NULL AND Fecha_Pago>='20220101' AND Accnt_ID<>'Contado'
ORDER BY Agrupacion;
-- Para definir el componente 614, obtener la fila/configuracion original.
-- No clonar 613 ni insertar un registro parcial sin revisar el DDL completo.

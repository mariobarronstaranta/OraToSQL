/* Primera prueba de cobertura para PROC_CFDI_PROCESAR_DOCTOS.
   Ejecutar en T3QA en una ventana adecuada: construye un indice sobre una
   tabla de aproximadamente 41.7 millones de filas. Puede consumir disco/log
   y bloquear operaciones durante la construccion.
   No ejecuta el procedimiento CFDI ni elimina indices existentes.
   Despues ejecutar INDICES_MEDICION.sql con fecha 20261014 y plan real.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

IF DB_NAME() <> N'T3QA'
    THROW 50000, 'Seleccionar T3QA antes de ejecutar la prueba de indice.', 1;

IF OBJECT_ID(N'T3.CFDI_DOCUMENTO_PASO', N'U') IS NULL
    THROW 50001, 'No se encuentra T3.CFDI_DOCUMENTO_PASO o no es visible.', 1;

IF EXISTS
 (SELECT 1 FROM sys.indexes
  WHERE object_id=OBJECT_ID(N'T3.CFDI_DOCUMENTO_PASO')
    AND name=N'IX_CFDI_Paso_BATMD_RFC_Cobertura')
    THROW 50002, 'El indice candidato ya existe. Revisar su definicion y ejecutar la medicion; no recrearlo.', 1;

SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS InicioCreacion;

-- Cubre individuales, agrupacion y asociacion de notas por grupo.
-- VOIDDOC se incluye tambien para facilitar el uso del filtro IS NULL.
-- No se impone ONLINE, MAXDOP, compresion ni SORT_IN_TEMPDB sin medir recursos.
CREATE NONCLUSTERED INDEX IX_CFDI_Paso_BATMD_RFC_Cobertura
ON T3.CFDI_DOCUMENTO_PASO (FECHA_PROC_BATMD, RFC_CLIENTE)
INCLUDE (FACTURA, CTRO, FECHA_FACTURA_T3, FECHA_FACTURA_V3,
         TIPO_DOCTO, UBICACION, LISTA_PRECIO, CLIENTE_AGRUPADO, VOIDDOC)
WHERE VOIDDOC IS NULL;

SELECT SYSDATETIMEOFFSET() AS FinCreacion,
       I.name AS Indice,I.is_disabled,I.has_filter,I.filter_definition
FROM sys.indexes I
WHERE I.object_id=OBJECT_ID(N'T3.CFDI_DOCUMENTO_PASO')
  AND I.name=N'IX_CFDI_Paso_BATMD_RFC_Cobertura';

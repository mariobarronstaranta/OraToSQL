/*
  Exportar T3.DELIVERY_HIST para BCP, sin modificar datos en Oracle.
  Ejecutar como SCRIPT (F5 en SQL Developer o @archivo en SQLcl).
  Usar codificacion UTF-8 para el spool y finales de linea Windows CRLF.

  DIFERENCIAS RESPECTO DE LA EXPORTACION ANTERIOR
  - 19 columnas en el orden del DDL MSSQL, sin SELECT *.
  - Separador de campos ~|~: un | aislado dentro del nombre se conserva.
  - Una sola columna de texto ya serializada; no agrega comillas de CSV.
  - Fechas y decimales con formato explicito, independientes del NLS_DATE_FORMAT.
  - Cabecera unica para mantener -F 2 en BCP.
  - Salida nueva Delivery_Hist_BCP.txt; no sobrescribe Delivery_Hist.txt.

  El delimitador ~|~ tampoco puede aparecer dentro de un campo. Revisar la
  consulta de control de este mismo folder antes de exportar. CR/LF internos
  tambien impedirian usar CRLF como terminador de fila en BCP.
  QUANTITY se exporta con punto decimal y hasta tres decimales, como decimal(14,3)
  del destino. La consulta de control detecta cantidades que necesiten revision.

  SQL Developer: configurar la codificacion del script/spool como UTF-8.
  SQLcl: configurar SET ENCODING UTF-8 antes de ejecutar si no usa UTF-8.
  Este archivo no hace COMMIT, ROLLBACK ni ejecuta procedimientos de negocio.
*/
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET WRAP OFF
SET SQLBLANKLINES ON
SET SQLFORMAT DEFAULT
COLUMN LINEA_BCP FORMAT A4000

SPOOL "C:\Users\85233588\Documents\MigracionORA\OraToSQL\ORA\T3\T3\Datos\Delivery_Hist_BCP.txt"
PROMPT CREATED~|~DELIVERY~|~PICKDATE~|~DELIVERYDATE~|~PURCHASEORDER~|~DELIVERYTYPE~|~STATUS~|~PLANT~|~SHIPPINGPOINT~|~SOLDTOPARTY~|~SLOC~|~SHIPTOPARTY~|~SHIPTOPARTYNAME~|~MATERIAL~|~MATERIALNAME~|~QUANTITY~|~UNITMEASURE~|~SHIPTOPARTYLOC~|~SOCIEDAD

SELECT
    TO_CHAR(CREATED,'YYYY-MM-DD HH24:MI:SS') || '~|~' ||
    DELIVERY || '~|~' ||
    TO_CHAR(PICKDATE,'YYYY-MM-DD HH24:MI:SS') || '~|~' ||
    TO_CHAR(DELIVERYDATE,'YYYY-MM-DD HH24:MI:SS') || '~|~' ||
    PURCHASEORDER || '~|~' ||
    DELIVERYTYPE || '~|~' ||
    STATUS || '~|~' ||
    PLANT || '~|~' ||
    SHIPPINGPOINT || '~|~' ||
    SOLDTOPARTY || '~|~' ||
    SLOC || '~|~' ||
    SHIPTOPARTY || '~|~' ||
    SHIPTOPARTYNAME || '~|~' ||
    MATERIAL || '~|~' ||
    MATERIALNAME || '~|~' ||
    TO_CHAR(QUANTITY,'FM99999999990D000','NLS_NUMERIC_CHARACTERS=''.,''') || '~|~' ||
    UNITMEASURE || '~|~' ||
    SHIPTOPARTYLOC || '~|~' ||
    SOCIEDAD AS LINEA_BCP
FROM T3.DELIVERY_HIST
WHERE CREATED>DATE '2026-07-31'
ORDER BY CREATED DESC;

SPOOL OFF
COLUMN LINEA_BCP CLEAR
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 50

/*
  Exportar la consulta de cobranza a texto separado por pipes (|).
  Ejecutar TODO como script: F5 en SQL Developer o @archivo en SQLcl.
  El archivo se guarda en el equipo donde se ejecuta el cliente Oracle.

  Formato de carga: 42 columnas en el orden del DDL MSSQL y una cabecera.
  Los NULL se representan como campos vacios; los numeros usan punto decimal.
  Las siete fechas se expresan como YYYY-MM-DD HH24:MI:SS (precision segundos).
  La consulta original esta en DatosCobranza: conserva tambien la multiplicidad
  de los JOIN. El SELECT exterior serializa los campos para BCP sin comillas.

  Textos conservados tal cual: el contrato del archivo requiere que los valores
  no contengan | ni saltos CR/LF internos. Usar salida UTF-8 y CRLF en Windows.
  SQL Developer: configurar la codificacion del spool como UTF-8.
  SQLcl: se puede ejecutar SET ENCODING UTF-8 antes de llamar a este script.
  La cabecera permite mantener -F 2 al cargar por BCP.
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

-- Estas instrucciones se ejecutan antes del spool para no ensuciar el TXT.
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

SET TERMOUT OFF
SPOOL "C:\Users\85233588\Documents\MigracionORA\OraToSQL\ORA\T3\T3\Datos\CFDI_Cobranza_BCP.txt" REPLACE
PROMPT FOLIO_ID|ASIGNACION_ID|FECHA_ASIGNACION|IMPORTE|SALDO_ANTERIOR|NUMERO_PAGO|ACCNT_ID|FACTURA|NOTA_VENTA|RFC|FECHA_PROC_BATMD|FECHA_PROCESO|STATUS|VIA_PAGO|CANT_PAGOS|ABONO_PAGOS|CANT_CM|ABONO_CM|NOTA_CREDITO|UUID_VENTA|FECHA_FACTURA|DIAS_CDTO|IMPORTE_FACTURA|PID|CREATED_BY|PAGO_ID|FECHA_PAGO|SOCIEDAD|CTRO|DB_LAST_UPD|BANCO_NOMBRE|BANCO_NUM_CUENTA|NUMERO_CHEQUE|MASTER_BANCO|MASTER_CUENTA|RECEPTOR_BANCO|RECEPTOR_CUENTA|FECHA_ENVIO|TASA_IVA|REFERENCIA|ASIGNACION_CENTRAL|CLIENTE_SAP

WITH DatosCobranza AS (
       SELECT Cobza.*
          FROM T3.CFDI_Cobranza              Cobza,
               EAI_Owner.tmp_Account_Header  Acc  ,
               T3.Registro_Fiscal            RF
          WHERE Cobza.Fecha_Proceso                   > TRUNC( SYSDATE - NVL( 60, 0 ) )
            AND SUBSTR( Cobza.Asignacion_ID, 3, 10 )  = Acc.ClearingDocNumber
            AND Acc.FiscalYear                        = TO_CHAR( SYSDATE, 'YYYY' )
            AND Cobza.Factura                         = RF.Factura
            AND NVL( Acc.Assignment, RF.Entrega )    != RF.Entrega
            AND NVL( Acc.Assignment, RF.Entrega )    != 'B001 - Bank I'
            AND NVL( Acc.Assignment, RF.Entrega )    != Cobza.Factura || ','
            AND NVL( Acc.Assignment, RF.Entrega )     NOT LIKE '1-1%'
            AND NVL( Acc.Assignment, RF.Entrega )    != RF.Referencia
            AND Cobza.Asignacion_Central             IS NULL
)
SELECT
    Cobza.FOLIO_ID || '|' ||
    Cobza.ASIGNACION_ID || '|' ||
    TO_CHAR(Cobza.FECHA_ASIGNACION, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
    TO_CHAR(Cobza.IMPORTE, 'TM9') || '|' ||
    TO_CHAR(Cobza.SALDO_ANTERIOR, 'TM9') || '|' ||
    TO_CHAR(Cobza.NUMERO_PAGO, 'TM9') || '|' ||
    Cobza.ACCNT_ID || '|' ||
    Cobza.FACTURA || '|' ||
    Cobza.NOTA_VENTA || '|' ||
    Cobza.RFC || '|' ||
    TO_CHAR(Cobza.FECHA_PROC_BATMD, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
    TO_CHAR(Cobza.FECHA_PROCESO, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
    Cobza.STATUS || '|' ||
    Cobza.VIA_PAGO || '|' ||
    TO_CHAR(Cobza.CANT_PAGOS, 'TM9') || '|' ||
    TO_CHAR(Cobza.ABONO_PAGOS, 'TM9') || '|' ||
    TO_CHAR(Cobza.CANT_CM, 'TM9') || '|' ||
    TO_CHAR(Cobza.ABONO_CM, 'TM9') || '|' ||
    Cobza.NOTA_CREDITO || '|' ||
    Cobza.UUID_VENTA || '|' ||
    TO_CHAR(Cobza.FECHA_FACTURA, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
    TO_CHAR(Cobza.DIAS_CDTO, 'TM9') || '|' ||
    TO_CHAR(Cobza.IMPORTE_FACTURA, 'TM9') || '|' ||
    TO_CHAR(Cobza.PID, 'TM9') || '|' ||
    Cobza.CREATED_BY || '|' ||
    Cobza.PAGO_ID || '|' ||
    TO_CHAR(Cobza.FECHA_PAGO, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
    Cobza.SOCIEDAD || '|' ||
    Cobza.CTRO || '|' ||
    TO_CHAR(Cobza.DB_LAST_UPD, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
    Cobza.BANCO_NOMBRE || '|' ||
    Cobza.BANCO_NUM_CUENTA || '|' ||
    Cobza.NUMERO_CHEQUE || '|' ||
    Cobza.MASTER_BANCO || '|' ||
    Cobza.MASTER_CUENTA || '|' ||
    Cobza.RECEPTOR_BANCO || '|' ||
    Cobza.RECEPTOR_CUENTA || '|' ||
    TO_CHAR(Cobza.FECHA_ENVIO, 'YYYY-MM-DD HH24:MI:SS') || '|' ||
    TO_CHAR(Cobza.TASA_IVA, 'TM9') || '|' ||
    Cobza.REFERENCIA || '|' ||
    Cobza.ASIGNACION_CENTRAL || '|' ||
    Cobza.CLIENTE_SAP AS LINEA_BCP
FROM DatosCobranza Cobza;

SPOOL OFF
SET TERMOUT ON
COLUMN LINEA_BCP CLEAR
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 50
PROMPT Archivo de salida: C:\Users\85233588\Documents\MigracionORA\OraToSQL\ORA\T3\T3\Datos\CFDI_Cobranza_BCP.txt

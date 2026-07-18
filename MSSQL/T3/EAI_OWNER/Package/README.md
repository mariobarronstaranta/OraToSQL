# RECV_TO_SEND_V3

Conversión del package Oracle `EAI_OWNER.RECV_TO_SEND_V3` a procedimientos
independientes de SQL Server. SQL Server no tiene un objeto equivalente a un
package. Por decisión del cliente, cada procedimiento conserva exactamente el
nombre público que tenía como miembro del package Oracle; la carpeta `Package`
mantiene la agrupación visual de los scripts.

## Equivalente del package body

El `PACKAGE BODY` Oracle recibido no contiene un bloque global que ejecute
todos sus procedimientos. Su `END;` final solamente cierra el contenedor del
package. Por lo tanto, los 12 procedimientos T-SQL de esta carpeta constituyen
el equivalente del body: cada uno contiene la implementación de un miembro.

Las llamadas externas deben transformarse de esta forma:

```sql
-- Oracle
EAI_OWNER.RECV_TO_SEND_V3.RECV_CUSTOMER;

-- SQL Server
EXEC [EAI_OWNER].[RECV_CUSTOMER];
```

No se creó un procedimiento `RUN_ALL`, porque el package Oracle no ejecuta los
nueve `RECV_*` en secuencia. Agregarlo cambiaría la operación, las ventanas de
selección, el control de componentes y el manejo de errores. Si se requiere un
único punto de entrada, puede agregarse un despachador que reciba el nombre de
la operación y llame solamente al procedimiento solicitado; esta decisión debe
basarse en la definición de los jobs Oracle originales.

## Orden de despliegue

1. `PROC_CUSTOMER.SQL`
2. `PROC_CREDIT.SQL`
3. `PROC_ORDER.SQL`
4. Los nueve scripts `RECV_*.SQL`
5. `GRANTS.SQL`

## Dependencias

- Tablas: `EAI_OWNER.MX_RECEIVE_MESSAGE_LOG`,
  `EAI_OWNER.MX_SEND_MESSAGE_LOG`, `EAI_OWNER.MX_EAI_MESSAGE_LOG`,
  `EAI_OWNER.MX_COMPONENTS`, `T3.RF_PROCESOS_LOG` y `T3.MOV_CLIENTE`.
- Secuencia: `EAI_OWNER.ProcessID`.
- Funciones: `EAI_OWNER.GETCONV` y `EAI_OWNER.FN_CHECK_INSTANCE`.
- Procedimientos: `EAI_OWNER.LOG_START`, `EAI_OWNER.LOG_END`, los cinco
  procedimientos `SF_PROC_*` invocados por los coordinadores y
  `T3.PROC_T3_OT_GENERAL`.

Los DDL de `EAI_OWNER.ProcessID`, `T3.RF_PROCESOS_LOG` y `T3.MOV_CLIENTE` ya
están incorporados en el repositorio. Se validó su compatibilidad con este
package: `PID DECIMAL(10,0)` coincide con `@nPID NUMERIC(10,0)`, los componentes
401 a 409 caben en `PROCESO DECIMAL(4,0)`, y las columnas `CLIENTE_V3` y `CTRO`
son compatibles con los procedimientos de cliente y crédito.

`T3.PROC_T3_OT_GENERAL` también está definido y no recibe parámetros, por lo
que coincide con la llamada realizada al final de
`RECV_INVOICE_INTERCOMPANY`. La validación con `OBJECT_ID` se
conserva para detectar un orden de despliegue incorrecto.

Las dependencias T3 de `PROC_T3_OT_GENERAL` ya tienen scripts en
`MSSQL/T3/T3/Procedures` y `MSSQL/T3/T3/Tables`, incluidos
`WA_ERR_INVOICE_PAYMETHOD`, `PROC_V40_GENERAR_OTROS`, `OTROS_GENERAL`,
`OTROS_DETALLE` y `MATERIAL`. Su presencia no sustituye una prueba de
compilación ni de datos. Algunos scripts contienen `USE [T3QA]`; antes de
automatizar el despliegue debe seleccionarse la base desde el pipeline o
confirmarse ese contexto para el ambiente.

`EAI_OWNER.LOG_END` fue homologado para usar `EAI_OWNER.ProcessID`, conforme al
procedimiento Oracle original y al DDL de la secuencia ya incorporado.

## Decisiones y puntos de revisión

- `MX_RECEIVE_MESSAGE_LOG.ROW_ID` permanece como `VARCHAR(32)`. No se confunde
  con `MX_EAI_MESSAGE_LOG.ROW_ID BIGINT`, generado por su secuencia/default.
- Los candidatos se materializan y procesan en orden para conservar las
  llamadas fila por fila del cursor Oracle.
- SQL Server trabaja en autocommit; los `COMMIT` cada 50 filas de Oracle no se
  trasladan porque no existe una transacción exterior equivalente.
- `RECV_PRODUCT` y `RECV_PRICE` no llaman un procesador cuando la instancia es
  válida, tal como ocurre en el body Oracle recibido.
- `RECV_ORDER` no genera `ProcessID` ni crea una fila en `RF_PROCESOS_LOG` en
  el fuente Oracle. La anomalía se conservó y debe resolverse como un cambio
  funcional separado.
- Antes de producción deben compararse los XML generados por `PROC_CUSTOMER`,
  `PROC_CREDIT` y `PROC_ORDER` contra muestras reales generadas en Oracle.

## Guía de mantenimiento

Los 12 procedimientos incluyen un encabezado homologado orientado a personal
que no conoce el package Oracle. Cada encabezado describe:

- procedimiento Oracle de origen y propósito funcional;
- parámetros o criterios de selección del lote;
- flujo principal, procedimiento delegado y estados generados;
- dependencias y comportamientos heredados que no deben corregirse sin una
  decisión funcional;
- diferencia entre el `ROW_ID` VARCHAR de `MX_RECEIVE_MESSAGE_LOG` y el
  `ROW_ID` BIGINT autogenerado de `MX_EAI_MESSAGE_LOG`.

Los comentarios dentro del código se concentran en límites funcionales:
materialización del lote, extracción/construcción XML, validación de instancia,
delegación, cierre del componente y registro de errores. Si cambia una regla de
negocio, se debe actualizar el comentario correspondiente junto con el código.

## Jobs

Los 37 jobs `EAI_OWNER` ya tienen scripts de conversión bajo
`MSSQL/T3/EAI_OWNER/Jobs`. Los steps invocan los procedimientos públicos sin
prefijo, por ejemplo:

```sql
EXEC [EAI_OWNER].[RECV_CUSTOMER];
```

Los job names generados actualmente tampoco contienen `RECV_TO_SEND_V3`, pero
`GET_T3_ENABLE_EXECUTE` todavía busca ese texto en el nombre o comando. Antes de
habilitar los jobs se debe conservar esa marca solamente en el job name o
cambiar la función para consultar `Job_Oracle_SQLAgent_Map`. No debe
reintroducirse el prefijo en los stored procedures. Consultar
`Docs/JOBS_MIGRATION.md`.

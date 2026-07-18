# Migracion de jobs EAI_OWNER

## Alcance

El archivo `ExportJobs` entregado el 17 de julio de 2026 contiene 37 registros
de `USER_JOBS`. Todos tienen `PRIV_USER=EAI_OWNER` y
`SCHEMA_USER=EAI_OWNER`; por ello pertenecen al alcance de `EAI_OWNER`, aunque
el bloque `WHAT` invoque objetos de `EAI_OWNER`, `EAI` o `T3`.

| Destino del comando | Jobs |
|---|---:|
| `EAI_OWNER` | 15 |
| `EAI` | 5 |
| `T3` | 17 |
| Total | 37 |

En Oracle, 32 estaban activos (`BROKEN=N`) y cinco estaban deshabilitados:
216, 229, 236, 550 y 648.

## Equivalente SQL Server

`DBMS_JOB` se sustituye con SQL Server Agent:

| Oracle | SQL Server |
|---|---|
| `JOB` | SQL Agent Job y `Oracle_Job_No` en la tabla de mapeo |
| `WHAT` | Step T-SQL |
| `INTERVAL` | Schedule exclusivo |
| `BROKEN=Y` | Job deshabilitado |
| `NEXT_DATE` | Fecha inicial del schedule |
| `USER_JOBS` | `msdb` y catalogos locales de migracion |

Los scripts se encuentran en `MSSQL/T3/EAI_OWNER/Jobs`:

1. `01_CREATE_OR_UPDATE_JOBS.SQL`: crea o actualiza los 37 jobs, siempre
   deshabilitados.
2. `02_VALIDATE_JOBS.SQL`: valida job, step, schedule, procedimiento directo y
   dependencias T3 de segundo nivel.
3. `03_ENABLE_VALIDATED_JOBS.SQL`: requiere confirmacion manual y bloquea la
   habilitacion cuando faltan dependencias conocidas.
4. `04_DISABLE_MIGRATED_JOBS.SQL`: rollback operativo sin borrar historial.
5. `USER_JOBS_SOURCE.csv`: copia exacta del inventario recibido.

Cada job tiene su propio schedule porque `JOB_INTERVAL`, `JOB_NEXT_DATE` y
`JOB_NEXT_RUN` pueden cambiar su programacion por el numero historico Oracle.

## Estado de dependencias

Los 37 procedimientos llamados directamente por los jobs tienen script MSSQL.
En particular, los 17 procedimientos `T3` estan en
`MSSQL/T3/T3/Procedures` y sus firmas aceptan los parametros de `WHAT`.

Persisten diez dependencias internas por nombre exacto:

- Procedimientos: `T3.DELIVERY_CLEAR`, `T3.PROC_V40_GENERAR_MX06_CM`,
  `T3.PROC_CFDI_GENERAR_PAGO`, `T3.PROC_CFDI_GENERAR_PAGO_AGR` y
  `T3.PROC_T3_LANZA_REP`.
- Funciones: `T3.FN_ADDENDA_PARAM` y `T3.FN_VALIDA_RFC`.
- Secuencias: `T3.SEQ_CFD` y `T3.SEQ_PAGO_CENTRAL_AGR`.
- Tabla o vista: `T3.FACTURA_GENERAL`.

Existe `[T3].[DELIVERY_CLEAR_Migrado]`, pero no satisface la llamada a
`[T3].[DELIVERY_CLEAR]`. Tambien deben corregirse en `PROC_T3_EOD` y
`PROC_T3_BOD` las llamadas `T3.PKG_T3.PROC_T3_LANZA_REP`; SQL Server interpreta
esa expresion como `base.schema.procedimiento`, no como package Oracle.

## Pendiente de compatibilidad RECV_TO_SEND_V3

Los cinco jobs del package llaman los procedimientos publicos aprobados sin
prefijo: `RECV_REPLENISHMENT`, `RECV_INVOICE_INTERCOMPANY`, `RECV_PAYMENT`,
`RECV_INVOICE` y `RECV_CUSTOMER`.

La funcion `[EAI_OWNER].[GET_T3_ENABLE_EXECUTE]` todavia busca el texto
`RECV_TO_SEND_V3` en `msdb.dbo.sysjobs.name` o en el comando del step. Los jobs
generados se llaman `ORA_<numero>_<schema>_<procedimiento>` y sus steps tampoco
contienen ese texto. Antes de habilitarlos debe acordarse una de estas opciones:

1. Conservar `RECV_TO_SEND_V3` solamente en el nombre del SQL Agent Job.
2. Cambiar `GET_T3_ENABLE_EXECUTE` para usar `Job_Oracle_SQLAgent_Map` y el
   catalogo de migracion.

La decision no debe reintroducir el prefijo en los nombres de los stored
procedures, porque el cliente lo rechazo expresamente.

`WA_CIERRE_FLUJOS` llama `JOB_MANAGE('Suspend','Todos')`. La conversion actual
de `JOB_MANAGE` selecciona `Todos` mediante patrones históricos como
`GEN_REPLICATION`, `GEN_OUTBOUND_XML` y `SEND_STAGE_T3`; los steps `ORA_*`
generados ejecutan `EXEC [schema].[procedure]` y pueden quedar fuera. Debe
probarse y, si corresponde, cambiarse la selección para usar
`Job_Oracle_SQLAgent_Map` antes de considerar operativo el cierre de flujos.

## Diferencias de calendario

- `SYSDATE + N/1440` se convierte a cada N minutos.
- `SYSDATE + N/24` se convierte a cada N horas.
- `TRUNC(SYSDATE+1)+fraccion` se convierte a una hora diaria fija.
- Oracle puede recalcular el intervalo y acumular deriva; SQL Server Agent usa
  una cuadricula fija.

## Criterio de liberacion

No habilitar jobs hasta que:

- `02_VALIDATE_JOBS.SQL` regrese `OK` en objetos directos e internos;
- se resuelva la compatibilidad de `GET_T3_ENABLE_EXECUTE`;
- se confirme que `JOB_MANAGE('Suspend','Todos')` suspende los jobs migrados;
- se valide el propietario del job, permisos, SQL Server Agent, Database Mail y
  operadores;
- cada Step T-SQL se ejecute manualmente con datos controlados;
- los cinco jobs originalmente `BROKEN` permanezcan deshabilitados.

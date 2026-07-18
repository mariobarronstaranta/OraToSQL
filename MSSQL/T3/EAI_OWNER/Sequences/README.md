# Secuencias EAI_OWNER

Homólogos SQL Server de los cuatro DDL ubicados en
`ORA/T3/EAI_OWNER/Sequences/`.

| Secuencia | Tipo | Inicio | Incremento | Máximo | Caché | Ciclo |
|---|---:|---:|---:|---:|---:|---|
| `ProcessID` | `BIGINT` | 26512123 | 1 | 9999999999 | 20 | Sí |
| `SEQ_PAYMENT_SIBDB` | `BIGINT` | 16922 | 1 | 9999999999 | No | No |
| `Seq_Purge_LEGDB` | `BIGINT` | 447333 | 1 | 9999999999 | 20 | Sí |
| `SEQ_ALLOCATION_SIBDB` | `BIGINT` | 7000020266 | 1 | 9999999999 | No | No |

Los scripts no reinician una secuencia existente. Para migraciones con datos,
el valor inicial debe compararse contra los identificadores máximos del destino
antes de la primera creación.

## Diferencias respecto a Oracle

- `NOORDER`, `ORDER`, `NOKEEP`, `NOSCALE` y `GLOBAL` no tienen traducción
  directa equivalente en SQL Server.
- `NEXTVAL` se transforma en `NEXT VALUE FOR`.
- El permiso funcional para consumir valores es `UPDATE` sobre la secuencia,
  en lugar del `GRANT SELECT` utilizado en Oracle.
- Rollbacks, errores y caché pueden dejar huecos; no debe asumirse continuidad.

## Referencias pendientes

- `EAI_OWNER.LOG_END` ya fue corregido para usar `[EAI_OWNER].[ProcessID]`.
- `EAI_OWNER.PURGE_ACCOUNT_HEADER` todavía usa `dbo.Seq_Purge_LEGDB` y debe
  homologarse con `[EAI_OWNER].[Seq_Purge_LEGDB]`.
- `SF_INCONSISTENCIAS_REVISAR` todavía usa `dbo.ProcessID`; es una variante
  pendiente de consolidar, no el procedimiento principal.

Las secuencias `T3.SEQ_CFD` y `T3.SEQ_PAGO_CENTRAL_AGR`, requeridas por
`T3.PROC_CFDI_PROCESA_PAGO_AGR`, pertenecen a otro schema y aún no tienen DDL
en el repositorio.

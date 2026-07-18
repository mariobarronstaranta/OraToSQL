# Migracion de secuencias EAI_OWNER

## Inventario

Los cuatro DDL Oracle de `ORA/T3/EAI_OWNER/Sequences` tienen homologo en
`MSSQL/T3/EAI_OWNER/Sequences`:

| Secuencia SQL Server | Inicio | Incremento | Ciclo |
|---|---:|---:|---|
| `[EAI_OWNER].[ProcessID]` | 26512123 | 1 | Si |
| `[EAI_OWNER].[SEQ_PAYMENT_SIBDB]` | 16922 | 1 | No |
| `[EAI_OWNER].[Seq_Purge_LEGDB]` | 447333 | 1 | Si |
| `[EAI_OWNER].[SEQ_ALLOCATION_SIBDB]` | 7000020266 | 1 | No |

Los scripts son idempotentes respecto a la existencia: no reinician una
secuencia ya creada.

## Equivalencia

```sql
-- Oracle
EAI_OWNER.ProcessID.NEXTVAL

-- SQL Server
NEXT VALUE FOR [EAI_OWNER].[ProcessID]
```

`ORDER`, `NOORDER`, `KEEP`, `NOKEEP`, `SCALE` y atributos globales de Oracle no
tienen equivalencia directa. Una secuencia garantiza valores unicos dentro de
su configuracion, pero no continuidad sin huecos.

## Despliegue

1. Comparar `START WITH` contra el maximo usado en la base destino.
2. Crear las secuencias antes de procedimientos y jobs consumidores.
3. Otorgar el permiso SQL Server necesario para consumir valores.
4. Validar schema explicito en cada `NEXT VALUE FOR`.

## Pendientes conocidos

- `PURGE_ACCOUNT_HEADER.SQL` usa todavía `dbo.Seq_Purge_LEGDB`; debe revisarse
  contra `[EAI_OWNER].[Seq_Purge_LEGDB]`.
- `SF_INCONSISTENCIAS_REVISAR.SQL` usa `dbo.ProcessID`; es una variante pendiente
  de consolidar, no el procedimiento principal.
- Los procedimientos T3 de jobs requieren además `T3.SEQ_CFD` y
  `T3.SEQ_PAGO_CENTRAL_AGR`; esas secuencias no forman parte del inventario
  `EAI_OWNER` y todavía no tienen DDL en el repositorio.


# Migracion de packages Oracle

## Regla general

SQL Server no tiene un objeto equivalente a `PACKAGE`. Cada miembro Oracle se
convierte en un procedimiento o funcion independiente dentro del schema
correspondiente. Las carpetas `Package` y `Packages` son una agrupacion visual,
no un contenedor ejecutable.

Una llamada cambia de:

```sql
EAI_OWNER.RECV_TO_SEND_V3.RECV_CUSTOMER;
```

a:

```sql
EXEC [EAI_OWNER].[RECV_CUSTOMER];
```

## EAI_OWNER.RECV_TO_SEND_V3

Origen:

- `ORA/T3/EAI_OWNER/Packages/RECV_TO_SEND_V3.SQL`
- `ORA/T3/EAI_OWNER/Packages/RECV_TO_SEND_V3_BODY.SQL`

Destino: `MSSQL/T3/EAI_OWNER/Package`.

El body contiene 12 miembros, migrados con su nombre original:

- Constructores auxiliares: `PROC_CUSTOMER`, `PROC_CREDIT`, `PROC_ORDER`.
- Coordinadores: `RECV_CUSTOMER`, `RECV_CREDIT`, `RECV_PRODUCT`, `RECV_PRICE`,
  `RECV_INVOICE`, `RECV_ORDER`, `RECV_REPLENISHMENT`, `RECV_PAYMENT` y
  `RECV_INVOICE_INTERCOMPANY`.

Por decision del cliente, ningun stored procedure usa el prefijo
`RECV_TO_SEND_V3_`. El body Oracle no contiene un bloque global que ejecute los
12 miembros; por ello no se creo un `RUN_ALL`.

`GRANTS.SQL` no es un equivalente del package. Su funcion es conceder permisos
de ejecucion sobre los objetos independientes.

Pendiente: alinear los nombres de los SQL Agent Jobs o
`GET_T3_ENABLE_EXECUTE`, que todavia busca el texto `RECV_TO_SEND_V3`.

La revision realizada para estos 12 procedimientos fue estatica; falta compilar
el conjunto completo contra una base con todas sus dependencias y comparar XML
de muestra contra Oracle.

## EAI.PKG_ENCUESTAS_MKT

Origen:

- `ORA/T3/EAI/Packages/PKG_ENCUESTAS_MKT.SQL` — specification vacia.
- `ORA/T3/EAI/Packages/PKG_ENCUESTAS_MKT_BODY.SQL` — implementacion.

Destino: `MSSQL/T3/EAI/Packages`.

Miembros migrados:

| Miembro | Tipo SQL Server |
|---|---|
| `PRC_EJECUTA_PROCESO_ENCUESTAS` | Procedimiento coordinador |
| `PRC_VALIDA_ENCUESTAS` | Procedimiento |
| `PRC_REPORTE_ENCUESTAS` | Procedimiento |
| `FNC_REVISA_CAMPO_VALIDO` | Funcion escalar |

El coordinador sustituye la llamada principal del body: primero valida y luego
genera/publica el reporte.

La publicacion Oracle `@V3CEDIS` requiere un linked server y el sinonimo
`[CEDIS].[ENCUESTAS_CLIENTES_RESUMEN]`. El repositorio incluye solamente
`CONFIGURACION_CEDIS_TEMPLATE.SQL`; servidor y base reales deben ser definidos
por el DBA.

Riesgos pendientes:

- `ENCUESTAS_CLIENTES_CARGADAS` no tiene una llave equivalente al `ROWID`; el
  procedimiento usa `IDENCUESTADO` y requiere unicidad por carga.
- Confirmar con negocio las correcciones de rango de semana/consecutivo,
  `FECHA_FIN` y `VENTA_SEM_OTRASMARCAS` documentadas en el README del package.
- Probar la publicacion distribuida y el comportamiento transaccional con el
  linked server real.

Los cuatro objetos T-SQL se compilaron en una LocalDB temporal contra las siete
tablas EAI involucradas. Esa prueba no cubre la publicación remota CEDIS ni
datos funcionales.

## Reglas para packages futuros

- Conservar el schema y los nombres publicos aprobados.
- Migrar miembros privados que sean llamados internamente.
- Sustituir llamadas `schema.package.member` por `schema.member`.
- No trasladar el `END package;` como un procedimiento coordinador ficticio.
- Crear un coordinador solo si existe un flujo explicito en el body o en un job.
- Separar permisos (`GRANT`) de la implementacion.

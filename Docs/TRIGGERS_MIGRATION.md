# Migracion de triggers EAI

Este documento registra la migracion de los triggers Oracle del schema `EAI` a SQL Server.

## Inventario convertido

| Trigger Oracle | Fuente Oracle | Destino SQL Server |
| --- | --- | --- |
| `UPDATE_T3R_STATUS` | `ORA/T3/EAI/Triggers/UPDATE_T3R_STATUS.SQL` | `MSSQL/T3/EAI/Triggers/UPDATE_T3R_STATUS.SQL` |
| `T3R_SALES_DOCS_OLD_LOG` | `ORA/T3/EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL` | `MSSQL/T3/EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL` |

## Criterios de conversion aplicados

1. Se usan `CREATE OR ALTER TRIGGER` y nombres calificados por schema `[EAI]`.
2. Se conserva la semantica de negocio del trigger Oracle:
   - `UPDATE_T3R_STATUS`: registra en `[EAI].[T3R_STATUS_LOG]` cuando el nuevo `END_DATE` queda `NULL`.
   - `T3R_SALES_DOCS_OLD_LOG`: registra en `[EAI].[LOG_T3R_SALES_DOCS_OLD]` solo cuando hubo cambios relevantes.
3. Las tablas `inserted` y `deleted` se emparejan con las claves logicas que ya usan los procesos del repositorio:
   - `[PROCEDURE]` para `[EAI].[T3R_STATUS]`.
   - `[DOC_NUM_R3]` para `[EAI].[T3R_SALES_DOCS_OLD]`.
4. Se homologan funciones Oracle:
   - `SYSDATE` -> `SYSDATETIME()`
   - `NVL(x, 0)` -> `ISNULL(x, 0)`
   - `SYS_CONTEXT(...)` -> funciones de sesion SQL Server (`SUSER_SNAME`, `ORIGINAL_LOGIN`, `HOST_NAME`, `CONNECTIONPROPERTY`).

## Nota tecnica importante

Las tablas `[EAI].[T3R_STATUS]` y `[EAI].[T3R_SALES_DOCS_OLD]` no exponen llave primaria ni restriccion `UNIQUE` en el DDL consolidado actual. Los triggers usan la clave logica correspondiente y un `ROW_NUMBER()` particionado por esa clave para evitar productos cartesianos si existen duplicados.

Esta estrategia cubre las actualizaciones encontradas en el repositorio: los procesos localizan estados por `[PROCEDURE]` y documentos por `[DOC_NUM_R3]`, sin modificar esas columnas. No permite reconstruir de forma confiable la pareja anterior/nueva si una sentencia cambia la propia clave logica. Para eliminar esa limitacion se recomienda agregar una llave tecnica inmutable a cada tabla y emparejar `inserted`/`deleted` mediante ella.

El `ALTER SESSION SET TIME_ZONE=dbtimezone` del trigger Oracle no tiene equivalente dentro de un trigger T-SQL. `SYSDATETIME()` usa la hora local del servidor; la zona horaria de la instancia o de la conexion debe ser administrada como configuracion de plataforma.

## Equivalencias de contexto de sesion

| Oracle | SQL Server | Uso |
| --- | --- | --- |
| `USER` | `SUSER_SNAME()` | Login que ejecuta la actualizacion |
| `SYS_CONTEXT('USERENV', 'OS_USER')` | `ORIGINAL_LOGIN()` | Login original de la sesion |
| `SYS_CONTEXT('USERENV', 'IP_ADDRESS')` | `CONNECTIONPROPERTY('client_net_address')` | Direccion del cliente, si el proveedor la expone |
| `SYS_CONTEXT('USERENV', 'HOST')` | `HOST_NAME()` | Nombre de host informado por el cliente |

Los valores de sesion se convierten al ancho de las columnas destino para evitar errores de truncamiento. `HOST_NAME()` y los datos informados por el cliente son datos de auditoria orientativos, no credenciales confiables para autorizacion.

## Orden sugerido de despliegue

1. Desplegar tablas de `MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql`.
2. Desplegar:
   - `MSSQL/T3/EAI/Triggers/UPDATE_T3R_STATUS.SQL`
   - `MSSQL/T3/EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL`
3. Ejecutar pruebas de actualizacion sobre:
   - `[EAI].[T3R_STATUS]`
   - `[EAI].[T3R_SALES_DOCS_OLD]`
4. Validar inserciones esperadas en:
   - `[EAI].[T3R_STATUS_LOG]`
   - `[EAI].[LOG_T3R_SALES_DOCS_OLD]`

## Pruebas minimas recomendadas

1. Actualizar una fila de `T3R_STATUS` dejando `END_DATE = NULL` y comprobar que el log conserva los valores anteriores.
2. Actualizar varias filas de `T3R_STATUS` en una sentencia y comprobar una entrada por fila afectada.
3. Cambiar simultaneamente `DOC_STATUS`, `DOC_QTY`, `DOC_NETAMT` y `DOC_TAXAMT` en varios documentos y revisar el orden y formato de `CAMBIO`.
4. Cambiar una columna de texto desde o hacia `NULL`: igual que Oracle con `!=`, ese cambio no debe producir fragmento de auditoria.
5. Cambiar una columna numerica desde o hacia `NULL`: por la homologacion `NVL`/`ISNULL`, debe compararse contra cero.
6. Confirmar antes del despliegue que no existan duplicados en `[PROCEDURE]` ni en `[DOC_NUM_R3]`.

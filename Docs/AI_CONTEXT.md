# Contexto para IA

Usa este archivo como primer mensaje de contexto cuando pidas ayuda a una inteligencia artificial sobre este proyecto.

## Resumen del proyecto

Este repositorio contiene una migracion de objetos de base de datos Oracle hacia SQL Server para el ambiente `T3`.

La carpeta `ORA` contiene los fuentes Oracle originales de los esquemas `EAI` y `EAI_OWNER`. La carpeta `MSSQL` contiene la transformacion de esos scripts hacia SQL Server.

La relacion principal del proyecto es origen-destino:

- `ORA`: fuente Oracle.
- `MSSQL`: destino SQL Server transformado o en proceso de transformacion.

Los objetos principales estan relacionados con integraciones y procesos del dominio `EAI`, incluyendo cargas de datos, bitacoras, CFDI, clientes, pagos, ventas, inventario, stock, SAP, Salesforce/Siebel y procesos de conciliacion.

## Estructura principal

- `ORA/T3/EAI/Functions`: funciones Oracle originales del esquema `EAI`.
- `ORA/T3/EAI/Indexes`: 86 DDL individuales de indices Oracle `EAI`.
- `ORA/T3/EAI/Procedures`: procedimientos Oracle originales del esquema `EAI`.
- `ORA/T3/EAI/Packages`: specification y body de packages Oracle `EAI`.
- `ORA/T3/EAI/Triggers`: triggers Oracle originales de auditoria y estatus del esquema `EAI`.
- `ORA/T3/EAI/Tables`: definicion de tablas Oracle del esquema `EAI`.
- `ORA/T3/EAI_OWNER/Functions`: funciones Oracle originales del esquema `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Indexes`: 65 DDL individuales y una exportacion consolidada auxiliar de indices Oracle `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Procedures`: procedimientos Oracle originales del esquema `EAI_OWNER` disponibles actualmente.
- `ORA/T3/EAI_OWNER/Packages`: specification y body de packages Oracle `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Sequences`: cuatro secuencias Oracle `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Tables`: tablas Oracle originales del esquema `EAI_OWNER`.
- `MSSQL/T3/EAI/Functions`: funciones transformadas a SQL Server.
- `MSSQL/T3/EAI/Indexes`: migracion completa de los 86 indices, PK y restricciones unicas `EAI`.
- `MSSQL/T3/EAI/Procedures`: procedimientos transformados a SQL Server.
- `MSSQL/T3/EAI/Packages`: miembros independientes de `EAI.PKG_ENCUESTAS_MKT`.
- `MSSQL/T3/EAI/Triggers`: triggers `EAI` convertidos a logica set-based con `inserted` y `deleted`.
- `MSSQL/T3/EAI/Tablas`: definicion de tablas transformadas a SQL Server.
- `MSSQL/T3/EAI_OWNER/Functions`: funciones SQL Server asociadas a `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Indexes`: migracion completa de 65 indices y PK; incluye instalador consolidado y 8 columnas calculadas para indices funcionales.
- `MSSQL/T3/EAI_OWNER/Procedures`: transformacion SQL Server asociada a objetos `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Package`: miembros independientes de `EAI_OWNER.RECV_TO_SEND_V3`.
- `MSSQL/T3/EAI_OWNER/Sequences`: homologos de las cuatro secuencias Oracle.
- `MSSQL/T3/EAI_OWNER/Jobs`: despliegue controlado de 37 `USER_JOBS` en SQL Server Agent.
- `ORA/T3/T3/Procedures`: 17 procedimientos Oracle invocados directamente por jobs `EAI_OWNER`.
- `MSSQL/T3/T3/Procedures`: 156 scripts T-SQL del schema `T3`.
- `MSSQL/T3/T3/Tables`: 404 scripts de tablas `T3`; no existe actualmente un conjunto Oracle equivalente bajo `ORA/T3/T3/Tables`.

## Reglas de trabajo para la IA

Antes de proponer cambios:

1. Revisar el archivo Oracle original y su equivalente SQL Server.
2. Identificar tablas leidas, tablas insertadas, actualizadas, truncadas o eliminadas.
3. Revisar diferencias de sintaxis y comportamiento entre Oracle PL/SQL y T-SQL.
4. No asumir que el nombre de la carpeta siempre coincide con el tipo real del objeto.
5. Si el equivalente SQL Server no existe, marcar el objeto como pendiente de transformacion.
6. Si el equivalente SQL Server existe, compararlo contra Oracle antes de sugerir cambios.
7. Marcar cualquier conversion dudosa como pendiente en lugar de inventar reglas.
8. Aplicar las convenciones documentadas en `Docs/CONVERSION_RULES.md` cuando se genere o corrija T-SQL.
9. Para packages, revisar specification y body completos; SQL Server publica cada miembro como objeto independiente.
10. Para jobs, distinguir propietario (`SCHEMA_USER`) del schema del procedimiento invocado en `WHAT`.
11. No habilitar SQL Agent Jobs solo porque exista el procedimiento directo; validar dependencias internas, permisos y calendario.
12. Para indices con nombre `_PK`, revisar la restriccion en el DDL de tablas: un indice unico Oracle no demuestra por si solo que deba crearse una `PRIMARY KEY` en SQL Server.

## Diferencias Oracle -> SQL Server que suelen importar

- `SYSDATE` -> `GETDATE()` o `SYSDATETIME()`.
- `NVL` -> `ISNULL` o `COALESCE`.
- `DECODE` -> `CASE`.
- `DUAL` no existe en SQL Server.
- `VARCHAR2` -> `VARCHAR` o `NVARCHAR`, segun necesidad.
- `NUMBER` requiere decidir entre `INT`, `BIGINT`, `DECIMAL`, `NUMERIC`, etc.
- `DATE` en Oracle puede incluir hora; en SQL Server puede mapear a `datetime`, `datetime2` o `date`.
- `EXECUTE IMMEDIATE` -> SQL dinamico con `sp_executesql` cuando sea necesario.
- Manejo de transacciones y errores: `EXCEPTION` en PL/SQL vs `TRY/CATCH` en T-SQL.
- Secuencias: Oracle `sequence.NEXTVAL` vs SQL Server `NEXT VALUE FOR`.
- Cursores y variables pueden requerir ajustes de alcance y tipo.
- Evitar `dbo` si el objeto pertenece a `EAI`; preferir `[EAI].[Objeto]`.
- Evitar `dbo` si el objeto pertenece a `EAI_OWNER`; preferir `[EAI_OWNER].[Objeto]`.
- Usar `[EAI_OWNER].[ProcessID]`, `[EAI_OWNER].[Log_Start]` y `[T3].[RF_PROCESOS_LOG]` para procesos que en Oracle usan `EAI_Owner.ProcessID.NextVal`.
- Usar `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` para errores de job cuando el Oracle original registra en `MX_EAI_MESSAGE_LOG`.
- No dejar `COMMIT` o `ROLLBACK` sueltos sin `BEGIN TRANSACTION`.
- En funciones escalares T-SQL no usar `TRY/CATCH`; emular excepciones Oracle con validaciones y retornos conservadores cuando aplique.
- `DBMS_JOB` se migra a SQL Server Agent y conserva el numero Oracle mediante `dbo.Job_Oracle_SQLAgent_Map`.
- `schema.package.member` no es valido como equivalente de package: en SQL Server debe resolverse normalmente como `[schema].[member]`.

## Preguntas utiles para cada objeto

- Que problema de negocio resuelve?
- Cuales son las entradas y salidas?
- Que tablas son origen y cuales son destino?
- Hace limpieza previa con `TRUNCATE` o `DELETE`?
- Registra bitacoras o errores?
- Depende de funciones auxiliares?
- La version SQL Server conserva la logica Oracle?
- Que datos de prueba validarian el comportamiento?

## Hallazgos iniciales

- Hay 9 funciones Oracle y 9 funciones SQL Server bajo `EAI`.
- Hay 14 funciones Oracle bajo `ORA/T3/EAI_OWNER/Functions`, ya convertidas con el mismo nombre de archivo bajo `MSSQL/T3/EAI_OWNER/Functions`.
- Hay 36 funciones SQL Server bajo `MSSQL/T3/EAI_OWNER/Functions`; 22 no tienen archivo homonimo en el folder Oracle actual y deben validarse contra su origen.
- Hay 32 procedimientos Oracle bajo `ORA/T3/EAI/Procedures`.
- Hay 32 scripts de procedimiento SQL Server bajo `MSSQL/T3/EAI/Procedures`, mas el auxiliar `Procedures.slnx`.
- Hay dos triggers Oracle `EAI` y dos homologos SQL Server: `UPDATE_T3R_STATUS` y `T3R_SALES_DOCS_OLD_LOG`.
- Hay 86 indices Oracle individuales bajo `EAI` y los 86 tienen conversion homonima bajo `MSSQL/T3/EAI/Indexes`.
- Hay 65 indices Oracle individuales bajo `EAI_OWNER` y los 65 tienen conversion homonima bajo `MSSQL/T3/EAI_OWNER/Indexes`.
- Los triggers usan `[PROCEDURE]` y `[DOC_NUM_R3]` como claves logicas de emparejamiento; el DDL actual no declara llaves tecnicas y no se deben modificar esas claves dentro de las sentencias auditadas.
- Hay 86 procedimientos Oracle bajo `ORA/T3/EAI_OWNER/Procedures`, todos con archivo homonimo en `MSSQL/T3/EAI_OWNER/Procedures`.
- Hay 88 scripts SQL bajo `MSSQL/T3/EAI_OWNER/Procedures`: 86 pares homonimos, `SF_INCONSISTENCIAS_REVISAR.SQL` como variante duplicada de `SF_INCONSISTENCIAS` y `TABLA_Job_Oracle_SQLAgent_Map.SQL` como script de tabla auxiliar ubicado en la carpeta de procedimientos.
- Los procedimientos duplicados de `EAI` fueron retirados de `MSSQL/T3/EAI_OWNER/Procedures`; ambos schemas deben documentarse como conjuntos separados.
- El archivo `ORA/T3/EAI_OWNER/Tables/A51_OL_CLIENTES.SQL` esta ubicado en `Tables`, pero su contenido inicia como una funcion `CONV_45_47_CTRO`; debe revisarse antes de documentarlo como tabla.
- Se han ajustado conversiones recientes con el patron anterior: `SF_BITACORA_CFDI_RESUMEN`, `SF_BITACORA_CFDI_VENTA_SF`, `SF_CFDI_OPEN_ITEMS`, `SF_CFDI_VENTA` y `T3R_REPLICA_SALESDOC`.
- Se convirtieron recientemente las funciones `EAI_OWNER`: `GET_CLEARING_STATUS`, `GET_T3_ENABLE_EXECUTE`, `IC_MOVEMENT_TYPE`, `LETTER_TO_NUMBER`, `LINE_ITEM_TEXT`, `LOG_AUDIT_UPDATED`, `MX_CENTRO_COBZA`, `NUMBER_TO_LETTER`, `PHONE_SINTAXIS`, `SF_PAYMENT_ALLOC`, `SPECIAL_CHARS`, `SPECIAL_CHARS_EDP`, `SPECIAL_CHARS_NEW` y `WA_DN_SKU`.
- En `LOG_AUDIT_UPDATED`, el `ROWID` Oracle se mapeo a `TICKET_REFERENCIA` porque las tablas log SQL Server migradas no exponen una columna `ROWID`.
- `CURRENCY_TEXT` y `GET_4428_REFERENCE` ya se declaran bajo el schema `EAI_OWNER`; evitar reintroducir `dbo`.
- `WA_CIERRE_FLUJOS` es un wrapper transaccional: suspende todos los jobs mediante `EAI_OWNER.Job_Manage('Suspend', 'Todos')` y confirma la operacion.
- La revision mas reciente de procedimientos `WA_*` conserva comportamientos Oracle que requieren especial cuidado: commits dentro de manejadores de excepcion, cursores, `ROWNUM` sin orden explicito, cadenas CLOB fragmentadas y llamadas dinamicas o externas.
- Siete procedimientos de reproceso `WA_ERR_*` usan `MX_EAI_MESSAGE_LOG.ROW_ID` como llave origen: Customer, Intercompany, Invoice, Payment, Product, Replenishment Large y Replenishment Ampersand. El DDL de `ROW_ID` debe desplegarse antes que estos procedimientos; el identificador logico de `MX_RECEIVE_MESSAGE_LOG` se mantiene separado.
- `WA_PURGE_MX_EAI_MESSAGE_LOG` y los ocho bloques de `WA_DEPURA_MESSAGE_LOG` que limpian `MX_EAI_MESSAGE_LOG` materializan primero los `ROW_ID` candidatos y eliminan despues por esa llave. Sus relaciones de negocio solo determinan el conjunto inicial.
- `EAI_OWNER.RECV_TO_SEND_V3` se migro a 12 procedimientos con sus nombres originales, sin el prefijo del package. `GRANTS.SQL` solo concede permisos.
- `EAI.PKG_ENCUESTAS_MKT` se migro a tres procedimientos y una funcion; la publicacion CEDIS requiere linked server y sinonimo configurados por DBA.
- Los cuatro DDL Oracle de secuencias `EAI_OWNER` tienen script SQL Server. Permanecen referencias divergentes en `PURGE_ACCOUNT_HEADER` y `SF_INCONSISTENCIAS_REVISAR`.
- Los 37 jobs del inventario `USER_JOBS` pertenecen a `EAI_OWNER`: 15 llaman `EAI_OWNER`, cinco llaman `EAI` y 17 llaman `T3`. Todos se crean deshabilitados.
- Los 17 procedimientos T3 llamados directamente existen y sus firmas coinciden, pero hay diez dependencias internas pendientes por nombre exacto; consultar `Docs/JOBS_MIGRATION.md`.
- `GET_T3_ENABLE_EXECUTE` busca todavía el texto `RECV_TO_SEND_V3`; los nuevos job names y steps no lo contienen. Resolver esta compatibilidad antes de habilitar jobs.
- `JOB_MANAGE('Suspend','Todos')` usa patrones historicos de comandos que pueden no incluir los nuevos steps `ORA_*`; validar el cierre de flujos contra la tabla de mapeo.

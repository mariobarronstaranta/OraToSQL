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
- `ORA/T3/EAI/Procedures`: procedimientos Oracle originales del esquema `EAI`.
- `ORA/T3/EAI/Tables`: definicion de tablas Oracle del esquema `EAI`.
- `ORA/T3/EAI_OWNER/Functions`: funciones Oracle originales del esquema `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Procedures`: procedimientos Oracle originales del esquema `EAI_OWNER` disponibles actualmente.
- `ORA/T3/EAI_OWNER/Tables`: tablas Oracle originales del esquema `EAI_OWNER`.
- `MSSQL/T3/EAI/Functions`: funciones transformadas a SQL Server.
- `MSSQL/T3/EAI/Procedures`: procedimientos transformados a SQL Server.
- `MSSQL/T3/EAI/Tablas`: definicion de tablas transformadas a SQL Server.
- `MSSQL/T3/EAI_OWNER/Functions`: funciones SQL Server asociadas a `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Procedures`: transformacion SQL Server asociada a objetos `EAI_OWNER`.

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
- Hay 39 procedimientos Oracle bajo `ORA/T3/EAI_OWNER/Procedures`, todos con archivo homonimo en `MSSQL/T3/EAI_OWNER/Procedures`.
- Hay 88 procedimientos SQL Server bajo `MSSQL/T3/EAI_OWNER/Procedures`; 49 no tienen archivo homonimo en el origen Oracle actualmente incorporado y requieren validar su fuente.
- Los procedimientos duplicados de `EAI` fueron retirados de `MSSQL/T3/EAI_OWNER/Procedures`; ambos schemas deben documentarse como conjuntos separados.
- El archivo `ORA/T3/EAI_OWNER/Tables/A51_OL_CLIENTES.SQL` esta ubicado en `Tables`, pero su contenido inicia como una funcion `CONV_45_47_CTRO`; debe revisarse antes de documentarlo como tabla.
- Se han ajustado conversiones recientes con el patron anterior: `SF_BITACORA_CFDI_RESUMEN`, `SF_BITACORA_CFDI_VENTA_SF`, `SF_CFDI_OPEN_ITEMS`, `SF_CFDI_VENTA` y `T3R_REPLICA_SALESDOC`.
- Se convirtieron recientemente las funciones `EAI_OWNER`: `GET_CLEARING_STATUS`, `GET_T3_ENABLE_EXECUTE`, `IC_MOVEMENT_TYPE`, `LETTER_TO_NUMBER`, `LINE_ITEM_TEXT`, `LOG_AUDIT_UPDATED`, `MX_CENTRO_COBZA`, `NUMBER_TO_LETTER`, `PHONE_SINTAXIS`, `SF_PAYMENT_ALLOC`, `SPECIAL_CHARS`, `SPECIAL_CHARS_EDP`, `SPECIAL_CHARS_NEW` y `WA_DN_SKU`.
- En `LOG_AUDIT_UPDATED`, el `ROWID` Oracle se mapeo a `TICKET_REFERENCIA` porque las tablas log SQL Server migradas no exponen una columna `ROWID`.
- `CURRENCY_TEXT` y `GET_4428_REFERENCE` ya se declaran bajo el schema `EAI_OWNER`; evitar reintroducir `dbo`.

# Inventario

Este inventario fue generado a partir de la estructura actual del repositorio. Cubre los scripts fuente Oracle, las conversiones SQL Server y los documentos de soporte bajo `Docs`.

Nota de alcance: los conteos de objetos SQL no incluyen carpetas internas de herramienta como `.vs`. Cuando una carpeta contiene archivos auxiliares, se indica por separado.

## Conteo por carpeta

`ORA` contiene los fuentes Oracle de los esquemas `EAI` y `EAI_OWNER`. `MSSQL` contiene la transformacion de esos scripts hacia SQL Server.

| Ruta | Archivos | Objetos SQL | Observacion |
| --- | ---: | ---: | --- |
| `ORA/T3/EAI/Functions` | 9 | 9 | Funciones Oracle |
| `ORA/T3/EAI/Procedures` | 32 | 31 | Procedimientos Oracle; `SF_CFDI_NOTA_CREDITO` existe con y sin extension |
| `ORA/T3/EAI/Tables` | 1 | 1 | Script consolidado de tablas Oracle |
| `ORA/T3/EAI_OWNER/Tables` | 4 | 4 | Tablas Oracle de `EAI_OWNER`, con un archivo a revisar |
| `MSSQL/T3/EAI/Functions` | 9 | 9 | Funciones SQL Server |
| `MSSQL/T3/EAI/Procedures` | 33 | 31 | 32 scripts de procedimiento mas `Procedures.slnx`; `SF_CFDI_NOTA_CREDITO` existe con y sin extension |
| `MSSQL/T3/EAI/Tablas` | 1 | 1 | Script consolidado de tablas SQL Server |
| `MSSQL/T3/EAI_OWNER/Procedures` | 33 | 32 | Procedimientos transformados asociados a `EAI_OWNER`; incluye `LOGSTART` |
| `MSSQL/T3/EAI_OWNER/Tables` | 1 | 1 | Script consolidado de tablas SQL Server para `EAI_OWNER` |
| `Docs` | 9 | N/A | Documentacion y archivos Excel de soporte |

## Funciones EAI

| Objeto | Oracle | SQL Server |
| --- | --- | --- |
| `CONV_45_47_CTRO` | `ORA/T3/EAI/Functions/Conv_45_47_Ctro.SQL` | `MSSQL/T3/EAI/Functions/Conv_45_47_Ctro.SQL` |
| `CONV_ALM_TO_DIST` | `ORA/T3/EAI/Functions/CONV_ALM_TO_DIST.SQL` | `MSSQL/T3/EAI/Functions/CONV_ALM_TO_DIST.SQL` |
| `CONV_ALM_TO_PLANT` | `ORA/T3/EAI/Functions/CONV_ALM_TO_PLANT.SQL` | `MSSQL/T3/EAI/Functions/CONV_ALM_TO_PLANT.SQL` |
| `CONV_DIST_TO_PLANT` | `ORA/T3/EAI/Functions/Conv_Dist_to_Plant.SQL` | `MSSQL/T3/EAI/Functions/Conv_Dist_to_Plant.SQL` |
| `CONV_FECHA_MANTIS` | `ORA/T3/EAI/Functions/CONV_FECHA_MANTIS.SQL` | `MSSQL/T3/EAI/Functions/CONV_FECHA_MANTIS.SQL` |
| `CONV_PLANT_TO_DIST` | `ORA/T3/EAI/Functions/CONV_PLANT_TO_DIST.SQL` | `MSSQL/T3/EAI/Functions/CONV_PLANT_TO_DIST.SQL` |
| `F_SEMANA_MES` | `ORA/T3/EAI/Functions/F_SEMANA_MES.SQL` | `MSSQL/T3/EAI/Functions/F_SEMANA_MES.SQL` |
| `ISNUMBER` | `ORA/T3/EAI/Functions/ISNUMBER.SQL` | `MSSQL/T3/EAI/Functions/ISNUMBER.SQL` |
| `PORC_VENTA` | `ORA/T3/EAI/Functions/PORC_VENTA.SQL` | `MSSQL/T3/EAI/Functions/PORC_VENTA.SQL` |

## Procedimientos EAI principales

Estos procedimientos existen en Oracle y tienen version SQL Server bajo `MSSQL/T3/EAI/Procedures`.

```text
CCEA_DATA_ALLOCATION
CCEA_DATA_OPENITEM
CCEA_DATA_PAYMENT
CCEA_DATA_SALE
CCEA_DATA_STOCK
CCEA_DATA_UNLOAD
CC_DEBT_LDR_TO_CIFRAS
CC_SALESDOC_LDR_TO_CIFRAS
CC_STOCK_SAP
CUSTOMER_LOG_UPDATE
EXECUTE_TRUNCATE
INSERT_DEBITNOTE
INSERT_EAI_MESSAGE_LOG
INSERT_ERR_CLIENTE
INSERT_ERROR_CLIENTE
INSERT_FOLIOS_FE
INSERT_RECEIVE_MESSAGE
INSERT_RECEIVE_MESSAGE_CLOB
MOVE_EVIDENCIA_ENTREGA
SF_BITACORA_CFDI
SF_BITACORA_CFDI_RESUMEN
SF_BITACORA_CFDI_VENTA_SF
SF_CFDI_NOTA_CREDITO
SF_CFDI_OPEN_ITEMS
SF_CFDI_VENTA
SF_CLIENTE_SIEBEL
T3R_REPLICA_SALESDOC
TRACE_PLSQL
UPDATE_711_RECEPCION
UPDATE_FACT_CANCEL
WA_ENABLE_REMISION_OBD
```

Nota: el conteo de scripts de procedimiento es 32, pero hay 31 objetos distintos porque `SF_CFDI_NOTA_CREDITO` aparece con y sin extension `.SQL`. La carpeta `MSSQL/T3/EAI/Procedures` tambien contiene el archivo auxiliar `Procedures.slnx`.

## Procedimientos EAI_OWNER SQL Server

`MSSQL/T3/EAI_OWNER/Procedures` contiene una copia transformada de los procedimientos EAI y un procedimiento adicional:

- Los 31 objetos listados en la seccion anterior.
- `SF_CFDI_NOTA_CREDITO` tambien aparece con y sin extension `.SQL`.
- `LOGSTART` existe solo bajo `MSSQL/T3/EAI_OWNER/Procedures/LOGSTART.SQL`.

## Tablas

Oracle:

- `ORA/T3/EAI/Tables/Tables_Oracle_EAI.sql` contiene el esquema `EAI`.
- `ORA/T3/EAI_OWNER/Tables/ACTUAL_STOCK.sql`.
- `ORA/T3/EAI_OWNER/Tables/CATALOGO_COLONIA_SAT.sql`.
- `ORA/T3/EAI_OWNER/Tables/CAT_OFICIAL_COLONIA.sql`.
- `ORA/T3/EAI_OWNER/Tables/A51_OL_CLIENTES.SQL` requiere revision porque parece contener una funcion.

SQL Server:

- `MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql` contiene tablas `EAI` y tambien tablas `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql` contiene tablas transformadas asociadas a `EAI_OWNER`.

## Documentos de soporte

| Archivo | Tipo | Uso esperado |
| --- | --- | --- |
| `Docs/AI_CONTEXT.md` | Markdown | Contexto operativo para asistentes IA |
| `Docs/CONVERSION_RULES.md` | Markdown | Reglas y convenciones de conversion Oracle a SQL Server |
| `Docs/DOCUMENTATION_PLAN.md` | Markdown | Plan de documentacion |
| `Docs/INVENTORY.md` | Markdown | Este inventario |
| `Docs/PROMPTS.md` | Markdown | Prompts de trabajo |
| `Docs/README.md` | Markdown | Guia principal de la documentacion |
| `Docs/AccesosBDOracle.xlsx` | Excel | Accesos o referencia de bases Oracle |
| `Docs/Control_Migracion_Objetos_MB.xlsx` | Excel | Control de migracion de objetos |
| `Docs/T3MX Objects June 2026.xlsx` | Excel | Inventario externo de objetos T3MX |

## Hallazgos a revisar

- Revisar si `MSSQL/T3/EAI/Procedures` y `MSSQL/T3/EAI_OWNER/Procedures` deben mantenerse como transformaciones separadas o si representan duplicidad funcional.
- Existen archivos `SF_CFDI_NOTA_CREDITO` con y sin extension `.SQL`.
- `LOGSTART.SQL` existe en `MSSQL/T3/EAI_OWNER/Procedures`, pero no tiene contraparte bajo `ORA/T3/EAI/Procedures` ni `MSSQL/T3/EAI/Procedures`.
- `Procedures.slnx` es un archivo auxiliar de solucion y no un objeto SQL.
- El archivo `A51_OL_CLIENTES.SQL` no parece corresponder a una tabla por su contenido inicial.
- Algunos objetos usan `dbo` en SQL Server aunque su origen esta bajo `EAI`; validar convencion de schema esperada.

## Conversiones revisadas recientemente

Estos objetos fueron ajustados en `MSSQL/T3/EAI/Procedures` siguiendo la convencion documentada en `Docs/CONVERSION_RULES.md`:

| Objeto | Archivo SQL Server | Observacion |
| --- | --- | --- |
| `SF_BITACORA_CFDI_RESUMEN` | `MSSQL/T3/EAI/Procedures/SF_BITACORA_CFDI_RESUMEN.SQL` | Usa logging con `ProcessID`, `Log_Start`, `RF_PROCESOS_LOG` y errores en `MX_EAI_MESSAGE_LOG`. |
| `SF_BITACORA_CFDI_VENTA_SF` | `MSSQL/T3/EAI/Procedures/SF_BITACORA_CFDI_VENTA_SF.SQL` | Referencias a tablas con schema/corchetes; evita llamar `RF_PROCESOS_LOG` como procedimiento. |
| `SF_CFDI_OPEN_ITEMS` | `MSSQL/T3/EAI/Procedures/SF_CFDI_OPEN_ITEMS.SQL` | Conversion alineada al patron de logging del proyecto. |
| `SF_CFDI_VENTA` | `MSSQL/T3/EAI/Procedures/SF_CFDI_VENTA.SQL` | Conversion set-based para actualizar cobranza y timbrado. |
| `T3R_REPLICA_SALESDOC` | `MSSQL/T3/EAI/Procedures/T3R_REPLICA_SALESDOC.SQL` | Ajustado de `dbo` a `[EAI]`; errores enviados a `MX_EAI_MESSAGE_LOG`. |

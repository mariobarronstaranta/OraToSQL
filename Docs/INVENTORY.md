# Inventario

Este inventario fue generado a partir de la estructura actual del repositorio. Cubre los scripts fuente Oracle, las conversiones SQL Server y los documentos de soporte bajo `Docs`.

Nota de alcance: los conteos de objetos SQL no incluyen carpetas internas de herramienta como `.vs`. Cuando una carpeta contiene archivos auxiliares, se indica por separado.

## Conteo por carpeta

`ORA` contiene los fuentes Oracle de los esquemas `EAI` y `EAI_OWNER`. `MSSQL` contiene la transformacion de esos scripts hacia SQL Server.

| Ruta | Archivos | Objetos SQL | Observacion |
| --- | ---: | ---: | --- |
| `ORA/T3/EAI/Functions` | 9 | 9 | Funciones Oracle |
| `ORA/T3/EAI/Procedures` | 32 | 31 | Procedimientos Oracle; `SF_CFDI_NOTA_CREDITO` existe con y sin extension |
| `ORA/T3/EAI/Packages` | 2 | 1 package / 4 miembros | Specification vacia y body de `PKG_ENCUESTAS_MKT` |
| `ORA/T3/EAI/Indexes` | 86 | 86 | DDL Oracle individuales: 56 indices normales y 30 indices unicos |
| `ORA/T3/EAI/Triggers` | 2 | 2 | Triggers Oracle de auditoria/estatus |
| `ORA/T3/EAI/Tables` | 1 | 1 | Script consolidado de tablas Oracle |
| `ORA/T3/EAI_OWNER/Functions` | 14 | 14 | Funciones Oracle originales del esquema `EAI_OWNER` |
| `ORA/T3/EAI_OWNER/Procedures` | 86 | 86 | Procedimientos Oracle originales de `EAI_OWNER`; todos tienen archivo homonimo en SQL Server |
| `ORA/T3/EAI_OWNER/Packages` | 2 | 1 package / 12 miembros | Specification y body de `RECV_TO_SEND_V3` |
| `ORA/T3/EAI_OWNER/Indexes` | 66 | 65 | 65 DDL individuales mas `DDL_INDEX_EAI_OWNER.SQL` como archivo consolidado auxiliar; 63 indices normales y 2 unicos |
| `ORA/T3/EAI_OWNER/Sequences` | 4 | 4 | Secuencias Oracle con homologo SQL Server |
| `ORA/T3/EAI_OWNER/Tables` | 15 | 15 | Tablas Oracle de `EAI_OWNER`, con un archivo a revisar |
| `ORA/T3/T3/Procedures` | 17 | 17 | Procedimientos Oracle invocados directamente por jobs `EAI_OWNER` |
| `ORA/T3/T3/Tables` | 0 | 0 | No se han incorporado los DDL Oracle de las tablas T3 |
| `MSSQL/T3/EAI/Functions` | 9 | 9 | Funciones SQL Server |
| `MSSQL/T3/EAI/Procedures` | 33 | 31 | 32 scripts de procedimiento mas `Procedures.slnx`; `SF_CFDI_NOTA_CREDITO` existe con y sin extension |
| `MSSQL/T3/EAI/Packages` | 6 | 4 objetos + 1 plantilla | Tres procedimientos, una funcion, configuracion CEDIS y README |
| `MSSQL/T3/EAI/Indexes` | 87 | 86 | 86 scripts individuales mas `Indices_Consolidados_EAI.SQL`; migracion validada sobre 43 tablas en LocalDB |
| `MSSQL/T3/EAI/Triggers` | 2 | 2 | Triggers SQL Server homologados desde Oracle |
| `MSSQL/T3/EAI/Tablas` | 1 | 1 | Script consolidado de tablas SQL Server |
| `MSSQL/T3/EAI_OWNER/Functions` | 36 | 36 | Funciones SQL Server de `EAI_OWNER`; 14 corresponden al folder Oracle actual y 22 son preexistentes sin archivo par en `ORA/T3/EAI_OWNER/Functions` |
| `MSSQL/T3/EAI_OWNER/Indexes` | 66 | 65 | 65 scripts individuales mas `Indices_Consolidados_EAI_OWNER.SQL`; incluye 8 indices funcionales mediante columnas calculadas |
| `MSSQL/T3/EAI_OWNER/Procedures` | 88 | 87 | 86 procedimientos tienen par Oracle; un script duplica `SF_INCONSISTENCIAS` y otro crea una tabla auxiliar |
| `MSSQL/T3/EAI_OWNER/Package` | 14 | 12 procedimientos | Miembros de `RECV_TO_SEND_V3`, `GRANTS.SQL` y README |
| `MSSQL/T3/EAI_OWNER/Sequences` | 5 | 4 | Cuatro secuencias y README |
| `MSSQL/T3/EAI_OWNER/Jobs` | 6 | 37 jobs al desplegar | Cuatro scripts operativos, CSV fuente y README |
| `MSSQL/T3/EAI_OWNER/Tables` | 2 | 2 | Script consolidado y migracion incremental de `MX_EAI_MESSAGE_LOG` |
| `MSSQL/T3/T3/Procedures` | 156 | 156 | Procedimientos T3 migrados; incluye los 17 destinos directos de jobs |
| `MSSQL/T3/T3/Tables` | 404 | 404 | DDL SQL Server T3; falta incorporar su fuente Oracle equivalente |
| `Docs` | 16 | N/A | Trece documentos Markdown y tres archivos Excel de soporte |

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

## Triggers EAI

| Objeto | Oracle | SQL Server |
| --- | --- | --- |
| `UPDATE_T3R_STATUS` | `ORA/T3/EAI/Triggers/UPDATE_T3R_STATUS.SQL` | `MSSQL/T3/EAI/Triggers/UPDATE_T3R_STATUS.SQL` |
| `T3R_SALES_DOCS_OLD_LOG` | `ORA/T3/EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL` | `MSSQL/T3/EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL` |

## Indices y PK

- `ORA/T3/EAI/Indexes` contiene 86 DDL individuales: 56 `CREATE INDEX` y
  30 `CREATE UNIQUE INDEX`.
- `ORA/T3/EAI_OWNER/Indexes` contiene 65 DDL individuales: 63
  `CREATE INDEX` y dos `CREATE UNIQUE INDEX`. El archivo
  `DDL_INDEX_EAI_OWNER.SQL` conserva la exportacion consolidada y no se cuenta
  como objeto adicional.
- `MSSQL/T3/EAI/Indexes` contiene los 86 archivos homologos: 56 indices
  normales, dos indices unicos independientes, 27 PK y una restriccion
  `UNIQUE`. Las PK y la restriccion unica usan verificaciones condicionales
  para no duplicar las estructuras ya incluidas en el DDL de tablas.
- `MSSQL/T3/EAI/Indexes/Indices_Consolidados_EAI.SQL` agrupa los 86 objetos en
  un solo instalador idempotente. Es un archivo auxiliar y no incrementa el
  numero de objetos del schema.
- `MSSQL/T3/EAI_OWNER/Indexes` contiene los 65 homologos: 55 indices
  ordinarios, ocho indices funcionales mediante columnas calculadas persistidas
  y dos PK condicionales. `Indices_Consolidados_EAI_OWNER.SQL` permite instalar
  todo el lote desde un solo archivo.
- Los DDL Oracle con nombre terminado en `_PK` pueden ser el indice que soporta
  una llave primaria, pero `CREATE UNIQUE INDEX` por si solo no crea la
  restriccion `PRIMARY KEY`. La conversion debe contrastarse con el DDL de
  tablas antes de decidir entre `PRIMARY KEY` y `UNIQUE INDEX`.

Consultar `Docs/INDEXES_MIGRATION.md` para el alcance, reglas y estado de la
conversion.

## Funciones EAI_OWNER

Estas funciones existen en Oracle bajo `ORA/T3/EAI_OWNER/Functions` y tienen version SQL Server con el mismo nombre de archivo bajo `MSSQL/T3/EAI_OWNER/Functions`.

| Objeto | Oracle | SQL Server | Observacion |
| --- | --- | --- | --- |
| `GET_CLEARING_STATUS` | `ORA/T3/EAI_OWNER/Functions/GET_CLEARING_STATUS.SQL` | `MSSQL/T3/EAI_OWNER/Functions/GET_CLEARING_STATUS.SQL` | Consulta cobranza y determina estatus de compensacion. |
| `GET_T3_ENABLE_EXECUTE` | `ORA/T3/EAI_OWNER/Functions/GET_T3_ENABLE_EXECUTE.SQL` | `MSSQL/T3/EAI_OWNER/Functions/GET_T3_ENABLE_EXECUTE.SQL` | Evalua componentes/jobs T3; en SQL Server consulta metadatos de `msdb`. |
| `IC_MOVEMENT_TYPE` | `ORA/T3/EAI_OWNER/Functions/IC_MOVEMENT_TYPE.SQL` | `MSSQL/T3/EAI_OWNER/Functions/IC_MOVEMENT_TYPE.SQL` | Clasifica movimientos de pago. |
| `LETTER_TO_NUMBER` | `ORA/T3/EAI_OWNER/Functions/LETTER_TO_NUMBER.SQL` | `MSSQL/T3/EAI_OWNER/Functions/LETTER_TO_NUMBER.SQL` | Convierte letras tipo columna Excel a numero. |
| `LINE_ITEM_TEXT` | `ORA/T3/EAI_OWNER/Functions/LINE_ITEM_TEXT.SQL` | `MSSQL/T3/EAI_OWNER/Functions/LINE_ITEM_TEXT.SQL` | Extrae texto de linea despues de `/`. |
| `LOG_AUDIT_UPDATED` | `ORA/T3/EAI_OWNER/Functions/LOG_AUDIT_UPDATED.SQL` | `MSSQL/T3/EAI_OWNER/Functions/LOG_AUDIT_UPDATED.SQL` | Reconstruye llave o detalle de cambios; usa `TICKET_REFERENCIA` como identificador equivalente disponible para el `ROWID` Oracle. |
| `MX_CENTRO_COBZA` | `ORA/T3/EAI_OWNER/Functions/MX_CENTRO_COBZA.SQL` | `MSSQL/T3/EAI_OWNER/Functions/MX_CENTRO_COBZA.SQL` | Obtiene centro de cobranza por cliente o centro de venta. |
| `NUMBER_TO_LETTER` | `ORA/T3/EAI_OWNER/Functions/NUMBER_TO_LETTER.SQL` | `MSSQL/T3/EAI_OWNER/Functions/NUMBER_TO_LETTER.SQL` | Convierte numero a letras tipo columna Excel. |
| `PHONE_SINTAXIS` | `ORA/T3/EAI_OWNER/Functions/PHONE_SINTAXIS.SQL` | `MSSQL/T3/EAI_OWNER/Functions/PHONE_SINTAXIS.SQL` | Normaliza telefono/fax. |
| `SF_PAYMENT_ALLOC` | `ORA/T3/EAI_OWNER/Functions/SF_PAYMENT_ALLOC.SQL` | `MSSQL/T3/EAI_OWNER/Functions/SF_PAYMENT_ALLOC.SQL` | Valida asignacion de pago relacionada a IDoc. |
| `SPECIAL_CHARS` | `ORA/T3/EAI_OWNER/Functions/SPECIAL_CHARS.SQL` | `MSSQL/T3/EAI_OWNER/Functions/SPECIAL_CHARS.SQL` | Sustituye caracteres especiales puntuales. |
| `SPECIAL_CHARS_EDP` | `ORA/T3/EAI_OWNER/Functions/SPECIAL_CHARS_EDP.SQL` | `MSSQL/T3/EAI_OWNER/Functions/SPECIAL_CHARS_EDP.SQL` | Sustituye acentos y caracteres especiales para EDP. |
| `SPECIAL_CHARS_NEW` | `ORA/T3/EAI_OWNER/Functions/SPECIAL_CHARS_NEW.SQL` | `MSSQL/T3/EAI_OWNER/Functions/SPECIAL_CHARS_NEW.SQL` | Sustituye acentos y caracteres especiales. |
| `WA_DN_SKU` | `ORA/T3/EAI_OWNER/Functions/WA_DN_SKU.SQL` | `MSSQL/T3/EAI_OWNER/Functions/WA_DN_SKU.SQL` | Deriva SKU segun prefijo de nota de debito. |

Funciones SQL Server preexistentes en `MSSQL/T3/EAI_OWNER/Functions` sin par actual en `ORA/T3/EAI_OWNER/Functions`: `CHK_BANKCENTRAL_ALLOC`, `CHK_CREDITMEMO_ALLOC`, `CHK_CTRL_INVOICING`, `CHK_ZLOB_DOCUMENT`, `CURRENCY_TEXT`, `FN_CHECK_INSTANCE`, `FN_CONV_DOCTO_LETRA`, `FN_GET_CLIENTE_TMD`, `FN_GET_DOC_TYPE`, `FN_GET_PAY_REFERENCE`, `FN_GET_PAY_REFERENCE_NEW`, `FN_GET_TAX_ISSUE`, `FN_GET_UP_PAY_AMOUNT`, `FN_GET_UP_PAY_AMOUNT2`, `GET_4428_REFERENCE`, `GETCONV`, `GETCONV_COLONIA`, `GETCONV_MP_CFD`, `GETNAMESPACE`, `GETNEXTRUN`, `IC_CHECK_DOCUMENT`, `IC_CHECK_INVOICE`.

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

## Procedimientos EAI_OWNER

La carpeta ya no representa una copia de los procedimientos `EAI`. Los duplicados de `EAI` fueron retirados y se incorporo el conjunto propio de `EAI_OWNER`.

Los 86 procedimientos con par homonimo Oracle/SQL Server son:

```text
DEBITNOTE_TO_IFC
EXECUTE_TRUNCATE
INVOICE_FIX_TAX
INVOICE_TO_ENTREGA
INVOICE_TO_ENTREGA_PO
INVOICE_TO_FACTURA
INVOICE_TO_OTROS
INVOICE_TO_OTROS_PARTNERS
INVOICE_TO_OTROS_RETENTION
INVOICE_TO_OTROS_V33
INVOICE_TO_PREVENTA
INVOICE_TO_PREVENTA_NEW
JOB_INTERVAL
JOB_MANAGE
JOB_NEXT_DATE
JOB_NEXT_RUN
JOB_REFRESH
LOG_END
LOG_START
PROC_RECEIVE_REFERENCE
PROC_REPLENISHMENT_SUBDEPOT
PURGE_ACCOUNT_HEADER
PURGE_COMPONENT_LOG
PURGE_DOCUMENT_HEADER
PURGE_MESSAGE_LOG
PURGE_RECEIVE_LOG
PURGE_TEMPORAL_SAP
SF_GET_CREDIT_DATA
SF_GET_CUSTOMER_DATA
SF_GET_INVOICE_DATA
SF_GET_REP_DATA
SF_INCONSISTENCIAS
SF_JOB_MANAGE
SF_JOB_MANAGE_EOD
SF_PROC_CENTRAL_EXECUTE
SF_PROC_CENTRAL_EXECUTE_NEW
SF_PROC_CENTRAL_INCOBRABLE
SF_PROC_CENTRAL_PAYALLOC
SF_PROC_CENTRAL_PAYMENT
SF_PROC_CENTRAL_PAYMENT_CM
SF_PROC_CENTRAL_PAYMENT_ZV
SF_PROC_CUSTOMER
SF_PROC_CUSTOMER_MAIL
SF_PROC_CUSTOMER_N
SF_PROC_CUSTOMER_O
SF_PROC_PREINVOICE_IFC
SF_PROC_PREINVOICE_INTER
SF_PROC_PRODUCT
SF_PROC_REPLENISHMENT
SF_SAMPLES_GETINFO
SF_WA_PROC_REPLENISHMENT
WA_ACCNT_COMPLEMENT
WA_ACCNT_PAYAMOUNT
WA_ACCNT_PAYAMOUNT_CM
WA_ACCNT_REFOLEO
WA_ASIGNACION_PAGO
WA_ASIGNACION_PAGO_INSERT
WA_ASIGNACION_PAGO_RFC
WA_ASIGNA_INCOBRABLE
WA_ASIGNA_NOTACARGO
WA_BAT_PRODUCTORA
WA_CANTIDAD_UMV
WA_CHECK_PAYNULL
WA_CIERRE_FLUJOS
WA_DEPURA_MESSAGE_LOG
WA_DIF_IVA_SAP_T3
WA_ERR_CUSTOMER_AMPERSAND
WA_ERR_INVOICE_AMPERSAND
WA_ERR_INTERCOMPANY
WA_ERR_PAYMENT_AMPERSAND
WA_ERR_PRODUCT_AMPERSAND
WA_ERR_REPLENISH_AMPERSAND
WA_ERR_REPLENISHMENT_LARGE
WA_ERR_SEQUENCE
WA_ERR_TSEQ
WA_ERR_TSEQ_PRESALES
WA_EXECUTE_ARCHIVING
WA_FOLIO_FACTURA
WA_PURGE_MX_EAI_MESSAGE_LOG
WA_QTY_SAP_BILLING
WA_REP_MASTERDATA
WA_RESEND_CFDI
WA_RUN_STATEMENTS
WA_SEARCH_INVOICE_CANCEL
WA_TSEQ_HIST
WA_ZZ_TRASH
```

La incorporacion de fuentes Oracle aumento este conjunto de 39 a 86 pares y elimino el pendiente documental de origen para 47 conversiones SQL Server preexistentes.

Los dos archivos SQL Server sin homonimo Oracle no son procedimientos nuevos pendientes de origen:

- `SF_INCONSISTENCIAS_REVISAR.SQL` declara nuevamente `EAI_OWNER.SF_INCONSISTENCIAS`; es una variante de revision que debe consolidarse o archivarse.
- `TABLA_Job_Oracle_SQLAgent_Map.SQL` crea `dbo.Job_Oracle_SQLAgent_Map`; es una tabla auxiliar ubicada dentro de la carpeta de procedimientos y conviene reubicarla.

## Packages

| Package Oracle | Fuente | Destino SQL Server | Estado |
|---|---|---|---|
| `EAI_OWNER.RECV_TO_SEND_V3` | `ORA/T3/EAI_OWNER/Packages` | `MSSQL/T3/EAI_OWNER/Package` | 12 miembros migrados como procedimientos independientes y sin prefijo del package |
| `EAI.PKG_ENCUESTAS_MKT` | `ORA/T3/EAI/Packages` | `MSSQL/T3/EAI/Packages` | Tres procedimientos y una funcion; publicacion CEDIS pendiente de configuracion real |

`GRANTS.SQL` concede permisos sobre los miembros de `RECV_TO_SEND_V3`; no es un
equivalente del package. Consultar `Docs/PACKAGES_MIGRATION.md`.

## Secuencias EAI_OWNER

Los cuatro DDL Oracle tienen homologo bajo `MSSQL/T3/EAI_OWNER/Sequences`:

```text
ProcessID
SEQ_ALLOCATION_SIBDB
SEQ_PAYMENT_SIBDB
Seq_Purge_LEGDB
```

Pendientes: `PURGE_ACCOUNT_HEADER` usa `dbo.Seq_Purge_LEGDB` y la variante
`SF_INCONSISTENCIAS_REVISAR` usa `dbo.ProcessID`. `LOG_END` ya fue corregido.
Consultar `Docs/SEQUENCES_MIGRATION.md`.

## Jobs EAI_OWNER

El inventario entregado contiene 37 `USER_JOBS`: 32 activos y cinco `BROKEN`.
Todos pertenecen a `EAI_OWNER`, aunque 15 comandos llaman objetos `EAI_OWNER`,
cinco llaman `EAI` y 17 llaman `T3`.

Los scripts de `MSSQL/T3/EAI_OWNER/Jobs` crean los jobs deshabilitados, validan
dependencias, habilitan de forma controlada y permiten deshabilitarlos sin borrar
historial. Los 17 procedimientos T3 directos existen y aceptan los parametros de
los steps; hay diez dependencias internas pendientes por nombre exacto.

También falta resolver que `GET_T3_ENABLE_EXECUTE` busca `RECV_TO_SEND_V3`, texto
que ya no aparece en los nombres ni steps generados. Consultar
`Docs/JOBS_MIGRATION.md`.

`WA_CIERRE_FLUJOS` depende de `JOB_MANAGE('Suspend','Todos')`; la seleccion
actual usa patrones de comandos Oracle historicos y debe probarse contra los
steps T-SQL `ORA_*` antes de declarar operativo el cierre.

## Objetos T3 relacionados con jobs

- `ORA/T3/T3/Procedures` contiene los 17 procedimientos Oracle solicitados para
  los jobs.
- `MSSQL/T3/T3/Procedures` contiene 156 scripts, incluidos los 17 destinos.
- `MSSQL/T3/T3/Tables` contiene 404 DDL; no hay fuentes bajo
  `ORA/T3/T3/Tables`, por lo que su trazabilidad Oracle permanece pendiente.
- `PROC_T3_EOD` y `PROC_T3_BOD` conservan una llamada
  `T3.PKG_T3.PROC_T3_LANZA_REP` que no representa un package en SQL Server.

## Tablas

Oracle:

- `ORA/T3/EAI/Tables/Tables_Oracle_EAI.sql` contiene el esquema `EAI`.
- `ORA/T3/EAI_OWNER/Tables` contiene 15 archivos: `ACTUAL_STOCK`,
  `CAT_OFICIAL_COLONIA`, `CAT_REPS`, `CAT_SAT_CIUDAD`, `CAT_SAT_COLONIA`,
  `CATALOGO_COLONIA_SAT`, `CLIENT`, `COMPONENTS_DB`, `CREDIT_DETAILS`,
  `CREDIT_NOTES`, `CUSTOMERS_RULES`, `CUSTOMERS_RULES_ACT`, `DEBIT_OPEN_ITEM`,
  `DEBIT_OPEN_ITEM_B` y `A51_OL_CLIENTES`.
- `A51_OL_CLIENTES.SQL` requiere revision porque parece contener una funcion.
- `ORA/T3/T3/Tables` no contiene DDL; la fuente Oracle de las 404 tablas MSSQL
  T3 permanece fuera del repositorio.

SQL Server:

- `MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql` contiene tablas `EAI` y tambien tablas `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql` contiene tablas transformadas asociadas a `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Tables/ALTER_MX_EAI_MESSAGE_LOG_ADD_ROW_ID.SQL` agrega `[ROW_ID] BIGINT NOT NULL`, la secuencia `[EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ]`, su valor predeterminado y un indice unico. El script tambien asigna identificadores a los registros existentes.

## Documentos de soporte

| Archivo | Tipo | Uso esperado |
| --- | --- | --- |
| `Docs/AI_CONTEXT.md` | Markdown | Contexto operativo para asistentes IA |
| `Docs/CONVERSION_RULES.md` | Markdown | Reglas y convenciones de conversion Oracle a SQL Server |
| `Docs/DOCUMENTATION_PLAN.md` | Markdown | Plan de documentacion |
| `Docs/INVENTORY.md` | Markdown | Este inventario |
| `Docs/MESSAGE_LOG_ROW_ID.md` | Markdown | Decision tecnica y objetos impactados por la incorporacion de `MX_EAI_MESSAGE_LOG.ROW_ID` |
| `Docs/PACKAGES_MIGRATION.md` | Markdown | Equivalencia y estado de los packages Oracle migrados |
| `Docs/SEQUENCES_MIGRATION.md` | Markdown | Inventario y pendientes de secuencias `EAI_OWNER` |
| `Docs/JOBS_MIGRATION.md` | Markdown | Conversion de 37 `USER_JOBS` a SQL Server Agent |
| `Docs/INDEXES_MIGRATION.md` | Markdown | Inventario, separacion y estado de conversion de indices y PK |
| `Docs/INFO_INDEX.md` | Markdown | Detalle por esquema, nombre, tabla y tipo de indice o restriccion |
| `Docs/PROMPTS.md` | Markdown | Prompts de trabajo |
| `Docs/README.md` | Markdown | Guia principal de la documentacion |
| `Docs/AccesosBDOracle.xlsx` | Excel | Accesos o referencia de bases Oracle |
| `Docs/Control_Migracion_Objetos_MB.xlsx` | Excel | Control de migracion de objetos |
| `Docs/T3MX Objects June 2026.xlsx` | Excel | Inventario externo de objetos T3MX |

## Hallazgos a revisar

- Consolidar o archivar `SF_INCONSISTENCIAS_REVISAR.SQL` para evitar dos scripts que declaran el mismo procedimiento.
- Reubicar `TABLA_Job_Oracle_SQLAgent_Map.SQL` en la carpeta de tablas y validar si el schema `dbo` es intencional.
- Existen archivos `SF_CFDI_NOTA_CREDITO` con y sin extension `.SQL`.
- Los 86 indices y restricciones `EAI` y los 65 de `EAI_OWNER` ya tienen archivo
  homonimo MSSQL. Los tres indices compuestos `DEBIT_OPEN_ITEM_IDX8`,
  `PAGOS_IDX6` y `PAGOS_IDX7` usan `INCLUDE` para respetar el limite de 1,700
  bytes de llave de SQL Server.
- `Procedures.slnx` es un archivo auxiliar de solucion y no un objeto SQL.
- El archivo `A51_OL_CLIENTES.SQL` no parece corresponder a una tabla por su contenido inicial.
- En `LOG_AUDIT_UPDATED`, Oracle filtra tablas log por `ROWID`; la version SQL Server usa `TICKET_REFERENCIA` porque es el identificador disponible en las tablas migradas.
- Hay 22 funciones SQL Server en `MSSQL/T3/EAI_OWNER/Functions` que no tienen archivo homonimo en `ORA/T3/EAI_OWNER/Functions`; validar su origen documental.
- Algunos objetos usan `dbo` en SQL Server aunque su origen esta bajo `EAI`; validar convencion de schema esperada.
- `CURRENCY_TEXT` y `GET_4428_REFERENCE` fueron ajustadas para declararse en el schema `EAI_OWNER`.
- Los 86 procedimientos Oracle `EAI_OWNER` disponibles tienen un archivo homonimo en SQL Server.
- La tabla SQL Server `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` cuenta con una migracion incremental para incorporar `ROW_ID` generado por secuencia; las conversiones que sustituyeron el `ROWID` Oracle por otra estrategia deben reevaluarse despues de aplicar esta migracion.
- Los 37 procedimientos invocados directamente por jobs tienen script MSSQL, pero la habilitacion sigue bloqueada por dependencias internas T3 y por la compatibilidad de `GET_T3_ENABLE_EXECUTE` con los nombres sin prefijo.
- `T3.DELIVERY_CLEAR_Migrado` no satisface la llamada a `T3.DELIVERY_CLEAR`; homologar el nombre antes de ejecutar `PROC_CFDI_LIBERACION_REMISION`.
- Faltan los DDL de `T3.SEQ_CFD`, `T3.SEQ_PAGO_CENTRAL_AGR` y `T3.FACTURA_GENERAL`, ademas de funciones/procedimientos internos detallados en `Docs/JOBS_MIGRATION.md`.

## Conversiones revisadas recientemente

Estos objetos fueron ajustados en `MSSQL/T3/EAI/Procedures` siguiendo la convencion documentada en `Docs/CONVERSION_RULES.md`:

| Objeto | Archivo SQL Server | Observacion |
| --- | --- | --- |
| `SF_BITACORA_CFDI_RESUMEN` | `MSSQL/T3/EAI/Procedures/SF_BITACORA_CFDI_RESUMEN.SQL` | Usa logging con `ProcessID`, `Log_Start`, `RF_PROCESOS_LOG` y errores en `MX_EAI_MESSAGE_LOG`. |
| `SF_BITACORA_CFDI_VENTA_SF` | `MSSQL/T3/EAI/Procedures/SF_BITACORA_CFDI_VENTA_SF.SQL` | Referencias a tablas con schema/corchetes; evita llamar `RF_PROCESOS_LOG` como procedimiento. |
| `SF_CFDI_OPEN_ITEMS` | `MSSQL/T3/EAI/Procedures/SF_CFDI_OPEN_ITEMS.SQL` | Conversion alineada al patron de logging del proyecto. |
| `SF_CFDI_VENTA` | `MSSQL/T3/EAI/Procedures/SF_CFDI_VENTA.SQL` | Conversion set-based para actualizar cobranza y timbrado. |
| `T3R_REPLICA_SALESDOC` | `MSSQL/T3/EAI/Procedures/T3R_REPLICA_SALESDOC.SQL` | Ajustado de `dbo` a `[EAI]`; errores enviados a `MX_EAI_MESSAGE_LOG`. |

Funciones `EAI_OWNER` convertidas recientemente desde `ORA/T3/EAI_OWNER/Functions`:

```text
GET_CLEARING_STATUS
GET_T3_ENABLE_EXECUTE
IC_MOVEMENT_TYPE
LETTER_TO_NUMBER
LINE_ITEM_TEXT
LOG_AUDIT_UPDATED
MX_CENTRO_COBZA
NUMBER_TO_LETTER
PHONE_SINTAXIS
SF_PAYMENT_ALLOC
SPECIAL_CHARS
SPECIAL_CHARS_EDP
SPECIAL_CHARS_NEW
WA_DN_SKU
```

Procedimientos `EAI_OWNER` revisados recientemente contra su fuente Oracle:

```text
SF_JOB_MANAGE
SF_JOB_MANAGE_EOD
SF_PROC_CENTRAL_EXECUTE_NEW
SF_PROC_CENTRAL_INCOBRABLE
SF_PROC_CENTRAL_PAYALLOC
SF_PROC_CENTRAL_PAYMENT_CM
SF_PROC_CUSTOMER
SF_PROC_CUSTOMER_N
SF_PROC_CUSTOMER_O
SF_PROC_PREINVOICE_INTER
SF_PROC_REPLENISHMENT
SF_SAMPLES_GETINFO
WA_ASIGNACION_PAGO
WA_ASIGNA_INCOBRABLE
WA_ASIGNA_NOTACARGO
WA_BAT_PRODUCTORA
WA_DEPURA_MESSAGE_LOG
WA_DIF_IVA_SAP_T3
WA_ERR_CUSTOMER_AMPERSAND
WA_ERR_INTERCOMPANY
WA_RESEND_CFDI
WA_RUN_STATEMENTS
WA_SEARCH_INVOICE_CANCEL
WA_TSEQ_HIST
WA_ZZ_TRASH
```

En el lote de revision actual tambien se ajustaron o revalidaron:

```text
WA_ASIGNACION_PAGO
WA_ASIGNACION_PAGO_INSERT
WA_ASIGNACION_PAGO_RFC
WA_ASIGNA_INCOBRABLE
WA_ERR_INVOICE_AMPERSAND
WA_ERR_PAYMENT_AMPERSAND
WA_ERR_PRODUCT_AMPERSAND
WA_ERR_REPLENISHMENT_LARGE
WA_ERR_REPLENISH_AMPERSAND
WA_ERR_SEQUENCE
WA_ERR_TSEQ
WA_ERR_TSEQ_PRESALES
WA_EXECUTE_ARCHIVING
WA_PURGE_MX_EAI_MESSAGE_LOG
WA_QTY_SAP_BILLING
WA_REP_MASTERDATA
```

La revision realizada es estatica. Estos procedimientos aun requieren pruebas de compilacion y ejecucion en una instancia SQL Server con datos controlados.

Consideraciones funcionales documentadas durante la revision:

| Objeto | Consideracion conservada en SQL Server |
| --- | --- |
| `WA_CIERRE_FLUJOS` | Es un wrapper que llama `EAI_OWNER.Job_Manage('Suspend', 'Todos')`; el `COMMIT` Oracle se representa mediante una transaccion explicita. |
| `WA_ERR_CUSTOMER_AMPERSAND` | Usa `MX_EAI_MESSAGE_LOG.ROW_ID` para identificar la fila origen y conserva un identificador de 32 caracteres independiente para el registro de recepcion. |
| `WA_ERR_INTERCOMPANY` | Solo concatena 39 bloques de 3900 caracteres, aunque Oracle calcula una fase 40 que no utiliza. |
| `WA_RESEND_CFDI` | Conserva duplicados del cursor, la semantica de `LENGTH` y `nIndice = 0`; por ello `pOutput` no imprime documentos. |
| `WA_RUN_STATEMENTS` | Ejecuta SQL dinamico autorizado, captura `@@ROWCOUNT` dentro del lote y confirma cada paso de forma independiente. |
| `WA_SEARCH_INVOICE_CANCEL` | `sSAPInvoice` se conserva en la firma, pero Oracle no lo utiliza. |
| `WA_TSEQ_HIST` | Excluye la fila de encabezado con `Name = 'NAME'` y usa una fecha comun para el lote historico. |

Estas diferencias reproducen el codigo Oracle disponible. Cualquier cambio para corregir comportamientos heredados debe tratarse como una decision funcional separada de la migracion tecnica.

Los procedimientos `WA_ERR_CUSTOMER_AMPERSAND`, `WA_ERR_INTERCOMPANY`, `WA_ERR_INVOICE_AMPERSAND`, `WA_ERR_PAYMENT_AMPERSAND`, `WA_ERR_PRODUCT_AMPERSAND`, `WA_ERR_REPLENISHMENT_LARGE`, `WA_ERR_REPLENISH_AMPERSAND`, `WA_PURGE_MX_EAI_MESSAGE_LOG` y `WA_DEPURA_MESSAGE_LOG` ya materializan `MX_EAI_MESSAGE_LOG.ROW_ID` como llave de la fila origen. Deben desplegarse despues de `ALTER_MX_EAI_MESSAGE_LOG_ADD_ROW_ID.SQL`.

En los procedimientos de purga, primero se congela el conjunto de `ROW_ID` que satisface las relaciones de negocio y despues se ejecuta el `DELETE` exclusivamente por esa llave. `WA_DEPURA_MESSAGE_LOG` aplica este patron en sus ocho bloques sobre `MX_EAI_MESSAGE_LOG`; las depuraciones de `T3.RF_Error_Log` y `T3.Bitacora_Error` no dependen del nuevo campo.

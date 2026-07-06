# Inventario inicial

Este inventario fue generado a partir de la estructura actual del repositorio.

## Conteo por carpeta

`ORA` contiene los fuentes Oracle de los esquemas `EAI` y `EAI_OWNER`. `MSSQL` contiene la transformacion de esos scripts hacia SQL Server.

| Ruta | Cantidad | Observacion |
| --- | ---: | --- |
| `ORA/T3/EAI/Functions` | 9 | Funciones Oracle |
| `ORA/T3/EAI/Procedures` | 32 | Procedimientos Oracle |
| `ORA/T3/EAI/Tables` | 1 | Script consolidado de tablas Oracle |
| `ORA/T3/EAI_OWNER/Tables` | 4 | Tablas Oracle de `EAI_OWNER`, con un archivo a revisar |
| `MSSQL/T3/EAI/Functions` | 9 | Funciones SQL Server |
| `MSSQL/T3/EAI/Procedures` | 32 | Procedimientos SQL Server |
| `MSSQL/T3/EAI/Tablas` | 1 | Script consolidado de tablas SQL Server |
| `MSSQL/T3/EAI_OWNER/Procedures` | 32 | Procedimientos transformados asociados a `EAI_OWNER` |

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

Nota: el conteo de archivos es 32, pero hay 31 nombres distintos porque `SF_CFDI_NOTA_CREDITO` aparece con y sin extension `.SQL`.

## Tablas

Oracle:

- `ORA/T3/EAI/Tables/Tables_Oracle_EAI.sql` contiene el esquema `EAI`.
- `ORA/T3/EAI_OWNER/Tables/ACTUAL_STOCK.sql`.
- `ORA/T3/EAI_OWNER/Tables/CATALOGO_COLONIA_SAT.sql`.
- `ORA/T3/EAI_OWNER/Tables/CAT_OFICIAL_COLONIA.sql`.
- `ORA/T3/EAI_OWNER/Tables/A51_OL_CLIENTES.SQL` requiere revision porque parece contener una funcion.

SQL Server:

- `MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql` contiene tablas `EAI` y tambien tablas `EAI_OWNER`.

## Hallazgos a revisar

- Revisar si `MSSQL/T3/EAI/Procedures` y `MSSQL/T3/EAI_OWNER/Procedures` deben mantenerse como transformaciones separadas o si representan duplicidad funcional.
- Existen archivos `SF_CFDI_NOTA_CREDITO` con y sin extension `.SQL`.
- El archivo `A51_OL_CLIENTES.SQL` no parece corresponder a una tabla por su contenido inicial.
- Algunos objetos usan `dbo` en SQL Server aunque su origen esta bajo `EAI`; validar convencion de schema esperada.

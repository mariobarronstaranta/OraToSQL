> **2026-11-07: lote 17 REGISTRO_FISCAL_DETALLE SUSPENDIDO.** No ejecutar versiones anteriores, ni en vista previa. Revisar [diagnostico posterior al recovery](../17_RFD_REVISION_POST_RECOVERY_20261107/LEEME.md).

# PK T3 por lotes: orden de ejecucion

**Lotes 12-17 reemplazados:** usar los archivos de
[15_CORRECCIONES_LOTES_12_AL_17](../15_CORRECCIONES_LOTES_12_AL_17/README.md),
que manejan los indices dependientes detectados por el diagnostico 14.
Los originales de esta carpeta se conservan solo como historial para esos lotes.

**Correccion del lote 11 PAGO:** usar
[13_CORREGIR_PK_PAGO.sql](../13_CORREGIR_PK_PAGO.sql) en lugar de 11_PAGO.sql.
Resuelve la dependencia PAGO_IDX_1 sobre FECHA_TRN, con rollback completo.
Consultar [la guia](../CORRECCION_PAGO_20261106.md). No es el lote 13_CLIENTE.sql.

**Correccion del lote 10:** usar
[11_CORREGIR_PK_PREVENTA_GENERAL.sql](../11_CORREGIR_PK_PREVENTA_GENERAL.sql)
en lugar de 10_PREVENTA_GENERAL.sql. Resuelve la dependencia INCLUDE de
IX_PG_C005 reportada durante la aplicacion. No es el lote 11_PAGO.sql.
Consultar [la guia](../CORRECCION_PREVENTA_20261106.md).

Basado en el resultado 07 de T3QA del 2026-11-06 00:03:29 -06:00.
65 candidatas: 36 vacias, 18 pequenas y 11 individuales. Las 13 ausentes y
las tres pendientes (CFDI_CATALOGOS_SAT, MOV_CLIENTE, USUARIOS) no se incluyen.
Los tamanos corresponden a la tabla, no suman otros indices; son aproximados.

Cada SQL es autonomo, con el inventario restringido a sus tablas ANTES de
prevalidar datos. No ejecuta 05 ni escanea las otras tablas del inventario.
Conserva los controles, la transaccion por tabla y la reejecucion del 05.
El orden dentro de cada lote respeta el orden del reporte 07.

## Como ejecutar

1. Abrir 01_VACIAS.sql en SSMS conectado a T3QA y ejecutar completo con
   `@Aplicar=0`. Revisar que las nueve tablas esten LISTA o YA_EXISTE_EQUIVALENTE.
2. Cambiar solamente `@Aplicar=1` y ejecutar completo para aplicar ese lote.
   La prevalidacion se repite contra los datos actuales. Guardar el resultado
   03_RESULTADO_APLICACION. Las tablas CREADA o YA_EXISTE_EQUIVALENTE terminaron.
3. Continuar con el siguiente archivo cuando convenga. No ejecutar todos
   juntos ni en paralelo. No es necesario repetir los lotes completados.
4. Ante BLOQUEADA o ERROR_DDL_REVERTIDO, revisar el error; no eliminar indices
   ni datos manualmente. Un error de DDL revierte esa tabla, conserva las
   anteriores y deja las posteriores sin procesar. Se puede reejecutar el lote.
5. Al terminar, ejecutar ../02_VERIFICAR_PK_T3.sql: se esperan 65 equivalentes;
   las tres pendientes y 13 ausentes permanecen fuera del alcance.

Los lotes grandes necesitan su propia ventana sin escritores ni cambios de
esquema. Conservan los escaneos de validacion, el bloqueo exclusivo y el DDL
del 05: dividir archivos no vuelve instantanea ni online una tabla grande.
No se estima duracion ni espacio temporal/log necesario solo con estos MB.
No ejecutar el instalador 05 global ademas de estos lotes.

## Archivos en orden

| Archivo | Tablas | Filas aprox. | MB tabla |
|---|---:|---:|---:|
| [01_VACIAS.sql](01_VACIAS.sql) | 9 | 0 | 0.00 |
| [02_VACIAS.sql](02_VACIAS.sql) | 9 | 0 | 0.00 |
| [03_VACIAS.sql](03_VACIAS.sql) | 9 | 0 | 0.00 |
| [04_VACIAS.sql](04_VACIAS.sql) | 9 | 0 | 0.00 |
| [05_PEQUENAS.sql](05_PEQUENAS.sql) | 9 | 283 | 0.18 |
| [06_PEQUENAS.sql](06_PEQUENAS.sql) | 9 | 13,554 | 1.99 |
| [07_BITACORA_CARGA_T3.sql](07_BITACORA_CARGA_T3.sql) | 1 | 1,073,396 | 72.59 |
| [08_ENTREGA.sql](08_ENTREGA.sql) | 1 | 839,960 | 84.21 |
| [09_W_BUZON_CLIENTE.sql](09_W_BUZON_CLIENTE.sql) | 1 | 2,854,500 | 846.02 |
| [10_PREVENTA_GENERAL.sql](10_PREVENTA_GENERAL.sql) | 1 | 3,880,039 | 944.01 |
| [11_PAGO.sql](11_PAGO.sql) | 1 | 27,966,067 | 2,996.29 |
| [12_ASIGNACION_PAGO.sql](12_ASIGNACION_PAGO.sql) | 1 | 31,397,173 | 3,995.57 |
| [13_CLIENTE.sql](13_CLIENTE.sql) | 1 | 11,600,468 | 6,901.26 |
| [14_FACTURA_GENERAL.sql](14_FACTURA_GENERAL.sql) | 1 | 25,103,302 | 7,014.58 |
| [15_FACTURA_DETALLE.sql](15_FACTURA_DETALLE.sql) | 1 | 91,844,687 | 16,309.73 |
| [16_REGISTRO_FISCAL.sql](16_REGISTRO_FISCAL.sql) | 1 | 154,794,153 | 35,425.71 |
| [17_REGISTRO_FISCAL_DETALLE.sql](17_REGISTRO_FISCAL_DETALLE.sql) | 1 | 489,138,865 | 92,066.51 |

## Detalle por archivo

- **01_VACIAS.sql**: ASIGNA_AGR_T3, ASIGNA_T3, BITACORA_EDI, BITACORA_PROCESO, CADENA_CLIENTE, CADENAS_SAP_PASO, CARTERA_T3, CC_PANTALLA, CLASE_CLIENTE.

- **02_VACIAS.sql**: COMPRA_T3, CREDITO_EXPRESS, DEVCOMPRA_T3, ENTREGA_T3, FACT_T3, FACTD_AGR_T3, FACTD_T3, IFC_FORMATOS, MONITOR_CHART_CATALOG.

- **03_VACIAS.sql**: MOV_CLIENTE_TERR, NOTA_AGR_T3, NOTA_POR_APLICAR, NOTA_T3, NOTAD_AGR_T3, NOTAD_T3, PAGO_T3, PEDD_T3, REGISTRO_FISCAL_DETALLE_HIST.

- **04_VACIAS.sql**: REGISTRO_FISCAL_HIST, W_IMPRIME_DOCUMENTO, W_MATERIAL_MAQUILA, W_MOV_CENTRAL_ADC, W_REGISTRO_FISCAL_DETALLE2, W_REGISTRO_FISCAL2, WH_PEDIDO_DETALLE, WH_REGISTRO_FISCAL, WH_REGISTRO_FISCAL_DETALLE.

- **05_PEQUENAS.sql**: CONFIG_EMPRESA, IFC_CONFIG, W_REGISTRO_FISCAL, W_REGISTRO_FISCAL_DETALLE, ESTADO_FISCAL, TIPO_DOCUMENTO, REPC_FAMILIA, PASO_MATERIALES_FAM, REPC_CLIENTE_VENTA_HIST.

- **06_PEQUENAS.sql**: IMPRESORAS, VENTA_PLANEADA, CADENA_UPC, REPC_MATERIAL_FAMILIA, REPC_CLIENTE_VENTA, PASO_MATERIALES, DISTRIBUIDOR_FISCAL, IFC_FORMATO_HIST, MATERIAL.

- **07_BITACORA_CARGA_T3.sql**: BITACORA_CARGA_T3.

- **08_ENTREGA.sql**: ENTREGA.

- **09_W_BUZON_CLIENTE.sql**: W_BUZON_CLIENTE.

- **10_PREVENTA_GENERAL.sql**: PREVENTA_GENERAL.

- **11_PAGO.sql**: PAGO.

- **12_ASIGNACION_PAGO.sql**: ASIGNACION_PAGO.

- **13_CLIENTE.sql**: CLIENTE.

- **14_FACTURA_GENERAL.sql**: FACTURA_GENERAL.

- **15_FACTURA_DETALLE.sql**: FACTURA_DETALLE.

- **16_REGISTRO_FISCAL.sql**: REGISTRO_FISCAL.

- **17_REGISTRO_FISCAL_DETALLE.sql**: REGISTRO_FISCAL_DETALLE.

Generador: ../generar_lotes_08.py. inventario_07.json conserva el orden y volumen recibido; manifest.json registra cobertura y huellas. No se aplicaron cambios en T3QA desde esta sesion.

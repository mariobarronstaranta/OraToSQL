# Revisión de procedures EAI_OWNER

Fecha de revisión: 2026-07-22

Origen: `ORA/T3/EAI_OWNER/Procedures`

Destino: `MSSQL/T3/EAI_OWNER/Procedures`

## Resultado

| Procedure | Resultado | Observaciones principales |
|---|---|---|
| `DEBITNOTE_TO_IFC` | Validado | Se conserva la carga de notas de débito y se normaliza el instalador con `CREATE OR ALTER`. |
| `EXECUTE_TRUNCATE` | Corregido | Nombre sin esquema resuelto como `EAI_OWNER`; se mantiene lista blanca, identificadores delimitados y registro de errores. |
| `INVOICE_FIX_TAX` | Corregido | Las divisiones inválidas ya no se convierten silenciosamente en `NULL`; se conserva el recálculo de encabezado. |
| `INVOICE_TO_ENTREGA` | Corregido | Esquema de función, bandera de proceso, trazas y decisión INSERT/UPDATE de folios alineados con Oracle. |
| `INVOICE_TO_ENTREGA_PO` | Corregido | La operación de folio vuelve a depender de `CreadoPor`, incluyendo el caso `NULL` de Oracle. |
| `INVOICE_TO_FACTURA` | Corregido | Parámetro OUT, fechas, material numérico, UOM, precio unitario, funciones por esquema y totales sin detalles alineados. |
| `INVOICE_TO_OTROS` | Corregido | Se restauró CCE, conversión de país, reinicio de bandera, precio unitario y límites de commit/error de Oracle. |
| `INVOICE_TO_OTROS_PARTNERS` | Corregido | La combinación especial activa la actualización de todos los partners de la referencia, como en Oracle. |
| `INVOICE_TO_OTROS_RETENTION` | Corregido | Configuración leída desde `EAI_OWNER.GETCONV`; el encabezado sólo cambia cuando hubo detalles con retención. |
| `INVOICE_TO_OTROS_V33` | Validado sin cambios | Las tres prioridades de asignación SAT conservan el orden funcional del procedimiento Oracle. |

## Contratos preservados

- Cada procedure modificado incluye un encabezado funcional y comentarios junto
  a las reglas de negocio, operaciones destructivas y decisiones de integridad,
  redactados para facilitar el mantenimiento por developers Jr.
- Los identificadores de factura mantienen la longitud declarada por Oracle cuando aplica.
- `INVOICE_TO_FACTURA` inicializa el folio fiscal de salida en `NULL`, igual que un parámetro `OUT` de Oracle.
- Las conversiones de fecha, número y tasas inválidas producen un error registrable; no generan datos parciales con valores inventados.
- Los bloques de error escriben en `EAI_OWNER.MX_EAI_MESSAGE_LOG` y no propagan la excepción cuando Oracle tampoco lo hace.
- Las referencias a funciones usan su esquema real: `EAI`, `EAI_OWNER`.

## Validación técnica

Los diez archivos fueron procesados con `SET PARSEONLY ON` en SQL Server LocalDB. Resultado: sintaxis válida para todos los scripts.

La prueba fue sintáctica. Antes de producción se recomienda ejecutar casos funcionales en una base integrada con catálogos y datos equivalentes, comparando tablas destino y parámetros de salida contra Oracle.

## Revisión adicional: pagos, consultas y purgas

Fecha de revisión: 2026-07-22

| Procedure | Resultado | Observaciones principales |
|---|---|---|
| `PROC_REPLENISHMENT_SUBDEPOT` | Corregido | Se instalaba en `dbo`; ahora pertenece a `EAI_OWNER` y conserva la validación del catálogo de impresión. |
| `PURGE_ACCOUNT_HEADER` | Corregido | Secuencia corregida a `EAI_OWNER`; validación de fechas/intervalo y transacción independiente por ventana. |
| `PURGE_TEMPORAL_SAP` | Corregido | Periodo validado antes del borrado y eliminación atómica de hijos/encabezado. |
| `SF_GET_CREDIT_DATA` | Corregido | Función fiscal con esquema correcto, protección contra referencias truncadas y salidas definidas. |
| `SF_GET_CUSTOMER_DATA` | Corregido | Conversión de centro mediante `EAI.CONV_PLANT_TO_DIST` y validación del identificador SAP. |
| `SF_GET_INVOICE_DATA` | Corregido | Protección de entradas y restauración de trazas de la regla de importe SAT. |
| `SF_GET_REP_DATA` | Corregido | Protección de referencia y conservación de salidas inicializadas ante error. |
| `SF_PROC_CENTRAL_PAYMENT` | Corregido | Instalador idempotente, conversiones monetarias estrictas, rollback de la unidad temporal y error no propagado. |
| `SF_PROC_CENTRAL_PAYMENT_ZV` | Corregido | Pago/asignación atómicos, ID de integración compatible con Oracle, limpieza de cursor y validación de IDoc. |
| `SF_PROC_CUSTOMER_MAIL` | Corregido | Parámetros recibidos sin truncamiento previo, validación contra tamaños destino y prevención lógica de duplicados. |

Los diez archivos considerados en esta revisión pasaron validación con `SET PARSEONLY ON` en SQL Server LocalDB. `SF_INCONSISTENCIAS_REVISAR.SQL` fue excluido del alcance y permanece sin modificaciones.

## Revisión adicional: preinvoice y workarounds contables

Fecha de revisión: 2026-07-22

| Procedure | Resultado | Observaciones principales |
|---|---|---|
| `SF_PROC_PREINVOICE_IFC` | Corregido | Conversiones numéricas estrictas, liberación segura de cursores anidados, rollback integral y manejo de error compatible con Oracle. |
| `SF_PROC_PRODUCT` | Corregido | Se implementaron las reglas faltantes de UMV, Merchandise, ProductLine y códigos `99`; se protegió el material contra conversiones silenciosas. |
| `SF_WA_PROC_REPLENISHMENT` | Corregido | Instalador idempotente y liberación del cursor ante error. |
| `WA_ACCNT_COMPLEMENT` | Corregido | Función `GET_4428_REFERENCE` con esquema real, actualización atómica y bitácora equivalente. |
| `WA_ACCNT_PAYAMOUNT` | Corregido | Factura y nota comparten el mismo conjunto elegible; se restauraron filtros de estado, fecha, reversa y referencia. |
| `WA_ACCNT_PAYAMOUNT_CM` | Corregido | Conteo único de asignaciones por clearing document y función de sufijo bajo `EAI_OWNER`. |
| `WA_ACCNT_REFOLEO` | Corregido | Se eliminó la dependencia inexistente `T3.FN_CFDI_REFOLEO`; el mapeo se obtiene de `T3.CFDI_REFOLEO` con auditoría transaccional. |
| `WA_CHECK_PAYNULL` | Corregido | Conversión de método con esquema correcto y comparación contra el método fuente, como en Oracle. |
| `WA_FOLIO_FACTURA` | Corregido | Validación de folio/centro y conservación de bloqueos para evitar folios duplicados. |

Los nueve archivos pasaron validación sintáctica con `SET PARSEONLY ON` en SQL Server LocalDB. Todos los scripts modificados contienen comentarios funcionales y de integridad destinados a facilitar su mantenimiento.

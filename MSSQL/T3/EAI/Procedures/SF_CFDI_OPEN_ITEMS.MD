# Comparacion Oracle: SF_CFDI_OPEN_ITEMS (2026-10-08)

## Dictamen actual

**No hay equivalencia completa.** Se hicieron tres pasadas: reglas por etapa,
nulos/cardinalidad y contrato de ejecucion. Esta revision solo agrega comentarios
al procedimiento: se verifico que su SQL ejecutable permanezca identico.
No se desplego ni ejecuto en produccion.

Se compararon los archivos `.SQL` de ORA y MSSQL. El archivo principal MSSQL
declara `EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO`, pero el job 849 llama
`EAI.SF_CFDI_OPEN_ITEMS`. Ejecutar ese archivo no actualiza el objeto del job.

## Diferencias reproducidas

| Caso | MSSQL actual | Oracle |
|---|---|---|
| D01 Nombre desplegado | Sufijo _OPTIMIZADO | Nombre sin sufijo |
| D02 RFC/centro final | Agrupa por Nota_Venta y mezcla clientes del mismo folio | Agrega por Cliente_SAP de cada fila |
| D03 Cliente inexistente | Conserva centro anterior | Agregado escalar pone RFC/centro NULL |
| D04 RF inexistente | Conserva PedidoSAP/FacturaSAP anteriores | Subconsulta escalar pone ambas NULL |
| D05 Importe_Vta NULL en devolucion | ISNULL lo convierte a cero antes del ajuste | NULL + ajuste sigue NULL |
| D06 Devolucion sin cobranza | INNER JOIN omite la actualizacion | Agregado sin GROUP BY limpia aplicaciones a NULL |
| D07 P2 devolucion sin cobranza | Cuenta cero actualizadas | Cuenta una vuelta del cursor |
| D08 Venta con importes NULL | Importe/efectivo terminan en cero | SUM conserva NULL cuando no hay valores no nulos |
| D09 P2 ventas sin cobranza | Cuenta solo actualizadas | Cuenta todas las filas del cursor, aun sin cobranza |
| D10 Dos filas abiertas de un folio | DISTINCT elimina multiplicador: 116 por fila | JOIN al reporte duplica detalle: 232 por fila |
| D11 P3 en ese caso | Cuenta dos destinos | Cuenta un grupo fiscal |
| D12 Varias RF por folio en Final | UPDATE FROM selecciona una coincidencia | Subconsulta escalar lanza error |
| D13 Historico existente, Last_Updated NULL | NOT EXISTS lo excluye | LEFT JOIN y prueba de marca nula permiten insertarlo |
| D14 Factura NULL en Otros_General | NOT EXISTS permite referencias no coincidentes | NOT IN elimina candidatas por logica de NULL |
| D15 Fecha SAP invalida | TRY_CONVERT inserta fecha NULL | TO_DATE falla |

No todas deben corregirse ciegamente: NOT IN con NULL y multiplicacion por
duplicados pueden ser defectos heredados. Cambiarlos requiere reconocer que se
modifica el comportamiento Oracle, no afirmar que son optimizaciones equivalentes.

## Otras diferencias y limites de la revision estatica

- En etapas 20/30/80 Oracle selecciona Vta/Dev pero actualiza por Nota_Venta,
  incluyendo otras filas del mismo folio. MSSQL tambien filtra el tipo destino.
- Etapas 20/60/70/80/90: varias coincidencias con valores distintos dejan
  resultados ambiguos. El cursor Oracle sobrescribe sin orden total; UPDATE FROM
  no garantiza elegir la misma fuente. No asumir prioridad del UNION ALL de 90.
- P2/P3 cuentan cursores en Oracle y destinos actualizados en SQL: relaciones
  multiples tambien afectan auditoria en etapas 60/70/80/90.
- UUID vacio es NULL en Oracle; SQL comprueba solo IS NULL. Otras comparaciones
  de cadenas tambien dependen del cotejamiento y de la normalizacion de carga.
- Historicos usan las funciones externas FN_Cobza_Pay/FN_COBZA_CM_UUID: no se
  encontro su codigo en el repositorio. No se certifica equivalencia interna.
  Oracle asigna su resultado a NUMBER(16,2); verificar tipo/escala desplegados.
- Oracle usa sFactura VARCHAR2(20); el reporte SQL admite 30 caracteres. Revisar
  folios largos. Etapa Oracle es NUMBER y SQL INT; se revisaron etapas enteras.
- Final siempre se ejecuta, incluso etapa 100, y suma nuevamente ajuste fiscal
  a Dev: no es idempotente, comportamiento presente en ambas versiones.
- MSSQL no abre transaccion propia. XACT_ABORT ON no hace atomico el proceso.
  Oracle usa COMMIT por lotes y absorbe errores; MSSQL usa autocommit y THROW.
  Con transaccion externa condenada, el INSERT del CATCH puede ocultar el error.

## Reglas confirmadas en la lectura

Etapas acumulativas 0/10/20/30/60/70/80/90/Final; NULL equivale a cero;
refoleo DOI; clasificacion C003/C005 como Vta y C004/C006/C019/C025 como Dev;
fallback por signo de saldo y ABS condicionado; historicos desde 2023, cliente
vigente, preventas procesadas no canceladas y tolerancia estricta >0.05;
suma de subtotal/IVA/envio/credito; vias 01,02/03,CM,AI; nota de debito posterior
al importe fiscal; historia PAC y fallback de folio en creditos.

ScrCobza de ventas SI tiene GROUP BY: venta sin cobranza conserva valores.
ScrCreditMemo de devoluciones NO tiene GROUP BY: sin cobranza debe limpiar NULL.
Timbrado es suma de tres indicadores (0..3): importe 10 con tres UUID aporta 30,
no 10. Los JOIN fiscales pueden multiplicar filas y Oracle tambien lo hace.

## Evidencia local

`tests/SF_CFDI_OPEN_ITEMS/Run.ps1` crea/elimina una base LocalDB aleatoria.
Usa DDL del repositorio, LOG_START y FN_GET_TAX_ISSUE reales del repositorio;
las dos funciones de cobranza externas se simulan devolviendo cero.
Se compilo el procedimiento completo bajo el nombre que declara el archivo.
`Differences.sql` reprodujo D01..D15 y comprobo dos reglas conservadas (R01/R02).
Un diagnostico exitoso significa que la diferencia fue reproducida, NO que
el procedimiento cumple Oracle. No se ejecuto el motor Oracle ni una prueba
de rendimiento; los esperados se derivaron de la lectura del PL/SQL.

## Antecedentes previos (no acreditan equivalencia Oracle)

El texto siguiente describe una comparacion anterior entre versiones MSSQL.
Sus afirmaciones de reglas preservadas quedan limitadas por los hallazgos de
esta revision. Comparar dos versiones MSSQL con el mismo defecto no valida Oracle.

### EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO

## Objetivo

El procedimiento construye `EAI.CFDI_OPEN_ITEMS` con la cartera SAP, incorpora documentos históricos pendientes y enriquece cada documento con cobranza, UUID, información fiscal, cliente facturado y referencias SAP.

La versión original permanece sin cambios. El nuevo archivo es `SF_CFDI_OPEN_ITEMS_OPTIMIZADO.SQL`.

## Etapas conservadas

- Etapa `0`: reemplaza la tabla de trabajo con la cartera SAP actual.
- Etapa `10`: incorpora facturas y notas históricas que aún tienen diferencia pendiente.
- Etapa `20`: calcula cobranza de ventas por vía de pago y condición de timbrado.
- Etapa `30`: calcula aplicaciones e incobrables de notas de crédito.
- Etapa `60`: obtiene importe fiscal y datos de notas de débito.
- Etapa `70`: relaciona la nota operativa con su documento CFDI.
- Etapa `80`: calcula el importe aplicado de notas de crédito con UUID.
- Etapa `90`: sustituye el cliente SAP cuando el cliente facturado es distinto.
- Etapa final: completa RFC/centro, diferencia fiscal, pedido y entrega SAP.

`@nEtapa` conserva la semántica acumulativa del original: una etapa se ejecuta cuando `ISNULL(@nEtapa,0)` es menor o igual al número correspondiente. Las operaciones finales siempre se ejecutan.

## Cambios de rendimiento

### Agregaciones limitadas a documentos abiertos

Las etapas de ventas, devoluciones e importe fiscal ya no agregan primero todas las filas históricas de `CFDI_Cobranza` o `Registro_Fiscal`. Se crea un conjunto distinto de notas abiertas y se une al inicio de cada agregación.

Beneficio: reduce filas leídas, memoria de agregación y trabajo de hash/sort cuando las tablas históricas son mucho mayores que el conjunto abierto.

### Eliminación de auto-joins redundantes

Las etapas de nota de débito, relación CFDI, UUID de créditos y cliente facturado ya tienen `CFDI_OPEN_ITEMS` como tabla objetivo. Se eliminaron subconsultas que volvían a unir esa misma tabla para devolver nuevamente `Nota_Venta`.

Beneficio: evita escaneos adicionales de la tabla de trabajo y simplifica los planes de ejecución.

### Función fiscal conservada por compatibilidad

Se evaluó sustituir `EAI_OWNER.FN_GET_TAX_ISSUE` por una consulta relacional. No se realizó el cambio porque `T3.NDC_ISSUE_IVA` no tiene una llave única y el proceso que la alimenta puede producir más de una fila por factura. Una selección relacional podría devolver una diferencia distinta de la elegida actualmente por la función.

Decisión: se conserva la función para no cambiar resultados ante datos duplicados. Como mejora futura, primero debe definirse una regla determinista —por ejemplo, la fila con mayor `Fecha_Update`— y aplicarla tanto al procedimiento como a la función.

### Anti-join explícito para históricos

La comprobación de documentos ya existentes usa `NOT EXISTS` en lugar de `LEFT JOIN ... IS NULL`.

Beneficio: expresa directamente que solo interesa la ausencia de coincidencia y permite un semi-join sobre `CFDI_OPEN_ITEMS_IX (Nota_Venta)`.

## Reglas de negocio preservadas

- Se conserva el refoleo `DOI` antes de agrupar la cartera SAP.
- Los documentos de `T3.Otros_General` no se incorporan.
- Las clases `C003` y `C005` se tratan como venta; `C004`, `C006`, `C019` y `C025` como devolución.
- La tolerancia para incorporar históricos sigue siendo mayor a `0.05`.
- Se conservan las funciones `T3.FN_Cobza_Pay` y `T3.FN_COBZA_CM_UUID`; sus implementaciones no están disponibles en este repositorio.
- Las vías `01`, `02`/`03`, `CM` y `AI` mantienen su clasificación en efectivo, agrupado, nota de crédito e incobrable.
- El indicador de timbrado sigue sumando los CFDI de pago, agrupación y nota.
- El importe fiscal conserva subtotal, IVA, envío y crédito.
- La nota de débito mantiene precedencia sobre el importe obtenido de Registro Fiscal.
- Los errores continúan registrándose y relanzándose, como en el procedimiento MSSQL original.

## Comparación con Oracle

Se revisó `ORA/T3/EAI/Procedures/SF_CFDI_OPEN_ITEMS.SQL`. Los cursores Oracle ya habían sido convertidos a operaciones set-based en el procedimiento MSSQL original; esta versión conserva ese resultado funcional y reduce los universos consultados.

Se mantiene la diferencia ya existente en MSSQL: el procedimiento registra el error y usa `THROW`, mientras Oracle registra y termina sin propagar la excepción. No se cambió este contrato para no alterar el comportamiento actual del job SQL Server.

## Dependencias

- Secuencia y logging: `EAI_OWNER.ProcessID`, `EAI_OWNER.Log_Start`, `EAI_OWNER.MX_COMPONENTS`, `EAI_OWNER.MX_EAI_MESSAGE_LOG` y `T3.RF_PROCESOS_LOG`.
- Trabajo: `EAI.CFDI_OPEN_ITEMS` y `EAI.T3R_Cartera_SAP_OLD`.
- Ventas: `T3.Factura_General`, `T3.Factura_Detalle`, `T3.Preventa_General`, `T3.Preventa_Detalle` y `T3.Cliente`.
- Cobranza: `T3.CFDI_Cobranza`, `T3.CFDI_Agrupacion_Pago`, `T3.CFDI_Agrupacion_Ctrl` y `T3.CFDI_Documentos`.
- Fiscal: `T3.Registro_Fiscal`, `T3.Registro_Fiscal_Detalle`, `T3.CFDI_Historia_Docto_PAC`, `T3.Mov_Cliente`, `T3.DEBIT_NOTE_IFC` y `T3.NDC_ISSUE_IVA`.
- Conversión: `T3.CFDI_Refoleo` y `T3.Otros_General`.
- Funciones externas conservadas: `T3.FN_Cobza_Pay`, `T3.FN_COBZA_CM_UUID` y `EAI_OWNER.FN_GET_TAX_ISSUE`.

## Caller identificado

El job `ORA_849_EAI_SF_CFDI_OPEN_ITEMS` se crea en `MSSQL/T3/EAI_OWNER/Jobs/01_CREATE_OR_UPDATE_JOBS.SQL` y actualmente ejecuta:

```sql
EXEC [EAI].[SF_CFDI_OPEN_ITEMS] 0;
```

El job no se modifica automáticamente. Después de validar en QA, su comando podrá apuntar a `EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO`.

## Validación técnica realizada

La versión fue compilada y ejecutada en una base LocalDB temporal. Se compararon las 26 columnas funcionales de `CFDI_OPEN_ITEMS`, omitiendo únicamente `Last_Updated`, PID y tiempos de bitácora.

El conjunto controlado cubrió:

- cartera SAP positiva y negativa;
- refoleo y exclusión mediante `Otros_General`;
- factura y preventa históricas;
- vías de pago `01`, `02`, `CM` y `AI`;
- CFDI directo, agrupado y mediante historia PAC;
- importe fiscal, nota de débito y cliente facturado distinto;
- ajuste fiscal presente y ausente;
- ejecución independiente del bloque final con `@nEtapa = 100`.

Original y optimizado produjeron las mismas seis filas y los mismos valores funcionales.

### Rendimiento sintético observado

| Escenario | Original | Optimizado | Resultado |
|---|---:|---:|---|
| Flujo completo con 8,000 filas históricas ajenas | 348 ms | 125 ms | 64.1 % menos tiempo. |
| Mismo escenario, ejecutando primero el optimizado | 33 ms | 7 ms | 78.8 % menos tiempo con caché caliente. |
| Carga pequeña, 30 ejecuciones completas | 526 ms | 498 ms | 5.3 % menos tiempo; no se observó regresión. |

Las funciones de cobranza se simularon para aislar el costo del procedimiento. Los tiempos no sustituyen una prueba en QA: el volumen, los índices, la caché, la concurrencia y la implementación real de las funciones pueden cambiar el resultado.

## Validación recomendada

Comparar original y optimizado sobre copias idénticas, normalizando únicamente `Last_Updated`, PID y tiempos de log. Deben cubrirse:

1. Cartera SAP con y sin refoleo.
2. Documento excluido por `Otros_General`.
3. Venta y devolución inferidas por clase y por signo.
4. Histórico ya existente y no existente.
5. Diferencia histórica menor, igual y mayor a `0.05`.
6. Cada vía de pago y combinaciones de CFDI timbrados.
7. Nota de crédito aplicada e incobrable.
8. Registro fiscal y nota de débito para la misma nota.
9. CFDI directo y mediante historia PAC.
10. Cliente facturado distinto.
11. Ajuste de `NDC_ISSUE_IVA` presente y ausente.
12. Ejecuciones por etapas `0`, `20`, `60`, `70`, `80`, `90` y superior a `90`.

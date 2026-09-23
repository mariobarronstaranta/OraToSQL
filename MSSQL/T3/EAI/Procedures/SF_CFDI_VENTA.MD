# EAI.SF_CFDI_VENTA_OPTIMIZADO

## Objetivo

Construye `EAI.CFDI_UUID_VENTA` desde la bitacora de ventas y agrega la
clasificacion de cobranza, timbrado y metodo de pago. El original permanece
disponible para comparacion y rollback.

## Optimizaciones principales

- La cartera SAP se agrega solamente para notas presentes en el reporte; el
  original agregaba toda `T3R_Cartera_SAP_OLD`.
- Se crea una lista unica de notas para limitar las lecturas de cobranza.
- `CFDI_Documentos` se resume una sola vez por nota y se reutiliza para pago,
  agrupacion, nota de credito y metodo de pago.
- La lectura de `CFDI_Documentos` se limita a los folios realmente utilizados
  por las ventas y cobranzas incluidas en el reporte.
- Las agrupaciones timbradas se reducen a una fila por asignacion, evitando
  multiplicar importes por documentos duplicados.
- Se eliminan los cursores anidados de Oracle y se mantienen operaciones
  set-based.
- Los calculos de clasificacion se realizan una sola vez en `CobranzaBase` y se
  agregan una vez por factura.

## Reglas de negocio conservadas

- Solo se incluyen filas `Tipo_Vta='Vta'`.
- Se excluye el RFC generico `XAXX010101000`.
- `Importe_Vta` incluye subtotal, IVA, envio y credito.
- `Saldo_SAP` suma todas las partidas por referencia.
- Via `01` es efectivo, `02/03` agrupado, `CM` nota de credito y `AI`
  incobrable.
- El indicador de timbrado suma los comprobantes de pago directo, agrupado y
  nota de credito, igual que Oracle.
- `@nEtapa` conserva el mismo flujo 0/10 y trata NULL como cero.

## Correccion de auditoria

Oracle incrementa `Proceso_1` por cada venta recorrida, tenga o no cobranza. El
MSSQL original guardaba solamente el numero de filas actualizadas. La version
optimizada restaura el significado Oracle del contador.

## Caller identificado

El job `ORA_829_EAI_SF_CFDI_VENTA` ejecuta actualmente:

```sql
EXEC [EAI].[SF_CFDI_VENTA] 0;
```

El job no se modifica automaticamente. Debe apuntarse a `_OPTIMIZADO` solo
despues de las pruebas de aceptacion en QA.

## Dependencias

- EAI: `CFDI_UUID_VENTA`, `CFDI_BITACORA`, `T3R_Cartera_SAP_OLD`.
- EAI_OWNER: `ProcessID`, `Log_Start`, `MX_COMPONENTS`,
  `MX_EAI_MESSAGE_LOG`.
- T3: `CFDI_Cobranza`, `CFDI_Documentos`, `CFDI_Agrupacion_Pago` y
  `RF_PROCESOS_LOG`.

## Pruebas recomendadas en QA

1. Venta con y sin saldo SAP.
2. RFC real, RFC generico y RFC NULL.
3. Cobranza por cada via de pago.
4. Pago sin UUID y con UUID directo, agrupado y nota de credito.
5. Venta sin movimientos de cobranza.
6. Datos duplicados en `CFDI_Documentos` y `CFDI_Agrupacion_Pago`.
7. Ejecuciones con etapas 0, 10, mayor a 10 y NULL.
8. Comparar `STATISTICS IO`, `STATISTICS TIME` y planes reales.

## Validacion tecnica realizada

Se compilaron y ejecutaron el original y el optimizado en una base LocalDB
temporal. Todas las columnas coincidieron para ventas con y sin saldo SAP,
RFC real y generico, cobranza por las cuatro vias de pago, UUID directo,
agrupado y de nota de credito, metodo de pago y venta sin cobranza.

Tambien se agrego deliberadamente un CFDI duplicado y se comprobo que la
version optimizada no multiplica los importes. El contador `Proceso_1` coincide
con la regla Oracle. Esta prueba valida logica y compilacion; el beneficio de
performance debe confirmarse con volumen, `STATISTICS IO/TIME` y planes reales
en QA.

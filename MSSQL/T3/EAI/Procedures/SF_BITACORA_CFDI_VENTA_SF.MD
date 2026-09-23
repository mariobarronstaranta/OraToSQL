# EAI.SF_BITACORA_CFDI_VENTA_SF_OPTIMIZADO

## Objetivo

Concilia ventas, devoluciones y notas de credito de Salesforce contra
`EAI.CFDI_BITACORA`, completa datos SAP/CFDI y ejecuta correcciones de cambio de
mes. El procedure original permanece disponible para comparacion y rollback.

## Optimizaciones principales

- `FC__TIME_WINDOW` se consulta una sola vez, no una vez por cada fuente SF.
- Cada fecha textual de Salesforce se convierte una sola vez con `CROSS APPLY`.
- Los filtros mensuales usan rangos de fechas, evitando
  `CONVERT(CHAR(6), Invc_dt)` sobre cada fila.
- Los movimientos Salesforce se materializan en una tabla temporal indexada.
- Se elimino el `LEFT JOIN` a toda la bitacora usado para generar el texto
  `INSERT`; ahora la existencia se comprueba con `EXISTS/NOT EXISTS`.
- `Mov_Cliente` se reduce a una fila por cliente para evitar multiplicaciones.
- El filtro de 35 dias usa comparacion directa de fechas en vez de `DATEDIFF`.
- Los importes y factores del bloque de preventas canceladas se calculan una
  sola vez mediante `CROSS APPLY`.

## Reglas conservadas de Oracle

- Se excluyen facturas Salesforce canceladas, invalidas o incluidas en
  `Doctos_Cancelled`.
- No se importa el dia actual y se consideran 45 dias antes de la ventana.
- `Unsuccessful-X` se cuenta, pero no actualiza `SF_Amount`.
- Documentos nuevos se insertan con territorio `0000`.
- SAP actualiza `SAP_Amount` y `Factura_SAP` solo para estado `C`.
- Notas `DESC%` y `CONECT%` conservan su tratamiento especial.
- Se completa `CFDI_INFORME` cuando falta el folio fiscal.
- En cierre de mes se reconstruyen importes, se corrigen fechas y se recuperan
  preventas canceladas C005/C006.
- Los documentos `CHP%` se eliminan al final.
- Se conservan proceso 826, contadores y bitacora de errores.

## Parametros

- `@nEtapa`: conservado por compatibilidad. No controla bloques en Oracle ni en
  la version MSSQL original.
- `@sPeriod`: periodo opcional `YYYYMM`. Si esta vacio, los dias 1 y 2 se toma
  automaticamente el mes correspondiente a tres dias antes.

La version optimizada valida el periodo antes de modificar datos. Un valor con
formato invalido genera un error controlado.

## Caller identificado

No se encontro una llamada SQL directa ni un job en los scripts del repositorio.
El componente `826` de `MX_COMPONENTS` identifica el proceso como
`CFDI Detailed - Salesforce Sale`. La invocacion puede provenir de una
aplicacion o de una orquestacion externa que no esta incluida en el proyecto.

## Dependencias principales

- EAI: `CFDI_BITACORA`, `CFDI_INFORME`, `FC__TIME_WINDOW`,
  `T3R_Sales_Docs_Old`.
- EAI_OWNER: `Facturas_B`, `SR_Invoice`, `Credit_Notes`, `Doctos_Cancelled`,
  `ProcessID`, `Log_Start`, `MX_COMPONENTS`, `MX_EAI_MESSAGE_LOG`.
- T3: `Mov_Cliente`, `Preventa_General`, `Factura_General`,
  `CFDI_Documentos`, `RF_PROCESOS_LOG` y `FN_TOTAL_FACT`.

## Pruebas recomendadas en QA

1. Factura nueva, existente, cancelada, invalida y `Unsuccessful-X`.
2. Devolucion `SR_Invoice` y notas `DESC%`/`CONECT%`.
3. Documento SAP estado `C` y otros estados.
4. CFDI con folio faltante en `CFDI_INFORME`.
5. Ejecucion normal y ejecucion de cierre con `YYYYMM`.
6. Preventa C005/C006 cancelada que no exista en bitacora.
7. Eliminacion final de documentos `CHP%`.
8. Comparacion de resultados, `STATISTICS IO/TIME` y planes reales.

## Validacion tecnica realizada

Se compilaron y ejecutaron el original y el optimizado en una base LocalDB
temporal. Se compararon los resultados de `CFDI_BITACORA` y `CFDI_INFORME` para
factura existente, `Unsuccessful-X`, devolucion, CreditMemo, documento SAP,
complemento CFDI, reconstruccion mensual, preventa cancelada y limpieza CHP.
Los resultados funcionales coincidieron.

Tambien se comprobaron los contadores de auditoria y el rechazo de un periodo
invalido antes de modificar la bitacora. El escenario es adecuado para validar
logica y compilacion, pero no sustituye una medicion de performance con volumen
y planes de ejecucion reales en QA.

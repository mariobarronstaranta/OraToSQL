# EAI.CCEA_DATA_SALE_OPTIMIZADO

## Objetivo

Reconstruye `EAI.CC_DATA_SALE` para Cifras Control usando información de T3,
PAC y documentos SAP que aún no tienen origen T3.

## Optimizaciones principales

- La ventana se lee y convierte una sola vez.
- Los filtros sobre `CFDI_BITACORA.Invc_dt` usan rangos de fecha y permiten
  aprovechar índices; se eliminó `CAST(Invc_dt AS DATE)` por fila.
- `CFDI_INFORME` se consolida una sola vez por folio para evitar duplicados.
- `Preventa_General` se consulta con `EXISTS` porque únicamente determina si el
  documento es `Presales`; además se conserva la condición Oracle que exige
  una `Entrega` no nula.
- La segunda carga usa `NOT EXISTS` sobre factura y preventa en lugar de dos
  `LEFT JOIN`, evitando multiplicar documentos SAP.
- La fecha SAP se convierte una sola vez mediante `CROSS APPLY`.
- El importe operativo se calcula una sola vez y se reutiliza en tres columnas.

## Correcciones de compatibilidad con Oracle

- Se restauró la exclusión de documentos `CONEC%`, ausente en MSSQL.
- `Credito_Subt` y `Credito_IVA` NULL se consideran cero, como `NVL` en Oracle;
  el MSSQL original podía convertir todo el importe en NULL.
- `PAC_FISCAL_UUID` se guarda sin espacios laterales, igual que `TRIM` de Oracle.
- Una ventana inválida se rechaza antes de ejecutar `TRUNCATE`.

## Reglas conservadas

- La tabla destino se reconstruye completamente.
- Se incluyen fechas desde la ventana, nunca anteriores al 21/09/2020, y se
  excluye el día actual.
- Individual timbrado usa importes PAC; agrupado `G-` usa importe T3.
- Documentos SAP solo se incluyen con estado `C`, cliente permitido y cuando
  no existen como factura o preventa.
- Cliente SAP se completa a diez posiciones con ceros.
- Se conservan el proceso 702, contadores y registro de errores.

## Caller identificado

No se encontró un job ni una llamada SQL directa en el repositorio. El
componente `702` de `MX_COMPONENTS` identifica el proceso como
`Fiscal Module to Cifras Control`; puede ser invocado por una orquestación
externa no incluida en el proyecto.

## Dependencias

- EAI: `CC_DATA_SALE`, `CFDI_BITACORA`, `CFDI_INFORME`, `FC__TIME_WINDOW`,
  `T3R_Sales_Docs_Old`.
- EAI_OWNER: `ProcessID`, `Log_Start`, `MX_HashTable`, `MX_COMPONENTS`,
  `MX_EAI_MESSAGE_LOG`.
- T3: `Preventa_General`, `Factura_General`, `RF_PROCESOS_LOG`.

Los scripts de `ProcessID`, `Log_Start`, `Preventa_General` y
`RF_PROCESOS_LOG` sí están presentes en el repositorio. No se localizó el DDL
de `T3.Factura_General`; la tabla ya era una dependencia del procedimiento
original y debe confirmarse que exista en la base destino antes del despliegue.

## Despliegue

El archivo crea `EAI.CCEA_DATA_SALE_OPTIMIZADO` como procedimiento paralelo y
no modifica `EAI.CCEA_DATA_SALE`. Para sustituir el proceso productivo se debe
actualizar explícitamente su caller externo o, después de la aceptación en QA,
promover el código validado bajo el nombre original según el estándar del DBA.

## Pruebas recomendadas en QA

1. Documento Prompt, Presales, individual timbrado y agrupado `G-`.
2. Créditos NULL y con valor.
3. Exclusiones `CONEC%` y `DESC-%`.
4. Documento SAP con y sin factura/preventa T3.
5. Cliente descartado y fecha SAP inválida.
6. Duplicados de informe, factura y preventa.
7. Comparar `STATISTICS IO`, `STATISTICS TIME` y planes reales.

## Validación técnica realizada

La versión original y la optimizada se compilaron y ejecutaron en una base
LocalDB aislada con datos controlados. Se validaron:

- Equivalencia de las reglas comunes para Prompt, Presales, preventa con
  `Entrega` nula, PAC individual, agrupado `G-` y documento exclusivo SAP.
- Correcciones alineadas con Oracle: crédito nulo, exclusión `CONEC%` y UUID.
- Exclusiones por factura, preventa, cliente descartado, `DESC-%` y fecha SAP
  inválida.
- Auditoría del proceso 702, consolidación de informes duplicados y protección
  de la tabla destino cuando la ventana contiene una fecha inválida.

En la corrida final de ese conjunto pequeño la ejecución pasó de 49 ms a 28 ms. Este dato solo
confirma ausencia de una regresión evidente en la prueba sintética; la mejora
real debe medirse en QA con volumen representativo, caché controlada y planes
de ejecución reales.

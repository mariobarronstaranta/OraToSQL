# EAI.SF_BITACORA_CFDI_RESUMEN_OPTIMIZADO

## Objetivo

Reconstruye `EAI.CFDI_INFORME` con el resumen de CFDI individuales y
agrupados. El original permanece disponible para comparacion y rollback.

## Optimizaciones principales

- El rango se convierte una sola vez a `DATE`; se eliminaron conversiones de
  la columna `Fecha_Factura` en los filtros.
- El historial del periodo se materializa una vez en `#HDocPeriodo` y se
  reutiliza en las tres cargas.
- Signos y valores dependientes del estado PAC se calculan una sola vez por
  fila mediante `CROSS APPLY`.
- Cabeceras fiscales se reducen a una fila por documento antes de unir el
  detalle, evitando multiplicar cantidades e importes por duplicados.
- Los dos bloques de ajustes fiscales, que ejecutaban la misma operacion, se
  consolidaron en un solo `UPDATE`.
- Addenda se resuelve en un recorrido con `CASE/EXISTS`.
- Se elimino el `LEFT JOIN` sin uso de la actualizacion centralizada.
- Las diferencias menores de seis centavos se corrigen directamente, sin
  volver a leer `CFDI_INFORME` mediante una subconsulta derivada.

## Reglas de negocio conservadas

- Fecha predeterminada: un mes antes de `FC__TIME_WINDOW.Start_Date` hasta hoy.
- Ventas y devoluciones conservan sus factores positivo y negativo.
- Preventas canceladas o con fecha de proceso en 2999 tienen `Monto_T3In = 0`.
- `CONFIRMADO` usa importes PAC; `PENDING` y, cuando aplica, `PUBLICADO` usan
  importes T3.
- Los agrupados usan RFC generico `XAXX010101000` y sociedad `MX06`.
- Se conservan calculos de cigarrillos, envio, credito, lista de precio,
  ajustes fiscales, Addenda y origen SAP para ventas centralizadas.
- Se mantienen el proceso 802, contadores, control de reporte y bitacora de
  errores.

## Verificacion contra Oracle

Se comparo el flujo con
`ORA/T3/EAI/Procedures/SF_BITACORA_CFDI_RESUMEN.SQL`. No se encontraron etapas
de negocio omitidas en la version MSSQL original. La version optimizada conserva
las tres fuentes del informe, las condiciones PAC, los factores, volumen,
complemento agrupado, diferencias, centavos, Addenda y venta central.

Existen dos diferencias tecnicas deliberadas:

- Las cabeceras fiscales repetidas se reducen a una fila antes de agregar el
  detalle. Una cabecera duplicada ya no multiplica importes o cantidades.
- Las fechas invalidas se rechazan antes del `DELETE`, evitando dejar vacio el
  informe por un parametro incorrecto.

## Validacion de fechas

Se aceptan ambas fechas como `NULL` o ambas en formato `YYYYMMDD`. La version
optimizada detiene la ejecucion antes de borrar `CFDI_INFORME` si el formato es
invalido, falta una fecha o el rango esta invertido.

## Caller identificado

El job `ORA_569_EAI_SF_BITACORA_CFDI_RESUMEN` ejecuta actualmente:

```sql
EXEC [EAI].[SF_BITACORA_CFDI_RESUMEN] NULL, NULL;
```

El job no se cambia automaticamente. Debe apuntar a `_OPTIMIZADO` solo despues
de las pruebas funcionales y de rendimiento en QA.

## Dependencias principales

- EAI: `CFDI_INFORME`, `CFDI_BITACORA`, `CONTROL_REPORTE`,
  `FC__TIME_WINDOW`.
- EAI_OWNER: `ProcessID`, `Log_Start`, `MX_COMPONENTS`,
  `MX_EAI_MESSAGE_LOG`, `WA_VENTA_CENTRALIZADA`.
- T3: historial y documentos CFDI, facturas, preventas, clientes, entregas,
  registros fiscales, materiales, agrupados, diferencias, Addenda, `Fact_T3`,
  `Nota_T3` y `RF_PROCESOS_LOG`.

## Pruebas recomendadas en QA

1. Ejecutar original y optimizado con el mismo rango en copias aisladas.
2. Comparar todas las columnas por `Folio_Interno` y detectar duplicados.
3. Incluir venta, devolucion, preventa cancelada, individual y agrupado.
4. Probar estados `CONFIRMADO`, `PENDING`, `PUBLICADO` y otro estado.
5. Incluir envio, credito, materiales CAJ/PAQ, ajustes y centavos.
6. Comparar `STATISTICS IO`, `STATISTICS TIME` y planes reales.

## Validacion tecnica realizada

Se compilaron y ejecutaron ambas versiones en una base LocalDB temporal. El
escenario incluyo una factura individual, una preventa publicada y un CFDI
agrupado, ademas de volumen, envio, credito, lista de precio, ajuste, Addenda y
venta centralizada. Todas las columnas de `CFDI_INFORME` coincidieron entre el
original y el optimizado.

Tambien se validaron la invocacion predeterminada `NULL, NULL`, el cierre de
auditoria y el rechazo de fechas invalidas antes de eliminar el resumen. Los
tiempos de este conjunto pequeno no son representativos; la conclusion de
performance requiere datos y planes reales de QA.

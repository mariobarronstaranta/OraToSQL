# SF_CFDI_OPEN_ITEMS: revision de rendimiento

## Hallazgos en los archivos recibidos

1. La etapa 10 une cabeceras, detalles y vigencias de cliente antes de agrupar. Los comentarios del archivo recibido reportan 5,484,630 filas en factura con corte 20260101 y 5,008,634 en preventa. Son conteos proporcionados en el script, no mediciones realizadas en produccion.
2. `FN_COBZA_PAY` y `FN_COBZA_CM_UUID`, agregadas durante esta revision, abren un cursor para devolver una suma por cada documento. Repetir esa consulta sobre cobranza y documentos fiscales puede ser mas costoso que el acceso a Factura_General. Sin plan real y esperas del servidor no se puede atribuir el total de horas a un unico operador.
3. La exclusion de documentos ya abiertos esta expresada al final de la consulta original. SQL Server puede mover predicados; el texto por si solo no demuestra el orden fisico. La nueva version materializa cabeceras elegibles para establecer una separacion efectiva antes de expandir detalles.
4. La etapa 90 tambien consulta Factura_General y Preventa_General, sin corte de fecha. El filtro de etapa 10 no reduce esa consulta directamente. No se le agrego un filtro temporal: tambien debe resolver el cliente facturado de documentos antiguos que llegan de cartera SAP.
5. Los indices que realmente existen en produccion y sus estadisticas deben consultarse en el servidor. No se puede deducir su ausencia del DDL local.

## Entregables

- `SF_CFDI_OPEN_ITEMS_RENDIMIENTO.SQL`: crea un procedimiento separado `EAI.SF_CFDI_OPEN_ITEMS_RENDIMIENTO`; conserva el original. Usa la misma tabla de salida y los mismos logs/componente 923. El script contiene `USE [T3QA]`, igual al archivo recibido: comprobar base destino antes de desplegar.
- `SF_CFDI_OPEN_ITEMS_DIAGNOSTICO.SQL`: solo lectura; muestra filas aproximadas, indices con orden de claves/INCLUDE, estadisticas y solicitudes activas con esperas, bloqueo y sentencia actual. Con `@SPID` devuelve tambien el plan compilado de esa solicitud, no un plan de ejecucion real. Devuelve propuestas de CREATE INDEX como texto y no las ejecuta. Compararlas con indices equivalentes existentes, incluidos los scripts de Ventas.
- `tests/SF_CFDI_OPEN_ITEMS/Run_Rendimiento.ps1` y `Rendimiento.sql`: prueba reproducible en una base LocalDB desechable. Carga los DDL y las dos funciones reales recibidas; no usa stubs para cobranza. `Stage10_Rendimiento.sql` es el fragmento de referencia de la etapa nueva, no un script para ejecutar por separado.

## Cambios de etapa 10

- Cabeceras candidatas en temporales con indice por Factura, excluyendo los folios ya presentes en Open Items antes de consultar detalles. Se conservan cabeceras duplicadas, todas las filas de detalle y todas las vigencias coincidentes.
- Materializacion del importe historico con el mismo UNION ALL, expresiones numericas, claves de agrupacion y fechas inclusivas.
- Claves distintas por folio y tipo Vta/Dev para que las filas historicas no multipliquen cobranza. Las filas historicas originales no se deduplican.
- Dos sumas de cobranza por conjuntos sustituyen las UDF escalares solo en esta etapa. Venta suma toda cobranza por Factura. Devolucion conserva los JOIN por Nota_Credito, Historia_Docto_PAC y documento con Folio_Fiscal no nulo; varias coincidencias siguen multiplicando importes. No se agrega filtro de Via_Pago.
- Conversion a NUMERIC(15,2) como las funciones originales, incluido el error si desborda; sin cobranza se interpreta cero en la comparacion. Se conserva `ABS(importe - cobrado) > 0.05` y el contador de inserciones.
- OPTION(RECOMPILE) en las consultas grandes para compilar con el corte y temporales de esa ejecucion. Indices y materializacion consumen tempdb; deben medirse con el volumen real.
- Las etapas restantes son identicas al archivo MSSQL recibido. Esta optimizacion no resuelve las diferencias de negocio con Oracle anotadas en ese archivo ni certifica equivalencia total con Oracle.

## Validacion realizada

Prueba ejecutada en LocalDB con los tipos de las tablas reales y 1,500 documentos adicionales saldados, mas casos dirigidos:

- Comparacion bidireccional de filas agrupadas con multiplicidad, excluyendo la hora de ejecucion de Last_Updated.
- Limite de fecha, clases fiscales de ambas fuentes, preventa cancelada/sin procesamiento, documento sin cliente o sin detalle, y folio ya abierto con Last_Updated NULL.
- Pagos nulos, importe nulo/cero, saldo de 0.05 y 0.06, sobrepago, detalles/cabeceras duplicados y vigencias solapadas.
- Multiples relaciones PAC y multiples UUID, documento sin UUID y el mismo folio como Vta y Dev.
- Desbordamiento de NUMERIC(15,2): ambas versiones devuelven error 8115.
- Compilacion y ejecucion del procedimiento completo con cierre de RF_PROCESOS_LOG.

Mediciones ilustrativas: sin los indices propuestos, original 324 ms y nueva etapa 69 ms; con los 12 indices propuestos, original 118 ms y nueva etapa 102 ms. Ambos ensayos pasaron la comparacion. La materializacion tiene un costo y la diferencia disminuye en esta muestra pequena cuando las busquedas ya cuentan con indices. No es un benchmark controlado ni una estimacion o garantia de mejora en produccion.

Tambien se ejecuto el diagnostico y se crearon sus 12 propuestas de indices en la base desechable. Se verifico el corte parametrizable sin candidatos. Una comparacion textual confirmo que etapa 0 y etapas 20 en adelante permanecen identicas al archivo original. No se ejecuto el procedimiento ni se crearon indices en produccion.

## Uso para la prueba en QA

Primero ejecutar el diagnostico en el servidor mientras la solicitud lenta siga activa, para identificar etapa y esperas. Crear la version separada en QA y ejecutarla de forma exclusiva sobre una copia de datos representativa:

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
EXEC EAI.SF_CFDI_OPEN_ITEMS_RENDIMIENTO
    @nEtapa = 0,
    @FechaInicio = '20260101',
    @Diagnostico = 1;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
```

Esta ejecucion reconstruye EAI.CFDI_OPEN_ITEMS. No ejecutar ambos procedimientos al mismo tiempo. Comparar versiones partiendo de copias identicas y fuentes estables; no comparar dos corridas mientras las fuentes cambian. Las temporales se llenan en varias sentencias: no se introduce una transaccion snapshot ni se garantiza una fotografia unica bajo READ COMMITTED.

El parametro FechaInicio conserva el corte de prueba 20260101 recibido; acordar el corte definitivo antes de produccion. Solo afecta la etapa historica. Diagnostico emite conteos y milisegundos de cabeceras, agrupacion y cobranza de etapa 10. Para las demas etapas, consultar la sentencia activa y el plan real en SSMS.

`@nEtapa = 10` ejecuta la etapa 10 Y las posteriores, sin reconstruir SAP. No significa "solo etapa 10". La etapa final conserva el ajuste fiscal no idempotente del original; repetir ejecuciones parciales puede volver a sumarlo.

Para reproducir la prueba local desde esta carpeta:

```powershell
.\tests\SF_CFDI_OPEN_ITEMS\Run_Rendimiento.ps1
```

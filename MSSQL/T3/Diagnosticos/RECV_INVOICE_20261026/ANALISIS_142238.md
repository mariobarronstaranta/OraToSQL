# RECV_INVOICE: captura del 26 de octubre de 2026

Fuente: [resultado original](Captura_142238.txt), capturado a las
14:22:38.5561537 -06:00 en **AZCRNMXNEVTD06 / T3QA**. SQL Server
16.0.4305.5, compatibilidad 160, SQL_Latin1_General_CP1_CI_AS, recuperacion
SIMPLE y Query Store habilitado. Aunque el reporte inicial menciona produccion,
la evidencia identifica T3QA; no se acredita otra base productiva.

SHA256 del archivo recibido:
BAEE990FC544879B5989B5F408F5F8514A491DC9B74B4DF61764E5533C19FE13.

## Hallazgos medidos

| Modulo / plan | Llamadas | Tiempo medio, ms | Lecturas logicas medias |
|---|---:|---:|---:|
| SF_PROC_PREINVOICE_IFC | 976 | 680.10 | 63,833.57 |
| INVOICE_TO_PREVENTA | 9 | 4,648.60 | 196,727.78 |
| DELIVERY_WA_OXXO, actividad reciente | 259 | 2,069.33 | 670,025.44 |
| GET_REMISION_INFO, actividad reciente | 3,920 | 407.01 | 134,836.80 |
| INVOICE_TO_FACTURA | 2,874 | 36.74 | 646.69 |
| WA_FOLIO_FACTURA, actividad reciente | 1,982 | 17.20 | 713.16 |
| INVOICE_TO_ENTREGA_PO | 973 | 0.60 | 11.19 |

Son promedios acumulados de planes con distintas fechas de cache y llamadas
posiblemente de otros flujos. Hay otros planes para OXXO, remision y folios
con promedios mucho menores; no se deben mezclar ni elegir el mas barato para
representar el lote reciente. Padres e hijos tienen tiempo inclusivo: no sumar
filas ni derivar porcentajes de ruta a partir de conteos de ventanas distintas.

El parser de 680 ms tiene el mismo orden de magnitud que los 600 ms por
registro reportados por el usuario. Esto prioriza su analisis, no demuestra que
los 976 registros sean facturas completas ni que el parser XML sea por si solo
la sentencia costosa. Puede incluir trabajo de los procedimientos delegados.
Su CPU media es 3,867.85 ms; que supere al tiempo transcurrido no acredita
por si solo saturacion o bloqueo. Revisar paralelismo y plan antes de interpretarlo.

## Versiones y candidato principal

- SF_PROC_PREINVOICE_IFC: modify_date 2026-10-23 22:12:56.923,
  90,310 bytes de definicion, hash
  3BC62CB6FF66A66882CC1E573FE9F1326FCE40CCBD329F44ADFA5E3BC6F5F884.
  Las tres marcas RI_REF_SEEK son cero. No aparece el parche conocido.
- El antecedente QA del 19 de octubre detecto 48,277 lecturas / 420 ms en el
  DELETE de detalle y 11,583 lecturas / 108 ms en cabecera. Su suma es cercana
  a las lecturas del parser actual y justifica inspeccionar esos accesos primero.
  No prueba que los mismos DELETE dominen esta captura; una solucion equivalente
  sin marcadores tambien podria estar instalada.
- RECV_INVOICE: modify_date 2026-10-19 13:22:12.310; aparece el patron del
  COUNT_BIG dentro del WHILE. La variante RECV_INVOICE_OPTIMIZADO no es visible.
  El conteo repetido es un candidato adicional, no una explicacion demostrada
  del promedio de 680 ms. La variante del parser con sufijo OPTIMIZADO existe,
  pero su presencia no demuestra que el flujo la invoque.
- INVOICE_TO_PREVENTA y OXXO/remision merecen una segunda revision por sus
  lecturas altas. No crear indices ni reescribir cursores solo por estos promedios.

## Evidencia aun necesaria

El archivo entregado contiene 01, 02, 03 y la cabecera vacia de 04. No incluye
filas de sentencias, muestras de sesiones/bloqueos/esperas, indices ni el cierre
del diagnostico. El usuario aclara que copio todos los resultados obtenidos.
No afirmar que hay o no hay bloqueos, que faltan indices o que el script entero
termino correctamente. No hay mensajes de error en el archivo recibido.

Se preparo [RECV_INVOICE_RENDIMIENTO_FOCALIZADO.sql](../RECV_INVOICE_RENDIMIENTO_FOCALIZADO.sql):
consulta handles de tres procedimientos, estadisticas de sus sentencias sin
depender de T.dbid, indices/tipos de REFERENCEID y fragmentos de los DELETE,
tres planes compilados y actividad instantanea. Sin WAITFOR, ejecucion de
facturas ni DDL. Sintaxis validada con TSql160Parser; no ejecutado en servidor.

Ejecutar completo en la misma base y entregar texto y los tres XML de
05_PLANES como .sqlplan. Cache y planes pueden revisarse despues del lote;
solo la actividad instantanea requiere que el lote este ejecutando. Si un plan
es NULL o no hay estadisticas de sentencias, conservar ese resultado.
La correccion prioritaria es recuperar el acceso por ReferenceID si el plan
confirma la conversion/scan y el indice pertinente existe, mediante un parche
puntual sobre la definicion instalada que preserve sus correcciones y permisos.
No se alteraron SP ni indices durante este analisis.

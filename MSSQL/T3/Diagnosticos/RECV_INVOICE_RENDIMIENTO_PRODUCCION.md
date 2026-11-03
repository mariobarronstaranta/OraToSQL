# Revision de lentitud en produccion: RECV_INVOICE

Reporte del usuario, 26 de octubre de 2026: aproximadamente 100 registros por
minuto, equivalentes a 1.67 registros/s o 600 ms por registro como media del lote.
No se ha recibido aun captura del servidor productivo ni se ha demostrado que
ese contador represente documentos completos en las tablas destino.

## Primera captura

1. En SSMS, abrir otra ventana conectada a la misma base productiva.
2. Mientras el lote habitual sigue trabajando, ejecutar completo
   [RECV_INVOICE_RENDIMIENTO_PRODUCCION.sql](RECV_INVOICE_RENDIMIENTO_PRODUCCION.sql).
3. Dejar `@SesionObjetivo = NULL` si no se conoce el SPID. Si ya se conoce,
   indicarlo para limitar las esperas a esa sesion.
4. Guardar todos los resultados. Hay una espera de diez segundos entre muestras.
   El usuario no debe lanzar otra corrida del procedimiento para esta captura.

El archivo consulta catalogos/DMVs y variables locales; no recorre la cola ni
los XML de clientes, no ejecuta conversiones de facturas ni modifica negocio.
Se necesita una cuenta autorizada de monitoreo para ver las sesiones ajenas.

## Evidencia que ya existe y limites

- El codigo local de RECV_INVOICE materializa el lote y lo recorre documento
  por documento, delegando en SF_PROC_PREINVOICE_IFC. Repite COUNT_BIG del lote
  en cada iteracion. Existe una variante independiente que cuenta una vez,
  pero su existencia no demuestra activacion en produccion.
- El parser local conserva cursores de XML y material. Sus llamadas de negocio
  estan dentro de la transaccion de la factura, o de la transaccion externa.
  El tiempo atribuido al parser puede incluir preventa, factura, folios y entrega.
- El paquete de rendimiento del 19 de octubre documenta una captura QA con
  DELETE de detalle de aproximadamente 420 ms y 48,277 lecturas por llamada;
  DELETE de cabecera de aproximadamente 108 ms y 11,583 lecturas; relacion
  de folios de aproximadamente 88 ms. Son promedios acumulados de cache.
- Los 528 ms combinados de aquellos dos DELETE justifican revisar primero
  sus accesos, pero no prueban la causa de los 600 ms actuales en produccion.
  No sumar esos valores a la duracion inclusiva del parser o del coordinador.
- Ya existe el parche selectivo RI_REF_SEEK para los tres DELETE por
  ReferenceID Unicode frente a claves VARCHAR. Fue observado en una definicion
  instalada de QA y no forma parte del archivo local completo del parser.
  No se ha acreditado su presencia en la base productiva del reporte actual.
  Falta de marca no prueba un scan: una variante puede resolverlo de otra forma.
- Los indices de DOCTOS confirmados por el usuario en produccion corresponden
  a otro procedimiento y no acreditan cobertura de TMP_DOCUMENT_* o de folios.

## Como se usaran los resultados

| Seccion | Evidencia |
|---|---|
| 02 | Versiones, indicios del parche y conteo repetido del coordinador |
| 03 y 07 | Tiempo/CPU/lecturas de llamadas terminadas; muestra acumulada y diferencias del mismo plan |
| 04 | Sentencias concretas mas lentas, incluidos DELETE y consultas de folios |
| 05, 06, 08 y 09 | Actividad, bloqueador y esperas observadas durante el lote |
| 10 | Claves/INCLUDE, indices deshabilitados, tipos y collation de accesos relevantes |

Las llamadas terminadas del parser son una aproximacion de actividad, no una
conciliacion de documentos completos. La muestra solo incluye sesiones activas
al principio, salvo SPID explicitado; si no captura el lote, repetir durante su
ejecucion. La reutilizacion de SPID se descarta comparando login_time. Las
esperas pertenecen a la sesion y no exclusivamente a un procedimiento; en
paralelismo pueden superponerse. Los contadores nuevos o recompilados no se
comparan como si fueran el mismo plan. Un plan que sale de cache no aparece
en la muestra final. La captura no distingue todas las causas por si sola:
el siguiente paso sera obtener el plan de la sentencia que resulte dominante.

No se entregaron cambios de SP/indices ni se ejecuto SQL contra produccion
como parte de esta revision. La captura determina que ajuste preparar y probar.

Referencias de las unidades y limites de las DMVs:
[estadisticas de procedimientos](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-procedure-stats-transact-sql)
y [esperas por sesion](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-session-wait-stats-transact-sql).

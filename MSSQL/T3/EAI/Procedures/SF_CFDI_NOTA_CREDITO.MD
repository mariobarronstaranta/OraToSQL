# Revision Oracle de EAI.SF_CFDI_NOTA_CREDITO

Fecha: 2026-10-08. Tres pasadas contra
`ORA/T3/EAI/Procedures/SF_CFDI_NOTA_CREDITO.SQL`.
Archivo corregido: `MSSQL/T3/EAI/Procedures/SF_CFDI_NOTA_CREDITO.SQL`.
El archivo SIN extension es otra version que declara el esquema dbo;
no utilizarlo para desplegar esta correccion de EAI.

## Hallazgo principal y correccion

El cursor Oracle ScrCobza contiene agregados sin GROUP BY: aun cuando una
nota no tiene cobranza devuelve una fila, con COUNT=0 y SUM/MAX=NULL.
El INNER JOIN de MSSQL a una agregacion por nota omitio esas notas.
En etapa 10 dejaba aplicaciones antiguas; en carga completa dejaba Aplica_NC
nulo en vez de cero. El contador tambien excluia esas filas.

Se sustituyo por LEFT JOIN, con ISNULL solamente sobre Aplicaciones. Los demas
campos conservan NULL si no hay coincidencias. Se cuenta el universo del cursor
por separado, incluyendo notas sin cobranza y filas con Nota_Venta NULL.
Estas ultimas se cuentan pero no se actualizan, porque la igualdad con NULL
del UPDATE Oracle nunca encuentra filas. Los duplicados destino se conservan.
EXISTS limita el agregado de cobranza a las notas del reporte, sin multiplicar
sus importes cuando hay filas destino repetidas.

## Pasada 1: carga y filtros

| Regla | Resultado |
|---|---|
| Etapa NULL, cero o negativa | Reconstruye y calcula aplicaciones |
| Etapas 1..10 | Solo aplicaciones; conserva filas del reporte |
| Etapa >10 | Solo auditoria y control transaccional |
| Fecha minima | 2023-01-01 inclusiva, fija; sin fecha maxima ni FC__TIME_WINDOW |
| Factura | Solo C004 con detalle y cliente vigente |
| Preventa | C006/C019/C025, procesada y no cancelada, con detalle y cliente vigente |
| Cliente | Fecha factura BETWEEN inicio/fin de vigencia, limites inclusivos |
| RFC | Excluye XAXX010101000, NULL y ahora cadena vacia equivalente a NULL Oracle |
| Importe | Suma NVL(subtotal,0)+NVL(IVA,0)+NVL(envio subtotal,0)+NVL(envio IVA,0) |
| Signo | No aplica signo adicional ni ABS al importe de venta |
| Origenes | UNION ALL; se agrupa por centro/fecha/nota/cliente/RFC |
| SAP | SUM(NVL(Monto,0)) por referencia, luego ABS; ausencia produce saldo 0 |
| UUID | LEFT JOIN opcional, sin exigir estado o timbrado ni deduplicar documentos |

No se agregan credito ni bonificaciones al Importe_Vta. No se cambian vigencias
superpuestas ni multiplicidad de comprobantes: Oracle tambien multiplica sus
coincidencias. No se introducen filtros adicionales de pagos timbrados.

## Pasada 2: aplicaciones, nulos y contadores

- Aplica_NC cuenta Asignacion_ID no nulos, SIN DISTINCT. Se normaliza cadena
  vacia a NULL. Asignaciones repetidas siguen contando; ID nulo puede aportar
  importe aunque no aporte conteo.
- Importe_NC suma NVL(Importe,0) de TODAS las vias, no solamente CM.
- Fecha_Aplicacion toma MAX(Fecha_Asignacion).
- Incobrable suma Importe cuando Via_Pago=AI, cero en otras vias. No se agrega
  ISNULL dentro de la rama AI: si todas las filas son AI con importe nulo, el
  resultado es NULL; con filas no AI puede ser cero.
- Sin filas de cobranza: Aplica_NC=0; Importe_NC, Fecha_Aplicacion e Incobrable
  son NULL. Esto es distinto a tener filas de cobranza con importe nulo, cuya
  suma NVL puede producir cero.
- Proceso_1 cuenta filas recorridas del reporte, incluidos duplicados y notas
  nulas. Proceso_2/3/4 permanecen en cero. Se elimina la asignacion acumulativa
  de variable dentro del UPDATE; no se depende del orden de actualizacion.

## Pasada 3: transacciones, errores y despliegue

Se mantuvo la proteccion transaccional MSSQL previamente implementada:

- Ejecucion independiente: carga, aplicaciones y cierre en una transaccion;
  rollback completo ante fallo y registro de error posterior al rollback.
- Ejecucion anidada: savepoint, sin confirmar transaccion externa. Si queda
  condenada, el llamador debe revertir y no se intenta escribir el log.
- Un fallo del log no sustituye la excepcion funcional original; se usa THROW.

**No es equivalencia de fallos con Oracle:** Oracle confirma la carga y luego
cada 1000 filas, y su EXCEPTION hace COMMIT y registra sin relanzar. MSSQL
deliberadamente conserva el reporte anterior al fallar en ejecucion independiente.
Esto tambien cambia la persistencia del registro de inicio y componente ante error.
Reference usa identificadores de etapa MSSQL; Oracle usa CFDI_UUID_VENTA al cargar.
Los codigos/fuente son SQL-/T-SQL en lugar de ORA-/PL/SQL.

El job del repositorio es ORA_830_EAI_SF_CFDI_NOTA_CREDITO y llama al esquema EAI
con etapa 0. No se modifico ni ejecuto el job.

Limites revisados:

- Aplica_NC es NUMERIC(4,0): mas de 9999 asignaciones desborda. Se probo 10000
  y se verifico error 8115, rollback del reporte y ausencia de transaccion abierta.
- Los importes destino son NUMERIC(16,2). Los tests ajustan estos tipos y el
  saldo origen NUMERIC(13,2); no prueban todos los extremos numericos posibles.
- Oracle usa sFactura VARCHAR2(20), pero el destino MSSQL acepta Nota_Venta de
  30 caracteres. Para folios mayores a 20, Oracle podria fallar en la asignacion
  al cursor y MSSQL procesarlos: no se introdujo una restriccion artificial.
- Oracle acepta nEtapa NUMBER, MSSQL INT; las pruebas cubren etapas enteras.
- Comparaciones de cadenas dependen de collation destino (mayusculas, espacios).
  NULLIF(texto,'') tambien normaliza blancos bajo la comparacion SQL Server.
  Datos con blancos significativos requieren conciliacion especifica.
- Se presupone que fuentes y reporte no se modifican concurrentemente durante
  la comparacion. No se certificaron triggers, indices ni DDL de produccion.

## Pruebas realizadas

Se ejecuto `tests/SF_CFDI_NOTA_CREDITO/Run.ps1` en LocalDB con una base aleatoria
eliminada al terminar. Se compilo el procedimiento y se ejecutaron:

1. Pruebas anteriores: etapas 0/10/20/NULL, auditoria, rollback tras DELETE,
   fallo del log, transaccion externa exitosa y transaccion externa condenada.
2. 17 comprobaciones adicionales en OracleRules.sql: agregado escalar de
   referencia derivado de Oracle contra resultado MSSQL, falta de cobranza,
   AI nulo, vias mixtas, ID nulo/vacio/repetido, destinos repetidos, nota NULL,
   contador, etapa 11, filtros, corte inclusivo 2023, UNION ALL, saldo SAP,
   UUID ausente/duplicado, importes negativos/nulos y overflow de asignaciones.

Todas pasaron. Los errores 547 y 8115 se provocan intencionalmente. Las
advertencias de NULL eliminado en agregados son esperadas.
El arnes usa un esquema minimo y LOG_START simulado, no todas las dependencias
reales. No se ejecuto Oracle ni se accedio a produccion; no es un benchmark.

Antes de aceptar los resultados productivos, conciliar el mismo corte de fuentes
contra Oracle: filas y multiplicidad, Importe_Vta, Saldo_SAP, UUID, Aplica_NC,
Importe_NC, Fecha_Aplicacion, Incobrable y contadores. Probar especialmente etapa
10 sobre notas cuyas aplicaciones se eliminaron: deben limpiarse como Oracle.

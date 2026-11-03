# Medicion reportada: 2026-10-26 17:20:03

Fuente: horarios y cantidad compartidos por el usuario. No se recibieron
en este mensaje servidor/base, PID, RunId ni confirmacion de instalacion del
parche SKU. No atribuir el resultado a ese parche sin verificar su presencia.

| Dato | Valor |
|---|---:|
| Inicio local | 2026-10-26 17:20:03 |
| Fin local | 2026-10-26 17:21:01 |
| Duracion | 58 s |
| Registros procesados reportados | 869 |
| Registros por segundo | 14.98 |
| Registros por minuto | 898.97 |
| Tiempo del lote dividido entre registros | 66.74 ms |

Frente a la corrida de 865 registros en 51 s (16.96/s), la tasa observada
es 11.66% menor. Esto no acredita una regresion causada por un cambio:
faltan version instalada, mezcla de documentos y perfil de esta corrida.
La primera corrida de 706/50 s habia obtenido 14.12/s.

La meta de 20-25/s no se alcanza. Para 869 registros equivale a 34.76-43.45 s;
se necesita reducir 14.55-23.24 s frente a los 58 s reportados.

Siguiente evidencia: ejecutar [04_REVISAR_PARSER_Y_FACTURA.sql](04_REVISAR_PARSER_Y_FACTURA.sql)
en la misma base, sin necesidad de generar otra carga. La seccion 01 muestra
ParcheSku y DesdeModificacionParser; comparar esa fecha con el inicio del lote.
Las siguientes secciones permiten revisar el costo actual de curSKU y de
INVOICE_TO_FACTURA y sus esperas. La cache y Query Store pueden incluir otras
ejecuciones; no confundirlas con una medicion exclusiva del PID de esta carga.

No se realizan cambios adicionales ni se recomienda reversion solo por este
conteo. Se conserva la validacion RI8114_DETAILBASE_VACIO_V1 en
INVOICE_TO_FACTURA para materiales no convertibles como R044.

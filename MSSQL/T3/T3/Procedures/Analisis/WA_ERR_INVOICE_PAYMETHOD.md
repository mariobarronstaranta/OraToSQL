# Analisis de T3.WA_ERR_INVOICE_PAYMETHOD

Revision del 29/10/2026 del [procedimiento SQL Server](../WA_ERR_INVOICE_PAYMETHOD.sql).
Se agregaron comentarios de desarrollador al archivo actual del workspace.
No se modifico su SQL ejecutable ni se desplego en una base de datos.

## Proposito y contrato

Corrige MetodoPago a '03' en T3.OTROS_GENERAL. La decision se aplica cuando
el cursor encontro una cabecera con MetodoPago='No identificado',
Fecha_Proc_BATMD NULL y detalle coincidente con Material='R900' y
MaterialDescripcion='FIXED ASSET - External Sales'.

| Entrada | Efecto de la ventana sobre Fecha_Factura |
|---|---|
| Parametro omitido | @pDias=0: Fecha_Factura posterior al instante actual. No equivale a seleccionar todo el dia de hoy. |
| @pDias=4 | Fecha_Factura posterior al instante actual menos cuatro dias. |
| @pDias=NULL | ISNULL aplica siete dias. |
| Valor negativo | Desplaza el limite hacia el futuro; el SP no valida signo o rango. |

La condicion usa >, conserva la hora y no establece limite superior.
GETDATE se evalua al ejecutar la consulta del cursor. Fecha_Factura NULL
no cumple la comparacion. Fecha_Trn no interviene en esa seleccion.

No hay parametros OUTPUT ni SELECT de resultados de negocio. Imprime
`Documentos -> N`. No genera layouts/documentos ni cambia Fecha_Proc_BATMD.
No crea PID, no consume secuencias y no registra RF_PROCESOS_LOG.

## Recorrido

1. Declara variables y un cursor LOCAL FORWARD_ONLY STATIC.
2. El SELECT une OTROS_GENERAL y OTROS_DETALLE por Factura y filtra fecha,
   material y descripcion. La sintaxis de dos tablas en FROM con igualdad
   en WHERE corresponde a una union interna.
3. Inicializa @nPedidos=0 y abre el cursor: STATIC toma la fotografia en OPEN.
4. Recibe ocho columnas. Guarda la Factura en @sReference para diagnostico.
5. Si los valores recibidos indican metodo no identificado y estado pendiente,
   incrementa el contador y ejecuta UPDATE por Factura a MetodoPago='03'.
6. Avanza el FETCH; al terminar cierra el cursor, imprime el contador y libera
   la asignacion del cursor.
7. Ante error, limpia el cursor disponible e intenta insertar una bitacora.
   No ejecuta THROW ni ROLLBACK propios.

## Tablas, llamadores y efectos

| Objeto | Uso |
|---|---|
| T3.OTROS_GENERAL | Lectura y UPDATE de MetodoPago por Factura. |
| T3.OTROS_DETALLE | Lectura de Factura, Material y MaterialDescripcion. |
| EAI_OWNER.MX_EAI_MESSAGE_LOG | INSERT de errores en el CATCH. |
| T3.PROC_T3_OT_GENERAL | Llamador localizado: ejecuta este helper con el argumento 4 antes de abrir su propio cursor. |

El helper no llama otros SP ni funciones de usuario. Puede afectar un conjunto
distinto al que despues procesa PROC_T3_OT_GENERAL: aqui la fecha de seleccion
es Fecha_Factura; el padre usa Fecha_Trn. Tampoco recibe una lista de facturas
del lote de RECV_INVOICE_INTERCOMPANY que origino la llamada al padre.

## Alcance y puntos de mantenimiento

- **El contador mide iteraciones, no filas modificadas.** Se incrementa antes
  del UPDATE, no se consulta @@ROWCOUNT ni se cuentan facturas distintas.
  Si una cabecera tiene varias lineas de detalle coincidentes, el SELECT
  devuelve varias filas y puede repetirse la actualizacion de la misma Factura.
- **El SELECT no limita a pendientes ni al metodo a corregir.** Esas condiciones
  se revisan en el IF sobre la fotografia del cursor. Tras el primer UPDATE,
  otra copia del cursor puede seguir conservando el metodo antiguo.
- **El UPDATE es mas amplio que el IF.** Su unico filtro es Factura. Si existen
  varias cabeceras con el mismo identificador, puede cambiar tambien filas con
  otro metodo, otra fecha o una marca de procesamiento ya informada. La
  condicion de pendiente se evalua en la fila recibida, no en cada fila destino.
- **No filtra cancelacion ni sociedad.** Tampoco selecciona por Clase_Factura.
  Los campos recibidos de fecha, sociedad, moneda y nombre son contexto; no
  se usan para decidir ni restringir el UPDATE posterior.
- **No hay reserva entre sesiones.** STATIC conserva una fotografia y no
  impide otras ejecuciones concurrentes. Sin ORDER BY no hay un orden fijo.
- **No hay transaccion integral.** En autocommit pueden quedar cambios anteriores
  a un error. Bajo transaccion externa depende del llamador; el SP no confirma
  ni revierte esa transaccion.

No se aplicaron cambios de filtros, tipado, tolerancias, cursores o transacciones.
Las observaciones documentan el comportamiento actual y requieren una decision
funcional separada antes de cualquier correccion.

## Variables y bitacora

@nPID y @nProceso se declaran pero nunca se asignan; @nProceso no se consume y
JOB_PID queda NULL en el INSERT de error. Por ello no se debe atribuir
automaticamente un PID del padre a estos mensajes.

@Cur_MetodoPago es VARCHAR(50), frente al VARCHAR(80) del DDL local de la
cabecera. @Cur_Factura es VARCHAR(50) y @sReference VARCHAR(30), mientras
Factura se define VARCHAR(20) en el DDL revisado. El SELECT y ambos FETCH
mantienen ocho posiciones.

El CATCH verifica CURSOR_STATUS>=-1 para cubrir cursores abiertos y cerrados;
solo ejecuta CLOSE si el estado es >=0, y luego DEALLOCATE.

| Campo de MX_EAI_MESSAGE_LOG | Contenido |
|---|---|
| DIRECTION | Job Logging |
| REFERENCE | Ultima factura asignada a @sReference; puede ser NULL si fallo antes. |
| CREATED | GETDATE() al registrar el error. |
| JOB_PID | NULL, porque @nPID nunca recibe valor. |
| STATUS | Error |
| QUEUE_NAME | WA_ERR_INVOICE_PAYMETHOD |
| SIEBEL_ERROR_MESSAGE | Numero y mensaje del error, recortados a 250 caracteres. |
| SIEBEL_ERROR_CODE | SQL- seguido de ERROR_NUMBER(). |
| SOURCE | PL/SQL, etiqueta heredada conservada. |

Si el INSERT de bitacora termina correctamente, el SP retorna sin relanzar
el error y el padre puede continuar. Si el INSERT falla, por ejemplo por el
estado de una transaccion externa, ese nuevo error puede propagarse.
Que EXEC termine no acredita que todas las correcciones se hayan realizado.

## Comprobacion de la documentacion

- TSql160Parser: cero errores antes y despues.
- 466 tokens ejecutables identicos al comparar tipo y texto, excluyendo
  comentarios, espacios y fin de archivo.
- Se conservaron USE T3QA, ALTER PROCEDURE, opciones SET, UTF-16 LE con BOM
  y saltos CRLF del archivo recibido.
- Respaldo: tmp/wa_err_invoice_paymethod_comentarios_20261029/
  WA_ERR_INVOICE_PAYMETHOD.antes.sql, desde la raiz del repositorio.
- SHA-256 del respaldo:
  7db6977286b1050e80a6ca7c5e3952e91c357217b1baedcc4db5edf720bb43ee.
- Evidencia: tmp/wa_err_invoice_paymethod_comentarios_20261029/VALIDACION.txt.

No se ejecuto el procedimiento ni se alteraron datos de T3QA. La igualdad de
tokens acredita que solo se documento el archivo local; no certifica los
datos, restricciones o definiciones instaladas. No se encontro su fuente
Oracle independiente para una comparacion de paridad.

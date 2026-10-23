# Analisis de errores 3930 en PROC_PREINVOICE_IFC

## Seguimiento: 8114 en detalle de INVOICE_TO_FACTURA

### Causa confirmada con captura de las 15:02

La salida de 07 del 22/10/2026 15:02:26, AZCRNMXNEVTD06/T3QA, localiza el
documento fuera del prefijo liberado:

- Documento: 1658415284.
- ROW_ID: 20261002121244302218000302218000, CREATED 2026-10-02 12:12:44.
- Estado Received, PROCESSED NULL, REFERENCE NULL.
- ItemNumber: 000010/000010.
- MaterialID: R044, cuatro caracteres, hexadecimal Unicode 5200300034003400.
- TRY_CONVERT(numeric(38,0),MaterialID) devuelve NULL: no es convertible.
- Tiene8114Hoy=1, tres errores a las 14:29:42, 14:36:06 y 14:38:17.

Se analizaron 467 mensajes (466 del prefijo y uno adicional), con 2,081 filas
de material: un no convertible, ningun nulo/vacio ni mayor de 18. Esta evidencia
identifica R044 como causa concreta de la conversion 8114 para esa factura;
no requiere seguir buscando por otros prefijos para explicar este caso.

La copia historica del mismo mensaje existe en
ORA/T3/EAI_OWNER/Datos/MX_RECEIVE_MESSAGE_LOG_BCP.txt, alrededor de la linea
5105569. Contiene el mismo ROW_ID, documento y material, descripcion OTHER
RECHARGE, sociedad MX16 y unidad EA. El archivo historico lo presenta como
Processed; eso no demuestra que haya completado la ruta T3 ni que los destinos
instalados hoy sean equivalentes.

R044 tambien aparece en TMP_DOCUMENT_DETAIL.txt (por ejemplo, linea 7115)
y en MX_CFDI_PRODSERV_LOG.txt, con registros de tipo EXPO. Por ello no se
considera automaticamente un codigo mal capturado ni se elimina o cambia a 0.
Estos datos historicos no prueban que la ruta INVOICE_TO_FACTURA deba admitirlo.

Hay una decision funcional pendiente: conservar R044 como codigo alfanumerico
en esta ruta o corregir/reclasificar el documento origen si no corresponde.
La version Oracle de INVOICE_TO_FACTURA usa TO_NUMBER(Det.Material), por lo
que aceptar R044 seria una ampliacion explicita del comportamiento, no una
simple traduccion de sintaxis. Si se confirma su validez en esta ruta, el
diseno propuesto es mantener la normalizacion numerica actual para materiales
numericos (quitar ceros iniciales) y conservar el texto alfanumerico para los
demas, usando la misma expresion en SELECT, JOIN y GROUP BY. No perder la fila,
convertir el material a NULL/0 ni alterar importes para sortear el error.

Estado: causa tecnica confirmada; pendiente confirmar la regla funcional antes
de modificar la normalizacion del material o el enrutamiento del documento.

Nueva captura 22/10/2026 14:57:03: el prefijo contiene 15 Customer, 466 Invoice,
7 Invoice-Intercompany, 496 Payment, 28 Product y 880 VanReplenishment; total
1,892. Se confirma que la muestra Payment anterior no describia todo el grupo.
El documento 1658415284 sigue ausente por los criterios consultados. Las 50
cabeceras Invoice mostradas estan Received, PROCESSED NULL y REFERENCE NULL,
pero tienen DocumentNumber legible en XML. No se extrapola su estado a las 466.

Se preparo 07_REVISAR_MATERIALES_DEL_GRUPO.sql para revisar los materiales de
las 466 Invoice y correlacionarlos con los errores 8114 reales de hoy. Es una
consulta acotada y de lectura; aun no se atribuye el error a un material concreto
ni se altera la regla Oracle de conversion numerica.

Al revisar nuevamente RECV_INVOICE instalado se confirmo que el filtro
`R.CREATED > DATEADD(DAY,-5,...)` esta **comentado** en su linea 63. Por tanto
la version desplegada selecciona Invoice con PROCESSED NULL sin ese limite
de fecha; difiere del fuente local y de la suposicion del diagnostico 05.
Esto permite que los errores actuales correspondan a documentos ajenos al
prefijo liberado. No se cambia ese comportamiento como parte del diagnostico.
El script 07 busca tambien 1658415284 entre pendientes fuera del prefijo,
sin fecha y sin abrir detalles de mensajes no coincidentes, y lo identifica
separadamente en la salida. Esa busqueda adicional puede leer varios headers XML.

Captura posterior de 06, 22/10/2026 14:54:28: 1,892 mensajes del prefijo
202610060%, con CREATED entre 2026-10-06 00:07:04 y 09:57:36. No encontro el
DocumentNumber 1658415284. Las 50 cabeceras de muestra son Payment, procesadas
el 21 de octubre; no son documentos del flujo RECV_INVOICE. No se deduce que
todo el grupo sea Payment porque la muestra esta limitada y ordenada por ROW_ID.
Se ajusto 06 para agrupar el conteo por QUEUE_NAME, mostrar solo Invoice,
y buscar tambien la referencia por REFERENCE/DOCNUM fuera del prefijo.
La causa 8114 sigue sin confirmarse con un valor real de material.

Contexto adicional del usuario: libero facturas cuyos identificadores cumplen
`ROW_ID LIKE '202610060%'`. Se ajusto el script 06 para localizar el documento
1658415284 dentro de ese grupo sin filtrar CREATED/PROCESSED. El prefijo sugiere
una fecha, pero no permite afirmar CREATED ni cual UPDATE uso para liberarlas.
No inferir que debe cambiarse la ventana de RECV_INVOICE: primero observar las
fechas y el XML con la consulta de lectura. La busqueda por prefijo se probo
en LocalDB con un mensaje antiguo y procesado, sin valor de Reference.

Actualizacion de evidencia: captura de AZCRNMXNEVTD06/T3QA del 22/10/2026 a las
14:44:22, referencia 1658415284. Registra 8114 en los PID 26515580 (14:29:42),
26515581 (14:36:06) y 26515582 (14:38:17), precedidos de 3930 en los dos PID
anteriores. No se asumen documentos diferentes por cada reintento.

Los tipos instalados de TMP_DOCUMENT_DETAIL, FACTURA_DETALLE, MATERIAL y
MX_HASHTABLE coinciden con los revisados. Las cantidades/importes/linea son
numericos y Material es varchar(18). No se devolvieron filas de temporal ni
mensajes de origen por los filtros de 05. No interpretar una salida vacia como
material valido, material vacio o prueba de una eliminacion definitiva.

Se preparo 06_LOCALIZAR_ORIGEN_8114.sql para buscar REFERENCE/DOCNUM sin
restriccion de fecha, cola o estado; abre XML solo de coincidencias. Si no
aparece, se requiere ROW_ID/ItemData del mensaje original. No se modifica la
conversion de negocio sin evidencia. Otra posibilidad a revisar con el plan
si el material del documento resulta valido es la evaluacion adelantada de
conversiones sobre filas ajenas por el optimizador; no esta demostrada.

El usuario reporto SQL-8114, linea 195 de EAI_OWNER.INVOICE_TO_FACTURA,
sin referencia ni dato origen. En la definicion instalada recibida esa linea
inicia DetailBase y toda la sentencia CTE/INSERT del detalle. Dentro existen
conversiones explicitas de Det.Material varchar a numeric(38,0), repetidas en
SELECT, JOIN, subconsultas de Material y GROUP BY. Son candidatos a 8114, pero
la linea no prueba cual expresion ni valor concreto fallo.

El DDL del repositorio declara numericos ItemID, cantidades e importes temporales;
Material es varchar(18). Deben comprobarse los tipos instalados antes de excluir
otras conversiones implicitas. El Oracle original tambien usa
TRIM(TO_NUMBER(Det.Material)); no es valido eliminar la validacion numerica o
usar TRY_CONVERT para guardar NULL/0 silenciosamente y seguir con la factura.

Se preparo el script de lectura 05_DIAGNOSTICO_8114_FACTURA.sql. Localiza el
ultimo error de la ruta o acepta una referencia manual, lee detalle si queda,
y recupera los MaterialID con ObjectIdentification=002 del XML recibido.
Este respaldo es necesario porque el padre revierte la carga temporal y puede
revertir tambien el campo Reference de la cola. Los TRY_CONVERT se usan solo
para diagnosticar, no para alterar los datos ni su procesamiento.

Estado: diagnostico validado en LocalDB; pendiente evidencia del valor real
para decidir la correccion. No se modifico INVOICE_TO_FACTURA por este 8114.

## Causa posterior identificada: 2628 en REMISION_GENERAL

Tras la correccion 3930, el usuario reporto SQL-2628 en T3.DELIVERY_WA_OXXO,
linea 187: truncamiento de T3QA.T3.REMISION_GENERAL.REMISION_FOLIO, con prefijo
de valor `VPGG31G10930163`. El numero 187 coincide con el INSERT de la definicion
instalada previamente recibida.

Se encontro INSERT sin lista de columnas. Contrastando los 29 valores con el
DDL del repositorio, el orden coincide hasta CODIGOPOSTAL (posicion 16), pero
el procedimiento envia SHIPTOPARTY/RFC antes de los campos de DESTINO. La tabla
tiene esos dos campos al final. En consecuencia, la posicion 27 asigna
@Observaciones a REMISION_FOLIO; las posiciones 28/29 asignan serie/folio a
SHIPTOPARTY/RFC. Los campos de destino tambien quedan desalineados.

No deducir que el prefijo mostrado por 2628 es el folio completo ni que basta
ampliar REMISION_FOLIO. La variable @sRem_Folio del procedimiento se obtiene
con SUBSTRING de hasta 10 caracteres; el DDL declara el destino varchar(15).
El problema identificado es el mapeo por posicion, no el tamano de ese folio.

Se corrigio el fuente con columnas explicitas, manteniendo los mismos valores.
Se preparo RECV_INVOICE_3930/04_CORREGIR_COLUMNAS_REMISION.sql para aplicar solo
esa lista al modulo instalado, con respaldo, guardas y reversion por RunId.
Conserva la correccion 3930; no modifica tamanos ni reglas de construccion del folio.

Pruebas LocalDB: se reprodujo 2628 en REMISION_FOLIO con la sentencia anterior;
tras el parche se inserto la observacion completa y se verificaron las columnas
de origen/destino, serie/folio, ShipTo y RFC. Pasaron idempotencia y reversion.
No se desplego el script 04 en T3QA desde el agente; falta ejecucion del usuario.
Este error es una causa concreta ahora visible, pero no demuestra que explique
todas las referencias de los dos lotes ni todos los errores previos.

## Correccion preparada y probada el 22 de octubre de 2026

El usuario autorizo corregir el error y preparar los scripts a ejecutar.
Se agrego el guard RI3930_PROPAGATE_V1 al inicio del CATCH de los cuatro
fuentes: INVOICE_TO_PREVENTA, INVOICE_TO_FACTURA, INVOICE_TO_ENTREGA_PO y
DELIVERY_WA_OXXO. No se alteraron los fuentes de RECV_INVOICE ni de su padre
SF_PROC_PREINVOICE_IFC como parte de este cambio.

El paquete [RECV_INVOICE_3930](RECV_INVOICE_3930/README.md) contiene:

- 01_CORREGIR_CATCH.sql: modifica de forma atomica los cuatro modulos
  instalados en T3QA, respaldando sus definiciones. Conserva otros cambios
  de negocio existentes y rechaza firmas/opciones/casos no previstos.
- 02_VERIFICAR_RESULTADO.sql: lectura del guard y de los errores nuevos despues
  de la siguiente ejecucion normal del job.
- 03_REVERTIR_SOLO_SI_ES_NECESARIO.sql: reversion por RunId, con verificacion de
  hash para no sobrescribir despliegues posteriores. No es parte del flujo normal.

Las pruebas de LocalDB reprodujeron 3930 antes del parche y 547 original tras
el parche en los cuatro CATCH reales, con errores controlados. Tambien verificaron
transaccion confirmable, exito, contrato sin transaccion, hijos anidados,
idempotencia, respaldos y reversion. No es una prueba integral de los XML/datos
reales ni de todas las dependencias de negocio. Ver README del paquete.

Estado al preparar esta entrega: corregido en archivos y validado en LocalDB;
pendiente ejecucion manual de 01 y 02 en T3QA. No se desplego en produccion.
Todavia debe observarse y resolverse la causa de negocio que el 3930 ocultaba.

## Confirmacion con definiciones completas: captura 14:12:22

La tercera captura aportada por el usuario corresponde a AZCRNMXNEVTD06/T3QA,
2026-10-22 14:12:22 -06:00. Contiene los seis modulos por lineas/fragmentos,
permitiendo revisar los CATCH desplegados. Esta evidencia reemplaza la limitacion
de definiciones truncadas descrita en la segunda captura mas abajo.

| Modulo instalado | Evidencia en la definicion exportada |
|---|---|
| EAI_OWNER.RECV_INVOICE | SET XACT_ABORT OFF, delega por mensaje al padre; con transaccion externa o estado invalidado propaga la excepcion. |
| EAI_OWNER.SF_PROC_PREINVOICE_IFC | Inicia transaccion si no la habia; SAVEPOINT si es externa. En CATCH revierte la propia (lineas 813-814) o savepoint solo si XACT_STATE=1. Con transaccion externa relanza. Tras rollback propio registra el error en linea 836. |
| EAI_OWNER.INVOICE_TO_PREVENTA | SET XACT_ABORT ON (42); CATCH inicia en 691; INSERT al log en 718 sin comprobar la transaccion; THROW en 727, despues del INSERT. |
| EAI_OWNER.INVOICE_TO_FACTURA | CATCH en 379 e INSERT al log en 383 sin comprobar la transaccion; no relanza despues de registrar. |
| EAI_OWNER.INVOICE_TO_ENTREGA_PO | CATCH en 164 e INSERT al log en 177 sin comprobar la transaccion; no relanza al final. |
| T3.DELIVERY_WA_OXXO | CATCH en 301 e INSERT al log en 305 sin comprobar la transaccion; no relanza al final. |

Las lineas 718 y 383 coinciden exactamente con los errores 3930 reportados.
Queda confirmado que esos errores ocurren al intentar registrar otra excepcion
en los CATCH, no en las sentencias que originalmente procesaban la factura.

El flujo confirmado para las transacciones propias del padre es:

1. Ocurre una excepcion previa en el procesamiento del hijo o sus dependencias.
2. Se intenta registrar desde el CATCH del hijo mientras la transaccion esta
   no confirmable. Ese INSERT falla con 3930 y oculta la excepcion previa.
3. El padre captura el nuevo error, revierte su transaccion y registra el 3930
   con la referencia y PID; de ahi que las filas de log finales si persistan.
4. Sin transaccion externa, el padre termina tras registrar para que la cola
   gestione el reintento. Esto permite continuar con otras referencias en el
   mismo lote y volver a encontrar mensajes pendientes en ejecuciones posteriores.

No se recupero la excepcion inicial. No atribuirla a un indice, una conversion,
restriccion o documento concreto solo con este resultado. Corregir la propagacion
hara visible esa causa en una prueba controlada; no garantiza resolverla aun.

### Correccion propuesta, limitada al manejo de errores

En los cuatro hijos, antes de cualquier INSERT de su CATCH, propagar la excepcion
cuando hay una transaccion activa, para que su propietario decida el rollback:

```sql
-- Dentro del CATCH, antes de escribir la bitacora.
IF @@TRANCOUNT > 0
BEGIN
    THROW;
END;
```

Esto cubre tanto XACT_STATE=-1 (no permite escritura) como XACT_STATE=1 (el
padre tampoco debe confirmar un documento que el hijo no pudo completar).
Si se aplica solo para estado -1, persistiria el riesgo de confirmar cambios
incompletos cuando un error deje la transaccion confirmable y el hijo lo oculte.
El punto exacto debe respetar la limpieza de cursores locales, sin ejecutar
escrituras antes del guard. Los cursores LOCAL tambien se liberan al salir del
procedimiento. Para invocaciones sin transaccion, se puede mantener el registro
actual; revisar por separado excepciones que reviertan por si mismas toda la
transaccion y los contratos de otros llamadores antes de generalizar la politica.

No introducir ROLLBACK total en esos hijos, ni desactivar XACT_ABORT para
silenciar el sintoma. En esta ruta el padre ya contiene el rollback y el formato
de registro con numero, linea y procedimiento. No cambiar RECV_INVOICE ni sus
reglas de seleccion/reintento como parte de esta correccion inicial.

### Diferencias de version que deben conservarse

La definicion instalada de SF_PROC_PREINVOICE_IFC contiene bloques
`RI_REF_SEEK_TMP_DOCUMENT_HEADER`, `RI_REF_SEEK_TMP_DOCUMENT_DETAIL` y
`RI_REF_SEEK_TMP_DOCUMENT_CONDITIONS`, ausentes del archivo local revisado.
No reemplazar el padre completo desde el repositorio para corregir los CATCH.
Preparar un cambio acotado sobre las definiciones instaladas de los hijos,
con verificacion de version, para no perder ajustes existentes.

DELIVERY_WA_OXXO instalado tambien difiere del local: en su CATCH usa la columna
`ID` del log, mientras el local usa `REFERENCE`. No se recibio el DDL completo
actual de esa tabla para afirmar si ID es valido; no se considera causa probada.
Es otra razon para evitar un redespliegue completo sin contrastar definiciones.

### Validacion requerida del cambio antes de desplegar

- Error de negocio controlado dentro de transaccion propia: el padre debe
  registrar la causa original tras rollback, sin 3930 ni datos parciales.
- Error con transaccion externa: la causa debe llegar al llamador, sin rollback
  total ejecutado por el hijo; si XACT_STATE=-1, el llamador debe revertir todo.
- Error con transaccion aun confirmable: debe propagarse al padre, para evitar
  que este confirme el documento incompleto.
- Ruta exitosa sin cambios en resultados ni contador transaccional.
- Invocaciones directas de los hijos sin transaccion: comprobar su contrato de
  logging actual y los errores del propio log por separado.

Estado de esa captura: analisis confirmado; no se habian modificado los fuentes.
La correccion autorizada posteriormente se documenta al inicio de este informe.

## Alcance confirmado y segunda captura

El usuario solicito enfocar el analisis exclusivamente en
`EAI_OWNER.RECV_INVOICE` y sus dependencias para los errores del 22 de octubre
de 2026. El seguimiento se limita a RECV_INVOICE, SF_PROC_PREINVOICE_IFC,
INVOICE_TO_PREVENTA, INVOICE_TO_FACTURA, INVOICE_TO_ENTREGA_PO y
T3.DELIVERY_WA_OXXO. No se analizan otras colas o procesos en este incidente.

La segunda captura identifica AZCRNMXNEVTD06/T3QA, tomada el 22 de octubre a
las 14:08:39 -06:00, ventana consultada 13:45 a 14:10. El resultado refleja
lo registrado hasta ese momento de captura, no los minutos posteriores.

| JOB_PID | Errores 3930 en ventana | Referencias distintas por lote | Primero | Ultimo |
|---|---:|---:|---|---|
| 26515578 | 70 | 44 | 13:56:59 | 13:59:48 |
| 26515579 | 186 | 160 | 14:00:10 | 14:08:12 |

Total: 256 filas de error. Las referencias distintas no se suman como documentos
unicos entre lotes, porque pueden repetirse. El detalle TOP(200) no muestra las
256 filas completas; los conteos anteriores proceden del resumen agrupado.
No aparece en el resultado aportado una causa anterior distinta de 3930
atribuible a esta cadena. Esto no demuestra que no haya ocurrido: pudo no
registrarse por el fallo del INSERT o desaparecer con el rollback.

Los seis modulos existen y reportan uses_ansi_nulls=1 y
uses_quoted_identifier=1. No basta para conocer todas las opciones SET de
ejecucion, ni para excluir fallos en procedimientos/SQL dinamico mas profundos.
Las definiciones exportadas solo contienen unos 256 caracteres iniciales por
modulo; no permiten verificar sus CATCH desplegados. No afirmar que el codigo
instalado sea identico al repositorio a partir de esos fragmentos.

No aparecen cabeceras temporales de las cuatro referencias consultadas. Es
compatible con rollback de su carga, pero tambien con limpieza u otro estado
de los datos; no identifica por si solo la causa del error.

Siguiente evidencia requerida: ejecutar
`RECV_INVOICE_DEPENDENCIAS_DEFINICIONES.sql`, solo lectura, para extraer los
seis modulos completos en lineas/fragmentos de 180 caracteres. Con ello se
podra preparar una correccion precisa de propagacion y registro del error
original, sin modificar la logica de negocio ni ejecutar reintentos masivos.

Fuente: extracto de MX_EAI_MESSAGE_LOG aportado por el usuario el 22 de octubre
de 2026. No se consulto la instancia ni se modificaron procedimientos o datos.
El servidor/base del extracto no estan identificados.

## Evidencia observada

- 100 errores: 87 identifican INVOICE_TO_PREVENTA y 13 INVOICE_TO_FACTURA.
  QUEUE_NAME=PROC_PREINVOICE_IFC, JOB_PID 26515578 y 26515579.
- Error 3930 en multiples referencias, con repeticiones de algunas referencias
  dentro de un lote y entre ambos lotes.
- El mensaje identifica INVOICE_TO_PREVENTA, linea 718, o INVOICE_TO_FACTURA,
  linea 383. Confirmar esas lineas contra la definicion realmente desplegada:
  ERROR_LINE no necesariamente coincide con la numeracion del archivo local.
- El query del usuario obtiene las ultimas 100 filas. No incluye necesariamente
  el primer error ni todos los mensajes de cada ejecucion.

JOB_PID es el identificador logico del proceso, no el SPID de SQL Server.
Dos PID distintos no prueban concurrencia. Repeticiones por referencia no
prueban por si solas duplicidad incorrecta: pueden proceder de varios mensajes
de origen y reintentos. El extracto no muestra sus ROW_ID ni XML de origen.

## Mecanismo encontrado en el codigo local

SF_PROC_PREINVOICE_IFC abre una transaccion propia si el llamador no tiene una,
o crea un savepoint si ya existe una transaccion. Despues delega a los
procedimientos de negocio INVOICE_TO_PREVENTA o INVOICE_TO_FACTURA.

INVOICE_TO_PREVENTA activa XACT_ABORT ON. En su CATCH intenta insertar en
MX_EAI_MESSAGE_LOG antes de THROW, sin comprobar XACT_STATE. Si el error previo
deja XACT_STATE=-1, ese INSERT falla con 3930 y el THROW original no se alcanza.
El padre recibe el error del INSERT de bitacora, no la excepcion inicial.

INVOICE_TO_FACTURA tambien intenta insertar en el log desde CATCH sin comprobar
XACT_STATE; ademas, su CATCH actual no relanza cuando el registro si funciona.
INVOICE_TO_ENTREGA_PO y DELIVERY_WA_OXXO contienen un patron similar y son
dependencias del flujo. Un fallo puede ocultarse en mas de un nivel.

El CATCH de SF_PROC_PREINVOICE_IFC revierte antes de escribir su log cuando la
transaccion es propia. Esto explica que la fila final pueda persistir con
QUEUE_NAME=PROC_PREINVOICE_IFC aunque el hijo no pudiera escribirla: el padre
ya revirtio para ese momento. Con transaccion externa el padre propaga el error
sin intentar el INSERT. Verificar que estas versiones coincidan en el servidor.

## Conclusiones y limites

El codigo contiene un defecto de manejo de errores capaz de sustituir la causa
original por 3930. El extracto es consistente con ese defecto, pero no permite
identificar la sentencia de negocio inicial que invalido la transaccion.

No hay evidencia para atribuirlo a falta de espacio del log, a los dos indices
creados para PROC_CFDI_PROCESAR_DOCTOS o a un documento concreto. 3930 indica
que se intento escribir/confirmar una transaccion no confirmable; no demuestra
por si solo un problema fisico del transaction log.

Las pruebas de RECV_INVOICE_TRANSACTIONS del repositorio verifican el control
transaccional de RECV_INVOICE y SF_PROC_PREINVOICE_IFC, pero su README excluye
las rutas completas de INVOICE_TO_PREVENTA e INVOICE_TO_FACTURA. No cubren este
INSERT fallido de los CATCH de los hijos.

## Accion recomendada

1. Ejecutar PREINVOICE_ERROR_3930_DIAGNOSTICO.sql en la base del incidente para
   obtener los primeros mensajes y las definiciones instaladas. Es de lectura.
2. Corregir el manejo transaccional de los CATCH de la cadena para preservar
   ERROR_NUMBER/ERROR_LINE/ERROR_PROCEDURE/ERROR_MESSAGE y propagar la causa
   antes de intentar escribir en una transaccion invalidada. El propietario de
   la transaccion debe revertirla y registrar despues; no introducir ROLLBACK
   total indiscriminado en un hijo que no es propietario de la transaccion.
3. Atender tambien fallos con XACT_STATE=1: si un hijo oculta un error, el padre
   puede confirmar un documento incompleto. Cambiar esa semantica requiere
   revisar los llamadores y las reglas Oracle, no solo agregar un IF al INSERT.
4. Probar la ruta completa en QA con una violacion controlada: debe persistir
   la causa original tras rollback, no 3930, sin marcar el documento como exito
   y conservando la propiedad de transacciones externas.
5. Con la causa original visible, resolver la regla/dato/dependencia que falla
   antes de un reproceso masivo. El diagnostico no ejecuta reintentos.

Referencia: [Microsoft: TRY/CATCH y transacciones no confirmables](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql).

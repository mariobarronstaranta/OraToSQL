# Correccion de 3930 en los CATCH del flujo RECV_INVOICE

## Correccion vigente 8114: detalle vacio autorizada por el usuario

El usuario autorizo que, si un material no convierte a NUMERIC(38,0),
DetailBase devuelva cero filas para TODA la factura y continue el procedimiento.
Esta decision reemplaza la restriccion pendiente descrita en el historial inferior.
No se inserta una parte de una factura mixta ni se acepta R044 como material numerico.

1. En T3QA, sin ejecuciones concurrentes del job, ejecutar completo
   **08_DETAILBASE_VACIO_MATERIAL_INVALIDO.sql**. Mantener @Aplicar=1.
   Requiere el manejo de errores y tabla de respaldo del script 01 ya instalados.
   No es necesario repetir 01 ni 04 si ya estan aplicados.
2. Conservar el RunId que devuelve 08. El parche modifica unicamente DetailBase
   de la definicion instalada; conserva los demas cambios y no reintenta documentos.
3. Despues de la siguiente ejecucion normal del job, ejecutar
   **02_VERIFICAR_RESULTADO.sql**. Incluye EstadoMaterial para verificar 08.
   Comprobar ademas que el mensaje afectado avance de estado y los datos resultantes:
   ausencia de errores por si sola no prueba que el job haya procesado el documento.
4. Solo si se necesita revertir 08, usar **03_REVERTIR_SOLO_SI_ES_NECESARIO.sql**
   indicando el RunId de 08. Restaura el estado inmediatamente anterior a ese parche.

Las cinco conversiones de Det.Material usan TRY_CONVERT y NOT EXISTS valida
solo los detalles con ReferenceID=@sInvoiceID. NULL mantiene el comportamiento
anterior. Cadenas vacias y numeros fuera de NUMERIC(38,0) tambien omiten el detalle,
porque su conversion original fallaba. Facturas validas mantienen el calculo previo.

**Consecuencia funcional:** el encabezado persiste sin detalle; los SUM existentes
sobre ese conjunto vacio dejan sus totales en NULL. Luego se ejecutan las instrucciones
posteriores, incluidas Procesado e INVOICE_TO_ENTREGA_PO. Otros errores posteriores
pueden revertir la transaccion; este parche evita especificamente el 8114 de material.
No registra el material omitido como una nueva excepcion ni cambia otras reglas.

Validacion: `tests/Run_DetailBase.ps1` ejecutado satisfactoriamente en LocalDB,
con collation distinta de la instancia, CTE/INSERT reales y DDL real de FACTURA_DETALLE.
Reproduce 8114 antes del parche; prueba R044, factura mixta, desbordamiento,
cadena vacia, NULL, equivalencia completa del detalle numerico y siguiente factura,
continuidad posterior al CTE, transaccion, vista previa, idempotencia y reversion.
Aisla el CTE en un procedimiento de prueba: no ejecuta el coordinador completo ni
las dependencias de entrega. Base temporal eliminada. Pendiente aplicar y validar
con datos reales en T3QA; no desplegado remotamente por esta entrega.

## Historial diagnostico previo a la autorizacion

## Seguimiento: 8114 en INVOICE_TO_FACTURA, linea 195

**Causa confirmada:** salida de 07 a las 15:02: la factura 1658415284 tiene
ROW_ID 20261002121244302218000302218000 y material R044 en ItemNumber
000010/000010. Es el unico material no convertible entre 2,081 filas revisadas
y corresponde a los tres errores 8114 de hoy. Ya no hace falta repetir las
busquedas de origen para este caso.

R044 existe en datos historicos del proyecto como OTHER RECHARGE y en logs de
catalogo EXPO. Confirmar si debe admitirse como codigo alfanumerico en esta
ruta o si el documento requiere otro tratamiento. Oracle tambien usa TO_NUMBER:
no aplicar un cambio de regla, convertir a NULL/0 ni omitir la linea sin esa
decision funcional. No se ha generado/aplicado un parche de material todavia.

La captura de 06 de las 14:57 confirma 466 Invoice dentro de los 1,892 mensajes
del prefijo. No localiza 1658415284. El script
**07_REVISAR_MATERIALES_DEL_GRUPO.sql** revisa materiales de todos esos Invoice
y los cruza con los 8114 de hoy. Solo abre XML del grupo materializado y no
cambia el proceso. No concluir que el material de la referencia ausente es
incorrecto basandose en un error de otro documento.

Ademas, 07 busca la referencia objetivo 1658415284 entre Invoice pendientes
fuera del prefijo sin fecha. Se comprobo que RECV_INVOICE instalado tiene
comentado el filtro de cinco dias; su seleccion puede incluir otros grupos
historicos. La busqueda adicional puede leer varios headers XML; solo agrega
los mensajes coincidentes al analisis de materiales. La salida separa el
conteo del prefijo de las coincidencias adicionales. No se reactiva ni modifica
el filtro del job como parte de estos scripts de lectura.

La salida recibida de 05 (T3QA, 22/10/2026 14:44) confirma la referencia
1658415284 y los tipos de columnas, pero no devolvio detalle ni XML. Por tanto
todavia no se conoce el material responsable. Ejecutar **06_LOCALIZAR_ORIGEN_8114.sql**
para buscar por REFERENCE/DOCNUM sin fecha/estado, sin volver a recorrer XML
masivamente. Si tampoco aparece, se necesita ROW_ID o los ItemData originales.

Actualizacion del usuario: las facturas liberadas corresponden a
`ROW_ID LIKE '202610060%'`. El script 06 ahora prioriza ese prefijo y busca
DocumentNumber=1658415284 dentro de ese grupo, sin fecha/estado/cola. Reporta
MIN/MAX(CREATED) reales del grupo; el prefijo no se considera prueba de fecha.
Si no encuentra ese documento, devuelve hasta 50 cabeceras del grupo para
identificarlo. Poner @RowIdPatron=NULL activa la alternativa REFERENCE/DOCNUM.
Se valido en LocalDB con mensaje de fecha antigua, ya procesado y Reference NULL.

La captura de 06 de las 14:54 no encontro el documento; las 50 filas de muestra
eran Payment. La consulta se ajusto para separar conteos por cola y mostrar
unicamente Invoice, sin atribuir a todo el prefijo la cola de esa muestra.
Si el documento no esta en el prefijo, intenta tambien REFERENCE/DOCNUM en
Invoice fuera del grupo. Si tampoco aparece, se necesita su ROW_ID exacto.

El usuario reporto una conversion varchar/numeric en la sentencia del detalle.
La linea instalada 195 inicia el CTE entero, por lo que no identifica por si sola
la expresion exacta. Un candidato explicito es la conversion repetida
`CONVERT(NUMERIC(38,0),TRIM(Det.Material))`. El Oracle original usa TO_NUMBER:
no se puede aceptar material alfanumerico ni convertirlo a NULL/0 sin una regla
de negocio y evidencia del documento.

Ejecutar **05_DIAGNOSTICO_8114_FACTURA.sql** en T3QA y compartir todas las salidas.
Por defecto toma la referencia del ultimo error 8114 de hoy en esa ruta; se puede
indicar manualmente @Referencia. Comprueba tipos instalados y detalle temporal,
y obtiene materiales del XML recibido cuando el rollback ha vaciado temporales
y deshecho Reference. La busqueda de respaldo lee XML de pendientes Invoice
de los ultimos cinco dias; no ejecuta ni reintenta el proceso.

El diagnostico se probo en LocalDB con temporal vacio, Reference NULL y materiales
numerico/no numerico. Recupera el documento por DocumentNumber y senala el
material no convertible sin provocar 8114. No se ha aplicado una correccion de
negocio para este error: falta conocer el valor real y la referencia afectada.

## Continuacion: causa 2628 expuesta en REMISION_GENERAL

Tras aplicar 01, el usuario reporto SQL-2628 en DELIVERY_WA_OXXO, linea 187,
columna REMISION_FOLIO. El INSERT instalado era posicional y sus valores no
seguian el orden fisico del DDL: @Observaciones se asignaba a REMISION_FOLIO.
Otros campos de destino, serie, RFC y ShipTo tambien quedaban cruzados.

Con 01 ya aplicado, ejecutar **04_CORREGIR_COLUMNAS_REMISION.sql** en T3QA,
sin ejecuciones del job ni despliegues simultaneos. Solo agrega la lista de
29 columnas correspondiente a los valores existentes, conservando el modulo
instalado y el guard 3930. No recorta valores ni amplia la tabla. Guarda otro
RunId en la misma tabla de respaldo. No es necesario repetir 01.

Despues de la siguiente ejecucion normal del job, ejecutar nuevamente **02**
y compartir los errores nuevos. 02 tambien muestra el marcador del parche 04.
El script 03 permite revertir 04 con su RunId, conservando la version anterior
que ya tenia el guard 3930. Si se requiere revertir ambos cambios, hacerlo en
orden inverso de aplicacion; los hashes rechazan sobrescribir cambios posteriores.

`tests/Run_Remision.ps1` reproduce el 2628 usando el DDL real del repositorio
y el INSERT anterior. Despues de 04 verifica el mapeo de los campos, la observacion
completa, el folio correcto y que REMISION_FOLIO siga siendo varchar(15).
Tambien valida vista previa, idempotencia y reversion sin perder el guard 3930.
Es una prueba del INSERT, no del procedimiento completo con todas sus dependencias.

El parche no repara automaticamente registros historicos que hubieran entrado
con campos desalineados. Si los hubo, revisar su alcance antes de una correccion
de datos; no actualizar ni reprocesar masivamente solo con este hallazgo.

Preparada para T3QA a partir de las definiciones aportadas el 22 de octubre de
2026. La correccion esta lista en el repositorio; el agente no la desplego en
T3QA ni en produccion.

## Que ejecutar

1. Elegir una ventana sin ejecuciones del job RECV_INVOICE ni cambios concurrentes
   a sus dependencias. En SSMS seleccionar **T3QA**, sin transaccion abierta.
2. Ejecutar completo **01_CORREGIR_CATCH.sql**. Tiene @Aplicar=1; para una vista
   previa sin cambios se puede poner en 0. Conservar la salida, incluido RunId.
   Debe devolver los cuatro procedimientos como aplicados o ya corregidos.
3. Esperar la siguiente ejecucion normal del job y ejecutar completo
   **02_VERIFICAR_RESULTADO.sql**. Compartir todos sus resultados. No inicia el
   job ni hace reintentos por si mismo.

El script 01 aplica la correccion sobre las definiciones **instaladas**. Es la
opcion de despliegue para este incidente: evita sobreescribir variantes locales
de negocio o los ajustes RI_REF_SEEK de SF_PROC_PREINVOICE_IFC. No es necesario
ejecutar completos los cuatro fuentes ni desplegar el padre/coordinador.

Si ocurre un error al alterar cualquiera de los cuatro modulos, se revierte
toda esa aplicacion. El respaldo tambien forma parte de la misma transaccion.
Los permisos de ejecucion existentes del procedimiento se conservan al usar
ALTER. Si un modulo esta firmado, el script se detiene antes de cambiarlo para
que se prepare su refirma. Tambien se detiene ante definiciones invisibles,
opciones ANSI/QUOTED diferentes de la captura o CATCH ambiguos.

El script requiere lectura de definiciones, ALTER de los cuatro procedimientos,
y permisos para crear/usar la tabla de respaldo en EAI_OWNER. No concede permisos.
Las dos guardas de base exigen T3QA: no ejecutar en produccion como parte de esta
prueba. El estado de los indices en produccion no implica que esta correccion
de errores ya este desplegada alli.

## Cambio de comportamiento

Se inserta al principio del CATCH de estos cuatro procedimientos:

- EAI_OWNER.INVOICE_TO_PREVENTA
- EAI_OWNER.INVOICE_TO_FACTURA
- EAI_OWNER.INVOICE_TO_ENTREGA_PO
- T3.DELIVERY_WA_OXXO

```sql
IF @@TRANCOUNT > 0
BEGIN
    THROW;
END;
```

Con una transaccion activa, el hijo conserva el error original y lo propaga
antes de intentar escribir en bitacora. El propietario decide el rollback.
Para RECV_INVOICE, SF_PROC_PREINVOICE_IFC ya revierte su transaccion y registra
numero/linea/procedimiento. Con transaccion externa, la excepcion llega al
llamador sin rollback total iniciado por los hijos.

La guarda tambien propaga errores cuando la transaccion aun es confirmable:
evita que un hijo oculte un fallo y que el padre confirme un documento incompleto.
Esta es una diferencia intencional para cualquier otro llamador que tambien
ejecute esos hijos dentro de una transaccion. Los cursores locales se liberan
al salir del procedimiento. La ruta sin transaccion conserva el comportamiento
de registro existente; no se cambia XACT_ABORT ni la logica de negocio.

Esto corrige el **enmascaramiento** por 3930. Puede aparecer ahora el error de
datos/regla/dependencia que estaba oculto y que requerira una correccion posterior.
Si no hay errores nuevos en la consulta de verificacion, comprobar que el job
efectivamente haya corrido: una salida vacia no acredita procesamiento exitoso.

## Respaldo y reversion

El script 01 conserva las definiciones previas, su version ALTER y el hash de
la version corregida en **EAI_OWNER.RECV_INVOICE_3930_BACKUP**, con RunId,
usuario y fecha. La tabla se deja en T3QA como evidencia; no se elimina al final.
Reejecutar 01 no duplica el parche ni crea otro respaldo de modulos ya corregidos.

**03_REVERTIR_SOLO_SI_ES_NECESARIO.sql no forma parte de la ejecucion normal.**
Para volver al estado anterior, indicar el RunId recibido y ejecutarlo en T3QA
en una ventana equivalente. Verifica que las definiciones no cambiaron despues
de aplicar el parche; si cambiaron, rechaza la reversion en vez de sobrescribirlas.
Revertir restablece tambien el manejo de errores defectuoso anterior.

## Validacion realizada

`tests/Run.ps1` usa una base temporal LocalDB con collation diferente de la
instancia y los CATCH reales de los cuatro fuentes. El TRY se sustituye por
errores controlados para aislar el mecanismo; no es una prueba integral de XML,
facturas, triggers o reglas fiscales. La base temporal se elimina al terminar.

Casos probados:

- Reproduccion de 3930 antes del parche en los cuatro CATCH.
- Despues del parche: propagacion de 547 original, nombre de procedimiento y
  transaccion no confirmable, sin datos parciales despues del rollback del llamador.
- Error 50000 con transaccion confirmable: se propaga, preservando los cambios
  anteriores del llamador hasta que este decide revertir.
- Ruta exitosa conserva transaccion y datos esperados.
- Sin transaccion externa: conserva registro y contrato de propagacion previo.
- Dos hijos anidados: conserva la causa y permite registrar despues del rollback.
- Vista previa sin tabla persistente, aplicacion de los cuatro modulos,
  idempotencia, variantes de declaracion CREATE/CREATE OR ALTER y espacios/tabs.
- Reversion completa y rechazo ante cambios posteriores (51205 es esperado en
  esa prueba negativa).

Falta validar con el job y los datos reales de T3QA despues del despliegue manual.

# Validacion local de los scripts

Correccion de collation de metadatos del28/10: Run.ps1 finalizo con codigo0
en CodexLibPagoDiag_c767cdc56b; base temporal eliminada. Reportes en
tmp/liberacion_pago_diag_CodexLibPagoDiag_c767cdc56b.
Todos los casos anteriores pasaron junto con dos nuevas comprobaciones:

- 09A reproduce el error468 del diagnostico anterior forzando la collation
  de @Accesos.Columna distinta de la de sys.columns.name. Se ejecuta la
  copia anterior mediante SQL dinamico para capturar ese error de compilacion;
  la prueba falla si no obtiene exactamente468.
- 09B ejecuta el diagnostico completo con esa misma diferencia de metadatos
  y con `C.name COLLATE DATABASE_DEFAULT=A.Columna COLLATE DATABASE_DEFAULT`.
  Termina con TRACE_ASSERTS_OK y mantiene los conteos de las etapas.

La prueba anterior cubria columnas de negocio con collations mezcladas,
pero no esta diferencia entre el catalogo y una variable de tabla. Se
agrego el caso faltante sin modificar SP ni collations de la base real.

Actualizacion para el rastreo06: Run.ps1 finalizo con codigo 0 en
CodexLibPagoDiag_5c31b7fa6e. La base temporal se elimino al finalizar.
Reportes en tmp/liberacion_pago_diag_CodexLibPagoDiag_5c31b7fa6e.
Los casos anteriores tambien pasaron. El primer intento dentro del sandbox
no pudo abrir LocalDB; se repitio con la autorizacion local correspondiente.
No hubo conexion a T3QA ni ejecucion de procedimientos de negocio.

Para06 se cargaron DDL reales de recepcion, encabezados, pagos, asignaciones,
cobranzas, documentos y errores; se uso FN_VALIDA_RFC real. Los indices
TRACE_* y los datos se crearon exclusivamente en la fixture temporal.
La copia del diagnostico en memoria sustituyo solo la base permitida y el
reloj de captura por una fecha fija; no se cambio el archivo entregado.

- Recepcion del 28/10 con fecha XML del 08/10: cinco mensajes coincidentes.
  Un sexto mensaje del 09/10 quedo fuera del rastreo de etapas.
- Cinco claves esperadas, cuatro encabezados, tres pagos, tres asignaciones
  y dos cobranzas: conteos verificados mediante aserciones SQL.
- Mensaje sin encabezado y encabezado dentro del margen de 90 minutos:
  ambos se conservan visibles sin inventar asignaciones.
- Una asignacion con BATMD NULL y otras con BATMD 27/10, pese a pagos del
  08/10: se conservan y distinguen las fechas reales.
- Cobranza PPD sin exclusiones y cobranza con PUE, via distinta, UUID NULL,
  INTERFACE, PendienteT3, RFC no positivo y bitacora: muestra flags separados.
- Columnas de busqueda con Latin1_General_100_CI_AS_KS_WS_SC y otras con
  SQL_Latin1_General_CP1_CI_AS: las relaciones ejecutaron sin error 468.
- 209 mensajes mas recientes de otra fecha: limita a 200 ANTES del filtro
  XML; informa HayMasEnVentana=1 y no afirma ausencia global.
- Falta de indice inicial en ASIGNACION_PAGO: termina en 03_DETENIDO.
- Sin marcas de envio, bitacoras de corrida ni consumo de secuencia.

TSql160Parser: cero errores en06. PowerShell parser: cero errores en
Trace.ps1. Estas pruebas validan el diagnostico con datos sinteticos;
no certifican rendimiento, ruta instalada, ni generacion fiscal productiva.

## Validacion anterior de01,02 y04

28/10/2026. Run.ps1 finalizo con codigo 0 en CodexLibPagoDiag_00e842f88a,
collation SQL_Latin1_General_CP1_CI_AS. Base temporal eliminada al finalizar.
Reportes de fixture en tmp/liberacion_pago_diag_CodexLibPagoDiag_00e842f88a.

Ampliacion tras la demora real:04_VALIDAR_MUESTRA_LIGERA.sql y sus fragmentos
pasan parsers y ejecucion de fixture. Un candidato conserva riesgo VARCHAR4;
al crear210 cobranzas identicas preselecciona100 antes de validar, manteniendo
las100 filas de cursor y una asignacion distinta. La muestra no ejecuta fase
fiscal exhaustiva ni certifica el lote real. Los metadatos de tablas de prueba
son pequenos; no es una prueba de latencia ni volumen productivos.

TSql160Parser acepto wrapper, cuerpo y consulta posterior. PowerShell parser
acepto constructor y runner. El wrapper reporto dependencias ausentes sin
intentar compilar/invocar FN_VALIDA_RFC o GETCONV inexistentes.

Se cargaron DDL reales de tablas T3, EAI_OWNER y EAI, funciones GETCONV y
FN_VALIDA_RFC reales, y las definiciones del coordinador/generador/LOG_START
solo para inspeccion. Las tres funciones de formato son stubs de fixture.
No se ejecuto ningun procedimiento de negocio ni un layout real.

Casos comprobados:

- Dependencias ausentes: salida 05_DIAGNOSTICO_DETENIDO sin error de compilacion.
- Candidato elegible: una cobranza, una fila de cursor y una asignacion 4.0.
- Generador con VARCHAR(4): detecta FACTURA_TRUNCADA_A_4 y SIN_BASE_FISCAL.
- Solo en la fixture se amplia a VARCHAR(30): deja de reportar ambos riesgos
  para una factura con detalle fiscal completo.
- Denominador fiscal cero: detecta DENOMINADOR_CERO sin efectuar la division.
- Saldo que produce asteriscos en STR(...,12,2): detecta SALDO_NO_CABE_EN_STR.
- Cliente duplicado: detecta JOIN_MULTIPLICA_CABECERAS.
- Cliente ausente: detecta SIN_DATOS_CABECERA.
- Diagnostico no inserta layouts ni bitacoras de corrida, no marca cobranza,
  conserva componente y no consume la secuencia (last_used_value sigue NULL).
- Postvalidacion sin lista: reporta alcance insuficiente.
- Postvalidacion con baseline sin altas: devuelve estado de revision.
- Altas/marcas simuladas mediante fixture: reconoce incrementos y datos en
  ventana, sin declararlos una certificacion de contenido o timbrado.

Las primeras iteraciones del runner se ajustaron para aceptar encabezados
CREATE o ALTER y para mostrar errores SQL sin ocultarlos. La version final
paso todos los casos. No se cambiaron fuentes de negocio durante las pruebas.

Limites: datos sinteticos, sin permisos del usuario real, sin actividad
concurrente, sin PAC ni funciones reales de formato. No prueba ejecucion del
generador instalado, equivalencia integral, rendimiento o requisitos fiscales.
01 exhaustivo quedo suspendido por su costo real. El siguiente diagnostico
vigente es06; la decision y las dos corridas reales del usuario constan en
README y los analisis de PID, sin implicar certificacion del generador.

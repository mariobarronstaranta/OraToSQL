# Resultado del diagnostico 04: muestra sin candidatos

Fuente: [captura del 04](Captura_011021_MUESTRA.txt), archivo encontrado en
Downloads como Resultados_04_Muestra_Ligera.txt. El mensaje del usuario
enlazaba Resultados_03_Diagnostico.txt, cuyo contenido/hash seguia siendo
la captura anterior de actividad. Se localizo el archivo con nombre de04
y se verificaron sus secciones antes de analizarlo; no se reutilizaron los
contadores antiguos como si fueran una nueva ejecucion.

SHA256 de04:87E72B68139603CD0B0675D41EB04FA1223186DE3AA4603B9B5D5B2370EE5CF5.
AZCRNMXNEVTD06/T3QA, login AT85233588/dbo, TranCount0. Inicio28/10/2026
01:10:21.781 -06:00, fin01:11:41.261; aproximadamente79.48s. La captura
incluye13_ALCANCE_MUESTRA y final, sin error reportado:04 termino.

## Resultado de la muestra

Se preseleccionaron100 cobranzas que pasan filtros baratos. Tras aplicar
validadorRFC, exclusion de referencias y relacion de documento noPUE:

| Dato | Conteo |
|---|---:|
| Filas del cursor dentro de la muestra | 0 |
| Llamadas version4.0 | 0 |
| Asignaciones version4.0 | 0 |
| Filas sin rama de generacion | 0 |
| Sin documento relacionado con Metodo_Pago distinto de PUE | 95 |
| RFC sin retorno positivo de la funcion instalada | 31 |
| Referencia excluida por RF_ERROR_LOG | 5 |

Los tres motivos NO son excluyentes y no se suman. Los95 pueden incluir
documento ausente, soloPUE o Metodo_PagoNULL: el resumen no distingue esos
casos. Los31 no equivalen a31RFC oficialmente invalidos: se reporta el retorno
del validador local. Los cinco con alguna relacion noPUE tambien incumplen
RFC y/o bitacora, por la condicion del cursor; no se puede afirmar que sean
exactamente las cinco referencias de error sin ver sus IDs.

Las secciones de candidatos08, relaciones09, baseline10 y hallazgos por
asignacion12 estan vacias porque no hay claves elegibles en esta muestra.
Eso no acredita integridad fiscal de todo el lote ni ausencia de problemas:
no se llego a validar datos del generador para pagos concretos.

La seleccion era TOP100 sin orden, no todo el pendiente. No afirmar que el
SP real tendra cero candidatos, ni ampliar a todo el historico con el01 que
ya resulto costoso. No reejecutar la misma muestra esperando prueba global.

## Configuracion, codigo y accesos

Todos los objetos requeridos estan visibles con permisos consultados1 para
esa sesion. Hashes del coordinador/generador coinciden con la captura previa;
no hay indicio de una nueva definicion entre ambas capturas.
DeclaraFacturaPagadaVarchar4=1 sigue confirmado en el generador instalado.
Falta una factura elegible concreta para medir su efecto sobre la base fiscal.

Las siete claves generales tienen una fila y Target noNULL:
VersionCFDI4.0; RegimenFiscal601; RegimenFiscalCliente626; UsoCFDI_PaymentCP01;
UsoCFDI_ComercialG01; PaymentDefaultTime120000; MetodoPagoPPD.
Esto acredita existencia/configuracion del fallback, no correccion fiscal
de todos los clientes ni validacion de los valores contra un catalogo externo.
La etiqueta REVISAR VALOR de06 es informativa, no un error en esas siete filas.

Los accesos iniciales requeridos aparecen disponibles, excepto
CFDI_USOCFDI_CLIENTE (116filas, tratada como pequena por la guardia).
La consulta no se detuvo por indices. Los tamanos aproximados son56,109,048
cobranzas,22,891,006documentos,3,235,304layouts,834,239movimientoscliente,
337,243emails y53,994errores. Son estimaciones de metadatos, no COUNT de negocio.
No hay evidencia aqui para proponer otro indice.

## Siguiente paso pendiente

Se solicito al usuario una fecha de pago o Asignacion_ID/Factura que espera
liberar. El dato permitira construir una lectura enfocada y explicar para
esas filas la elegibilidad, relacion de venta, RFC, errores y datos fiscales.
El filtro se aplicaria solo al diagnostico: el SP real no recibe fecha ni IDs
y conserva el alcance de todos sus candidatos.

Por ahora no se acredita que exista un conjunto apto para una prueba de
generacion exitosa. No ejecutar el SP por el solo hecho de que04 termino.
No se cambian documentosPUE, RFC ni referencias de error para forzar el paso.
No se modificaron scripts de negocio, GETCONV, indices o datos en esta revision.

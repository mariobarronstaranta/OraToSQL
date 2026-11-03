# Validacion posterior de DELIVERY_TO_REMISION

Ejecutar `01_VALIDAR_EJECUCION.sql` completo en T3QA. Solo consulta tablas y
la funcion getConv; no ejecuta el generador, no modifica CREATED ni datos.

Por defecto revisa el dia actual del servidor. `@DiaEjecucion` determina la
medianoche del filtro del SP; `@Desde`/`@Hasta` acotan errores y Fecha_Trn.
`@DesdeOrigen='20260731'` agrega contexto de las entregas historicas del archivo
cargado. Con `@Delivery` puede revisarse una sola entrega. Los logs de helpers
se muestran completos para el rango porque referencian centros/sociedades.

Leer primero **01_FILTRO_DE_ORIGEN**: el SP local utiliza Created mayor que la
medianoche, sin limite superior. El TXT revisado tenia Created maximo del
29/10/2026; si las fechas no cambiaron, esas filas no son candidatas en noviembre.
El diagnostico no cambia las fechas para hacerlas entrar al proceso.

**02** reproduce los grupos de cabecera y el JOIN de sociedad. **03/04** resumen
salidas faltantes, cabeceras sin detalle, duplicados, unidades numericas y folios
vacios. **05/06** muestran las cabeceras y lineas actuales. **07** coteja la relacion
de folio REM con la serie/folio de cabecera. **08** muestra errores y **09** senala
el riesgo del FETCH cruzado en el fuente local. **10** muestra el catalogo de
sociedades por centro involucrado.

Los conteos de detalle esperado usan todo Delivery_Hist de la entrega y el LEFT
JOIN a Material, igual que ScrDetail; no solamente los registros Created de hoy.
Coincidir en numero de lineas no certifica cantidades, domicilios o unidades.
Se incluyen salidas historicas como contexto: no se califican como altas nuevas
solo por pertenecer a una entrega del archivo.

El SP no tiene PID ni auditoria propia. Fecha_Trn disminuye un segundo por alta,
por lo que no es la hora exacta de INSERT y puede cruzar medianoche. MX_NRIV_RELACION
no tiene fecha. Los valores actuales no permiten reconstruir una corrida exacta
sin captura previa. La consulta tampoco presupone si se uso @nConvCases=0 o 1.

El log del coordinador guarda la delivery en **ID**, no REFERENCE. Los helpers
guardan otros identificadores en REFERENCE. DELIVERY_IDOC_TO_REMISION comparte
Queue_Name='DELIVERY_TO_REMISION': correlacionar horario, referencia y contexto.

El diagnostico parte de la definicion local comentada; puede diferir de una
version instalada modificada despues. `@VerDefinicion=1` devuelve la definicion
instalada como XML para revisar el SELECT y los FETCH actuales.

La salida de riesgo del FETCH no corrige nada. Una cabecera sin detalle puede
persistir tras un error absorbido y provocar que la reejecucion la omita. Revisar
los resultados antes de intentar una reparacion o una nueva generacion.

Las consultas se ejecutan secuencialmente con el aislamiento de la sesion;
otros procesos pueden cambiar el estado entre resultados. No se usa NOLOCK.

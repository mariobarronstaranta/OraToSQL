# Analisis de performance de PROCESA_PAGO_AGR

El resultado de la revision esta en **ANALISIS.md**. No hay porcentajes de mejora
medidos en T3QA ni cambios al procedimiento instalado.

**Estado confirmado por el resultado 07:** ver
`Resultados_07/ANALISIS_RESULTADO_07.md`. El indice propuesto ya existe activo
en T3QA, con las claves y cobertura correctas. La cache sigue mostrando la
corrida del 29/10 y Query Store no devuelve metricas en la ventana del 02 al
03/11 consultada. Todavia no hay una medicion posterior para calcular la mejora.

**Siguiente paso:** despues de la siguiente corrida de negocio autorizada,
repetir `07_VALIDAR_MEJORA_UPDATE.sql`. Comparar fecha, parametros (@nDias=30
en la referencia), carga, plan, lecturas y duracion. El 07 no ejecuta el SP.

**Plan completo analizado:** ver `Resultados_05/ANALISIS_RESULTADO_05.md`.
El plan 8889 muestra un Table Scan de CFDI_COBRANZA: 56.1 millones de filas
estimadas a leer y unas 15,466 despues del filtro. La primera mejora propuesta
es (ASIGNACION_CENTRAL, FECHA_PROCESO) INCLUDE (ASIGNACION_ID, FACTURA).

**06_INDICE_UPDATE_COBRANZA.sql** permite crear el indice que ya se observa en
el 07. El reporte no identifica como se creo. Con @Aplicar=0 devuelve solo
metadatos y DDL. Con @Aplicar=1 comprueba alternativas de Assignment elegibles
y crea un unico indice si no hay ambiguedades ni otro equivalente activo.
No ejecuta el SP. La comprobacion y la construccion pueden ser costosas sobre
56 millones de filas; reservar una ventana y coordinar escritores concurrentes.
El indice agrega espacio y mantenimiento a futuras cargas. El SP queda igual.

**07_VALIDAR_MEJORA_UPDATE.sql**, de solo lectura, compara la referencia
historica con cache/Query Store despues de una nueva corrida autorizada.
No ejecuta el SP para medirlo. Ajustar @Desde al momento de creacion del indice.
Conservar los resultados y revisar parametros, fechas, carga y uso del indice.
El beneficio real aun no esta medido. Ocho comprobaciones locales aprobadas.
Posponer el 02 completo y las otras propuestas hasta medir este primer cambio.

1. **01_METADATOS_Y_TIEMPOS.sql**: ejecutar completo en T3QA. Solo consulta
   catalogos, indices reales, tipos/collation, bitacoras, cache y estadisticas.
   @VerPlanes=1 incluye XML de planes EN CACHE. Los bloques DMV informan si
   faltan permisos; en SQL Server 2022+ ciertas vistas requieren VIEW SERVER
   PERFORMANCE STATE y en versiones anteriores VIEW SERVER STATE.
2. **02_VOLUMENES_Y_SELECTIVIDAD.sql**: poner @nDias igual al valor utilizado.
   Lee las tablas de negocio y crea/elimina solo sus temporales locales de
   sesion. Puede consumir IO/tempdb; ejecutar en un momento apropiado. Con
   @AnalizarLiberacion=1 y @RevisarAsignacionCentral=1 agrega los cruces costosos
   para investigar repeticion de facturas y multiplicidad de asignaciones.
3. **03_PROPUESTAS_INDICES_SOLO_TEXTO.sql**: devuelve ocho DDL candidatos COMO
   TEXTO y muestra indices con prefijos de claves coincidentes. **No crea indices**.
   No contiene un modo @Aplicar. No copiar todos los DDL sin revisar evidencia.

Ningun script ejecuta PROC_CFDI_PROCESA_PAGO_AGR, liberadores, CHECK ni
generadores. El 06 es el unico que permite DDL con @Aplicar=1: crea el indice
y su estadistica; no modifica registros de negocio ni consume secuencias.
Los demas scripts son de lectura, con temporales locales cuando se indica.
Las consultas se leen secuencialmente: con escritores concurrentes no forman
una fotografia transaccional unica. No usan NOLOCK.

El 01, 04, 05 y 07 ya fueron analizados. Compartir la proxima salida del 07
despues de una corrida posterior para medir el efecto del indice.
El plan recuperado es compilado historico, sin metricas reales por operador.

Los SP de produccion y sus hijos permanecen sin modificaciones. El modelo
de 02 refleja Asignacion_Central actual y conserva el detalle sin corte de
Fecha_Proceso; no es una simulacion completa del UPDATE inicial ni una prueba
de generacion fiscal. Los indices propuestos deben compararse con los existentes,
incluidos los que tienen nombre de PK pero no son restricciones PRIMARY KEY.

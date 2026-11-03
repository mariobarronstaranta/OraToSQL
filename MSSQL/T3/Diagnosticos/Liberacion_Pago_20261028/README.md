# Preparacion de la corrida PROC_CFDI_LIBERACION_PAGO

Correccion de06 tras el error real468 en la linea50: la comparacion
`sys.columns.name = @Accesos.Columna` ahora aplica `COLLATE DATABASE_DEFAULT`
a ambos lados. El conflicto era entre metadatos y la variable de tabla;
las pruebas previas de columnas de negocio no cubrian ese caso.
Reproduccion del fallo original y ejecucion del diagnostico corregido
verificadas en LocalDB; ver [pruebas](tests/RESULTADO.md).
Usar la version actualizada de06 y ejecutarla completa en T3QA.

Estado vigente tras la nueva carga: la segunda corrida, PID 26516975,
28/10 09:32:31.543-09:36:35.582, duro 244.039 segundos y volvio a cerrar
con CERO filas recorridas, retorno 0, sin errores en las bitacoras consultadas.
Ver [resultado y ruta de recepcion](RESULTADO_CORRIDA_26516975.md).

El usuario confirmo que ingreso pagos del **2026-10-08** mediante
`EXEC EAI_OWNER.RECV_PAYMENT`. El siguiente paso es ejecutar solamente
[06_RASTREAR_PAGOS_20261008.sql](06_RASTREAR_PAGOS_20261008.sql) en T3QA
y guardar todos sus Resultados y Mensajes. No repetir01 ni05 para buscar filas.
06 es de solo lectura de negocio; no ejecuta SP ni altera GETCONV o indices.

Se distingue fecha de pago, fecha de recepcion y FECHA_PROC_BATMD. La ruta
normal pasa por TMP_ACCOUNT_HEADER, procesos centrales, PAGO/ASIGNACION_PAGO,
el preparador PROC_CFDI_PROCESAR_PAGOS y finalmente el liberador. El margen
de 90 minutos de CENTRAL_EXECUTE y su ventana desde EOD son indicios del
codigo, no causas ya confirmadas en la base. No ejecutar EOD como atajo.

06 toma primero hasta 200 mensajes Payment de las ultimas 48 horas y despues
revisa sus fechas XML. Busca encabezados por IDoc y las etapas siguientes
por claves de la ruta ZV/PAYALLOC; las relaciones se limitan a 2000 filas.
No lee todo el historico ni llama funciones sobre millones de cobranzas.
Si la muestra no incluye el lote, o se detiene por indices/limites, enviar
esa salida antes de ampliar. Cero en la muestra no significa cero global.
Las claves de busqueda heredan collation de cada tabla para conservar los
accesos por indice y evitar el conflicto 468 en las relaciones.

Los apartados siguientes conservan el historial de preparacion y corridas.
La fecha y la ruta de carga ya fueron respondidas; no volver a pedirlas.

Corrida real recibida:28/10 01:44:00.936-01:47:24.844, PID26516972,
proceso613,203.908s,FilasRecorridas0,Finregistrado,componenteStatus1,
sin errores en las consultas devueltas. Cierre normal SIN candidatos elegibles;
no se intento generar pagos desde ese recorrido. No significa tabla vacia.
Ver [resultado de la corrida](RESULTADO_CORRIDA_26516972.md). No repetirla
solo para obtener filas; falta una futura generacion con datos elegibles
para validar el generador y resolver su riesgoVARCHAR4.

Decision vigente del usuario: ejecutara el SP sin parametros tal como esta.
Usar [05_EJECUTAR_Y_REVISAR_CORRIDA.sql](05_EJECUTAR_Y_REVISAR_CORRIDA.sql),
que SI inicia el proceso real, conserva la definicion y devuelve horarios,
SPID, bitacoras y errores. Guardar Resultados y Mensajes. Se conserva el
riesgoVARCHAR4; un retorno normal no certifica el contenido generado.
La fecha/IDs solicitados eran solo para acotar el diagnostico, no parametros
del SP. Los apartados previos describen las revisiones realizadas y no
cambian esta decision. El agente no ejecuto la corrida en la base remota.

Resultado actual04 (01:10:21-01:11:41,~79.48s):100 preseleccionadas y
CEROfilas elegibles de cursor. Motivos solapados:95sin documento noPUE,
31RFCsin retorno positivo,5referencias en bitacora. No concluye ceroglobal.
Configgeneral7claves presentes; version4.0; riesgoVARCHAR4 sigue instalado.
Ese resultado se obtuvo antes de conocer la carga del 8 de octubre.
No repetir01 ni tomar esta muestra como autorizacion funcional del lote.
Ver [analisis de la muestra](ANALISIS_MUESTRA_011021.md).

Paso vigente tras la captura03: sesion76 esta ejecutando SELECT INTO #Base,
16.5min/CPU14.5min/28.7M lecturas logicas, sin bloqueador ni espera actual.
Cancelar01 y usar [04_VALIDAR_MUESTRA_LIGERA.sql](04_VALIDAR_MUESTRA_LIGERA.sql)
para la siguiente captura. NO correr ambas consultas a la vez. Ver
[analisis de actividad y cambios del diagnostico](ANALISIS_ACTIVIDAD_005017.md).
04 limita primero a100 cobranzas, valida RFC distintos una vez y omite el
calculo fiscal masivo. Revisa accesos por catalogo y se detiene si necesita
leer tablas grandes sin acceso inicial reconocido. Emite etapas M1-M5.
Es una MUESTRA, no conteo completo ni certificacion de todas las precondiciones.
Si devuelve05G_DETENIDO, enviar los metadatos; si se demora, guardar ultima
etapa y capturar03. No se modificaron SP de negocio, GETCONV o indices.

Actualizacion de la primera ejecucion: el usuario informa que01 lleva mas de
once minutos y entrega resultados hasta05B. No repetir01 completo por ahora.
Ejecutar [03_VER_DIAGNOSTICO_EN_CURSO.sql](03_VER_DIAGNOSTICO_EN_CURSO.sql) en
otra ventana mientras01 siga activo y guardar todos los resultados; despues
puede cancelarse01 desde SSMS. El generador instalado SI declara facturaVARCHAR4,
y aun no llegaron candidatos/detalle fiscal. Ver [analisis parcial](ANALISIS_PARCIAL_003347.md).
No confundir @MaxDetalle con limite de trabajo:01 revisa todos los pendientes
de via01. Falta identificar la sentencia/espera real antes de rehacer la captura.

Preparado el 28 de octubre de 2026. Los scripts 01 y 02 son de solo lectura
de tablas de negocio. El primero usa temporales locales y llama unicamente
funciones escalares para revisar datos; ninguno ejecuta el proceso ni consume
NEXT VALUE FOR. No cambian permisos, configuracion, indices, estados ni jobs.

## Primero: revisar antes de ejecutar

Seleccionar la base real de la corrida (el ambiente conocido es T3QA) y
ejecutar completo [04_VALIDAR_MUESTRA_LIGERA.sql](04_VALIDAR_MUESTRA_LIGERA.sql),
despues de cancelar01. El diagnostico exhaustivo01 queda suspendido para esta fase.
No necesita parametros ni SQLCMD mode. Guardar todos los resultados y errores.
El script muestra servidor/base/login para evitar confundir contextos. Si el
job se ejecutara con otro usuario, los permisos del usuario de diagnostico
no acreditan por si solos los de ese job.

| Seccion | Que permite revisar |
|---|---|
| 02/03 | Visibilidad, tipo, firma, permisos directos y hashes de dependencias. Permiso directo=0 no prueba fallo dentro del SP si hay cadena de propiedad. No se conceden permisos. |
| 04 | Si el generador instalado declara FacturaPagada VARCHAR(4), que puede truncar la factura del calculo fiscal. Es una marca de codigo, no certificacion completa de version. |
| 04B | Metadatos de ProcessID sin consumirlo. Revisar que sus valores quepan en el NUMERIC(8,0) del coordinador. |
| 05 | Componente 613 y ultimas corridas, incluidas las que quedaron sin fin. |
| 06 | Configuracion general, mapeos ausentes, NULL y duplicados de MX_HashTable. |
| 05G/05M | Accesos/tamanos por metadatos y alcance de hasta100 filas preseleccionadas. Una ausencia de acceso sobre tabla grande detiene la lectura. |
| 07/07B | Filas del cursor para la muestra, llamadas a version4.0 y filtros restantes. No es el total del pendiente. |
| 08 | Candidatos con asignacion, factura, version, cliente, importe y relacion de venta. |
| 09 | Relaciones necesarias del generador: MOV_CLIENTE, distribuidor y sociedad. Se usa MOV_CLIENTE, no CLIENTE. |
| 10 | Conteos previos de layout, documento y cobranzas marcadas por asignacion: guardar como baseline. |
| 11 | Fase fiscal exhaustiva de01; no se ejecuta en04. |
| 12/12B | Hallazgos por tipo y asignacion. Cero denominador, factura sin guion o cabecera ausente; riesgos de truncamiento, falta de base fiscal, duplicados y datos incompletos. |

En04, @MaxMuestra=100 limita las cobranzas ANTES de funciones/relaciones.
@MaxDetalle=100 solo limita la salida. Mantener estos valores para la primera
captura; los resultados no son un baseline completo del lote. Se conserva la
multiplicidad de documentos de esas notas, sin DISTINCT que ocultaria llamadas.
Confirmar las reglas contra la definicion instalada; una muestra sin candidatos
no acredita ausencia global.

No interpretar cero candidatos como una prueba de generacion exitosa. El
coordinador puede terminar normalmente sin generar nada. Tampoco asumir
que version distinta de 4.0 tiene una rama alternativa: el fuente actual la omite.

## Riesgo de codigo que se revisa expresamente

El fuente actual de PROC_V20_GENERAR_PAGO declara @sFacturaPagada VARCHAR(4)
y la usa para consultar Registro_Fiscal. La revision previa no habia corregido
ese generador. El diagnostico consulta OBJECT_DEFINITION en la base y, si
encuentra esa declaracion, contrasta la clave truncada con la factura completa.
No modifica el generador ni decide que basta cargar mas datos. Resolver los
hallazgos reales antes de la corrida; una consulta sin errores no prueba que
el layout resultante tendria todos sus importes e impuestos correctos.

FN_VALIDA_RFC ya tiene [definicion en el repositorio](../../T3/Funciones/FN_VALIDA_RFC.SQL).
El diagnostico invoca la funcion instalada y conserva el contrato >0 del
coordinador. No reemplaza su validacion por una expresion inventada. Las
comprobaciones de UUID/RFC son locales; no certifican autenticidad ni contenido
fiscal. No se ejecutan las funciones de formato del layout durante esta revision.

## Corrida real, despues de revisar los resultados previos

El SP no recibe fecha, ID ni limite de lote. Ejecutara TODOS sus candidatos,
no solo los mostrados en las primeras 200 filas ni los de una lista de validacion.
Coordinar la corrida para que no coincida con otra ejecucion manual/automatica
del proceso; estos scripts no deshabilitan jobs ni reservan candidatos.

Comando para la corrida real, una vez resueltos los hallazgos de codigo y
revisadas las precondiciones del conjunto completo. La muestra04 por si sola
no acredita ese alcance; no iniciar el SP en la fase actual de diagnostico:

```sql
SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual,
       SYSDATETIME() AS InicioReal;
EXEC T3.PROC_CFDI_LIBERACION_PAGO;
SELECT SYSDATETIME() AS FinReal;
```

Guardar inicio/fin y mensajes de SSMS. No envolverlo en una transaccion para
hacer una supuesta prueba sin efectos: seria una ejecucion real y consumiria
la secuencia. Fin del proceso y Proceso_1 son solo bitacora/filas recorridas;
los CATCH del coordinador y generador pueden registrar errores sin THROW.

## Despues: conciliar salidas

Ejecutar [02_VALIDAR_RESULTADO.sql](02_VALIDAR_RESULTADO.sql) completando
@Desde con el inicio real, @PID si se conoce y @Baseline con los conteos de 10.
Formato del baseline (sustituir por los valores reales, no ejecutar este ejemplo
como si identificara una asignacion existente):

```json
[
  {
    "Asignacion_ID": "ID_REAL",
    "LayoutsAntes": 0,
    "DocumentosAntes": 0,
    "CobranzasMarcadasAntes": 0
  }
]
```

Sin lista/baseline, el script devuelve bitacoras y advierte que no puede
acreditar todas las salidas ni detectar omisiones. Con baseline, compara
incrementos, Fecha_Liberacion y marcas de cobranza. CFDI_DOCUMENTOS_ENVIAR no
tiene una fecha en el DDL revisado: la mera existencia de un layout no acredita
que se insertara en esta corrida. Con concurrencia tampoco hay atribucion exclusiva.

Los errores del generador se buscan con su nombre historico GENERAR_PAGO en
RF_ERROR_LOG, sin exigir JOB_PID: Referencia puede ser Folio_ID. Los del
coordinador se consultan en MX_EAI_MESSAGE_LOG por su cola y ventana/PID.
Altas y marcas no acreditan contenido fiscal del layout, envio posterior ni timbrado.

## Mantenimiento y validacion del paquete

El cuerpo de consulta se mantiene en queries/DatosPrecondiciones.sql y se
embebe en 01 con queries/Build.ps1. La compilacion diferida permite mostrar
dependencias ausentes sin que falle antes una referencia a funcion inexistente.
El usuario ejecuta04 en la fase previa actual y02 solo despues de una corrida
real. Los archivos queries/tests son de mantenimiento; no ejecutar01 exhaustivo.

La nueva muestra04 se genera con queries/BuildMuestra.ps1 usando el encabezado
de01 y los fragmentos BaseMuestra/GuardiaMuestra. No reemplazar su salida parcial
por un estado de validacion integral. El uso vigente de datos es04, no relanzar01.

Se comprobaron sintaxis y ejecucion LocalDB con DDL real, GETCONV/FN_VALIDA_RFC
reales y datos sinteticos. El generador/coordinador se cargaron en la base de
prueba, pero no se ejecutaron. Las funciones de formato son stubs solo para
metadatos: no se usan para certificar un layout. Ver [pruebas](tests/RESULTADO.md).
No se conecto a T3QA desde el agente ni se modificaron SP de negocio.

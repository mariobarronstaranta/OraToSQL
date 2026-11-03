# Demora identificada en la construccion de Base

Fuente: [captura de actividad](Captura_005017_ACTIVIDAD.txt), recibida como
Resultados_03_Diagnostico.txt. SHA256:
F66DB4B4D6FB512FB2A5BD6E23C4BF5A42D5E3FAD3BC1F7F992FD3D03FF3903E.
AZCRNMXNEVTD06/T3QA, 28/10/2026 00:50:17 -06:00.

## Evidencia

Sesion76, usuario AT85233588 desde SSMS; estado running, comando SELECT INTO.
El inicio de SentenciaActual corresponde al SELECT IDENTITY que construye
#Base en 01. La celda exportada corta el texto a 256 caracteres; offsets
2804-5568 identifican el rango dentro del batch dinamico capturado.

La solicitud completa acumula 989,640 ms (16 min29.640 s), CPU867,883 ms
(14 min27.883 s), 28,669,546 lecturas logicas y 355,104 fisicas reportadas.
No son mediciones exclusivas de esta sentencia: incluyen lo ejecutado antes
dentro de la misma solicitud. Lecturas logicas no equivalen a bytes de disco.

Bloqueador0, espera actual NULL/0, sin bloqueador positivo. En ese instante
esta trabajando, no detenida por un bloqueo identificado. Las esperas de
sesion incluyen PAGEIOLATCH_SH135,575 ms y SOS_SCHEDULER_YIELD774 ms, pero son
acumuladas de la sesion, no un delta de la fase Base ni prueba de su causa unica.

open_transaction_count=2 durante SELECT INTO no contradice el TranCount0 del
inicio: hay actividad de la propia instruccion/temporales. El diagnostico no
contiene DML de negocio ni NEXT VALUE FOR; puede cancelarse desde SSMS, sin
KILL o resetear estados. La cancelacion podria tardar en completar su limpieza.

## Revision del diseno del diagnostico

El primer01 tenia un alcance excesivo para una primera validacion en esta
base: todas las cobranzas pendientes de via01, funciones escalares por fila,
conteos correlacionados de documentos y evaluacion de referencias de error.
MaxDetalle200 limitaba solo la salida. Las pruebas pequeñas validaban
correccion, no rendimiento al volumen real. No es un fallo demostrado del
SP de negocio: la solicitud observada ejecuta el diagnostico.

El inventario22Oct ya registraba aproximadamente56.1M filas de COBRANZA,
22.9M DOCUMENTOS,154.8M REGISTRO_FISCAL y489.1M de su detalle; cifras historicas,
no conteos nuevos. Hay indices iniciales conocidos, lo que no basta para
garantizar costo bajo si se consulta todo el pendiente con funciones/correlaciones.
No se prescribe crear indices, tocar GETCONV, cambiar MAXDOP o aumentar memoria
solo con esta captura; falta el plan para repartir el costo exacto.

## Consulta de muestra preparada

[04_VALIDAR_MUESTRA_LIGERA.sql](04_VALIDAR_MUESTRA_LIGERA.sql) conserva la
revision de metadatos y codigo, y cambia el alcance de los datos:

- Consulta accesos iniciales activos y tamanos aproximados por catalogos/DMV.
  Si falta acceso reconocido en una tabla grande, se detiene antes de leer
  datos. No fuerza un plan ni crea indices. Una tabla pequena puede leerse.
- Preselecciona TOP100 con los filtros baratos de cobranza antes de funciones
  o relaciones. No usa ORDER BY que obligue a ordenar todo el pendiente.
- Materializa RFC distintos y ejecuta el validador una vez por RFC de esa
  preseleccion; reutiliza la version general ya obtenida en configuracion.
- Obtiene documentos por el conjunto de notas muestreadas y materializa una
  vez las referencias globales de error. Conserva la multiplicidad de
  documentos para esos candidatos y la semantica de NOT IN.
- Limita contexto a1000 cobranzas y2000 cabeceras. Si alcanza alguno de esos
  topes, se detiene sin diagnosticar ausencias sobre una lista truncada.
- Omite el calculo/lectura fiscal masivo de 11; si la factura supera cuatro
  caracteres y el generador instalado usa VARCHAR(4), conserva el hallazgo.
- Informa etapas M1-M5 mediante mensajes NOWAIT para saber donde avanza.

TOP100 limita filas preseleccionadas, no un tiempo maximo: el acceso fisico
para encontrarlas y las relaciones dependen de los datos/plan. Si se demora,
guardar la ultima etapa y observar con03. No ejecutar simultaneamente01.

Es MUESTRA, no conteo global ni aprobacion del lote. Si no encuentra candidatos
en esas100 filas, no demuestra que no haya mas fuera de ellas. El SP real
sigue procesando todos sus candidatos y aun conserva el riesgo VARCHAR(4)
confirmado en la captura parcial. No ejecutar el generador solo porque una
muestra termine o porque las dependencias esten visibles.

## Validacion

SQL/PowerShell parsers sin errores. Run.ps1 termino exit0 en
CodexLibPagoDiag_00e842f88a (base eliminada). Conserva los casos anteriores y
agrega muestra de un candidato con riesgo de factura y210 cobranzas identicas:
limito a100 antes de la validacion. Se comprobaron ausencia de DML de negocio
y de consumo de secuencia, asi como las consultas posteriores.

La prueba usa DDL real, GETCONV/FN_VALIDA_RFC reales y stubs de formato solo
para metadatos; no ejecuta generacion ni certifica rendimiento a escala real.
La recomendacion inmediata es cancelar01 y ejecutar solo04 para la siguiente
captura, compartiendo todos los resultados y mensajes de etapas.

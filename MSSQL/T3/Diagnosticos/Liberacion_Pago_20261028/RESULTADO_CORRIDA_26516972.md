# Corrida real: proceso 613, PID 26516972

Fuente: [resultado del usuario](Corrida_014400_PID_26516972.txt).
AZCRNMXNEVTD06/T3QA, usuario AT85233588, sesion76.

| Dato | Resultado |
|---|---|
| Inicio del bloque | 28/10/2026 01:44:00.936 |
| Fin del bloque | 28/10/2026 01:47:24.844 |
| Duracion | 203,908 ms: 3 min23.908 s |
| PID / Proceso | 26516972 / 613 |
| Inicio / Fin registrados en RF_PROCESOS_LOG | 01:44:01 / 01:47:25 |
| FilasRecorridas (Proceso_1) | 0 |
| Proceso_2/3/4 | 0/0/0 |
| CodigoRetorno / ErrorPropagado | 0 / NULL |
| TranCountFinal / XactStateFinal | 0 / 0 |
| Estado del componente | 1; Last_Run 01:44:01 |
| Errores del coordinador y generador en la ventana consultada | Sin filas |

La ejecucion completo su cierre normal sin encontrar filas elegibles en su
cursor. Este resultado ya proviene del SP completo sin parametros, no de
la muestra100. Proceso_1 se incrementa antes de revisar version; al ser cero,
no se intentaron llamadas al generador desde este recorrido.

La conclusion se limita a candidatos que cumplen los filtros del procedimiento
en esa corrida. No acredita que CFDI_COBRANZA este vacia ni que no puedan
aparecer candidatos despues. Los motivos observados en la muestra anterior
(documento noPUE, RFC y bitacora) no se extrapolan como conteos del universo.

El generador no fue ejercitado con datos elegibles. No se certifican calculo,
layout ni timbrado, y la declaracion VARCHAR(4) sigue siendo un hallazgo
pendiente para una futura generacion. No es causa demostrada del contador0:
esa ruta no llego a ejecutarse segun el flujo revisado.

La duracion203.9s corresponde al bloque completo, incluida seleccion y
bitacoras; no es tiempo de generacion por pago. No se propone repetir la
corrida o modificar datos/filtros solo para obtener un candidato.
El usuario ejecuto el SP instalado; el agente solo analizo y archivo evidencia.

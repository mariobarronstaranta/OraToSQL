# Corrida real posterior a la carga de pagos: PID 26516975

Fuente: [resultado entregado por el usuario](Corrida_093231_PID_26516975.txt).
Servidor AZCRNMXNEVTD06, base T3QA, usuario AT85233588, sesion 90.

| Dato | Resultado |
|---|---|
| Inicio / fin del bloque | 28/10/2026 09:32:31.543 / 09:36:35.582 |
| Duracion | 244,039 ms; 4 min 4.039 s |
| PID / proceso | 26516975 / 613 |
| Inicio / fin de bitacora | 09:32:32 / 09:36:36 |
| Proceso_1, filas del cursor | 0 |
| Proceso_2 / 3 / 4 | 0 / 0 / 0 |
| Retorno / error propagado | 0 / NULL |
| TranCountFinal / XactStateFinal | 0 / 0 |
| Componente 613 | Status 1; Last_Run 09:32:32 |
| Errores de coordinador y generador consultados | Sin filas |

El proceso completo volvio a cerrar normalmente sin recorrer candidatos.
El contador se incrementa antes del IF de version: no hubo llamadas al
generador desde este recorrido. No demuestra que las tablas esten vacias
ni acredita generacion de layouts, calculo fiscal o timbrado.
El riesgo pendiente VARCHAR(4) del generador no fue ejercitado y no explica
por si mismo este contador cero.

El usuario aclaro que cargo pagos del **8 de octubre** mediante
`EXEC EAI_OWNER.RECV_PAYMENT`. Se interpreta 2026-10-08 por el contexto.
La fecha del pago no se debe asumir igual a FECHA_PROC_BATMD.

## Ruta observada en los fuentes

1. RECV_PAYMENT, componente 408, toma mensajes Payment pendientes con
   CREATED dentro de los ultimos 20 dias. Ese corte usa la recepcion,
   no la fecha de negocio contenida en XML.
2. SF_PROC_CENTRAL_PAYMENT deposita el mensaje normal en TMP_ACCOUNT_HEADER
   con CREATED=GETDATE(); no crea directamente CFDI_COBRANZA.
3. SF_PROC_CENTRAL_EXECUTE agrupa encabezados pendientes y deriva a ZV o
   PAYALLOC segun el grupo S/H. Normalmente aplica un margen de 90 minutos
   desde CREATED; entre las horas 1 y 2 lo reduce a cero. PROC_T3_EOD lo
   llama con una ventana de 2 dias de CREATED. EOD tiene otros efectos y
   no se recomienda ejecutarlo manualmente como atajo.
4. Las rutas centrales pueden crear PAGO y ASIGNACION_PAGO. Sus INSERT del
   repositorio omiten FECHA_PROC_BATMD; defaults, triggers o fases posteriores
   instaladas pueden modificarla. No asumir un valor sin consultar los datos.
5. PROC_CFDI_PROCESAR_PAGOS, componente 604, prepara CFDI_COBRANZA a partir
   de ASIGNACION_PAGO por FECHA_PROC_BATMD. Recibe una fecha obligatoria.
   No se recomienda repetirlo sin conciliar las filas existentes.
6. PROC_CFDI_LIBERACION_PAGO, componente 613 y sin parametros, toma las
   cobranzas que cumplen sus filtros. Su corte historico de Fecha_Pago
   es 2020-09-21: el 2026-10-08 por si solo no queda excluido por ese corte.

Estos son hallazgos de codigo; no prueban que falte una fase concreta en
la base ni que los 90 minutos expliquen esta corrida. Para eso se entrego
[06_RASTREAR_PAGOS_20261008.sql](06_RASTREAR_PAGOS_20261008.sql): muestra
acotada desde recepcion hasta cobranza, fechas BATMD reales y filtros del
liberador. No cambia SP, GETCONV, indices, estados ni datos de negocio.

La muestra usa hasta 200 mensajes Payment de las ultimas 48 horas antes
de evaluar XML. Si no incluye la carga, no concluir ausencia global ni
ampliar a todo el historico: revisar primero fechas y alcance devueltos.
Los bloqueos por errores son historicos, igual que el filtro del liberador.
No se ejecuto el SP ni se conecto a la base remota desde el agente.

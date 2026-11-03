# Segunda reparacion: preservar la cancelacion valida de T3QA

Paquete listo para revisar y ejecutar por etapas. No se ejecuto en T3QA.
La fuente ya esta incorporada en `02_CARGAR_ORIGEN.sql`: se genero desde
`ORA/T3/T3/Datos/Resultados_28_Oracle.jsonl` con fechas completas y NULL reales.
El hash SHA-256 esta en MANIFIESTO.txt y en la fila Estado del paquete.
No requiere volver a ejecutar el export ni el generador Python.

## Decision de alcance

El usuario confirmo que la cobranza 262201996890 tiene una cancelacion valida
en T3QA: FACTURA/NOTA_VENTA CHD-33522, STATUS Canc Pago, FECHA_ENVIO NULL.
No se restaura esa cobranza desde Oracle ni se crea su relacion con 529057.
Se preservan tambien sus relaciones actuales y los documentos existentes.

Para no cambiar el significado de una relacion actual sin revisar la
cancelacion, se DIFIERE el grupo 514967 completo. El reporte lo muestra con
dos controles y una relacion de octubre con la asignacion cancelada.
Si se restaurara solo su cabecera de julio dejando esa relacion, quedaria
un control historico asociado a un pago que no le corresponde.
Tampoco se modifica ni se crea el grupo 529057. Esta exclusion es deliberada,
no implica que la relacion actual con 514967 sea correcta.

| Alcance a reparar | Cantidad |
|---|---:|
| Grupos historicos de julio (excluye 514967) | 27 |
| Control adicional 529099, marcado Contado | 1 |
| Relaciones originales seleccionadas (99 julio + 1 octubre) | 100 |
| Cobranza faltante 262201997114 | 1 |

Con el estado del reporte 09, se esperan 54 controles antes y 28 despues.
En relaciones se esperan 130 antes y 100 despues: se conservan las 99
relaciones historicas legitimas, se retiran 31 relaciones adicionales que no
coinciden con Oracle y se incorpora la relacion original de octubre:
529099 -> 262201997114. Las relaciones de 514967 quedan fuera del reemplazo.

## Protecciones

- Esquema independiente REPAIR_AGR28_20261028; no sobrescribe ni elimina
  REPAIR_AGR_20261028, de la reparacion anterior.
- Respaldo completo de las tres tablas dentro del alcance, incluidos duplicados.
- Copia de la cobranza cancelada para revision y huellas de las demas cobranzas,
  documentos, layouts y grupos/relaciones diferidos. Los layouts se protegen
  con hash del contenido completo, no solo longitud/cabecera.
- La unica escritura de cobranza es INSERT de 262201997114, si sigue ausente.
  No se actualiza ni elimina ninguna cobranza existente.
- No escribe documentos ni layouts, no ejecuta procesos de negocio y no
  modifica la secuencia ni el componente 614.
- Captura y comparaciones usan bloqueos mantenidos durante la transaccion;
  las copias se ejecutan con MAXDOP 1. Espera de bloqueo limitada a 15 segundos.
  No garantiza ausencia de deadlocks: mantener ventana de mantenimiento.
- Rechaza cambios de destino desde la captura, alteracion de las tablas
  Origen_*, triggers activos y FK entrantes activas. No deshabilita objetos.
- Usa hashes SHA-256 por fila y cuenta multiplicidades; distingue NULL,
  mayusculas, espacios y duplicados. No editar Antes_*, Protegido ni SelloOrigen.

## Pasos para el usuario

Usar una ventana nueva de SSMS conectada a T3QA. Mantener detenidos los procesos
que modifican este alcance desde la captura hasta terminar la verificacion.
No ejecutar el agrupador/liberadores para completar esta reparacion.

1. Ejecutar `01_CAPTURAR_T3QA.sql` completo. Debe mostrar Fase CAPTURADO.
   Crea tablas de respaldo/preparacion y guarda huellas protegidas; no cambia
   datos de negocio. Si el esquema ya existe, se detiene en lugar de borrarlo.
2. Ejecutar `02_CARGAR_ORIGEN.sql` completo. Debe mostrar Fase CARGADO.
   Contiene los INSERT del origen ya validado: 28 controles, 100 relaciones
   y una cobranza. Solo escribe las tablas de preparacion.
3. Ejecutar `03_REVISAR.sql`. Guardar resultados ANTES / ORIGEN SELECCIONADO
   y comprobar la copia de la cancelacion valida.
4. Ejecutar `04_REPARAR.sql` con `@Aplicar = 0`, que es el valor entregado.
   Exigir `ENSAYO CORRECTO; TODOS LOS CAMBIOS REVERTIDOS`. El ensayo hace el
   DML real en una transaccion y lo revierte, sin modificar la fase del paquete.
5. Una vez revisado el ensayo, cambiar a `@Aplicar = 1` y ejecutar completo.
   Debe mostrar APLICADO. La aplicacion vuelve a revisar todas las condiciones.
6. Ejecutar `05_VERIFICAR.sql` y conservar resultados. Exigir tres tablas
   IGUAL A ORIGEN SELECCIONADO y cinco conjuntos protegidos SIN CAMBIOS.
   Los grupos diferidos se muestran expresamente; pueden seguir duplicados.

La sustitucion de controles y relaciones es DELETE + INSERT del alcance exacto
dentro de una transaccion, necesaria para retirar copias sin una clave unica.
El INSERT de cobranza es independiente y exige ausencia inicial. Si cualquier
comprobacion falla, se hace ROLLBACK. No eliminar condiciones para continuar.

Si ocurre 1205 o 1222: comprobar que no exista una captura confirmada antes de
reintentar el 01. Si existe el esquema, revisar Estado y no borrarlo.
El error 1205 revierte la transaccion victima; el CATCH revierte otros errores.

## Resultado y limitaciones posteriores

- El grupo 529099 queda Contado, sin fecha de envio del control. La cobranza
  original recuperada tiene su fecha de envio; esa diferencia es la misma
  que en Oracle y no indica que haya que generar un complemento.
- Los documentos y layouts individuales generados en la corrida 26517156
  permanecen intactos, igual que las 15 asignaciones con filas de cobranza
  repetidas. Su conciliacion requiere otro alcance: no eliminar INCOBRABLE
  globalmente ni poner fechas de envio NULL para forzar reproceso.
- Persisten los layouts de 4000 bytes pendientes de revisar; este paquete
  comprueba que no cambien, no certifica su contenido fiscal.
- El control/relaciones 514967 y el caso 529057 siguen pendientes de una
  revision de la cancelacion. Tener un documento confirmado no implica
  que deba volver a generarse o que deba copiarse su relacion original.
- No se crea el componente 614: tampoco aparece en la consulta de Oracle.
  La configuracion operacional requiere revisar LOG_START y la definicion
  instalada antes de preparar una alta nueva.
- La secuencia no se consume ni se reinicia. El paquete exige que su valor
  actual sea superior al maximo local de grupos y a 529099; si no, se detiene.
  Esta comprobacion es conservadora y no reserva numeros entre sesiones.
- Terminar esta reparacion NO habilita automaticamente una ejecucion general
  del agrupador: queda al menos el grupo diferido y las diferencias de cobranza.

## Reversion

`06_REVERTIR.sql` usa `@Revertir = 0` por defecto. Para revertir deliberadamente,
cambiar a 1. Exige Fase APLICADO, que el destino conserve exactamente el estado
aplicado y que los datos protegidos no hayan cambiado.
Recupera controles/relaciones del respaldo, incluidos duplicados anteriores,
y retira exclusivamente la cobranza insertada por este paquete.
No restaura la cobranza cancelada ni toca la secuencia. Si detecta cambios
posteriores, se detiene en lugar de sobrescribir trabajo de otra ejecucion.

## Validacion realizada

Se probaron los scripts en una base temporal aislada de LocalDB con el export
recibido como origen y un escenario de destino sintetico. Se comprobaron:
captura, carga, ensayo con rollback, rechazo de cambios en cancelacion,
rechazo de staging modificado, rollback ante error despues del DELETE,
aplicacion con paridad, preservacion de cancelacion/documentos/layouts,
rechazo de reaplicacion, rechazo de reversion con documento modificado y
reversion exacta sin cambios en secuencia. La base temporal fue eliminada.

Evidencia: `tmp/CodexAGR28_1265c75b28/RESULTADO.txt` desde la raiz del repo.
No se ejecuto el paquete en T3QA ni en Oracle.
`generar.py` y `tests_local.py` son herramientas de mantenimiento; no hace falta
ejecutarlas para usar los SQL entregados. Generar de nuevo sobrescribe los SQL
locales del paquete: no hacerlo sobre archivos editados para una aplicacion.

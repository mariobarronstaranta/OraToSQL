# Ajuste de ReferenceID en SF_PROC_REPLENISHMENT

Basado en el respaldo adjuntado de T3QA del 20/10/2026 13:01.
Para aplicar el ajuste de rendimiento se ejecuta **02_PATCH_REFERENCEID.sql**.
La correccion de permisos del job es independiente y usa el archivo 06.

## Estado y archivos del paquete

El usuario confirmo la aplicacion del parche en T3QA y 820 documentos exitosos
en 46 segundos, equivalentes a 17.83 documentos/segundo. No se modifico
DELIVERY_IDOC_TO_REMISION ni se crearon indices nuevos en esta etapa.

| Archivo | Funcion | Efecto |
|---|---|---|
| `02_PATCH_REFERENCEID.sql` | Aplicar/revertir siete bloques del parser | Modifica el procedimiento |
| `03_DIAGNOSTICO_REMISION.sql` | Consultar cache, planes y errores | Solo lectura |
| `04_MEDIR_LOTE_MANUAL.sql` | Medir el lote habitual | **Procesa documentos pendientes** |
| `05_DIAGNOSTICO_JOB.sql` | Revisar identidad, permisos y errores del job | Solo lectura |
| `06_PERMISOS_LOG_JOB.sql` | Conceder acceso al log y verificar permisos efectivos | Modifica permisos |
| `07_PERMISO_FUNCION_OBD_JOB.sql` | Conceder EXECUTE sobre la funcion OBD al rol | Modifica permisos |
| `08_PERMISOS_CATALOGOS_JOB.sql` | Conceder SELECT sobre MX_HASHTABLE y MATERIAL | Modifica permisos |
| `09_PERMISOS_FLUJO_REPLENISHMENT.sql` | Permisos por objeto de las dependencias revisadas | Modifica permisos |

No ejecutar todos los archivos en secuencia como si fueran un instalador.

## Aplicacion del parche de rendimiento

1. Tener el respaldo guardado y esperar a que termine cualquier lote.
2. Abrir 02_PATCH_REFERENCEID.sql en SSMS, AZCRNMXNEVTD06 / T3QA.
3. Conservar `DECLARE @Revertir bit=0;`. Ejecutar completo fuera de transacciones.
4. Esperar `Revertido=0, BloquesModificados=7`.
5. Ejecutar un lote manual comparable, anotar inicio/fin/documentos correctos,
   y ejecutar RECV_REPLENISHMENT_DIAGNOSTICO.SQL para comparar lecturas/tiempos.

El parche conserva el cuerpo recibido y solo envuelve cuatro DELETE y tres
UPDATE por ReferenceID. Para referencias representables sin perdida en VARCHAR,
agrega igualdad VARCHAR y conserva la comparacion Unicode residual. Para NULL
o referencias no representables conserva la sentencia original.
No cambia el numero/orden de actualizaciones por partida ni la logica de negocio.
La correccion de permisos del job se describe abajo y no requiere reaplicar
el parche de rendimiento.

Si el cuerpo desplegado difiere del respaldo, se detiene antes del ALTER.
Reejecutarlo no acumula cambios. Para revertir, usar el mismo archivo cambiando
`@Revertir=1`; tambien comprueba que no haya modificaciones posteriores.
No ejecutar respaldo_recibido.sql como paso del despliegue: es una copia auxiliar
utilizada en las pruebas. El archivo base del repositorio no fue sustituido:
un despliegue posterior debe incorporar este parche para conservar la mejora.

Validacion local: compilacion del procedimiento recibido con tablas temporales
de negocio segun DDL real, aplicacion/reversa repetidas, siete bloques detectados
y 18 comparaciones de resultados DELETE/UPDATE con NULL, espacios, mayusculas,
acentos, Unicode no representable y referencia de 50 caracteres.
Los procedimientos hijos no se ejecutaron; la funcion OBD se simulo. Estas
pruebas no sustituyen la validacion de documentos completos y planes en T3QA.
La aplicacion en T3QA fue realizada por el usuario, no mediante una conexion
del asistente al servidor.

generar.js y guard_inicio/fin.txt permiten regenerar el archivo desde el respaldo.
Test.ps1 usa una base temporal exclusiva de LocalDB y la elimina al terminar.

## Correccion del error 229 del job

El diagnostico del 20/10/2026 confirma:

- Job `ORA_216_EAI_OWNER_RECV_REPLENISHMENT`, paso TSQL sobre T3QA,
  propietario `T3_SQLAGENT_OWNER`, sin usuario alternativo en el paso.
- La cuenta pertenece a `T3SqlAgentJobExecutor` y puede ejecutar el coordinador.
- El coordinador pertenece a `AT85233588` y RF_PROCESOS_LOG a `dbo`.
  El acceso a la tabla requiere permisos adicionales.
- El error registrado es INSERT denegado sobre `T3.RF_PROCESOS_LOG`.
- El job estaba deshabilitado en esa captura.

Para una base existente, abrir **06_PERMISOS_LOG_JOB.sql** y ejecutarlo
completo como dbo/administrador en AZCRNMXNEVTD06 / T3QA, fuera de una
transaccion externa. Concede SELECT, INSERT y UPDATE sobre esa tabla al rol
existente `T3SqlAgentJobExecutor`. SELECT permite evaluar el filtro PID del
UPDATE de cierre. El script verifica los permisos mediante EXECUTE AS USER
y REVERT, sin ejecutar documentos. Si la comprobacion falla, revierte sus GRANT.
Guardar la salida ANTES; se esperan PuedeLeer=1, PuedeInsertar=1 y
PuedeActualizar=1 al finalizar.

Para instalaciones futuras, los mismos GRANT estan incorporados en
[Jobs/E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL](../../Jobs/E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL).
No es necesario desplegar otra vez los 37 jobs para aplicar la correccion puntual.
Ambos scripts conceden los permisos al mismo rol; repetir GRANT no duplica permisos.
El rol/cuenta es compartido: estos permisos tambien sirven a sus otros jobs.
No se conceden DELETE, ALTER, db_owner ni sysadmin.

**Actualizacion 21/10/2026:** el usuario confirmo que el job ya no reporta
el error del log, pero ahora recibe 229 al ejecutar T3.FN_EVAL_REMISION_OBD.
Se preparo el script 07 y se incorporo el mismo GRANT EXECUTE al despliegue E.
Falta confirmar su aplicacion y una prueba exitosa completa del job.
Los valores de permisos en 1 verifican
esa tabla, no garantizan los permisos de todas las llamadas internas.
Despues de aplicarlo, validar una ejecucion controlada del job sin otro lote
simultaneo, verificar documentos y errores posteriores a la prueba. El coordinador
puede capturar errores sin relanzarlos; el historial de Agent por si solo no
garantiza exito funcional. Habilitar su horario es un paso separado.

Los scripts 05/06 no habilitan, deshabilitan ni inician el job y no cambian
propietarios ni membresias.

## Reversa de permisos

Tras el error SELECT sobre T3.ENTREGA se preparo el archivo 09 para aplicar
en conjunto los permisos revisados de T3/EAI y las llamadas desde T3 a
EAI_OWNER. Incluye las concesiones de 06/07/08; se puede ejecutar directamente
sin repetirlos. No aplica GRANT sobre esquemas completos. Ver @RRPermisos
para la lista exacta de objetos/operaciones. Se incorporo la misma lista al
script E de Jobs.

Ejecutar 09 completo como administrador en T3QA, fuera de transacciones.
Guardar ANTES. Todas las filas deben devolver Permitido=1. El archivo no
ejecuta el flujo ni inicia/habilita jobs. Aun no se ha confirmado su aplicacion
ni una ejecucion completa exitosa del job. Los accesos internos con el mismo
propietario siguen usando la cadena de propiedad; la lista se basa en las
dependencias revisadas, no garantiza cubrir SQL dinamico/triggers o versiones
desplegadas distintas.

No restaurar masivamente mensajes fallidos a pendientes: el parser puede
haber dejado efectos parciales. Conciliar cada documento antes de reprocesarlo.
Para revertir 09, restaurar el estado ANTES de cada permiso y considerar los
otros jobs que comparten el rol; no revocar concesiones previas.

Actualizacion posterior del 21/10: el usuario reporto sucesivamente errores
229 de SELECT sobre EAI_OWNER.MX_HASHTABLE y T3.MATERIAL. Ambos permisos se
incorporaron al script E y al archivo puntual 08. Este ultimo debe devolver
PuedeLeerHashtable=1 y PuedeLeerMaterial=1; no ejecuta el job. Repetir GRANT
sobre MX_HASHTABLE no duplica permisos si ya se aplico la instruccion manual.
No se ha confirmado aun una ejecucion completa del job sin errores.
Para revertir, conservar/restaurar el estado ANTES de cada objeto, sin quitar
permisos anteriores ni afectar otros jobs que usan el mismo rol.

El archivo 07 se ejecuta como administrador, completo y fuera de transacciones.
Guardar la salida ANTES; se espera PuedeEjecutarFuncion=1. Solo verifica
el permiso EXECUTE, sin llamar a la funcion ni validar sus accesos internos.
La reversa puntual debe restaurar el estado ANTES del permiso de la funcion,
sin revocar concesiones previas. Eliminar el rol en el rollback completo
retira tambien este permiso; afecta a todos sus miembros.

La reversa del parche con @Revertir=1 no modifica permisos. Para retirar la
correccion puntual, revisar primero la salida ANTES y las dependencias de otros
jobs; restaurar solo los permisos agregados por esta intervencion. No ejecutar
el rollback completo de Jobs para deshacer tres permisos.

Si se ejecuto la version inicial del archivo 06 que concedia al usuario
T3_SQLAGENT_OWNER directamente, esos GRANT se conservan: cambiar el archivo
no los retira de la base. Revisar permisos directos y del rol antes de una
reversa o limpieza; quitar un GRANT al rol no elimina otro concedido al usuario.

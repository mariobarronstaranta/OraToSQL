# Rollback de SQL Server Agent para T3

Este directorio contiene el procedimiento para deshacer la creacion de jobs y
la solucion de seguridad basada en `T3_SQLAGENT_OWNER`.

> **Advertencia:** el rollback elimina jobs, schedules, roles, permisos y el
> login tecnico. Debe ejecutarse en una ventana de mantenimiento, por un DBA o
> una cuenta `sysadmin`, y primero en un ambiente no productivo.

## Que revierte

El proceso retira:

- Los 37 jobs `ORA_*` y sus schedules administrados por los scripts de migracion.
- Las filas de control de esos jobs y, si quedan vacias, sus tablas auxiliares.
- El wrapper `msdb.dbo.T3_JOB_NEXT_RUN`.
- Los roles `msdb.T3JobExecutors`, `T3QA.T3BODExecutors` y
  `T3QA.T3SqlAgentJobExecutor`.
- El usuario tecnico en `T3QA` y `msdb`, y el login
  `T3_SQLAGENT_OWNER` del servidor.
- Opcionalmente, los usuarios de base de datos de los cuatro ejecutores.

`EAI_OWNER.JOB_NEXT_RUN` no se elimina: se restaura a su version previa, que
llama directamente a los procedimientos de SQL Server Agent.

## Limitacion importante

La instalacion crea o actualiza jobs y schedules por nombre, pero no guarda una
copia de su definicion anterior. Si antes de la migracion ya existia un objeto
con el mismo nombre, este rollback lo eliminara y **no puede reconstruir su
version original**. Antes de continuar, el DBA debe respaldar `msdb` o generar
scripts de los jobs/schedules que necesite conservar.

## Preparacion obligatoria

1. Confirme que el servidor y la base objetivo son correctos (`T3QA`).
2. Abra un ticket/cambio y defina una ventana de mantenimiento.
3. Respalde `msdb` y `T3QA`, o genere scripts de los objetos afectados.
4. Conserve una copia de los archivos de instalacion y rollback ejecutados.
5. Use una cuenta miembro de `sysadmin`.
6. Ejecute cada archivo por separado en SSMS o con `sqlcmd`, en el orden
   indicado abajo. No seleccione y ejecute toda la carpeta de una sola vez.

Los scripts destructivos tienen una variable de confirmacion con valor `0`.
Esto es un seguro: primero lea el archivo y, cuando esté listo, cambie solamente
esa variable a `1`. No retire las validaciones ni los `THROW`.

## Orden exacto de ejecucion

### 00 - `00_PREFLIGHT_ROLLBACK.SQL`

Es de solo lectura. Verifica la cuenta ejecutora, muestra el servidor, cuenta
los jobs migrados y revisa los objetos de seguridad. Si encuentra un job del
alcance ejecutandose, muestra su nombre y detiene el proceso.

Resultado esperado: no debe devolver jobs en ejecucion. Si devuelve alguno,
espere a que termine. Si debe detenerse, solicite esa accion al DBA y vuelva a
ejecutar el preflight.

### 01 - `01_DISABLE_MIGRATED_JOBS.SQL`

Deshabilita los 37 jobs antes de eliminarlos. Esto impide que SQL Server Agent
inicie una nueva ejecucion durante el rollback.

Antes de ejecutar, cambie `@ConfirmDisable` de `0` a `1`. El script valida los
nombres y el propietario tecnico; no deshabilita silenciosamente jobs ajenos.
Al terminar, espere unos segundos y vuelva a ejecutar el paso 00 para asegurar
que ninguna ejecucion sigue activa.

### 02 - `02_REMOVE_JOBS_SCHEDULES_AND_CONTROL.SQL`

Elimina, dentro de una transaccion:

1. Los jobs exactos incluidos en el catalogo del script.
2. Sus schedules exactos, siempre que ya no esten asociados a otro job.
3. Las filas correspondientes de las tablas de mapeo/control.
4. Las tablas auxiliares solamente cuando quedan vacias.

Cambie `@ConfirmRollback` de `0` a `1`. Si ocurre un error, la transaccion se
revierte y se conserva el estado previo a ese intento.

### 03 - `03_RESTORE_JOB_NEXT_RUN_PRE_SECURITY.SQL`

Restaura `T3QA.EAI_OWNER.JOB_NEXT_RUN` a la implementacion anterior. Es
necesario hacerlo antes de retirar el wrapper; de lo contrario, el procedimiento
quedaria llamando a `msdb.dbo.T3_JOB_NEXT_RUN`, que dejará de existir.

Esta version anterior puede volver a requerir permisos elevados al ejecutarse.
Eso es esperado: el objetivo del rollback es regresar al comportamiento previo,
no mantener parcialmente la nueva solucion de seguridad.

### 04 - `04_REMOVE_SECURITY_ROLES_AND_WRAPPER.SQL`

Primero elimina el wrapper de `msdb`, luego saca todos los miembros de los roles
creados por la solucion y finalmente elimina esos roles. Los usuarios se
conservan en este paso para que cualquier dependencia resulte más fácil de
diagnosticar.

Cambie `@ConfirmSecurityRollback` de `0` a `1`.

### 05 - `05_DROP_T3_SQLAGENT_OWNER.SQL`

Retira las membresias restantes del usuario tecnico, elimina sus usuarios en
`T3QA` y `msdb`, y finalmente elimina el login del servidor.

Cambie `@ConfirmDropTechnicalLogin` de `0` a `1` solamente si se confirmó que
`T3_SQLAGENT_OWNER` fue creado exclusivamente para este proyecto. **Omita este
paso si el login existia antes o lo utiliza otra aplicacion.**

El script se detiene si el login aun posee una base, un job o un esquema, o si
el wrapper no fue retirado. No cambie propietarios automaticamente sin analizar
primero a qué cuenta deben transferirse.

### 06 - `06_OPTIONAL_REMOVE_HUMAN_DATABASE_USERS.SQL`

Este paso es opcional y normalmente debe omitirse. Considera estos usuarios:

- `IX85234150`
- `AT85233588`
- `AT85233589`
- `T3`

Solo elimina usuarios de base de datos en `T3QA` y `msdb`; nunca elimina los
logins del servidor o cuentas de Active Directory. Además, conserva cada usuario
que todavía tenga roles, permisos explícitos o sea propietario de un esquema.

Use `@ConfirmDropHumanUsers = 1` únicamente cuando haya evidencia de que esos
usuarios fueron creados por esta implementación y no existían previamente.

### 07 - `07_VERIFY_ROLLBACK.SQL`

Es de solo lectura y debe ejecutarse siempre. Comprueba jobs, mapeos, wrapper,
roles y login tecnico. Si encuentra restos, los lista y genera el error `51671`.

Resultado correcto:

```text
VERIFICACION CORRECTA: no se detectaron componentes obligatorios de la solucion.
EAI_OWNER.JOB_NEXT_RUN permanece restaurado a su version previa.
```

## Que hacer si falla un paso

- Lea primero el mensaje completo y el numero de error.
- No avance al siguiente archivo si el paso actual no terminó correctamente.
- Si falla una dependencia, identifique su propietario y uso antes de borrarla.
- Los pasos transaccionales revierten sus cambios ante errores; aun así, vuelva
  a ejecutar el preflight para conocer el estado real.
- Si el error indica un job activo, espere o solicite al DBA detenerlo.
- Si un rol no puede eliminarse, consulte sus miembros y permisos antes de
  intentar nuevamente.
- Si el login tecnico no puede eliminarse, revise jobs, ownership de bases,
  esquemas, credenciales y cualquier dependencia de otro proyecto.

Los scripts usan verificaciones `IF EXISTS`, por lo que pueden volver a
ejecutarse después de corregir una dependencia. Las confirmaciones regresan a
`0` en los archivos almacenados; cada ejecución destructiva requiere una
decision consciente.

## Checklist para cerrar el cambio

- [ ] Preflight sin jobs activos.
- [ ] Jobs deshabilitados.
- [ ] Jobs, schedules y registros de control retirados.
- [ ] `EAI_OWNER.JOB_NEXT_RUN` restaurado.
- [ ] Wrapper y roles eliminados.
- [ ] Login tecnico eliminado, o excepción documentada porque era compartido.
- [ ] Decisión sobre usuarios humanos documentada.
- [ ] Verificación final sin problemas.
- [ ] Evidencias y mensajes de ejecución anexados al ticket de cambio.

# Jobs T3: migración, seguridad, despliegue y operación

## 1. Objetivo de esta guía

Esta carpeta contiene la migración de 37 procesos programados de Oracle
`DBMS_JOB` a SQL Server Agent. Esta guía explica, desde cero:

- Qué es un job y cómo se relaciona con un schedule y un procedimiento.
- Por qué los jobs no deben pertenecer a una cuenta personal.
- Qué hace el login técnico `T3_SQLAGENT_OWNER`.
- Qué permisos reciben los desarrolladores y cuáles no deben recibir.
- Para qué sirven los scripts `A` a `E`, `00` a `04` y la secuencia completa
  de rollback.
- En qué orden deben ejecutarse.
- Cómo validar el despliegue y resolver los errores más comunes.
- Cómo habilitar, deshabilitar o eliminar los jobs de forma segura.

La guía está escrita para un desarrollador JR. No presupone experiencia previa
administrando SQL Server Agent.

### Mapa rápido de lectura

- Si es la primera vez que trabajas con jobs, lee las secciones 2 a 5.
- Si vas a desplegar, sigue las secciones 7 a 12 sin cambiar el orden.
- Si recibiste un error, ve a la sección 19.
- Si necesitas detener o eliminar jobs, revisa las secciones 13 y 14 y la guía
  `Rollback/readme_rollbacl_jobs.md`.
- Antes de liberar, completa la lista de la sección 21.

## 2. Resumen del ambiente

| Concepto | Valor esperado |
|---|---|
| Base funcional | `T3QA` |
| Base de SQL Server Agent | `msdb` |
| Propietario técnico | `T3_SQLAGENT_OWNER` |
| Jobs migrados | 37 |
| Jobs activos en Oracle | 32 |
| Jobs `BROKEN` en Oracle | 5 |
| Fuente original | `USER_JOBS_SOURCE.csv` |
| Wrapper de seguridad | `msdb.dbo.T3_JOB_NEXT_RUN` |

Los cinco jobs que estaban `BROKEN=Y` en Oracle son:

```text
216, 229, 236, 550 y 648
```

Permanecen deshabilitados durante el despliegue inicial. Los procedimientos
`SF_JOB_MANAGE` y `SF_JOB_MANAGE_EOD` pueden suspenderlos o reactivarlos como
parte de los procesos BOD/EOD.

## 3. Conceptos básicos

### 3.1 Login de servidor

Un login permite autenticarse en la instancia de SQL Server. Existe en el
nivel del servidor, no dentro de una base específica.

Ejemplos:

```text
T3_SQLAGENT_OWNER
AT85233588
IX85234150
```

### 3.2 Usuario de base de datos

Para que un login pueda usar una base, normalmente necesita un usuario mapeado
dentro de esa base.

En esta solución, `T3_SQLAGENT_OWNER` tiene usuario en:

- `msdb`, para ser propietario y administrar sus jobs/schedules.
- `T3QA`, para ejecutar los procedimientos de los steps.

Un login y un usuario pueden tener el mismo nombre, pero son objetos distintos.
El vínculo real se comprueba mediante su `SID`.

### 3.3 Rol

Un rol agrupa permisos. En lugar de conceder permisos uno por uno a cada
persona, se concede el permiso al rol y se agregan usuarios al rol.

### 3.4 Job

Un job de SQL Server Agent representa un proceso programado. Cada job migrado
tiene:

- Un propietario.
- Un step T-SQL.
- Una base de ejecución, `T3QA`.
- Un schedule exclusivo.
- Un estado habilitado o deshabilitado.

### 3.5 Step

El step contiene el comando que ejecuta el job. Ejemplo:

```sql
EXEC [EAI_OWNER].[RECV_CUSTOMER];
```

Los steps de esta migración usan el subsistema `TSQL` y ejecutan en `T3QA`.

### 3.6 Schedule

El schedule define cuándo se ejecuta un job. Cada job tiene un schedule
exclusivo porque varios procedimientos migrados pueden cambiar su fecha/hora:

- `JOB_INTERVAL`
- `JOB_NEXT_DATE`
- `JOB_NEXT_RUN`
- `JOB_MANAGE`

Un schedule compartido sería peligroso: cambiar la fecha de un job también
cambiaría la de otros jobs.

### 3.7 Propietario de job y propietario de schedule

Job y schedule almacenan su propietario por separado. Cambiar únicamente el
propietario del job no cambia automáticamente el del schedule.

Los 37 jobs y los 37 schedules deben pertenecer a:

```text
T3_SQLAGENT_OWNER
```

Si un schedule sigue perteneciendo a una cuenta personal, una ejecución hecha
por otro usuario puede producir:

```text
Only owner of a job schedule or members of sysadmin role can modify or delete
the job schedule.
```

El script `C_SECURITY_REASSIGN_T3_JOB_OWNERS.SQL` corrige ambos propietarios.

## 4. Arquitectura funcional y de seguridad

El flujo relevante para BOD tiene una rama de suspensión y otra de reactivación:

```text
Usuario del equipo
    |
    v
T3.PROC_T3_BOD
    |
    +--> EAI_OWNER.SF_JOB_MANAGE 'Suspend'
    |
    +--> EAI_OWNER.SF_JOB_MANAGE_EOD 'Resume'
    |
    v
EAI_OWNER.JOB_NEXT_RUN
    |
    v
msdb.dbo.T3_JOB_NEXT_RUN
    |
    +--> msdb.dbo.sp_update_job
    |
    +--> msdb.dbo.sp_update_schedule
```

`SF_JOB_MANAGE` procesa cinco jobs. La versión actual de `SF_JOB_MANAGE_EOD`
reactiva tres de ellos: Intercompany, Delivery y Customer. Por ello no debe
suponerse que BOD reactiva automáticamente los cinco jobs que suspendió.

El usuario humano no recibe permiso directo sobre `sp_update_job` ni sobre
`sp_update_schedule`. Obtiene acceso a `PROC_T3_BOD` mediante
`T3QA.T3BODExecutors` y al wrapper mediante `msdb.T3JobExecutors`.

El wrapper:

- Se ejecuta como `T3_SQLAGENT_OWNER`.
- Acepta únicamente cinco parejas job/schedule autorizadas.
- Comprueba que el job exista.
- Comprueba que el schedule exista.
- Comprueba que estén asociados.
- Comprueba que el schedule sea exclusivo.
- Comprueba que ambos pertenezcan a `T3_SQLAGENT_OWNER`.
- Sólo cambia `enabled`, `active_start_date` y `active_start_time`.
- No permite cambiar comandos, frecuencia, propietario ni otros jobs.

## 5. Modelo de seguridad

### 5.1 Principio principal

Las cuentas personales no son propietarias de jobs. El propietario es un login
técnico estable. Los desarrolladores reciben únicamente permiso para iniciar el
flujo funcional autorizado.

### 5.2 Roles utilizados

| Base | Rol | Miembros | Propósito |
|---|---|---|---|
| `msdb` | `SQLAgentUserRole` | `T3_SQLAGENT_OWNER` | Permite administrar únicamente jobs/schedules propios. |
| `msdb` | `T3JobExecutors` | Login técnico y equipo autorizado | Permite ejecutar el wrapper controlado. |
| `T3QA` | `T3SqlAgentJobExecutor` | `T3_SQLAGENT_OWNER` | Ejecuta los entry points de los 37 jobs y recibe permisos acotados de control y log. |
| `T3QA` | `T3BODExecutors` | Equipo autorizado | Permite ejecutar `T3.PROC_T3_BOD`. |

### 5.3 Usuarios humanos autorizados actualmente

El script `D_SECURITY_GRANT_T3_JOB_EXECUTORS.SQL` contiene esta lista:

```text
IX85234150
AT85233588
AT85233589
T3
```

Todos deben existir previamente como logins de servidor. El script crea sus
usuarios en `msdb` y `T3QA` cuando sea necesario y los agrega a los roles
controlados.

La lista `@TeamLogins` del script `D` se utiliza para el aprovisionamiento
inicial. Para altas posteriores no es necesario editar D: se instala una vez
`D1_SECURITY_CREATE_MSDB_T3_ADD_JOB_EXECUTORS.SQL` y después el DBA llama a
`msdb.dbo.T3_ADD_JOB_EXECUTORS` con los nuevos nombres separados por comas.

Para varios operadores se recomienda registrar una sola vez un grupo de Active
Directory, por ejemplo `DOMINIO\Operador_SQL_Jobs`, en lugar de administrar cada
cuenta individualmente. Debe utilizarse el nombre exacto que aparece en
`master.sys.server_principals`; un nombre local como `Operador_SQL_Jobs` sólo es
válido si ése es realmente el nombre del login creado en SQL Server.

Proceso de alta de un operador o grupo:

1. El DBA crea o confirma el login de servidor.
2. Confirma que el script D1 ya instaló `msdb.dbo.T3_ADD_JOB_EXECUTORS`.
3. Ejecuta el procedimiento con los nombres separados por comas.
4. Comprueba que cada principal aparezca en `msdb.T3JobExecutors` y
   `T3QA.T3BODExecutors`.
5. Se prueba `PROC_T3_BOD` con una ejecución controlada.

La baja requiere retirarlo de ambos roles. No se debe borrar el login hasta
confirmar que ninguna otra aplicación lo utiliza. Los operadores humanos no se
agregan a `T3SqlAgentJobExecutor` ni a roles fijos de SQL Server Agent.

### 5.4 Permisos que no se deben conceder

No se debe:

- Agregar desarrolladores a `sysadmin`.
- Agregar desarrolladores a `db_owner`.
- Concederles `EXECUTE` directo sobre `sp_update_job` o `sp_update_schedule`.
- Conceder `IMPERSONATE` sobre la cuenta técnica.
- Activar `TRUSTWORTHY ON` como solución rápida.
- Volver a colocar un usuario personal como propietario.
- Agregar usuarios humanos a `T3SqlAgentJobExecutor`.

## 6. Archivos incluidos

### 6.1 Scripts funcionales

| Archivo | Función | Modifica estado |
|---|---|---:|
| `00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL` | Rollback legado y limitado: elimina jobs, schedules y filas de control, pero no revierte la seguridad. | Sí, destructivo |
| `01_CREATE_OR_UPDATE_JOBS.SQL` | Crea/actualiza 37 jobs, schedules y tablas de control; deja jobs deshabilitados. | Sí |
| `02_VALIDATE_JOBS.SQL` | Valida objetos, configuración, propietarios, permisos y dependencias. | No |
| `03_ENABLE_VALIDATED_JOBS.SQL` | Habilita los 32 jobs que estaban activos en Oracle. | Sí |
| `04_DISABLE_MIGRATED_JOBS.SQL` | Deshabilita los 37 jobs sin eliminarlos. | Sí |

### 6.2 Scripts de seguridad

| Archivo | Base principal | Función |
|---|---|---|
| `A_SECURITY_CREATE_T3_SQLAGENT_OWNER.SQL` | `master`, `msdb`, `T3QA` | Crea el login técnico y sus usuarios. |
| `B_SECURITY_CREATE_MSDB_T3_JOB_NEXT_RUN.SQL` | `msdb` | Crea el wrapper de privilegio controlado. |
| `C_SECURITY_REASSIGN_T3_JOB_OWNERS.SQL` | `msdb` | Reasigna los 37 jobs y schedules al login técnico. |
| `D_SECURITY_GRANT_T3_JOB_EXECUTORS.SQL` | `msdb`, `T3QA` | Crea roles y agrega a los usuarios humanos autorizados. |
| `D1_SECURITY_CREATE_MSDB_T3_ADD_JOB_EXECUTORS.SQL` | `msdb` | Crea el procedimiento reutilizable para altas posteriores mediante una lista CSV. |
| `E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL` | `T3QA` | Concede mediante rol permisos de ejecución, control y acceso a `T3.RF_PROCESOS_LOG`. |

### 6.3 Archivos de soporte

| Archivo | Función |
|---|---|
| `USER_JOBS_SOURCE.csv` | Inventario original exportado desde Oracle. |
| `MSSQL/T3/EAI_OWNER/Procedures/JOB_NEXT_RUN.SQL` | Procedimiento funcional que llama al wrapper de `msdb`. |
| `Rollback/readme_rollbacl_jobs.md` | Guía y orden obligatorio para revertir jobs, wrapper, roles, usuarios y login técnico. |

## 7. Prerrequisitos

Antes de ejecutar cualquier despliegue, confirmar:

1. La instancia es la correcta.
2. Existe la base `T3QA`.
3. SQL Server Agent está instalado e iniciado.
4. La ejecución no se hace en LocalDB; LocalDB no proporciona SQL Server Agent.
5. El DBA dispone de una cuenta `sysadmin` para los scripts de seguridad.
6. Todos los logins o grupos autorizados en `@TeamLogins` existen en
   `master.sys.server_principals`.
7. Los procedimientos requeridos por los 37 jobs están desplegados en `T3QA`.
8. Existe el esquema `EAI_OWNER` en `T3QA`.

Consulta de contexto:

```sql
SELECT
    @@SERVERNAME AS Server_Name,
    DB_NAME() AS Database_Name,
    SUSER_SNAME() AS Login_Name,
    IS_SRVROLEMEMBER(N'sysadmin') AS Is_Sysadmin;
```

Consulta de logins humanos:

```sql
SELECT [name], [type_desc], is_disabled
FROM master.sys.server_principals
WHERE [name] IN
(
    N'IX85234150',
    N'AT85233588',
    N'AT85233589',
    N'T3'
)
ORDER BY [name];
```

El resultado debe contener una fila por cada principal configurado y
`is_disabled` debe ser `0`. Si se utiliza un grupo AD, agregar su nombre
completo a la consulta.

## 8. Orden completo de despliegue

El orden obligatorio para un ambiente nuevo es:

```text
A
-> 01
-> B
-> C
-> D
-> D1
-> desplegar EAI_OWNER.JOB_NEXT_RUN
-> E
-> 02
-> pruebas funcionales
-> 03
```

| Paso | Archivo/acción | Ejecuta | Base seleccionada |
|---:|---|---|---|
| 1 | `A_SECURITY_CREATE_T3_SQLAGENT_OWNER.SQL` | DBA `sysadmin` | El script cambia de base internamente. |
| 2 | `01_CREATE_OR_UPDATE_JOBS.SQL` | DBA `sysadmin` | Seleccionar `T3QA`. |
| 3 | `B_SECURITY_CREATE_MSDB_T3_JOB_NEXT_RUN.SQL` | DBA `sysadmin` | El script selecciona `msdb`. |
| 4 | `C_SECURITY_REASSIGN_T3_JOB_OWNERS.SQL` | DBA `sysadmin` | El script selecciona `msdb`. |
| 5 | `D_SECURITY_GRANT_T3_JOB_EXECUTORS.SQL` | DBA `sysadmin` | El script selecciona `msdb` y usa `T3QA`. |
| 6 | `D1_SECURITY_CREATE_MSDB_T3_ADD_JOB_EXECUTORS.SQL` | DBA `sysadmin` | Instala en `msdb` el helper para altas futuras. |
| 7 | `MSSQL/T3/EAI_OWNER/Procedures/JOB_NEXT_RUN.SQL` | DBA/deployer | Seleccionar `T3QA`; debe existir antes de ejecutar `E`. |
| 8 | `E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL` | DBA `sysadmin` o `db_owner` | El script selecciona `T3QA`. |
| 9 | `02_VALIDATE_JOBS.SQL` | `T3_SQLAGENT_OWNER` | Seleccionar `T3QA`. |
| 10 | Pruebas funcionales | Equipo autorizado | Seleccionar `T3QA`. |
| 11 | `03_ENABLE_VALIDATED_JOBS.SQL` | `T3_SQLAGENT_OWNER` | Seleccionar `T3QA`. |

Para un ambiente donde `A` y `01` ya se ejecutaron, aplicar:

```text
B -> C -> D -> D1 -> JOB_NEXT_RUN.SQL -> E -> 02 -> pruebas
```

No ejecutar `03` hasta obtener `PASS` en `02`.

## 9. Explicación paso a paso

### Paso A: crear el propietario técnico

Archivo:

```text
A_SECURITY_CREATE_T3_SQLAGENT_OWNER.SQL
```

Antes de la primera ejecución, cambiar la contraseña provisional. No guardar la
contraseña real en Git.

El script:

- Crea el login SQL `T3_SQLAGENT_OWNER` si no existe.
- Crea su usuario en `msdb`.
- Lo agrega a `SQLAgentUserRole`.
- Crea su usuario en `T3QA`.
- No concede `sysadmin` ni `db_owner`.

Es idempotente y no cambia la contraseña si el login ya existe.

### Paso 01: crear los jobs deshabilitados

Archivo:

```text
01_CREATE_OR_UPDATE_JOBS.SQL
```

Debe ejecutarse conectado a `T3QA`. Crea o actualiza:

- 37 jobs.
- 37 steps T-SQL.
- 37 schedules exclusivos.
- La asociación de cada job con su schedule.
- El servidor local de ejecución.
- `EAI_OWNER.Job_Oracle_SQLAgent_Map`.
- `EAI_OWNER.Job_Oracle_Migration_Catalog`.

Todos los jobs se dejan deshabilitados. Esto evita ejecuciones accidentales
antes de terminar la validación.

Las tablas de control tienen funciones distintas:

| Tabla | Propósito |
|---|---|
| `Job_Oracle_SQLAgent_Map` | Relaciona el número Oracle con `job_id` y `schedule_id`. |
| `Job_Oracle_Migration_Catalog` | Conserva comando, procedimiento, estado Oracle e intervalo convertido. |

### Paso B: crear el wrapper de `msdb`

Archivo:

```text
B_SECURITY_CREATE_MSDB_T3_JOB_NEXT_RUN.SQL
```

Crea:

```text
msdb.dbo.T3_JOB_NEXT_RUN
```

Se ejecuta con `WITH EXECUTE AS 'T3_SQLAGENT_OWNER'`. Su lista permitida incluye
solamente:

| Oracle job | Job SQL Agent | Schedule |
|---:|---|---|
| 216 | `ORA_216_EAI_OWNER_RECV_REPLENISHMENT` | `SCH_ORA_216` |
| 229 | `ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY` | `SCH_ORA_229` |
| 236 | `ORA_236_EAI_OWNER_RECV_PAYMENT` | `SCH_ORA_236` |
| 550 | `ORA_550_EAI_OWNER_RECV_INVOICE` | `SCH_ORA_550` |
| 648 | `ORA_648_EAI_OWNER_RECV_CUSTOMER` | `SCH_ORA_648` |

### Paso C: corregir propietarios

Archivo:

```text
C_SECURITY_REASSIGN_T3_JOB_OWNERS.SQL
```

Reasigna los 37 jobs y los 37 schedules. Debe ejecutarlo un `sysadmin`, porque
sólo `sysadmin` puede cambiar un propietario existente.

El resultado esperado por fila es:

```text
JobOwner      = T3_SQLAGENT_OWNER
ScheduleOwner = T3_SQLAGENT_OWNER
OwnerStatus   = OK
```

Si falta un objeto, existe una asociación incorrecta o un schedule está
compartido, el script no realiza una reasignación parcial.

### Paso D: autorizar al equipo

Archivo:

```text
D_SECURITY_GRANT_T3_JOB_EXECUTORS.SQL
```

El script contiene `@TeamLogins` con cuatro logins. Antes de modificar permisos:

- Confirma que todos existan en el servidor.
- Verifica que no haya usuarios homónimos con otro `SID`.
- Confirma que existan el wrapper y `PROC_T3_BOD`.
- Confirma que los nombres de los roles no estén ocupados por otro tipo de objeto.

Después crea usuarios, roles y permisos dentro de una transacción.

Resultado esperado en `msdb`:

```text
T3JobExecutors
  - T3_SQLAGENT_OWNER
  - IX85234150
  - AT85233588
  - AT85233589
  - T3
```

Resultado esperado en `T3QA`:

```text
T3BODExecutors
  - IX85234150
  - AT85233588
  - AT85233589
  - T3
```

El login `T3` debe existir como login de servidor. No basta con que exista un
esquema o un usuario llamado `T3` dentro de `T3QA`.

#### Alta posterior mediante `T3_ADD_JOB_EXECUTORS`

Primero se instala el procedimiento una sola vez:

```text
D1_SECURITY_CREATE_MSDB_T3_ADD_JOB_EXECUTORS.SQL
```

Si el nuevo ejecutor es un login SQL llamado exactamente
`Operador_SQL_Jobs`, el DBA ejecuta:

```sql
EXEC msdb.dbo.T3_ADD_JOB_EXECUTORS
    @LoginNames = N'Operador_SQL_Jobs';
```

Para agregar varios logins o un grupo de Active Directory:

```sql
EXEC msdb.dbo.T3_ADD_JOB_EXECUTORS
    @LoginNames =
        N'IX85234150, AT85233588, DOMINIO\Operador_SQL_Jobs';
```

El procedimiento ignora espacios alrededor de la coma y elimina duplicados.
Primero valida la lista completa y después realiza las altas en una transacción;
si un login no existe, está deshabilitado o tiene un SID incompatible, no aplica
altas parciales. La coma es el separador y no puede formar parte de un nombre.

El resultado correcto contiene dos filas por principal: una para
`msdb.T3JobExecutors` y otra para `T3QA.T3BODExecutors`. No es suficiente
agregarlo únicamente al rol de `T3QA`, porque la cadena termina llamando al
wrapper ubicado en `msdb`.

### Desplegar `EAI_OWNER.JOB_NEXT_RUN` antes del paso E

Archivo:

```text
MSSQL/T3/EAI_OWNER/Procedures/JOB_NEXT_RUN.SQL
```

La definición correcta contiene:

```sql
EXEC @ReturnCode = msdb.dbo.T3_JOB_NEXT_RUN
    @JobId = @SqlAgentJobId,
    @ScheduleId = @ScheduleId,
    @Enabled = @Enabled,
    @ActiveDate = @ActiveStartDate,
    @ActiveTime = @ActiveStartTime;
```

No debe contener llamadas directas desde `JOB_NEXT_RUN` a:

```text
msdb.dbo.sp_update_job
msdb.dbo.sp_update_schedule
```

### Paso E: autorizar al propietario técnico

Actualizacion del flujo RECV_REPLENISHMENT: el script E incluye permisos
por objeto para sus dependencias revisadas de T3 y EAI y para las llamadas
desde T3 a EAI_OWNER. Para una base existente usar
[09_PERMISOS_FLUJO_REPLENISHMENT.sql](../Package/RECV_REPLENISHMENT_PERF/09_PERMISOS_FLUJO_REPLENISHMENT.sql).
Este archivo agrupa las correcciones de permisos de 06/07/08 y agrega las
operaciones identificadas en entregas, remisiones y catalogos. No es necesario
ejecutar primero esos tres archivos. La lista exacta esta en @RRPermisos;
no concede permisos de esquema, ALTER ni roles de administracion.
Guardar el resultado ANTES; todas las filas de verificacion deben mostrar
Permitido=1. Si falla, el archivo 09 revierte sus concesiones de esa ejecucion.
La prueba del job sigue siendo necesaria: cambios posteriores en dependencias,
SQL dinamico o triggers pueden requerir otra revision.

Archivo:

```text
E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL
```

Crea el rol `T3QA.T3SqlAgentJobExecutor`, agrega únicamente a
`T3_SQLAGENT_OWNER` y concede:

- `EXECUTE` sobre los 37 procedimientos principales del catálogo.
- `SELECT` y `UPDATE` sobre `Job_Oracle_SQLAgent_Map`.
- `SELECT` sobre `Job_Oracle_Migration_Catalog`.
- `EXECUTE` sobre `T3.FN_EVAL_REMISION_OBD`, llamada por el parser de reabasto.
- `SELECT` sobre `EAI_OWNER.MX_HASHTABLE` y `T3.MATERIAL`, por errores 229
  confirmados al ejecutar el flujo mediante el job.
- `SELECT`, `INSERT` y `UPDATE` sobre `T3.RF_PROCESOS_LOG`, mediante el rol
  `T3SqlAgentJobExecutor`. Permiten registrar el inicio y cierre por `PID`
  cuando el procedimiento y la tabla tienen propietarios distintos.
- `VIEW DEFINITION` sobre `JOB_NEXT_RUN`, `PROC_T3_BOD` y `PROC_T3_EOD`.

- `EXECUTE` sobre `T3.PROC_T3_OT_GENERAL`, dependencia del coordinador
  `EAI_OWNER.RECV_INVOICE_INTERCOMPANY`. En T3QA se confirmaron propietarios
  diferentes y falta de visibilidad/ejecucion bajo `T3_SQLAGENT_OWNER`.
  Para una instalacion existente basta ejecutar como sysadmin la
  [correccion puntual del permiso](../../Diagnosticos/RECV_INVOICE_INTERCOMPANY_50021_CORREGIR_PERMISO.sql).
  Verifica el acceso efectivo sin iniciar jobs ni procesar documentos; no es
  necesario repetir el despliegue completo. El mensaje `50021` no demostraba
  ausencia del objeto: `OBJECT_ID` devolvia NULL por falta de visibilidad.
  La siguiente corrida normal debe validarse por separado para detectar
  errores posteriores. No se conceden permisos adicionales sobre los dos
  procedimientos internos T3 que comparten propietario con el procedimiento.

No agregar usuarios humanos a este rol.

El lote con datos del 23 de octubre de 2026, PID `26516078`, fallo por DELETE
denegado en `T3.PREVENTA_GENERAL`. Para la ruta `INVOICE_TO_PREVENTA`, el script E
incluye SELECT/INSERT/UPDATE/DELETE en general, SELECT/INSERT/DELETE en detalle y
condiciones y EXECUTE en `T3.DELIVERY_WA_OXXO`. RF_COMPLEMENTO y MATERIAL ya estan
incluidos en el bloque de permisos anterior. Para una base existente ejecutar
solo [el ajuste puntual de preventa](../../Diagnosticos/RECV_INVOICE_INTERCOMPANY_229_PERMISOS_PREVENTA.sql)
como sysadmin; verifica quince permisos efectivos sin procesar documentos.
El delegado puede haber marcado el mensaje antes del fallo. Ejecutar tambien
[la revision de mensajes](../../Diagnosticos/RECV_INVOICE_INTERCOMPANY_26516078_REVISION_MENSAJE.sql)
antes de decidir un reproceso; no actualiza estados ni garantiza que los
candidatos temporales correspondan al PID. No se modificaron procedimientos.

La revision posterior identifico diez errores adicionales por SELECT denegado
en `T3.OTROS_GENERAL`. El script E incluye tambien los permisos de reconstruccion
de OTROS, UPDATE de detalle para V33/retenciones y SELECT de `CFDI_PRODSERV_WA`.
Para una instalacion existente usar el
[ajuste combinado PREVENTA/OTROS](../../Diagnosticos/RECV_INVOICE_INTERCOMPANY_229_PERMISOS_RUTAS.sql),
que verifica 29 permisos y puede aplicarse aunque ya se haya ejecutado el ajuste
de PREVENTA. RF_COMPLEMENTO y los catalogos se incluyen sin permisos de esquema.
Los once mensajes se marcaron Processed pese a sus errores. La
[revision de los once documentos](../../Diagnosticos/RECV_INVOICE_INTERCOMPANY_26516078_ESTADO_11_DOCUMENTOS.sql)
verifica identidad, temporales, salidas y definicion instalada. Sus CREATED son
del 4/5 de octubre, fuera de los cinco dias del selector local al 23 de octubre;
no basta con resetear PROCESSED sin verificar la version instalada. Estos scripts
no ejecutan reprocesos ni cambian reglas de estados/errores de los SP.

En la corrida de las 17:25 se reporto SELECT denegado en
`EAI_OWNER.TMP_DOCUMENT_PARTNERS`, consultada tambien por
`T3.PROC_V40_GENERAR_OTROS`. El ajuste combinado y el script E incluyen ahora
esa lectura (el combinado anterior verificaba 28 permisos). Si ya se aplico
el combinado anterior, ejecutar solo el
[permiso puntual de partners](../../Diagnosticos/RECV_INVOICE_INTERCOMPANY_229_PERMISO_PARTNERS.sql)
como sysadmin. Debe devolver `PuedeLeer=1`. No inicia jobs ni reprocesos, ni
concede permisos de modificacion sobre partners. El mensaje aislado no
identifica el PID, la factura ni el procedimiento exacto que lo registro.

Antes de ejecutar `E` deben existir:

- Los 37 procedimientos principales incluidos en el catálogo.
- `EAI_OWNER.JOB_NEXT_RUN`, ya actualizado para llamar al wrapper de `msdb`.
- `T3.PROC_T3_BOD`.
- `T3.PROC_T3_EOD`.
- La tabla `T3.RF_PROCESOS_LOG` (si falta, el script devuelve `51506`).
- La funcion escalar `T3.FN_EVAL_REMISION_OBD` (si falta, devuelve `51507`).
- Las tablas `EAI_OWNER.MX_HASHTABLE` y `T3.MATERIAL` (si falta alguna,
  devuelve `51508`).

Para agregar solo las lecturas confirmadas en una instalacion existente,
ejecutar [08_PERMISOS_CATALOGOS_JOB.sql](../Package/RECV_REPLENISHMENT_PERF/08_PERMISOS_CATALOGOS_JOB.sql).
Verifica ambos permisos efectivos en la cuenta tecnica sin procesar documentos.

Para el error 229 especifico de la funcion OBD en una instalacion existente,
ejecutar [07_PERMISO_FUNCION_OBD_JOB.sql](../Package/RECV_REPLENISHMENT_PERF/07_PERMISO_FUNCION_OBD_JOB.sql)
como administrador. Agrega EXECUTE al mismo rol y debe devolver
PuedeEjecutarFuncion=1. No ejecuta la funcion ni inicia el job. Esa verificacion
no certifica los permisos de los objetos internos de la funcion.

La correccion puntual [06_PERMISOS_LOG_JOB.sql](../Package/RECV_REPLENISHMENT_PERF/06_PERMISOS_LOG_JOB.sql)
concede estos mismos permisos al rol existente y verifica su acceso efectivo
para `T3_SQLAGENT_OWNER`. No habilita ni inicia jobs. Si ya se ejecuto una
version anterior que concedia permisos directamente al usuario, esos permisos
se conservan; este despliegue no los revoca automaticamente.

Esta correccion atiende el error 229 de `RECV_REPLENISHMENT` al insertar en
`T3.RF_PROCESOS_LOG`. El diagnostico mostro propietarios diferentes para el
procedimiento y la tabla. La cuenta tecnica ya tenia EXECUTE sobre el
procedimiento, pero le faltaba acceso a la tabla.

Para corregir una instalacion existente basta el script 06, ejecutado como
administrador; no es necesario recrear jobs ni repetir todo el despliegue.
Debe devolver PuedeLeer=1, PuedeInsertar=1 y PuedeActualizar=1. Esto verifica
permisos efectivos sobre el log; luego se debe comprobar una ejecucion del job
y sus resultados de negocio. El procedimiento puede registrar errores sin
relanzarlos, por lo que un estado exitoso en Agent no basta.
La habilitacion del horario del job es independiente y no la realiza el script 06.
Ver [instrucciones y reversa puntual](../Package/RECV_REPLENISHMENT_PERF/LEEME.md).

Si falta un procedimiento del catálogo, el script devuelve `51504`, muestra
`Missing_Procedure` y no concede permisos parciales. Si falta uno de los tres
objetos usados por los `GRANT VIEW DEFINITION`, la transacción también falla y
debe corregirse el despliegue antes de repetir `E`.

Los cinco entry points de `SF_JOB_MANAGE` están en:

```text
MSSQL/T3/EAI_OWNER/Package/RECV_REPLENISHMENT.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_INVOICE_INTERCOMPANY.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_PAYMENT.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_INVOICE.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_CUSTOMER.SQL
```

## 10. Validación con `02_VALIDATE_JOBS.SQL`

Ejecutar como `T3_SQLAGENT_OWNER`, conectado a `T3QA`.

El script es de solo lectura y produce cinco grupos de resultados:

1. Detalle de los 37 jobs.
2. Resumen de objetos válidos.
3. Dependencias de segundo nivel.
4. Referencias Oracle inválidas.
5. Wrapper, roles, integración y propietarios.

### 10.1 Estados principales

| Columna | Significado |
|---|---|
| `Catalog_Status` | La fila existe en el catálogo de migración. |
| `Dependency_Status` | El procedimiento principal existe. |
| `Execute_Permission_Status` | El propietario técnico puede ejecutarlo. |
| `Map_Status` | El número Oracle apunta al job/schedule correctos. |
| `Job_Status` | Job existente, deshabilitado, propietario correcto y servidor asociado. |
| `Step_Status` | Step T-SQL con comando, base y acciones correctas. |
| `Schedule_Status` | Schedule existente, asociado, configurado y con propietario correcto. La exclusividad de los cinco schedules controlados se revisa en el resultado 5. |
| `Deployment_Status` | Primer error encontrado o `OK`. |

Resultado esperado:

```text
Validation_Result = PASS
Ready_Jobs = 37
```

Si cualquier estado es distinto de `OK`, no ejecutar `03`.

`02` espera que los 37 jobs estén deshabilitados. Si se ejecuta después de `03`,
los 32 jobs activos pueden aparecer como `JOB_NOT_DISABLED`. Esto no implica que
la activación haya fallado; significa que `02` está diseñado como validación
previa.

## 11. Pruebas funcionales

Antes de habilitar jobs:

1. Ejecutar `T3.PROC_T3_BOD` con uno de los usuarios autorizados.
2. Confirmar que no aparezca un error de propietario de schedule.
3. Comprobar que `SF_JOB_MANAGE 'Suspend'` deshabilite los cinco jobs esperados.
4. Comprobar por separado que `SF_JOB_MANAGE_EOD 'Resume'` reactive únicamente
   Intercompany, Delivery y Customer según la implementación actual.
5. Confirmar que `Last_Update_User` registre al usuario llamador.
6. Ejecutar cada `Step_Command` con parámetros controlados.
7. Comparar resultados con Oracle.
8. Revisar duración, bloqueos y concurrencia.
9. Revisar SQL Server Agent Job History.

Consulta de estado de los cinco jobs controlados:

```sql
SELECT
    J.[name] AS JobName,
    J.[enabled],
    SUSER_SNAME(J.owner_sid) AS JobOwner,
    S.[name] AS ScheduleName,
    SUSER_SNAME(S.owner_sid) AS ScheduleOwner
FROM msdb.dbo.sysjobs AS J
INNER JOIN msdb.dbo.sysjobschedules AS JS
    ON JS.job_id = J.job_id
INNER JOIN msdb.dbo.sysschedules AS S
    ON S.schedule_id = JS.schedule_id
WHERE J.[name] IN
(
    N'ORA_216_EAI_OWNER_RECV_REPLENISHMENT',
    N'ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY',
    N'ORA_236_EAI_OWNER_RECV_PAYMENT',
    N'ORA_550_EAI_OWNER_RECV_INVOICE',
    N'ORA_648_EAI_OWNER_RECV_CUSTOMER'
)
ORDER BY J.[name];
```

Todos deben mostrar `T3_SQLAGENT_OWNER` como propietario del job y schedule.

## 12. Habilitación con `03_ENABLE_VALIDATED_JOBS.SQL`

Sólo después de recibir `PASS` en `02`, cambiar:

```sql
DECLARE @ConfirmEnable BIT = 1;
```

Ejecutar como `T3_SQLAGENT_OWNER` desde `T3QA`.

El script:

- Repite validaciones críticas.
- Habilita los 32 jobs que estaban activos en Oracle.
- Mantiene deshabilitados los cinco `BROKEN`.
- Usa una transacción para evitar una activación parcial.

Resultado esperado:

```text
ACTIVACION COMPLETADA
```

Al terminar, regresar la variable a:

```sql
DECLARE @ConfirmEnable BIT = 0;
```

## 13. Deshabilitación operativa

Para impedir ejecuciones futuras sin eliminar objetos, usar:

```text
04_DISABLE_MIGRATED_JOBS.SQL
```

Cambiar temporalmente:

```sql
DECLARE @ConfirmDisable BIT = 1;
```

Puede ejecutarlo `T3_SQLAGENT_OWNER` o un `sysadmin`.

Deshabilitar un job no detiene una ejecución que ya comenzó. Detener un job en
curso requiere una decisión operativa del DBA porque puede dejar una transacción
o proceso funcional incompleto.

Al terminar, regresar `@ConfirmDisable` a `0`.

## 14. Rollback completo

El rollback completo ya no consiste únicamente en ejecutar
`00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL`. Ese archivo se conserva como rollback
legado y sólo elimina jobs, schedules y datos de control; no retira el wrapper,
los roles ni el login técnico.

La secuencia vigente se encuentra en el directorio `Rollback` y debe ejecutarse
en este orden:

| Orden | Archivo | Propósito |
|---:|---|---|
| 0 | `Rollback/00_PREFLIGHT_ROLLBACK.SQL` | Comprueba el ambiente y detiene el proceso si hay jobs activos. |
| 1 | `Rollback/01_DISABLE_MIGRATED_JOBS.SQL` | Deshabilita los 37 jobs para impedir nuevas ejecuciones. |
| 2 | `Rollback/02_REMOVE_JOBS_SCHEDULES_AND_CONTROL.SQL` | Elimina jobs, schedules y datos de control. |
| 3 | `Rollback/03_RESTORE_JOB_NEXT_RUN_PRE_SECURITY.SQL` | Restaura `EAI_OWNER.JOB_NEXT_RUN` a su versión previa. |
| 4 | `Rollback/04_REMOVE_SECURITY_ROLES_AND_WRAPPER.SQL` | Elimina wrapper, helper de altas y roles controlados. |
| 5 | `Rollback/05_DROP_T3_SQLAGENT_OWNER.SQL` | Elimina usuarios y login técnico, si no es compartido. |
| 6 | `Rollback/06_OPTIONAL_REMOVE_HUMAN_DATABASE_USERS.SQL` | Opcionalmente elimina usuarios humanos sin dependencias. |
| 7 | `Rollback/07_VERIFY_ROLLBACK.SQL` | Verifica que no queden componentes obligatorios. |

La explicación detallada está en
[`Rollback/readme_rollbacl_jobs.md`](Rollback/readme_rollbacl_jobs.md).

Los pasos destructivos mantienen sus variables de confirmación en `0`. El DBA
debe revisar cada archivo y cambiar a `1` únicamente la confirmación del paso
que va a ejecutar. No se debe avanzar si el paso anterior produjo un error.

El paso 5 se omite cuando `T3_SQLAGENT_OWNER` existía antes del proyecto o es
utilizado por otra aplicación. El paso 6 también es opcional: retirar a una
persona de los roles no significa que deba borrarse su login de servidor.

El instalador no conserva una copia de una definición preexistente con el mismo
nombre. El rollback puede eliminarla, pero no reconstruirla. Antes de comenzar,
el DBA debe respaldar `msdb`/`T3QA` o generar scripts de los objetos que necesite
conservar.

## 15. Nomenclatura

La convención es determinística:

```text
Job:      ORA_<numero Oracle>_<schema>_<procedimiento>
Schedule: SCH_ORA_<numero Oracle>
```

Ejemplo:

```text
ORA_42_EAI_OWNER_WA_ERR_INTERCOMPANY
SCH_ORA_42
```

Nunca cambiar manualmente un nombre sin actualizar también:

- `01_CREATE_OR_UPDATE_JOBS.SQL`
- `02_VALIDATE_JOBS.SQL`
- `03_ENABLE_VALIDATED_JOBS.SQL`
- `04_DISABLE_MIGRATED_JOBS.SQL`
- `C_SECURITY_REASSIGN_T3_JOB_OWNERS.SQL`
- Las listas permitidas del wrapper, si el job pertenece a `SF_JOB_MANAGE`.
- Las tablas de mapeo y catálogo.

## 16. Conversión desde Oracle

### 16.1 Packages

SQL Server no tiene packages Oracle. Las llamadas fueron convertidas así:

| Oracle | SQL Server |
|---|---|
| `RECV_TO_SEND_V3.Recv_Replenishment` | `[EAI_OWNER].[RECV_REPLENISHMENT]` |
| `RECV_TO_SEND_V3.Recv_Invoice_Intercompany` | `[EAI_OWNER].[RECV_INVOICE_INTERCOMPANY]` |
| `RECV_TO_SEND_V3.Recv_Payment` | `[EAI_OWNER].[RECV_PAYMENT]` |
| `RECV_TO_SEND_V3.Recv_Invoice` | `[EAI_OWNER].[RECV_INVOICE]` |
| `RECV_TO_SEND_V3.Recv_Customer` | `[EAI_OWNER].[RECV_CUSTOMER]` |

No reintroducir el prefijo `RECV_TO_SEND_V3` en comandos T-SQL.

### 16.2 Calendarios

| Oracle | SQL Server Agent |
|---|---|
| `SYSDATE + N/1440` | Cada `N` minutos. |
| `SYSDATE + N/24` | Cada `N` horas. |
| `TRUNC(SYSDATE + 1) + N/1440` | Ejecución diaria en el minuto `N`. |
| `TRUNC(SYSDATE + 1) + N/24` | Ejecución diaria a la hora `N`. |

Oracle recalcula `INTERVAL`; SQL Server Agent usa una cuadrícula fija. Si un job
dura más que su intervalo, la siguiente ejecución puede diferir de Oracle.

El CSV no contiene la hora completa de `NEXT_DATE`; la fecha/hora inicial se
deriva del intervalo durante el despliegue.

## 17. Dependencias conocidas

`02` valida estas dependencias de segundo nivel:

- Procedimientos: `DELIVERY_CLEAR`, `PROC_V40_GENERAR_MX06_CM`,
  `PROC_CFDI_GENERAR_PAGO`, `PROC_CFDI_GENERAR_PAGO_AGR`,
  `PROC_T3_LANZA_REP`.
- Funciones: `FN_ADDENDA_PARAM`, `FN_VALIDA_RFC`.
- Secuencias: `SEQ_CFD`, `SEQ_PAGO_CENTRAL_AGR`.
- Tabla o vista: `FACTURA_GENERAL`.

`DELIVERY_CLEAR_Migrado` no sustituye automáticamente a `DELIVERY_CLEAR`; SQL
Server considera que son nombres distintos.

`PROC_T3_EOD` y `PROC_T3_BOD` no deben conservar esta referencia Oracle:

```text
T3.PKG_T3.PROC_T3_LANZA_REP
```

La llamada válida es:

```sql
EXEC [T3].[PROC_T3_LANZA_REP] ...;
```

## 18. Consultas de seguridad y diagnóstico

### 18.1 Propietario técnico y rol de Agent

```sql
USE [msdb];

SELECT
    DP.[name] AS UserName,
    R.[name] AS RoleName
FROM sys.database_role_members AS DRM
INNER JOIN sys.database_principals AS R
    ON R.principal_id = DRM.role_principal_id
INNER JOIN sys.database_principals AS DP
    ON DP.principal_id = DRM.member_principal_id
WHERE DP.[name] = N'T3_SQLAGENT_OWNER';
```

Debe incluir `SQLAgentUserRole` y `T3JobExecutors`.

### 18.2 Contexto del wrapper

```sql
USE [msdb];

SELECT
    P.[name] AS ProcedureName,
    USER_NAME(M.execute_as_principal_id) AS ExecuteAsUser
FROM sys.procedures AS P
INNER JOIN sys.sql_modules AS M
    ON M.object_id = P.object_id
WHERE P.object_id = OBJECT_ID(N'dbo.T3_JOB_NEXT_RUN', N'P');
```

Resultado esperado:

```text
ProcedureName = T3_JOB_NEXT_RUN
ExecuteAsUser = T3_SQLAGENT_OWNER
```

### 18.3 Miembros humanos en `msdb`

```sql
USE [msdb];

SELECT M.[name]
FROM sys.database_role_members AS DRM
INNER JOIN sys.database_principals AS R
    ON R.principal_id = DRM.role_principal_id
INNER JOIN sys.database_principals AS M
    ON M.principal_id = DRM.member_principal_id
WHERE R.[name] = N'T3JobExecutors'
ORDER BY M.[name];
```

### 18.4 Miembros humanos en `T3QA`

```sql
USE [T3QA];

SELECT M.[name]
FROM sys.database_role_members AS DRM
INNER JOIN sys.database_principals AS R
    ON R.principal_id = DRM.role_principal_id
INNER JOIN sys.database_principals AS M
    ON M.principal_id = DRM.member_principal_id
WHERE R.[name] = N'T3BODExecutors'
ORDER BY M.[name];
```

## 19. Errores frecuentes

| Error/estado | Causa probable | Solución |
|---|---|---|
| `Only owner of a job schedule...` | Schedule pertenece a una cuenta personal. | Ejecutar `C` como `sysadmin`. |
| `51405` en `D` | Uno o más logins o grupos de `@TeamLogins` no existen con ese nombre exacto. | Revisar `Missing_Server_Login`; para AD usar `DOMINIO\Grupo`, crear/corregir el login y repetir `D`. |
| `51408` o `51409` en `D` | Existe un usuario homónimo con otro `SID`. | DBA debe corregir el mapeo; no eliminarlo sin investigar. |
| `51420` al usar el helper | El caller no es `sysadmin`. | Solicitar al DBA autorizado que ejecute `T3_ADD_JOB_EXECUTORS`. |
| `51421` o `51427` | La lista CSV está vacía o sólo contiene espacios/comas. | Enviar al menos un nombre de login. |
| `51423` o `51424` | No existe uno de los roles controlados. | Ejecutar primero el script D y después repetir el helper. |
| `51430` | Un login no existe, está deshabilitado o su tipo no está permitido. | Revisar el result set de validación, corregir todos los nombres y repetir. |
| `51431` o `51432` | Existe un usuario homónimo asociado a otro SID. | El DBA debe corregir el mapeo antes de continuar. |
| `51433` o `51434` | Los roles existen pero perdieron el `GRANT EXECUTE` base. | Ejecutar nuevamente D y después repetir el alta. |
| `51504` en `E` | Faltan procedimientos del catálogo en `T3QA`. | Desplegar las filas mostradas como `Missing_Procedure` y repetir `E`. |
| `WRONG_JOB_OWNER` | Job no pertenece al login técnico. | Ejecutar `C`. |
| `WRONG_SCHEDULE_OWNER` | Schedule no pertenece al login técnico. | Ejecutar `C`. |
| `WRAPPER_MISSING` | No se ejecutó `B`. | Ejecutar `B` como DBA. |
| `WRONG_EXECUTE_AS` | Wrapper no ejecuta como login técnico. | Volver a ejecutar `B`. |
| `EXECUTE_GRANT_MISSING` | Rol de `msdb` no tiene permiso sobre wrapper. | Ejecutar `D`. |
| `TEAM_ROLE_MEMBER_MISSING` | No hay usuario humano en el rol de `msdb`. | Revisar `@TeamLogins` y ejecutar `D`. |
| `T3QA_TEAM_MEMBER_MISSING` | Usuario está autorizado en `msdb`, pero no en `T3QA`. | Ejecutar `D`. |
| `EXECUTE_PERMISSION_MISSING` | Propietario técnico no puede ejecutar un entry point. | Ejecutar `E`. |
| `DEPENDENCY_MISSING` | Falta un objeto interno. | Desplegar el objeto indicado. |
| `INVALID_PACKAGE_REFERENCE` | Queda sintaxis Oracle en BOD/EOD. | Corregir la llamada a `PROC_T3_LANZA_REP`. |
| `WRONG_SCHEDULE_CONFIG` | Frecuencia/hora no coincide con catálogo. | Ejecutar `01`, luego `C` y `02`. |
| Error de base actual | Script ejecutado desde otra base. | Seleccionar la base indicada en la tabla de despliegue. |
| `51611` en rollback | Existe un job del alcance en ejecución. | Esperar a que termine o solicitar al DBA que lo detenga; repetir el preflight. |
| `51641`, `51651` o `51661` | La confirmación destructiva continúa en `0`. | Revisar el alcance y cambiar a `1` solamente durante la ventana autorizada. |
| `51671` | La verificación final encontró componentes restantes. | Revisar el listado anterior al error y repetir desde el paso incompleto. |

## 20. Consideraciones adicionales

### 20.1 Manejo de errores en `PROC_T3_BOD`

La versión actual registra errores en `MX_EAI_MESSAGE_LOG`. También debe volver
a lanzar el error con `THROW;` después del registro. Si sólo registra y no lanza,
el llamador puede interpretar una ejecución fallida como exitosa.

### 20.2 `GET_T3_ENABLE_EXECUTE`

Debe comprobarse si `[EAI_OWNER].[GET_T3_ENABLE_EXECUTE]` busca nombres antiguos
de package dentro de `sysjobs` o `sysjobsteps`. No se deben cambiar los nombres
nuevos sólo para satisfacer una búsqueda histórica; la función debe adaptarse al
catálogo/mapeo.

### 20.3 `WA_CIERRE_FLUJOS`

`WA_CIERRE_FLUJOS` llama `JOB_MANAGE('Suspend','Todos')`. La selección histórica
usa patrones que pueden no existir en los comandos migrados. Debe probarse antes
de liberar ese flujo.

## 21. Lista final antes de liberar

- [ ] La instancia y base `T3QA` son correctas.
- [ ] SQL Server Agent está iniciado.
- [ ] `T3_SQLAGENT_OWNER` existe y no es `sysadmin`.
- [ ] El login técnico pertenece a `msdb.SQLAgentUserRole`.
- [ ] Todos los logins o grupos configurados en `@TeamLogins` existen y están habilitados.
- [ ] `01` creó 37 jobs deshabilitados.
- [ ] `B` creó `msdb.dbo.T3_JOB_NEXT_RUN` con el contexto correcto.
- [ ] `C` dejó 37 jobs y schedules a nombre del login técnico.
- [ ] `EAI_OWNER.JOB_NEXT_RUN` llama al wrapper y no a las APIs directamente.
- [ ] `D` agregó al equipo en `msdb.T3JobExecutors` y `T3QA.T3BODExecutors`.
- [ ] `D1` instaló `msdb.dbo.T3_ADD_JOB_EXECUTORS` para altas posteriores.
- [ ] `E` se ejecutó después de desplegar `JOB_NEXT_RUN` y terminó sin error `51504`.
- [ ] `02` devolvió `PASS` y `Ready_Jobs=37`.
- [ ] Las dependencias de segundo nivel existen.
- [ ] BOD/EOD no contienen referencias Oracle inválidas.
- [ ] Un usuario o integrante del grupo autorizado ejecutó satisfactoriamente `PROC_T3_BOD`.
- [ ] Se verificó que Suspend afecte cinco jobs y que Resume EOD reactive los tres esperados.
- [ ] Se revisaron historia, duración, concurrencia y bloqueos.
- [ ] Los jobs `216`, `229`, `236`, `550` y `648` permanecen deshabilitados antes de pruebas de Resume.
- [ ] La activación fue autorizada.
- [ ] `@ConfirmEnable` volvió a `0` después de usar `03`.
- [ ] `@ConfirmDisable` volvió a `0` después de usar `04`.
- [ ] La ruta y el orden del rollback completo quedaron anexados al ticket de cambio.

## 22. Regla de oro

Si `02_VALIDATE_JOBS.SQL` no devuelve `PASS`, no habilitar jobs. Primero corregir
el estado indicado, volver a ejecutar la validación y documentar el resultado.

# Jobs T3: migración, seguridad, despliegue y operación

## 1. Objetivo de esta guía

Esta carpeta contiene la migración de 37 procesos programados de Oracle
`DBMS_JOB` a SQL Server Agent. Esta guía explica, desde cero:

- Qué es un job y cómo se relaciona con un schedule y un procedimiento.
- Por qué los jobs no deben pertenecer a una cuenta personal.
- Qué hace el login técnico `T3_SQLAGENT_OWNER`.
- Qué permisos reciben los desarrolladores y cuáles no deben recibir.
- Para qué sirven los scripts `A` a `E` y `00` a `04`.
- En qué orden deben ejecutarse.
- Cómo validar el despliegue y resolver los errores más comunes.
- Cómo habilitar, deshabilitar o eliminar los jobs de forma segura.

La guía está escrita para un desarrollador JR. No presupone experiencia previa
administrando SQL Server Agent.

### Mapa rápido de lectura

- Si es la primera vez que trabajas con jobs, lee las secciones 2 a 5.
- Si vas a desplegar, sigue las secciones 7 a 12 sin cambiar el orden.
- Si recibiste un error, ve a la sección 19.
- Si necesitas detener o eliminar jobs, revisa las secciones 13 y 14.
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

El flujo relevante para BOD es:

```text
Usuario del equipo
    |
    v
T3.PROC_T3_BOD
    |
    v
EAI_OWNER.SF_JOB_MANAGE
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

El usuario humano no recibe permiso directo sobre `sp_update_job` ni sobre
`sp_update_schedule`. Sólo puede ejecutar el wrapper controlado.

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
| `T3QA` | `T3SqlAgentJobExecutor` | `T3_SQLAGENT_OWNER` | Permite ejecutar los entry points de los 37 jobs. |
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

Si se agrega otra persona, se añade una fila en `@TeamLogins` y se vuelve a
ejecutar `D`. El script es idempotente: no duplica membresías existentes.

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
| `00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL` | Elimina jobs, schedules y filas de control de la migración. | Sí, destructivo |
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
| `E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL` | `T3QA` | Concede al login técnico permisos mínimos sobre los entry points. |

### 6.3 Archivos de soporte

| Archivo | Función |
|---|---|
| `USER_JOBS_SOURCE.csv` | Inventario original exportado desde Oracle. |
| `MSSQL/T3/EAI_OWNER/Procedures/JOB_NEXT_RUN.SQL` | Procedimiento funcional que llama al wrapper de `msdb`. |

## 7. Prerrequisitos

Antes de ejecutar cualquier despliegue, confirmar:

1. La instancia es la correcta.
2. Existe la base `T3QA`.
3. SQL Server Agent está instalado e iniciado.
4. La ejecución no se hace en LocalDB; LocalDB no proporciona SQL Server Agent.
5. El DBA dispone de una cuenta `sysadmin` para los scripts de seguridad.
6. Los cuatro logins humanos existen en `master.sys.server_principals`.
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

El resultado debe contener cuatro filas y `is_disabled` debe ser `0`.

## 8. Orden completo de despliegue

El orden obligatorio para un ambiente nuevo es:

```text
A
-> 01
-> B
-> C
-> D
-> E
-> desplegar EAI_OWNER.JOB_NEXT_RUN
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
| 6 | `E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL` | DBA `sysadmin` o `db_owner` | El script selecciona `T3QA`. |
| 7 | `MSSQL/T3/EAI_OWNER/Procedures/JOB_NEXT_RUN.SQL` | DBA/deployer | Seleccionar `T3QA`. |
| 8 | `02_VALIDATE_JOBS.SQL` | `T3_SQLAGENT_OWNER` | Seleccionar `T3QA`. |
| 9 | Pruebas funcionales | Equipo autorizado | Seleccionar `T3QA`. |
| 10 | `03_ENABLE_VALIDATED_JOBS.SQL` | `T3_SQLAGENT_OWNER` | Seleccionar `T3QA`. |

Para un ambiente donde `A` y `01` ya se ejecutaron, aplicar:

```text
B -> C -> D -> E -> JOB_NEXT_RUN.SQL -> 02 -> pruebas
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

### Paso E: autorizar al propietario técnico

Archivo:

```text
E_SECURITY_GRANT_T3_SQLAGENT_OWNER_EXECUTE.SQL
```

Crea el rol:

```text
T3QA.T3SqlAgentJobExecutor
```

Agrega únicamente a `T3_SQLAGENT_OWNER` y concede:

- `EXECUTE` sobre los 37 procedimientos principales del catálogo.
- `SELECT` y `UPDATE` sobre `Job_Oracle_SQLAgent_Map`.
- `SELECT` sobre `Job_Oracle_Migration_Catalog`.
- `VIEW DEFINITION` sobre `JOB_NEXT_RUN`, `PROC_T3_BOD` y `PROC_T3_EOD`.

No agregar usuarios humanos a este rol.

El script exige que los 37 procedimientos existan. Si falta alguno, devuelve
`51504`, muestra `Missing_Procedure` y no concede permisos parciales.

Los cinco entry points de `SF_JOB_MANAGE` están en:

```text
MSSQL/T3/EAI_OWNER/Package/RECV_REPLENISHMENT.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_INVOICE_INTERCOMPANY.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_PAYMENT.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_INVOICE.SQL
MSSQL/T3/EAI_OWNER/Package/RECV_CUSTOMER.SQL
```

### Desplegar `EAI_OWNER.JOB_NEXT_RUN`

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
3. Comprobar que los cinco jobs cambien de estado durante Suspend/Resume.
4. Confirmar que `Last_Update_User` registre al usuario llamador.
5. Ejecutar cada `Step_Command` con parámetros controlados.
6. Comparar resultados con Oracle.
7. Revisar duración, bloqueos y concurrencia.
8. Revisar SQL Server Agent Job History.

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

`00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL` elimina:

- Los 37 jobs administrados.
- Sus steps, historial y asociaciones.
- Schedules exclusivos sin asociaciones.
- Filas de las tablas de control.
- Opcionalmente, tablas de control vacías.

Es destructivo y debe ejecutarse únicamente con autorización del DBA.

Para conservar las tablas vacías:

```sql
DECLARE @DropEmptySupportTables BIT = 0;
```

El instalador no conserva una copia de una definición preexistente con el mismo
nombre. El rollback puede eliminarla, pero no reconstruirla.

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
| `51405` en `D` | Uno o más logins de `@TeamLogins` no existen. | Revisar el result set `Missing_Server_Login`; crear/corregir el login. |
| `51408` o `51409` en `D` | Existe un usuario homónimo con otro `SID`. | DBA debe corregir el mapeo; no eliminarlo sin investigar. |
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
- [ ] Los cuatro logins humanos existen y están habilitados.
- [ ] `01` creó 37 jobs deshabilitados.
- [ ] `B` creó `msdb.dbo.T3_JOB_NEXT_RUN` con el contexto correcto.
- [ ] `C` dejó 37 jobs y schedules a nombre del login técnico.
- [ ] `D` agregó al equipo en `msdb` y `T3QA`.
- [ ] `E` concedió permisos al propietario técnico sin error `51504`.
- [ ] `EAI_OWNER.JOB_NEXT_RUN` llama al wrapper y no a las APIs directamente.
- [ ] `02` devolvió `PASS` y `Ready_Jobs=37`.
- [ ] Las dependencias de segundo nivel existen.
- [ ] BOD/EOD no contienen referencias Oracle inválidas.
- [ ] Un usuario humano ejecutó satisfactoriamente `PROC_T3_BOD`.
- [ ] Se revisaron historia, duración, concurrencia y bloqueos.
- [ ] Los jobs `216`, `229`, `236`, `550` y `648` permanecen deshabilitados antes de pruebas de Resume.
- [ ] La activación fue autorizada.
- [ ] `@ConfirmEnable` volvió a `0` después de usar `03`.
- [ ] `@ConfirmDisable` volvió a `0` después de usar `04`.

## 22. Regla de oro

Si `02_VALIDATE_JOBS.SQL` no devuelve `PASS`, no habilitar jobs. Primero corregir
el estado indicado, volver a ejecutar la validación y documentar el resultado.

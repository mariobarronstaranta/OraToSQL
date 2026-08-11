# Migración de Oracle `USER_JOBS` a SQL Server Agent

Esta carpeta contiene la migración de los 37 registros de Oracle `DBMS_JOB`
incluidos en [`USER_JOBS_SOURCE.csv`](./USER_JOBS_SOURCE.csv) hacia SQL Server
Agent.

La configuración de este ambiente es fija:

- Base de datos destino: `T3QA`.
- Propietario esperado de los jobs: login SQL `AT85233588`.
- Total de jobs: 37.
- Jobs activos en Oracle (`BROKEN=N`): 32.
- Jobs suspendidos en Oracle (`BROKEN=Y`): 5.

> **Importante:** ningún script de esta carpeta debe ejecutarse desde `master`,
> `msdb` u otra base. Todos validan o esperan estar conectados a `T3QA`.

## Archivos incluidos

| Archivo | Función | ¿Modifica datos? |
|---|---|---:|
| `USER_JOBS_SOURCE.csv` | Inventario original exportado desde Oracle. | No |
| `00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL` | Elimina los objetos creados o administrados por el instalador. | Sí, destructivo |
| `01_CREATE_OR_UPDATE_JOBS.SQL` | Crea o actualiza los 37 jobs, schedules y tablas de control. Todos quedan deshabilitados. | Sí |
| `02_VALIDATE_JOBS.SQL` | Valida configuración, dependencias y permisos antes de habilitar. | No |
| `03_ENABLE_VALIDATED_JOBS.SQL` | Habilita los 32 jobs que estaban activos en Oracle. | Sí |
| `04_DISABLE_MIGRATED_JOBS.SQL` | Deshabilita los jobs sin eliminarlos ni borrar historial. | Sí |

## Prerrequisitos de seguridad

### Login propietario

Los jobs pertenecen al login SQL local:

```text
AT85233588
```

No es una cuenta de dominio y no se utiliza `sa` como propietario.

Cuando `01_CREATE_OR_UPDATE_JOBS.SQL` es ejecutado por `AT85233588`, el script
omite deliberadamente `@owner_login_name`. SQL Server asigna automáticamente el
job al login actual. Esto es necesario porque un usuario que no pertenece a
`sysadmin` no puede establecer explícitamente el propietario de un job.

Un DBA miembro de `sysadmin` también puede ejecutar el instalador; en ese caso,
el script asigna explícitamente `AT85233588` como propietario.

### Permisos de SQL Server Agent

`AT85233588` no pertenece a `sysadmin`. Debe existir como usuario en `msdb` y
pertenecer, como mínimo, a uno de estos roles:

- `SQLAgentUserRole`
- `SQLAgentReaderRole`
- `SQLAgentOperatorRole`

Para administrar únicamente sus propios jobs, `SQLAgentUserRole` es el permiso
mínimo habitual. La asignación debe realizarla un DBA de acuerdo con la política
del ambiente.

Comprobación para el developer:

```sql
SELECT
    SUSER_SNAME() AS Login_Actual,
    IS_SRVROLEMEMBER(N'sysadmin') AS Es_Sysadmin;

USE [msdb];
SELECT
    IS_ROLEMEMBER(N'SQLAgentUserRole') AS Es_SQLAgentUserRole,
    IS_ROLEMEMBER(N'SQLAgentReaderRole') AS Es_SQLAgentReaderRole,
    IS_ROLEMEMBER(N'SQLAgentOperatorRole') AS Es_SQLAgentOperatorRole;

USE [T3QA];
```

### Permisos en `T3QA`

El login necesita permisos suficientes para:

- Crear las tablas de control bajo el esquema `EAI_OWNER`, si no existen.
- Consultar, insertar y actualizar las tablas de control.
- Ejecutar los procedimientos utilizados por los jobs.
- Consultar la definición de `PROC_T3_EOD` y `PROC_T3_BOD` mediante
  `VIEW DEFINITION` para detectar referencias Oracle incompatibles.

Los permisos deben ser otorgados por un DBA. No se recomienda elevar
permanentemente `AT85233588` a `sysadmin`.

## Secuencia normal de despliegue

### 1. Confirmar el contexto

Abra una conexión con el login `AT85233588`, seleccione `T3QA` y ejecute:

```sql
SELECT DB_NAME() AS Base_Actual, SUSER_SNAME() AS Login_Actual;
```

El resultado esperado es:

| Base_Actual | Login_Actual |
|---|---|
| `T3QA` | `AT85233588` |

Confirme también que el servicio SQL Server Agent esté iniciado.

### 2. Limpiar un intento anterior fallido, si aplica

Si `01_CREATE_OR_UPDATE_JOBS.SQL` ya falló y se necesita regresar a un estado
limpio, revise y ejecute `00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL` antes de repetir
el despliegue.

No ejecute el rollback como parte del flujo normal cuando no existe un intento
fallido.

### 3. Crear los jobs deshabilitados

Ejecute:

```text
01_CREATE_OR_UPDATE_JOBS.SQL
```

El script:

- Exige estar conectado a `T3QA`.
- Valida que exista el login `AT85233588`.
- Valida acceso a SQL Server Agent antes de crear objetos.
- Crea las tablas de control si no existen.
- Crea o actualiza los 37 jobs.
- Crea un schedule exclusivo por job.
- Configura cada paso T-SQL para ejecutarse en `T3QA`.
- Deja los 37 jobs deshabilitados para evitar ejecuciones accidentales.

Las tablas de control son:

- `[EAI_OWNER].[Job_Oracle_SQLAgent_Map]`: relaciona el número histórico Oracle
  con los IDs de SQL Server Agent.
- `[EAI_OWNER].[Job_Oracle_Migration_Catalog]`: conserva procedimiento, comando,
  estado Oracle y calendario convertido para auditoría.

Si existen versiones históricas bajo `dbo`, se copian únicamente las filas que
todavía no existen en `EAI_OWNER`; las tablas antiguas no se eliminan.

### 4. Validar el despliegue

Ejecute `02_VALIDATE_JOBS.SQL` como `AT85233588`.

El archivo es de solo lectura y devuelve cuatro resultados de diagnóstico más
un resultado final `PASS` o `FAIL`:

1. Estado detallado de los 37 jobs.
2. Resumen de jobs, procedimientos, pasos y schedules válidos.
3. Dependencias internas o de segundo nivel.
4. Revisión de referencias Oracle inválidas dentro de `PROC_T3_EOD` y
   `PROC_T3_BOD`.

En el primer resultado, `Deployment_Status` debe ser `OK` para los 37 registros.
Las columnas intermedias permiten localizar el problema:

| Columna | Qué comprueba |
|---|---|
| `Catalog_Status` | Que exista la fila esperada en el catálogo. |
| `Dependency_Status` | Que exista el procedimiento principal. |
| `Execute_Permission_Status` | Que `AT85233588` pueda ejecutarlo. |
| `Map_Status` | Que IDs y nombres del mapeo sean correctos. |
| `Job_Status` | Existencia, propietario, estado y servidor asociado. |
| `Step_Status` | Subsistema T-SQL, comando, base y acciones del paso. |
| `Schedule_Status` | Existencia, asociación, frecuencia y horario. |

El resultado final debe ser:

```text
Validation_Result = PASS
```

Si existe cualquier problema, el script muestra `FAIL` y genera el error
`51019`. Este error es intencional: no debe ejecutarse
`03_ENABLE_VALIDATED_JOBS.SQL` hasta corregir todos los estados distintos de
`OK`.

> `02_VALIDATE_JOBS.SQL` es una validación previa a la activación y espera que
> todos los jobs estén deshabilitados. Después de ejecutar correctamente `03`,
> los 32 jobs activos aparecerán como `JOB_NOT_DISABLED`; eso no significa que
> la activación haya fallado.

### 5. Ejecutar pruebas funcionales

Antes de habilitar automáticamente los jobs:

1. Ejecute manualmente cada `Step_Command` con el login `AT85233588`.
2. Confirme que los parámetros generan el mismo resultado que en Oracle.
3. Revise tiempos de ejecución y bloqueos.
4. Confirme que ningún job permanece ejecutándose más tiempo que su intervalo.
5. Verifique que las dependencias internas del resultado 3 existan.

### 6. Habilitar los jobs validados

En `03_ENABLE_VALIDATED_JOBS.SQL`, cambie únicamente:

```sql
DECLARE @ConfirmEnable BIT = 1;
```

Después ejecute el archivo completo como `AT85233588` desde `T3QA`.

El script vuelve a comprobar la configuración crítica. Esto protege contra
cambios realizados después de ejecutar `02`. La operación es transaccional:
si un job no puede habilitarse, se revierten las habilitaciones efectuadas por
ese lote.

Resultado esperado:

- 32 jobs habilitados, o reportados como previamente habilitados.
- 5 jobs `BROKEN` conservados deshabilitados.
- Estado final `ACTIVACION COMPLETADA`.

Los jobs `BROKEN` son: `216`, `229`, `236`, `550` y `648`.

Al terminar, restaure la confirmación a cero en la copia de trabajo para evitar
una activación accidental posterior:

```sql
DECLARE @ConfirmEnable BIT = 0;
```

## Deshabilitación operativa

`04_DISABLE_MIGRATED_JOBS.SQL` se utiliza durante una contingencia o ventana de
mantenimiento. Conserva jobs, schedules, catálogo e historial.

Antes de ejecutarlo, cambie:

```sql
DECLARE @ConfirmDisable BIT = 1;
```

Puede ejecutarlo `AT85233588` o un miembro de `sysadmin`. El script:

- Busca directamente los 37 nombres esperados en `msdb`.
- No depende de que las tablas de mapeo estén completas.
- Se detiene sin modificar nada si encuentra un job propiedad de otro login.
- Deshabilita todos los jobs encontrados dentro de una transacción.
- Considera válido que falten jobs cuando el despliegue original fue parcial.
- Muestra un resumen y el estado individual de los 37 nombres.

> Deshabilitar un job impide sus próximas ejecuciones, pero no detiene una
> ejecución que ya comenzó. Si es necesario detener una ejecución en curso, el
> DBA debe revisar primero su impacto transaccional y usar el procedimiento
> operativo autorizado para detenerla.

Al terminar, restaure:

```sql
DECLARE @ConfirmDisable BIT = 0;
```

## Rollback completo

`00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL` elimina los objetos administrados por el
instalador:

- Los 37 jobs identificados por nombre exacto.
- Pasos, historial y asociaciones eliminados por `sp_delete_job`.
- Schedules exclusivos que queden sin asociación.
- Las 37 filas correspondientes en las tablas de control.
- Las tablas de control, únicamente si quedan vacías y
  `@DropEmptySupportTables=1`.

Para conservar las tablas vacías, cambie:

```sql
DECLARE @DropEmptySupportTables BIT = 0;
```

El rollback es idempotente: puede ejecutarse nuevamente si el intento anterior
quedó incompleto. Debe ejecutarse conectado a `T3QA`.

### Limitación del rollback

`01_CREATE_OR_UPDATE_JOBS.SQL` actualiza cualquier job o schedule preexistente
que tenga uno de los nombres administrados. El instalador no conserva una copia
de su definición anterior. El rollback puede eliminar ese objeto, pero no puede
reconstruir automáticamente su configuración previa.

Si un intento anterior alcanzó a crear jobs propiedad de `sa`, `AT85233588` no
podrá eliminarlos. En ese caso, el rollback debe ejecutarlo un DBA miembro de
`sysadmin`.

## Nomenclatura

Cada objeto sigue una convención determinística:

```text
Job:      ORA_<numero>_<schema>_<procedimiento>
Schedule: SCH_ORA_<numero>
```

Ejemplo:

```text
ORA_42_EAI_OWNER_WA_ERR_INTERCOMPANY
SCH_ORA_42
```

Los schedules no se comparten. Los procedimientos migrados `JOB_INTERVAL`,
`JOB_NEXT_RUN`, `JOB_NEXT_DATE` y `JOB_MANAGE` necesitan identificar cada job
mediante su número Oracle y la tabla de mapeo.

## Conversión de llamadas de package

SQL Server no tiene el concepto Oracle `PACKAGE`. Las cinco llamadas
`EAI_OWNER.RECV_TO_SEND_V3.*` se convirtieron a procedimientos públicos bajo
`EAI_OWNER`:

| Oracle | SQL Server |
|---|---|
| `RECV_TO_SEND_V3.Recv_Replenishment` | `[EAI_OWNER].[RECV_REPLENISHMENT]` |
| `RECV_TO_SEND_V3.Recv_Invoice_Intercompany` | `[EAI_OWNER].[RECV_INVOICE_INTERCOMPANY]` |
| `RECV_TO_SEND_V3.Recv_Payment` | `[EAI_OWNER].[RECV_PAYMENT]` |
| `RECV_TO_SEND_V3.Recv_Invoice` | `[EAI_OWNER].[RECV_INVOICE]` |
| `RECV_TO_SEND_V3.Recv_Customer` | `[EAI_OWNER].[RECV_CUSTOMER]` |

Estas equivalencias deben confirmarse funcionalmente antes de habilitar los
jobs.

## Conversión de calendarios

| Expresión Oracle | Conversión SQL Server Agent |
|---|---|
| `SYSDATE + N/1440` | Cada `N` minutos. |
| `SYSDATE + N/24` | Cada `N` horas. |
| `TRUNC(SYSDATE + 1) + N/1440` | Ejecución diaria en el minuto `N` del día. |
| `TRUNC(SYSDATE + 1) + N/24` | Ejecución diaria a la hora `N`. |

Oracle vuelve a evaluar la expresión `INTERVAL`; SQL Server Agent usa una
cuadrícula fija de calendario. Si un job dura más que su intervalo o comienza
tarde, la siguiente ejecución puede diferir del comportamiento de `DBMS_JOB`.
Esta diferencia debe compararse con el historial Oracle para los procesos
críticos.

El CSV contiene `NEXT_DATE` sin hora, por lo que no permite recuperar la próxima
ejecución original con precisión. El instalador comienza los schedules desde la
fecha en que se ejecuta y utiliza la hora derivada de `INTERVAL`.

## Dependencias conocidas de segundo nivel

Los procedimientos principales pueden existir y aun así fallar por objetos
llamados internamente. `02` los reporta y `03` bloquea la activación mientras
falte cualquiera:

- Procedimientos: `DELIVERY_CLEAR`, `PROC_V40_GENERAR_MX06_CM`,
  `PROC_CFDI_GENERAR_PAGO`, `PROC_CFDI_GENERAR_PAGO_AGR` y
  `PROC_T3_LANZA_REP`.
- Funciones: `FN_ADDENDA_PARAM` y `FN_VALIDA_RFC`.
- Secuencias: `SEQ_CFD` y `SEQ_PAGO_CENTRAL_AGR`.
- Tabla o vista: `FACTURA_GENERAL`.

Existe un archivo para `[T3].[DELIVERY_CLEAR_Migrado]`, pero
`PROC_CFDI_LIBERACION_REMISION` requiere el nombre exacto
`[T3].[DELIVERY_CLEAR]`. Los nombres no son equivalentes.

Los archivos migrados de `PROC_T3_EOD` y `PROC_T3_BOD` todavía contienen una
referencia con formato Oracle:

```text
T3.PKG_T3.PROC_T3_LANZA_REP
```

En SQL Server debe reemplazarse por una llamada válida al procedimiento público:

```sql
EXEC [T3].[PROC_T3_LANZA_REP] ...;
```

Mientras la referencia inválida exista, `02` devolverá
`INVALID_PACKAGE_REFERENCE` y `03` impedirá la activación.

## Compatibilidad con procedimientos de administración

Los cinco steps procedentes de `RECV_TO_SEND_V3` usan los nombres públicos y los
nombres de los jobs tampoco incluyen `RECV_TO_SEND_V3`.

`[EAI_OWNER].[GET_T3_ENABLE_EXECUTE]` todavía puede buscar ese texto en
`msdb.dbo.sysjobs.name` o `sysjobsteps.command`. Debe comprobarse si la función
necesita consultar las tablas de mapeo. No debe reintroducirse el prefijo de
package en los procedimientos T-SQL.

`WA_CIERRE_FLUJOS` llama `JOB_MANAGE('Suspend','Todos')`. La selección histórica
de `Todos` usa patrones como `GEN_REPLICATION`, `GEN_OUTBOUND_XML` y
`SEND_STAGE_T3`, que no aparecen en los nuevos comandos. Este flujo debe probarse
o ajustarse para utilizar la tabla de mapeo antes de liberarlo.

## Diagnóstico rápido

| Situación | Acción recomendada |
|---|---|
| Error de base de datos | Seleccionar `T3QA` y ejecutar nuevamente el archivo completo. |
| Falta un rol de SQL Server Agent | Solicitar al DBA acceso en `msdb`. |
| `WRONG_JOB_OWNER` | Solicitar al DBA revisar o reasignar el propietario. |
| `EXECUTE_PERMISSION_MISSING` | Solicitar permiso `EXECUTE` sobre el procedimiento o esquema correspondiente. |
| `DEPENDENCY_MISSING` | Desplegar o corregir el nombre del objeto indicado. |
| `WRONG_SCHEDULE_CONFIG` | Volver a ejecutar `01` y después `02`. |
| `INVALID_PACKAGE_REFERENCE` | Corregir el procedimiento migrado; no habilitar el job. |
| Falló `01` y quedaron objetos parciales | Ejecutar `00`, revisar el resultado y repetir desde `01`. |
| Se requiere detener futuras ejecuciones | Ejecutar `04` con confirmación explícita. |
| Se requiere eliminar toda la migración | Ejecutar `00` con autorización del DBA. |

## Lista de comprobación antes de liberar

- [ ] La conexión apunta a `T3QA`.
- [ ] El login actual es `AT85233588`.
- [ ] SQL Server Agent está iniciado.
- [ ] `01` terminó sin errores y dejó 37 jobs deshabilitados.
- [ ] `02` devolvió `PASS` y 37 filas con `Deployment_Status=OK`.
- [ ] Las diez dependencias de segundo nivel existen con el nombre exacto.
- [ ] `PROC_T3_EOD` y `PROC_T3_BOD` no contienen referencias Oracle inválidas.
- [ ] Los 37 comandos fueron probados manualmente con parámetros controlados.
- [ ] Se revisaron duración, concurrencia y bloqueos de los jobs críticos.
- [ ] Los jobs `216`, `229`, `236`, `550` y `648` permanecen deshabilitados.
- [ ] Reintentos, Database Mail y operadores fueron definidos según la política
      operativa; el CSV Oracle no contiene esa información.
- [ ] La activación fue autorizada y `@ConfirmEnable` se cambió temporalmente a 1.

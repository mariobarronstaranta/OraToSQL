# Migración de Oracle USER_JOBS a SQL Server Agent

Esta carpeta contiene la conversión de los 37 registros entregados en el archivo
`ExportJobs` el 17 de julio de 2026. El origen usa `DBMS_JOB`; el equivalente
operativo es SQL Server Agent.

## Resultado del inventario

- Total: 37 jobs.
- Activos en Oracle (`BROKEN=N`): 32.
- Deshabilitados en Oracle (`BROKEN=Y`): 5.
- Procedimientos llamados directamente por los jobs localizados en MSSQL: 37.
- Dependencias directas de jobs todavía ausentes: 0.
- Dependencias de segundo nivel todavía ausentes o con nombre incompatible: 10.

Los jobs Oracle 216, 229, 236, 550 y 648 estaban `BROKEN`. Permanecen
deshabilitados aunque sus procedimientos ya existan.

## Archivos y orden de uso

1. Ejecutar `01_CREATE_OR_UPDATE_JOBS.SQL` conectado a la base de la aplicación.
   Todos los jobs quedan deshabilitados.
2. Ejecutar `02_VALIDATE_JOBS.SQL` y resolver cada estado distinto de `OK`.
3. Ejecutar pruebas manuales de los comandos indicados en cada Job Step.
4. Durante la ventana de corte, cambiar `@ConfirmEnable=1` en
   `03_ENABLE_VALIDATED_JOBS.SQL` y ejecutarlo.
5. Ante una contingencia, usar `04_DISABLE_MIGRATED_JOBS.SQL`.

El primer script usa `DB_NAME()` como base destino del Job Step. Por eso no debe
ejecutarse desde `master` ni `msdb`. El propietario predeterminado es `sa`; el DBA
debe revisar `@JobOwner` antes del despliegue.

## Nomenclatura y compatibilidad

Cada job se crea como `ORA_<numero>_<schema>_<procedimiento>` y cada schedule
como `SCH_ORA_<numero>`. Los schedules no se comparten porque los procedimientos
migrados `JOB_INTERVAL` y `JOB_NEXT_RUN` administran jobs por su número Oracle.

`dbo.Job_Oracle_SQLAgent_Map` mantiene la correspondencia necesaria para esos
procedimientos. `dbo.Job_Oracle_Migration_Catalog` conserva el comando, estado,
dependencia y calendario de origen para auditoría y validación.

Las cinco llamadas `EAI_OWNER.RECV_TO_SEND_V3.*` se cambiaron a los nombres
públicos aprobados por el cliente, sin prefijo de package:

- `RECV_REPLENISHMENT`
- `RECV_INVOICE_INTERCOMPANY`
- `RECV_PAYMENT`
- `RECV_INVOICE`
- `RECV_CUSTOMER`

## Dependencias T3 de segundo nivel

Los 17 procedimientos T3 llamados directamente por los jobs ya están en
`MSSQL/T3/T3/Procedures` y sus parámetros coinciden con `USER_JOBS`. Al revisar
sus cuerpos se encontraron estos objetos pendientes por nombre exacto:

- Procedimientos: `DELIVERY_CLEAR`, `PROC_V40_GENERAR_MX06_CM`,
  `PROC_CFDI_GENERAR_PAGO`, `PROC_CFDI_GENERAR_PAGO_AGR` y
  `PROC_T3_LANZA_REP`.
- Funciones: `FN_ADDENDA_PARAM` y `FN_VALIDA_RFC`.
- Secuencias: `SEQ_CFD` y `SEQ_PAGO_CENTRAL_AGR`.
- Tabla o vista: `FACTURA_GENERAL`.

Existe un script que crea `[T3].[DELIVERY_CLEAR_Migrado]`, pero el procedimiento
`PROC_CFDI_LIBERACION_REMISION` llama `[T3].[DELIVERY_CLEAR]`; los nombres no son
equivalentes. Además, `PROC_T3_EOD` y `PROC_T3_BOD` conservan una llamada de tres
partes `T3.PKG_T3.PROC_T3_LANZA_REP`, que en SQL Server se interpreta como
`base.schema.procedimiento`. Debe sustituirse por el procedimiento público
`[T3].[PROC_T3_LANZA_REP]` cuando se migre el miembro del package.

`02_VALIDATE_JOBS.SQL` muestra estas dependencias en un resultado separado y
`03_ENABLE_VALIDATED_JOBS.SQL` bloquea la activación mientras falte alguna.

## Compatibilidad con GET_T3_ENABLE_EXECUTE

Los cinco steps procedentes de `RECV_TO_SEND_V3` llaman los nombres públicos
sin prefijo aprobados por el cliente. Los job names generados tampoco contienen
`RECV_TO_SEND_V3`. La función `[EAI_OWNER].[GET_T3_ENABLE_EXECUTE]` todavía
busca ese texto en `msdb.dbo.sysjobs.name` o `sysjobsteps.command`, por lo que
puede concluir que no existen jobs T3In y cambiar su decisión de ejecución.

Antes de habilitar debe acordarse si la marca se conserva solamente en el job
name o si la función se cambia para consultar las tablas de mapeo. No se debe
reintroducir el prefijo en los stored procedures.

`WA_CIERRE_FLUJOS` llama `JOB_MANAGE('Suspend','Todos')`. La selección actual de
`Todos` usa patrones históricos (`GEN_REPLICATION`, `GEN_OUTBOUND_XML` y
`SEND_STAGE_T3`) que no aparecen en los nuevos steps `EXEC [schema].[procedure]`.
Debe probarse o ajustarse para usar la tabla de mapeo antes de liberar el cierre
de flujos.

## Conversión de calendarios

- `SYSDATE + N/1440` se convirtió a ejecución cada N minutos.
- `SYSDATE + N/24` se convirtió a ejecución cada N horas.
- `TRUNC(SYSDATE + 1) + N/1440` se convirtió a ejecución diaria a la hora N.
- `TRUNC(SYSDATE + 1) + N/24` se convirtió a ejecución diaria a la hora N.

Existe una diferencia: `DBMS_JOB` calcula nuevamente una expresión Oracle y puede
presentar desplazamiento respecto de la duración real. SQL Server Agent usa una
cuadrícula fija de calendario. Esta diferencia evita deriva acumulada, pero debe
compararse con el historial Oracle en los jobs críticos.

## Pruebas recomendadas

1. Confirmar que SQL Server Agent esté iniciado.
2. Validar el propietario y permisos sobre los esquemas `EAI_OWNER`, `EAI` y `T3`.
3. Ejecutar manualmente cada `Step_Command` con los mismos parámetros.
4. Comparar siguiente ejecución y frecuencia contra Oracle.
5. Revisar que los cinco jobs `BROKEN` permanezcan deshabilitados.
6. Validar que `JOB_MANAGE`, `JOB_INTERVAL`, `JOB_NEXT_RUN` y `JOB_NEXT_DATE`
   encuentren los números Oracle en la tabla de mapeo.
7. Configurar reintentos, Database Mail y operadores según la política operativa;
   `USER_JOBS` no contiene esa información.

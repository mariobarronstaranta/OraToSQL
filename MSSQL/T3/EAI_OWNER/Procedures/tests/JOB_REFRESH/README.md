# Regresion JOB_REFRESH - 2026-10-08

El DDL de INTERNAL_JOBS define INSTANCE_JOB como FLOAT. El procedimiento
insertaba @@SERVERNAME convertido a VARCHAR, causando error 8114.
Se asigna ahora 0 numerico como compatibilidad sin afinidad Oracle y se
conserva el servidor en NLS_ENV. No representa un identificador SQL Server.

Se limitan LOG_USER/PRIV_USER a 30 e INTERVAL_JOB a 200 caracteres conforme
al DDL migrado. El intervalo completo permanece en la tabla de mapeo; la
foto INTERNAL_JOBS no debe utilizarse como fuente completa para reconstruirlo.

Run.ps1 crea una base LocalDB aleatoria y la elimina al terminar. Usa el DDL
real de INTERNAL_JOBS y de la tabla de mapeo. Redirige exclusivamente las
referencias msdb.dbo a AgentFixture para ejecutar la consulta completa contra
catalogos simulados. No crea jobs ni modifica msdb.

Cases.sql reproduce 8114, verifica INSTANCE_JOB=0, intervalo largo y fallback
al schedule, fechas, duracion de 01:02:03 = 3723 segundos, dos fallos despues
del ultimo exito y rollback posterior al TRUNCATE.

No valida permisos, SQL Agent real ni el esquema efectivamente desplegado en
produccion. El procedimiento conserva su manejo transaccional previo, incluido
el rollback completo si se invoca dentro de una transaccion externa y falla.

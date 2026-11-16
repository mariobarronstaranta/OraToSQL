# Alternativa de PROC_T3_OT_GENERAL alineada con el coordinador Oracle

Archivo: `PROC_T3_OT_GENERAL.ORACLE.sql`. Referencia leida:
`ORA/T3/T3/Procedures/PROC_T3_OT_GENERAL.SQL` (41 lineas).

El archivo usa ALTER sobre **T3.PROC_T3_OT_GENERAL**, sin crear otro nombre.
Al ejecutarlo sustituye su definicion instalada; no ejecuta el procedimiento.
La version con controles adicionales permanece en `PROC_T3_OT_GENERAL.sql`
y en el paquete `OT_GENERAL_Control_Generacion_20261029`. No instalar despues
el 01 de ese paquete si se desea conservar esta alternativa.

## Reglas conservadas

| Oracle | Alternativa MSSQL |
|---|---|
| Pendientes, Fecha_Trn mayor que SYSDATE-4 | Mismo filtro con GETDATE()-4. |
| JOIN cabecera/detalle y GROUP BY de siete columnas/expresiones | Mismo JOIN y grupos; sin deduplicar facturas ni ordenar. |
| Apartado MX10, RFC BAT030325CE9 y material existente | Mismos filtros de cuatro/treinta dias y fecha 2999-12-31. |
| WA_ERR_INVOICE_PAYMETHOD(4) antes del FOR | Misma llamada antes de OPEN. |
| sPROCESAR='SI'; sFACTURA VARCHAR2(12) | Mismas asignaciones y limite de longitud reproducido con error. |
| ABS(TOTAL-TOTAL_DETALLE)<0.10 | Misma tolerancia; se mantienen los siete decimales del origen MSSQL. |
| PROC_V40_GENERAR_OTROS(Factura) | Misma llamada, con esquema T3 explicito. |
| UPDATE por Factura despues del retorno normal | Mismo marcado de todas las cabeceras por identificador, sin validar salidas. |
| Sin EXCEPTION propio en el coordinador | TRY/CATCH solo libera el cursor y relanza el error recibido. |

No agrega reservas UPDLOCK/HOLDLOCK, conteos de errores, filtros de historicos,
validacion de documento/layout, transacciones o savepoints por factura,
log propio ni contadores de corrida. La comprobacion de longitud reproduce
un error de asignacion de Oracle; no es una validacion de negocio adicional.

La version anterior MSSQL recibia totales con dos decimales; el cursor Oracle
no los redondea asi. Esta alternativa conserva siete decimales del DDL local.
La diferencia se calcula con SUM de los valores con signo para evitar que
la resta de dos DECIMAL(38,7) reduzca la escala a seis decimales en SQL Server.

## Alcance transaccional de la alineacion

Oracle tiene COMMIT en lineas 27 y 40. El generador Oracle tambien contiene
COMMIT al terminar y ROLLBACK/registro/COMMIT en su EXCEPTION. El helper de
metodo de pago y el mapeo SAT contienen sus propios COMMIT.

Esta alternativa conserva el modo autocommit de la migracion MSSQL y no
introduce transacciones propias ni confirma trabajo del llamador. Para su
uso normal, ejecutar con IMPLICIT_TRANSACTIONS OFF y sin transaccion externa.
Los UPDATE persisten por sentencia; con una transaccion externa dependen
del COMMIT/ROLLBACK del llamador, a diferencia del Oracle que confirma dentro.

**La alineacion cubre las decisiones del coordinador, no certifica identidad
transaccional de toda la cadena.** El generador MSSQL actual no reproduce el
ROLLBACK del generador Oracle en su CATCH; por ello una salida parcial puede
persistir en autocommit. No se modificaron los hijos como parte de este cambio.

El marcado tras un error absorbido se conserva deliberadamente: Oracle
tambien vuelve al coordinador y ejecuta su UPDATE. Un error propagado detiene
la corrida; las filas anteriores ya persistidas en autocommit permanecen.

Se conserva el parche numerico de PROC_V40_GENERAR_OTROS: Oracle construye
la tasa con TO_CHAR(...,'999') y divide un NUMBER entre 100. La conversion
DECIMAL/longitud de texto en MSSQL es una adaptacion de tipos del motor,
no uno de los controles agregados al coordinador que se retiraron aqui.

## Instalacion

1. Guardar la definicion instalada si se desea conservarla para reversion.
2. Abrir `PROC_T3_OT_GENERAL.ORACLE.sql` en SSMS conectado a T3QA y ejecutar
   el archivo completo. Solo modifica el modulo T3.PROC_T3_OT_GENERAL.
3. La llamada sigue siendo `EXEC T3.PROC_T3_OT_GENERAL;`. Este archivo no
   la ejecuta ni desmarca facturas anteriores.

Pruebas locales en `tests/PROC_T3_OT_GENERAL_ORACLE/tests_local.py`: generador
simulado, sin acceso a T3QA ni ejecucion en Oracle. No validan la generacion
fiscal real; verifican las reglas y propagacion de errores del coordinador.

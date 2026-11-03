# Verificacion de instalacion de PAGOS y control 889

Evidencia: resultados del script PROC_CFDI_PROCESAR_PAGOS_VERIFICAR_INSTALACION.sql
pegados por el usuario. Captura: **23/10/2026 13:49:52.3829734 -06:00**.
Servidor **AZCRNMXNEVTD06**, base **T3QA**. Finalizacion del cliente:
2026-10-23T13:49:52.6203308-06:00. No se consulto directamente la base.

## Resultado recibido

| Objeto | Ultimo ALTER | EstadoVersion | VersionOracle | CursorCorregido | CalculoOActualizacion | Savepoint | FechaSoloDATE |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T3.PROC_CFDI_PROCESAR_PAGOS | 2026-10-23 13:43:38.253 | MARCAS ESPERADAS PRESENTES | 1 | 1 | 1 | 1 | 1 |
| T3.WA_CFDI_COBZA_ASIG_CTRL | 2026-10-23 13:46:46.050 | MARCAS ESPERADAS PRESENTES | 1 | 1 | 1 | 1 | NULL |

Las marcas corroboran la instalacion de la entrega en T3QA. La columna
FechaSoloDATE se evalua exclusivamente para el procedimiento principal;
NULL en el control es **no aplicable**, no una falla. Su ventana movil conserva
fecha y hora segun la regla del control.

| Funcion compartida | Ultimo ALTER | Estado recibido |
| --- | --- | --- |
| EAI_OWNER.GETCONV | 2026-09-23 13:23:18.753 | VISIBLE; FUERA DEL CAMBIO ENTREGADO |
| T3.FN_TOTAL_FACT | 2026-09-09 13:46:09.620 | VISIBLE; FUERA DEL CAMBIO ENTREGADO |

Las fechas de las funciones son anteriores a esta entrega y coherentes con
mantenerlas fuera del cambio. La consulta no compara sus definiciones con
un hash previo, por lo que no constituye prueba criptografica de identidad.

## Alcance y siguiente validacion

Estado: **instalacion corroborada por metadatos y marcas; validacion funcional
de la version nueva pendiente**. No se confirma produccion. Los indicadores
no equivalen a comparar el texto completo instalado ni a ejecutar el lote.
La corrida previa de 326 filas corresponde a la version anterior DATE/cursores.

Tras el siguiente procesamiento normal, ejecutar el
[validador de resultados](../PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql)
con la fecha BATMD del lote y, preferentemente, su PID 604. Revisar conciliacion,
importes/saldos/numero de pago, bases NULL y control 889/logs. No se requiere
reprocesar el 14/10 para verificar la instalacion. Los dos ALTER y esta consulta
no acreditan timbrado ni paridad completa con un motor Oracle.

Detalle de la entrega: [CAMBIOS_ORACLE](../../T3/Procedures/PROC_CFDI_PROCESAR_PAGOS.CAMBIOS_ORACLE.md).

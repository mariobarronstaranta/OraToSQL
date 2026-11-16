# PAGO: error 4922 en FECHA_TRN

Diagnostico de T3QA recibido, captura 2026-11-06 00:54:33 -06:00:
PAGO_ID varchar(50) y FECHA_TRN datetime2(0) siguen nullable; PAGO_PK sigue
indice unico NONCLUSTERED activo sin restriccion PK. Confirma rollback previo.
PAGO_IDX_1 es un indice no unico NONCLUSTERED sobre FECHA_TRN ASC, sin INCLUDE,
filtro ni compresion, en PRIMARY. Esta dependencia reproduce el error 4922.

Usar `13_CORREGIR_PK_PAGO.sql` **en lugar del lote**
`08_LOTES_PK_20261106/11_PAGO.sql`. No confundir con el lote 13_CLIENTE.sql.

1. Ejecutar completo con @Aplicar=0: debe reportar una tabla LISTA.
2. Con el plan correcto, cambiar @Aplicar=1 y ejecutar completo en ventana
   sin escritores ni cambios de esquema. Se repite la validacion de datos.
3. Esperado: CREADA y resultado final con PAGO_PK activo/is_primary_key=1,
   PAGO_ID y FECHA_TRN NOT NULL, y PAGO_IDX_1 activo/no unico sobre FECHA_TRN.

La transaccion retira PAGO_IDX_1 y PAGO_PK, convierte ambas columnas a
NOT NULL conservando sus tipos, crea PRIMARY KEY NONCLUSTERED
(PAGO_ID,FECHA_TRN) y recrea PAGO_IDX_1. Valida columnas y opciones del
indice auxiliar contra el diagnostico antes de retirarlo. Si difieren,
bloquea el cambio. REP_P y PK_PAGO_FECHA_PROC no se retiran.
Un fallo revierte ambos indices y la nullabilidad de ambas columnas.
No cambia registros. La reejecucion reconoce una PK equivalente existente.

Reconstruir PAGO_IDX_1 agrega tiempo, bloqueo y consumo de espacio/log;
sus estadisticas se regeneran, no se conserva el histograma anterior ni
su identificador interno. No extrapolar esta correccion a otras tablas.

Pruebas: tests_fix_pago_13.py aprobado en LocalDB el 2026-11-06.
Reproduce 4922 del lote original, verifica preview, rollback ante fallo en
recreacion, bloqueo por opciones distintas, PK compuesta activa, tipos y
NOT NULL, indices auxiliares y datos conservados y reejecucion.
Fixtures pequenas, no prueba de rendimiento sobre 28 millones de filas.
Base temporal CodexFixPago_463e47fb eliminada.

## Resultado real recibido

T3QA / AZCRNMXNEVTD06: captura 2026-11-06 00:58:00.890, final
01:02:37.9572807 -06:00. Aplicar=1, resultado CREADA y APLICACION TERMINADA.
PAGO_PK is_primary_key=1, is_unique=1, is_disabled=0; columnas en orden
PAGO_ID, FECHA_TRN, ambas is_nullable=0. PAGO_IDX_1 is_primary_key=0,
is_unique=0, is_disabled=0, NONCLUSTERED sobre FECHA_TRN ASC.
La columna ColumnasNullable=2 del plan conserva el valor de prevalidacion;
no describe el estado posterior. El SELECT final confirma NOT NULL.
Aplicacion confirmada por resultados proporcionados por el usuario.

# PREVENTA_GENERAL: correccion del error 4922

El diagnostico recibido de T3QA (2026-11-06 00:29:58 -06:00) confirma que
PREVG_PK sigue siendo indice unico activo sin PK y FACTURA sigue NULLABLE:
el rollback del lote 10 restauro el estado anterior.

IX_PG_C005 incluye FACTURA y bloquea el ALTER COLUMN. Se reprodujo el error
4922 en LocalDB con esta definicion. Las dependencias SQL reportadas no
estan ligadas al esquema; no hay filas de computed columns, checks, defaults
ni FK en el reporte. No se necesita eliminar procedimientos o funciones.

## Archivo a ejecutar

Usar `11_CORREGIR_PK_PREVENTA_GENERAL.sql` **en lugar de**
`08_LOTES_PK_20261106/10_PREVENTA_GENERAL.sql`.
No confundir con el lote `08_LOTES_PK_20261106/11_PAGO.sql`.

1. Ejecutar completo con `@Aplicar=0`. Debe mostrar una tabla LISTA.
   El DDL propuesto incluye retirada y recreacion de IX_PG_C005.
2. Con el plan correcto, cambiar a `@Aplicar=1` y ejecutar completo en una
   ventana sin escritores ni cambios de esquema.
3. Esperado: CREADA, PREVG_PK con is_primary_key=1/is_disabled=0,
   FACTURA con is_nullable=0 y IX_PG_C005 activo con siete columnas:
   cuatro claves y tres INCLUDE. El archivo muestra esos metadatos al final.

El script valida la definicion real de IX_PG_C005 antes de retirarlo. Si
detecta opciones, columnas o dependencias distintas, queda BLOQUEADA.
Revalida datos y metadatos. En una misma transaccion retira IX_PG_C005,
reemplaza PREVG_PK por restriccion PK y recrea IX_PG_C005:

- Claves ASC: CLASE_FACTURA, CLIENTE_SAP, FECHA_FACTURA, ENTREGA.
- INCLUDE: PEDIDO, FACTURA, CTRO.
- NONCLUSTERED no unico, sin filtro; PRIMARY, sin compresion y opciones
  reportadas en el diagnostico. No elimina otros indices ni cambia filas.

Si falla cualquier paso, revierte toda la transaccion. La recreacion fisica
de IX_PG_C005 tambien reconstruye sus estadisticas y requiere tiempo y
espacio/log; no conserva su histograma ni identificador interno anteriores.
Este tratamiento adicional solo aplica a PREVENTA_GENERAL; no modifica
automaticamente los otros lotes.

## Pruebas

`tests_fix_preventa_11.py` aprobado el 2026-11-06 en LocalDB:
reproduce 4922 del lote original, comprueba vista previa, rollback de ambos
indices y nullabilidad al fallar recreacion, bloqueo por opciones distintas,
creacion de PK activa/NOT NULL, conservacion de INCLUDE, otro indice y datos,
y reejecucion. Base temporal CodexFixPreventa_a8dfcb6f eliminada.
No se aplico la correccion en T3QA desde esta sesion.

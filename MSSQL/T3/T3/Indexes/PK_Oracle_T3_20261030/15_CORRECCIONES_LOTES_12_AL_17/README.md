> **2026-11-07: lote 17 REGISTRO_FISCAL_DETALLE SUSPENDIDO.** No ejecutar versiones anteriores, ni en vista previa. Revisar [diagnostico posterior al recovery](../17_RFD_REVISION_POST_RECOVERY_20261107/LEEME.md).

# Lotes 12-17 corregidos con sus indices dependientes

Captura real: AZCRNMXNEVTD06 / T3QA, 2026-11-06 01:11:08.9693711 -06:00.
Las seis tablas conservan indices con nombres de PK, pero sin restriccion PK;
sus 12 columnas de clave permiten NULL. Este diagnostico solo revisa metadatos.
Los instaladores vuelven a comprobar NULL/duplicados al ejecutarse.

En ASIGNACION_PAGO, IDX_T3_ASIGNACION_PAGO_FECHA_PROC_BATMD incluye las cuatro
columnas de la PK, entre ellas PAGO_ID, donde fallo el lote original.
Ademas otros cuatro indices usan columnas de esa clave. Se prepararon
correcciones para todas las tablas restantes a partir de su definicion recibida.

## Ejecutar estos archivos en lugar de los originales

| Orden | Archivo | Indices auxiliares a recrear |
|---|---|---:|
| 12 | [12_ASIGNACION_PAGO_CORREGIDO.sql](12_ASIGNACION_PAGO_CORREGIDO.sql) | 5 |
| 13 | [13_CLIENTE_CORREGIDO.sql](13_CLIENTE_CORREGIDO.sql) | 4 |
| 14 | [14_FACTURA_GENERAL_CORREGIDO.sql](14_FACTURA_GENERAL_CORREGIDO.sql) | 2 |
| 15 | [15_FACTURA_DETALLE_CORREGIDO.sql](15_FACTURA_DETALLE_CORREGIDO.sql) | 1 |
| 16 | [16_REGISTRO_FISCAL_CORREGIDO.sql](16_REGISTRO_FISCAL_CORREGIDO.sql) | 3 |
| 17 | [17_REGISTRO_FISCAL_DETALLE_CORREGIDO.sql](17_REGISTRO_FISCAL_DETALLE_CORREGIDO.sql) | 3 |

Cada archivo es autonomo y procesa una sola tabla. Empezar por el 12:

1. Ejecutar completo en T3QA con `@Aplicar=0`. Esperado: una tabla LISTA.
   Revisar el DDL propuesto, incluidos DROP y CREATE de auxiliares.
2. Si el plan esta correcto, ejecutar completo con `@Aplicar=1` durante
   una ventana sin escritores ni cambios de esquema. No ejecutar en paralelo.
3. Guardar 03_RESULTADO_APLICACION y los metadatos finales. Esperado: CREADA,
   PK activa, columnas NOT NULL y auxiliares con su definicion/estado original.
4. Continuar con el siguiente archivo cuando convenga. No repetir los lotes
   anteriores confirmados ni ejecutar el instalador global 05.

Si ya existe una PK equivalente, la reconoce sin reconstruirla. Si aparece
BLOQUEADA no aplica DDL; revisar la observacion. Si falla durante el DDL,
revierte toda la tabla (PK, indices auxiliares y nullabilidad).
Las otras tablas no forman parte de esa transaccion.

## Conservacion y limites

Valida nombres, columnas clave, INCLUDE, filtro, unicidad y estado de los
auxiliares contra `captura_indices_14.json`. Si encuentra otro indice que
usa columnas de PK, definiciones diferentes, opciones no admitidas, FK
dependientes o propiedades extendidas, bloquea sin eliminarlos.
Mantiene los controles del instalador base para tipos y columnas de la PK,
datos, firma de metadatos y transaccion exclusiva por tabla.

Los auxiliares se recrean NONCLUSTERED sobre PRIMARY, sin compresion y con
las opciones reportadas. La direccion de claves es ASC. Conserva el indice
unico CLIENTE_IDX1 y el filtro `([STATUS]<>'Cancelled')` de
IX_REGISTRO_FISCAL_MX16_LOAD. No elimina indices ajenos a las columnas de PK.

Tres auxiliares estaban deshabilitados: IX_Cliente_SAP_Vigencia,
IX_Ventas_Cliente_SAP_Vigencia y PK_FACTURA_FECHA_PROC. Se crean y vuelven
a deshabilitar dentro de la transaccion. No se dejan activos. Para sus
estructuras, cuya compresion no aparece al estar deshabilitadas, se elige
explicitamente NONE. CLIENTE_PK, en cambio, se convierte en una PK activa.

La recreacion de auxiliares agrega construccion de indices, uso de espacio/log
y bloqueo; tambien se construyen los que se vuelven a deshabilitar. Las
estadisticas y los identificadores internos se regeneran, no se conservan
histogramas previos. No se estiman minutos ni espacio requerido solo a partir
del numero de filas. Los ultimos lotes siguen siendo operaciones grandes.

No se borran, rellenan ni deduplican filas. Los tres pendientes por datos
CFDI_CATALOGOS_SAT, MOV_CLIENTE y USUARIOS quedan fuera de este paquete.

## Pruebas y trazabilidad

`../tests_correcciones_15.py`, aprobado el 2026-11-06 en LocalDB:

- Cinco DDL reales y una tabla ficticia para FACTURA_GENERAL (sin DDL local).
- Indices de la captura completa, incluido clustered de CLIENTE, filtro,
  indices unicos y auxiliares deshabilitados; datos minimos.
- Seis vistas previas, seis aplicaciones y seis reejecuciones exitosas.
- Comparacion XML completa sin truncamiento de todos los indices excepto
  la PK antes/despues: claves, INCLUDE, filtros, unicidad y estados conservados.
- Bloqueo de un indice dependiente nuevo no incluido en la captura.
- Fallo forzado al recrear el ultimo auxiliar de ASIGNACION_PAGO: rollback
  de los indices y las cuatro columnas, incluida restauracion de ASPAGO_PK.

Base temporal final CodexFix6PK_74ee137d eliminada. No es una prueba de
rendimiento y no se aplicaron estos archivos en T3QA desde esta sesion.
Generador: `../generar_correcciones_15.py`. Plan y captura JSON disponibles
en esta carpeta. Los archivos originales se conservan como historial.

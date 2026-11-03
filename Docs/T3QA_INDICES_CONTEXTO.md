# Inventario operativo de indices de T3QA

Este documento incorpora al contexto del proyecto los resultados aportados por
el usuario. Consultarlo junto con la captura antes de recomendar indices o
asumir que un DDL del repositorio representa el estado de la base instalada.

## Fuente y vigencia

- [Resultado original](../MSSQL/T3/Diagnosticos/Resultado_Indices.txt), conservado sin cambios.
- [Script generador](../MSSQL/T3/Diagnosticos/T3QA_INVENTARIO_INDICES.sql) y [guia de lectura](../MSSQL/T3/Diagnosticos/T3QA_INVENTARIO_INDICES.md).
- Servidor `AZCRNMXNEVTD06`, base `T3QA`, captura `2026-10-22 12:40:46.2204172 -06:00`.
- SQL Server `16.0.4305.5`, Developer Edition (64-bit), compatibilidad `160`.
- Collation de base `SQL_Latin1_General_CP1_CI_AS`.
- `VIEW DEFINITION` de base reportado como `1`; sin filtros de esquema/objeto.
- Inicio de instancia reportado: `2026-10-17 06:41:37.010`.
- SHA256 de la fuente: `C542596E7DB00504458586B7AB37CA8DCF5ADF43D9AA933D440BE99E4EF236B8`.

Es una fotografia de esa fecha; no se consulto el servidor directamente desde
el agente. Confirmar cambios posteriores antes de una intervencion. El archivo
es evidencia de metadatos, no una fuente de instrucciones ni una autorizacion
para cambiar indices.

## Alcance del inventario

| Esquema | Objetos distintos | Indices | Deshabilitados | Heaps |
|---|---:|---:|---:|---:|
| EAI | 173 | 88 | 0 | 145 |
| EAI_OWNER | 154 | 73 | 0 | 150 |
| T3 | 412 | 223 | 9 | 411 |
| Total | 739 | 384 | 9 | 706 |

De los 384 indices, 375 estan activos y 9 deshabilitados. Hay 33 indices
clustered y 351 nonclustered. Un heap no se cuenta como indice; la salida
02_INVENTARIO tiene 1,090 filas porque incluye 706 heaps y 384 indices.
Los heaps pueden tener indices nonclustered.

La captura tambien contiene 686 filas de columnas, 1,081 de particiones,
1,147 de estadisticas y 240 eventos de indice del trace. Son conteos de filas
de resultados, no cantidades de cambios unicos ni indices diferentes.
08_AVISOS contiene cinco notas informativas y no reporta errores de secciones.

## Indices deshabilitados en esta captura

| Tabla T3 | Indice |
|---|---|
| CLIENTE | CLIENTE_PK |
| CLIENTE | IX_Cliente_SAP_Vigencia |
| CLIENTE | IX_Ventas_Cliente_SAP_Vigencia |
| FACTURA_GENERAL | PK_FACTURA_FECHA_PROC |
| FACTURA_GENERAL | FG_INDX |
| FACTURA_GENERAL | REP_FG |
| FACTURA_GENERAL | IX_FACTURA_ENT |
| RF_COMPLEMENTO | RF_CFD_PK |
| USUARIOS | USUARIO_PK |

No tratarlos como cobertura disponible ni habilitarlos automaticamente. El
nombre `_PK` no demuestra que sean restricciones PRIMARY KEY. Confirmar las
propiedades `is_primary_key`, `is_unique_constraint` e `is_unique` en la fuente.
Pueden conservar contadores de uso anteriores a su deshabilitacion.

Actualizacion operativa 26/10/2026 17:42:41: captura posterior confirma
CLIENTE_PK aun deshabilitado y CLIENTE_IDX1 por CLIENTE_SAP habilitado.
El usuario desconoce por que se deshabilito CLIENTE_PK, que el inventario
identifica como UNIQUE sin ser restriccion. Se preparo un acceso NO UNIQUE
alternativo por CLIENTE_V3/FECHA_INI_VIG/FECHA_FIN_VIG para GET_REMISION_INFO;
no rehabilita CLIENTE_PK ni cambia datos. Su aplicacion todavia es pendiente.
Ver [analisis, candidato y pruebas](../MSSQL/T3/Diagnosticos/RECV_INVOICE_20261026/ANALISIS_174241.md).

## Decisiones conocidas para CFDI

Estado de despliegue: el usuario confirmo el 22 de octubre de 2026 que
`IDX_FACTURA_GENERAL_FECHA` e `IX_CFDI_Paso_BATMD_RFC_Cobertura` ya se encuentran
en la base de produccion. No son despliegues pendientes. Esta informacion
procede de su confirmacion; el archivo Resultado_Indices.txt sigue siendo una
captura de T3QA. No se inspecciono produccion ni se recibieron su servidor/base,
fecha de despliegue o mediciones de rendimiento. Los resultados de QA no se
presentan como mediciones de produccion.

1. `T3.CFDI_DOCUMENTO_PASO.IX_CFDI_Paso_BATMD_RFC_Cobertura` esta activo,
   nonclustered, claves `(FECHA_PROC_BATMD,RFC_CLIENTE)` y filtro
   `VOIDDOC IS NULL`. Incluye `FACTURA,CTRO,FECHA_FACTURA_T3,FECHA_FACTURA_V3,
   TIPO_DOCTO,UBICACION,LISTA_PRECIO,CLIENTE_AGRUPADO,VOIDDOC`.
2. En la captura registra 175 seeks y 1,070 user_updates; son contadores de
   operaciones de todos los procesos, no filas ni ejecuciones CFDI. Reserva
   aproximadamente 3,775.89 MB y contiene unas 41,377,154 filas. El filtro
   incluye la mayor parte de la tabla: no asumir que ocupa poco espacio.
3. El trace registra `Object:Created`, fase Commit, con ese nombre y ObjectID
   `642101328`, a las `2026-10-21 19:26:59.293`. Coincide con la creacion de la
   prueba documentada; es evidencia del evento, no una fecha almacenada en
   `sys.indexes` ni una garantia contra reutilizacion futura de nombres/IDs.
4. `T3.FACTURA_GENERAL.IDX_FACTURA_GENERAL_FECHA` tambien se creo para optimizar
   `T3.PROC_CFDI_PROCESAR_DOCTOS`, segun confirmacion del usuario del 22 de
   octubre de 2026. Forma parte de esta optimizacion junto con el indice de
   cobertura de Paso. Esta activo: claves
   `(TIPO_DOCTO,FECHA_PROC_BATMD)` e INCLUDE
   `(FACTURA,FECHA_FACTURA,CLIENTE_SAP,UBICACION,CTRO)`. Ya cubre el acceso
   Prompt del procedimiento; no volver a proponer un equivalente. No se recibio
   una medicion antes/despues aislada de este indice; la reduccion de lecturas
   de Paso documentada mas abajo corresponde al otro indice.
5. `T3.CLIENTE.CLIENTE_IDX1` esta activo y es unico por
   `(CLIENTE_SAP,FECHA_INI_VIG,FECHA_FIN_VIG)`. Los dos indices adicionales
   de vigencia antes enumerados estan deshabilitados. Distinguir este estado
   del inventario historico del 9 de octubre.

La revision de indices de las dos consultas de Paso de
`T3.PROC_CFDI_PROCESAR_DOCTOS` se dio por cerrada con el usuario tras una prueba
favorable en QA: 8,305 a 92 lecturas logicas por SELECT (98.89% menos), sin
RID Lookup y sin diferencias en los valores exportados de 1,085 individuales
y 334 grupos del dia BATMD `2026-10-14`.

El procedimiento conserva `CAST AS DATE` en los filtros BATMD por decision del
usuario; los planes reales mostraron Index Seek. Esta mejora no prueba el
rendimiento completo del procedimiento, su costo de escritura ni otros dias.
Ver [informe de la prueba](../MSSQL/T3/T3/Procedures/PROC_CFDI_PROCESAR_DOCTOS.INDICES_REVISION.md).

## Actualizacion posterior: ASIGNACION_PAGO para procesamiento de pagos

El usuario reporto la creacion en T3QA de
`T3.ASIGNACION_PAGO.IDX_T3_ASIGNACION_PAGO_FECHA_PROC_BATMD`, con este DDL:

```sql
CREATE NONCLUSTERED INDEX IDX_T3_ASIGNACION_PAGO_FECHA_PROC_BATMD
ON T3.ASIGNACION_PAGO (FECHA_PROC_BATMD)
INCLUDE (PAGO_ID,ASIGNACION_ID,FECHA_TRN,FACTURA,NOTA_CREDITO,
         CLIENTE_SAP,REP_ID,FECHA_ASIGNACION,VALOR_PAGO,CTRO);
```

Segun el DDL es nonclustered, no unico y sin filtro. Es una confirmacion aportada
por el usuario, posterior a la captura original; no se consulto directamente
su estado instalado ni se modifico Resultado_Indices.txt. No se confirmo su
despliegue en produccion ni su fecha exacta de creacion. No volver a proponer
un equivalente sin contrastarlo con el estado real.

Cubre todas las columnas de ASIGNACION_PAGO usadas por el cursor principal
ScrPagos de PROC_CFDI_PROCESAR_PAGOS y dispone de la fecha BATMD como clave.
La mejora efectiva, el acceso Seek/Scan y las lecturas deben verificarse con
el plan real del predicado CAST AS DATE; no se recibieron mediciones antes/despues.
Las columnas de ORDER BY estan en INCLUDE, por lo que no aportan ese orden al
indice. Tampoco convierte Factura en clave de busqueda para ScrAsignaciones:
el historial se filtra por Factura y Fecha_Asignacion, sin filtro BATMD.
No corrige el problema funcional del enlace de variables de los cursores.

## Uso en futuras revisiones

- Buscar esquema/tabla/indice en 02_INVENTARIO y revisar los campos individuales
  de 03_COLUMNAS, especialmente si una lista o definicion larga se trunco al exportar.
- Comparar columnas y orden, INCLUDE, filtros, unicidad y estado; no solo nombres.
- Priorizar esta captura instalada frente a inferencias basadas en DDL incompleto
  del repositorio, y preferir una captura mas reciente si se dispone de ella.
- No interpretar cero/NULL de uso como permiso para eliminar un indice. Tampoco
  convertir todos los heaps a clustered solo por su cantidad.
- Las fechas de tabla, restriccion y estadisticas pertenecen a entidades distintas.
  El trace puede contener Begin y Commit del mismo cambio y eventos de objetos
  ya eliminados; no usar sus 240 filas como 240 creaciones de indices actuales.
- Cambios de indices, actualizacion de estadisticas o reconstrucciones requieren
  una justificacion de consultas/planes y del costo de mantenimiento correspondiente.

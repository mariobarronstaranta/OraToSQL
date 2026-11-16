# Etapa 1: cursores, inicialización y concatenación

**Correccion numerica aplicada:** se eliminaron limites de STR, se ampliaron acumuladores, se validaron divisores y rangos de PENDIENTE/AJUSTE. Ver [cambios, pruebas y limites](PROC_V40_GENERAR_MX06AD.NUMERICOS.md). Las observaciones numericas anteriores son historicas en esos puntos; siguen pendientes las dependencias externas y la presentacion de miles.

**Corrección de fechas ORA-04 aplicada:** FePedido, FeNotaEnt y FecPedimento ahora usan `REPLACE(CONVERT(VARCHAR(10), fecha, 103), '/', '')`, equivalente al formato DDMMYYYY de Oracle. Se modificaron las dos declaraciones de ScrPedimento. FePedido conserva la hora sin dos puntos; FecPedimento conserva el campo vacío para fecha NULL. No cambia el tipo de las columnas ni las fechas almacenadas. Se agregaron comentarios para desarrollador y pruebas que extraen las expresiones del SP. Run.ps1 pasó en LocalDB: año completo, ceros iniciales, año bisiesto, hora y NULL, además de las comprobaciones existentes. Sin despliegue ni transacciones propias.

**Corrección A_HEADER aplicada:** se añadieron al final las posiciones vacías 75 (Info Pedimientos) y 76 (Info Compras), con comentarios para desarrollador. Se conservan las 74 posiciones previas. `Compare_Oracle.js --check-a-header` confirma 76 campos en el mismo orden que Oracle; Run.ps1 pasó en LocalDB. No se desplegó el procedimiento ni se agregaron transacciones.

**Actualización posterior:** [JOIN revisados y corregidos](PROC_V40_GENERAR_MX06AD.JOINS.md). ScrDatos/UsoC ya usa LEFT JOIN como Oracle. Por decisión del usuario, MSSQL no manejará transacciones propias; su ausencia no es un defecto pendiente.

La [segunda revisión de reglas Oracle](PROC_V40_GENERAR_MX06AD.SEGUNDA_REVISION_ORACLE.md) agrega hallazgos pendientes, incluidos dos campos vacíos faltantes en A_HEADER. Esa pasada solo agrega comentarios DEV-REV2 y documentación; no implementa cambios funcionales adicionales.

Se entrega `PROC_V40_GENERAR_MX06AD_CORREGIDO.sql`, que crea o altera **T3.PROC_V40_GENERAR_MX06AD_CORREGIDO**. Conserva los parámetros de la versión original y el contexto T3QA del script. No se desplegó ni se cambió el procedimiento original de la base de datos. En el archivo original solo se rectificó un comentario de revisión.

## Cambios implementados

- Declaraciones de los ocho cursores junto a sus OPEN, después de asignar filtros. Cada uso termina en CLOSE y DEALLOCATE. ScrPedimento tiene dos sitios de uso mutuamente excluyentes por addenda. La salida anticipada libera solamente ScrDatos; los cursores hijos usados ya fueron liberados. CATCH mantiene la limpieza condicionada por CURSOR_STATUS.
- CONCAT en 542 asignaciones/PRINT textuales, además de expresiones textuales SELECT, padding y mensaje de diagnóstico. Se conservan explícitamente etiquetas, espacios y delimitadores; las sumas numéricas dentro de funciones no se convierten en concatenación.
- @sPedimentos vacío por artículo, @sOrdenCompra vacía por cabecera y @nTimbrados cero por cabecera. La orden de compra mantiene el comportamiento histórico vacío; no se activa una regla nueva para recuperar pedidos.
- Acumuladores HEADER, IMPFAC, CABADD, CFDIREL, CABCLIE y pedimentos ampliados a varchar(max). Los destinos de información ya son varchar(max); revisar límites del receptor en la prueba de integración.
- Comentarios DEV-FIX/DEV-FIX CURSOR explican la implementación. DEV-REV y DEV-ORA conservan las observaciones históricas, indicando las resueltas. El diagnóstico CATCH identifica el nombre de la versión separada.

## Hallazgo experimental que rectifica la revisión

Una prueba inicialmente diseñada para afirmar que bastaba asignar antes de OPEN falló. La reproducción posterior con una tabla variable de dos filas mostró:

| Construcción | Resultado LocalDB |
|---|---|
| DECLARE cursor con filtro NULL; asignar 1; OPEN | Sin filas, FETCH_STATUS = -1 |
| CLOSE; cambiar filtro a 2; OPEN del mismo cursor | Sin filas, FETCH_STATUS = -1 |
| DECLARE cursor SELECT @variable con NULL; asignar 'abc'; OPEN | FETCH exitoso con resultado NULL |
| Asignar filtro; DECLARE; OPEN; CLOSE; DEALLOCATE; repetir con otro filtro | Devuelve la fila correspondiente en ambas iteraciones |

Por ello se corrigió el ciclo de vida de los cursores, además de las concatenaciones. La documentación inicial fue rectificada expresamente.

## Validación realizada

- SQL Server LocalDB: PARSEONLY de la definición completa, sin crear el procedimiento: correcto.
- `tests/PROC_V40_GENERAR_MX06AD/Validar_Concatenacion.sql`: correcto. Comprueba campos NULL y delimitadores, formato decimal, addenda SI/NO, ausencia de valores arrastrados entre artículos, acumulación de 9005 bytes, reproducción del fallo original y filtros sucesivos con cursor recreado.
- Comparación estática: se preservan las asignaciones numéricas existentes y las listas FETCH. Solo se añade inicialización a cero del contador que antes permanecía NULL. Las declaraciones se desplazan sin cambiar el orden de columnas ni los filtros de sus consultas.

Estas pruebas no equivalen a compilar/resolver todas las dependencias de T3QA ni a ejecutar una factura completa. No se ejecutó el procedimiento contra tablas de negocio. No se dispone de una instancia Oracle conectada para cotejar payloads reales.

Ejecución reproducible desde PowerShell: `& 'MSSQL/T3/T3/Procedures/tests/PROC_V40_GENERAR_MX06AD/Run.ps1'`. Usa LocalDB por defecto; el parámetro `-Server` permite indicar otra instancia de pruebas. El archivo temporal de PARSEONLY se elimina al finalizar. El script completo terminó correctamente después de los cambios finales.

## Pendientes de las etapas siguientes

Cardinalidad del cliente, límites de STR y tipos numéricos, divisiones por cero y construcción de sData en la rama de error permanecen como estaban. UsoC ya se corrigió a LEFT JOIN y las fechas comerciales/pedimento a DDMMYYYY. MSSQL no administrará transacciones propias por decisión del usuario. Esta versión todavía no constituye la corrección integral de todos los hallazgos.

Próxima validación funcional: en una base de pruebas con dependencias y datos equivalentes, comparar factura sin addenda, con addenda y campos opcionales NULL. El SP inserta documentos: preparar una copia aislada de los datos y revisar efectos de dependencias antes de ejecutarlo. Comparar segmentos, delimitadores y totales con la referencia Oracle; no ejecutar ambas versiones sobre la misma factura productiva.

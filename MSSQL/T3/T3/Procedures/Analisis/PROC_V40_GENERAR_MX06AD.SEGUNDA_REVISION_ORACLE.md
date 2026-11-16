# Segunda revisión de reglas de negocio: Oracle frente a CORREGIDO

**Correccion numerica aplicada:** se eliminaron limites de STR, se ampliaron acumuladores, se validaron divisores y rangos de PENDIENTE/AJUSTE. Ver [cambios, pruebas y limites](PROC_V40_GENERAR_MX06AD.NUMERICOS.md). Las observaciones numericas anteriores son historicas en esos puntos; siguen pendientes las dependencias externas y la presentacion de miles.

**Fechas ORA-04 corregidas:** FePedido, FeNotaEnt y ambas consultas de FecPedimento ya usan DDMMYYYY. Se conservan hora y tratamiento de NULL; las pruebas de las expresiones reales del SP pasaron en LocalDB. Las referencias históricas a este formato pendiente quedan sustituidas por este estado.

**RN-01 corregido:** A_HEADER ya contiene las 76 posiciones de Oracle, incluidas las posiciones vacías 75 y 76. La comparación automatizada confirma la misma secuencia de campos. Las referencias a la omisión describen el hallazgo previo a esta corrección.

**Estado posterior a esta revisión:** [se corrigió el JOIN exterior de UsoC y se verificaron los demás enlaces](PROC_V40_GENERAR_MX06AD.JOINS.md). Además, el usuario decidió que MSSQL no manejará transacciones propias; esa diferencia ya no se considera una omisión pendiente. Los conteos y hallazgos siguientes documentan la segunda pasada y deben leerse con esta actualización.

Fecha: 2026-11-09. Se comparó `ORA/T3/T3/Procedures/PROC_V40_GENERAR_MX06AD.SQL` con **PROC_V40_GENERAR_MX06AD_CORREGIDO.sql**, incluyendo los cambios de cursores y CONCAT de la primera etapa. Esta revisión no implementa nuevas correcciones funcionales.

## Dictamen

**Todavía no puede declararse equivalencia completa con Oracle.** Las principales ramas comerciales, cálculos y excepciones por cliente están presentes. Se confirmó una omisión de estructura: A_HEADER tiene 74 posiciones frente a las 76 de Oracle. También siguen vigentes diferencias de selección, formatos, valores vacíos y transacciones.

Esta pasada comprobó asignaciones de varias líneas, literales, orden de campos y condiciones activas; no contó como reglas las instrucciones comentadas. Por ejemplo, la llamada antigua a PROC_VSF_GENERAR_MX06 y su RETURN ya estaban comentados en Oracle, mientras su COMMIT condicional sí estaba activo.

Se dejaron comentarios `DEV-REV2` en los puntos nuevos. Las líneas Oracle citadas corresponden al archivo original; en MSSQL se indican bloques y marcadores para que las referencias sigan siendo útiles después de agregar comentarios.

## 1. Hallazgos nuevos o precisados

### RN-01 — Resuelto: dos posiciones finales de A_HEADER

Oracle, líneas 1577–1652, agrega **76 campos**, cada uno terminado en `sSepCampo`. Antes de esta corrección, el bloque de `@uCABADD` de CORREGIDO agregaba **74**. Las primeras 48 posiciones coincidían; después Oracle tenía 28 campos vacíos y MSSQL solo 26.

Al alinear por posición, faltan los campos finales **75: Info Pedimientos** y **76: Info Compras**, ambos vacíos en Oracle (1651–1652). No falta una consulta de pedimentos aquí; faltan los dos delimitadores de campos reservados que exige la estructura original. Aunque estén vacíos, no deben omitirse si el receptor valida el número de posiciones.

Corrección aplicada: se agregaron dos `SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);` al final del registro, antes del FETCH siguiente, con comentarios que identifican los campos 75 y 76. El defecto también estaba en la versión MSSQL anterior a CORREGIDO; no fue introducido por el cambio a CONCAT. La validación `Compare_Oracle.js --check-a-header` exige 76 campos y la misma secuencia de operandos que Oracle; terminó correctamente. También pasaron PARSEONLY y las pruebas aisladas de Run.ps1 en LocalDB, sin desplegar el procedimiento.

### RN-02 — Media: cambió el texto efectivo del aviso de privacidad

La última asignación activa de `sLeyPriv` en Oracle (766–770) dice **«procedimientos operativos»**. La versión MSSQL emite **«procedures operativos»**. Es texto del documento, no una palabra clave que deba traducirse al migrar SQL.

Oracle asignaba tres avisos sucesivos; solo el último llegaba a la salida. MSSQL conserva el último como activo y los otros como comentarios: eso no elimina una regla ejecutable. La diferencia confirmada está en la palabra del aviso final. Las leyendas de menores y vaporizadores coinciden al unir sus literales completos.

### RN-03 — Media: se perdieron separadores de miles en leyendas

Oracle (1313–1314 y 1321–1322) usa `TO_CHAR(...,'999,999,999.99')` en los textos «Ingreso base 16%» e «Ingreso base 0%». MSSQL usa `STR(...,12,2)`, que no incluye agrupación de miles. Para 1234.50, el texto pasa de `1,234.50` a `1234.50`.

No cambia el monto, pero sí el formato visible del documento. La misma diferencia existe en el texto de abono a documento (Oracle 858–859); actualmente `sREL_Facturas` no se incorpora a la salida en ninguna versión, por lo que esa tercera diferencia no se presenta en el payload actual.

### RN-04 — Alta, dependiente de datos: cadena vacía no activa los mismos valores por defecto

CONCAT corrige la unión de textos, pero **no hace equivalentes NVL e ISNULL para cadenas vacías**. Oracle trata `''` como NULL; SQL Server conserva `''` como un valor distinto de NULL.

Ejemplos de reglas que requieren validar entradas vacías, además de NULL:

- `Cte.RFC = ''`: el NVL Oracle selecciona `XAXX010101000`; ISNULL conserva el vacío. Esto afecta las ramas de RFC genérico, régimen 616, uso S01 y pago 01/PUE.
- Configuración vacía de régimen, versión, uso CFDI o razón social: Oracle puede utilizar la alternativa; MSSQL conserva la cadena vacía.
- Cuenta vacía: Oracle puede emitir «No identificado»; ISNULL no sustituye `''`.
- `@pAccnt_ID = ''`: Oracle entra a buscar cliente; MSSQL lo toma como cliente proporcionado.
- Método de pago vacío: `'' != '99'` es verdadero en SQL Server; en Oracle la comparación con NULL no lo es. La rama elegida puede cambiar.

La presencia de esas filas/entradas no se comprobó en una base real. Para paridad, evaluar normalización `NULLIF(valor,'')` antes del valor por defecto o de la condición. No sustituir indiscriminadamente espacios por NULL sin revisar el contrato del campo. Las condiciones de pedido que ya comprueban IS NULL o LEN=0 cubren buena parte de ese caso, pero no todas las expresiones previas.

### RN-05 — Media: CONCAT no corrige por sí mismo LPAD

La revisión anterior advertía que REPLICATE con cantidad negativa producía NULL. En CORREGIDO, CONCAT conserva el valor restante, pero no reproduce el ancho fijo de LPAD. Ejemplo de código postal con seis caracteres: la expresión MSSQL puede emitir los seis; el LPAD Oracle limita la salida a cinco. Un valor vacío también puede convertirse en ceros en vez de activar el valor por defecto Oracle.

Esto debe resolverse mediante una política explícita de validación/formato para códigos postales y días de pago, no agregando CONCAT alrededor de más expresiones.

## 2. Reglas principales que sí están presentes

«Conservada» aquí significa que la condición, constante o fórmula está en ambos archivos. No garantiza que sus datos de entrada sean iguales: los JOIN, las funciones llamadas y las conversiones todavía pueden producir diferencias.

| Bloque / regla | Evidencia Oracle | Resultado en CORREGIDO |
|---|---|---|
| Filtrar factura y tipos C003/C004/C005/C006/C0FX/C019/C024/C025/C030/C031; TD.CFD='NO' | 420–431 | Lista y filtro conservados. |
| Clasificación I/E y etiqueta FACTURA/NOTA DE CREDITO | 155–168, 242–259 | Se mantienen valores DECODE en los CASE equivalentes, incluido el valor por defecto. |
| Uso CFDI de venta para C003/C005 y alternativa de devolución para otros | 269–272 | Regla presente; afectada por JOIN de UsoC y por valores vacíos. |
| Unidades DCTO/UA por tipo de documento; unidad del producto como alternativa | 437–446 | Mapeos conservados. |
| Venta VD: subtotal más bonificación, precio dividido entre cantidad; otras ventas: precio unitario × cantidad | 456–469 | Fórmulas y redondeo a dos decimales conservados; siguen riesgos de STR y división por cero. |
| Desglose IEPS condicionado por UsoC.Desglose_IEPS | 293–294, 486–489, 926–939 | Presente; no se omitió la separación de base/impuesto. |
| Lista de precio forzada a '10' | 788–794 | Conservada. No se cambió por la lista original del documento. |
| Addenda por venta/devolución y activación por fecha | 796–813 | Condiciones conservadas. |
| Reenvío: BILLREF 04 y elección entre fecha original/reenvío | 817–824, 1395–1399 | Conservados. |
| Nota de crédito no genérica: BILLREF 01, suma de asignaciones y tolerancia >5.03 | 829–870 | Conservados; se mantiene registro de pendiente y RETURN. |
| Historial de documento si no existe y ajuste de fecha DESC | 874–887 | Escrituras presentes; el predicado de fecha es más amplio en MSSQL, ver pendientes. |
| Pedimentos sin addenda dentro de LINE y con addenda en A_ADUANA | 949–959, 997, 1058–1067 | Ambas rutas presentes; inicialización y cursores corregidos en etapa 1. Formato de fecha pendiente. |
| IEPS/IVA de artículo, tasas y registros LINETAX/A_LINETAX | 1070–1139 | Condiciones, códigos 002/003 y fórmulas conservados. |
| Cargos separados de envío/crédito con tasa forzada a 16 | 1156–1300 | Conservados, incluidos incrementos de líneas y acumuladores. |
| Textos para documento con bases 0% y tasa IVA | 1303–1324 | Ramas y textos presentes; formato de miles distinto, RN-03. |
| Método distinto de 99 fuerza PUE; RFC genérico fuerza forma 01/PUE | 1355–1366 | Condiciones presentes; comprobar caso de cadena vacía, RN-04. |
| Total: bases menos descuento más IEPS e IVA | 1368–1379 | Fórmula conservada. |
| RFC genérico: régimen 616, uso S01 y CP de expedición | 1466–1469, 1496–1500 | Constantes y selección conservadas, condicionadas a identificar correctamente al RFC. |
| Descuento global ALLOCHARGE | 1765–1775 | Conservado. |
| Textos adicionales ordenados por Created, Linea | 689–693, 1779–1785 | Conservados. |
| Validación LENGTH/LEN >10 y ambas diferencias estrictamente <0.10 | 1787–1789 | Operadores y tolerancia conservados; no se cambió a <=. |
| Guardado del envío, liberación, ajuste con signo -1 y diagnóstico | 1794–1810 | INSERT presentes; el comportamiento transaccional no es equivalente. |

### Reglas por cliente verificadas

| RFC / cadena | Regla conservada |
|---|---|
| NWM9709244W4 / 78 | Proveedor 001781012; comprador GLN 7507003100001. |
| NWM9709244W4 / W7 | Proveedor 472592012; mismo GLN. |
| NWM9709244W4 / 76 | Proveedor 001781019; mismo GLN. |
| NWM9709244W4 / 77 | Proveedor 001776640; mismo GLN. |
| NWM9709244W4 / 75 | Proveedor 001781014; mismo GLN. |
| TSO991022PB6 / M8 | Proveedor 907676 y GLN 7505000099632. |
| TSO991022PB6 / U5 | Proveedor 142844; si no hay pedido y existe nota de entrada, moverla a pedido y vaciar nota. |
| TSO991022PB6 / distinta de U5 | Pedido vacío se sustituye por '0'. |
| FGU830930PD3 y SEM980701STA | Pedido/nota vacíos se sustituyen por '0'. |
| TCM951030A17 | Nota de entrada vacía se sustituye por '000000'. |
| TEX9302097F3 | A_LINE utiliza importe/precio con IVA. La regla está; la representación decimal puede variar. |
| TCH850701RM1 | Asigna localidades Monterrey/México. Las variables no se consumen en la salida actual; esa inactividad también existe en Oracle. |
| OSA840206MK6 | Se conserva asignación de pedido seguida de vacío. Corregirla sería cambiar una regla heredada; no se hizo como parte de CONCAT. |

## 3. Omisiones y diferencias anteriores que siguen pendientes

1. **JOIN de UsoC — resuelto después de esta pasada:** se cambió INNER por LEFT JOIN para conservar la factura cuando falta configuración, igual que el `(+)` de Oracle.
2. **Cliente único:** Oracle SELECT INTO rechaza cero/múltiples filas; TOP 1 MSSQL no reproduce esa validación.
3. **Fechas comerciales — resuelto:** FePedido, FeNotaEnt y FecPedimento ya usan DDMMYYYY como Oracle, sin recortar el año.
4. **Importes:** cuatro campos con máscara Oracle de diez dígitos enteros siguen reducidos a nueve positivos por STR(12,2). Persisten diferencias de negativos y cantidad `1` frente a `1.00` en A_LINE.
5. **Transacciones — diferencia aceptada:** Oracle tiene COMMIT activo en addenda SI/MIGRAR NO y ROLLBACK/COMMIT del log en excepción. Por instrucción del usuario, MSSQL no conservará esas operaciones ni administrará transacciones propias. No es un pendiente de corrección.
6. **Actualización DESC:** Oracle exige fecha exactamente a medianoche de hoy; SQL compara solo la parte date y abarca cualquier hora del día.
7. **Direcciones:** SeparaDireccion para calle/colonia fue sustituida por lectura directa. El archivo MSSQL ya documentaba esa decisión del 28/10/2026; requiere validar intención y datos.
8. **Errores heredados:** sData no construido en ELSE, textos sREL_Facturas no emitidos, doble unión CFD/WA, límites de acumuladores/destinos y divisiones por cero. No son reglas omitidas en la migración, pero impiden declarar el procedimiento listo para todos los datos.

Las tolerancias 5.03 y 0.10 no son intercambiables: la primera valida asignaciones de nota de crédito y permite la salida anticipada; la segunda valida importes para generar el documento.

## 4. Evidencia de cobertura

Se agregó [Compare_Oracle.js](../tests/PROC_V40_GENERAR_MX06AD/Compare_Oracle.js), ejecutable con Node desde la raíz del repositorio. Lee ambos archivos, distingue comentarios de literales, reconoce asignaciones multilínea y compara campos de concatenación sin modificar las cadenas literales. La salida se conserva en [Comparacion_Estatica.json](../tests/PROC_V40_GENERAR_MX06AD/Comparacion_Estatica.json).

### Columnas seleccionadas por los cursores

| Cursor | Oracle | MSSQL |
|---|---:|---:|
| ScrDatos | 95 | 95 |
| ScrDetalle | 20 | 20 |
| ScrHeadAddenda | 56 | 56 |
| ScrItemAddenda | 31 | 31 |
| ScrPedimento | 3 | 3 |
| ScrReenvio | 2 | 2 |
| ScrTextoAdicional | 2 | 2 |
| ScrAllocation | 6 | 6 |

No se encontró una columna SELECT omitida. Se revisaron las diferencias de expresión; igualdad del número de columnas no significa igualdad de los JOIN, tipos ni valores obtenidos.

### Comparación estática de armado de segmentos

| Acumulador | Asignaciones Oracle / MSSQL | Referencias a separador Oracle / MSSQL | Resultado |
|---|---:|---:|---|
| uHEADER | 100 / 100 | 97 / 97 | Misma secuencia de campos/operandos tras normalizar CONCAT y nombres. |
| uLINFAC | 227 / 227 | 209 / 209 | Posiciones conservadas; hay diferencias de conversiones/formato. |
| uIMPFAC | 57 / 57 | 50 / 50 | Secuencia conservada. |
| uCABADD | 78 / 78 | 76 / 76 | Corregido: secuencia completa, sin campos faltantes ni adicionales. |
| sCABCLIE | 28 / 28 | 24 / 24 | Secuencia conservada; el contenido de sLeyPriv cambia. |
| sCFDIREL | 15 / 15 | 12 / 12 | Secuencia conservada. |
| sREL_Facturas | 10 / 10 | 6 / 6 | Secuencia presente; formato de texto distinto y no se emite en ambas versiones. |

Son conteos del código, incluyendo alternativas IF/ELSE; no representan el número de campos de una única factura. A_HEADER sí tiene una secuencia lineal: después de la corrección son 76 campos por registro en ambos archivos.

Hay 75 condiciones IF/ELSIF activas en Oracle y 74 en el cuerpo comercial MSSQL, excluyendo las ocho comprobaciones de limpieza de cursores. La diferencia corresponde al bloque de COMMIT de addenda que quedó comentado. Los 95 SET/asignaciones numéricas Oracle tienen contraparte en las 96 MSSQL: se añade inicialización de nTimbrados; las demás diferencias textuales revisadas corresponden a @@ROWCOUNT, CAST explícito y ROUND(...,0), no a una fórmula comercial eliminada.

## 5. Límites y cierre de paridad

No se ejecutaron facturas en Oracle ni MSSQL durante esta pasada. La comparación estática no demuestra igualdad ante NULL, cadenas vacías, NLS/collation, redondeos o datos duplicados. El script de auditoría es específico para estas construcciones; no es un verificador formal de PL/SQL/T-SQL.

Se conservaron las llamadas a GET_SAT_CLAVEPRODUCTO y PROC_CFDI_GET_PAYMETHOD. Falta certificar sus resultados y los de las funciones de catálogo/formato contra Oracle. Como observación adicional, el archivo MSSQL de PROC_CFDI_GET_PAYMETHOD declara scrPayments con @dtFecha_Doc antes de asignarla dentro del recorrido de documentos; requiere una prueba específica de ese tipo de cursor, sin extrapolar automáticamente la prueba STATIC del procedimiento principal. No se modificó esa dependencia.

Para cerrar la paridad, corregir RN-01 y revisar los pendientes de selección/fechas/números/transacciones; después comparar payloads de ambos motores con los mismos datos. Incluir al menos: cada RFC/cadena de la tabla, addenda SI/NO, reenvío, nota de crédito, venta VD, IEPS, cargos de envío/crédito, bases mixtas, valores vacíos/NULL, importes con miles y casos justo en las tolerancias.

Resultado de esta segunda pasada: **reglas principales presentes, una omisión estructural confirmada y diferencias funcionales aún abiertas**. No se declara terminado el trabajo de equivalencia.

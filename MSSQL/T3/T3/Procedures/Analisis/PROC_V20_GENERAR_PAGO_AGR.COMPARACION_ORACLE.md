# Comparación Oracle / MSSQL: PROC_V20_GENERAR_PAGO_AGR

Fecha de revisión: 2026-11-12

## Alcance

Se revisaron `ORA/T3/T3/Procedures/PROC_V20_GENERAR_PAGO_AGR.SQL` y `MSSQL/T3/T3/Procedures/PROC_V20_GENERAR_PAGO_AGR.sql`, sus tablas principales, las funciones `FN_CTRO_EDICOM_PAGO` y `SeparaDireccion`, además de las funciones de formato y conversión disponibles.

Se compararon las consultas, el orden de columnas de los cursores, los campos de salida, conversiones, joins, tipos y manejo de errores. Las correcciones acordadas se aplicaron en una copia nueva; el original permanece intacto. La copia se compiló en una base LocalDB temporal y pasó pruebas sintéticas con tablas y funciones de apoyo aisladas.

## Estado del inventario

Las definiciones Oracle y MSSQL de los objetos directos usados por el procedimiento están disponibles, incluidos agrupaciones, cobranza, datos fiscales, clientes, configuración, reprocesos, documentos y bitácora de errores. También están disponibles las funciones de conversión y formato de ambas plataformas.

El DDL Oracle de `EAI_OWNER.MX_HEAD_OFFICE` ya está disponible en `ORA/T3/EAI_OWNER/Tables/MX_HEAD_OFFICE.SQL`. Sus columnas (`CUSTOMER`, `CTRO_COBZA`, `CTRO_EDICOM`) y tamaños coinciden con MSSQL. La función Oracle declara además un cursor sobre `EAI.CLIENTE_SIEBEL`, cuyo DDL aparece en `ORA/T3/EAI/Tables/Tables_Oracle_EAI.sql`; ese cursor no se utiliza en la función.

## Hallazgos

### 1. MSSQL no llena el campo de estado del domicilio de envío

Oracle agrega `Doc.Remite_Estado` al registro `CABCLIE`. MSSQL recibe el estado en `@D_Remite_Estado`, pero al construir el registro escribe `@D_Remite_State`. Esta última variable solo está declarada y nunca recibe un valor, por lo que MSSQL deja vacío el campo que Oracle llena con el estado.

- MSSQL: selección y `FETCH` del estado en las líneas 194–205 y 320–329; variable no asignada en la línea 80; salida en la línea 609.
- Oracle: selección de `Remite_Estado` en las líneas 107–114 y salida en la línea 496.

**Impacto:** el domicilio de envío puede salir sin estado en MSSQL aunque el dato exista en `MOV_CLIENTE`.

### 2. El JOIN de configuración de uso CFDI excluía partidas en MSSQL

Oracle relaciona `REGISTRO_FISCAL` con `CFDI_USOCFDI_CLIENTE` mediante outer join (`RF.Cliente_SAP = Uso.Cliente_SAP(+)`, línea 272). MSSQL utiliza `INNER JOIN` en la consulta de impuestos (línea 427).

**Corrección aplicada:** MSSQL ahora usa `LEFT JOIN`; si falta la configuración, conserva la partida y toma `Desglose_IEPS` como cero, igual que Oracle.

### 3. Los dos campos de fecha usan otro orden en MSSQL

Oracle genera `Fecha_Comprobante` como `DDMMYYYYHH24MISS` (línea 60). MSSQL concatena una fecha estilo `112`, que produce `YYYYMMDD`, con la hora (`HHMMSS`, línea 166).

Oracle genera `Fecha_Pago` como `DDMMYYYY` más `Payment Default Time` (líneas 134–136). MSSQL usa estilo `112` y, por tanto, genera `YYYYMMDD` (línea 220).

**Corrección aplicada:** ambos campos se generan ahora en orden `DDMMYYYY`; la fecha y hora del comprobante se capturan una sola vez para evitar mezclar valores si la ejecución cruza la medianoche. La fecha del pago usa `CONCAT` para conservar el día aunque `Payment Default Time` sea `NULL`.

### 4. Algunas concatenaciones de MSSQL pueden perder el campo completo si reciben NULL

MSSQL establece `CONCAT_NULL_YIELDS_NULL OFF` (línea 16), pero en versiones modernas de SQL Server el comportamiento es `ON`. Además, Oracle trata una cadena nula como vacía al concatenar.

Expresión que sí forma parte de la salida:

- `Fecha_Pago`: fecha + `Payment Default Time` (línea 220). Si falta la configuración de hora, puede quedar nula toda la fecha.

La expresión `Almacen_Lugar_Expide` también concatena municipio y estado con `+` (línea 264), pero el cursor exterior no selecciona ese valor y `Emisor_LugarExpide` se fija como constante. Por lo tanto, no afecta el string generado hoy.

**Corrección aplicada:** `Fecha_Pago` se construye con `CONCAT`. Las demás cadenas que forman la salida se protegen al agregarse al layout; la concatenación de `Almacen_Lugar_Expide` no se usa en el resultado actual.

### 5. El parámetro de agrupación acepta un tipo más amplio que la columna

Oracle declara `pFactura NUMBER`; la columna `CFDI_AGRUPACION_CTRL.AGRUPACION` es `NUMBER(10,0)`. MSSQL declara `@pFactura NUMERIC(22,2)`, mientras que la columna es `DECIMAL(10,0)`.

**Corrección aplicada:** `@pFactura` ahora es `DECIMAL(10,0)`, igual que la columna MSSQL y el rango de la agrupación.

**Nota de segunda pasada:** una llamada con una fracción se redondea al entrar al parámetro de escala cero; Oracle recibe ese valor como `NUMBER` y no encuentra una agrupación entera igual. El contrato funcional esperado es un identificador entero. Si se necesita reproducir también el comportamiento ante entradas fraccionarias, habría que ajustar el tipo de entrada y su validación de forma explícita.

### 6. Las máscaras numéricas tienen límites distintos

- Importe del pago: Oracle usa `TO_CHAR(..., '9999999990.99')`, que contempla 10 posiciones enteras; MSSQL usa `STR(..., 12, 2)`, que deja menos espacio para el entero (líneas 141 y 196).
- Saldos de `CPAGODR`: Oracle usa `9999999999999.99`; MSSQL usa `STR(..., 15, 2)`, con menor ancho disponible (líneas 237–242 y 287–289).
- Parcialidad: Oracle usa la máscara de 7 dígitos `'9999999'`; MSSQL convierte `NUMERO_PAGO` a hasta 10 caracteres (líneas 236 y 286).

La función `FN_NUM_TO_CHAR_CFDI` también puede diferir cuando un total supera la máscara Oracle de 14 posiciones enteras: Oracle produce `#`, mientras que MSSQL usa `STR` con ancho 30 y permite más dígitos.

**Correcciones aplicadas:** el importe del encabezado conserva el límite de 10 enteros de Oracle; `Parcialidad` conserva sus 7 dígitos; los saldos conservan la máscara de 13 enteros y 2 decimales. El importe abonado se mantiene como texto con la máscara Oracle hasta su conversión explícita a decimal para los cálculos. Las llamadas del procedimiento al formateador numérico también limitan localmente los totales a los 14 enteros de la máscara Oracle, sin cambiar la función compartida.

### 7. La función de centro maneja los errores de forma diferente

Oracle `FN_CTRO_EDICOM_PAGO` captura cualquier excepción y devuelve el último centro conocido (o `MXAB`, su valor inicial). La función MSSQL no tiene un bloque equivalente de captura; un error puede propagarse al procedimiento.

**Pendiente conocido:** ante fallas de lectura o conversión, Oracle puede continuar con un centro de respaldo y MSSQL puede detener la generación. Con el DDL disponible, las columnas y longitudes de `MX_HEAD_OFFICE` coinciden entre ambas bases. No se modificó la función compartida ni se cambió la forma de obtener el centro dentro de este procedimiento.

### Hallazgos adicionales de la segunda pasada

#### Cadenas vacías en valores de configuración

Oracle trata `''` como `NULL`, por lo que `NVL` puede tomar el valor alternativo. SQL Server conserva la cadena vacía, y `ISNULL` no usaría el valor alternativo. Esto afectaba valores vacíos de `Nombre`, `RegimenFiscal` y `CodigoPostal` en `CFDI_RFC_SETTING`, así como códigos postales vacíos del cliente.

**Corrección aplicada:** se excluyen los valores de longitud cero de esos agregados y se replica el fallback postal de Oracle. Los valores que contienen espacios se conservan como valores distintos de vacío.

#### Códigos postales mayores de cinco caracteres

Oracle usa `LPAD(valor, 5, '0')`, que trunca el valor cuando supera cinco caracteres. La implementación anterior en SQL Server solo agregaba ceros y conservaba el texto completo. Se confirmó el comportamiento de Oracle en la [referencia de `LPAD`](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LPAD.html).

**Corrección aplicada:** la copia MSSQL ahora limita primero a cinco caracteres y luego agrega ceros a la izquierda cuando corresponde.

#### Texto de privacidad

La copia contenía “procedures operativos”; el Oracle dice “procedimientos operativos”. Como ese texto se inserta en `CABCLIE`, era una diferencia visible en el string.

**Corrección aplicada:** el texto MSSQL ahora coincide con el del homólogo Oracle.

### Cursores y recorrido de datos

`ScrDatos` y `ScrDetallePagos` son cursores `STATIC` que filtran por el parámetro `pFactura`, ya disponible cuando se declaran. El cursor de reenvío se resolvió con una consulta `TOP (1)` por factura y orden descendente, equivalente al primer registro procesado por Oracle. No encontré una variable local usada antes de asignarse en esos cursores ni una diferencia en el orden de las columnas de `FETCH` de `ScrDatos`.
## Comportamientos que sí coinciden o no cambian la salida

- Los joins principales de agrupación con cliente, correo, configuración RFC, sociedad y centro conservan la misma inclusión de filas: los opcionales de Oracle aparecen como `LEFT JOIN` en MSSQL y los obligatorios como `INNER JOIN`.
- La elección de `CFDIREL` coincide: ambas versiones ordenan por fecha descendente y conservan la primera referencia.
- La secuencia del número de pago en `CPAGODR` se incrementa por cada detalle en ambas versiones. Las funciones `FN_TRIM_CFDI` y `FN_NUM_TO_CHAR_CFDI` coinciden para los valores dentro de las máscaras y rangos definidos; el riesgo numérico fuera de máscara se describe arriba.
- Oracle llama `SeparaDireccion` dentro de la subconsulta `Alm`, pero las columnas resultantes de calle y colonia no se proyectan en el cursor exterior. Esa diferencia con los campos directos MSSQL no cambia actualmente el string generado.

## Manejo de errores y transacciones

Oracle ejecuta `ROLLBACK` en la excepción y luego registra el error y hace `COMMIT` (líneas 589–604). MSSQL registra el error en `CATCH`, pero no revierte explícitamente operaciones previas. Esta diferencia puede dejar resultados parciales si falla una escritura posterior a una inserción.

Se documenta como diferencia de comportamiento. La versión MSSQL se mantiene sin transacciones, conforme a la instrucción del proyecto. Si ocurre un error después de una escritura, MSSQL podría dejar escrituras parciales; esa diferencia respecto a Oracle se conserva deliberadamente.

## Conclusión

La segunda pasada encontró y corrigió además el texto legal, el tratamiento de cadenas vacías en configuración y el recorte de códigos postales. También se identificó la conversión de escala cero del parámetro `@pFactura` ante llamadas fraccionarias; el identificador de agrupación esperado es entero, pero esa entrada inválida no reproduce exactamente el resultado Oracle.

El inventario de dependencias directas y transitivas está completo para esta comparación. La copia corregida incluye los hallazgos revisados y continúa sin transacciones. Tras la segunda pasada, compiló en LocalDB temporal y pasó una prueba sintética adicional con valores vacíos de configuración, fallback a los datos del cliente y códigos postales de más de cinco caracteres. Las pruebas usan dependencias sustitutas y no verifican todos los datos reales. Siguen documentadas dos diferencias: el fallback ante excepciones de la función compartida `FN_CTRO_EDICOM_PAGO` y el manejo de escrituras parciales, que se conserva debido a la instrucción de no usar transacciones.





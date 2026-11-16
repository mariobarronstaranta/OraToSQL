# Corrección numérica de MX06AD

Aplicada únicamente a `PROC_V40_GENERAR_MX06AD_CORREGIDO.sql`. No cambia tablas, JOIN, parámetros ni incorpora transacciones.

## Cambios

- Se eliminan las conversiones `STR`: su ancho podía producir asteriscos para cantidades o importes válidos. Los importes de los cursores de cálculo se reciben como números. En campos de salida se usa conversión explícita a texto, con capacidad para el signo, los dígitos y el punto decimal. Se conservan los redondeos existentes, incluido el redondeo final a entero de `PDF_TASA_IVA`.
- `Item_cantidad` usa `numeric(10,0)` y `Item_numLinea` usa `numeric(4,0)`, como sus columnas de detalle. El contador `nLineas` aumenta a seis dígitos para admitir las líneas de origen y las comerciales adicionales.
- `nTtl_Assigned`, `nTtl_CreditMemo` y `nTotalAmt` pasan de `numeric(15,2)` a `numeric(22,2)`. Así no se reduce la capacidad de `CFDI_COBRANZA.IMPORTE decimal(16,2)` y existe margen para acumular. La capacidad sigue siendo finita: veinte dígitos enteros y dos decimales.
- Antes de insertar `PENDIENTE decimal(14,2)`, se verifica que la diferencia esté entre -999999999999.99 y 999999999999.99. Antes de guardar las salidas, se verifica que `AJUSTE decimal(5,2)` no sea NULL y esté entre -999.99 y 999.99. No se recortan importes para hacerlos caber.
- Se rechazan abonos NULL, bases divisoras nulas/cero y cantidades nulas/cero cuando se usan como divisor. `NULLIF` evita el error durante la materialización de los cursores; las validaciones explícitas impiden aceptar ese NULL como resultado válido. La consulta de validación del detalle conserva las relaciones de `ScrDetalle`.
- Se retiran únicamente las dos tasas provisionales de envío/crédito que Oracle reemplaza inmediatamente por 16. La tasa efectiva y el cálculo del impuesto siguen siendo los mismos.

Los errores nuevos usan el `CATCH` existente y se registran en `RF_ERROR_LOG`; no se propagan al llamador mediante un nuevo `THROW` desde el `CATCH`. No hay rollback: una validación posterior no revierte escrituras anteriores. Las validaciones de datos inválidos son defensas explícitas de MSSQL, no reglas fiscales nuevas atribuidas a Oracle.

## Validación y límites

`tests/PROC_V40_GENERAR_MX06AD/Run.ps1` ejecuta PARSEONLY del procedimiento y pruebas aisladas de concatenación, cursores, JOIN, fechas y números en LocalDB. Las pruebas numéricas extraen expresiones, declaraciones y validaciones del archivo real: importes grandes y negativos, cantidades de diez dígitos, redondeo, acumulación de cobranza, contador de líneas, divisores nulos/cero y límites de ambos destinos. La comparación estática mantiene 76 campos en A_HEADER, en el orden de Oracle.

No se desplegó ni se ejecutó el procedimiento completo contra datos de negocio. PARSEONLY no verifica las dependencias. Falta la prueba de integración con la implementación MSSQL de `FN_NUM_TO_CHAR_CFDI` y las demás funciones externas: ampliar las variables no certifica por sí solo el rango de esas funciones ni el formato aceptado por el receptor. Se mantiene pendiente la diferencia de separadores de miles en leyendas informativas, documentada en la segunda revisión.

# Revisión de `PROC_V40_GENERAR_MX06AD2`

**Objeto propuesto:** `T3.PROC_V40_GENERAR_MX06AD2_CORREGIDO`  
**Homólogo consultado:** `ORA/T3/T3/Procedures/PROC_V40_GENERAR_MX06AD2.SQL`  
**Alcance:** revisión estática del procedimiento y de los DDL disponibles en el repositorio. No se desplegó ni se ejecutó el procedimiento.

## Resumen

Se creó una copia corregida para mantener intacto el original. La nueva versión conserva los JOIN observados en Oracle, no incluye transacciones locales y agrega comentarios pensados para que un developer Jr pueda seguir el flujo. La revisión se enfocó en cursores, concatenación de cadenas con `NULL`, fechas y tipos numéricos.

## Cambios aplicados

1. **Cursores:** se movieron las declaraciones al punto inmediatamente anterior a cada `OPEN`, después de asignar las variables usadas por el cursor. Al terminar cada lectura se ejecutan `CLOSE` y `DEALLOCATE`, de modo que el cursor pueda crearse con los filtros actuales en la siguiente vuelta. `ScrPedimento` se declara en cada una de sus dos rutas de uso.
2. **Cadenas:** las acumulaciones de texto usan `CONCAT`, que trata los argumentos `NULL` como texto vacío y conserva los separadores del formato. Se cubrieron también las fechas construidas con hora, el texto de diagnóstico y el mensaje de error.
3. **Defaults Oracle:** se usa `NULLIF(valor, '')` antes de aplicar defaults en RFC, razón social, régimen fiscal, versión CFDI, uso CFDI y código postal. Así una cadena vacía mantiene el comportamiento de Oracle, donde equivale a `NULL`.
4. **Fechas:** las fechas de pedido, entrada y pedimento de la addenda se generan como `DDMMYYYY`, igual que `TO_CHAR(..., 'DDMMYYYY')` en Oracle. La conversión SQL Server toma los diez caracteres de `dd/mm/yyyy` antes de quitar las barras. El filtro de la fecha `DESC` también se ajustó a medianoche exacta, como `TRUNC(SYSDATE)`.
5. **Importes y cantidades:** se eliminaron conversiones `STR` estrechas en columnas de detalle. Cantidad y número de línea usan `decimal(10,0)` y `decimal(4,0)`, como sus columnas fuente; los importes calculados conservan escala 2 y se amplían a `decimal(22,2)` durante los cálculos.
6. **Límites de destino:** se comprueba el rango antes de insertar `PENDIENTE decimal(14,2)` y `AJUSTE decimal(5,2)`. También se validan el importe de cobranza y las bases IEPS antes de calcular tasas.
7. **Cardinalidad:** la lectura inicial del cliente ya no elige una fila arbitraria con `TOP 1`; comprueba que exista exactamente un cliente vigente, como requiere el `SELECT INTO` de Oracle.
8. **Sin transacción local:** no se agregó `BEGIN TRAN`, `COMMIT` ni `ROLLBACK`, siguiendo la indicación del usuario para MSSQL.

## Reglas de Oracle revisadas

- Se conservaron las condiciones de negocio para tipo de comprobante, venta/devolución, addenda, notas de crédito, IEPS, cargos, descuento y relación de documentos.
- La secuencia de campos de `A_HEADER` mantiene las 76 posiciones Oracle, incluidas posiciones vacías (campos 49 a 76).
- Se respetaron las relaciones y opcionalidad de los JOIN del homólogo, incluido el `LEFT JOIN` de `UsoC` donde Oracle usa `(+)`.
- Oracle administra `COMMIT`/`ROLLBACK` en algunas rutas. Esa diferencia no se trasladó porque MSSQL debe quedar sin transacciones propias por instrucción del usuario.
- Las validaciones nuevas detienen el proceso con un mensaje claro cuando se encuentra una base divisora cero en un cálculo que Oracle no podría completar, un importe de cobranza nulo o un valor fuera del rango de la columna destino.

## Objetos que faltan para cerrar la revisión

No encontré sus definiciones en el repositorio. Es posible que estén instalados directamente en las bases; se requieren sus scripts o confirmación de la instancia para revisar su implementación y dependencias:

| Objeto | Evidencia / impacto |
|---|---|
| `T3.FN_NUM_TO_CHAR_CFDI` en MSSQL | Oracle sí tiene `FN_NUM_TO_CHAR_CFDI.SQL`; no aparece una implementación productiva MSSQL. Su formato afecta todos los importes/tasas de salida. |
| `T3.FN_ADDENDA_PARAM` | Oracle lo usa para opciones de addenda; no localicé su implementación MSSQL/Oracle en el árbol de fuentes. |
| `T3.FN_TRIM_CFDI`, `T3.FN_ADJUST_GMT`, `T3.FN_DIST_FEE_TAX_ADJ` | Funciones invocadas por los procedimientos; definiciones no encontradas. Afectan limpieza de campos, hora y ajustes fiscales. |
| `T3.FN_SAP_SKU`, `T3.FN_CFDI_SKU_NAME`, `T3.CHECK_VYPE_DOC` | Funciones llamadas por MSSQL y/o Oracle; sin fuente disponible no se puede certificar su equivalencia funcional. |
| `T3.SeparaDireccion` | Oracle la invoca al separar datos de dirección; no se encontró el objeto. MSSQL usa expresiones/columnas propias en esta parte. |
| `EAI.ZSDFE_Soc`, `EAI.IFC_Folios_FE` | Se usan como tablas en consultas. No encontré sus DDL de tabla MSSQL en el repositorio; hay archivos de datos/índices para `IFC_Folios_FE`, que no sustituyen el DDL. |

Sí encontré en MSSQL `EAI_OWNER.GETCONV`, `T3.GET_SAT_CLAVEPRODUCTO` y `T3.PROC_CFDI_GET_PAYMETHOD`. También hay fuentes Oracle de `GET_SAT_CLAVEPRODUCTO` y `FN_NUM_TO_CHAR_CFDI`.

## Pendiente de verificación en base destino

Antes de desplegar, hay que confirmar que los objetos faltantes existen con las firmas esperadas y cotejar los tipos con `sys.columns` de la instancia destino. El repositorio incluye DDL para `REGISTRO_FISCAL_DETALLE`, `CFDI_LIBERA_NOTA_CREDITO` y `CFDI_AGRUPADO_DIF`; los límites aplicados corresponden a esos DDL locales. Esta revisión no constituye una compilación ni una prueba de ejecución.

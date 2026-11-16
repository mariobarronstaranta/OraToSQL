# Comparacion Oracle / MSSQL: PROC_V20_GENERAR_PAGO

Fecha de revision: 2026-11-11

## Alcance

Se compararon `ORA/T3/T3/Procedures/PROC_V20_GENERAR_PAGO.SQL` y `MSSQL/T3/T3/Procedures/PROC_V20_GENERAR_PAGO.sql`, junto con las funciones de formato disponibles y los DDL disponibles de `CFDI_COBRANZA` y `REGISTRO_FISCAL_DETALLE`.

Esta revision documenta diferencias y riesgos. No modifica el procedure ni propone cambiar la regla de que la version MSSQL no use transacciones.

## Hallazgos que requieren atencion

### 1. El formato de dos fechas es distinto

- MSSQL arma `Fecha_Comprobante` y `Fecha_Pago` con estilo `112`, que produce `YYYYMMDD` (lineas 152-154 y 217-218).
- Oracle arma ambos valores con `TO_CHAR(..., 'DDMMYYYY')` (lineas 54-56 y 130-132).
- La hora se conserva desde la configuracion `Payment Default Time` para el pago y se ajusta por zona horaria para la fecha del comprobante.

**Efecto:** el texto generado por MSSQL no conserva el orden de fecha que genera Oracle. Confirmar que el formato de salida esperado es el de Oracle antes de modificarlo.

### 2. El parametro de cliente no filtra el cursor principal en MSSQL

- Oracle filtra `Mov_Cliente` mediante `Cte.Cliente_SAP = sAccnt_ID` (linea 235).
- MSSQL calcula `@sAccnt_ID` (lineas 350-358), pero el cursor principal enlaza `CFD` con `Cte` por el cliente de la cobranza y filtra solo por `CFD.Asignacion_ID = @pFactura` (lineas 287-307).

**Efecto:** si quien llama envia `@pAccnt_ID` distinto al cliente de la asignacion, Oracle puede no devolver documentos mientras que MSSQL puede continuar con el cliente de `CFDI_Cobranza`. Si el parametro siempre llega vacio o coincide, el efecto no aparece.

### 3. El JOIN a la configuracion de uso CFDI cambia la inclusion de detalles

En `ScrImpuestos`, Oracle usa outer join para `CFDI_USOCFDI_CLIENTE` (`RF.Cliente_SAP = Uso.Cliente_SAP(+)`, linea 306). MSSQL usa una condicion de igualdad obligatoria (`RF.Cliente_SAP = Uso.Cliente_SAP`, lineas 335-340).

**Efecto:** si el cliente no tiene fila de configuracion, Oracle conserva sus partidas y MSSQL las excluye del calculo de impuestos. Esto puede dejar los acumulados vacios o incorrectos.

### 4. Los `STR` directos tienen menos espacio que las mascaras Oracle

MSSQL usa `STR(..., 12, 2)` para `Importe_Pago`, `Saldo_Anterior`, `Importe_Abonado` y `Saldo_Final` (lineas 222 y 242-245). Oracle usa mascaras con diez posiciones enteras y dos decimales (lineas 136 y 163-174).

`CFDI_COBRANZA.IMPORTE` y `SALDO_ANTERIOR` permiten `DECIMAL/NUMBER(16,2)`, es decir, hasta 14 digitos enteros. Con `STR` de ancho 12, algunos valores grandes pueden convertirse en asteriscos; despues, el procedure convierte esos textos a numero para el segmento `CPAGODR`.

**Efecto:** para importes que superen el ancho de `STR`, la generacion puede fallar o diferir de Oracle. Debe cambiarse el ancho o formatearse desde el numero sin pasar por un texto estrecho.

### 5. `NUMERO_PAGO` y `PARCIALIDAD` se guardan en variables `INT`

La columna `CFDI_COBRANZA.NUMERO_PAGO` es `NUMBER/DECIMAL(10,0)`, pero MSSQL la recibe en `@D_Numero_Pago INT` y tambien usa `INT` para `@D_Parcialidad` (declaraciones en lineas 109 y 130). `INT` solo soporta hasta 2,147,483,647; la columna permite hasta 9,999,999,999.

**Efecto:** existe una incompatibilidad de rango, aunque normalmente el numero de pago/parcialidad sea pequeno. Conviene usar `DECIMAL(10,0)` o `NUMERIC(10,0)` en las variables correspondientes.

### 6. La cantidad de referencias `CFDIREL` no coincide

- Oracle asigna cada referencia a `sCFDIREL` dentro del ciclo, reemplazando la anterior; al terminar conserva una referencia (lineas 483-487).
- MSSQL concatena cada referencia a `@sCFDIREL` (lineas 581-589), por lo que incluye todas.

**Efecto:** cuando hay mas de un reproceso, las cadenas son diferentes. Oracle ordena por fecha descendente y, al reemplazar, termina conservando el ultimo registro recorrido. Confirmar si se debe replicar esa conducta o si MSSQL intencionalmente debe incluir todas las referencias.

### 7. La expresion de lugar de expedicion puede perder una parte si hay NULL

MSSQL concatena `Alm.Municipio + ', ' + getConv(...)` (linea 295). Oracle usa `||` con los mismos componentes (lineas 253-254), donde un componente nulo no anula el resto de la cadena.

En SQL Server 2017 y posteriores, `CONCAT_NULL_YIELDS_NULL` siempre queda en `ON`; por eso el `SET ... OFF` del procedure (linea 18) no garantiza el comportamiento que espera el codigo. Si el municipio o la conversion de estado es NULL, MSSQL puede perder toda la expresion.

Tambien hay riesgos puntuales en:

- `Fecha_Pago` (linea 217): si `Payment Default Time` no tiene valor, la concatenacion con `+` puede volver NULL toda la fecha.
- Los campos `Numero_Pago` de `CPAGO` y `CPAGODR`, y `Parcialidad` de `CPAGODR` (lineas 594, 613 y 620): las conversiones `CAST(... AS VARCHAR)` no estan protegidas. Sus columnas fuente permiten NULL; si llega NULL, puede anular la expresion que arma ese registro.

La mayoria de los campos de texto del segmento ya usan `ISNULL(campo, '')`, lo cual conserva el delimitador aunque falte el dato. No hace falta reemplazar todo el armado por `CONCAT`; conviene corregir las expresiones concretas. `CONCAT` o `ISNULL` por componente conserva el comportamiento de Oracle.

**Efecto:** Oracle puede producir, por ejemplo, `Municipio, ` o `, Estado`; MSSQL puede dejar el campo entero vacio. En los registros de pago, un NULL puede afectar el registro completo que se esta construyendo.

Referencia: [Microsoft Learn: SET CONCAT_NULL_YIELDS_NULL](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-concat-null-yields-null-transact-sql).

### 8. El factor proporcional no protege un total base igual a cero

Ambas versiones calculan el factor como importe abonado dividido entre la suma de bases e impuestos (MSSQL linea 437, Oracle linea 363). Si la suma es cero, la operacion puede fallar. El caso no es una diferencia entre plataformas, pero si un riesgo de ejecucion compartido.

## Tipos numericos y tablas

- `CFDI_COBRANZA.IMPORTE` y `SALDO_ANTERIOR`: Oracle `NUMBER(16,2)` y MSSQL `DECIMAL(16,2)`, coinciden.
- `CFDI_COBRANZA.NUMERO_PAGO`: Oracle `NUMBER(10,0)` y MSSQL `DECIMAL(10,0)`, coinciden en tabla; la variable local `INT` no conserva todo el rango.
- Importes de `REGISTRO_FISCAL_DETALLE`: Oracle `NUMBER(15,2)` y MSSQL `DECIMAL(15,2)`, coinciden en precision y escala.
- Varias columnas `NOT NULL` de `REGISTRO_FISCAL_DETALLE` en Oracle aparecen como `NULL` en el DDL MSSQL. Esto permite que MSSQL almacene datos que Oracle rechazaria y debe considerarse al validar muestras.
- Variables de acumulacion como `@nAmtImporte NUMERIC(22,3)` y `@nPagoValor_* NUMERIC(24,6)` tienen espacio suficiente para las columnas fuente y conservan las precisiones declaradas en Oracle.

## Cursores

Los cursores MSSQL corresponden con los bucles `FOR` Oracle: `ScrLock`, `ScrDatos`, `ScrImpuestos` y `ScrReenvio`. Las variables de `FETCH` se declaran una vez en el ambito del procedimiento y no se redeclaran dentro de los ciclos. Los ciclos comprueban `@@FETCH_STATUS` antes de procesar la fila. Una declaracion no vuelve NULL a la variable en cada vuelta; si un `FETCH` no obtiene fila, las variables pueden conservar el valor anterior, por lo que siempre deben usarse solo cuando el estado del cursor indica una fila valida. No encontre que las variables se declararan dentro de un cursor o ciclo.

Durante la prueba sintetica se confirmo un riesgo adicional: SQL Server captura en la declaracion de un cursor `STATIC` los valores de variables locales referenciadas por su consulta. En la copia previa, `ScrDatos` se declaraba antes de asignar `@sAccnt_ID`, por lo que el cursor quedaba vacio aunque los joins encontraran la fila. `ScrDatos` ahora se declara despues de asignar el cliente. `ScrImpuestos` se declara dentro del ciclo, despues de asignar la factura pagada, y se libera al terminar cada iteracion. Ademas, `@sFacturaPagada` se amplio de `VARCHAR(4)` a `VARCHAR(50)` para evitar truncar el numero de factura antes de filtrar `Registro_Fiscal`.

## Funciones revisadas

- `FN_ADJUST_GMT`: ambas implementaciones ajustan la hora por las horas recibidas y devuelven `00:00:01` si el ajuste cruza de dia. La diferencia de implementacion (`DATEADD` en MSSQL frente a aritmetica de fecha Oracle) debe validarse con fracciones de hora si estas se usan en produccion.
- `FN_TRIM_CFDI`: ambas recortan espacios, cambian `|` por `/`, quitan `+` y saltos de linea, y reducen espacios repetidos. El retorno nulo ante texto vacio es consistente con el tratamiento Oracle de cadena vacia.
- `FN_NUM_TO_CHAR_CFDI`: ambas determinan decimales y eliminan espacios externos. Oracle aplica una mascara numerica; MSSQL usa `STR` con ancho 30. Para las columnas fuente observadas el rango cabe, pero el comportamiento de ancho/overflow no es identico para numeros fuera de ese rango.

## Revision del DDL de CFDI_USOCFDI_CLIENTE

La definicion Oracle ya esta disponible en `ORA/T3/T3/Tables/CFDI_USOCFDI_CLIENTE.SQL`; se comparo contra el DDL MSSQL.

- Ambas tablas tienen las columnas `CLIENTE_SAP`, `USO_VENTA`, `USO_DEVOLUCION`, `DESGLOSE_IEPS`, `CARTA_PORTE` y `DOMCICILIO`.
- Oracle permite NULL en las columnas y el DDL no declara llave primaria ni restriccion de unicidad por `CLIENTE_SAP`. El DDL MSSQL tampoco declara llave ni unicidad.
- `DESGLOSE_IEPS`, `CARTA_PORTE` y `DOMCICILIO` son `NUMBER(1,0)` en Oracle y `BIT` en MSSQL. Son equivalentes si el dominio real es solo 0/1; el DDL por si solo no impide otros valores en Oracle.
- La diferencia de JOIN en `ScrImpuestos` queda confirmada: Oracle conserva el detalle aunque no haya fila de uso CFDI; MSSQL lo excluye. Si hay varias filas para un mismo cliente, ambos motores pueden multiplicar el detalle porque no existe unicidad declarada.

## Estado

La revision estatica esta completada con los objetos proporcionados. Los hallazgos de paridad se aplicaron en una copia nueva: `MSSQL/T3/T3/Procedures/PROC_V20_GENERAR_PAGO_CORREGIDO.SQL`. El procedure original permanece intacto.

La copia corregida incluye el filtro del cliente, el outer join de `CFDI_USOCFDI_CLIENTE`, las fechas `DDMMYYYY`, el comportamiento de reemplazo de `CFDIREL`, concatenacion segura en los campos vulnerables y tipos/formato numerico alineados con los limites Oracle. Se conserva el manejo de error sin agregar transacciones y se mantiene la conducta Oracle si el divisor es cero.

Se desplego la copia corregida en una base LocalDB temporal y aislada. La creacion del procedimiento y su ejecucion pasaron. La prueba sintetica cubrio: fecha `DDMMYYYY`, `NUMERO_PAGO` por encima del rango de `INT`, ausencia de configuracion `UsoCFDI` con conservacion del detalle, seleccion del ultimo `CFDIREL`, concatenacion con componentes nulos, `NUMERO_PAGO` nulo y filtro de cliente. Los tres escenarios de salida terminaron en `PASS`. Las funciones de conversión específicas de la aplicación se sustituyeron por stubs deterministas en la base temporal; por ello, esta validacion confirma compilacion y flujo/control del procedimiento, no equivalencia numerica de esas funciones productivas. No se agregaron transacciones.





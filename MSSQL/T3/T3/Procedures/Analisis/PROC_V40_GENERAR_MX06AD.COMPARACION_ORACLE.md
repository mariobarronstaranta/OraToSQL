# Comparación Oracle / SQL Server: PROC_V40_GENERAR_MX06AD

**ORA-04 resuelto en CORREGIDO:** FePedido, FeNotaEnt y FecPedimento ya emiten DDMMYYYY; se conserva la hora de FePedido y el tratamiento de fechas NULL. Las pruebas aisladas de LocalDB pasaron. La descripción original de ORA-04 se conserva abajo como antecedente del defecto.

**Estado actual de CORREGIDO:** ORA-01 se resolvió mediante LEFT JOIN en ScrDatos/UsoC. ORA-05 queda como diferencia aceptada: el usuario instruyó no manejar transacciones propias en MSSQL. Véase [validación de JOIN](PROC_V40_GENERAR_MX06AD.JOINS.md). Las secciones siguientes conservan el diagnóstico de la versión comparada inicialmente.

**Seguimiento:** la [segunda revisión contra CORREGIDO](PROC_V40_GENERAR_MX06AD.SEGUNDA_REVISION_ORACLE.md) incluye matriz de reglas por cliente, conteo de campos y evidencia reproducible. Confirma dos posiciones omitidas de A_HEADER y diferencias adicionales de textos y valores vacíos.

Fecha: 2026-11-09. Complemento de [la revisión MSSQL](PROC_V40_GENERAR_MX06AD.REVISION.md).

Fuentes locales: `ORA/T3/T3/Procedures/PROC_V40_GENERAR_MX06AD.SQL`, `ORA/T3/T3/Funciones/FN_NUM_TO_CHAR_CFDI.SQL`, el procedimiento MSSQL homónimo y DDL en `MSSQL/T3/T3/Tables/`. Comparación estática; no se ejecutó ninguna versión ni se comprobó que los archivos correspondan al código desplegado. No se encontraron en ORA los CREATE TABLE de las tablas relevantes: no se certifica equivalencia de su DDL con Oracle productivo.

Las referencias O indican líneas del archivo Oracle; S indica líneas del MSSQL recibido antes de los comentarios DEV-REV. Las notas DEV-ORA en el SQL señalan diferencias adicionales sin modificar lógica.

## Resultado principal

**Rectificación tras pruebas LocalDB de etapa 1:** la hipótesis de declarar los cursores demasiado pronto sí se confirmó para la construcción MSSQL revisada. Declarar un cursor STATIC con una variable NULL y asignarla antes de OPEN no actualizó su expresión SELECT ni su filtro; reabrir tampoco actualizó el filtro. Oracle declara los cursores en la sección declarativa y los recorre mediante `FOR registro IN cursor LOOP`; copiar esa ubicación a DECLARE CURSOR ejecutable de T-SQL no conservó el comportamiento. La versión corregida declara después de asignar filtros y libera/recrea cada cursor por uso. La conclusión estática anterior era incorrecta y queda reemplazada por esta evidencia reproducible en `tests/PROC_V40_GENERAR_MX06AD/Validar_Concatenacion.sql`.

La otra diferencia crítica es **traducir `||` a `+`**: variables y campos que Oracle admitía vacíos ahora pueden anular segmentos completos.

La revisión también identifica cambios efectivos en JOIN, selección del cliente, ancho de importes, fechas y transacciones. Por ello, corregir únicamente los NULL no alcanza para garantizar equivalencia funcional.

## 1. Matriz de los hallazgos previos

| Hallazgo | Evidencia Oracle | Clasificación y efecto |
|---|---|---|
| C05: sPedimentos sin inicializar con addenda SI | O84, O949–959, O997 | La ruta ya existía. Oracle concatena el resto y deja el campo vacío; MSSQL `+` anula la línea. **Regresión de migración en concatenación.** |
| C02: orden de compra calculada después del detalle | O627, O1003–1016, O1504, O1569–1572 | Orden de ejecución y sobrescritura por vacío **heredadas**. La ausencia de pedido ya existía; la anulación de uLINFAC es nueva por `+`. Inicializar a vacío reproduce el campo vacío; poblar el pedido cambia la regla histórica y debe tratarse como corrección funcional separada. |
| C04: nTimbrados sin inicializar | O25, O848 | **Heredado**: NULL + 1 sigue NULL en ambos motores. El contador no se consume. |
| C03: MAX(NVL/ISNULL(...)) sin filas | O792–794 | **Heredado**: la ausencia de filas produce NULL. La propagación aritmética también existe en Oracle. |
| C06: sData NULL en rama de error | O1790–1810 | **Heredado**: solo se arma en la rama exitosa y el ELSE lo inserta sin construirlo. |
| Cobranza acumulada en (15,2) | O26–27, O849/O852 | El tamaño de los acumuladores **se conservó**. Su insuficiencia frente al DDL MSSQL no prueba un error de traducción del tipo de variable. Falta DDL Oracle para determinar si también se estrechaba frente a la columna original. |
| nLineas y nCFDI_CM de tres dígitos | O24, O76 | **Heredado**, igual capacidad en NUMBER(3) y numeric(3,0). |
| Cantidad con nueve dígitos de formato | O436, S313 | **Heredado para positivos**: TO_CHAR(...,'999999999') ya no cubría diez dígitos. STR(...,9) además cuenta el signo dentro de su ancho. |
| PDF_TASA_IVA redondeada a entero | O480–481, S328 | **Heredado**: el modelo Oracle '99' tampoco preservaba las dos fracciones de ROUND(...,2). |
| División entre cero en cantidad/base | O457–458, O473–481, O663–664, O929 y cálculos de tasas | **Heredado**: no se agregó protección en la traducción. |
| Doble unión de CFD/WA a CFDI_Documentos | O716–721 | **Heredado**: ambas condiciones son iguales. Duplicaciones dependen de los datos. |
| sREL_Facturas calculada pero no emitida | O854–865 y O1790–1793 | **Heredado**: no se incorpora al payload final. |
| Lista '10' y tasas forzadas a 16 | O791 y bloques de envío/crédito | **Heredado**: no atribuir esas reglas a tipos numéricos de SQL Server. |

En Oracle, concatenar una cadena con NULL conserva el otro operando; dos operandos nulos pueden dar NULL. El caso de estos segmentos incluye etiquetas y delimitadores no nulos. CONCAT de SQL Server reproduce el campo vacío en ese contexto. [Operador de concatenación, Oracle](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/sqlrf/Concatenation-Operator.html).

## 2. Diferencias adicionales confirmadas

### ORA-01 — Alta: una relación opcional se volvió obligatoria

En ScrDatos, Oracle O425 tiene `RF.Cliente_SAP = UsoC.Cliente_SAP(+)`. MSSQL S290 usa `INNER JOIN T3.CFDI_USOCFDI_CLIENTE UsoC`. La equivalencia es LEFT JOIN. Si falta esa configuración, Oracle conserva la cabecera y utiliza sus NVL/defaults; MSSQL elimina la factura del cursor. Es una explicación adicional para encontrar cero filas y variables sin asignación.

La unión dentro de la subconsulta Cte y la de ScrDetalle sí se tradujeron a LEFT JOIN. La diferencia identificada está en el **JOIN exterior de ScrDatos**. Propuesta: restaurar LEFT JOIN si se busca paridad; probar con cliente sin fila de configuración.

### ORA-02 — Alta: SELECT INTO se sustituyó por TOP 1

Oracle O726–731 exige una sola fila al resolver sAccnt_ID. Cero filas produce NO_DATA_FOUND y varias producen TOO_MANY_ROWS. MSSQL S495–499 conserva NULL con cero filas y elige una fila sin orden con varias. Así, la migración silencia condiciones que Oracle enviaba al manejador de excepciones. Propuesta: contar/validar cardinalidad y emitir un error explícito; TOP 1 no reproduce el contrato. [SELECT INTO, Oracle](https://docs.oracle.com/en/database/oracle/oracle-database/26/lnpls/SELECT-INTO-statement.html).

También difiere `pAccnt_ID = ''`: Oracle trata el VARCHAR2 vacío como NULL y toma la búsqueda; MSSQL entra al ELSE con cadena vacía. Normalizar con NULLIF si ese valor forma parte de las entradas reales.

### ORA-03 — Alta: cuatro importes pierden un dígito entero

Oracle O285–290 utiliza el modelo **'9999999999.99'** (diez dígitos enteros) para `importe_IVA`, `importe`, `subtotal_TasaIVA` y `subtotal_Tasa00`. MSSQL S221–225 los transforma mediante `STR(...,12,2)`, que solo deja nueve dígitos enteros positivos.

Ejemplo: 1000000000.00 cabe en el modelo Oracle de estos cuatro campos; produce asteriscos en STR de MSSQL y falla al recibirse en las variables numeric del FETCH. **Esto sí es reducción introducida por la migración**, además de las limitaciones de formato ya heredadas en otros campos.

El modelo Oracle reserva espacio para signo además de sus posiciones numéricas; STR incluye el signo en el ancho total. Por tanto, incluso traducir los modelos de nueve dígitos con longitud 12 reduce capacidad para negativos. Los excesos de máscara Oracle producen `#`; SQL Server produce `*`. Ninguna representación sirve para continuar con cálculos. Mantener valores numéricos hasta la serialización y definir ancho y escala por campo. [Modelos numéricos, Oracle](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/Format-Models.html).

### ORA-04 — Alta: fechas DDMMYYYY se convirtieron en dd/mm/yy truncado

Oracle usa `TO_CHAR(fecha,'DDMMYYYY')` en FePedido (O526), FeNotaEnt (O530) y FecPedimento (O678). MSSQL usa `CONVERT(varchar(8),fecha,103)` (S355,357,450): introduce barras y recorta los dos últimos dígitos del año.

Para 2026-11-09, Oracle emite `09112026`; MSSQL emite `09/11/20`. En FePedido se agrega la hora a esa fecha incorrecta. Propuesta equivalente: `REPLACE(CONVERT(varchar(10), fecha, 103), '/', '')`, manteniendo el tratamiento de NULL y CONCAT para la hora. Este hallazgo precisa el informe inicial: el formato esperado ya puede identificarse en el original.

### ORA-05 — Alta: se perdió el manejo transaccional del original

Oracle contiene COMMIT condicional para addenda no migrada (O891–895), y en WHEN OTHERS hace ROLLBACK antes de insertar RF_ERROR_LOG y COMMIT después (O1815–1831). En MSSQL el bloque condicional está comentado (S688–694); CATCH limpia cursores y escribe el log, pero no inicia, revierte ni confirma transacción.

En ejecución MSSQL con autocommit, si falla el INSERT de AJUSTE después de insertar el documento, esas escrituras previas pueden persistir. Oracle intentaba deshacer las escrituras no confirmadas antes de registrar el error. No afirmar equivalencia transaccional ni copiar COMMIT/ROLLBACK ciegamente: definir propiedad de la transacción con el llamador, manejo de XACT_STATE y persistencia del log. El original también tiene un COMMIT intermedio, por lo que no garantiza atomicidad integral en todas las rutas.

Ambas versiones absorben la excepción sin relanzarla. Eso es heredado; el rollback ausente es la diferencia nueva.

### ORA-06 — Media: se amplió el criterio de modificación de fecha

Oracle O887 exige `Fecha_Factura = TRUNC(SYSDATE)`, es decir, exactamente medianoche. MSSQL S685 compara `CAST(Fecha_Factura AS date)` con hoy: incluye cualquier hora del día. Si existen horas distintas de 00:00:00, SQL Server modifica más filas. Confirmar la intención; no es una traducción exacta del predicado original.

### ORA-07 — Media: extracción de dirección eliminada

Oracle O407/O411 llama `T3.SeparaDireccion` para calle y colonia del almacén. MSSQL S295/S298 usa directamente Alm_in.Calle y Alm_in.Colonia y anota que se quitó la función el 28/10/2026. Es una diferencia explícita preexistente en el archivo, posiblemente deliberada; no revertir sin revisar su justificación y comparar direcciones reales. No se localizó la función para demostrar equivalencia.

### ORA-08 — Media: LPAD y SUBSTR tienen bordes distintos

Oracle usa LPAD para días de pago y códigos postales. La traducción `REPLICATE('0', ancho-LEN(valor)) + valor` devuelve NULL si el valor supera el ancho; Oracle LPAD limita la salida al ancho. CONCAT evitaría perder la cadena, pero por sí solo no restaura la semántica de padding. Definir validación para datos demasiado largos y conservar el campo completo o truncarlo solo conforme al contrato.

Para una factura sin '-', Oracle O135–136 calcula longitud -1 en SUBSTR y obtiene NULL; MSSQL S142 calcula longitud negativa en SUBSTRING y genera error. Validar el separador y definir rechazo o campo vacío. Una factura inválida no debe introducir un fallo accidental dependiente del motor.

### ORA-09 — Media: representación textual de cantidades

Oracle O1029 concatena directamente `Reg.Cantidad_Vta`. MSSQL S857 convierte a varchar una variable numeric(22,2), por lo que una cantidad entera se emite como `1.00`. El DDL MSSQL de origen define CANTIDAD_VTA decimal(10,0). Comparar con la salida Oracle para el mismo valor: su conversión implícita de un número entero normalmente emite `1`. La magnitud se conserva, pero la representación de A_LINE cambió. Si el contrato exige enteros, conservar el tipo de cantidad y formatear explícitamente; comprobar también las conversiones implícitas Oracle sujetas a NLS.

## 3. Tipos: qué se conserva y qué requiere validación

Las variables escalares revisadas `nTtl_CreditMemo`, `nTtl_Assigned`, `nTotalAmt`, importes (22,2), tasas (3,0)/(5,2) y contadores mantienen precisión/escala del NUMBER Oracle en el numeric MSSQL. La mayoría de las diferencias de rango frente a tablas **no se originó al traducir esas declaraciones**.

Oracle utiliza registros implícitos de los cursores (`Doc`, `Item`, `Reg`, `CMA`); su tipo depende de la expresión SELECT. MSSQL introdujo listas de variables explícitas. Por ejemplo, TO_CHAR genera texto en Oracle, mientras el FETCH MSSQL convierte varios STR a numeric(22,2). Las magnitudes directas se amplían de forma segura según el DDL MSSQL, pero las expresiones calculadas, SUM y conversiones intermedias requieren presupuesto de precisión/rango; no basta copiar el tipo de la columna base.

`pFactura` es `%TYPE` de Factura_General.FACTURA en Oracle, frente a varchar(50) en MSSQL; varias variables/destinos MSSQL son varchar(30). Falta el DDL Oracle de FACTURA_GENERAL para validar el tamaño original. El procedimiento Oracle también declara referencias locales de 30 caracteres.

Los campos fecha de cursor Oracle son DATE; las variables MSSQL son datetime y las tablas locales incluyen datetime2(0). Considerar el dominio de fechas admitido además del formato, especialmente fechas anteriores a 1753. No se observó un caso de datos que lo active.

La función Oracle `FN_NUM_TO_CHAR_CFDI` sí está disponible: aplica NVL(pValue,0), conserva al menos dos fracciones si el valor no es entero y admite más si se solicitan. Por tanto, **Oracle formatea NULL como cero dentro de esa función**; el NULL como vacío solicitado corresponde a concatenación, no autoriza cambiar automáticamente ese contrato numérico. No se encontró su implementación MSSQL de producción para compararla. Hay que comprobar NULL, cero, decimales, seis posiciones de tasa y valores negativos antes de certificar el payload.

## 4. Prioridad y validación de paridad

1. Corregir concatenaciones y C05/C02, preservando posiciones vacías. No introducir pedidos antes vacíos como parte silenciosa de esa corrección.
2. Revisar LEFT JOIN de UsoC y cardinalidad del cliente: factura con configuración ausente, cliente inexistente y múltiples vigencias coincidentes.
3. Comparar importes de nueve/diez dígitos positivos y negativos, tasas y cantidades; comprobar que no aparecen `#`/`*` y que la escala por segmento coincide.
4. Comparar FePedido, FeNotaEnt y FecPedimento con 2026-11-09 y hora 13:14:15: fecha esperada `09112026`, fecha-hora `09112026131415`.
5. Simular fallo del INSERT de AJUSTE en un entorno aislado y verificar escrituras/log conforme al contrato transaccional acordado.
6. Comparar por segmentos, número de campos y valores entre ambos motores con la misma factura/datos. Incluir addenda SI/NO, campos NULL/vacíos, cadenas largas, datos sin separador y configuración incompleta.

No se ejecutaron estas pruebas de integración: son criterios para la corrección posterior. Las conclusiones confirmadas corresponden al código local; los riesgos de datos y las diferencias deliberadas permanecen identificados como tales.

# Migración de EAI.CC_SALESDOC_LDR_TO_CIFRAS

El procedimiento fue reescrito desde `ORA/T3/EAI/Procedures/CC_SALESDOC_LDR_TO_CIFRAS.SQL`. Sustituye la implementación incompleta de MSSQL y conserva el nombre. El archivo utiliza `CREATE OR ALTER PROCEDURE`; ejecutarlo en la base destino instala o actualiza el procedimiento, sin ejecutarlo.

No se modificaron los BAT, el FTP ni las rutinas del comparativo de la carpeta `Venta`. Tampoco se trasladó al procedimiento la regla del cliente `53545044`: esa actualización sigue perteneciendo a `moveDailyInfo.sql`.

## Reglas implementadas

La entrada es `EAI.TAO_SALES_DOCS_LDR`. El cursor toma una foto de los cruces al abrirse, conservando su multiplicidad. La precedencia del tipo es:

1. `T3.PREVENTA_GENERAL.CLASE_FACTURA`, si está informada.
2. `T3.FACTURA_GENERAL.TIPO_DOCTO`, si está informado.
3. Equivalencias SAP: `ZF2 → C003`, `ZRE → C004`.
4. El tipo original de la carga.

| Tipo resultante | Destino |
|---|---|
| C003, C004, C005, C006, C0FX, C019 | EAI.T3R_SALES_DOCS_OLD |
| C020, C021, C022 | EAI.T3R_SALES_DOCS_LDR_MX01 |
| Los demás, incluido NULL | EAI.T3R_SALES_DOCS_OTHERS |

Un documento ya presente en la tabla comercial al abrir el cursor no se vuelve a insertar. Para producción y otros se conserva el `UPDATE DOC_QTY=DOC_QTY+0` y, si no encuentra filas, se inserta. El UPDATE aparentemente redundante permanece porque puede activar triggers.

Sin factura de preventa, las referencias se intercambian: REF1 destino toma REF2 entrada, y REF2 destino toma REF1 entrada. Cuando existe factura de preventa, REF1 destino toma REF1 entrada y REF2 destino toma la factura de preventa.

La fase final busca documentos comerciales con estado F e impuesto cero que tengan un impuesto positivo en la carga. Actualiza impuesto y estado por número de documento, manteniendo el alcance del UPDATE original, incluso si hay varias filas destino para ese número.

## Carga parcial confirmada por el usuario

Cada documento válido se confirma de manera independiente. Si falla una conversión, longitud, restricción o escritura dentro del tratamiento de ese documento, se revierte su transacción, se registra el error en `EAI.ERROR_TABLE` y se continúa.

Si falla el registro del error, una dependencia general o la corrección final de estados, se interrumpe el procedimiento, se intenta registrar la causa en `EAI_OWNER.MX_EAI_MESSAGE_LOG` y se propaga el error. Los documentos confirmados anteriormente permanecen guardados. Si también falla el log general, se conserva la excepción original.

Los códigos de retorno son:

| Código | Significado |
|---|---|
| 0 | Terminó sin documentos rechazados. |
| 1 | Terminó con carga parcial; revisar ERROR_TABLE. |
| 2 | No inició la carga porque había una transacción externa o transacciones implícitas activadas. |

Los errores generales se propagan con `THROW`. Los códigos 1 y 2 no equivalen por sí solos a un error de ejecución de `sqlcmd`: el llamador debe capturarlos y decidir su tratamiento. La futura migración del BAT debe contemplarlo antes de archivar un archivo como completamente procesado.

Ejemplo de ejecución y evaluación explícita:

```sql
DECLARE @Resultado int;
EXEC @Resultado = EAI.CC_SALESDOC_LDR_TO_CIFRAS
    @pTruncate = 'N',
    @pOutput = 1;
SELECT @Resultado AS Resultado;
```

`@pTruncate='Y'` elimina primero los datos comerciales y de producción; **no elimina los de otros ni la entrada**. Se conserva desactivado por defecto. El vaciado de las dos tablas se confirma junto y las inserciones posteriores son parciales: no es una reconstrucción atómica del lote completo. Las transacciones externas se rechazan para no confirmarlas ni revertirlas inadvertidamente.

## Correcciones y decisiones de equivalencia

- Se restauró la lógica de inserción que faltaba en la versión MSSQL anterior.
- Se corrigió la rama de otros: obtiene `@@ROWCOUNT` de su propio UPDATE. Oracle reutilizaba el contador de otra operación y podía omitir inserciones.
- La selección de destino utiliza `IF / ELSE IF / ELSE`, eliminando la condición repetida de producción y las banderas `SI/YES`. Tener factura de preventa no fuerza por sí solo el destino comercial; se conserva la decisión efectiva por tipo.
- Se conservaron ambos controles: `LOAD CIFRAS VENTAS` y `AUTO-UPLOAD VENTAS`.
- Se califica explícitamente el esquema de las tablas para no depender del esquema predeterminado del usuario.
- No se utilizan ROWID ni el texto de UPDATE que el cursor Oracle construía pero nunca ejecutaba.
- `PROCESO_1..4` siguen recibiendo `0, NULL, 0, 0`. No se reutilizaron esas columnas para contadores nuevos sin una definición funcional.
- Los registros por documento incluyen PID en MESSAGE para facilitar su correlación. Si el distribuidor no es numérico, se registra NULL en la columna numérica de ERROR_TABLE en lugar de perder el error de origen por una segunda conversión fallida.
- Las comparaciones de tipos y estados usan intercalación binaria para conservar sus literales. Las relaciones entre claves utilizan la intercalación de las columnas de destino.
- Los importes y cantidades se redondean a los dos decimales definidos en las tablas destino. No se alteraron sus tipos ni longitudes; un valor que no cabe se registra como rechazo.

No se elimina la multiplicidad de Oracle. En particular, dos filas comerciales nuevas del mismo documento en la foto inicial pueden producir dos inserciones. Una recarga posterior las encuentra existentes y no las reinserta. Cruces múltiples en PREVENTA_GENERAL o FACTURA_GENERAL también conservan sus resultados; deben revisarse con datos reales. Cuando varias filas proponen valores diferentes para la corrección F del mismo documento, el origen no define un orden de prioridad y esta versión tampoco inventa uno.

Un bloqueo de aplicación evita ejecutar simultáneamente este procedimiento en la misma base, y las búsquedas/inserciones de producción y otros se protegen dentro de su transacción. Esto no coordina la limpieza/carga de TAO_SALES_DOCS_LDR hecha por otros procesos: el futuro BAT debe coordinar el flujo completo. El procedimiento no fuerza índices ni desactiva triggers.

## Dependencias

- Entrada/destinos: `EAI.TAO_SALES_DOCS_LDR`, `EAI.T3R_SALES_DOCS_OLD`, `EAI.T3R_SALES_DOCS_LDR_MX01`, `EAI.T3R_SALES_DOCS_OTHERS`.
- Referencias: `T3.PREVENTA_GENERAL`, `T3.FACTURA_GENERAL`.
- Seguimiento: `EAI.CONTROL_REPORTE`, `EAI.ERROR_TABLE`, `T3.RF_PROCESOS_LOG`, `EAI_OWNER.MX_COMPONENTS`, `EAI_OWNER.MX_EAI_MESSAGE_LOG`.
- Secuencia `EAI_OWNER.ProcessID` y procedimiento `EAI_OWNER.LOG_START`.
- Los triggers instalados en los destinos mantienen sus dependencias; las pruebas incluyen `EAI.T3R_SALES_DOCS_OLD_LOG` y `EAI.LOG_T3R_SALES_DOCS_OLD`.

La secuencia debe estar instalada y alineada con los PID ya existentes. Este archivo no la reinicia ni modifica permisos, tablas o índices.

## Validación realizada

El arnés `tests/CC_SALESDOC_LDR_TO_CIFRAS/verify.py` crea y elimina una base aislada de LocalDB, instala las definiciones reales del repositorio, LOG_START, el trigger de auditoría y el procedimiento nuevo. Python es solo una herramienta de prueba; no es un requisito operativo.

Se verificaron compilación e instalación repetida, los tres destinos, precedencia PG/FG, referencias, redondeo positivo/negativo, estado F, auditoría, controles, repetición de carga, rechazo por cliente inválido/referencia demasiado larga, continuidad de los válidos, duplicados comerciales, vaciado opcional, entrada vacía, parámetros NULL, opciones de cursor del llamador, protección de transacciones externas, registro y propagación de errores generales y rechazo de ejecución concurrente.

No se desplegó ni ejecutó en T3QA. No hay comparación de ejecución contra Oracle ni medición con el volumen operativo; la equivalencia se evaluó desde su código y mediante los casos de prueba.

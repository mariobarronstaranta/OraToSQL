# Incorporacion de ROW_ID en MX_EAI_MESSAGE_LOG

## Resumen

Durante la migracion de Oracle a SQL Server se identifico que varios procedimientos Oracle usan el pseudocampo fisico `ROWID` de `EAI_OWNER.MX_EAI_MESSAGE_LOG` para localizar una fila especifica despues de materializar un cursor.

La tabla migrada `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` no tenia inicialmente una llave equivalente. Por esa razon, algunas conversiones T-SQL tuvieron que relacionar las filas mediante combinaciones de columnas como `ID`, `CREATED` y `MESSAGE`, repetir los filtros funcionales del cursor o generar tokens temporales con `NEWID()`.

Estas alternativas permitian conservar el flujo general, pero no garantizaban identificar una sola fila cuando existian registros con los mismos valores funcionales.

## Problema identificado

En Oracle, un patron comun era:

```sql
SELECT Err.ROWID AS Err_RowID
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG Err;

UPDATE EAI_OWNER.MX_EAI_MESSAGE_LOG
SET Status = 'Reprocess'
WHERE ROWID = Inv.Err_RowID;
```

`ROWID` identifica directamente la fila fisica seleccionada por el cursor. SQL Server no proporciona un pseudocampo equivalente.

Antes de incorporar una llave propia, las conversiones utilizaban estrategias como:

- Volver a filtrar por cola, estado, direccion y fecha.
- Relacionar mediante `ID + CREATED`.
- Relacionar mediante `ID + CREATED + MESSAGE`.
- Usar bloqueos para mantener estable el conjunto entre el `SELECT` y el `UPDATE`.
- Generar un token temporal con `NEWID()` para distinguir filas durante una ejecucion.

El principal riesgo era afectar mas de una fila cuando dos mensajes compartieran los mismos valores funcionales.

## Solucion acordada

Se acordo agregar una columna numerica estable a la tabla SQL Server:

```sql
[EAI_OWNER].[MX_EAI_MESSAGE_LOG].[ROW_ID] BIGINT NOT NULL
```

El valor se genera mediante:

```sql
[EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ]
```

La solucion incluye:

- Secuencia `BIGINT`, iniciada en `1` e incrementada en `1`.
- Restriccion `DEFAULT` con `NEXT VALUE FOR` para nuevos registros.
- Asignacion de valores a los registros existentes.
- Columna `ROW_ID` obligatoria despues de completar la carga inicial.
- Indice unico `UX_MX_EAI_MESSAGE_LOG_ROW_ID`.
- Validaciones para permitir la ejecucion repetida del script sin recrear objetos existentes.

El script se encuentra en:

```text
MSSQL/T3/EAI_OWNER/Tables/ALTER_MX_EAI_MESSAGE_LOG_ADD_ROW_ID.SQL
```

## Correccion realizada al script DDL

La primera version del script generaba el siguiente error al ejecutarse:

```text
Msg 207, Level 16, State 1
Invalid column name 'ROW_ID'.
```

SQL Server compilaba el lote completo antes de ejecutar el `ALTER TABLE`. El `UPDATE` que utilizaba `ROW_ID` era validado cuando la columna todavia no existia.

La correccion consistio en ejecutar mediante `sys.sp_executesql` las sentencias que dependen de la columna nueva:

- `ALTER TABLE ... ADD ROW_ID`.
- Creacion del `DEFAULT`.
- Actualizacion de registros existentes.
- Cambio a `NOT NULL`.
- Creacion del indice unico.

De esta manera, cada sentencia se compila despues de que el objeto requerido ya existe.

## Criterio de conversion adoptado

El nuevo `MX_EAI_MESSAGE_LOG.ROW_ID` sustituye exclusivamente al `ROWID` fisico de Oracle utilizado para identificar la fila origen.

No debe confundirse con `MX_RECEIVE_MESSAGE_LOG.Row_ID`, que es un identificador logico de mensaje y conserva su formato existente de texto. Los procedimientos pueden seguir generando ese identificador mediante fecha, consecutivo o GUID.

La convencion aplicada en los procedimientos es:

```sql
/* Cambio homologado ROW_ID: materializar la llave de cada fila origen. */
SELECT
    Source_ROW_ID = Err.ROW_ID,
    ...
FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err;

/* Cambio homologado ROW_ID: actualizar solo las filas materializadas. */
UPDATE Err
SET Err.Status = 'Reprocess'
FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
INNER JOIN @Mensajes AS M
    ON M.Source_ROW_ID = Err.ROW_ID;
```

Para las purgas, primero se materializan los `ROW_ID` que cumplen las relaciones de negocio y despues se elimina exclusivamente mediante esa llave.

## Procedimientos de reproceso modificados

Los siguientes procedimientos materializan `MX_EAI_MESSAGE_LOG.ROW_ID` como `Source_ROW_ID BIGINT` y actualizan la fila origen mediante esa llave:

| Procedimiento | Ajuste principal |
| --- | --- |
| `WA_ERR_CUSTOMER_AMPERSAND` | Usa `Source_ROW_ID` para actualizar el mensaje Customer original. Conserva un GUID independiente para `MX_RECEIVE_MESSAGE_LOG.Row_ID`. |
| `WA_ERR_INTERCOMPANY` | Sustituye el token temporal `NEWID()` usado para correlacionar el origen por `Source_ROW_ID`. Conserva el GUID del mensaje reprocesado. |
| `WA_ERR_INVOICE_AMPERSAND` | Sustituye la correlacion por `ID + CREATED` por una union directa con `ROW_ID`. |
| `WA_ERR_PAYMENT_AMPERSAND` | Sustituye la correlacion por `ID + CREATED + MESSAGE`; solo actualiza los tipos de documento que fueron reinsertados. |
| `WA_ERR_PRODUCT_AMPERSAND` | Sustituye la correlacion funcional por una union directa con `ROW_ID`. |
| `WA_ERR_REPLENISHMENT_LARGE` | Sustituye la correlacion por `ID + CREATED + MESSAGE` por `Source_ROW_ID`. |
| `WA_ERR_REPLENISH_AMPERSAND` | Usa `Source_ROW_ID` para actualizar el mensaje original y lo conserva como referencia textual en el log de error. |

## Procedimientos de depuracion modificados

### WA_PURGE_MX_EAI_MESSAGE_LOG

El procedimiento conserva las cinco relaciones de negocio que determinan si un mensaje puede eliminarse. La diferencia es que ahora:

1. Materializa los candidatos en `@PurgeRows`.
2. Conserva `ROW_ID` como llave primaria del conjunto.
3. Ejecuta el `DELETE` mediante `P.ROW_ID = Err.ROW_ID`.
4. Obtiene `@@ROWCOUNT` despues del `DELETE` real.

### WA_DEPURA_MESSAGE_LOG

El procedimiento reutiliza la tabla `@MessageLogRows` en ocho bloques de limpieza de `MX_EAI_MESSAGE_LOG`:

1. `ErrReceivePayment`.
2. `ErrTaOPaymentInbound`.
3. `ErrInsertingT3`.
4. `ErrBankDeposit_I`.
5. `ErrIntercompany`.
6. `ErrInvoice`.
7. `ErrReplenishment`.
8. `ErrPromptDocuments`.

Cada bloque:

1. Limpia la tabla de candidatos.
2. Materializa los `ROW_ID` que cumplen la regla de negocio.
3. Elimina de `MX_EAI_MESSAGE_LOG` uniendo por `ROW_ID`.
4. Conserva el conteo mediante `@@ROWCOUNT`.

Las limpiezas de `[T3].[RF_Error_Log]` y `[T3].[Bitacora_Error]` no fueron modificadas porque no dependen de `MX_EAI_MESSAGE_LOG.ROW_ID`.

## Objetos relacionados

### Tabla, secuencia, restriccion e indice

- Tabla: `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]`.
- Columna: `[ROW_ID] BIGINT NOT NULL`.
- Secuencia: `[EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ]`.
- Default: `[DF_MX_EAI_MESSAGE_LOG_ROW_ID]`.
- Indice unico: `[UX_MX_EAI_MESSAGE_LOG_ROW_ID]`.

### Procedimientos SQL Server modificados

```text
WA_ERR_CUSTOMER_AMPERSAND
WA_ERR_INTERCOMPANY
WA_ERR_INVOICE_AMPERSAND
WA_ERR_PAYMENT_AMPERSAND
WA_ERR_PRODUCT_AMPERSAND
WA_ERR_REPLENISHMENT_LARGE
WA_ERR_REPLENISH_AMPERSAND
WA_PURGE_MX_EAI_MESSAGE_LOG
WA_DEPURA_MESSAGE_LOG
```

### Tablas relacionadas funcionalmente

- `[EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]`: recibe los mensajes XML corregidos; su `Row_ID` logico permanece separado.
- `[EAI_OWNER].[MX_SEND_MESSAGE_LOG]`: participa en reglas de depuracion.
- `[EAI_OWNER].[TMP_DOCUMENT_HEADER]` y `[EAI_OWNER].[tmp_Document_Header]`: determinan mensajes VanReplenishment ya procesados.
- `[T3].[FACTURA_GENERAL]` y `[T3].[Factura_General]`.
- `[T3].[PREVENTA_GENERAL]` y `[T3].[Preventa_General]`.
- `[T3].[OTROS_GENERAL]` y `[T3].[Otros_General]`.
- `[EAI_OWNER].[tmp_Account_Header]`.
- `[T3].[RF_Error_Log]` y `[T3].[Bitacora_Error]`: relacionadas con `WA_DEPURA_MESSAGE_LOG`, pero sin cambios por `ROW_ID`.

Los cambios de mayusculas y minusculas anteriores reflejan las referencias existentes en los scripts; SQL Server normalmente las considera equivalentes en bases con intercalacion no sensible a mayusculas.

## Objetos que no requieren modificacion inmediata

Con la incorporacion de los scripts T3, se identificaron 159 sentencias `INSERT`
sobre `MX_EAI_MESSAGE_LOG` en el repositorio MSSQL. Las 159 usan una lista
explicita de columnas.

Esos `INSERT` no necesitan agregar manualmente `ROW_ID`, porque el `DEFAULT` ejecuta `NEXT VALUE FOR` automaticamente.

El body Oracle `RECV_TO_SEND_V3` contiene diez `INSERT` de logging en
`MX_EAI_MESSAGE_LOG`, pero ninguno consume el pseudocampo `ROWID`. Sus homologos
pueden omitir `ROW_ID` en la lista de columnas y recibirlo mediante el default.

## Orden de despliegue

1. Ejecutar `ALTER_MX_EAI_MESSAGE_LOG_ADD_ROW_ID.SQL`.
2. Verificar columna, secuencia, default e indice unico.
3. Compilar los siete procedimientos de reproceso.
4. Compilar `WA_PURGE_MX_EAI_MESSAGE_LOG`.
5. Compilar `WA_DEPURA_MESSAGE_LOG`.
6. Ejecutar pruebas funcionales y de concurrencia.

Los nueve procedimientos modificados dependen de que la columna `ROW_ID` ya exista.

## Consultas de validacion sugeridas

```sql
-- No deben existir valores nulos.
SELECT COUNT(*) AS RowIdNulos
FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
WHERE [ROW_ID] IS NULL;

-- No deben existir duplicados.
SELECT [ROW_ID], COUNT(*) AS Repeticiones
FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
GROUP BY [ROW_ID]
HAVING COUNT(*) > 1;

-- Validar que nuevos INSERT reciben un ROW_ID automaticamente.
SELECT TOP (20)
    [ROW_ID],
    [CREATED],
    [QUEUE_NAME],
    [STATUS]
FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
ORDER BY [ROW_ID] DESC;
```

## Pruebas funcionales recomendadas

- Insertar dos mensajes con el mismo `ID`, `CREATED`, `MESSAGE`, cola y estado, pero diferentes `ROW_ID`; comprobar que ambos se materializan como filas independientes y que ninguna fila no materializada es modificada.
- Ejecutar cada procedimiento sin candidatos y comprobar que termina sin errores.
- Provocar un XML invalido despues del saneamiento y validar el contrato de transaccion y logging del procedimiento.
- Confirmar que el `Row_ID` insertado en `MX_RECEIVE_MESSAGE_LOG` conserva el formato esperado por los consumidores existentes.
- Ejecutar dos sesiones concurrentes de un procedimiento de reproceso y comprobar que una fila origen no se procesa dos veces.
- Validar que las purgas eliminan el mismo conjunto funcional que Oracle y que `@@ROWCOUNT` registra la cantidad real.

## Estado de validacion

Los cambios fueron revisados mediante validaciones estaticas:

- Presencia de `Source_ROW_ID` en los siete procedimientos de reproceso.
- Uniones directas mediante `Source_ROW_ID = Err.ROW_ID`.
- Ocho materializaciones y ocho eliminaciones por `ROW_ID` en `WA_DEPURA_MESSAGE_LOG`.
- Una materializacion y una eliminacion por `ROW_ID` en `WA_PURGE_MX_EAI_MESSAGE_LOG`.
- Ausencia de las correlaciones anteriores por `Source_ID`, `SourceCreated`, `SourceMessage` y `SourceToken` en los procedimientos ajustados.
- Validacion de formato mediante `git diff --check`.

Queda pendiente validar la compilacion y ejecucion en una instancia SQL Server con datos controlados.

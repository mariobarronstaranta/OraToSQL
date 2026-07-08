# Reglas de conversion Oracle a SQL Server

Este documento resume las convenciones usadas en las conversiones del proyecto. Debe usarse junto con el archivo Oracle original y el equivalente en `MSSQL`.

## Convenciones de archivos y schemas

- Origen Oracle: `ORA/T3/<SCHEMA>/<Tipo>/<Objeto>.SQL`.
- Destino SQL Server: `MSSQL/T3/<SCHEMA>/<Tipo>/<Objeto>.SQL`.
- Los objetos Oracle bajo `ORA/T3/EAI/Procedures` deben generarse normalmente como `[EAI].[NombreObjeto]`.
- Las funciones Oracle bajo `ORA/T3/EAI_OWNER/Functions` deben generarse normalmente como `[EAI_OWNER].[NombreObjeto]` y mantener el mismo nombre de archivo en `MSSQL/T3/EAI_OWNER/Functions`.
- Evitar `dbo` salvo que exista una razon funcional documentada.
- Usar nombres calificados y con corchetes: `[EAI].[Tabla]`, `[EAI_OWNER].[Objeto]`, `[T3].[Tabla]`.

## Equivalencias comunes

| Oracle | SQL Server |
| --- | --- |
| `SYSDATE` | `GETDATE()` o `SYSDATETIME()` |
| `NVL(a, b)` | `ISNULL(a, b)` o `COALESCE(a, b)` |
| `DECODE` | `CASE` |
| `TO_CHAR(fecha, formato)` | `CONVERT` o `FORMAT`, segun el caso |
| `TO_DATE(texto, formato)` | `TRY_CONVERT` o `CONVERT`, segun el caso |
| `sequence.NEXTVAL` | `NEXT VALUE FOR [schema].[sequence]` |
| Outer join `(+)` | `LEFT JOIN` |
| `DBMS_OUTPUT.PUT_LINE` | `PRINT` |
| `EXCEPTION WHEN OTHERS` | `BEGIN TRY / BEGIN CATCH` |

## Funciones escalares

- Usar `CREATE OR ALTER FUNCTION [schema].[NombreFuncion]`.
- No usar `TRY/CATCH`, SQL dinamico, tablas temporales ni operaciones con efectos secundarios dentro de funciones escalares T-SQL.
- Cuando Oracle usa `EXCEPTION WHEN OTHERS` en una funcion, emular el comportamiento con validaciones previas y retornos conservadores.
- Preferir reemplazar cursores de solo lectura por `SELECT`, `EXISTS`, `JOIN` o agregados.
- Cuidar semantica de `NULL`: en Oracle `''` se trata como `NULL`, mientras SQL Server distingue cadena vacia de `NULL`.
- Si Oracle usa `ROWID`, validar si la tabla SQL Server conserva una columna equivalente. Si no existe, documentar el identificador usado como sustituto.

## Logging de procesos

Cuando el Oracle original usa:

```sql
nPID := EAI_Owner.ProcessID.NextVal;
EAI_Owner.Log_Start(nProceso);
INSERT INTO T3.RF_PROCESOS_LOG (...);
```

La conversion recomendada es:

```sql
SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];
EXEC [EAI_OWNER].[Log_Start] @nProceso;

INSERT INTO [T3].[RF_PROCESOS_LOG]
(
    PID,
    Proceso,
    Fecha_Proc_BATMD,
    Inicio
)
VALUES
(
    @nPID,
    @nProceso,
    NULL,
    SYSDATETIME()
);
```

Importante: usar siempre `[T3].[RF_PROCESOS_LOG]` como tabla. Evitar referencias ambiguas que SQL Server pueda interpretar como llamada a procedimiento.

## Logging de errores

Usar `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` cuando el origen registre errores de proceso. La forma recomendada es:

```sql
BEGIN CATCH
    SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
    SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 1, 250);

    INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
    (
        DIRECTION,
        REFERENCE,
        CREATED,
        MESSAGE,
        JOB_PID,
        STATUS,
        QUEUE_NAME,
        SIEBEL_ERROR_MESSAGE,
        SOURCE,
        SIEBEL_ERROR_CODE,
        RETRY_COUNT,
        SEQUENCE,
        PARENT_ROW_ID
    )
    VALUES
    (
        'Job Logging',
        @v_ID,
        GETDATE(),
        NULL,
        @nPID,
        'Error',
        '<NOMBRE_PROCEDURE>',
        @sMsg,
        'T-SQL',
        @sErrorCode,
        NULL,
        NULL,
        NULL
    );

    THROW;
END CATCH;
```

Si el procedure no genera `@nPID`, puede usarse `NULL` en `JOB_PID`, dejando documentado el motivo.

## Transacciones

- No copiar `COMMIT` de Oracle de forma directa.
- Si se usa `COMMIT TRANSACTION`, debe existir `BEGIN TRANSACTION`.
- Si el proceso solo ejecuta operaciones independientes, puede omitirse la transaccion explicita y usar `SET XACT_ABORT ON`.
- En `CATCH`, ejecutar `ROLLBACK TRANSACTION` solo si `XACT_STATE() <> 0`.

## Cursores

Cuando un cursor Oracle solo agrupa datos y actualiza una tabla por llave, preferir una conversion set-based con `UPDATE ... FROM`, `JOIN`, CTE o tabla temporal.

Mantener cursor solo si:

- Existe dependencia estricta del orden.
- Hay side effects por iteracion.
- El resultado cambia segun acumuladores no triviales.

## Reglas de validacion estatica

Despues de convertir un procedure, buscar restos de Oracle o patrones riesgosos:

```powershell
rg -n "SCOPE_IDENTITY|COMMIT|ROLLBACK|ROWID|\(\+\)|SYSDATE|NVL|TO_CHAR|TO_DATE|RAISERROR|\bdbo\.|EAI_Owner" MSSQL\T3\EAI\Procedures\<Objeto>.SQL
```

Despues de convertir una funcion, aplicar una revision equivalente sobre el archivo destino:

```powershell
rg -n "create or replace|VARCHAR2|\bNVL\b|\bDECODE\b|\bSUBSTR\b|\bINSTR\b|\bLENGTH\b|EAI_Owner|User_Jobs|:=|ELSIF|END IF" MSSQL\T3\EAI_OWNER\Functions\<Objeto>.SQL
```

Nota: `SYSDATETIME()` puede aparecer en la busqueda por contener `SYSDATE`; eso es valido en SQL Server.

## Objetos convertidos con este patron

- `SF_BITACORA_CFDI_RESUMEN`
- `SF_BITACORA_CFDI_VENTA_SF`
- `SF_CFDI_OPEN_ITEMS`
- `SF_CFDI_VENTA`
- `T3R_REPLICA_SALESDOC`
- Funciones `EAI_OWNER` bajo `ORA/T3/EAI_OWNER/Functions` convertidas a `MSSQL/T3/EAI_OWNER/Functions`.

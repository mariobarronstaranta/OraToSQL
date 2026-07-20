# Reglas de conversion Oracle a SQL Server

Este documento resume las convenciones usadas en las conversiones del proyecto. Debe usarse junto con el archivo Oracle original y el equivalente en `MSSQL`.

## Convenciones de archivos y schemas

- Origen Oracle: `ORA/T3/<SCHEMA>/<Tipo>/<Objeto>.SQL`.
- Destino SQL Server: `MSSQL/T3/<SCHEMA>/<Tipo>/<Objeto>.SQL`.
- Los objetos Oracle bajo `ORA/T3/EAI/Procedures` deben generarse normalmente como `[EAI].[NombreObjeto]`.
- Las funciones Oracle bajo `ORA/T3/EAI_OWNER/Functions` deben generarse normalmente como `[EAI_OWNER].[NombreObjeto]` y mantener el mismo nombre de archivo en `MSSQL/T3/EAI_OWNER/Functions`.
- Los procedimientos Oracle bajo `ORA/T3/EAI_OWNER/Procedures` deben generarse normalmente como `[EAI_OWNER].[NombreObjeto]` y mantener el mismo nombre de archivo en `MSSQL/T3/EAI_OWNER/Procedures`.
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

## Preservacion de semantica Oracle

- En Oracle una cadena vacia (`''`) se trata como `NULL`; SQL Server distingue ambos valores. Agregar validaciones explicitas cuando esta diferencia afecte filtros o SQL dinamico.
- `LENGTH` de Oracle cuenta espacios finales. `LEN` de SQL Server no los cuenta. Para un `VARCHAR`, puede usarse `LEN(valor + '#') - 1`; tratar `NULL` y cadena vacia por separado cuando aplique.
- No agregar `ISNULL` o `COALESCE` automaticamente a parametros. Un parametro omitido usa su valor default, pero un `NULL` enviado explicitamente puede tener otra semantica en Oracle.
- `LPAD(valor, longitud, relleno)` tambien recorta el valor cuando excede la longitud. Una conversion basada solamente en `RIGHT` puede conservar el extremo equivocado.
- Los CTE de SQL Server solo existen para la sentencia inmediatamente posterior. Si el mismo conjunto alimenta varios `INSERT` o `UPDATE`, materializarlo en una tabla temporal o variable de tabla.
- Capturar `@@ROWCOUNT` inmediatamente despues de la sentencia relevante. Para SQL dinamico, capturarlo dentro del mismo lote ejecutado por `sp_executesql`.
- Cuando una expresion devuelve `sql_variant`, por ejemplo `CONNECTIONPROPERTY`, usar `CONVERT` explicito al tipo y longitud de la columna destino.
- No introducir `DISTINCT` al reemplazar un cursor sin comprobar si Oracle genera efectos secundarios por cada fila duplicada.

## Funciones escalares

- Usar `CREATE OR ALTER FUNCTION [schema].[NombreFuncion]`.
- No usar `TRY/CATCH`, SQL dinamico, tablas temporales ni operaciones con efectos secundarios dentro de funciones escalares T-SQL.
- Cuando Oracle usa `EXCEPTION WHEN OTHERS` en una funcion, emular el comportamiento con validaciones previas y retornos conservadores.
- Preferir reemplazar cursores de solo lectura por `SELECT`, `EXISTS`, `JOIN` o agregados.
- Cuidar semantica de `NULL`: en Oracle `''` se trata como `NULL`, mientras SQL Server distingue cadena vacia de `NULL`.
- Si Oracle usa `ROWID`, validar si la tabla SQL Server conserva una columna equivalente. Si no existe, documentar el identificador usado como sustituto.
- No asumir que existe una columna `Row_ID` solo porque Oracle consulta el pseudocampo `ROWID`. Revisar el DDL SQL Server; cuando no haya llave equivalente, generar un identificador para el destino o conservar el conjunto mediante bloqueos y filtros documentados.
- Para `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]`, aplicar `MSSQL/T3/EAI_OWNER/Tables/ALTER_MX_EAI_MESSAGE_LOG_ADD_ROW_ID.SQL`: la columna `[ROW_ID]` se genera con la secuencia `[EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ]` y puede usarse como sustituto estable del `ROWID` Oracle.
- El nuevo `[EAI_OWNER].[MX_EAI_MESSAGE_LOG].[ROW_ID]` identifica exclusivamente la fila origen del log. No sustituir con ese valor el `ROW_ID` logico generado para `[EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]` salvo que exista una decision funcional especifica.
- En reprocesos, materializar `MX_EAI_MESSAGE_LOG.ROW_ID` como `Source_ROW_ID BIGINT` y relacionar el `UPDATE` o `DELETE` mediante esa llave; no reconstruir la identidad con combinaciones de `ID`, `CREATED` y `MESSAGE`.
- Identificar estos ajustes dentro del T-SQL con la etiqueta `Cambio homologado ROW_ID`: documentar la estructura que conserva las llaves, la materializacion de candidatos y el `UPDATE` o `DELETE` final por `ROW_ID`.

## Triggers

- Usar `CREATE OR ALTER TRIGGER [schema].[NombreTrigger]`.
- Convertir siempre a logica set-based con `inserted` y `deleted`; no asumir una sola fila por sentencia.
- Si el trigger Oracle es `BEFORE UPDATE`, en SQL Server usar `AFTER UPDATE` y evaluar condiciones con los valores de `inserted`.
- Cuando Oracle compara columnas con `!=`, mantener `<>` en SQL Server para conservar semantica de `NULL` (si uno de los lados es `NULL`, la condicion no se dispara).
- Cuando Oracle use `NVL(col, 0)` en comparaciones, homologar con `ISNULL(col, 0)`.
- Emparejar `inserted` y `deleted` mediante una PK o llave tecnica inmutable. Si el DDL no la ofrece, usar una clave logica sustentada por los procesos consumidores y documentar la limitacion.
- `ROW_NUMBER()` global con `ORDER BY (SELECT NULL)` no garantiza que una fila anterior corresponda con la nueva. Solo usar un ordinal dentro de cada clave logica para controlar duplicados, con un orden determinista y dejando recomendada la correccion por PK.
- No afirmar equivalencia para actualizaciones que cambien la propia clave usada en el emparejamiento: SQL Server requiere una llave inmutable compartida por `inserted` y `deleted`.

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
    SET @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
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

    -- Agregar THROW solo si el procedimiento Oracle propaga la excepcion.
END CATCH;
```

Si el procedure no genera `@nPID`, puede usarse `NULL` en `JOB_PID`, dejando documentado el motivo.

La presencia de `WHEN OTHERS` no implica por si sola que SQL Server deba ejecutar `THROW`. Si Oracle inserta el error, hace `COMMIT` y finaliza sin `RAISE`, el homologo debe terminar sin relanzar para conservar el contrato del llamador. Si Oracle no captura la excepcion o la vuelve a lanzar, usar `THROW`.

## Transacciones

- No copiar `COMMIT` de Oracle de forma directa.
- Si se usa `COMMIT TRANSACTION`, debe existir `BEGIN TRANSACTION`.
- Si el proceso solo ejecuta operaciones independientes, puede omitirse la transaccion explicita y usar `SET XACT_ABORT ON`.
- En `CATCH`, ejecutar `ROLLBACK TRANSACTION` solo si `XACT_STATE() <> 0`.
- Conservar los limites de confirmacion funcionales. Si Oracle confirma cada iteracion, una unica transaccion para todo el procedimiento puede cambiar que trabajo permanece ante un error intermedio.
- No ejecutar `ROLLBACK` en un procedimiento que no abrio su propia transaccion: podria revertir trabajo perteneciente al invocador.
- Si el bloque `EXCEPTION` Oracle registra el error y ejecuta `COMMIT`, evaluar `SET XACT_ABORT OFF`: en el `CATCH`, revertir solo si `XACT_STATE() = -1`; si el estado es `1`, registrar el error y confirmar para conservar el trabajo previo. Esta regla debe aplicarse caso por caso.

## Cursores

Cuando un cursor Oracle solo agrupa datos y actualiza una tabla por llave, preferir una conversion set-based con `UPDATE ... FROM`, `JOIN`, CTE o tabla temporal.

Mantener cursor solo si:

- Existe dependencia estricta del orden.
- Hay side effects por iteracion.
- El resultado cambia segun acumuladores no triviales.

Si un cursor T-SQL puede quedar abierto al saltar al `CATCH`, cerrarlo y liberarlo usando `CURSOR_STATUS` antes de registrar o propagar el error.

## ROWNUM sin orden explicito

Oracle no garantiza orden cuando usa `ROWNUM` sin `ORDER BY`. Al generar una secuencia equivalente con `ROW_NUMBER()`, no introducir una regla de negocio artificial; usar `ORDER BY (SELECT NULL)` y documentar que la asignacion es no determinista. Si el orden es funcionalmente importante, debe definirse y validarse como una decision separada.

## Packages Oracle

- SQL Server no tiene `PACKAGE`; convertir cada miembro en un procedimiento o
  funcion independiente dentro del schema original.
- Leer specification y body completos. Un miembro privado llamado por otro
  miembro tambien debe migrarse.
- La clausula final `END package` no representa un coordinador ejecutable.
- Convertir `schema.package.member(...)` a `[schema].[member]` y actualizar todas
  las llamadas internas, jobs y permisos.
- No agregar un prefijo al nombre publico si no fue aprobado. La carpeta
  `Package`/`Packages` conserva agrupacion visual, no namespace.
- Separar `GRANT` de la implementacion; un archivo de permisos no sustituye el
  package.
- Para database links, usar linked server/sinonimo o una interfaz acordada. No
  inventar servidor, base ni credenciales.

## Secuencias

- Calificar siempre el schema: `NEXT VALUE FOR [schema].[sequence]`.
- Comparar `START WITH` contra valores ya usados antes de crear en una base con
  datos.
- No asumir continuidad: caché, rollbacks y errores dejan huecos.
- `ORDER`, `NOORDER`, `KEEP`, `SCALE` y atributos globales Oracle no tienen
  equivalencia directa y deben documentarse.
- Los scripts idempotentes no deben reiniciar una secuencia existente.

## Indices y llaves primarias

- Mantener un archivo por indice con el mismo nombre del objeto Oracle.
- Convertir indices Oracle ordinarios a `CREATE NONCLUSTERED INDEX` y conservar
  el orden y la secuencia de las columnas.
- Convertir `CREATE UNIQUE INDEX` a `CREATE UNIQUE NONCLUSTERED INDEX` solo
  cuando el objeto represente exclusivamente un indice unico.
- No inferir una restriccion `PRIMARY KEY` por el sufijo `_PK` ni por
  `CREATE UNIQUE INDEX`. Confirmar `ALTER TABLE ... PRIMARY KEY` en el DDL de
  tablas y evitar crear dos estructuras equivalentes para la misma llave.
- Omitir opciones fisicas exclusivas de Oracle como `PCTFREE`, `INITRANS`,
  `MAXTRANS`, `STORAGE`, `COMPUTE STATISTICS`, `NOLOGGING`, `NOPARALLEL` y
  `TABLESPACE`.
- Asignar el filegroup SQL Server de acuerdo con la configuracion del destino;
  actualmente las tablas `EAI` migradas usan `[PRIMARY]`.
- Revisar el limite de bytes de la llave en SQL Server, especialmente para
  indices compuestos o columnas `VARCHAR`/`NVARCHAR` extensas.
- Los indices funcionales Oracle, por ejemplo `TO_DATE(columna, formato)` o
  `SUBSTR(columna, ...)`, requieren una columna calculada determinista e
  indexable en SQL Server, o un rediseño documentado. No trasladar la expresion
  Oracle directamente.
- Para columnas calculadas de fecha originadas por `TO_DATE(texto,
  'YYYY-MM-DD')`, usar una conversion determinista; el lote `EAI_OWNER` elimina
  guiones y aplica el estilo `112`. El estilo `23` no permite marcar como
  persistida la columna calculada en la version SQL Server validada.
- Si la suma maxima declarada de una llave compuesta supera 1,700 bytes,
  mantener como llave la columna principal y evaluar mover columnas de
  cobertura a `INCLUDE`, documentando la perdida de ordenamiento o busqueda por
  esas columnas dentro del mismo indice.
- Validar sintaxis y, cuando exista una instancia de prueba, crear el indice
  sobre el DDL real de la tabla para detectar columnas ausentes, tipos no
  indexables, duplicados en indices unicos y exceso de tamaño de llave.

## DBMS_JOB y SQL Server Agent

- Determinar pertenencia por el inventario Oracle (`PRIV_USER`/`SCHEMA_USER`),
  no por el schema del procedimiento contenido en `WHAT`.
- Convertir `WHAT` en un Step T-SQL y `INTERVAL` en un schedule exclusivo.
- Conservar el numero Oracle en `dbo.Job_Oracle_SQLAgent_Map` cuando los
  procedimientos de administracion todavía lo usan.
- `BROKEN=Y` se convierte en job deshabilitado. Durante migracion, crear todos
  deshabilitados y habilitar solo en una ventana autorizada.
- No reutilizar schedules si `JOB_INTERVAL`, `JOB_NEXT_DATE` o `JOB_NEXT_RUN`
  pueden modificarlos individualmente.
- Validar dependencias transitivas, propietario, permisos, SQL Server Agent,
  operadores y Database Mail antes de habilitar.
- Oracle puede recalcular expresiones relativas y presentar deriva; SQL Server
  Agent usa una cuadricula de calendario fija.
- Si otro codigo busca texto del package en `USER_JOBS.WHAT`, conservar una
  marca compatible en el job name o cambiar la consulta para usar el mapeo. No
  reintroducir prefijos rechazados en los stored procedures.

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

Para procedimientos `EAI_OWNER`, ejecutar tambien la validacion sobre su carpeta destino y revisar especialmente declaraciones accidentales en `dbo`:

```powershell
rg -n "create or replace|VARCHAR2|:=|ELSIF|END IF|SYSDATE|NVL|TO_CHAR|TO_DATE|\bdbo\." MSSQL\T3\EAI_OWNER\Procedures\<Objeto>.SQL
```

## Objetos convertidos con este patron

- `SF_BITACORA_CFDI_RESUMEN`
- `SF_BITACORA_CFDI_VENTA_SF`
- `SF_CFDI_OPEN_ITEMS`
- `SF_CFDI_VENTA`
- `T3R_REPLICA_SALESDOC`
- Funciones `EAI_OWNER` bajo `ORA/T3/EAI_OWNER/Functions` convertidas a `MSSQL/T3/EAI_OWNER/Functions`.

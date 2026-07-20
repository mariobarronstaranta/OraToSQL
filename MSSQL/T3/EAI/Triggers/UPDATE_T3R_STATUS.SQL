SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Objeto  : [EAI].[UPDATE_T3R_STATUS]
Origen  : ORA/T3/EAI/Triggers/UPDATE_T3R_STATUS.SQL
Evento  : UPDATE sobre [EAI].[T3R_STATUS]
Proposito:
    Guardar los valores anteriores de una fila cuando, despues de la
    actualizacion, [END_DATE] queda en NULL.

Notas de migracion:
    - Oracle ejecuta el trigger una vez por fila (FOR EACH ROW). SQL Server lo
      ejecuta una vez por sentencia; por eso se procesan todas las filas de
      las tablas logicas inserted y deleted.
    - El ALTER SESSION del trigger Oracle no se migra. La zona horaria debe
      configurarse a nivel de instancia/conexion; SYSDATETIME() conserva la
      fecha y hora local del servidor, equivalente operativo usado por el
      resto del proyecto.
    - El DDL actual no declara una PK. [PROCEDURE] se usa como clave logica
      porque los procesos actualizan el estado mediante esa columna. El
      ordinal evita multiplicar filas si existen duplicados de la clave.
      No se debe actualizar [PROCEDURE] en la misma sentencia: para admitir
      ese caso se requiere agregar una llave tecnica estable a la tabla.
*/
CREATE OR ALTER TRIGGER [EAI].[UPDATE_T3R_STATUS]
ON [EAI].[T3R_STATUS]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /*
    Se asigna un ordinal dentro de cada [PROCEDURE] para poder emparejar
    duplicados de forma set-based. En condiciones normales cada particion
    contiene una sola fila.
    */
    ;WITH PreviousRows AS
    (
        SELECT
            d.[PROCEDURE],
            d.[START_DATE],
            d.[END_DATE],
            ROW_NUMBER() OVER
            (
                PARTITION BY d.[PROCEDURE]
                ORDER BY d.[START_DATE], d.[END_DATE]
            ) AS DuplicateOrdinal
        FROM deleted AS d
    ),
    CurrentRows AS
    (
        SELECT
            i.[PROCEDURE],
            i.[START_DATE],
            i.[END_DATE],
            ROW_NUMBER() OVER
            (
                PARTITION BY i.[PROCEDURE]
                ORDER BY i.[START_DATE], i.[END_DATE]
            ) AS DuplicateOrdinal
        FROM inserted AS i
    )
    INSERT INTO [EAI].[T3R_STATUS_LOG]
    (
        [DATE_INSERT],
        [PROCEDURE],
        [START_DATE],
        [END_DATE]
    )
    SELECT
        SYSDATETIME(),
        PreviousRows.[PROCEDURE],
        PreviousRows.[START_DATE],
        PreviousRows.[END_DATE]
    FROM PreviousRows
    INNER JOIN CurrentRows
        ON
        (
            CurrentRows.[PROCEDURE] = PreviousRows.[PROCEDURE]
            OR
            (
                CurrentRows.[PROCEDURE] IS NULL
                AND PreviousRows.[PROCEDURE] IS NULL
            )
        )
        AND CurrentRows.DuplicateOrdinal = PreviousRows.DuplicateOrdinal
    WHERE CurrentRows.[END_DATE] IS NULL;
END;
GO

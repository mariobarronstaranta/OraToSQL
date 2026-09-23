/*
    Índice de soporte para EAI_OWNER.FN_GET_TAX_ISSUE.

    Factura es la columna utilizada para buscar la incidencia de IVA.
    Diferencia se incluye para que SQL Server pueda devolver el ajuste desde
    el propio índice, sin consultar nuevamente la tabla base.

    El índice NO es único porque NDC_ISSUE_IVA puede contener duplicados
    históricos. Imponer unicidad requiere primero depurar esos registros y
    corregir el proceso que alimenta la tabla.
*/
IF OBJECT_ID(N'[T3].[NDC_ISSUE_IVA]', N'U') IS NULL
    THROW 54901, 'No existe la tabla T3.NDC_ISSUE_IVA.', 1;
GO

/*
    Un índice puede cambiar el orden físico usado por una consulta sin ORDER
    BY. Por seguridad se detiene el despliegue si una factura tiene ajustes
    contradictorios. Los duplicados con la misma Diferencia no cambian el
    resultado funcional y no bloquean la creación.
*/
IF EXISTS
(
    SELECT 1
    FROM [T3].[NDC_ISSUE_IVA]
    WHERE Factura IS NOT NULL
    GROUP BY Factura
    HAVING COUNT(*) > 1
       AND MIN(ISNULL(CONVERT(DECIMAL(7,2), Diferencia), -10000.00))
           <> MAX(ISNULL(CONVERT(DECIMAL(7,2), Diferencia), -10000.00))
)
    THROW 54902, 'Existen facturas duplicadas con diferencias de IVA contradictorias. Depure los datos antes de crear el indice.', 1;
GO

/*
    No se crea otro índice si la base ya tiene uno equivalente, aunque utilice
    un nombre distinto. Factura debe ser la primera llave y Diferencia debe
    formar parte del índice como llave adicional o columna incluida.
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS IX
    WHERE IX.object_id = OBJECT_ID(N'[T3].[NDC_ISSUE_IVA]')
      AND IX.is_disabled = 0
      AND IX.is_hypothetical = 0
      AND EXISTS
      (
          SELECT 1
          FROM sys.index_columns AS IC
          INNER JOIN sys.columns AS C
              ON C.object_id = IC.object_id
             AND C.column_id = IC.column_id
          WHERE IC.object_id = IX.object_id
            AND IC.index_id = IX.index_id
            AND IC.key_ordinal = 1
            AND C.name = N'FACTURA'
      )
      AND EXISTS
      (
          SELECT 1
          FROM sys.index_columns AS IC
          INNER JOIN sys.columns AS C
              ON C.object_id = IC.object_id
             AND C.column_id = IC.column_id
          WHERE IC.object_id = IX.object_id
            AND IC.index_id = IX.index_id
            AND C.name = N'DIFERENCIA'
      )
)
BEGIN
    CREATE NONCLUSTERED INDEX [NDC_ISSUE_IVA_FACTURA_IX]
        ON [T3].[NDC_ISSUE_IVA] ([FACTURA] ASC)
        INCLUDE ([DIFERENCIA]);
END;
GO

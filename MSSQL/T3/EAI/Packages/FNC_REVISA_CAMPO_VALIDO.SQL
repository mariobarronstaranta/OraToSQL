/*
    Homologo de EAI.PKG_ENCUESTAS_MKT.FNC_REVISA_CAMPO_VALIDO.

    Dev Jr:
    - Devuelve 0 cuando el campo tiene al menos un error registrado.
    - Devuelve 1 cuando no existe un error para ese encuestado/campo.
    - En SQL Server las funciones del package se publican en el esquema EAI.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [EAI].[FNC_REVISA_CAMPO_VALIDO]
(
    @P_CAMPO        VARCHAR(120),
    @P_IDENCUESTADO DECIMAL(30, 0)
)
RETURNS DECIMAL(1, 0)
AS
BEGIN
    DECLARE @Valido DECIMAL(1, 0) = 1;

    IF EXISTS
    (
        SELECT 1
        FROM [EAI].[ENCUESTAS_CLIENTES_INVALIDAS] AS i
        INNER JOIN [EAI].[ENCUESTAS_CLIENTES_ERRORES] AS e
            ON e.[IDENCUESTA_INVALIDA] = i.[IDENCUESTA_INVALIDA]
        WHERE i.[IDENCUESTADO] = @P_IDENCUESTADO
          AND e.[CAMPO_ERROR] = @P_CAMPO
    )
        SET @Valido = 0;

    RETURN @Valido;
END;
GO

/*
    Punto de entrada equivalente al miembro principal del package Oracle.

    Dev Jr:
    - Conserva el orden del body: primero valida y despues genera/publica el reporte.
    - Los procedimientos llamados administran sus propias transacciones y bitacora.
    - La dependencia remota CEDIS se explica en README.md.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI].[PRC_EJECUTA_PROCESO_ENCUESTAS]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        EXEC [EAI].[PRC_VALIDA_ENCUESTAS];
        EXEC [EAI].[PRC_REPORTE_ENCUESTAS];
    END TRY
    BEGIN CATCH
        -- Sustituye DBMS_OUTPUT: devuelve el error al invocador/SQL Agent.
        THROW;
    END CATCH;
END;
GO

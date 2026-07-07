SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [EAI_Owner].[CHK_CREDITMEMO_ALLOC]
(
    @pReferenceID VARCHAR(99)
)
RETURNS VARCHAR(4)
AS
BEGIN
    DECLARE @sReturn         VARCHAR(4)  = 'YES';
    DECLARE @sAllocReference VARCHAR(99);
    DECLARE @nMatches        INT;

    /*
        Equivalencia Oracle:
        SELECT Doc.NombreCliente
          INTO sAllocReference
          FROM EAI_Owner.tmp_Document_Header Doc
         WHERE Doc.ReferenceID LIKE '%' || pReferenceID;

        En Oracle:
        - 0 filas  => NO_DATA_FOUND  => EXCEPTION => 'NO'
        - >1 filas => TOO_MANY_ROWS  => EXCEPTION => 'NO'

        En SQL Server una función escalar no permite TRY/CATCH,
        por eso se emula el comportamiento validando cardinalidad.
    */

    IF @pReferenceID IS NULL OR LTRIM(RTRIM(@pReferenceID)) = ''
    BEGIN
        RETURN 'NO';
    END;

    SELECT
        @nMatches = COUNT(*)
    FROM [EAI_Owner].[tmp_Document_Header] AS Doc
    WHERE Doc.ReferenceID LIKE '%' + @pReferenceID;

    IF ISNULL(@nMatches, 0) <> 1
    BEGIN
        RETURN 'NO';
    END;

    SELECT
        @sAllocReference = Doc.NombreCliente
    FROM [EAI_Owner].[tmp_Document_Header] AS Doc
    WHERE Doc.ReferenceID LIKE '%' + @pReferenceID;

    IF @sAllocReference IS NULL
    BEGIN
        RETURN 'NO';
    END;

    /*
        Equivalencia del cursor Oracle:

        CURSOR ScrAllocation IS
            SELECT Doc.ReferenceID, Doc.NombreCliente, Doc.Procesado
              FROM EAI_Owner.tmp_Document_Header Doc
             WHERE Doc.Incoterms     = 'CentralAllocation'
               AND Doc.NombreCliente = sAllocReference
               AND Doc.ReferenceID NOT LIKE '%' || pReferenceID;

        FOR Alloc IN ScrAllocation LOOP
            IF Alloc.Procesado IS NOT NULL THEN
                sReturn := 'NO';
            END IF;
        END LOOP;

        Mejora:
        No se requiere cursor. Basta saber si existe al menos un documento
        relacionado ya procesado.
    */

    IF EXISTS
    (
        SELECT 1
        FROM [EAI_Owner].[tmp_Document_Header] AS Doc
        WHERE Doc.Incoterms = 'CentralAllocation'
          AND Doc.NombreCliente = @sAllocReference
          AND Doc.ReferenceID NOT LIKE '%' + @pReferenceID
          AND Doc.Procesado IS NOT NULL
    )
    BEGIN
        SET @sReturn = 'NO';
    END;

    RETURN @sReturn;
END;
GO
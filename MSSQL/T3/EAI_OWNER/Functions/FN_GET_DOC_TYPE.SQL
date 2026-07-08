CREATE OR ALTER FUNCTION EAI_OWNER.FN_GET_DOC_TYPE
(
    @P_REFERENCE VARCHAR(100)
)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @sDocType VARCHAR(10);

    SET @sDocType =
        CASE
            WHEN @P_REFERENCE IS NULL THEN 'VD'

            -- Prefijos de 1 carácter
            WHEN LEFT(@P_REFERENCE, 1) IN ('A', 'O') THEN 'PR'

            -- Prefijos de 2 caracteres
            WHEN LEFT(@P_REFERENCE, 2) IN
                 (
                    'VP', 'DP',
                    'WO', '20',
                    -- '21', '22', -- Comentado en Oracle; no se activa sin validación de negocio.
                    '23', '24',
                    '25', '26',
                    'L2', 'H2',
                    'KA'
                 )
            THEN 'PR'

            -- Prefijos de 3 caracteres
            WHEN LEFT(@P_REFERENCE, 3) IN
                 (
                    'MAY',
                    'CHP', -- Corrección: en Oracle estaba SUBSTR(...,1,1) = 'CHP', condición imposible.
                    'KPI',
                    'QHD', 'QHI', 'QMA', 'QLT', 'QPI',
                    'T10', 'T11', 'T12', 'T13', 'T14',
                    'T15', 'T16', 'T17', 'T18', 'T19',
                    'T20', 'T21', 'T23', 'T24', 'T25',
                    'T26', 'T28', 'T29', 'T40'
                 )
            THEN 'PR'

            -- Prefijos de 4 caracteres
            WHEN LEFT(@P_REFERENCE, 4) IN
                 (
                    'DESC',
                    'CONE',
                    'TRAD',
                    'VUSE',
                    'SLMT'
                 )
            THEN 'PR'

            -- Prefijos de 5 caracteres
            WHEN LEFT(@P_REFERENCE, 5) IN
                 (
                    'DIFND',
                    'D0769',
                    'D0897',
                    'OMYFM'
                 )
            THEN 'PR'

            -- Prefijos de 6 caracteres
            WHEN LEFT(@P_REFERENCE, 6) = 'MIRETO' THEN 'PR'

            ELSE 'VD'
        END;

    RETURN @sDocType;
END;
GO
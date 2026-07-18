/*
    Plantilla de configuracion para sustituir el database link Oracle @V3CEDIS.

    NO ejecutar sin reemplazar SERVIDOR_V3CEDIS y BASE_DATOS_CEDIS.
    El linked server debe ser creado por DBA conforme a las politicas de seguridad.
*/

IF SCHEMA_ID(N'CEDIS') IS NULL
    EXEC(N'CREATE SCHEMA [CEDIS] AUTHORIZATION [dbo];');
GO

-- Ejemplo, una vez configurado el linked server:
-- CREATE SYNONYM [CEDIS].[ENCUESTAS_CLIENTES_RESUMEN]
-- FOR [SERVIDOR_V3CEDIS].[BASE_DATOS_CEDIS].[CEDIS].[ENCUESTAS_CLIENTES_RESUMEN];
-- GO

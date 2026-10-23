SET NOCOUNT ON;
-- Reutiliza el procedimiento migrado sin cambiarlo ni sustituirlo por el optimizado.
-- La version desplegada debe propagar errores con THROW.
EXEC EAI.SF_BITACORA_CFDI_VENTA_SF @nEtapa = 0;

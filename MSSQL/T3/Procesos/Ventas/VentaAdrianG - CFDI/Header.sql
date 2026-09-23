:ON ERROR EXIT
-- Ejecutado por el BAT original mediante sqlcmd. Sin cambios en tablas de negocio.
SET NOCOUNT ON;
SET XACT_ABORT ON;
:r "Extract.sql"

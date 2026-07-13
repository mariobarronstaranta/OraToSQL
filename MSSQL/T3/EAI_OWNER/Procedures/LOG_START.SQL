CREATE OR ALTER PROCEDURE EAI_OWNER.LOG_START
(
    @nComponent INT
)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE EAI_OWNER.MX_COMPONENTS
       SET Status   = 2,
           Last_Run = GETDATE()
     WHERE Component = @nComponent;

END
GO
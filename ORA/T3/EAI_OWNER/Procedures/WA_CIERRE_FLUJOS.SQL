create or replace PROCEDURE      "WA_CIERRE_FLUJOS" AS
BEGIN
   EAI_OWNER.Job_Manage( 'Suspend', 'Todos' ) ;
   COMMIT ;
END WA_CIERRE_FLUJOS ;
 
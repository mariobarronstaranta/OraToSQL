SET NOCOUNT ON;
EXEC EAI.SF_CFDI_NOTA_CREDITO 0;
IF @@TRANCOUNT<>0 THROW 51000,'Transaccion abierta despues de etapa 0.',1;
IF (SELECT COUNT(*) FROM EAI.CFDI_UUID_NOTA_CREDITO)<>2 THROW 51001,'Carga incompleta.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='NC1'
 AND Importe_Vta=116 AND Saldo_SAP=40 AND Aplica_NC=2 AND Importe_NC=30 AND Incobrable=10)
 THROW 51002,'Resultado funcional incorrecto.',1;
IF NOT EXISTS (SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE Fin IS NOT NULL AND Proceso=922)
 THROW 51003,'No se cerro la auditoria.',1;
PRINT 'OK: reconstruccion completa y auditoria';
UPDATE T3.CFDI_Cobranza SET Importe=25 WHERE Asignacion_ID='A1';
EXEC EAI.SF_CFDI_NOTA_CREDITO 10;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='NC1' AND Importe_NC=35)
 THROW 51004,'Etapa 10 no actualizo aplicaciones.',1;
EXEC EAI.SF_CFDI_NOTA_CREDITO 20;
EXEC EAI.SF_CFDI_NOTA_CREDITO NULL;
IF @@TRANCOUNT<>0 THROW 51005,'Etapas alternativas dejan una transaccion.',1;
PRINT 'OK: etapas 10, 20 y NULL';

-- Fallo en la segunda etapa: el DELETE y la nueva carga deben revertirse.
ALTER TABLE EAI.CFDI_UUID_NOTA_CREDITO ADD CONSTRAINT CK_Test_Aplicacion CHECK(Importe_NC<100);
SELECT * INTO #Before FROM EAI.CFDI_UUID_NOTA_CREDITO;
UPDATE T3.CFDI_Cobranza SET Importe=150 WHERE Asignacion_ID='A1';
DECLARE @caught int=0;
BEGIN TRY
 EXEC EAI.SF_CFDI_NOTA_CREDITO 0;
END TRY
BEGIN CATCH
 SET @caught=ERROR_NUMBER();
END CATCH;
IF @caught<>547 THROW 51006,'No se propago el error original de restriccion.',1;
IF @@TRANCOUNT<>0 THROW 51007,'Fallo deja transaccion abierta.',1;
IF EXISTS(SELECT * FROM #Before EXCEPT SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO)
 OR EXISTS(SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO EXCEPT SELECT * FROM #Before)
 THROW 51008,'No se recupero el reporte anterior.',1;
IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE SIEBEL_ERROR_CODE='SQL-547')
 THROW 51009,'No persiste el log de error.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.MX_COMPONENTS WHERE Status<>1)
 THROW 51010,'No se restauro el estado del componente.',1;
PRINT 'OK: fallo posterior al DELETE revierte el reporte y registra error';

-- El log no debe sustituir la excepcion inicial por otro error.
ALTER TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG WITH NOCHECK ADD CONSTRAINT CK_Test_Log CHECK(STATUS<>'Error');
SET @caught=0;
BEGIN TRY
 EXEC EAI.SF_CFDI_NOTA_CREDITO 0;
END TRY
BEGIN CATCH
 SET @caught=ERROR_NUMBER();
 IF ERROR_MESSAGE() NOT LIKE '%CK_Test_Aplicacion%'
  THROW 51011,'El fallo del log oculto el error original.',1;
END CATCH;
IF @caught<>547 THROW 51012,'Error original perdido.',1;
ALTER TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG DROP CONSTRAINT CK_Test_Log;
PRINT 'OK: fallo de la bitacora conserva el error original';

-- Exito anidado: el procedimiento no confirma la transaccion del llamador.
UPDATE T3.CFDI_Cobranza SET Importe=25 WHERE Asignacion_ID='A1';
BEGIN TRANSACTION;
UPDATE T3.CFDI_Cobranza SET Importe=26 WHERE Asignacion_ID='A1';
EXEC EAI.SF_CFDI_NOTA_CREDITO 0;
IF @@TRANCOUNT<>1 THROW 51013,'Se confirmo la transaccion externa.',1;
ROLLBACK TRANSACTION;
IF EXISTS(SELECT * FROM #Before EXCEPT SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO)
 THROW 51014,'El rollback externo no restauro el reporte.',1;
PRINT 'OK: exito anidado respeta rollback del llamador';

-- Error anidado con transaccion condenada: el llamador debe revertirla.
BEGIN TRANSACTION;
UPDATE T3.CFDI_Cobranza SET Importe=150 WHERE Asignacion_ID='A1';
SET @caught=0;
BEGIN TRY
 EXEC EAI.SF_CFDI_NOTA_CREDITO 0;
END TRY
BEGIN CATCH
 SET @caught=ERROR_NUMBER();
 IF XACT_STATE()<>-1 THROW 51015,'Estado externo inesperado.',1;
END CATCH;
IF @caught<>547 THROW 51016,'No se propago el fallo anidado.',1;
ROLLBACK TRANSACTION;
IF EXISTS(SELECT * FROM #Before EXCEPT SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO)
 THROW 51017,'Rollback anidado incompleto.',1;
PRINT 'OK: fallo anidado preserva la responsabilidad del llamador';
GO

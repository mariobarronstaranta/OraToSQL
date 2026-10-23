CREATE PROCEDURE dbo.Assert3930 @Corregido bit
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Names TABLE(Id int,Nombre nvarchar(128));
 INSERT @Names VALUES(1,N'EAI_OWNER.INVOICE_TO_PREVENTA'),(2,N'EAI_OWNER.INVOICE_TO_FACTURA'),
 (3,N'EAI_OWNER.INVOICE_TO_ENTREGA_PO'),(4,N'T3.DELIVERY_WA_OXXO');
 DECLARE @i int=1,@Name nvarchar(128),@SQL nvarchar(max),@Error int,@Estado int,
         @Cuenta int,@Proc sysname,@Esperado int;
 WHILE @i<=4
 BEGIN
  SELECT @Name=Nombre FROM @Names WHERE Id=@i;
  SET @SQL=N'EXEC '+@Name+N' @Caso=@C;';
  DELETE dbo.CheckData; DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG;
  SET @Error=0;
  BEGIN TRY
   BEGIN TRANSACTION;
   EXEC sys.sp_executesql @SQL,N'@C int',@C=1;
  END TRY
  BEGIN CATCH
   SELECT @Error=ERROR_NUMBER(),@Estado=XACT_STATE(),@Cuenta=@@TRANCOUNT,@Proc=ERROR_PROCEDURE();
   IF XACT_STATE()<>0 ROLLBACK;
  END CATCH;
  SET @Esperado=IIF(@Corregido=1,547,3930);
  IF @Error<>@Esperado OR @Estado<>-1 OR @Cuenta<>1
   THROW 51801,'Error/estado inesperado con transaccion invalidada',1;
  IF @Corregido=1 AND PARSENAME(@Proc,1)<>PARSENAME(@Name,1)
   THROW 51802,'No se preservo ERROR_PROCEDURE',1;
  IF EXISTS(SELECT 1 FROM dbo.CheckData) OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
   THROW 51803,'Datos parciales tras rollback',1;
  PRINT CONCAT('PASS ',@Name,' invalidada; error=',@Error);

  IF @Corregido=1
  BEGIN
   -- Error confirmable: debe propagarse, sin consumir la transaccion externa
   -- ni escribir bitacora antes de que el llamador decida el rollback.
   SET @Error=0;
   BEGIN TRANSACTION;
   INSERT dbo.CheckData(Valor) VALUES(5);
   BEGIN TRY
    EXEC sys.sp_executesql @SQL,N'@C int',@C=2;
   END TRY
   BEGIN CATCH
    SELECT @Error=ERROR_NUMBER(),@Estado=XACT_STATE(),@Cuenta=@@TRANCOUNT;
   END CATCH;
   IF @Error<>50000 OR @Estado<>1 OR @Cuenta<>1
    THROW 51804,'Se oculto error confirmable o se altero la transaccion externa',1;
   IF (SELECT COUNT(*) FROM dbo.CheckData WHERE Valor=5)<>1
    THROW 51805,'Se perdieron cambios previos del llamador',1;
   IF EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
    THROW 51806,'El hijo escribio log dentro de transaccion externa',1;
   ROLLBACK;

   BEGIN TRANSACTION;
   EXEC sys.sp_executesql @SQL,N'@C int',@C=0;
   IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (SELECT COUNT(*) FROM dbo.CheckData)<>1
    THROW 51807,'Ruta exitosa alterada',1;
   ROLLBACK;

   -- Sin transaccion: se conserva logging original (Preventa relanza;
   -- los otros procedimientos conservan su contrato de finalizar tras log).
   SET @Error=0;
   BEGIN TRY
    EXEC sys.sp_executesql @SQL,N'@C int',@C=1;
   END TRY
   BEGIN CATCH
    SET @Error=ERROR_NUMBER();
   END CATCH;
   IF @@TRANCOUNT<>0 OR (SELECT COUNT(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)<>1
    THROW 51808,'Contrato sin transaccion alterado',1;
   IF (@i=1 AND @Error<>547) OR (@i<>1 AND @Error<>0)
    THROW 51809,'Propagacion sin transaccion alterada',1;
   DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG;
   PRINT CONCAT('PASS ',@Name,' confirmable, exito y llamada directa');
  END;
  SET @i+=1;
 END;
END;

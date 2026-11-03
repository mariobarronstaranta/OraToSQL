/* Revierte solo la definicion del coordinador, nunca datos ni generador.
   @Id=NULL usa el ultimo respaldo activo. No sobrescribe cambios posteriores. */
USE [T3QA]; SET NOCOUNT ON;
DECLARE @Revertir bit=0,@Id int=NULL,@Antes nvarchar(max),@Despues nvarchar(max),
        @Ansi bit,@Quoted bit,@Lock int;
IF OBJECT_ID('dbo.REPAIR_OT_GENERAL_20261029','U') IS NULL
    THROW 53860,'No existe respaldo instalado para esta correccion.',1;
IF @Id IS NULL SELECT @Id=MAX(Id) FROM dbo.REPAIR_OT_GENERAL_20261029 WHERE Reversion IS NULL;
SELECT @Antes=DefinicionAntes,@Despues=DefinicionDespues,
       @Ansi=AnsiNullsAntes,@Quoted=QuotedIdentifierAntes
FROM dbo.REPAIR_OT_GENERAL_20261029 WHERE Id=@Id AND Reversion IS NULL;
IF @Antes IS NULL THROW 53861,'No existe respaldo activo para el Id solicitado.',1;
IF @Revertir=0 BEGIN SELECT @Id Respaldo,'VISTA PREVIA; SIN REVERSION' Resultado; RETURN; END;
IF @@TRANCOUNT<>0 THROW 53862,'Ejecutar reversion sin transaccion externa.',1;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @Lock=sys.sp_getapplock @Resource='REPAIR_OT_GENERAL_20261029',
        @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
    IF @Lock<0 THROW 53863,'No se obtuvo bloqueo de reversion.',1;
    IF @Despues<>ISNULL(OBJECT_DEFINITION(OBJECT_ID('T3.PROC_T3_OT_GENERAL')),N'')
        THROW 53864,'El modulo tiene cambios posteriores; no sobrescribir.',1;
    -- OBJECT_DEFINITION puede empezar con CREATE, ALTER o CREATE OR ALTER.
    DECLARE @Pos int=CHARINDEX('PROCEDURE',UPPER(@Antes));
    IF @Pos=0 THROW 53865,'Definicion anterior no reconocida.',1;
    DECLARE @SQL nvarchar(max)=N'SET ANSI_NULLS '+CASE WHEN @Ansi=1 THEN N'ON' ELSE N'OFF' END+
        N'; SET QUOTED_IDENTIFIER '+CASE WHEN @Quoted=1 THEN N'ON' ELSE N'OFF' END+
        N'; EXEC sys.sp_executesql N'''+REPLACE(N'ALTER '+SUBSTRING(@Antes,@Pos,LEN(@Antes)),N'''',N'''''')+N''';';
    EXEC sys.sp_executesql @SQL;
    UPDATE dbo.REPAIR_OT_GENERAL_20261029 SET Reversion=SYSDATETIME() WHERE Id=@Id;
    COMMIT;
    SELECT 'DEFINICION ANTERIOR RESTAURADA; DATOS SIN CAMBIOS' Resultado,@Id Respaldo;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;

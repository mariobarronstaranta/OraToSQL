SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID('EAI_OWNER.WOT_RUN','U') IS NULL
CREATE TABLE EAI_OWNER.WOT_RUN
(
 RunId uniqueidentifier NOT NULL PRIMARY KEY,
 Started datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
 Finished datetime2(0) NULL,
 State varchar(20) NOT NULL DEFAULT 'CREATED',
 OrderRows int NULL, InvoiceRows int NULL
);
IF OBJECT_ID('EAI_OWNER.WOT_OUTPUT','U') IS NULL
CREATE TABLE EAI_OWNER.WOT_OUTPUT
(
 RunId uniqueidentifier NOT NULL,
 Days int NOT NULL,
 Seq bigint NOT NULL,
 CsvLine nvarchar(max) NOT NULL,
 CONSTRAINT PK_WOT_OUTPUT PRIMARY KEY(RunId,Days,Seq)
);
GO
CREATE OR ALTER PROCEDURE EAI_OWNER.WOT_BEGIN
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 DECLARE @id uniqueidentifier=NEWID(), @suffix varchar(32), @sql nvarchar(max);
 SET @suffix=REPLACE(CONVERT(varchar(36),@id),'-','');
 BEGIN TRY
 BEGIN TRAN;
 INSERT EAI_OWNER.WOT_RUN(RunId) VALUES(@id);
 SET @sql=N'CREATE TABLE EAI_OWNER.WOT_O_'+@suffix+N'([LineNo] bigint IDENTITY(1,1) NOT NULL, RawLine nvarchar(max) NULL);
 CREATE TABLE EAI_OWNER.WOT_I_'+@suffix+N'([LineNo] bigint IDENTITY(1,1) NOT NULL, RawLine nvarchar(max) NULL);';
 EXEC sys.sp_executesql @sql;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
 SELECT CONVERT(varchar(36),@id);
END;
GO
CREATE OR ALTER PROCEDURE EAI_OWNER.WOT_CLEANUP @RunId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.WOT_RUN WHERE RunId=@RunId)
   THROW 51000,'RunId desconocido.',1;
 DECLARE @suffix varchar(32)=REPLACE(CONVERT(varchar(36),@RunId),'-',''), @sql nvarchar(max);
 BEGIN TRY
 BEGIN TRAN;
 SET @sql=N'DROP TABLE IF EXISTS EAI_OWNER.WOT_O_'+@suffix+N'; DROP TABLE IF EXISTS EAI_OWNER.WOT_I_'+@suffix+N';';
 EXEC sys.sp_executesql @sql;
 DELETE EAI_OWNER.WOT_OUTPUT WHERE RunId=@RunId;
 UPDATE EAI_OWNER.WOT_RUN SET State=CASE WHEN State IN('READY','EXPORTED') THEN 'EXPORTED' ELSE 'CLEANED' END,
 Finished=SYSDATETIME() WHERE RunId=@RunId;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
-- CSV parser: quotes, escaped quotes, CRLF/LF and embedded newlines.
-- Returns normalized values. Any malformed record fails the entire input.
CREATE OR ALTER PROCEDURE EAI_OWNER.WOT_PARSE_CSV @Text nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @p bigint=1, @n bigint=LEN(@Text+N'#')-1, @r int=1,@c int=1,
 @q bigint,@end bigint,@comma bigint,@lf bigint,@cr bigint,@v nvarchar(max),@ch nchar(1);
 DECLARE @cells TABLE(RowNo int,ColNo int,Value nvarchar(max));
 IF LEFT(@Text,1)=NCHAR(65279) SET @p=2;
 WHILE @p<=@n
 BEGIN
   -- Empty physical records are allowed only outside quoted fields.
   IF @c=1 AND SUBSTRING(@Text,@p,1) IN(NCHAR(13),NCHAR(10))
   BEGIN
     IF SUBSTRING(@Text,@p,2)=NCHAR(13)+NCHAR(10) SET @p+=1;
     SET @p+=1;
     CONTINUE;
   END;
   SET @v=N'';
   IF SUBSTRING(@Text,@p,1)=N'"'
   BEGIN
     SET @p+=1;
     WHILE 1=1
     BEGIN
       SET @q=CHARINDEX(N'"',@Text,@p);
       IF @q=0 THROW 51001,'CSV: comillas sin cerrar.',1;
       SET @v+=SUBSTRING(@Text,@p,@q-@p);
       SET @p=@q+1;
       IF SUBSTRING(@Text,@p,1)=N'"'
       BEGIN SET @v+=N'"'; SET @p+=1; END
       ELSE BREAK;
     END;
   END
   ELSE
   BEGIN
     SET @end=@n+1;
     SET @comma=CHARINDEX(N',',@Text,@p);
     SET @lf=CHARINDEX(NCHAR(10),@Text,@p);
     SET @cr=CHARINDEX(NCHAR(13),@Text,@p);
     IF @comma>0 AND @comma<@end SET @end=@comma;
     IF @lf>0 AND @lf<@end SET @end=@lf;
     IF @cr>0 AND @cr<@end SET @end=@cr;
     SET @v=SUBSTRING(@Text,@p,@end-@p);
     IF CHARINDEX(N'"',@v)>0 THROW 51002,'CSV: comilla dentro de campo sin delimitar.',1;
     SET @p=@end;
   END;
   INSERT @cells VALUES(@r,@c,@v);
   IF @p>@n BREAK;
   SET @ch=SUBSTRING(@Text,@p,1);
   IF @ch=N','
   BEGIN
     SET @c+=1; SET @p+=1;
     IF @p>@n INSERT @cells VALUES(@r,@c,N'');
   END
   ELSE IF @ch IN(NCHAR(13),NCHAR(10))
   BEGIN
     IF SUBSTRING(@Text,@p,2)=NCHAR(13)+NCHAR(10) SET @p+=1;
     SET @p+=1; SET @r+=1; SET @c=1;
   END
   ELSE THROW 51003,'CSV: contenido despues del cierre de comillas.',1;
 END;
 SELECT RowNo,ColNo,Value FROM @cells ORDER BY RowNo,ColNo;
END;
GO

SET NOCOUNT ON;
CREATE TABLE #Probe (ReferenceID varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL);
CREATE INDEX IX_Probe ON #Probe(ReferenceID);
INSERT #Probe VALUES('123'),('000123'),('ABC'),('abc'),('ABC '),(''),(' '),('?'),(NULL),(N'é');
DECLARE @Cases table (Id int IDENTITY,Ref nvarchar(30));
INSERT @Cases VALUES(N'123'),(N'ABC'),(N'abc '),(N''),(NULL),(N'é'),(N'漢'),(N'NO_EXISTE');
DECLARE @i int=1,@ref nvarchar(30),@old int,@new int;
WHILE @i<=8
BEGIN
 SELECT @ref=Ref FROM @Cases WHERE Id=@i;
 BEGIN TRAN;
 DELETE #Probe WHERE ReferenceID=@ref;
 SET @old=@@ROWCOUNT;
 ROLLBACK;
 BEGIN TRAN;
 IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(50),@ref)))=CONVERT(varbinary(max),@ref)
 BEGIN
   DELETE #Probe WHERE ReferenceID=CONVERT(varchar(50),@ref) AND CONVERT(nvarchar(50),ReferenceID)=@ref;
   SET @new=@@ROWCOUNT;
 END
 ELSE
 BEGIN
   DELETE #Probe WHERE ReferenceID=@ref;
   SET @new=@@ROWCOUNT;
 END;
 ROLLBACK;
 IF @new<>@old THROW 51960,'Diferencia en comparacion de referencia',1;
 SET @i+=1;
END;
PRINT 'PASS: 8 casos de referencias (numeros, texto, espacios, NULL, vacios, acentos y Unicode no convertible)';

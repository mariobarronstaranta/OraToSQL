SET NOCOUNT ON;
CREATE TABLE #Base(ID int IDENTITY,ReferenceID varchar(50),Valor varchar(60));
INSERT #Base(ReferenceID,Valor) VALUES
 ('123','a'),('000123','b'),('ABC','c'),('abc','d'),('ABC ','e'),
 ('','f'),(' ','g'),('?','h'),(NULL,'i'),(NCHAR(233),'j'),(REPLICATE('X',50),'k');
CREATE TABLE #Antes(ID int,ReferenceID varchar(50),Valor varchar(60));
CREATE TABLE #Despues(ID int,ReferenceID varchar(50),Valor varchar(60));
DECLARE @Casos table(ID int IDENTITY,Ref nvarchar(50));
INSERT @Casos VALUES(N'123'),(N'ABC'),(N'abc '),(N''),(NULL),
 (NCHAR(233)),(NCHAR(28450)),(N'NO_EXISTE'),(REPLICATE(N'X',50));
DECLARE @i int=1,@op int,@ref nvarchar(50);
WHILE @i<=9
BEGIN
 SELECT @ref=Ref FROM @Casos WHERE ID=@i;
 SET @op=1;
 WHILE @op<=2
 BEGIN
  DELETE #Antes; INSERT #Antes SELECT * FROM #Base;
  DELETE #Despues; INSERT #Despues SELECT * FROM #Base;
  IF @op=1 DELETE #Antes WHERE ReferenceID=@ref;
  ELSE UPDATE #Antes SET Valor=CONCAT(Valor,'-00') WHERE ReferenceID=@ref;
  IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(50),@ref)))=CONVERT(varbinary(max),@ref)
  BEGIN
   IF @op=1 DELETE #Despues WHERE ReferenceID=CONVERT(varchar(50),@ref) AND CONVERT(nvarchar(50),ReferenceID)=@ref;
   ELSE UPDATE #Despues SET Valor=CONCAT(Valor,'-00') WHERE ReferenceID=CONVERT(varchar(50),@ref) AND CONVERT(nvarchar(50),ReferenceID)=@ref;
  END
  ELSE
  BEGIN
   IF @op=1 DELETE #Despues WHERE ReferenceID=@ref;
   ELSE UPDATE #Despues SET Valor=CONCAT(Valor,'-00') WHERE ReferenceID=@ref;
  END;
  IF EXISTS(SELECT * FROM #Antes EXCEPT SELECT * FROM #Despues)
   OR EXISTS(SELECT * FROM #Despues EXCEPT SELECT * FROM #Antes)
   THROW 51991,'Diferencia funcional en predicados',1;
  SET @op+=1;
 END;
 SET @i+=1;
END;
PRINT 'PASS: 18 comparaciones de DELETE/UPDATE, Unicode, NULL, espacios y 50 caracteres';

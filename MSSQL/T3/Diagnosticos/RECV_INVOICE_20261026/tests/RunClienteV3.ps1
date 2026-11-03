$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$package=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$server='(localdb)\MSSQLLocalDB'
$db='CodexClienteV3_'+[guid]::NewGuid().ToString('N').Substring(0,10)
$created=$false
function Sql([string]$Text) {
 ("SET NOCOUNT ON;`nGO`n"+$Text) | & sqlcmd -S $server -E -No -I -b -l 5 -d $db
 if($LASTEXITCODE -ne 0){throw 'Fallo prueba LocalDB de acceso CLIENTE_V3.'}
}
function TableDdl([string]$Path,[string]$Schema,[string]$Table) {
 $s=[IO.File]::ReadAllText((Join-Path $repo $Path))
 $m=[regex]::Match($s,'(?ims)^CREATE TABLE \['+$Schema+'\]\.\['+$Table+'\].*?^GO\s*$')
 if(-not $m.Success){throw "No se encontro DDL de $Schema.$Table"}
 Sql $m.Value
}
try {
 & sqlcmd -S $server -E -No -b -l 5 -Q "CREATE DATABASE [$db] COLLATE SQL_Latin1_General_CP1_CI_AS"
 if($LASTEXITCODE -ne 0){throw 'No fue posible crear la base temporal.'}
 $created=$true
 Sql "CREATE SCHEMA T3;`nGO`nCREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA EAI;`nGO"
 foreach($t in @('CLIENTE','DISTRIBUIDOR_FISCAL','REMISION_CTRO_SOCIEDAD')){
  TableDdl ('MSSQL/T3/T3/Tables/T3.'+$t+'.Table.sql') 'T3' $t
 }
 foreach($t in @('TAO_CEDIS_VALID','MX_EAI_MESSAGE_LOG')){
  TableDdl 'MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql' 'EAI_OWNER' $t
 }
 TableDdl 'MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql' 'EAI' 'ZSDFE_SOC'
 Sql @'
CREATE CLUSTERED INDEX IX_Prueba_RFC ON T3.CLIENTE(RFC);
CREATE UNIQUE INDEX CLIENTE_IDX1 ON T3.CLIENTE(CLIENTE_SAP,FECHA_INI_VIG,FECHA_FIN_VIG);
CREATE UNIQUE INDEX CLIENTE_PK ON T3.CLIENTE(CLIENTE_V3,FECHA_INI_VIG);
ALTER INDEX CLIENTE_PK ON T3.CLIENTE DISABLE;
;WITH D AS(SELECT N FROM(VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) V(N)),
N AS(SELECT TOP(50000) ROW_NUMBER() OVER(ORDER BY(SELECT NULL)) AS I FROM D A,D B,D C,D E,D F)
INSERT T3.CLIENTE(CLIENTE_V3,CLIENTE_SAP,NOMBRE,RFC,FECHA_INI_VIG,FECHA_FIN_VIG,
 DIRECCION_1,COLONIA_1,CIUDAD_1,ESTADO_1,PAIS_1,CODIGO_POSTAL_1)
SELECT 'V3'+RIGHT('00000000'+CONVERT(varchar(8),I),8),
 '8'+RIGHT('000000000'+CONVERT(varchar(9),I),9),'CLIENTE '+CONVERT(varchar(9),I),
 'RFC'+RIGHT('000000000'+CONVERT(varchar(9),I),9),
 DATEADD(day,-10,CONVERT(date,GETDATE())),DATEADD(day,10,CONVERT(date,GETDATE())),
 'CALLE','COLONIA','CIUDAD','ESTADO','MX','01000' FROM N;
DECLARE @hoy date=CONVERT(date,GETDATE());
INSERT T3.CLIENTE(CLIENTE_V3,CLIENTE_SAP,NOMBRE,RFC,FECHA_INI_VIG,FECHA_FIN_VIG,
 DIRECCION_1,COLONIA_1,CIUDAD_1,ESTADO_1,PAIS_1,CODIGO_POSTAL_1)
SELECT V3,SAP,Nombre,'ESPECIAL',FechaIni,FechaFin,'CALLE','COLONIA','CIUDAD','ESTADO','MX','01000'
FROM(VALUES
 ('V3_MATCH','9000000001','ALFA',DATEADD(day,-1,@hoy),DATEADD(day,1,@hoy)),
 ('SAP_MATCH','9000000002','BETA',DATEADD(day,-1,@hoy),DATEADD(day,1,@hoy)),
 ('EXPIRED_V3','9000000003','VENCIDO',DATEADD(day,-10,@hoy),DATEADD(day,-1,@hoy)),
 ('FUTURE_V3','9000000004','FUTURO',DATEADD(day,1,@hoy),DATEADD(day,10,@hoy)),
 ('NULL_VIG','9000000005','SIN VIGENCIA',NULL,DATEADD(day,1,@hoy)),
 ('C_DUP','9000000006','COPIA',DATEADD(day,-1,@hoy),DATEADD(day,1,@hoy)),
 ('C_DUP','9000000007','COPIA',DATEADD(day,-1,@hoy),DATEADD(day,1,@hoy)),
 ('HOY','9000000008','LIMITE HOY',@hoy,@hoy)
) S(V3,SAP,Nombre,FechaIni,FechaFin);
INSERT EAI_OWNER.TAO_CEDIS_VALID(SHIPTO_HUB,LOC) VALUES('0000000099','V3_MATCH');
INSERT T3.DISTRIBUIDOR_FISCAL(DISTRIBUIDOR,CTRO,DESCRIPCION,MUNICIPIO,ESTADO,PAIS)
 VALUES(1,'MX01','DISTRIBUIDOR','MUNICIPIO','ESTADO','MX');
INSERT EAI.ZSDFE_SOC(BUKRS,KUNNR,RFC,RAZON_SOCIAL) VALUES('1000','1000','SOC010101AAA','EMPRESA');
INSERT T3.REMISION_CTRO_SOCIEDAD(CTRO,SOCIEDAD,DESCRIPCION) VALUES('MX01','1000','TRANSITO');
CREATE TABLE dbo.Casos(N int PRIMARY KEY,Ctro varchar(50),NombreEsperado varchar(250));
INSERT dbo.Casos VALUES
 (1,'V3_MATCH','ALFA'),(2,'9000000002','BETA'),(3,'EXPIRED_V3',''),
 (4,'FUTURE_V3',''),(5,'NULL_VIG',''),(6,'C_DUP','COPIA'),(7,'99','ALFA'),
 (8,'MX01','EMPRESA TRANSITO'),(9,'MISSING',''),(10,NULL,''),(11,'HOY','LIMITE HOY');
CREATE TABLE dbo.Resultados(Fase char(1),N int,RFC varchar(250),Nombre varchar(250),
 Lugar varchar(250),Calle varchar(250),NoExt varchar(50),NoInt varchar(50),
 Colonia varchar(250),Municipio varchar(250),Estado varchar(250),Pais varchar(250),Codigo varchar(50));
'@
 $source=[IO.File]::ReadAllText((Join-Path $repo 'MSSQL/T3/T3/Procedures/GET_REMISION_INFO.sql'))
 $start=$source.IndexOf('CREATE PROCEDURE')
 if($start -lt 0){throw 'No se encontro la declaracion GET_REMISION_INFO.'}
 Sql ("SET ANSI_NULLS ON;`nSET QUOTED_IDENTIFIER ON;`nGO`n"+$source.Substring($start))
 Sql "CREATE TABLE dbo.DefAntes(H varbinary(32)); INSERT dbo.DefAntes SELECT HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID(N'T3.GET_REMISION_INFO')));"
 $cases=@'
DECLARE @n int=1,@c varchar(50),@a varchar(250),@b varchar(250),@c1 varchar(250),
 @d varchar(250),@e varchar(50),@f varchar(50),@g varchar(250),@h varchar(250),
 @i varchar(250),@j varchar(250),@k varchar(50);
WHILE @n<=11
BEGIN
 SELECT @c=Ctro FROM dbo.Casos WHERE N=@n;
 EXEC T3.GET_REMISION_INFO @c,'1000',@a OUTPUT,@b OUTPUT,@c1 OUTPUT,@d OUTPUT,
  @e OUTPUT,@f OUTPUT,@g OUTPUT,@h OUTPUT,@i OUTPUT,@j OUTPUT,@k OUTPUT;
 INSERT dbo.Resultados VALUES('{FASE}',@n,@a,@b,@c1,@d,@e,@f,@g,@h,@i,@j,@k);
 SET @n+=1;
END;
IF EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 THROW 52720,'GET_REMISION_INFO registro errores.',1;
IF EXISTS(SELECT 1 FROM dbo.Resultados R INNER JOIN dbo.Casos C ON C.N=R.N
 WHERE R.Fase='{FASE}' AND (R.Nombre IS NULL OR R.Nombre<>C.NombreEsperado))
 THROW 52721,'No coincide el nombre esperado del caso.',1;
'@
 $bench=@'
DECLARE @n int=0,@a varchar(250),@b varchar(250),@c varchar(250),@d varchar(250),
 @e varchar(50),@f varchar(50),@g varchar(250),@h varchar(250),@i varchar(250),
 @j varchar(250),@k varchar(50),@inicio datetime2=SYSDATETIME(),@r bigint;
SELECT @r=SUM(total_logical_reads) FROM sys.dm_exec_procedure_stats
 WHERE database_id=DB_ID() AND object_id=OBJECT_ID(N'T3.GET_REMISION_INFO');
WHILE @n<40
BEGIN
 EXEC T3.GET_REMISION_INFO 'V3_MATCH','1000',@a OUTPUT,@b OUTPUT,@c OUTPUT,@d OUTPUT,
  @e OUTPUT,@f OUTPUT,@g OUTPUT,@h OUTPUT,@i OUTPUT,@j OUTPUT,@k OUTPUT;
 SET @n+=1;
END;
SELECT '{FASE}' AS Fase,@n AS Llamadas,DATEDIFF(microsecond,@inicio,SYSDATETIME())/1000.0 AS Tiempo_ms,
 (SUM(total_logical_reads)-@r)*1.0/@n AS LecturasPorLlamada
FROM sys.dm_exec_procedure_stats WHERE database_id=DB_ID() AND object_id=OBJECT_ID(N'T3.GET_REMISION_INFO');
'@
 Sql ($cases.Replace('{FASE}','A'))
 Sql ($bench.Replace('{FASE}','A'))
 $patch=[IO.File]::ReadAllText((Join-Path $package '07_CREAR_ACCESO_CLIENTE_V3.sql')).Replace("N'T3QA'","N'$db'")
 Sql $patch
 Sql $patch
 Sql ($cases.Replace('{FASE}','B'))
 Sql ($bench.Replace('{FASE}','B'))
 Sql @'
IF EXISTS(SELECT N,RFC,Nombre,Lugar,Calle,NoExt,NoInt,Colonia,Municipio,Estado,Pais,Codigo
 FROM dbo.Resultados WHERE Fase='A'
 EXCEPT SELECT N,RFC,Nombre,Lugar,Calle,NoExt,NoInt,Colonia,Municipio,Estado,Pais,Codigo
 FROM dbo.Resultados WHERE Fase='B')
 OR EXISTS(SELECT N,RFC,Nombre,Lugar,Calle,NoExt,NoInt,Colonia,Municipio,Estado,Pais,Codigo
 FROM dbo.Resultados WHERE Fase='B'
 EXCEPT SELECT N,RFC,Nombre,Lugar,Calle,NoExt,NoInt,Colonia,Municipio,Estado,Pais,Codigo
 FROM dbo.Resultados WHERE Fase='A')
 THROW 52722,'Las once salidas no son equivalentes.',1;
IF (SELECT COUNT(*) FROM T3.CLIENTE WHERE CLIENTE_V3='C_DUP')<>2
 THROW 52723,'No se conservaron duplicados existentes.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'T3.CLIENTE')
 AND name=N'CLIENTE_PK' AND is_unique=1 AND is_disabled=1)
 THROW 52724,'Cambio el indice unico deshabilitado.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'T3.CLIENTE')
 AND name=N'IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA' AND is_unique=0 AND is_disabled=0)
 THROW 52725,'No se creo el acceso no unico.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes I INNER JOIN sys.dm_db_index_usage_stats U
 ON U.object_id=I.object_id AND U.index_id=I.index_id AND U.database_id=DB_ID()
 WHERE I.object_id=OBJECT_ID(N'T3.CLIENTE')
   AND I.name=N'IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA' AND U.user_seeks>0)
 THROW 52729,'El indice nuevo no registro busquedas de las pruebas.',1;
IF EXISTS(SELECT 1 FROM dbo.DefAntes WHERE H<>HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID(N'T3.GET_REMISION_INFO'))))
 THROW 52726,'Cambio la definicion del procedimiento.',1;
DROP INDEX IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA ON T3.CLIENTE;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'T3.CLIENTE')
 AND name=N'IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA') THROW 52727,'No se revirtio el indice nuevo.',1;
PRINT 'PASS 11 salidas GET_REMISION_INFO, duplicados, estado UNIQUE, repeticion y reversion';
'@
 # Si ya hay un acceso habilitado inicial por V3, el parche no crea otro.
 Sql 'CREATE INDEX IX_AccesoExistente ON T3.CLIENTE(CLIENTE_V3);'
 Sql $patch
 Sql "IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'T3.CLIENTE') AND name=N'IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA') THROW 52728,'Se duplico un acceso activo.',1; PRINT 'PASS acceso previo reconocido';"
} finally {
 if($created -and $db -match '^CodexClienteV3_[a-f0-9]{10}$'){
  & sqlcmd -S $server -E -No -b -l 5 -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
  if($LASTEXITCODE -ne 0){Write-Warning "Revisar limpieza de la base temporal $db"}
 }
}

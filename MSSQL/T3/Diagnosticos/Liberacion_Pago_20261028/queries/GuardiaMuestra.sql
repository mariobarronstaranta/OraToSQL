-- Solo metadatos: evitar relaciones contra tablas grandes sin un acceso
-- inicial visible. Esto no fuerza ni acredita el plan que elegira SQL Server.
DECLARE @Accesos table(Tabla nvarchar(256) COLLATE DATABASE_DEFAULT,
 Columna sysname COLLATE DATABASE_DEFAULT,Id int,FilasAprox bigint,Acceso bit);
INSERT @Accesos(Tabla,Columna) VALUES
 (N'T3.CFDI_COBRANZA',N'FECHA_ENVIO'),(N'T3.CFDI_COBRANZA',N'ASIGNACION_ID'),
 (N'T3.CFDI_DOCUMENTOS',N'NOTA_VENTA'),(N'T3.CFDI_DOCUMENTOS_ENVIAR',N'NOTA_VENTA'),
 (N'T3.MOV_CLIENTE',N'CLIENTE_SAP'),(N'T3.TMD_EMAIL',N'CLIENTE_SAP'),
 (N'T3.CFDI_USOCFDI_CLIENTE',N'CLIENTE_SAP'),(N'T3.RF_ERROR_LOG',N'REFERENCIA');
UPDATE @Accesos SET Id=OBJECT_ID(Tabla);
UPDATE A SET FilasAprox=P.N FROM @Accesos A
OUTER APPLY(SELECT SUM(row_count) AS N FROM sys.dm_db_partition_stats
 WHERE object_id=A.Id AND index_id IN(0,1)) P;
UPDATE A SET Acceso=CASE WHEN EXISTS(
 SELECT 1 FROM sys.indexes I INNER JOIN sys.index_columns IC
  ON IC.object_id=I.object_id AND IC.index_id=I.index_id
 INNER JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
 WHERE I.object_id=A.Id AND I.type IN(1,2) AND I.is_disabled=0 AND I.is_hypothetical=0
 AND I.has_filter=0 AND IC.key_ordinal=1
 AND (C.name COLLATE DATABASE_DEFAULT=A.Columna OR
 (A.Tabla=N'T3.CFDI_COBRANZA' AND A.Columna=N'FECHA_ENVIO' AND C.name=N'VIA_PAGO')))
 THEN 1 ELSE 0 END FROM @Accesos A;
SELECT '05G_ACCESOS_MUESTRA' AS Seccion,Tabla,Columna,FilasAprox,Acceso,
 CASE WHEN Acceso=1 THEN N'ACCESO DISPONIBLE; NO PLAN FORZADO'
 WHEN FilasAprox<=50000 THEN N'TABLA PEQUENA SEGUN METADATOS'
 ELSE N'REVISAR ANTES DE LEER' END AS Estado FROM @Accesos;
IF EXISTS(SELECT 1 FROM @Accesos WHERE Acceso=0 AND (FilasAprox>50000 OR FilasAprox IS NULL))
BEGIN
 SELECT '05G_DETENIDO' AS Seccion,
 N'No se continua: falta acceso inicial reconocido en una tabla grande o no se pudo estimar su tamano. Enviar metadatos; no crea indices.' AS Resultado;
 RETURN;
END;
RAISERROR(N'Modo muestra: validacion por etapas, sin calculo fiscal completo.',10,1) WITH NOWAIT;

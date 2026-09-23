-- Invocado por truncate_ldr.sql en la misma sesion sqlcmd.
-- Primero validar TODO el archivo. No vaciar tablas si falla su estructura.
SELECT REPLACE(REPLACE(LINEA,NCHAR(13),N''),NCHAR(65279),N'') Linea
INTO #LineasVenta FROM [$(StageTable)]
WHERE NULLIF(LTRIM(RTRIM(REPLACE(LINEA,NCHAR(13),N''))),N'') IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM #LineasVenta)
 THROW 51505,'Archivo vacio. No se aplicaron cambios.',1;
IF EXISTS(SELECT 1 FROM #LineasVenta WHERE CHARINDEX(N'"',Linea)>0
 OR LEN(Linea)-LEN(REPLACE(Linea,N',',N''))<>12)
 THROW 51506,'Se requieren 13 campos por coma, sin comillas ni encabezado.',1;
SELECT NULLIF(LTRIM(RTRIM(J.C0)),N'') AS DOC_ORD_R3,
       NULLIF(LTRIM(RTRIM(J.C1)),N'') AS DOC_NUM_R3,
       NULLIF(LTRIM(RTRIM(J.C2)),N'') AS CUSTOMER_NUMBER,
       NULLIF(LTRIM(RTRIM(J.C3)),N'') AS DISTRIBUTOR,
       NULLIF(LTRIM(RTRIM(J.C4)),N'') AS CUSTOMER,
       NULLIF(LTRIM(RTRIM(J.C5)),N'') AS DOC_DATE,
       NULLIF(LTRIM(RTRIM(J.C6)),N'') AS DOC_TYPE,
       NULLIF(LTRIM(RTRIM(J.C7)),N'') AS DOC_NUM_REF1,
       NULLIF(LTRIM(RTRIM(J.C8)),N'') AS DOC_NUM_REF2,
       NULLIF(LTRIM(RTRIM(J.C9)),N'') AS DOC_STATUS,
       NULLIF(LTRIM(RTRIM(J.C10)),N'') AS DOC_NETAMT,
       NULLIF(LTRIM(RTRIM(J.C11)),N'') AS DOC_TAXAMT,
       NULLIF(LTRIM(RTRIM(J.C12)),N'') AS DOC_QTY
INTO #CamposVenta
FROM #LineasVenta L
CROSS APPLY OPENJSON(N'[["'+REPLACE(STRING_ESCAPE(L.Linea,'json'),N',',N'","')+N'"]]')
WITH (C0 nvarchar(max) '$[0]',
      C1 nvarchar(max) '$[1]',
      C2 nvarchar(max) '$[2]',
      C3 nvarchar(max) '$[3]',
      C4 nvarchar(max) '$[4]',
      C5 nvarchar(max) '$[5]',
      C6 nvarchar(max) '$[6]',
      C7 nvarchar(max) '$[7]',
      C8 nvarchar(max) '$[8]',
      C9 nvarchar(max) '$[9]',
      C10 nvarchar(max) '$[10]',
      C11 nvarchar(max) '$[11]',
      C12 nvarchar(max) '$[12]') J;

-- Limites de las columnas de texto del DDL real. No truncar silenciosamente.
IF EXISTS(SELECT 1 FROM #CamposVenta C
 CROSS APPLY(VALUES (C.DOC_ORD_R3,20),(C.DOC_NUM_R3,20),(C.DISTRIBUTOR,4),
 (C.CUSTOMER,20),(C.DOC_DATE,8),(C.DOC_TYPE,4),(C.DOC_NUM_REF1,30),
 (C.DOC_NUM_REF2,30),(C.DOC_STATUS,1)) V(Valor,Limite)
 WHERE DATALENGTH(CONVERT(varchar(max),V.Valor COLLATE DATABASE_DEFAULT))>V.Limite)
 THROW 51507,'Un campo supera la longitud de la tabla de carga.',1;
IF EXISTS(SELECT 1 FROM #CamposVenta WHERE DOC_NUM_R3 IS NULL OR DOC_DATE IS NULL
 OR LEN(DOC_DATE)<>8 OR DOC_DATE COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9]%'
 OR TRY_CONVERT(date,DOC_DATE,112) IS NULL)
 THROW 51508,'Documento vacio o fecha invalida. La fecha del archivo debe ser YYYYMMDD.',1;
IF EXISTS(SELECT 1 FROM #CamposVenta WHERE CUSTOMER_NUMBER IS NOT NULL
 AND (TRY_CONVERT(decimal(10,0),CUSTOMER_NUMBER) IS NULL
 OR CUSTOMER_NUMBER COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9]%'))
 THROW 51509,'CUSTOMER_NUMBER no es un entero valido para numeric(10,0).',1;
-- Importes: punto decimal, dos decimales significativos; cantidad: tres.
-- Se conserva el rango de las mascaras TO_NUMBER del control Oracle.
IF EXISTS(SELECT 1 FROM #CamposVenta C
 CROSS APPLY(VALUES(C.DOC_NETAMT),(C.DOC_TAXAMT)) V(Valor)
 WHERE V.Valor IS NOT NULL AND (TRY_CONVERT(decimal(13,2),V.Valor) IS NULL
 OR TRY_CONVERT(decimal(38,10),V.Valor)<>TRY_CONVERT(decimal(13,2),V.Valor)
 OR ABS(TRY_CONVERT(decimal(13,2),V.Valor))>999999999.99))
 THROW 51510,'Importe invalido, fuera de rango o con mas de dos decimales.',1;
IF EXISTS(SELECT 1 FROM #CamposVenta WHERE DOC_QTY IS NOT NULL
 AND (TRY_CONVERT(decimal(13,3),DOC_QTY) IS NULL
 OR TRY_CONVERT(decimal(38,10),DOC_QTY)<>TRY_CONVERT(decimal(13,3),DOC_QTY)
 OR ABS(TRY_CONVERT(decimal(13,3),DOC_QTY))>999999999.999))
 THROW 51511,'Cantidad invalida, fuera de rango o con mas de tres decimales.',1;

BEGIN TRY
 BEGIN TRANSACTION;
 -- Mantener la autorizacion y auditoria de EXECUTE_TRUNCATE sin silenciar errores.
 IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.EAI_TRUNC_TABLE WITH(HOLDLOCK)
  WHERE UPPER(TABLE_NAME) COLLATE DATABASE_DEFAULT=N'EAI.TAO_SALES_DOCS_LDR')
  THROW 51504,'Tabla de carga no autorizada para limpieza.',1;
 TRUNCATE TABLE EAI.TAO_SALES_DOCS_LDR;
 INSERT EAI_OWNER.EAI_TRUNC_LOG(TABLE_NAME,EXECUTED,USER_SCHEMA,USER_ID,IP_ADDRESS,TERMINAL)
 VALUES('EAI.TAO_SALES_DOCS_LDR',SYSDATETIME(),LEFT(SCHEMA_NAME(),30),LEFT(SUSER_SNAME(),40),
 LEFT(CONVERT(varchar(100),CONNECTIONPROPERTY('client_net_address')),40),LEFT(HOST_NAME(),40));
 INSERT EAI.TAO_SALES_DOCS_LDR
 (DOC_ORD_R3,DOC_NUM_R3,CUSTOMER_NUMBER,DISTRIBUTOR,CUSTOMER,DOC_DATE,DOC_TYPE,
  DOC_NUM_REF1,DOC_NUM_REF2,DOC_STATUS,DOC_NETAMT,DOC_TAXAMT,DOC_QTY)
 SELECT DOC_ORD_R3,DOC_NUM_R3,CONVERT(decimal(10,0),CUSTOMER_NUMBER),DISTRIBUTOR,CUSTOMER,
  DOC_DATE,DOC_TYPE,DOC_NUM_REF1,DOC_NUM_REF2,DOC_STATUS,
  CONVERT(decimal(13,2),DOC_NETAMT),CONVERT(decimal(13,2),DOC_TAXAMT),CONVERT(decimal(13,3),DOC_QTY)
 FROM #CamposVenta;
 PRINT CONCAT('Registros cargados: ',@@ROWCOUNT);
 -- Regla original, sin filtro de fecha: afecta todo el cliente 53545044.
 UPDATE EAI.T3R_SALES_DOCS_OLD SET DOC_STATUS='D' WHERE CUSTOMER=53545044;
 PRINT CONCAT('Registros del cliente 53545044 actualizados: ',@@ROWCOUNT);
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;

-- No envolver el procedimiento en una transaccion: su carga es parcial.
-- 0 completo; 1 parcial; 2 llamada rechazada. El BAT distingue estos resultados.
CREATE TABLE #ResultadoVenta(Resultado int NOT NULL);
DECLARE @Resultado int;
EXEC @Resultado=EAI.CC_SALESDOC_LDR_TO_CIFRAS @pTruncate='N',@pOutput=1;
IF @Resultado IS NULL OR @Resultado NOT IN (0,1)
 THROW 51512,'El procedimiento rechazo la ejecucion. Revisar logs.',1;
INSERT #ResultadoVenta VALUES(@Resultado);

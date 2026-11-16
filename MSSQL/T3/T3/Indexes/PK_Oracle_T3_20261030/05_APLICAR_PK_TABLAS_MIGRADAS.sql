/* Instalador 05, basado en el 01 y resultados reales del 2026-11-05.
   @Aplicar=0: vista previa. @Aplicar=1: una transaccion por tabla.
   Omite tablas ausentes y, por defecto, las tres pendientes conocidas.
   Reemplaza SOLO indices homonimos equivalentes de configuracion simple
   validada abajo; conserva nombre, columnas, orden y filegroup PRIMARY.
   DROP INDEX + ALTER COLUMN NOT NULL + ADD PRIMARY KEY son atomicos por tabla.
   Si falla una tabla, se revierte y se detiene; las anteriores permanecen.
   No corrige datos. No modifica indices ajenos. Usar ventana sin escritores
   ni cambios de esquema: toma bloqueo exclusivo durante cada aplicacion.
   No ejecutar fragmentos del DDL propuesto fuera de este instalador.
*/
USE [T3QA];
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS(SELECT 1 FROM sys.configurations WHERE name='fill factor (%)' AND CONVERT(int,value_in_use)<>0)
    THROW 56847,'Fill factor del servidor distinto de cero: revisar configuracion fisica.',1;
DECLARE @Aplicar bit=0;
DECLARE @IncluirPendientes bit=0; -- Solo poner 1 despues de corregir sus datos.

DECLARE @SoloTabla sysname=NULL; -- Ejemplo: N'MATERIAL'. NULL = todas.
DECLARE @ConvertirColumnasANotNull bit=1;

DECLARE @Origen table(
    Tabla sysname COLLATE DATABASE_DEFAULT NOT NULL,
    NombrePK sysname COLLATE DATABASE_DEFAULT NOT NULL,
    Posicion int NOT NULL,
    Columna sysname COLLATE DATABASE_DEFAULT NOT NULL,
    PRIMARY KEY(Tabla,Posicion));
INSERT @Origen(Tabla,NombrePK,Posicion,Columna) VALUES
(N'ASIGNACION_PAGO',N'ASPAGO_PK',1,N'PAGO_ID'),
(N'ASIGNACION_PAGO',N'ASPAGO_PK',2,N'ASIGNACION_ID'),
(N'ASIGNACION_PAGO',N'ASPAGO_PK',3,N'FECHA_TRN'),
(N'ASIGNACION_PAGO',N'ASPAGO_PK',4,N'FACTURA'),
(N'ASIGNA_AGR_T3',N'ASIGRT3_PK',1,N'NUM_ID'),
(N'ASIGNA_T3',N'ASIGT3_PK',1,N'NUM_ID'),
(N'BITACORA_CARGA_T3',N'BIT_CARGA_PK',1,N'SEC_BIT'),
(N'BITACORA_EDI',N'PK_BITACORA_EDI',1,N'DISTRIBUIDOR'),
(N'BITACORA_EDI',N'PK_BITACORA_EDI',2,N'FECHA'),
(N'BITACORA_PROCESO',N'BIT_PROC_PK',1,N'SECUENCIA'),
(N'CADENAS_SAP_PASO',N'CADENAS_SAP_PASO_PK',1,N'CADENA'),
(N'CADENA_CLIENTE',N'PK_CADENA_CLIENTE',1,N'CADENA'),
(N'CADENA_CLIENTE',N'PK_CADENA_CLIENTE',2,N'CLIENTE'),
(N'CADENA_UPC',N'PK_CADENA_UPC',1,N'CADENA'),
(N'CADENA_UPC',N'PK_CADENA_UPC',2,N'UPC_CTE'),
(N'CADENA_UPC',N'PK_CADENA_UPC',3,N'UPC_SAP'),
(N'CARTERA_T3',N'CART3_PK',1,N'NUM_ID'),
(N'CC_PANTALLA',N'CC_PANTALLA_PK',1,N'PANTALLA'),
(N'CFDI_CATALOGOS_SAT',N'CFDI_CATALOGOS_SAT_PK',1,N'ID'),
(N'CLASE_CLIENTE',N'CLACLI_PK',1,N'CLASE_CLIENTE'),
(N'CLIENTE',N'CLIENTE_PK',1,N'CLIENTE_V3'),
(N'CLIENTE',N'CLIENTE_PK',2,N'FECHA_INI_VIG'),
(N'COMPRA_T3',N'COMPT_T3',1,N'NUM_MOVTO'),
(N'COMPRA_T3',N'COMPT_T3',2,N'DISTRIBUIDOR'),
(N'CONFIG_EMPRESA',N'EMPRESA_PK',1,N'EMPRESA'),
(N'CREDITO_EXPRESS',N'PK_CE',1,N'DISTRIBUIDOR'),
(N'CREDITO_EXPRESS',N'PK_CE',2,N'INICIO'),
(N'CREDITO_EXPRESS',N'PK_CE',3,N'FIN'),
(N'DEVCOMPRA_T3',N'DEVCOMPT3',1,N'NUM_MOVTO'),
(N'DEVCOMPRA_T3',N'DEVCOMPT3',2,N'DISTRIBUIDOR'),
(N'DISTRIBUIDOR_FISCAL',N'DISTRIBUIDOR_PK',1,N'DISTRIBUIDOR'),
(N'ECV_DOCS_SUM_WEEK',N'ECV_DOCS_SUM_WEEK_PK',1,N'REP'),
(N'ECV_DOCS_SUM_WEEK',N'ECV_DOCS_SUM_WEEK_PK',2,N'WEEK_ID'),
(N'ECV_DOCS_SUM_WEEK_NEW',N'ECV_DOCS_SUM_WEEK_NEW_PK',1,N'REP'),
(N'ECV_DOCS_SUM_WEEK_NEW',N'ECV_DOCS_SUM_WEEK_NEW_PK',2,N'WEEK_ID'),
(N'ENTREGA',N'ENT_PK',1,N'FACTURA'),
(N'ENTREGA',N'ENT_PK',2,N'FECHA_TRN'),
(N'ENTREGA_T3',N'ENTT3_PK',1,N'ENTREGA'),
(N'ESTADO_FISCAL',N'ESTADO_PK',1,N'ESTADO'),
(N'FACTC_AGR_T3',N'FAGRCT3_PK',1,N'FACTURA'),
(N'FACTC_AGR_T3',N'FAGRCT3_PK',2,N'NUM_LINEA'),
(N'FACTC_AGR_T3',N'FAGRCT3_PK',3,N'CLASE_COND'),
(N'FACTC_T3',N'FACCT3_PK',1,N'FACTURA'),
(N'FACTC_T3',N'FACCT3_PK',2,N'NUM_LINEA'),
(N'FACTC_T3',N'FACCT3_PK',3,N'CLASE_COND'),
(N'FACTD_AGR_T3',N'FAGRDT3_PK',1,N'FACTURA'),
(N'FACTD_AGR_T3',N'FAGRDT3_PK',2,N'NUM_LINEA'),
(N'FACTD_T3',N'FACDT3_PK',1,N'FACTURA'),
(N'FACTD_T3',N'FACDT3_PK',2,N'NUM_LINEA'),
(N'FACTURA_DETALLE',N'FACTDET_PK',1,N'FACTURA'),
(N'FACTURA_DETALLE',N'FACTDET_PK',2,N'NUM_LINEA'),
(N'FACTURA_GENERAL',N'FACTURA_PK',1,N'FACTURA'),
(N'FACT_AGR_T3',N'FAGRT3_PK',1,N'FACTURA'),
(N'FACT_T3',N'FACT3_PK',1,N'FACTURA'),
(N'IFC_CONFIG',N'PK_CONFIG',1,N'NUM_CONFIG'),
(N'IFC_FORMATOS',N'PK_FORMATO',1,N'NUM_FORMA'),
(N'IFC_FORMATO_HIST',N'PK_FORMATO_HIST',1,N'DISTRIBUIDOR'),
(N'IFC_FORMATO_HIST',N'PK_FORMATO_HIST',2,N'TIPO_VENTA'),
(N'IFC_FORMATO_HIST',N'PK_FORMATO_HIST',3,N'TIPO_FORMA'),
(N'IFC_FORMATO_HIST',N'PK_FORMATO_HIST',4,N'FECHA_INI'),
(N'IMPRESORAS',N'IMPRESORAS_PK',1,N'NUMERO_IMPRESORA'),
(N'MATERIAL',N'PRODUCTO_PK',1,N'MATERIAL'),
(N'MONITOR_CHART_CATALOG',N'MONITOR_CHART_CATALOG_PK',1,N'ID'),
(N'MOV_CLIENTE',N'MCLTE_PK',1,N'CLIENTE_V3'),
(N'MOV_CLIENTE_TERR',N'MCLTETERR_PK',1,N'CLIENTE_V3'),
(N'NOTAC_AGR_T3',N'NAGRCT3_PK',1,N'FACTURA'),
(N'NOTAC_AGR_T3',N'NAGRCT3_PK',2,N'NUM_LINEA'),
(N'NOTAC_AGR_T3',N'NAGRCT3_PK',3,N'CLASE_COND'),
(N'NOTAC_T3',N'NOTACT3_PK',1,N'FACTURA'),
(N'NOTAC_T3',N'NOTACT3_PK',2,N'NUM_LINEA'),
(N'NOTAC_T3',N'NOTACT3_PK',3,N'CLASE_COND'),
(N'NOTAD_AGR_T3',N'NAGRDT3_PK',1,N'FACTURA'),
(N'NOTAD_AGR_T3',N'NAGRDT3_PK',2,N'NUM_LINEA'),
(N'NOTAD_T3',N'NOTADT3_PK',1,N'FACTURA'),
(N'NOTAD_T3',N'NOTADT3_PK',2,N'NUM_LINEA'),
(N'NOTA_AGR_T3',N'NAGRT3_PK',1,N'FACTURA'),
(N'NOTA_POR_APLICAR',N'NOTA_POR_APL_PK',1,N'SECUENCIA_ADC'),
(N'NOTA_T3',N'NOTAT3_PK',1,N'FACTURA'),
(N'PAGO',N'PAGO_PK',1,N'PAGO_ID'),
(N'PAGO',N'PAGO_PK',2,N'FECHA_TRN'),
(N'PAGO_T3',N'PAGOT3_PK',1,N'REFERENCIA'),
(N'PASO_MATERIALES',N'PASO_MATERIALES_PK',1,N'FAMILIA'),
(N'PASO_MATERIALES',N'PASO_MATERIALES_PK',2,N'MATERIAL'),
(N'PASO_MATERIALES_FAM',N'PASO_MATERIALES_FAM_PK',1,N'FAMILIA'),
(N'PEDC_T3',N'PEDCT3_PK',1,N'DISTRIBUIDOR'),
(N'PEDC_T3',N'PEDCT3_PK',2,N'NUM_LINEA'),
(N'PEDC_T3',N'PEDCT3_PK',3,N'PEDIDO'),
(N'PEDC_T3',N'PEDCT3_PK',4,N'MATERIAL'),
(N'PEDC_T3',N'PEDCT3_PK',5,N'CLASE_COND'),
(N'PEDD_T3',N'PEDDT3_PK',1,N'DISTRIBUIDOR'),
(N'PEDD_T3',N'PEDDT3_PK',2,N'NUM_LINEA'),
(N'PEDD_T3',N'PEDDT3_PK',3,N'PEDIDO'),
(N'PEDD_T3',N'PEDDT3_PK',4,N'MATERIAL'),
(N'PED_T3',N'PEDT3_PK',1,N'DISTRIBUIDOR'),
(N'PED_T3',N'PEDT3_PK',2,N'PEDIDO'),
(N'PREVENTA_GENERAL',N'PREVG_PK',1,N'FACTURA'),
(N'REGISTRO_FISCAL',N'REGFIS_PK',1,N'FACTURA'),
(N'REGISTRO_FISCAL_DETALLE',N'REGFEDDET_PK',1,N'FACTURA'),
(N'REGISTRO_FISCAL_DETALLE',N'REGFEDDET_PK',2,N'NUM_LINEA'),
(N'REGISTRO_FISCAL_DETALLE_HIST',N'REGFEDDETHIST_PK',1,N'FACTURA'),
(N'REGISTRO_FISCAL_DETALLE_HIST',N'REGFEDDETHIST_PK',2,N'NUM_LINEA'),
(N'REGISTRO_FISCAL_HIST',N'REGFISHIST_PK',1,N'FACTURA'),
(N'REPC_CLIENTE_VENTA',N'PK_REPC_CLIENTE_VENTA',1,N'CLIENTE_SAP'),
(N'REPC_CLIENTE_VENTA',N'PK_REPC_CLIENTE_VENTA',2,N'FACTURA'),
(N'REPC_CLIENTE_VENTA',N'PK_REPC_CLIENTE_VENTA',3,N'MATERIAL'),
(N'REPC_CLIENTE_VENTA_HIST',N'REPC_CLIENTE_VENTA_HIST_PK',1,N'CLIENTE_SAP'),
(N'REPC_CLIENTE_VENTA_HIST',N'REPC_CLIENTE_VENTA_HIST_PK',2,N'FACTURA'),
(N'REPC_CLIENTE_VENTA_HIST',N'REPC_CLIENTE_VENTA_HIST_PK',3,N'NOMBRE'),
(N'REPC_FAMILIA',N'REPC_FAMILIA_PK',1,N'FAMILIA'),
(N'REPC_MATERIAL_FAMILIA',N'REPC_MATERIAL_FAMILIA_PK',1,N'MATERIAL'),
(N'RMAC_T3',N'RMACT3_PK',1,N'DISTRIBUIDOR'),
(N'RMAC_T3',N'RMACT3_PK',2,N'NUM_LINEA'),
(N'RMAC_T3',N'RMACT3_PK',3,N'PEDIDO'),
(N'RMAC_T3',N'RMACT3_PK',4,N'MATERIAL'),
(N'RMAC_T3',N'RMACT3_PK',5,N'CLASE_COND'),
(N'RMAD_T3',N'RMADT3_PK',1,N'DISTRIBUIDOR'),
(N'RMAD_T3',N'RMADT3_PK',2,N'NUM_LINEA'),
(N'RMAD_T3',N'RMADT3_PK',3,N'PEDIDO'),
(N'RMAD_T3',N'RMADT3_PK',4,N'MATERIAL'),
(N'RMA_T3',N'RMAT3_PK',1,N'DISTRIBUIDOR'),
(N'RMA_T3',N'RMAT3_PK',2,N'PEDIDO'),
(N'TIPO_DOCUMENTO',N'TIPODOC_PK',1,N'TIPO_DOCUMENTO'),
(N'USUARIOS',N'USUARIO_PK',1,N'USUARIO'),
(N'VAN_T3',N'VANT3_PK',1,N'NUM_MOVTO'),
(N'VENTA_PLANEADA',N'PK_VP',1,N'DISTRIBUIDOR'),
(N'VENTA_PLANEADA',N'PK_VP',2,N'INICIO'),
(N'VENTA_PLANEADA',N'PK_VP',3,N'FIN'),
(N'WH_PEDIDO_DETALLE',N'WH_PED_DET_IDX',1,N'COMPANIA'),
(N'WH_PEDIDO_DETALLE',N'WH_PED_DET_IDX',2,N'UNIDAD_ORG'),
(N'WH_PEDIDO_DETALLE',N'WH_PED_DET_IDX',3,N'FOLIO_PED'),
(N'WH_PEDIDO_DETALLE',N'WH_PED_DET_IDX',4,N'FECHA_PED'),
(N'WH_PEDIDO_DETALLE',N'WH_PED_DET_IDX',5,N'PRODUCTO'),
(N'WH_REGISTRO_FISCAL',N'WH_REGFIS_PK',1,N'FACTURA'),
(N'WH_REGISTRO_FISCAL_DETALLE',N'WH_REGFEDDET_PK',1,N'FACTURA'),
(N'WH_REGISTRO_FISCAL_DETALLE',N'WH_REGFEDDET_PK',2,N'NUM_LINEA'),
(N'W_BUZON_CLIENTE',N'W_BUZ_CLTE_PK',1,N'SECUENCIA_ADC'),
(N'W_IMPRIME_DOCUMENTO',N'W_IMP_DOC_PK',1,N'TIPO_IMPRESION'),
(N'W_IMPRIME_DOCUMENTO',N'W_IMP_DOC_PK',2,N'SECUENCIA'),
(N'W_MATERIAL_MAQUILA',N'W_MATERIAL_MAQUILA_PK',1,N'MATERIAL'),
(N'W_MOV_CENTRAL_ADC',N'W_MOV_CEN_PK',1,N'SECUENCIA_ADC'),
(N'W_REGISTRO_FISCAL',N'W_REGFIS_PK',1,N'FACTURA'),
(N'W_REGISTRO_FISCAL2',N'W_REGFIS2_PK',1,N'FACTURA'),
(N'W_REGISTRO_FISCAL_DETALLE',N'W_REGFEDDET_PK',1,N'FACTURA'),
(N'W_REGISTRO_FISCAL_DETALLE',N'W_REGFEDDET_PK',2,N'NUM_LINEA'),
(N'W_REGISTRO_FISCAL_DETALLE2',N'W_REGFEDDET2_PK',1,N'FACTURA'),
(N'W_REGISTRO_FISCAL_DETALLE2',N'W_REGFEDDET2_PK',2,N'NUM_LINEA');

-- Suspension posterior al incidente del 2026-11-06: tambien bloquea vista previa.
IF EXISTS(SELECT 1 FROM @Origen WHERE Tabla=N'REGISTRO_FISCAL_DETALLE'
          AND (@SoloTabla IS NULL OR @SoloTabla=Tabla))
    THROW 56992,'REGISTRO_FISCAL_DETALLE suspendida. Ejecutar 17_RFD_REVISION_POST_RECOVERY_20261107/01_ESTADO_Y_CAPACIDADES.sql. No reutilizar lote 17.',1;

IF @SoloTabla IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @Origen WHERE Tabla=@SoloTabla)
    THROW 56800,'@SoloTabla no pertenece al listado Oracle proporcionado.',1;
IF @Aplicar=1 AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2)
    THROW 56801,'Aplicar sin transaccion externa y con IMPLICIT_TRANSACTIONS OFF.',1;

SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() Captura,@Aplicar Aplicar,
       @SoloTabla SoloTabla,@ConvertirColumnasANotNull ConvertirColumnasANotNull,
       (SELECT COUNT(DISTINCT Tabla) FROM @Origen) PKEnArchivoOrigen,
       (SELECT COUNT(*) FROM @Origen) ColumnasEnArchivoOrigen;

DECLARE @Plan table(
    Id int NOT NULL PRIMARY KEY,Tabla sysname COLLATE DATABASE_DEFAULT NOT NULL,
    NombrePK sysname COLLATE DATABASE_DEFAULT NOT NULL,Columnas nvarchar(max) NULL,
    Estado varchar(40) COLLATE DATABASE_DEFAULT NOT NULL DEFAULT 'PENDIENTE',
    Observacion nvarchar(2000) NULL,ColumnasNullable int NULL,
    FilasConNull bigint NULL,GruposDuplicados bigint NULL,BytesMaximosClave int NULL,
    SQLPropuesto nvarchar(max) NULL,SQLDiagnostico nvarchar(max) NULL,Firma varbinary(32) NULL);
INSERT @Plan(Id,Tabla,NombrePK)
SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY Tabla)),Tabla,NombrePK
FROM @Origen WHERE @SoloTabla IS NULL OR Tabla=@SoloTabla GROUP BY Tabla,NombrePK;

DECLARE @Meta table(
    Posicion int NOT NULL PRIMARY KEY,Columna sysname COLLATE DATABASE_DEFAULT NOT NULL,
    TipoBase sysname COLLATE DATABASE_DEFAULT NOT NULL,TipoDDL nvarchar(400) NOT NULL,
    CollationName sysname COLLATE DATABASE_DEFAULT NULL,Nullable bit NOT NULL,
    BytesColumna int NOT NULL,NoSoportada bit NOT NULL);
DECLARE @IndiceReemplazo int,@Prefijo nvarchar(max),@Firma varbinary(32),@FirmaActual varbinary(32),@LockCount bigint;
-- Huella de columnas, indices y dependencias antes de preparar y aplicar DDL.
DECLARE @SQLFirma nvarchar(max)=N'
SELECT @F=HASHBYTES(''SHA2_256'',CONVERT(nvarchar(max),(
 SELECT
 (SELECT * FROM sys.columns WHERE object_id=@O ORDER BY column_id FOR XML PATH(''C''),TYPE),
 (SELECT * FROM sys.indexes WHERE object_id=@O ORDER BY index_id FOR XML PATH(''I''),TYPE),
 (SELECT * FROM sys.index_columns WHERE object_id=@O ORDER BY index_id,index_column_id FOR XML PATH(''IC''),TYPE),
 (SELECT index_id,partition_number,data_compression FROM sys.partitions WHERE object_id=@O ORDER BY index_id,partition_number FOR XML PATH(''P''),TYPE),
 (SELECT stats_id,no_recompute,is_incremental FROM sys.stats WHERE object_id=@O ORDER BY stats_id FOR XML PATH(''S''),TYPE),
 (SELECT * FROM sys.foreign_keys WHERE referenced_object_id=@O OR parent_object_id=@O ORDER BY object_id FOR XML PATH(''FK''),TYPE)
 FOR XML PATH(''Firma''),TYPE)));';
DECLARE @Id int,@Tabla sysname,@PK sysname,@Objeto int,@Nombre nvarchar(520),
        @Columnas nvarchar(max),@PredicadoNull nvarchar(max),@Alter nvarchar(max),
        @DDL nvarchar(max),@SQL nvarchar(max),@SQLDiagnostico nvarchar(max),
        @PKActual sysname,@ColumnasActuales nvarchar(max),@IndicePK int,
        @Nullable int,@Bytes int,@FilasNull bigint,@Duplicados bigint,
        @Error nvarchar(2000),@Orden int,@Columna sysname,@TipoDDL nvarchar(400),@Collation sysname,
        @DefAntes nvarchar(max),@DefDespues nvarchar(max);

DECLARE Claves CURSOR LOCAL STATIC READ_ONLY FOR
SELECT Id,Tabla,NombrePK FROM @Plan ORDER BY Id;
OPEN Claves;
FETCH NEXT FROM Claves INTO @Id,@Tabla,@PK;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Nombre=QUOTENAME(N'T3')+N'.'+QUOTENAME(@Tabla);
    SET @Objeto=OBJECT_ID(@Nombre,N'U');
    SELECT @Columnas=STUFF((SELECT N','+QUOTENAME(O.Columna)
        FROM @Origen O WHERE O.Tabla=@Tabla ORDER BY O.Posicion
        FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'');
    UPDATE @Plan SET Columnas=@Columnas WHERE Id=@Id;
    BEGIN TRY
        IF @Objeto IS NULL
        BEGIN
            UPDATE @Plan SET Estado='OMITIDA_NO_VISIBLE',Observacion=N'Tabla ausente/no visible; no se crea.' WHERE Id=@Id;
            FETCH NEXT FROM Claves INTO @Id,@Tabla,@PK;
            CONTINUE;
        END;
        IF @IncluirPendientes=0 AND @Tabla IN(N'CFDI_CATALOGOS_SAT',N'MOV_CLIENTE',N'USUARIOS')
        BEGIN
            UPDATE @Plan SET Estado='PENDIENTE_DATOS',Observacion=N'Excluida por resultado 04: resolver NULL/duplicados; luego @IncluirPendientes=1.' WHERE Id=@Id;
            FETCH NEXT FROM Claves INTO @Id,@Tabla,@PK;
            CONTINUE;
        END;
        EXEC sys.sp_executesql @SQLFirma,N'@O int,@F varbinary(32) OUTPUT',@O=@Objeto,@F=@Firma OUTPUT;
        UPDATE @Plan SET Firma=@Firma WHERE Id=@Id;
        DELETE @Meta;
        INSERT @Meta(Posicion,Columna,TipoBase,TipoDDL,CollationName,Nullable,BytesColumna,NoSoportada)
        SELECT O.Posicion,C.name,B.name,
            CASE WHEN U.user_type_id<>U.system_type_id THEN QUOTENAME(SCHEMA_NAME(U.schema_id))+N'.'+QUOTENAME(U.name)
                 ELSE QUOTENAME(B.name)+CASE
                   WHEN B.name IN ('varchar','char','varbinary','binary')
                     THEN N'('+CASE WHEN C.max_length=-1 THEN N'max' ELSE CONVERT(nvarchar(10),C.max_length) END+N')'
                   WHEN B.name IN ('nvarchar','nchar')
                     THEN N'('+CASE WHEN C.max_length=-1 THEN N'max' ELSE CONVERT(nvarchar(10),C.max_length/2) END+N')'
                   WHEN B.name IN ('decimal','numeric')
                     THEN N'('+CONVERT(nvarchar(10),C.precision)+N','+CONVERT(nvarchar(10),C.scale)+N')'
                   WHEN B.name IN ('datetime2','datetimeoffset','time')
                     THEN N'('+CONVERT(nvarchar(10),C.scale)+N')'
                   WHEN B.name='float' THEN N'('+CONVERT(nvarchar(10),C.precision)+N')'
                   ELSE N'' END END,
            -- Los tipos alias conservan su propia collation: SQL Server no
            -- admite una clausula COLLATE al usarlos en ALTER COLUMN.
            CASE WHEN U.user_type_id<>U.system_type_id THEN NULL ELSE C.collation_name END,
            C.is_nullable,C.max_length,
            CASE WHEN C.is_computed=1 OR C.is_sparse=1 OR C.is_column_set=1 OR C.is_filestream=1
                   OR C.generated_always_type<>0 OR C.encryption_type IS NOT NULL OR C.max_length=-1
                   OR B.name NOT IN ('varchar','char','nvarchar','nchar','varbinary','binary',
                     'decimal','numeric','bigint','int','smallint','tinyint','bit','money','smallmoney',
                     'float','real','date','datetime','smalldatetime','datetime2','datetimeoffset','time','uniqueidentifier')
                 THEN 1 ELSE 0 END
        FROM @Origen O
        JOIN sys.columns C ON C.object_id=@Objeto AND C.name COLLATE DATABASE_DEFAULT=O.Columna
        JOIN sys.types B ON B.user_type_id=C.system_type_id AND B.user_type_id=B.system_type_id
        JOIN sys.types U ON U.user_type_id=C.user_type_id
        WHERE O.Tabla=@Tabla;
        IF (SELECT COUNT(*) FROM @Meta)<>(SELECT COUNT(*) FROM @Origen WHERE Tabla=@Tabla)
            THROW 56811,'Faltan columnas de la clave Oracle o no se pudo resolver su tipo.',1;

        -- Reconocer equivalencia por columnas en el mismo orden, no solo por nombre.
        SET @PKActual=NULL;
        SET @IndicePK=NULL;
        SELECT @PKActual=K.name,@IndicePK=K.unique_index_id
        FROM sys.key_constraints K WHERE K.parent_object_id=@Objeto AND K.type='PK';
        IF @PKActual IS NOT NULL
        BEGIN
            SELECT @ColumnasActuales=STUFF((SELECT N','+QUOTENAME(C.name)
                FROM sys.index_columns IC JOIN sys.columns C
                  ON C.object_id=IC.object_id AND C.column_id=IC.column_id
                WHERE IC.object_id=@Objeto AND IC.index_id=@IndicePK AND IC.key_ordinal>0
                ORDER BY IC.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'');
            IF @ColumnasActuales COLLATE DATABASE_DEFAULT<>@Columnas COLLATE DATABASE_DEFAULT
                THROW 56812,'La tabla ya tiene una PK con columnas u orden diferentes. No se reemplaza.',1;
            IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@Objeto AND index_id=@IndicePK AND is_disabled=1)
                THROW 56813,'La PK equivalente existe pero su indice esta deshabilitado; requiere revision.',1;
            UPDATE @Plan SET Estado='YA_EXISTE_EQUIVALENTE',
                Observacion=N'PK actual: '+QUOTENAME(@PKActual)+N'. Se conserva su nombre e indice.' WHERE Id=@Id;
        END
        ELSE
        BEGIN
            IF EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Objeto AND (is_memory_optimized=1 OR is_filetable=1 OR temporal_type<>0))
                THROW 56814,'Tabla especial: no se aplica DDL automatico de PK rowstore.',1;
            IF EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.data_spaces D ON D.data_space_id=I.data_space_id
                      WHERE I.object_id=@Objeto AND I.index_id IN(0,1) AND D.type='PS')
                THROW 56815,'Tabla particionada: revisar colocacion del indice y columnas de particion.',1;
            IF EXISTS(SELECT 1 FROM @Meta WHERE NoSoportada=1)
                THROW 56816,'Tipo MAX/especial o atributo de columna no admitido por este script; revisar manualmente.',1;
            IF OBJECT_ID(QUOTENAME(N'T3')+N'.'+QUOTENAME(@PK)) IS NOT NULL
                THROW 56817,'El nombre de la restriccion ya esta ocupado por otro objeto de T3.',1;
            SET @IndiceReemplazo=NULL; SET @Prefijo=N'';
            SELECT @IndiceReemplazo=index_id FROM sys.indexes WHERE object_id=@Objeto AND name COLLATE DATABASE_DEFAULT=@PK;
            IF @IndiceReemplazo IS NOT NULL
            BEGIN
                -- Configuracion observada en 04. Cualquier diferencia exige revision.
                IF NOT EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.data_spaces DS ON DS.data_space_id=I.data_space_id
                    JOIN sys.stats S ON S.object_id=I.object_id AND S.stats_id=I.index_id
                    WHERE I.object_id=@Objeto AND I.index_id=@IndiceReemplazo
                    AND I.type=2 AND I.is_unique=1 AND I.is_primary_key=0 AND I.is_unique_constraint=0
                    AND I.is_hypothetical=0 AND I.has_filter=0 AND I.ignore_dup_key=0
                    AND I.fill_factor=0 AND I.is_padded=0 AND I.allow_row_locks=1 AND I.allow_page_locks=1
                    AND S.no_recompute=0 AND S.is_incremental=0 AND DS.type='FG' AND DS.name=N'PRIMARY')
                    THROW 56840,'Indice homonimo con propiedades distintas de las soportadas; no se reemplaza.',1;
                IF EXISTS(SELECT 1 FROM sys.index_columns WHERE object_id=@Objeto AND index_id=@IndiceReemplazo
                    AND (is_included_column=1 OR is_descending_key=1 OR partition_ordinal<>0))
                    THROW 56841,'Indice con INCLUDE, DESC o particion: revisar manualmente.',1;
                IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@Objeto AND index_id=@IndiceReemplazo
                    AND (partition_number<>1 OR data_compression<>0))
                    THROW 56842,'Indice con compresion/particionado: revisar manualmente.',1;
                IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id=@Objeto AND key_index_id=@IndiceReemplazo)
                    THROW 56843,'Hay FK referenciando el indice: no se elimina.',1;
                IF EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=7 AND major_id=@Objeto AND minor_id=@IndiceReemplazo)
                    THROW 56844,'Indice con propiedades extendidas: revisar antes de reemplazar.',1;
                SELECT @ColumnasActuales=STUFF((SELECT N','+QUOTENAME(C.name)
                    FROM sys.index_columns IC JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
                    WHERE IC.object_id=@Objeto AND IC.index_id=@IndiceReemplazo AND IC.key_ordinal>0
                    ORDER BY IC.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'');
                IF @ColumnasActuales COLLATE DATABASE_DEFAULT<>@Columnas COLLATE DATABASE_DEFAULT OR @ColumnasActuales IS NULL
                    THROW 56845,'Indice homonimo con columnas u orden distintos de Oracle.',1;
                SET @Prefijo=N'DROP INDEX '+QUOTENAME(@PK)+N' ON '+@Nombre+N';'+CHAR(13)+CHAR(10);
            END;

            SELECT @Nullable=SUM(CONVERT(int,Nullable)),@Bytes=SUM(BytesColumna) FROM @Meta;
            UPDATE @Plan SET ColumnasNullable=@Nullable,BytesMaximosClave=@Bytes WHERE Id=@Id;
            IF @Bytes>900 OR (SELECT COUNT(*) FROM @Meta)>32
                THROW 56819,'La definicion excede el limite conservador de 900 bytes o 32 columnas para PK; revisar.',1;
            SELECT @PredicadoNull=STUFF((SELECT N' OR '+QUOTENAME(Columna)+N' IS NULL'
                FROM @Meta ORDER BY Posicion FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,4,N'');
            SET @SQL=N'SELECT @N=COUNT_BIG(*) FROM '+@Nombre+N' WHERE '+@PredicadoNull+N';
                SELECT @D=COUNT_BIG(*) FROM (SELECT 1 X FROM '+@Nombre+N' GROUP BY '+@Columnas+
                N' HAVING COUNT_BIG(*)>1) G;';
            SET @FilasNull=NULL;
            SET @Duplicados=NULL;
            EXEC sys.sp_executesql @SQL,N'@N bigint OUTPUT,@D bigint OUTPUT',@N=@FilasNull OUTPUT,@D=@Duplicados OUTPUT;
            SET @SQLDiagnostico=N'SELECT TOP(20) '+@Columnas+N' FROM '+@Nombre+N' WHERE '+@PredicadoNull+N';'+CHAR(13)+CHAR(10)+
                N'SELECT TOP(20) '+@Columnas+N',COUNT_BIG(*) AS Repeticiones FROM '+@Nombre+N' GROUP BY '+@Columnas+
                N' HAVING COUNT_BIG(*)>1 ORDER BY Repeticiones DESC;';
            UPDATE @Plan SET FilasConNull=@FilasNull,GruposDuplicados=@Duplicados,SQLDiagnostico=@SQLDiagnostico WHERE Id=@Id;
            IF @FilasNull>0 THROW 56820,'Existen filas con NULL en columnas de la PK; no se corrigen automaticamente.',1;
            IF @Duplicados>0 THROW 56821,'Existen combinaciones duplicadas segun los tipos/collation SQL Server.',1;
            IF @Nullable>0 AND @ConvertirColumnasANotNull=0
                THROW 56822,'Columnas declaradas NULL: requieren NOT NULL para crear la PK.',1;

            SET @Alter=N'';
            DECLARE ColumnasNull CURSOR LOCAL STATIC READ_ONLY FOR
            SELECT Posicion,Columna,TipoDDL,CollationName FROM @Meta WHERE Nullable=1 ORDER BY Posicion;
            OPEN ColumnasNull;
            FETCH NEXT FROM ColumnasNull INTO @Orden,@Columna,@TipoDDL,@Collation;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SQL=N'ALTER TABLE '+@Nombre+N' ALTER COLUMN '+QUOTENAME(@Columna)+N' '+@TipoDDL+
                    CASE WHEN @Collation IS NOT NULL THEN N' COLLATE '+@Collation ELSE N'' END+
                    N' NOT NULL;';
                -- Compilar cada ALTER despues del anterior. Si se compila el
                -- ADD PK junto con los ALTER, puede ver columnas aun NULL.
                SET @Alter+=N'EXEC sys.sp_executesql N'''+REPLACE(@SQL,N'''',N'''''')+N''';'+CHAR(13)+CHAR(10);
                FETCH NEXT FROM ColumnasNull INTO @Orden,@Columna,@TipoDDL,@Collation;
            END;
            CLOSE ColumnasNull;
            DEALLOCATE ColumnasNull;
            SET @SQL=N'ALTER TABLE '+@Nombre+N' ADD CONSTRAINT '+QUOTENAME(@PK)+
                N' PRIMARY KEY NONCLUSTERED ('+@Columnas+N') WITH (PAD_INDEX=OFF,IGNORE_DUP_KEY=OFF,STATISTICS_NORECOMPUTE=OFF,ALLOW_ROW_LOCKS=ON,ALLOW_PAGE_LOCKS=ON,DATA_COMPRESSION=NONE) ON [PRIMARY];';
            SET @DDL=@Prefijo+@Alter+N'EXEC sys.sp_executesql N'''+REPLACE(@SQL,N'''',N'''''')+N''';';
            UPDATE @Plan SET Estado='LISTA',Observacion=CASE WHEN @IndiceReemplazo IS NULL THEN N'Crear PK nueva; datos validados.' ELSE N'Reemplazar indice equivalente por PK activa; datos validados.' END,
                SQLPropuesto=@DDL WHERE Id=@Id;
        END;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ColumnasNull')>=0 CLOSE ColumnasNull;
        IF CURSOR_STATUS('local','ColumnasNull')>=-1 DEALLOCATE ColumnasNull;
        UPDATE @Plan SET Estado='BLOQUEADA',Observacion=LEFT(CONCAT(ERROR_NUMBER(),N': ',ERROR_MESSAGE()),2000) WHERE Id=@Id;
    END CATCH;
    FETCH NEXT FROM Claves INTO @Id,@Tabla,@PK;
END;
CLOSE Claves;
DEALLOCATE Claves;

SELECT '01_PREVALIDACION' Seccion,* FROM @Plan ORDER BY Id;
SELECT '02_RESUMEN' Seccion,Estado,COUNT(*) Cantidad FROM @Plan GROUP BY Estado;
-- XML conserva el DDL completo y evita el truncamiento habitual del grid.
SELECT Tabla,NombrePK,SQLPropuesto FROM @Plan WHERE Estado='LISTA'
FOR XML PATH('Clave'),ROOT('DDLPropuesto'),TYPE;
IF @Aplicar=0
BEGIN
    SELECT 'VISTA PREVIA; NO SE CREARON PK NI SE CAMBIO NULLABILIDAD.' Resultado;
    RETURN;
END;
IF EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA')
    THROW 56830,'Hay PK bloqueadas. No se aplico ninguna; revisar 01_PREVALIDACION o seleccionar @SoloTabla.',1;

DECLARE Aplicacion CURSOR LOCAL STATIC READ_ONLY FOR
SELECT Id,Tabla,NombrePK,SQLPropuesto FROM @Plan WHERE Estado='LISTA' ORDER BY Id;
OPEN Aplicacion;
FETCH NEXT FROM Aplicacion INTO @Id,@Tabla,@PK,@DDL;
BEGIN TRY
    WHILE @@FETCH_STATUS=0
    BEGIN
        BEGIN TRANSACTION;
        SET @Objeto=OBJECT_ID(QUOTENAME(N'T3')+N'.'+QUOTENAME(@Tabla),N'U');
        -- Bloquea escritores y revalida el esquema antes de eliminar el indice.
        SET @SQL=N'SELECT @N=COUNT_BIG(*) FROM '+QUOTENAME(N'T3')+N'.'+QUOTENAME(@Tabla)+N' WITH(TABLOCKX,HOLDLOCK);';
        EXEC sys.sp_executesql @SQL,N'@N bigint OUTPUT',@N=@LockCount OUTPUT;
        EXEC sys.sp_executesql @SQLFirma,N'@O int,@F varbinary(32) OUTPUT',@O=@Objeto,@F=@FirmaActual OUTPUT;
        IF @FirmaActual IS NULL OR @FirmaActual<>(SELECT Firma FROM @Plan WHERE Id=@Id)
            THROW 56846,'El esquema cambio despues de prevalidar; volver a ejecutar.',1;
        SELECT @DefAntes=CONVERT(nvarchar(max),(
            SELECT C.column_id,C.system_type_id,C.user_type_id,C.max_length,C.precision,C.scale,C.collation_name,C.is_identity
            FROM sys.columns C JOIN @Origen O ON O.Tabla=@Tabla AND O.Columna=C.name COLLATE DATABASE_DEFAULT
            WHERE C.object_id=@Objeto ORDER BY O.Posicion
            FOR XML PATH('Columna'),ROOT('Definicion'),TYPE));
        EXEC sys.sp_executesql @DDL;
        SELECT @DefDespues=CONVERT(nvarchar(max),(
            SELECT C.column_id,C.system_type_id,C.user_type_id,C.max_length,C.precision,C.scale,C.collation_name,C.is_identity
            FROM sys.columns C JOIN @Origen O ON O.Tabla=@Tabla AND O.Columna=C.name COLLATE DATABASE_DEFAULT
            WHERE C.object_id=@Objeto ORDER BY O.Posicion
            FOR XML PATH('Columna'),ROOT('Definicion'),TYPE));
        IF HASHBYTES('SHA2_256',@DefAntes)<>HASHBYTES('SHA2_256',@DefDespues)
            THROW 56832,'Cambio inesperado en tipo/longitud/precision/escala/collation/identidad; se revierte la tabla.',1;
        COMMIT TRANSACTION;
        UPDATE @Plan SET Estado='CREADA',Observacion=N'PK creada y cambios NOT NULL confirmados para esta tabla.' WHERE Id=@Id;
        FETCH NEXT FROM Aplicacion INTO @Id,@Tabla,@PK,@DDL;
    END;
    CLOSE Aplicacion;
    DEALLOCATE Aplicacion;
END TRY
BEGIN CATCH
    SET @Error=LEFT(CONCAT(N'Tabla ',QUOTENAME(@Tabla),N'; PK ',QUOTENAME(@PK),N'; ',ERROR_NUMBER(),N': ',ERROR_MESSAGE()),2000);
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF CURSOR_STATUS('local','Aplicacion')>=0 CLOSE Aplicacion;
    IF CURSOR_STATUS('local','Aplicacion')>=-1 DEALLOCATE Aplicacion;
    UPDATE @Plan SET Estado='ERROR_DDL_REVERTIDO',Observacion=@Error WHERE Id=@Id;
    SELECT '03_RESULTADO_APLICACION' Seccion,* FROM @Plan ORDER BY Id;
    THROW 56831,@Error,1;
END CATCH;
SELECT '03_RESULTADO_APLICACION' Seccion,* FROM @Plan ORDER BY Id;
SELECT 'APLICACION TERMINADA. No se eliminaron filas. Solo se reemplazaron los indices equivalentes indicados en el plan.' Resultado;

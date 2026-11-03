/* SOLO LECTURA. Ejecutar antes de 02_DATOS_30_DIAS.sql.
   No ejecuta procedimientos de negocio, NEXT VALUE FOR ni actualiza datos.
   Ausencia de metadatos puede significar falta de VIEW DEFINITION.
*/
USE [T3QA];
SET NOCOUNT ON;
SELECT @@SERVERNAME Servidor, DB_NAME() BaseDatos, GETDATE() HoraServidor,
       CAST(DATEADD(day,-30,GETDATE()) AS date) LimiteFechaProceso,
       ORIGINAL_LOGIN() LoginOriginal, USER_NAME() UsuarioBase;

DECLARE @Objetos table(Nombre sysname, Tipo varchar(10));
INSERT @Objetos VALUES
 ('T3.PROC_CFDI_PROCESA_PAGO_AGR','P'),
 ('T3.PROC_CFDI_LIBERA_PAGO_CENTRAL','P'),
 ('T3.PROC_CFDI_LIBERA_PAGO_CHECK','P'),
 ('T3.PROC_V20_GENERAR_PAGO_AGR','P'),('EAI_OWNER.LOG_START','P'),
 ('EAI_OWNER.GETCONV','FN'),('T3.FN_TRIM_CFDI','FN'),
 ('T3.FN_NUM_TO_CHAR_CFDI','FN'),('T3.FN_CTRO_EDICOM_PAGO','FN'),
 ('T3.SeparaDireccion','FN'),('T3.SEQ_CFD','SO'),
 ('T3.SEQ_PAGO_CENTRAL_AGR','SO'),('EAI_OWNER.ProcessID','SO'),
 ('T3.CFDI_Cobranza','U'),('EAI_OWNER.TMP_ACCOUNT_HEADER','U'),
 ('T3.REGISTRO_FISCAL','U'),('T3.REGISTRO_FISCAL_DETALLE','U'),
 ('T3.WA_FACTORAJE','U'),('T3.CFDI_AGRUPACION_CTRL','U'),
 ('T3.CFDI_AGRUPACION_PAGO','U'),('T3.CFDI_DOCUMENTOS','U'),
 ('T3.CFDI_DOCUMENTOS_ENVIAR','U'),('T3.RF_PROCESOS_LOG','U'),
 ('T3.RF_ERROR_LOG','U'),('T3.CFDI_RFC_SETTING','U'),
 ('T3.MOV_CLIENTE','U'),('T3.TMD_EMAIL','U'),('EAI.ZSDFE_SOC','U'),
 ('T3.DISTRIBUIDOR_FISCAL','U'),('T3.CFDI_USOCFDI_CLIENTE','U'),
 ('T3.CFDI_REPROCESO','U'),('EAI_OWNER.MX_COMPONENTS','U'),
 ('EAI_OWNER.MX_EAI_MESSAGE_LOG','U'),('EAI_OWNER.MX_HASHTABLE','U');
SELECT '01_OBJETOS' Seccion, V.Nombre, V.Tipo TipoEsperado,
       O.type TipoInstalado, O.modify_date,
       CASE WHEN O.object_id IS NULL THEN 'AUSENTE O NO VISIBLE' ELSE 'VISIBLE' END Estado
FROM @Objetos V LEFT JOIN sys.objects O ON O.object_id=OBJECT_ID(V.Nombre)
ORDER BY V.Tipo,V.Nombre;

SELECT '02_SECUENCIAS' Seccion, SCHEMA_NAME(schema_id) Esquema,name,
       start_value,current_value,increment,minimum_value,maximum_value,
       is_cycling,is_exhausted,cache_size
FROM sys.sequences WHERE name IN ('SEQ_CFD','SEQ_PAGO_CENTRAL_AGR','ProcessID');
SELECT '03_PERMISOS' Seccion,
 HAS_PERMS_BY_NAME('T3.PROC_CFDI_PROCESA_PAGO_AGR','OBJECT','EXECUTE') PuedeEjecutar,
 HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','VIEW DEFINITION') PuedeVerDefiniciones;

-- Resolucion de dependencias SIN ejecutar SP/funciones. Puede reportar
-- limitaciones con temporales; conservar el mensaje para interpretarlo.
DECLARE @Objeto sysname;
DECLARE Dependencias CURSOR LOCAL FAST_FORWARD FOR
 SELECT Nombre FROM @Objetos WHERE Tipo IN ('P','FN') AND OBJECT_ID(Nombre) IS NOT NULL;
OPEN Dependencias;
FETCH NEXT FROM Dependencias INTO @Objeto;
WHILE @@FETCH_STATUS=0
BEGIN
 BEGIN TRY
  SELECT '04_DEPENDENCIAS' Seccion,@Objeto Modulo,
         referenced_schema_name,referenced_entity_name,referenced_minor_name
  FROM sys.dm_sql_referenced_entities(@Objeto,'OBJECT');
 END TRY
 BEGIN CATCH
  SELECT '04_ERROR_RESOLUCION' Seccion,@Objeto Modulo,
         ERROR_NUMBER() Numero,ERROR_MESSAGE() Mensaje;
 END CATCH;
 FETCH NEXT FROM Dependencias INTO @Objeto;
END;
CLOSE Dependencias;
DEALLOCATE Dependencias;

SELECT '05_COLUMNAS_DISTRIBUIDOR' Seccion,name
FROM sys.columns WHERE object_id=OBJECT_ID('T3.DISTRIBUIDOR_FISCAL')
 AND name IN ('STATE','ESTADO');
SELECT '06_GENERADOR_INSTALADO' Seccion, M.definition
FROM sys.sql_modules M WHERE object_id=OBJECT_ID('T3.PROC_V20_GENERAR_PAGO_AGR');

-- Consultas dinamicas para permitir diagnosticar objetos ausentes.
IF OBJECT_ID('EAI_OWNER.MX_HASHTABLE') IS NOT NULL
EXEC(N'SELECT ''07_CONFIGURACION'' Seccion,[Type],[Source],[Target]
FROM EAI_OWNER.MX_HASHTABLE
WHERE [Type]=''CFG Settings'' AND [Source] IN
(''VersionCFDI'',''Regimen Fiscal'',''Regimen Fiscal Cliente'',''UsoCFDI_Payment'',
 ''Payment Default Time'',''Banco Def - Central'',''Cuenta Def - Central'',''Metodo Pago'')
ORDER BY [Source];
SELECT ''07_DUPLICADOS_CONFIG'' Seccion,[Type],[Source],COUNT_BIG(*) Filas
FROM EAI_OWNER.MX_HASHTABLE WHERE [Type] IN (''CFG Settings'',''CFDI Estado'')
GROUP BY [Type],[Source] HAVING COUNT_BIG(*)>1;');
IF OBJECT_ID('EAI_OWNER.MX_COMPONENTS') IS NOT NULL
EXEC(N'SELECT ''08_COMPONENTE_614'' Seccion,Component,Status,Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component=614;');
IF OBJECT_ID('EAI.ZSDFE_SOC') IS NOT NULL
EXEC(N'SELECT ''09_EMISOR'' Seccion,BUKRS,KUNNR,RFC,RAZON_SOCIAL_HH,CODIGO_POSTAL
FROM EAI.ZSDFE_SOC WHERE BUKRS=''MX16'' AND KUNNR=''MX16'';');
IF OBJECT_ID('T3.CFDI_AGRUPACION_CTRL') IS NOT NULL
EXEC(N'SELECT ''10_CONTROLES_EXISTENTES'' Seccion,MAX(Agrupacion) MaxAgrupacion,
 COUNT_BIG(*) Filas FROM T3.CFDI_AGRUPACION_CTRL;
SELECT ''11_PENDIENTES_ANTERIORES_614'' Seccion,COUNT_BIG(*) Filas,
 MIN(Fecha_Pago) PrimeraFecha,MAX(Fecha_Pago) UltimaFecha
FROM T3.CFDI_AGRUPACION_CTRL
WHERE Fecha_Envio IS NULL AND Fecha_Pago>=''20220101'' AND Accnt_ID<>''Contado'';');

/* Diagnostico sintetico de diferencias, NO prueba de paridad ni correccion.
   Solo para la base desechable creada por Run.ps1 -AnalizarDependencias.
   Ejecuta los fuentes SQL actuales. Las expectativas Oracle proceden de leer
   el original; no se ejecuta ningun motor Oracle. PASS acredita reproduccion
   del hallazgo, incluso cuando confirma un defecto del SQL vigente. */
SET NOCOUNT ON;
IF DB_NAME() NOT LIKE N'CodexPagosDate[_]%'
    THROW 52400,'Este diagnostico solo permite la base sintetica desechable.',1;

DECLARE @TotalModelo decimal(18,2), @TotalSQL decimal(18,2);
SELECT @TotalModelo=SUM(ISNULL(VALOR_SUBT,0)+ISNULL(VALOR_IVA,0)
    +ISNULL(ENVIO_SUBT,0)+ISNULL(ENVIO_IVA,0)
    +ISNULL(CREDITO_SUBT,0)+ISNULL(CREDITO_IVA,0))
FROM T3.REGISTRO_FISCAL_DETALLE WHERE FACTURA='PARITY-NO-DETAIL';
SET @TotalSQL=T3.FN_TOTAL_FACT('PARITY-NO-DETAIL');
IF @TotalModelo IS NOT NULL OR @TotalSQL IS NULL OR @TotalSQL<>0
    THROW 52401,'No se reprodujo SUM NULL frente a FN_TOTAL_FACT SQL cero.',1;
SELECT 'FN_SIN_DETALLE' AS Caso,@TotalModelo AS SUM_sin_coalesce_exterior,
    @TotalSQL AS FN_TOTAL_FACT_SQL;
PRINT 'PASS hallazgo FN_TOTAL_FACT: conjunto vacio produce SUM NULL; funcion SQL retorna 0';

INSERT T3.REGISTRO_FISCAL_DETALLE(FACTURA,NUM_LINEA) VALUES('PARITY-NULLS',1);
SET @TotalSQL=T3.FN_TOTAL_FACT('PARITY-NULLS');
IF @TotalSQL IS NULL OR @TotalSQL<>0
    THROW 52402,'Un detalle con seis componentes NULL debe sumar cero.',1;
PRINT 'PASS detalle existente con componentes NULL retorna 0: distinto de ausencia de detalle';

INSERT EAI_OWNER.MX_HashTable([Type],[Source],[Target]) VALUES
    ('Parity Catalog','SINGLE','TARGET'),('Parity Catalog','NULL_TARGET',NULL),
    ('Parity Catalog','DUP','ONE'),('Parity Catalog','DUP','TWO');
IF EAI_OWNER.GETCONV('Parity Catalog','MISSING') IS NULL
   OR EAI_OWNER.GETCONV('Parity Catalog','MISSING')<>'MISSING'
   OR EAI_OWNER.GETCONV('Parity Catalog','SINGLE') IS NULL
   OR EAI_OWNER.GETCONV('Parity Catalog','SINGLE')<>'TARGET'
   OR EAI_OWNER.GETCONV('Parity Catalog','NULL_TARGET') IS NOT NULL
    THROW 52403,'Fallo de fallback, conversion unica o Target NULL.',1;
PRINT 'PASS GETCONV: fallback, coincidencia unica y Target NULL comprobados';
DECLARE @Elegido varchar(99)=EAI_OWNER.GETCONV('Parity Catalog','DUP');
IF @Elegido IS NULL OR @Elegido NOT IN ('ONE','TWO')
    THROW 52404,'El duplicado debe devolver uno de los Target disponibles.',1;
SELECT 'GETCONV_DUPLICADO' AS Caso,@Elegido AS Target_elegido_SQL,
    COUNT(*) AS Coincidencias,COUNT(DISTINCT [Target]) AS Targets_distintos
FROM EAI_OWNER.MX_HashTable WHERE [Type]='Parity Catalog' AND [Source]='DUP';
PRINT 'PASS GETCONV: duplicados ambiguos reproducidos; no se presupone orden Oracle ni SQL';

-- Dos pagos con via dominante y uno con via minoritaria, todos no enviados.
-- Oracle ScrPagos abre con RFC/asignacion ya asignados y marcaria el minoritario.
INSERT T3.CFDI_COBRANZA(ASIGNACION_ID,RFC,ASIGNACION_CENTRAL,VIA_PAGO,FECHA_PROCESO)
VALUES('PARITY-A1','AAA010101AAA','CENTRAL0001','01',GETDATE()),
      ('PARITY-A2','AAA010101AAA','CENTRAL0001','01',GETDATE()),
      ('PARITY-A3','AAA010101AAA','CENTRAL0001','03',GETDATE());
EXEC T3.WA_CFDI_COBZA_ASIG_CTRL @pDays=3,@pOutput=1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
    THROW 52405,'El control genero un error en vez de reproducir el defecto silencioso.',1;
IF NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE Proceso=889
    AND Fin IS NOT NULL AND Proceso_1=2 AND Proceso_2=1 AND Proceso_3=0)
 OR EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE FECHA_ENVIO IS NOT NULL)
 OR (SELECT COUNT(*) FROM T3.CFDI_COBRANZA)<>3
    THROW 52406,'No se reprodujo el filtro NULL del cursor ScrPagos del control.',1;
SELECT 'CONTROL_CURSOR_ACTUAL' AS Caso,Proceso,Proceso_1,Proceso_2,Proceso_3
FROM T3.RF_PROCESOS_LOG WHERE Proceso=889;
PRINT 'PASS defecto del control reproducido: 2 grupos, 1 inconsistencia, 0 pagos revisados, sin error';

-- Reproduce SOLO el predicado de actualizacion actual, sin modificar el SP.
-- Dos filas de distinta agrupacion comparten Asignacion_ID. ROWID distinguiria
-- una sola fila; el WHERE SQL actual abarca las dos. No acredita duplicados reales.
INSERT T3.CFDI_COBRANZA(ASIGNACION_ID,RFC,ASIGNACION_CENTRAL,VIA_PAGO,FECHA_PROCESO)
VALUES('PARITY-DUP','AAA010101AAA','CENTRAL0001','03',GETDATE()),
      ('PARITY-DUP','BBB010101BBB','CENTRAL9999','01',DATEADD(day,-10,GETDATE()));
BEGIN TRANSACTION;
UPDATE T3.CFDI_COBRANZA SET FECHA_ENVIO=GETDATE() WHERE ASIGNACION_ID='PARITY-DUP';
DECLARE @Afectadas int=@@ROWCOUNT;
ROLLBACK TRANSACTION;
IF @Afectadas<>2 THROW 52407,'No se reprodujo actualizacion amplia por Asignacion_ID.',1;
SELECT 'PREDICADO_UPDATE_ACTUAL' AS Caso,@Afectadas AS Filas_con_mismo_Asignacion_ID;
PRINT 'PASS riesgo ROWID: predicado por Asignacion_ID alcanza 2 filas de grupos y fechas distintos';
IF @@TRANCOUNT<>0 THROW 52408,'La prueba dejo una transaccion abierta.',1;
PRINT 'PASS diagnostico de dependencias terminado: diferencias confirmadas, codigo de negocio sin cambios';

/* Ejecutar completo en la base real seleccionada en SSMS, sin agregar GO.
   Solo lectura de tablas reales; INSERT unicamente en variables locales.
   No ejecuta procedimientos, funciones de negocio, jobs ni reprocesos.
   No usa NOLOCK. Las lecturas pueden reflejar momentos distintos.
*/
SET NOCOUNT ON;
DECLARE @FechaProc date='2026-10-14';
DECLARE @PID numeric(10,0)=NULL; -- NULL: ultima corrida 604 de ese dia BATMD.
DECLARE @MaxCalculosHistorial int=20; -- Solo la seccion 08B; conciliacion cubre todo el lote.
DECLARE @UsaParidadOracle bit=CASE WHEN CHARINDEX(N'PAGOS_SAT_AMOUNT_V1',
 OBJECT_DEFINITION(OBJECT_ID(N'T3.PROC_CFDI_PROCESAR_PAGOS')))>0 THEN 1 ELSE 0 END;
DECLARE @ModificacionModulo datetime=(SELECT modify_date FROM sys.objects
 WHERE object_id=OBJECT_ID(N'T3.PROC_CFDI_PROCESAR_PAGOS'));
DECLARE @Desde date=@FechaProc,@Hasta date=DATEADD(day,1,@FechaProc),
 @Inicio datetime2(0),@Fin datetime2(0),@Contador numeric(10,0),
 @VentanaInicio datetime2(0),@VentanaFin datetime2(0);

SELECT N'01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
 SYSDATETIMEOFFSET() AS FechaCaptura,@FechaProc AS FechaBATMD;
SELECT N'02_VERSION' AS Seccion,O.modify_date,
 CASE WHEN M.definition IS NULL THEN N'No visible'
      WHEN CHARINDEX(N'PAGOS_CURSOR_BIND_V1',M.definition)>0 THEN N'Marca de cursores presente'
      ELSE N'Sin marca: contrastar definicion instalada' END AS Cursores,
 CASE WHEN CHARINDEX(N'CAST(AP.Fecha_Proc_BATMD AS DATE)',M.definition)>0
      THEN N'Filtro DATE presente' ELSE N'Revisar filtro BATMD instalado' END AS Fecha,
 @UsaParidadOracle AS ReglasOracleSATyTotalNull
FROM sys.objects O LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id=OBJECT_ID(N'T3.PROC_CFDI_PROCESAR_PAGOS');

IF @PID IS NULL
 SELECT TOP (1) @PID=L.PID FROM T3.RF_PROCESOS_LOG L
 WHERE L.Proceso=604 AND L.Fecha_Proc_BATMD>=@Desde AND L.Fecha_Proc_BATMD<@Hasta
 ORDER BY L.Inicio DESC,L.PID DESC;
SELECT TOP (1) @Inicio=L.Inicio,@Fin=L.Fin,@Contador=L.Proceso_1
FROM T3.RF_PROCESOS_LOG L WHERE L.PID=@PID AND L.Proceso=604
 AND L.Fecha_Proc_BATMD>=@Desde AND L.Fecha_Proc_BATMD<@Hasta ORDER BY L.Inicio DESC;
IF @Inicio IS NULL
BEGIN
 SELECT N'03_SIN_CORRIDA' AS Seccion,@PID AS PID,
 N'No se encontro inicio 604 para ese PID/dia BATMD. No se puede acreditar exito.' AS Resultado;
 SELECT TOP (20) L.* FROM T3.RF_PROCESOS_LOG L WHERE L.Proceso=604 ORDER BY L.Inicio DESC;
 RETURN;
END;
IF DATEADD(second,1,@Inicio)<@ModificacionModulo
BEGIN
 SELECT N'03_VERSION_POSTERIOR_A_CORRIDA' AS Seccion,@PID AS PID,@Inicio AS Inicio,
 @ModificacionModulo AS ModificacionModulo,
 N'La definicion actual es posterior a la corrida. No usar sus reglas para certificar una ejecucion historica.' AS Resultado;
 RETURN;
END;
-- Margen de un segundo por redondeo datetime2(0) en las bitacoras/resultados.
SET @VentanaInicio=DATEADD(second,-1,@Inicio);
SET @VentanaFin=DATEADD(second,1,COALESCE(@Fin,CONVERT(datetime2(0),SYSDATETIME())));
SELECT N'03_CORRIDA' AS Seccion,L.*,@VentanaInicio AS VentanaDesde,@VentanaFin AS VentanaHasta
FROM T3.RF_PROCESOS_LOG L WHERE L.Proceso=604 AND L.PID=@PID;

-- Reproduce solo la seleccion del cursor, sin llamar FN_TOTAL_FACT ni insertar.
-- Conservar multiplicidad: varias vigencias/RF/TD/CFDI pueden producir varias filas.
-- CFDI participa solo si el modulo instalado tiene la regla nueva.
DECLARE @E table
(Asignacion_ID varchar(50) COLLATE DATABASE_DEFAULT,Factura varchar(30) COLLATE DATABASE_DEFAULT,
 Pago_ID varchar(50) COLLATE DATABASE_DEFAULT,Cliente_SAP varchar(10) COLLATE DATABASE_DEFAULT,
 Fecha_Asignacion datetime2(0),ImporteAP decimal(15,2),Nota_Credito varchar(30) COLLATE DATABASE_DEFAULT,
 Origen varchar(30) COLLATE DATABASE_DEFAULT);
INSERT @E
SELECT A.Asignacion_ID,CASE WHEN @UsaParidadOracle=1 AND DATALENGTH(A.Factura)=0 THEN NULL ELSE A.Factura END,
 A.Pago_ID,A.Cliente_SAP,A.Fecha_Asignacion,A.Valor_Pago,
 CASE WHEN @UsaParidadOracle=1 AND DATALENGTH(A.Nota_Credito)=0 THEN NULL ELSE A.Nota_Credito END,
 ISNULL(CASE WHEN @UsaParidadOracle=1 AND DATALENGTH(T.Origen)=0 THEN NULL ELSE T.Origen END,'INCOBRABLE')
FROM T3.Asignacion_Pago A
JOIN T3.Cliente C ON C.Cliente_SAP=A.Cliente_SAP
 AND CAST(A.Fecha_Asignacion AS date) BETWEEN CAST(C.Fecha_Ini_Vig AS date) AND CAST(C.Fecha_Fin_Vig AS date)
LEFT JOIN T3.Registro_Fiscal R ON R.Factura=A.Factura AND (@UsaParidadOracle=0 OR DATALENGTH(A.Factura)>0)
LEFT JOIN T3.Tipo_Documento T ON T.Tipo_Documento=R.Tipo_Docto AND (@UsaParidadOracle=0 OR DATALENGTH(R.Tipo_Docto)>0)
LEFT JOIN T3.CFDI_Documentos CFD ON @UsaParidadOracle=1 AND CFD.Nota_Venta=A.Factura AND DATALENGTH(A.Factura)>0
WHERE A.Fecha_Proc_BATMD>=@Desde AND A.Fecha_Proc_BATMD<@Hasta
 AND (@UsaParidadOracle=0 OR DATALENGTH(A.Cliente_SAP)>0);

DECLARE @R table
(Asignacion_ID varchar(30) COLLATE DATABASE_DEFAULT,Factura varchar(30) COLLATE DATABASE_DEFAULT,
 Pago_ID varchar(30) COLLATE DATABASE_DEFAULT,Importe decimal(16,2),Importe_Factura decimal(16,2),
 Saldo_Anterior decimal(16,2),Numero_Pago decimal(10,0),Cant_Pagos decimal(10,0),
 Abono_Pagos decimal(16,2),Cant_CM decimal(10,0),Abono_CM decimal(16,2),
 Fecha_Asignacion datetime2(0),Fecha_Proceso datetime2(0),Fecha_Factura datetime2(0),
 Status varchar(20) COLLATE DATABASE_DEFAULT,Via_Pago varchar(4) COLLATE DATABASE_DEFAULT,
 Nota_Venta varchar(30) COLLATE DATABASE_DEFAULT,UUID_Venta varchar(40) COLLATE DATABASE_DEFAULT);
INSERT @R
SELECT C.Asignacion_ID,C.Factura,C.Pago_ID,C.Importe,C.Importe_Factura,C.Saldo_Anterior,
 C.Numero_Pago,C.Cant_Pagos,C.Abono_Pagos,C.Cant_CM,C.Abono_CM,C.Fecha_Asignacion,
 C.Fecha_Proceso,C.Fecha_Factura,C.Status,C.Via_Pago,C.Nota_Venta,C.UUID_Venta
FROM T3.CFDI_Cobranza C WHERE C.Fecha_Proc_BATMD>=@Desde AND C.Fecha_Proc_BATMD<@Hasta
 AND C.Fecha_Proceso>=@VentanaInicio AND C.Fecha_Proceso<=@VentanaFin;

DECLARE @K table(Asignacion_ID varchar(50) COLLATE DATABASE_DEFAULT,
 Factura varchar(30) COLLATE DATABASE_DEFAULT,Esperadas bigint,Encontradas bigint);
;WITH E AS (SELECT Asignacion_ID,Factura,COUNT_BIG(*) AS n FROM @E GROUP BY Asignacion_ID,Factura),
 R AS (SELECT Asignacion_ID,Factura,COUNT_BIG(*) AS n FROM @R GROUP BY Asignacion_ID,Factura)
INSERT @K
SELECT COALESCE(E.Asignacion_ID,R.Asignacion_ID),COALESCE(E.Factura,R.Factura),ISNULL(E.n,0),ISNULL(R.n,0)
FROM E FULL JOIN R ON (E.Asignacion_ID=R.Asignacion_ID OR (E.Asignacion_ID IS NULL AND R.Asignacion_ID IS NULL))
 AND (E.Factura=R.Factura OR (E.Factura IS NULL AND R.Factura IS NULL));
DECLARE @nEsperadas bigint=(SELECT COUNT_BIG(*) FROM @E),
 @nInsertadas bigint=(SELECT COUNT_BIG(*) FROM @R),@nFaltantes bigint,@nExcedentes bigint,
 @nNoEsperadas bigint,@nErrores bigint,
 @nBaseNull bigint=(SELECT COUNT_BIG(*) FROM @R WHERE Importe_Factura IS NULL AND Factura<>'INCOBRABLE'),
 @nSinSaldo bigint=(SELECT COUNT_BIG(*) FROM @R WHERE Factura<>'INCOBRABLE'
                   AND (Numero_Pago IS NULL OR (Saldo_Anterior IS NULL
                        AND (@UsaParidadOracle=0 OR Importe_Factura IS NOT NULL))));
SELECT @nFaltantes=COALESCE(SUM(CASE WHEN Esperadas>Encontradas THEN Esperadas-Encontradas ELSE 0 END),0),
 @nExcedentes=COALESCE(SUM(CASE WHEN Esperadas>0 AND Encontradas>Esperadas THEN Encontradas-Esperadas ELSE 0 END),0),
 @nNoEsperadas=COALESCE(SUM(CASE WHEN Esperadas=0 THEN Encontradas ELSE 0 END),0) FROM @K;
SELECT @nErrores=COUNT_BIG(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE QUEUE_NAME='PROC_CFDI_PROCESAR_PAGOS' AND JOB_PID=@PID;
SELECT N'04_CONCILIACION' AS Seccion,@PID AS PID,@nEsperadas AS EsperadasCursor,
 @nInsertadas AS InsertadasEnVentana,@Contador AS ContadorProceso604,
 @nFaltantes AS Faltantes,@nExcedentes AS Excedentes,@nNoEsperadas AS NoEsperadas,
 @nErrores AS ErroresDelPID,@nSinSaldo AS FilasConCalculoIncompleto,@nBaseNull AS FilasConImporteBaseNull,
 CASE WHEN @Fin IS NULL THEN N'INCOMPLETO: falta Fin'
      WHEN @nErrores>0 THEN N'CON ERRORES: revisar bitacora'
      WHEN @nFaltantes+@nExcedentes+@nNoEsperadas>0 THEN N'NO CONCILIA: revisar detalle'
      WHEN @Contador IS NULL OR @Contador<>@nEsperadas THEN N'CONTADOR NO CONCILIA'
      WHEN @nSinSaldo>0 THEN N'FILAS INCOMPLETAS: saldo/parcialidad NULL'
      WHEN @UsaParidadOracle=1 AND @nBaseNull>0 THEN N'CONCILIA; base NULL conforme Oracle, revisar detalle fiscal/SAT'
      WHEN @nEsperadas=0 THEN N'SIN ASIGNACIONES ELEGIBLES; no acredita una insercion'
      ELSE N'CONCILIA POR CLAVE/CANTIDAD; revisar calidad y control posterior' END AS Resultado;
SELECT N'05_DIFERENCIAS' AS Seccion,* FROM @K
WHERE Esperadas<>Encontradas OR Esperadas>1 OR Encontradas>1 OR Asignacion_ID IS NULL OR Factura IS NULL
ORDER BY Factura,Asignacion_ID;

-- Excluidas antes de iniciar el recorrido; no contarlas como faltantes de insercion.
SELECT N'06_EXCLUIDAS_CLIENTE' AS Seccion,A.Asignacion_ID,A.Factura,A.Cliente_SAP,
 A.Fecha_Asignacion,A.Valor_Pago,N'Sin cliente vigente en la fecha de asignacion' AS Motivo
FROM T3.Asignacion_Pago A WHERE A.Fecha_Proc_BATMD>=@Desde AND A.Fecha_Proc_BATMD<@Hasta
 AND NOT EXISTS(SELECT 1 FROM T3.Cliente C WHERE C.Cliente_SAP=A.Cliente_SAP
 AND CAST(A.Fecha_Asignacion AS date) BETWEEN CAST(C.Fecha_Ini_Vig AS date) AND CAST(C.Fecha_Fin_Vig AS date))
ORDER BY A.Factura,A.Asignacion_ID;

SELECT N'07_FILAS_INSERTADAS' AS Seccion,* FROM @R ORDER BY Factura,Fecha_Asignacion,Asignacion_ID;
SELECT N'08_CALIDAD' AS Seccion,R.*,
 CASE WHEN R.Factura='INCOBRABLE' THEN N'Ruta especial: puede no calcular saldo/parcialidad'
      WHEN @UsaParidadOracle=1 AND R.Importe_Factura IS NULL AND R.Saldo_Anterior IS NULL
           AND R.Numero_Pago IS NOT NULL THEN N'Base/saldo NULL conforme Oracle; revisar origen fiscal/SAT'
      WHEN R.Saldo_Anterior IS NULL OR R.Numero_Pago IS NULL THEN N'REVISAR saldo/parcialidad NULL'
      WHEN R.Saldo_Anterior<0 THEN N'REVISAR saldo negativo/origen fiscal'
      WHEN R.Importe_Factura=0 THEN N'REVISAR importe base cero'
      WHEN R.Status='PendienteT3' THEN N'Documento pendiente T3'
      ELSE N'Sin alerta basica; no sustituye validacion funcional' END AS Observacion
FROM @R R WHERE R.Factura='INCOBRABLE' OR R.Saldo_Anterior IS NULL OR R.Numero_Pago IS NULL
 OR R.Saldo_Anterior<0 OR R.Importe_Factura=0 OR R.Status='PendienteT3';

-- Comprobacion orientativa del historial: usa el importe base ya escrito y
-- movimientos actuales. Revisar seccion 09 si existen duplicados en cobranza.
-- No reconstruye la eleccion de un documento T3 ambiguo ni valida su importe base.
DECLARE @Calculos table(Asignacion_ID varchar(50) COLLATE DATABASE_DEFAULT,
 Factura varchar(30) COLLATE DATABASE_DEFAULT);
INSERT @Calculos SELECT TOP (@MaxCalculosHistorial) Asignacion_ID,Factura FROM @K
WHERE Esperadas=1 AND Encontradas=1 AND Factura<>'INCOBRABLE'
ORDER BY Factura,Asignacion_ID;
SELECT N'08B_CALCULO_HISTORIAL' AS Seccion,R.Factura,R.Asignacion_ID,
 R.Importe,E.ImporteAP AS ImporteOrigen,R.Saldo_Anterior,
 R.Importe_Factura-S.AbonoPagos-S.AbonoCM AS SaldoAnteriorSegunHistorial,
 R.Numero_Pago,S.Pagos+CASE WHEN E.Nota_Credito IS NOT NULL OR EXISTS
 (SELECT 1 FROM T3.Pago P WHERE P.Pago_ID=E.Pago_ID AND P.Tipo_Pago='Returns') THEN 0 ELSE 1 END AS NumeroSegunHistorial,
 R.Cant_Pagos,S.Pagos AS PagosAnteriores,R.Abono_Pagos,S.AbonoPagos AS AbonoPagosAnterior,
 R.Cant_CM,S.CM AS CMAnteriores,R.Abono_CM,S.AbonoCM AS AbonoCMAnterior
FROM @R R JOIN @E E ON E.Asignacion_ID=R.Asignacion_ID AND E.Factura=R.Factura
JOIN @Calculos Q ON Q.Asignacion_ID=R.Asignacion_ID AND Q.Factura=R.Factura
CROSS APPLY
 (SELECT COALESCE(SUM(CONVERT(bigint,CASE WHEN (H.Nota_Credito IS NOT NULL AND (@UsaParidadOracle=0 OR DATALENGTH(H.Nota_Credito)>0)) OR P.Tipo_Pago='Returns' THEN 0 ELSE 1 END)),0) AS Pagos,
  COALESCE(SUM(CONVERT(bigint,CASE WHEN (H.Nota_Credito IS NOT NULL AND (@UsaParidadOracle=0 OR DATALENGTH(H.Nota_Credito)>0)) OR P.Tipo_Pago='Returns' THEN 1 ELSE 0 END)),0) AS CM,
  COALESCE(SUM(CASE WHEN (H.Nota_Credito IS NOT NULL AND (@UsaParidadOracle=0 OR DATALENGTH(H.Nota_Credito)>0)) OR P.Tipo_Pago='Returns' THEN 0 ELSE ISNULL(H.Valor_Pago,0) END),0) AS AbonoPagos,
  COALESCE(SUM(CASE WHEN (H.Nota_Credito IS NOT NULL AND (@UsaParidadOracle=0 OR DATALENGTH(H.Nota_Credito)>0)) OR P.Tipo_Pago='Returns' THEN ISNULL(H.Valor_Pago,0) ELSE 0 END),0) AS AbonoCM
  FROM T3.Asignacion_Pago H LEFT JOIN T3.Pago P ON P.Pago_ID=H.Pago_ID
  WHERE H.Factura=E.Factura AND H.Fecha_Asignacion>=CONVERT(date,'20180901',112)
   AND (H.Fecha_Asignacion<E.Fecha_Asignacion
        OR (H.Fecha_Asignacion=E.Fecha_Asignacion AND H.Asignacion_ID<E.Asignacion_ID))) S
WHERE R.Factura<>'INCOBRABLE' AND R.Importe_Factura IS NOT NULL
 AND EXISTS(SELECT 1 FROM @K K WHERE K.Asignacion_ID=R.Asignacion_ID AND K.Factura=R.Factura
            AND K.Esperadas=1 AND K.Encontradas=1)
ORDER BY R.Factura,R.Fecha_Asignacion,R.Asignacion_ID;

-- Duplicados de origen/historial pueden afectar los saldos. No se eliminan aqui.
SELECT N'09_DUPLICADOS_COBRANZA' AS Seccion,C.Asignacion_ID,C.Factura,COUNT_BIG(*) AS Filas,
 MIN(C.Fecha_Proceso) AS PrimeraInsercion,MAX(C.Fecha_Proceso) AS UltimaInsercion
FROM T3.CFDI_Cobranza C WHERE EXISTS(SELECT 1 FROM @E E WHERE E.Factura=C.Factura)
GROUP BY C.Asignacion_ID,C.Factura HAVING COUNT_BIG(*)>1;
SELECT N'10_ORIGEN_FISCAL_AUSENTE' AS Seccion,E.Factura,COUNT_BIG(*) AS FilasElegibles
FROM @E E WHERE NOT EXISTS(SELECT 1 FROM T3.Registro_Fiscal F WHERE F.Factura=E.Factura)
GROUP BY E.Factura;

-- Casos concretos de la captura: referencias orientativas, no exigencias para todo el lote.
SELECT N'11_CASOS_CAPTURA' AS Seccion,R.* FROM @R R
WHERE R.Factura IN ('CHD-33522','V1972-85517','V2363-145780','V0010-134061')
ORDER BY R.Factura,R.Fecha_Asignacion,R.Asignacion_ID;
SELECT N'12_ERRORES_PROCESO' AS Seccion,CREATED,QUEUE_NAME,JOB_PID,REFERENCE,
 SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE QUEUE_NAME='PROC_CFDI_PROCESAR_PAGOS' AND JOB_PID=@PID ORDER BY CREATED;

-- El 889 usa otro PID. Coincidencia temporal es contexto, NO un vinculo de padre/hijo.
SELECT TOP (10) N'13_CONTROL_POSTERIOR_CANDIDATO' AS Seccion,L.*
FROM T3.RF_PROCESOS_LOG L WHERE L.Proceso=889
 AND L.Inicio>=DATEADD(second,-1,COALESCE(@Fin,@Inicio))
 AND L.Inicio<DATEADD(minute,10,COALESCE(@Fin,@Inicio)) ORDER BY L.Inicio,L.PID;
SELECT N'14_ERRORES_CONTROL_VENTANA' AS Seccion,CREATED,QUEUE_NAME,JOB_PID,REFERENCE,
 SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE QUEUE_NAME='WA_CFDI_COBZA_ASIG_CTRL'
 AND CREATED>=@VentanaInicio AND CREATED<DATEADD(minute,10,COALESCE(@Fin,@Inicio)) ORDER BY CREATED;
SELECT N'15_ESTADO_ACTUAL_COMPONENTES' AS Seccion,Component,Status,Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component IN (604,889);
SELECT N'16_ALCANCE' AS Seccion,
 N'Cobranza no guarda el PID de esta corrida en el INSERT. Asociacion por BATMD/Fecha_Proceso; '
 +N'corridas concurrentes o repetidas en la misma ventana requieren revision. '
 +N'Los esperados usan datos actuales, no una fotografia anterior a la ejecucion.' AS Limitacion;

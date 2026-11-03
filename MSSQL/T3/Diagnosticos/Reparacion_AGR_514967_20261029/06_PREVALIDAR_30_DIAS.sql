/* SOLO LECTURA. Ejecutar despues de verificar la reparacion.
   Esta primera parte revisa metadatos y estado global del liberador.
   La segunda parte proyecta los datos con nDias=30 usando GETDATE del servidor.
   No llama CHECK ni consume secuencias. No altera LOG_START ni crea componente.
*/
USE [T3QA];
SET NOCOUNT ON;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() HoraServidor,
       CAST(DATEADD(day,-30,GETDATE()) AS date) FechaProcesoLimiteExclusivo;
SELECT Component,Name,Status,Last_Run FROM EAI_OWNER.MX_COMPONENTS WHERE Component IN (613,614);
SELECT OBJECT_DEFINITION(OBJECT_ID('EAI_OWNER.LOG_START')) DefinicionLogStart;
SELECT SCHEMA_NAME(schema_id) Esquema,name,current_value,maximum_value,increment,is_exhausted
FROM sys.sequences WHERE name IN ('SEQ_CFD','SEQ_PAGO_CENTRAL_AGR','ProcessID');
SELECT name,uses_ansi_nulls,uses_quoted_identifier FROM sys.sql_modules M
JOIN sys.objects O ON O.object_id=M.object_id
WHERE O.object_id IN (OBJECT_ID('T3.PROC_CFDI_PROCESA_PAGO_AGR'),
 OBJECT_ID('T3.PROC_CFDI_LIBERA_PAGO_CENTRAL'),OBJECT_ID('T3.PROC_V20_GENERAR_PAGO_AGR'));
-- El contrato del LOG_START local solo hace UPDATE. Un componente inexistente
-- no es por si solo prueba de que la generacion vaya a fallar; revisar instalado.
SELECT 'PENDIENTES_GLOBALES_614' Seccion,A.*
FROM T3.CFDI_AGRUPACION_CTRL A
WHERE A.Fecha_Envio IS NULL AND A.Fecha_Pago>='20220101' AND A.Accnt_ID<>'Contado';
-- El UPDATE inicial del agrupador es mas amplio que el filtro de candidatos.
SELECT 'ALCANCE_UPDATE_INICIAL' Seccion,COUNT_BIG(*) FilasJoin,
 COUNT(DISTINCT C.Asignacion_ID) Asignaciones
FROM T3.CFDI_Cobranza C
JOIN EAI_OWNER.TMP_ACCOUNT_HEADER A ON SUBSTRING(C.Asignacion_ID,3,10)=A.ClearingDocNumber
 AND A.FiscalYear=CONVERT(varchar(4),YEAR(GETDATE()))
JOIN T3.REGISTRO_FISCAL RF ON RF.Factura=C.Factura
WHERE C.Fecha_Proceso>CAST(DATEADD(day,-30,GETDATE()) AS date)
 AND C.Asignacion_Central IS NULL
 AND ISNULL(A.Assignment,RF.Entrega)<>RF.Entrega
 AND ISNULL(A.Assignment,RF.Entrega)<>'B001 - Bank I'
 AND ISNULL(A.Assignment,RF.Entrega)<>C.Factura+','
 AND ISNULL(A.Assignment,RF.Entrega) NOT LIKE '1-1%'
 AND ISNULL(A.Assignment,RF.Entrega)<>RF.Referencia;

/* SOLO LECTURA de negocio. Ejecutar despues del script 01.
   Simula el UPDATE inicial UNICAMENTE sobre #P, no sobre CFDI_Cobranza.
   No ejecuta CHECK, generadores, liberadores ni consume secuencias.
   Lectura acotada a 50000 pendientes; si supera limite, DETIENE sin emitir
   conclusiones sobre una muestra incompleta. Aumentar solo tras revisar costo.
   No es una fotografia transaccional: evitar cambios concurrentes al evaluar.
*/
USE [T3QA];
SET NOCOUNT ON;
DECLARE @nDias int=30, @MaxFilas int=50000;
DECLARE @Ahora datetime=GETDATE(), @Limite date;
SET @Limite=CAST(DATEADD(day,-@nDias,@Ahora) AS date);
SELECT '01_VENTANA' Seccion,@Ahora HoraServidor,@Limite LimiteExclusivo;
DROP TABLE IF EXISTS #P,#G,#D;

-- Incluye historico porque el INSERT de detalle no filtra Fecha_Proceso.
SELECT TOP (@MaxFilas+1) C.* INTO #P
FROM T3.CFDI_Cobranza C
WHERE C.Fecha_Envio IS NULL AND C.Created_By<>'INTERFACE'
 AND C.Via_Pago NOT IN ('01','CM','AI')
 AND ISNULL(C.Status,'1') NOT IN ('Debit Note','Canc Pago')
 AND C.RFC<>'XAXX010101000'
 AND NOT EXISTS(SELECT 1 FROM T3.WA_Factoraje F WHERE F.Factura=C.Factura);
IF (SELECT COUNT_BIG(*) FROM #P)>@MaxFilas
BEGIN
 SELECT 'DETENIDO_LIMITE' Seccion,@MaxFilas Limite,
 'No se analizan datos incompletos. Revisar volumen e indices antes de ampliar.' Mensaje;
 RETURN;
END;

-- Detecta multiplicidad antes de simular el UPDATE FROM del procedimiento.
SELECT '02_ASIGNACION_AMBIGUA' Seccion,C.Asignacion_ID,C.Factura,A.Filas,
 A.PrimeraAssignment,A.UltimaAssignment
FROM #P C
CROSS APPLY (
 SELECT COUNT_BIG(*) Filas,MIN(Acc.Assignment) PrimeraAssignment,
 MAX(Acc.Assignment) UltimaAssignment
 FROM EAI_OWNER.TMP_ACCOUNT_HEADER Acc
 INNER JOIN T3.REGISTRO_FISCAL RF ON RF.Factura=C.Factura
 WHERE SUBSTRING(C.Asignacion_ID,3,10)=Acc.ClearingDocNumber
 AND Acc.FiscalYear=CONVERT(varchar(4),YEAR(@Ahora))
 AND ISNULL(Acc.Assignment,RF.Entrega)<>RF.Entrega
 AND ISNULL(Acc.Assignment,RF.Entrega)<>'B001 - Bank I'
 AND ISNULL(Acc.Assignment,RF.Entrega)<>C.Factura+','
 AND ISNULL(Acc.Assignment,RF.Entrega) NOT LIKE '1-1%'
 AND ISNULL(Acc.Assignment,RF.Entrega)<>RF.Referencia
) A
WHERE C.Fecha_Proceso>@Limite AND C.Asignacion_Central IS NULL AND A.Filas>1;

UPDATE C SET Asignacion_Central=Acc.Assignment
FROM #P C
INNER JOIN EAI_OWNER.TMP_ACCOUNT_HEADER Acc
 ON SUBSTRING(C.Asignacion_ID,3,10)=Acc.ClearingDocNumber
 AND Acc.FiscalYear=CONVERT(varchar(4),YEAR(@Ahora))
INNER JOIN T3.REGISTRO_FISCAL RF ON RF.Factura=C.Factura
WHERE C.Fecha_Proceso>@Limite AND C.Asignacion_Central IS NULL
 AND ISNULL(Acc.Assignment,RF.Entrega)<>RF.Entrega
 AND ISNULL(Acc.Assignment,RF.Entrega)<>'B001 - Bank I'
 AND ISNULL(Acc.Assignment,RF.Entrega)<>C.Factura+','
 AND ISNULL(Acc.Assignment,RF.Entrega) NOT LIKE '1-1%'
 AND ISNULL(Acc.Assignment,RF.Entrega)<>RF.Referencia;
SELECT '03_SIMULACION' Seccion,@@ROWCOUNT FilasTemporalesConAsignacion,
 'Si 02 arrojo filas, la agrupacion proyectada no es determinista.' Observacion;

SELECT IDENTITY(int,1,1) GrupoDiagnostico,
 CAST(Fecha_Pago AS date) Fecha_Pago,RFC,
 CASE Via_Pago WHEN 'NA' THEN '03' ELSE Via_Pago END Via_Pago,
 ISNULL(Banco_Nombre,'NoBanco') Banco_Nombre,
 ISNULL(Banco_Num_Cuenta,'NoCuenta') Banco_Num_Cuenta,
 ISNULL(Asignacion_Central,'NoAsigna') Asignacion_Central,
 SUM(Importe) Importe,COUNT(Importe) Cantidad_Pagos,
 MAX(Accnt_ID) Accnt_ID,MAX(Cliente_SAP) Cliente_SAP,
 COUNT(DISTINCT Cliente_SAP) ClientesDistintos,COUNT_BIG(*) Filas
INTO #G FROM #P
WHERE Fecha_Proceso>@Limite
GROUP BY CAST(Fecha_Pago AS date),RFC,
 CASE Via_Pago WHEN 'NA' THEN '03' ELSE Via_Pago END,
 ISNULL(Banco_Nombre,'NoBanco'),ISNULL(Banco_Num_Cuenta,'NoCuenta'),
 ISNULL(Asignacion_Central,'NoAsigna');

SELECT G.GrupoDiagnostico,P.* INTO #D FROM #G G INNER JOIN #P P
 ON CAST(P.Fecha_Pago AS date)=G.Fecha_Pago AND P.RFC=G.RFC
 AND CASE P.Via_Pago WHEN 'NA' THEN '03' ELSE P.Via_Pago END=G.Via_Pago
 AND ISNULL(P.Banco_Nombre,'NoBanco')=G.Banco_Nombre
 AND ISNULL(P.Banco_Num_Cuenta,'NoCuenta')=G.Banco_Num_Cuenta
 AND ISNULL(P.Asignacion_Central,'NoAsigna')=G.Asignacion_Central;

SELECT '04_GRUPOS_PROYECTADOS' Seccion,G.*,
 ISNULL(V.VersionCFDI,EAI_OWNER.GETCONV('CFG Settings','VersionCFDI')) VersionCFDI,
 CASE WHEN G.Accnt_ID IS NULL OR G.Accnt_ID='Contado' THEN 1 ELSE 0 END ExcluidoPorAccnt,
 CASE WHEN G.Fecha_Pago IS NULL OR G.Fecha_Pago<'20220101' THEN 1 ELSE 0 END ExcluidoPorFecha,
 CASE WHEN G.Cantidad_Pagos>9999 OR ABS(G.Importe)>9999999999999.99 THEN 1 ELSE 0 END ExcedeControl,
 D.Detalles,D.ImporteDetalle,D.FueraVentana,
 CASE WHEN G.Cantidad_Pagos<>D.Detalles OR G.Importe<>D.ImporteDetalle
 OR G.Importe IS NULL OR D.ImporteDetalle IS NULL THEN 1 ELSE 0 END RevisarConciliacion
FROM #G G
OUTER APPLY(SELECT MAX(Valor) VersionCFDI FROM T3.CFDI_RFC_SETTING
 WHERE RFC=G.RFC AND Parametro='VersionCFDI') V
OUTER APPLY(SELECT COUNT_BIG(*) Detalles,SUM(Importe) ImporteDetalle,
 COUNT_BIG(CASE WHEN Fecha_Proceso<=@Limite OR Fecha_Proceso IS NULL THEN 1 END) FueraVentana
 FROM #D WHERE GrupoDiagnostico=G.GrupoDiagnostico) D
ORDER BY G.GrupoDiagnostico;

SELECT '05_DETALLES_A_REVISAR' Seccion,GrupoDiagnostico,Asignacion_ID,Factura,
 Nota_Venta,RFC,Cliente_SAP,Accnt_ID,Fecha_Proceso,Fecha_Pago,
 Importe,Saldo_Anterior,Numero_Pago,UUID_Venta,Status
FROM #D
WHERE Asignacion_ID IS NULL OR Factura IS NULL OR CHARINDEX('-',Factura)<=1
 OR RIGHT(Factura,1)='-' OR LEN(ISNULL(UUID_Venta,'NULL'))<=20
 OR Importe IS NULL OR Importe<=0 OR Saldo_Anterior IS NULL
 OR Saldo_Anterior<Importe OR Numero_Pago IS NULL
 OR Fecha_Proceso<=@Limite OR Fecha_Proceso IS NULL;

-- La multiplicidad global por ID afecta CHECK y generador, no solo el grupo.
SELECT '06_MULTIPLICIDAD_COBRANZA' Seccion,K.Asignacion_ID,COUNT_BIG(*) Cobranzas
FROM (SELECT DISTINCT Asignacion_ID FROM #D) K
JOIN T3.CFDI_Cobranza C ON C.Asignacion_ID=K.Asignacion_ID
GROUP BY K.Asignacion_ID HAVING COUNT_BIG(*)>1;

-- Simulacion exacta del conteo CHECK para el detalle proyectado: JOIN vuelve
-- a COBRANZA completa, como el SP. No modifica Accnt_ID a Contado.
SELECT '07_CHECK_PROYECTADO' Seccion,G.GrupoDiagnostico,X.Items,X.UUIDs,X.Contado,
 CASE WHEN X.UUIDs>0 AND X.UUIDs=X.Contado THEN 'MARCARIA CONTADO'
 WHEN X.Items>0 AND X.Items=X.UUIDs THEN 'PASA CONTEOS; FALTA VERSION Y GENERADOR'
 ELSE 'NO PASA CHECK' END Resultado
FROM #G G
OUTER APPLY (
 SELECT COUNT_BIG(*) Items,
 COUNT_BIG(CASE WHEN LEN(ISNULL(C.UUID_Venta,'NULL'))>20 THEN 1 END) UUIDs,
 COUNT_BIG(CASE WHEN CAST(C.Fecha_Asignacion AS date)=CAST(C.Fecha_Factura AS date)
 AND V.Metodo_Pago='PUE' THEN 1 END) Contado
 FROM #D D JOIN T3.CFDI_Cobranza C ON C.Asignacion_ID=D.Asignacion_ID
 JOIN T3.CFDI_Documentos V ON V.Nota_Venta=C.Nota_Venta
 WHERE D.GrupoDiagnostico=G.GrupoDiagnostico
) X;

SELECT '08_DOCUMENTOS_VENTA' Seccion,K.Nota_Venta,X.Documentos,X.PUE,X.PPD
FROM (SELECT DISTINCT C.Nota_Venta FROM #D D
 JOIN T3.CFDI_Cobranza C ON C.Asignacion_ID=D.Asignacion_ID) K
OUTER APPLY(SELECT COUNT_BIG(*) Documentos,
 COUNT_BIG(CASE WHEN Metodo_Pago='PUE' THEN 1 END) PUE,
 COUNT_BIG(CASE WHEN Metodo_Pago='PPD' THEN 1 END) PPD
 FROM T3.CFDI_Documentos V WHERE V.Nota_Venta=K.Nota_Venta) X;

SELECT '09_CLIENTES' Seccion,G.GrupoDiagnostico,G.Cliente_SAP,G.RFC RFCGrupo,
 C.RFC RFCCliente,C.Nombre,C.Codigo_Postal_3,
 (SELECT COUNT_BIG(*) FROM T3.MOV_CLIENTE M WHERE M.Cliente_SAP=G.Cliente_SAP) FilasCliente,
 (SELECT COUNT_BIG(*) FROM T3.TMD_EMAIL M WHERE M.Cliente_SAP=G.Cliente_SAP) FilasEmail
FROM #G G LEFT JOIN T3.MOV_CLIENTE C ON C.Cliente_SAP=G.Cliente_SAP;

-- Mismo denominador que ScrImpuestos. No realiza la division.
SELECT '10_BASES_IMPUESTOS' Seccion,K.Factura,X.FilasJoin,X.Denominador,
 CASE WHEN X.FilasJoin=0 OR X.Denominador IS NULL THEN 'FALTAN DATOS'
 WHEN X.Denominador=0 THEN 'DIVISION POR CERO' ELSE 'REVISAR IMPORTES Y MULTIPLICIDAD' END Estado
FROM (SELECT DISTINCT C.Factura FROM #D D
 JOIN T3.CFDI_Cobranza C ON C.Asignacion_ID=D.Asignacion_ID) K
OUTER APPLY (
 SELECT COUNT_BIG(*) FilasJoin,
 SUM(ISNULL(RFD.Valor_Subt,0)+ISNULL(RFD.Envio_Subt,0)+ISNULL(RFD.Credito_Subt,0)
 -ISNULL(U.Desglose_IEPS,0)*ISNULL(RFD.Valor_IEPS,0))
 +SUM(CASE WHEN ISNULL(RFD.Valor_IVA,0)<>0 THEN
 ISNULL(RFD.Valor_IVA,0)+ISNULL(RFD.Envio_IVA,0)+ISNULL(RFD.Credito_IVA,0) ELSE 0 END)
 +SUM(ISNULL(U.Desglose_IEPS,0)*ISNULL(RFD.Valor_IEPS,0)) Denominador
 FROM T3.REGISTRO_FISCAL RF
 JOIN T3.REGISTRO_FISCAL_DETALLE RFD ON RFD.Factura=RF.Factura
 JOIN T3.CFDI_USOCFDI_CLIENTE U ON U.Cliente_SAP=RF.Cliente_SAP
 WHERE RF.Factura=K.Factura
) X;

SELECT '11_PENDIENTES_ANTERIORES' Seccion,A.*,
 ISNULL(V.VersionCFDI,EAI_OWNER.GETCONV('CFG Settings','VersionCFDI')) VersionCFDI
FROM T3.CFDI_AGRUPACION_CTRL A
OUTER APPLY(SELECT MAX(Valor) VersionCFDI FROM T3.CFDI_RFC_SETTING
 WHERE RFC=A.RFC AND Parametro='VersionCFDI') V
WHERE A.Fecha_Envio IS NULL AND A.Fecha_Pago>='20220101' AND A.Accnt_ID<>'Contado';

SELECT '12_ALCANCE' Seccion,
 'Grupos proyectados, no creados. IDs diagnosticos no son Agrupacion. Pendientes anteriores requieren revisar tambien sus detalles, clientes e impuestos. El UPDATE inicial real puede tocar otras cobranzas recientes no elegibles; aqui solo se simulan las candidatas. Ninguna salida certifica timbrado.' Observacion;
DROP TABLE #D,#G,#P;


-- Muestra de filas que pasan los filtros baratos, sin buscar UUID/RFC por fila
-- en tablas grandes. TOP limita ANTES de ejecutar funciones o JOIN adicionales.
RAISERROR(N'Etapa M1: obtener hasta %d cobranzas para la muestra.',10,1,@MaxMuestra) WITH NOWAIT;
SELECT TOP(@MaxMuestra) IDENTITY(int,1,1) AS Fila,
 C.Asignacion_ID,C.Folio_ID,C.Factura,C.Nota_Venta,C.RFC,C.Cliente_SAP,
 C.Ctro,C.Sociedad,C.Importe,C.Saldo_Anterior,C.Numero_Pago,C.Fecha_Pago,
 C.Fecha_Factura,C.Fecha_Asignacion,C.Fecha_Proc_BATMD,C.Fecha_Proceso,
 C.Created_By,C.Status,C.UUID_Venta
INTO #Muestra
FROM T3.CFDI_COBRANZA C
WHERE C.Fecha_Envio IS NULL AND C.Via_Pago='01'
 AND C.UUID_Venta IS NOT NULL AND C.Created_By<>'INTERFACE'
 AND C.Fecha_Pago>='20200921' AND ISNULL(C.Status,'EMPTY') NOT IN('PendienteT3','Canc Pago');
SELECT '05M_ALCANCE_MUESTRA' AS Seccion,@MaxMuestra AS Limite,
 (SELECT COUNT_BIG(*) FROM #Muestra) AS FilasPreseleccionadas,
 N'Muestra sin orden; no es conteo global ni garantiza todas las asignaciones elegibles.' AS Alcance;

RAISERROR(N'Etapa M2: validar cada RFC distinto una vez y reutilizar la configuracion.',10,1) WITH NOWAIT;
SELECT DISTINCT RFC INTO #RFCs FROM #Muestra;
SELECT RFC,T3.FN_VALIDA_RFC(RFC) AS ValidacionRFC INTO #RFCValidado FROM #RFCs;
DECLARE @VersionGeneral varchar(99);
SELECT @VersionGeneral=ValorQueDevuelveGETCONV FROM #Config WHERE Clave='VersionCFDI';
SELECT S.RFC,MAX(S.Valor) AS VerCFD INTO #VersionRFC
FROM T3.CFDI_RFC_SETTING S INNER JOIN #RFCs R ON R.RFC=S.RFC
WHERE S.Parametro='VersionCFDI' GROUP BY S.RFC;

RAISERROR(N'Etapa M3: obtener documentos de las notas de la muestra.',10,1) WITH NOWAIT;
SELECT DISTINCT Nota_Venta INTO #Notas FROM #Muestra;
SELECT D.Nota_Venta,COUNT_BIG(*) AS Documentos,
 SUM(CASE WHEN D.Metodo_Pago<>'PUE' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS DocumentosNoPUE
INTO #DocumentosMuestra FROM T3.CFDI_DOCUMENTOS D
INNER JOIN #Notas N ON N.Nota_Venta=D.Nota_Venta GROUP BY D.Nota_Venta;

RAISERROR(N'Etapa M4: materializar una vez las referencias de error y armar candidatos de la muestra.',10,1) WITH NOWAIT;
-- Mantener el conjunto global de referencias no NULL conserva incluso la
-- semantica de NOT IN con Asignacion_ID NULL. Se lee una sola vez.
SELECT DISTINCT Referencia INTO #ReferenciasError FROM T3.RF_ERROR_LOG
WHERE Referencia IS NOT NULL AND RUTINA LIKE '%GENERAR_PAGO%';
SELECT C.*,R.ValidacionRFC,ISNULL(V.VerCFD,@VersionGeneral) AS VersionCFD,
 CAST(1 AS int) AS PasaUUID,CAST(1 AS int) AS PasaOrigen,
 CAST(1 AS int) AS PasaFecha,CAST(1 AS int) AS PasaStatus,
 CASE WHEN C.Asignacion_ID NOT IN(SELECT Referencia FROM #ReferenciasError) THEN 1 ELSE 0 END AS PasaBitacora,
 ISNULL(D.Documentos,0) AS Documentos,D.DocumentosNoPUE
INTO #Base FROM #Muestra C LEFT JOIN #RFCValidado R
 ON R.RFC=C.RFC OR (R.RFC IS NULL AND C.RFC IS NULL)
LEFT JOIN #VersionRFC V ON V.RFC=C.RFC
LEFT JOIN #DocumentosMuestra D ON D.Nota_Venta=C.Nota_Venta;

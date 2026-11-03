/*
  SOLO LECTURA de datos permanentes. No ejecuta DELIVERY_TO_REMISION ni sus SP,
  no cambia CREATED, no elimina cabeceras y no genera/reprocesa remisiones.
  Las variables de tabla solo organizan los resultados de esta consulta.

  Alcance: dia del servidor, con horas opcionales, y entregas del rango exportado
  desde Oracle. Las remisiones y folios existentes son ESTADO ACTUAL, no prueba
  de insercion en una ejecucion concreta. El coordinador no crea PID propio.
  Fecha_Trn se reduce un segundo por remision; puede caer antes del inicio real.
  Los logs de DELIVERY_IDOC_TO_REMISION comparten la etiqueta del coordinador.
  El filtro del cursor se reproduce desde el fuente local: Created > medianoche,
  SIN limite superior. La definicion instalada puede consultarse con el parametro.
*/
USE [T3QA];
SET NOCOUNT ON;
DECLARE @Captura datetime=GETDATE();
DECLARE @DiaEjecucion date=CONVERT(date,@Captura);
DECLARE @Desde datetime2(0)=CONVERT(datetime2(0),@DiaEjecucion),
        @Hasta datetime2(0)=DATEADD(DAY,1,CONVERT(datetime2(0),@DiaEjecucion));
-- Para acotar errores y Fecha_Trn: sustituir @Desde/@Hasta por horas conocidas.
-- @DiaEjecucion debe corresponder al dia en que se ejecuto el SP (filtro Created).
DECLARE @DesdeOrigen datetime=CONVERT(datetime,'20260731',112);
DECLARE @Delivery varchar(50)=NULL; -- Opcional: '2656613453'.
DECLARE @VerDefinicion bit=0;

SELECT '00_CONTEXTO' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,@Captura Captura,
       @DiaEjecucion DiaFiltroCursor,@Desde DesdeIncluido,@Hasta HastaExcluido,
       @DesdeOrigen CorteHistoricoDeContexto,@Delivery DeliverySeleccionada;
SELECT '00_MODULO_INSTALADO' Seccion,O.name,O.modify_date FechaDeALTER_NoEsUltimaEjecucion,
       CONVERT(varchar(64),HASHBYTES('SHA2_256',M.definition),2) HashDefinicion
FROM sys.objects O LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id=OBJECT_ID('T3.DELIVERY_TO_REMISION');
IF @VerDefinicion=1
    SELECT OBJECT_DEFINITION(OBJECT_ID('T3.DELIVERY_TO_REMISION')) AS DefinicionInstalada
    FOR XML PATH('Modulo'),TYPE;

SELECT '01_FILTRO_DE_ORIGEN' Seccion,COUNT_BIG(*) FilasEnDeliveryHist,
       MIN(H.Created) CreatedMinimo,MAX(H.Created) CreatedMaximo,
       COUNT_BIG(CASE WHEN H.Created>CONVERT(datetime,@DiaEjecucion) THEN 1 END) FilasQuePasanCreatedDelSP,
       COUNT_BIG(CASE WHEN H.Created=CONVERT(datetime,@DiaEjecucion) THEN 1 END) FilasEnMedianocheExcluidas,
       COUNT_BIG(CASE WHEN H.Created IS NULL THEN 1 END) CreatedNull,
       COUNT_BIG(CASE WHEN H.Delivery IS NULL THEN 1 END) DeliveryNull,
       CASE WHEN COUNT_BIG(CASE WHEN H.Created>CONVERT(datetime,@DiaEjecucion) THEN 1 END)=0
            THEN 'NO HAY FILAS QUE CUMPLAN CREATED DEL CURSOR EN EL ESTADO ACTUAL'
            ELSE 'HAY FILAS POR FECHA; FALTA VALIDAR SOCIEDAD Y SALIDAS' END Interpretacion
FROM T3.Delivery_Hist H
WHERE @Delivery IS NULL OR H.Delivery COLLATE DATABASE_DEFAULT=@Delivery COLLATE DATABASE_DEFAULT;

DECLARE @Entregas table(Delivery varchar(50) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY);
INSERT @Entregas
SELECT H.Delivery COLLATE DATABASE_DEFAULT FROM T3.Delivery_Hist H
WHERE H.Created>@DesdeOrigen AND H.Delivery IS NOT NULL
  AND (@Delivery IS NULL OR H.Delivery COLLATE DATABASE_DEFAULT=@Delivery COLLATE DATABASE_DEFAULT)
UNION
SELECT R.Factura COLLATE DATABASE_DEFAULT FROM T3.Remision_General R
WHERE R.Fecha_Trn>=@Desde AND R.Fecha_Trn<@Hasta AND R.Factura IS NOT NULL
  AND (@Delivery IS NULL OR R.Factura COLLATE DATABASE_DEFAULT=@Delivery COLLATE DATABASE_DEFAULT)
UNION
SELECT E.ID COLLATE DATABASE_DEFAULT FROM EAI_OWNER.MX_EAI_MESSAGE_LOG E
WHERE E.Created>=@Desde AND E.Created<@Hasta AND E.Queue_Name='DELIVERY_TO_REMISION' AND E.ID IS NOT NULL
  AND (@Delivery IS NULL OR E.ID COLLATE DATABASE_DEFAULT=@Delivery COLLATE DATABASE_DEFAULT);

-- Mismos grupos y normalizacion de cabecera del cursor principal. No se usa
-- DISTINCT Delivery para ocultar grupos de cabecera diferentes de una entrega.
DECLARE @Grupos table(
    Delivery varchar(50) COLLATE DATABASE_DEFAULT NULL,PickDate datetime NULL,
    PurchaseOrder varchar(50) NULL,DeliveryType varchar(20) NULL,
    Sociedad varchar(10) COLLATE DATABASE_DEFAULT NULL,Plant varchar(20) NULL,
    ShippingPoint varchar(20) NULL,ShiptoParty varchar(100) NULL,
    ShiptoParty_New varchar(100) NULL,ShippingPlace varchar(100) NULL,
    ShippingName varchar(100) NULL,ShippingCtro varchar(10) NULL,
    Items bigint NULL,CoincidenciasSociedad bigint NULL);
INSERT @Grupos(Delivery,PickDate,PurchaseOrder,DeliveryType,Sociedad,Plant,ShippingPoint,
    ShiptoParty,ShiptoParty_New,ShippingPlace,ShippingName,ShippingCtro,Items)
SELECT H.Delivery,H.PickDate,H.PurchaseOrder,H.DeliveryType,ISNULL(H.Sociedad,'MX16'),
    H.Plant,H.ShippingPoint,H.ShiptoParty,
    CASE WHEN LEFT(H.ShiptoParty,6)='PC-00-' THEN SUBSTRING(H.ShiptoParty,7,4)
         WHEN H.SoldtoParty IS NOT NULL THEN RIGHT('0000000000'+H.SoldtoParty,10)
         WHEN H.ShiptoParty IS NULL THEN '' ELSE RIGHT('0000000000'+H.ShiptoParty,10) END,
    H.ShiptoPartyLoc,H.ShiptoPartyName,
    MAX(CASE WHEN LEFT(H.ShiptoParty,6)='PC-00-' THEN SUBSTRING(H.ShiptoParty,7,4) ELSE '0000' END),
    COUNT_BIG(H.Material)
FROM T3.Delivery_Hist H
WHERE H.Created>CONVERT(datetime,@DiaEjecucion)
  AND (@Delivery IS NULL OR H.Delivery COLLATE DATABASE_DEFAULT=@Delivery COLLATE DATABASE_DEFAULT)
GROUP BY H.Delivery,H.PickDate,H.PurchaseOrder,H.DeliveryType,ISNULL(H.Sociedad,'MX16'),
    H.Plant,H.ShippingPoint,H.ShiptoParty,
    CASE WHEN LEFT(H.ShiptoParty,6)='PC-00-' THEN SUBSTRING(H.ShiptoParty,7,4)
         WHEN H.SoldtoParty IS NOT NULL THEN RIGHT('0000000000'+H.SoldtoParty,10)
         WHEN H.ShiptoParty IS NULL THEN '' ELSE RIGHT('0000000000'+H.ShiptoParty,10) END,
    H.ShiptoPartyLoc,H.ShiptoPartyName;
UPDATE G SET CoincidenciasSociedad=S.N
FROM @Grupos G OUTER APPLY(SELECT COUNT_BIG(*) N FROM EAI.ZSDFE_Soc S
    WHERE S.BUKRS COLLATE DATABASE_DEFAULT=G.Sociedad
      AND S.KUNNR COLLATE DATABASE_DEFAULT=G.Sociedad) S;

SELECT '02_GRUPOS_DEL_CURSOR_ACTUAL' Seccion,G.*,
    CASE WHEN CoincidenciasSociedad=0 THEN 'EXCLUIDO POR JOIN DE SOCIEDAD'
         WHEN CoincidenciasSociedad>1 THEN 'SOCIEDAD DUPLICADA; MULTIPLICA EL CURSOR'
         ELSE 'PASA FECHA Y SOCIEDAD' END ValidacionSociedad,
    CASE WHEN EXISTS(SELECT 1 FROM T3.Remision_General R
                     WHERE R.Factura COLLATE DATABASE_DEFAULT=G.Delivery)
         THEN 'CABECERA ACTUAL EXISTE: EL SP LA OMITE AL LEERLA'
         ELSE 'SIN CABECERA ACTUAL: PENDIENTE O INTENTO FALLIDO' END EstadoActual
FROM @Grupos G ORDER BY G.Delivery;

DECLARE @Revision table(
    Delivery varchar(50) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
    FilasOrigen bigint NULL,GruposPorFecha bigint NULL,GruposConSociedad bigint NULL,
    LineasEsperadasSegunJoinDetalle bigint NULL,CabecerasActuales bigint NULL,
    CabecerasFechaTrnEnRango bigint NULL,DetallesActuales bigint NULL,
    DuplicadosNumeroLinea bigint NULL,DetallesConUnidadNumerica bigint NULL,DetallesSinMaterialDeOrigen bigint NULL,
    CabecerasSinSerieOFolio bigint NULL,RelacionesREMActuales bigint NULL);
INSERT @Revision
SELECT E.Delivery,
    (SELECT COUNT_BIG(*) FROM T3.Delivery_Hist H WHERE H.Delivery COLLATE DATABASE_DEFAULT=E.Delivery),
    (SELECT COUNT_BIG(*) FROM @Grupos G WHERE G.Delivery=E.Delivery),
    (SELECT COUNT_BIG(*) FROM @Grupos G WHERE G.Delivery=E.Delivery AND G.CoincidenciasSociedad>0),
    -- El detalle del SP lee TODO el historial de la delivery y hace LEFT JOIN
    -- con Material. Contar ese JOIN incluye su posible multiplicacion.
    (SELECT COUNT_BIG(*) FROM T3.Delivery_Hist H LEFT JOIN T3.Material M
      ON M.Material COLLATE DATABASE_DEFAULT=H.Material COLLATE DATABASE_DEFAULT
      WHERE H.Delivery COLLATE DATABASE_DEFAULT=E.Delivery),
    (SELECT COUNT_BIG(*) FROM T3.Remision_General R WHERE R.Factura COLLATE DATABASE_DEFAULT=E.Delivery),
    (SELECT COUNT_BIG(*) FROM T3.Remision_General R WHERE R.Factura COLLATE DATABASE_DEFAULT=E.Delivery
      AND R.Fecha_Trn>=@Desde AND R.Fecha_Trn<@Hasta),
    (SELECT COUNT_BIG(*) FROM T3.Remision_Detalle D WHERE D.Factura COLLATE DATABASE_DEFAULT=E.Delivery),
    (SELECT COUNT_BIG(*) FROM (SELECT D.Num_Linea FROM T3.Remision_Detalle D
      WHERE D.Factura COLLATE DATABASE_DEFAULT=E.Delivery GROUP BY D.Num_Linea HAVING COUNT_BIG(*)>1) X),
    (SELECT COUNT_BIG(*) FROM T3.Remision_Detalle D WHERE D.Factura COLLATE DATABASE_DEFAULT=E.Delivery
      AND NULLIF(LTRIM(RTRIM(D.UnidadMedida)),'') IS NOT NULL
      AND TRY_CONVERT(decimal(22,7),D.UnidadMedida) IS NOT NULL),
    (SELECT COUNT_BIG(*) FROM T3.Remision_Detalle D WHERE D.Factura COLLATE DATABASE_DEFAULT=E.Delivery
      AND NOT EXISTS(SELECT 1 FROM T3.Delivery_Hist H
          WHERE H.Delivery COLLATE DATABASE_DEFAULT=E.Delivery
            AND H.Material COLLATE DATABASE_DEFAULT=D.Material COLLATE DATABASE_DEFAULT)),
    (SELECT COUNT_BIG(*) FROM T3.Remision_General R WHERE R.Factura COLLATE DATABASE_DEFAULT=E.Delivery
      AND (NULLIF(LTRIM(RTRIM(R.Remision_Serie)),'') IS NULL OR NULLIF(LTRIM(RTRIM(R.Remision_Folio)),'') IS NULL)),
    (SELECT COUNT_BIG(*) FROM EAI_OWNER.MX_NRIV_RELACION N WHERE N.FacturaSAP COLLATE DATABASE_DEFAULT=E.Delivery
      AND N.Clase_Factura='REM')
FROM @Entregas E;

SELECT '03_VALIDACION_POR_DELIVERY' Seccion,R.*,
    CASE WHEN CabecerasActuales>1 THEN 'REVISAR: CABECERAS DUPLICADAS'
         WHEN CabecerasActuales=0 AND DetallesActuales>0 THEN 'REVISAR: DETALLE SIN CABECERA'
         WHEN CabecerasActuales>0 AND DetallesActuales=0 THEN 'REVISAR: CABECERA SIN DETALLE'
         WHEN DuplicadosNumeroLinea>0 THEN 'REVISAR: NUMEROS DE LINEA DUPLICADOS'
         WHEN DetallesConUnidadNumerica>0 THEN 'REVISAR: UNIDAD NUMERICA; POSIBLE CRUCE DE FETCH'
         WHEN DetallesSinMaterialDeOrigen>0 THEN 'REVISAR: MATERIAL DEL DETALLE SIN CORRESPONDENCIA EN ORIGEN'
         WHEN CabecerasActuales>0 AND CabecerasSinSerieOFolio>0 THEN 'REVISAR: SERIE/FOLIO VACIOS'
         WHEN CabecerasActuales>0 AND LineasEsperadasSegunJoinDetalle>0
              AND DetallesActuales<>LineasEsperadasSegunJoinDetalle THEN 'REVISAR: NUMERO DE DETALLES DIFERENTE DEL ORIGEN'
         WHEN CabecerasActuales>0 AND RelacionesREMActuales<>1 THEN 'REVISAR: RELACION DE FOLIO REM AUSENTE O MULTIPLE'
         WHEN CabecerasActuales>0 THEN 'HAY SALIDA ACTUAL; REVISAR DATOS Y FOLIOS, NO ACREDITA ALTA DE ESTA CORRIDA'
         WHEN GruposConSociedad>0 THEN 'SIN SALIDA: CANDIDATA ACTUAL O EJECUCION INTERRUMPIDA'
         WHEN GruposPorFecha>0 THEN 'SIN SALIDA: JOIN DE SOCIEDAD EXCLUYE EL ORIGEN'
         ELSE 'FUERA DEL FILTRO CREATED ACTUAL; HISTORICA O SOLO CONTEXTO DE LOG' END Diagnostico
FROM @Revision R ORDER BY R.Delivery;

SELECT '04_RESUMEN' Seccion,
    (SELECT COUNT_BIG(*) FROM @Grupos) GruposPorFecha,
    (SELECT COUNT_BIG(*) FROM @Grupos WHERE CoincidenciasSociedad>0) GruposConSociedad,
    (SELECT COUNT_BIG(*) FROM @Revision WHERE GruposConSociedad>0 AND CabecerasActuales=0) EntregasCandidatasSinCabecera,
    (SELECT COUNT_BIG(*) FROM @Revision WHERE CabecerasActuales>0 AND DetallesActuales=0) EntregasConCabeceraSinDetalle,
    (SELECT COUNT_BIG(*) FROM @Revision WHERE DetallesConUnidadNumerica>0) EntregasConUnidadNumerica,
    (SELECT COUNT_BIG(*) FROM @Revision WHERE CabecerasActuales>1) EntregasConCabecerasDuplicadas;

SELECT '05_CABECERAS_ACTUALES' Seccion,R.*,
    CASE WHEN R.Fecha_Trn>=@Desde AND R.Fecha_Trn<@Hasta THEN 1 ELSE 0 END FechaTrnEnRango
FROM T3.Remision_General R
WHERE EXISTS(SELECT 1 FROM @Entregas E WHERE E.Delivery=R.Factura COLLATE DATABASE_DEFAULT)
ORDER BY R.Factura,R.Fecha_Trn;
SELECT '06_DETALLES_ACTUALES' Seccion,D.*,
    CASE WHEN NULLIF(LTRIM(RTRIM(D.UnidadMedida)),'') IS NOT NULL
              AND TRY_CONVERT(decimal(22,7),D.UnidadMedida) IS NOT NULL
         THEN 'UNIDAD NUMERICA: REVISAR POSICIONES DEL FETCH' ELSE '' END Observacion
FROM T3.Remision_Detalle D
WHERE EXISTS(SELECT 1 FROM @Entregas E WHERE E.Delivery=D.Factura COLLATE DATABASE_DEFAULT)
ORDER BY D.Factura,D.Num_Linea;

-- Esta tabla NO tiene fecha de alta: su presencia no prueba insercion hoy.
SELECT '07_RELACIONES_DE_FOLIO_REM_ACTUALES' Seccion,N.*,
    CASE WHEN EXISTS(SELECT 1 FROM T3.Remision_General R
         WHERE R.Factura COLLATE DATABASE_DEFAULT=N.FacturaSAP COLLATE DATABASE_DEFAULT
           AND (R.Remision_Serie+'-'+R.Remision_Folio) COLLATE DATABASE_DEFAULT=N.FacturaT3 COLLATE DATABASE_DEFAULT)
         THEN 'COINCIDE CON SERIE/FOLIO DE CABECERA ACTUAL'
         ELSE 'REVISAR: RELACION SIN CABECERA/FOLIO COINCIDENTE' END Validacion
FROM EAI_OWNER.MX_NRIV_RELACION N
WHERE N.Clase_Factura='REM'
  AND EXISTS(SELECT 1 FROM @Entregas E WHERE E.Delivery=N.FacturaSAP COLLATE DATABASE_DEFAULT)
ORDER BY N.FacturaSAP;

-- Mostrar todos los errores de estos helpers en el rango: sus referencias
-- pueden ser centro/sociedad, no delivery. No aplicar un JOIN que los oculte.
SELECT '08_ERRORES_DEL_RANGO' Seccion,E.Created,E.Queue_Name,E.ID,E.REFERENCE,
       E.Siebel_Error_Code,E.Siebel_Error_Message,E.Source,E.Job_PID,
       CASE WHEN E.Queue_Name='DELIVERY_TO_REMISION' THEN 'ID ES DELIVERY; ETIQUETA COMPARTIDA CON DELIVERY_IDOC_TO_REMISION'
            ELSE 'HELPER COMPARTIDO; REFERENCIA PUEDE SER CENTRO O SOCIEDAD/CLASE' END Alcance
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG E
WHERE E.Created>=@Desde AND E.Created<@Hasta
  AND E.Queue_Name IN ('DELIVERY_TO_REMISION','GET_REMISION_INFO','Folio Interno')
ORDER BY E.Created,E.Queue_Name;

-- Compara posiciones del SELECT de detalle con el FETCH del fuente local.
-- No genera remisiones. getConv es una funcion de consulta del catalogo actual.
-- Solo las filas que pasan fecha/sociedad hoy, pero se revisa TODO su historial.
SELECT '09_RIESGO_DE_FETCH_EN_DETALLE' Seccion,H.Delivery,H.Created,H.Material,H.MaterialName,
       H.Quantity CantidadOrigen,H.UnitMeasure UnidadOrigen,M.Unidad_Med_Vta UnidadCatalogo,
       X.UnidadPosicion5,TRY_CONVERT(numeric(22,7),X.UnidadPosicion5) ConversionActualHaciaCantidad,
       CASE WHEN X.UnidadPosicion5 IS NOT NULL AND TRY_CONVERT(numeric(22,7),X.UnidadPosicion5) IS NULL
            THEN 'RIESGO: UNIDAD NO CONVERTIBLE A LA VARIABLE NUMERICA DEL FETCH LOCAL'
            ELSE 'REVISAR TAMBIEN CANTIDAD/UNIDAD DEL FETCH INSTALADO' END Diagnostico
FROM T3.Delivery_Hist H LEFT JOIN T3.Material M
  ON M.Material COLLATE DATABASE_DEFAULT=H.Material COLLATE DATABASE_DEFAULT
CROSS APPLY(SELECT ISNULL(M.Unidad_Med_Vta,EAI_OWNER.getConv('ECC_V3 UOM',H.UnitMeasure)) UnidadPosicion5) X
WHERE EXISTS(SELECT 1 FROM @Grupos G WHERE G.Delivery=H.Delivery COLLATE DATABASE_DEFAULT AND G.CoincidenciasSociedad>0)
ORDER BY H.Delivery,H.Material;

SELECT '10_CENTROS_SOCIEDADES_ACTUALES' Seccion,C.*
FROM T3.REMISION_CTRO_SOCIEDAD C
WHERE EXISTS(SELECT 1 FROM @Grupos G WHERE G.CoincidenciasSociedad>0
    AND (C.Ctro COLLATE DATABASE_DEFAULT=G.Plant COLLATE DATABASE_DEFAULT
      OR C.Ctro COLLATE DATABASE_DEFAULT=G.ShippingCtro COLLATE DATABASE_DEFAULT))
ORDER BY C.Ctro,C.Sociedad;

SELECT '11_AVISO_DE_INTERPRETACION' Seccion,
    'Sin PID/auditoria propia no se puede atribuir cada fila a esta ejecucion. Fecha_Trn y folios muestran estado, no prueba completa de alta.' Mensaje
UNION ALL
SELECT '11_AVISO_DE_INTERPRETACION',
    'Una cabecera existente impide que el SP regenere su detalle. No reejecutar ni desmarcar para reparar antes de revisar las inconsistencias.';

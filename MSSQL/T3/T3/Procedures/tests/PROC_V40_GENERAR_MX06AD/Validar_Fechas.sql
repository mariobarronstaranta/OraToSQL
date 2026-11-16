-- Run.ps1 reemplaza los marcadores por expresiones extraidas del procedimiento.
-- Prueba aislada; no escribe tablas de negocio.
SET NOCOUNT ON;
DECLARE @Casos table(Id int, Fecha datetime, Hora varchar(8), EsperadoFecha varchar(8), EsperadoPedido varchar(14));
INSERT @Casos VALUES
(1,CONVERT(datetime,'20261109',112),'13:14:15','09112026','09112026131415'),
(2,CONVERT(datetime,'20000229',112),'00:00:00','29022000','29022000000000'),
(3,CONVERT(datetime,'19991231',112),'23:59:59','31121999','31121999235959'),
(4,NULL,NULL,NULL,''),
(5,CONVERT(datetime,'20260102',112),NULL,'02012026','02012026'),
(6,NULL,'13:14:15',NULL,'131415');

DECLARE @Actual table(Id int, FePedido varchar(50), FeNotaEnt varchar(50), FecPedimento varchar(50));
INSERT @Actual
SELECT c.Id, /*FePedido*/, /*FeNotaEnt*/, /*FecPedimento*/
FROM @Casos c;
IF EXISTS (
    SELECT 1 FROM @Actual a JOIN @Casos c ON c.Id=a.Id
    WHERE a.FePedido IS NULL OR a.FePedido<>c.EsperadoPedido
       OR ISNULL(a.FeNotaEnt,'<NULL>')<>ISNULL(c.EsperadoFecha,'<NULL>')
       OR a.FecPedimento IS NULL OR a.FecPedimento<>ISNULL(c.EsperadoFecha,'')
       OR a.FePedido LIKE '%/%' OR a.FeNotaEnt LIKE '%/%' OR a.FecPedimento LIKE '%/%'
)
    THROW 51000, 'Fecha/hora distinta del formato Oracle o cambio de tratamiento de NULL.', 1;
PRINT 'OK: fechas DDMMYYYY, anio completo, ceros iniciales, bisiesto, hora y NULL.';

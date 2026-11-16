-- Pruebas aisladas de etapa 1. No ejecuta el SP ni modifica tablas de negocio.
SET NOCOUNT ON;
SET CONCAT_NULL_YIELDS_NULL ON;

DECLARE @resultado varchar(max), @campo varchar(30) = NULL;
SET @resultado = CONCAT(CAST('LINE|previo|' AS varchar(max)), @campo, '|', 'siguiente', '|');
IF @resultado <> 'LINE|previo||siguiente|' OR @resultado IS NULL
    THROW 51000, 'NULL debe conservar campos y separadores.', 1;

-- Numeros/fechas se formatean antes de concatenar: no cambia escala por CONCAT.
DECLARE @importe decimal(22,2) = 123.40;
DECLARE @anterior varchar(max) = 'TAX|' + CONVERT(varchar(30), @importe) + '|';
SET @resultado = CONCAT('TAX|', CONVERT(varchar(30), @importe), '|');
IF @resultado <> @anterior THROW 51000, 'Cambio de formato numerico.', 1;

-- Dos articulos y ambas ramas de addenda. El primero tiene pedimento, el segundo no.
DECLARE @casos table(Addenda varchar(2), Articulo int, Pedimento varchar(30));
INSERT @casos VALUES ('NO',1,'PED-1'),('NO',2,NULL),('SI',1,'PED-1'),('SI',2,NULL);
DECLARE @addenda varchar(2), @articulo int, @pedOrigen varchar(30);
DECLARE @pedimentos varchar(max), @orden varchar(60) = '', @linea varchar(max);
DECLARE casos CURSOR LOCAL FAST_FORWARD FOR
    SELECT Addenda, Articulo, Pedimento FROM @casos ORDER BY Addenda, Articulo;
OPEN casos;
FETCH NEXT FROM casos INTO @addenda,@articulo,@pedOrigen;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @pedimentos = '';
    IF @addenda <> 'SI'
        SET @pedimentos = CONCAT(@pedimentos,@pedOrigen);
    SET @linea = CONCAT(CAST('LINE|' AS varchar(max)),@pedimentos,'|',@orden,'|');
    IF @linea IS NULL THROW 51000, 'Linea anulada por NULL.', 1;
    IF @addenda='NO' AND @articulo=1 AND @linea <> 'LINE|PED-1||'
        THROW 51000, 'Se perdio el pedimento presente.', 1;
    IF (@addenda='SI' OR @articulo=2) AND @linea <> 'LINE|||'
        THROW 51000, 'Pedimento u orden heredados de otra iteracion.', 1;
    FETCH NEXT FROM casos INTO @addenda,@articulo,@pedOrigen;
END;
CLOSE casos;
DEALLOCATE casos;

-- Supera tanto 4000 como 8000 bytes, verificando el sufijo y los limites intermedios.
DECLARE @cabecera varchar(max) = REPLICATE(CAST('X' AS varchar(max)),9000);
SET @cabecera = CONCAT(@cabecera,NULL,'|FIN|');
IF DATALENGTH(@cabecera) <> 9005 OR RIGHT(@cabecera,5) <> '|FIN|'
    THROW 51000, 'Truncamiento de acumulador MAX.', 1;

-- Regresion reproducida: declarar antes de asignar captura el valor NULL.
DECLARE @ordenCursor varchar(60), @recibido varchar(60);
DECLARE ordenes CURSOR LOCAL FORWARD_ONLY STATIC FOR SELECT @ordenCursor;
SET @ordenCursor = '';
OPEN ordenes;
FETCH NEXT FROM ordenes INTO @recibido;
IF @recibido IS NOT NULL
    THROW 51000, 'Cambio de comportamiento: revisar captura en DECLARE.', 1;
CLOSE ordenes;
DEALLOCATE ordenes;

-- Correccion: asignar ANTES de DECLARE y recrear el cursor por cada filtro.
DECLARE @filas table(id int);
INSERT @filas VALUES(1),(2);
DECLARE @filtro int = 1, @id int;
WHILE @filtro <= 2
BEGIN
    SET @ordenCursor = '';
    DECLARE porFila CURSOR LOCAL FORWARD_ONLY STATIC FOR
        SELECT id, @ordenCursor FROM @filas WHERE id=@filtro;
    OPEN porFila;
    FETCH NEXT FROM porFila INTO @id,@recibido;
    IF @@FETCH_STATUS <> 0 OR @id <> @filtro OR @recibido IS NULL OR DATALENGTH(@recibido) <> 0
        THROW 51000, 'Filtro/orden capturados incorrectamente.', 1;
    CLOSE porFila;
    DEALLOCATE porFila;
    SET @filtro += 1;
END;
PRINT 'OK: NULL, delimitadores, formato, addenda SI/NO, reinicio por item, 9005 bytes y captura/recreacion de cursores.';

-- Plantilla para Run.ps1: inserta el JOIN extraido del procedimiento real.
-- Solo usa variables de tabla; no ejecuta el procedimiento ni escribe datos de negocio.
SET NOCOUNT ON;
DECLARE @RF table(Factura varchar(30), Cliente_SAP varchar(10));
DECLARE @UsoC table(Cliente_SAP varchar(10), Desglose_IEPS int, Uso_Devolucion varchar(4));
INSERT @RF VALUES('SIN_CONFIG','C1'),('CON_CONFIG','C2'),('DUPLICADOS','C3'),('CLIENTE_NULL',NULL);
INSERT @UsoC VALUES('C2',1,'G02'),('C3',0,'G01'),('C3',1,'G02'),('OTRO',1,'G03');
DECLARE @Resultado table(Factura varchar(30), ClienteConfig varchar(10), Desglose int, Uso varchar(4));
INSERT @Resultado
SELECT RF.Factura, UsoC.Cliente_SAP, ISNULL(UsoC.Desglose_IEPS,0), ISNULL(UsoC.Uso_Devolucion,'DEF')
FROM @RF RF
/*JOIN_BAJO_PRUEBA*/;

IF (SELECT COUNT(*) FROM @Resultado WHERE Factura='SIN_CONFIG' AND ClienteConfig IS NULL AND Desglose=0 AND Uso='DEF') <> 1
    THROW 51000, 'La factura sin configuracion debe conservarse con valores alternativos.', 1;
IF (SELECT COUNT(*) FROM @Resultado WHERE Factura='CON_CONFIG' AND ClienteConfig='C2' AND Desglose=1 AND Uso='G02') <> 1
    THROW 51000, 'No se respetaron la coincidencia y los datos de configuracion.', 1;
IF (SELECT COUNT(*) FROM @Resultado WHERE Factura='DUPLICADOS') <> 2
    THROW 51000, 'Cambiar a LEFT no debe deduplicar una relacion que Oracle permite.', 1;
IF (SELECT COUNT(*) FROM @Resultado WHERE Factura='CLIENTE_NULL' AND ClienteConfig IS NULL) <> 1
    THROW 51000, 'El JOIN debe conservar la fila izquierda sin clave coincidente.', 1;
IF (SELECT COUNT(*) FROM @Resultado) <> 5 OR EXISTS(SELECT 1 FROM @Resultado WHERE ClienteConfig='OTRO')
    THROW 51000, 'Filas extra o condicion de enlace incorrecta.', 1;
PRINT 'OK: JOIN real de ScrDatos conserva factura sin configuracion, coincidencias, NULL y multiplicidad Oracle.';

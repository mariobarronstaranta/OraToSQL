SET NOCOUNT ON;
-- Reproductor independiente: comprueba la captura del filtro al DECLARE.
DECLARE @Filtro varchar(30),@Recuperado varchar(30),@Estado int;
DECLARE Antes CURSOR LOCAL FOR SELECT Factura FROM T3.ASIGNACION_PAGO WHERE Factura=@Filtro;
SET @Filtro='F1';
OPEN Antes;
FETCH NEXT FROM Antes INTO @Recuperado;
SET @Estado=@@FETCH_STATUS;
CLOSE Antes; DEALLOCATE Antes;
IF @Estado<>-1 OR @Recuperado IS NOT NULL
 THROW 52020,'No se reprodujo la captura del filtro NULL al declarar el cursor.',1;
DECLARE Despues CURSOR LOCAL FOR SELECT Factura FROM T3.ASIGNACION_PAGO WHERE Factura=@Filtro;
OPEN Despues;
FETCH NEXT FROM Despues INTO @Recuperado;
SET @Estado=@@FETCH_STATUS;
CLOSE Despues; DEALLOCATE Despues;
IF @Estado<>0 OR @Recuperado<>'F1'
 THROW 52021,'Cursor declarado despues de asignar filtro no recupero la factura.',1;
PRINT 'PASS causa reproducida: DECLARE antes de SET no encuentra filas; despues de SET si';

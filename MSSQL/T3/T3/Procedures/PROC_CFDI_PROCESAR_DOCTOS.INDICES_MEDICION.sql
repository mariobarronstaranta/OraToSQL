/* Ejecutar en T3QA desde SQL Server Management Studio.
   1. Ajustar la fecha a un dia con documentos y agrupados representativos.
   2. Activar Incluir plan de ejecucion real (Ctrl+M) ANTES de ejecutar.
   3. Ejecutar todo y conservar Mensajes y los planes de ambos SELECT.
   Solo lectura de tablas de negocio: no llama al procedimiento ni genera CFDI.
   Los SELECT pueden consumir recursos; usar una ventana adecuada de QA.
*/
SET NOCOUNT ON;
DECLARE @dtFechaProcBATMD DATETIME = '20261014'; -- Mismo dia de la medicion inicial.
SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaMedicion,
       CAST(@dtFechaProcBATMD AS DATE) AS DiaEvaluado;

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Consulta: ScrIndPrompt
SELECT Paso.Factura, Paso.Ctro, Paso.Fecha_Factura_T3
          FROM T3.CFDI_Documento_Paso Paso
          INNER JOIN T3.Factura_General FG ON Paso.Factura = FG.Factura
          WHERE CAST(Paso.Fecha_Proc_BATMD AS DATE) = CAST(@dtFechaProcBATMD AS DATE)
            AND Paso.VoidDoc          IS NULL
            AND ( ( Paso.RFC_Cliente      != 'XAXX010101000' )
               OR ( Paso.Tipo_Docto       IN ( 'Z024', 'C024' ) ) ) ;

-- Consulta: ScrAgrPrompt
SELECT Ctro, Ubicacion, Fecha_Factura_T3, Lista_Precio, Cliente_Agrupado, Tipo_Docto,
               SUBSTRING( Factura, 1, CHARINDEX( '-', Factura ) )                AS Serie          ,
               MAX( Factura )                                                    AS Ultima_Factura ,
               MAX( Fecha_Factura_V3 )                                           AS Ultima_Hora    ,
               MAX( CAST( 
                   SUBSTRING( Factura, CHARINDEX( '-', Factura ) + 1 , 6 ) AS NUMERIC ) )
                                                                                 AS Ultimo_Folio
        FROM T3.CFDI_Documento_Paso Paso
        WHERE CAST(Paso.Fecha_Proc_BATMD AS DATE) = CAST(@dtFechaProcBATMD AS DATE)
          AND Paso.RFC_Cliente       = 'XAXX010101000' 
          AND Paso.VoidDoc          IS NULL         
          AND Paso.Tipo_Docto       NOT IN ( 'Z024', 'C024' )
        GROUP BY Ctro, Ubicacion, Fecha_Factura_T3, Lista_Precio, Cliente_Agrupado, Tipo_Docto,
                 SUBSTRING( Factura, 1, CHARINDEX( '-', Factura ) ) ;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

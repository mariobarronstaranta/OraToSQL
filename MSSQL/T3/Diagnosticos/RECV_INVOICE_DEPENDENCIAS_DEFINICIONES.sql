/* Solo lectura, ejecutar en T3QA, misma base del incidente del 22/10/2026.
   Alcance: RECV_INVOICE y dependencias de la ruta de los errores 3930.
   No ejecuta procedimientos ni reprocesa mensajes.
   Devuelve las definiciones por lineas y fragmentos de 180 caracteres para
   evitar el recorte a 256 caracteres observado en la exportacion anterior.
   Ejecutar todo en una misma sesion y guardar todos los resultados.
*/
SET NOCOUNT ON;
IF DB_NAME() <> N'T3QA'
    THROW 50000, 'Seleccionar T3QA, base de la captura del incidente.', 1;

SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura;

DECLARE @Objetos TABLE (Nombre nvarchar(128) COLLATE DATABASE_DEFAULT);
INSERT @Objetos VALUES(N'EAI_OWNER.RECV_INVOICE'),
 (N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'),(N'EAI_OWNER.INVOICE_TO_PREVENTA'),
 (N'EAI_OWNER.INVOICE_TO_FACTURA'),(N'EAI_OWNER.INVOICE_TO_ENTREGA_PO'),
 (N'T3.DELIVERY_WA_OXXO');

SELECT N.Nombre,O.object_id,O.modify_date,
       M.uses_ansi_nulls,M.uses_quoted_identifier,
       LEN(M.definition) AS CaracteresDefinicion,
       CASE WHEN M.definition IS NULL THEN N'No visible, cifrado o no existe'
            ELSE N'Disponible' END AS Estado
FROM @Objetos N
LEFT JOIN sys.objects O ON O.object_id=OBJECT_ID(N.Nombre)
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id;

;WITH Lineas AS
(
 SELECT N.Nombre,L.ordinal AS Linea,
        CONVERT(nvarchar(max),L.value) AS TextoCompleto
 FROM @Objetos N
 JOIN sys.sql_modules M ON M.object_id=OBJECT_ID(N.Nombre)
 CROSS APPLY STRING_SPLIT(REPLACE(M.definition,CHAR(13),N''),CHAR(10),1) L
), Fragmentos AS
(
 SELECT Nombre,Linea,TextoCompleto,CONVERT(int,1) AS Fragmento
 FROM Lineas
 UNION ALL
 SELECT Nombre,Linea,TextoCompleto,Fragmento+1
 FROM Fragmentos
 WHERE CONVERT(bigint,Fragmento)*180 < LEN(TextoCompleto)
)
SELECT Nombre,Linea,Fragmento,
       CONVERT(nvarchar(180),SUBSTRING(TextoCompleto,(Fragmento-1)*180+1,180)) AS Texto
FROM Fragmentos
ORDER BY Nombre,Linea,Fragmento
OPTION (MAXRECURSION 0);

-- Las lineas son las de sys.sql_modules.definition. Para reconstruir una
-- linea, concatenar sus fragmentos en orden sin insertar espacios nuevos.
-- Las opciones SET de creacion del modulo se reportan en la salida anterior.

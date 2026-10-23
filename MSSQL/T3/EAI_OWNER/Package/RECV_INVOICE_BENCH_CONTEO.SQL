/* Microprueba aislada del coordinador: NO mide facturas, XML ni produccion.
   Solo variables de tabla. Ejecutar en QA/LocalDB; no requiere tablas de negocio.
   Compara el COUNT_BIG dentro del WHILE contra contar el lote fijo una sola vez.
   Ambos recorridos hacen la misma busqueda por clave. Repetir para medir variacion.
*/
SET NOCOUNT ON;
DECLARE @Records table (Item bigint PRIMARY KEY);
DECLARE @Resultados table (N int, Patron varchar(20), Milisegundos decimal(18,3), ChecksumIteracion bigint);
DECLARE @N int=1000,@i bigint,@Total bigint,@Value bigint,@Checksum bigint,@Inicio datetime2;
WHILE @N<=10000
BEGIN
    DELETE @Records;
    ;WITH D AS (SELECT X FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) V(X))
    INSERT @Records SELECT TOP (@N) ROW_NUMBER() OVER (ORDER BY A.X,B.X,C.X,E.X)
    FROM D A CROSS JOIN D B CROSS JOIN D C CROSS JOIN D E;
    SET @i=1; SET @Checksum=0; SET @Inicio=SYSDATETIME();
    WHILE @i<=(SELECT COUNT_BIG(*) FROM @Records)
    BEGIN
        SELECT @Value=Item FROM @Records WHERE Item=@i;
        SET @Checksum+=@Value;
        SET @i+=1;
    END;
    INSERT @Resultados VALUES (@N,'COUNT en WHILE',DATEDIFF_BIG(MICROSECOND,@Inicio,SYSDATETIME())/1000.0,@Checksum);
    SET @i=1; SET @Checksum=0; SET @Inicio=SYSDATETIME();
    SELECT @Total=COUNT_BIG(*) FROM @Records;
    WHILE @i<=@Total
    BEGIN
        SELECT @Value=Item FROM @Records WHERE Item=@i;
        SET @Checksum+=@Value;
        SET @i+=1;
    END;
    INSERT @Resultados VALUES (@N,'COUNT unico',DATEDIFF_BIG(MICROSECOND,@Inicio,SYSDATETIME())/1000.0,@Checksum);
    SET @N=CASE @N WHEN 1000 THEN 5000 WHEN 5000 THEN 10000 ELSE 10001 END;
END;
IF EXISTS(SELECT 1 FROM @Resultados WHERE ChecksumIteracion<>CONVERT(bigint,N)*(N+1)/2)
    THROW 51000,'Los recorridos no son equivalentes',1;
SELECT * FROM @Resultados ORDER BY N,Patron;

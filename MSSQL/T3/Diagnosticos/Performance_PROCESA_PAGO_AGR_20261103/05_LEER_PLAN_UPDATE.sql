/*
  SOLO LECTURA. Lee el plan historico 8889 / query_id 32735 del UPDATE de
  Asignacion_Central. No ejecuta el UPDATE ni ningun SP de negocio.
  No lee tablas de negocio, crea indices, actualiza estadisticas, fuerza planes
  ni cambia Query Store. Solo usa catalogos y variables de tabla locales.

  Ejecutar completo en SSMS y guardar TODOS los resultados en texto.
  Las columnas de texto largo se dividen en fragmentos de 180 caracteres:
  funcionan incluso con el limite de 256 caracteres por columna del reporte 04.
  @IncluirXMLCompleto=1 conserva tambien el XML completo en esos fragmentos.
  Los costos y las filas son ESTIMADOS; no son contadores reales de operadores.
*/
USE [T3QA];
SET NOCOUNT ON;
DECLARE @QueryId bigint=32735, @PlanId bigint=8889;
DECLARE @IncluirXMLCompleto bit=1;
DECLARE @Objeto int=OBJECT_ID(N'T3.PROC_CFDI_PROCESA_PAGO_AGR');
DECLARE @Plan xml, @SQL nvarchar(max), @UltimaCompilacion datetimeoffset,
        @Forzado bit, @QueryHash binary(8);

BEGIN TRY
    SELECT @Plan=TRY_CONVERT(xml,P.query_plan), @SQL=T.query_sql_text,
           @UltimaCompilacion=P.last_compile_start_time,
           @Forzado=P.is_forced_plan, @QueryHash=Q.query_hash
    FROM sys.query_store_plan P
    JOIN sys.query_store_query Q ON Q.query_id=P.query_id
    JOIN sys.query_store_query_text T ON T.query_text_id=Q.query_text_id
    WHERE P.plan_id=@PlanId AND Q.query_id=@QueryId AND Q.object_id=@Objeto
      AND T.query_sql_text LIKE N'%UPDATE Cobza%'
      AND T.query_sql_text LIKE N'%Asignacion_Central%';
END TRY
BEGIN CATCH
    SELECT '00_ERROR_LECTURA' Seccion,ERROR_NUMBER() Error,
           LEFT(ERROR_MESSAGE(),180) Mensaje;
    RETURN;
END CATCH;

SELECT '00_CONTEXTO_PLAN' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,
       SYSDATETIMEOFFSET() Captura,@QueryId QueryId,@PlanId PlanId,
       CONVERT(varchar(18),@QueryHash,1) QueryHash,
       @UltimaCompilacion Compilacion,@Forzado EsForzado;
IF @Plan IS NULL
BEGIN
    SELECT '00_PLAN_NO_DISPONIBLE' Seccion,
        'No se encontro el plan esperado del UPDATE; puede haber expirado o faltar visibilidad. No ejecutar el SP para recuperarlo.' Mensaje;
    RETURN;
END;

DECLARE @Operadores table(
    Id int IDENTITY(1,1) PRIMARY KEY,Sentencia int,Nodo int,
    Operador nvarchar(60),Operacion nvarchar(60),Paralelo bit,
    FilasEstimadas float,FilasLeidasEstimadas float,
    CostoIO float,CostoCPU float,CostoSubarbol float,
    Esquema nvarchar(128),Tabla nvarchar(128),Indice nvarchar(128),
    Lookup nvarchar(10),NodoXML xml);
;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
INSERT @Operadores(Sentencia,Nodo,Operador,Operacion,Paralelo,FilasEstimadas,
    FilasLeidasEstimadas,CostoIO,CostoCPU,CostoSubarbol,Esquema,Tabla,Indice,Lookup,NodoXML)
SELECT S.N.value('(@StatementId)[1]','int'),R.N.value('(@NodeId)[1]','int'),
    R.N.value('(@PhysicalOp)[1]','nvarchar(60)'),R.N.value('(@LogicalOp)[1]','nvarchar(60)'),
    R.N.value('(@Parallel)[1]','bit'),R.N.value('(@EstimateRows)[1]','float'),
    TRY_CONVERT(float,NULLIF(R.N.value('string((@EstimatedRowsRead)[1])','nvarchar(60)'),N'')),
    TRY_CONVERT(float,NULLIF(R.N.value('string((@EstimateIO)[1])','nvarchar(60)'),N'')),
    TRY_CONVERT(float,NULLIF(R.N.value('string((@EstimateCPU)[1])','nvarchar(60)'),N'')),
    TRY_CONVERT(float,NULLIF(R.N.value('string((@EstimatedTotalSubtreeCost)[1])','nvarchar(60)'),N'')),
    R.N.value('string((*/Object/@Schema)[1])','nvarchar(128)'),
    R.N.value('string((*/Object/@Table)[1])','nvarchar(128)'),
    R.N.value('string((*/Object/@Index)[1])','nvarchar(128)'),
    R.N.value('string((*/@Lookup)[1])','nvarchar(10)'),R.N.query('.')
FROM @Plan.nodes('//StmtSimple') S(N)
CROSS APPLY S.N.nodes('.//RelOp') R(N);

SELECT '01_OPERADORES_ESTIMADOS' Seccion,Sentencia,Nodo,Operador,Operacion,
    Paralelo,FilasEstimadas,FilasLeidasEstimadas,CostoIO,CostoCPU,CostoSubarbol,
    Esquema,Tabla,Indice,Lookup
FROM @Operadores ORDER BY Sentencia,Nodo;

;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT '02_ARISTAS_DEL_PLAN' Seccion,O.Sentencia,O.Nodo NodoPadre,
    C.N.value('(@NodeId)[1]','int') NodoHijo
FROM @Operadores O CROSS APPLY O.NodoXML.nodes('/RelOp/*/RelOp') C(N)
ORDER BY O.Sentencia,O.Nodo,NodoHijo;

;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT '03_PARAMETROS_COMPILADOS' Seccion,
    C.N.value('string((@Column)[1])','nvarchar(128)') Parametro,
    C.N.value('string((@ParameterDataType)[1])','nvarchar(128)') Tipo,
    C.N.value('string((@ParameterCompiledValue)[1])','nvarchar(180)') ValorCompilado,
    C.N.value('string((@ParameterRuntimeValue)[1])','nvarchar(180)') ValorRuntime
FROM @Plan.nodes('//ParameterList/ColumnReference') C(N);

-- Una sugerencia del optimizador es una hipotesis, no una instruccion de DDL.
;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT '04_SUGERENCIAS_DEL_OPTIMIZADOR' Seccion,
    G.N.value('(@Impact)[1]','float') ImpactoEstimado,
    M.N.value('string((@Schema)[1])','nvarchar(128)') Esquema,
    M.N.value('string((@Table)[1])','nvarchar(128)') Tabla,
    U.N.value('string((@Usage)[1])','nvarchar(60)') Uso,
    C.N.value('string((@Name)[1])','nvarchar(128)') Columna
FROM @Plan.nodes('//MissingIndexGroup') G(N)
CROSS APPLY G.N.nodes('MissingIndex') M(N)
CROSS APPLY M.N.nodes('ColumnGroup') U(N)
CROSS APPLY U.N.nodes('Column') C(N);

-- Todo texto extenso, incluidos predicados/advertencias, se devuelve por partes.
DECLARE @Textos table(Id int IDENTITY(1,1) PRIMARY KEY,Clase nvarchar(60),
    Sentencia int NULL,Nodo int NULL,Texto nvarchar(max));
INSERT @Textos(Clase,Texto) VALUES(N'SQL_INSTALADO_EN_QUERY_STORE',@SQL);
;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
INSERT @Textos(Clase,Sentencia,Nodo,Texto)
SELECT C.N.value('local-name(.)','nvarchar(60)'),O.Sentencia,O.Nodo,
       CONVERT(nvarchar(max),C.N.query('.'))
FROM @Operadores O CROSS APPLY O.NodoXML.nodes('/RelOp/*/*') C(N)
WHERE C.N.value('local-name(.)','nvarchar(60)') IN
    (N'Predicate',N'SeekPredicates',N'ProbeResidual',N'BuildResidual',N'Residual',
     N'HashKeysBuild',N'HashKeysProbe',N'OuterReferences',N'DefinedValues',N'SetPredicate');
;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
INSERT @Textos(Clase,Texto)
SELECT N'ADVERTENCIAS',CONVERT(nvarchar(max),W.N.query('.'))
FROM @Plan.nodes('//Warnings') W(N);
;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
INSERT @Textos(Clase,Texto)
SELECT N'MEMORY_GRANT_INFO',CONVERT(nvarchar(max),M.N.query('.'))
FROM @Plan.nodes('//MemoryGrantInfo') M(N);
IF @IncluirXMLCompleto=1
    INSERT @Textos(Clase,Texto) VALUES(N'PLAN_XML_COMPLETO',CONVERT(nvarchar(max),@Plan));

-- Los marcadores <CR>/<LF>/<TAB> hacen visible el formato del texto SQL.
-- El XML serializado normalmente ya contiene entidades para estos caracteres.
DECLARE @MaxPartes int;
SELECT @MaxPartes=MAX((LEN(REPLACE(REPLACE(REPLACE(Texto,
    CHAR(13),N'<CR>'),CHAR(10),N'<LF>'),CHAR(9),N'<TAB>')+N'#')-1+179)/180)
FROM @Textos;
;WITH Numeros AS (
    SELECT 1 Parte
    UNION ALL SELECT Parte+1 FROM Numeros WHERE Parte<@MaxPartes
), Textos AS (
    SELECT Id,Clase,Sentencia,Nodo,REPLACE(REPLACE(REPLACE(Texto,
        CHAR(13),N'<CR>'),CHAR(10),N'<LF>'),CHAR(9),N'<TAB>') Texto FROM @Textos
)
SELECT '05_TEXTOS_FRAGMENTADOS' Seccion,T.Id,T.Clase,T.Sentencia,T.Nodo,N.Parte,
    (LEN(T.Texto+N'#')-1+179)/180 TotalPartes,
    CONVERT(nvarchar(180),SUBSTRING(T.Texto,(N.Parte-1)*180+1,180)) Fragmento
FROM Textos T JOIN Numeros N ON N.Parte<=(LEN(T.Texto+N'#')-1+179)/180
ORDER BY T.Id,N.Parte OPTION(MAXRECURSION 0);

SELECT '06_ALCANCE' Seccion,
    'Plan compilado historico: costos/filas estimados. No demuestra filas reales, spills ni duracion de cada operador. No ejecuta procedimientos.' Mensaje;

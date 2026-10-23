/*
  Diagnostico de MSSQL-50021 en RECV_INVOICE_INTERCOMPANY.
  Solo lectura: no ejecuta procedimientos de negocio ni modifica datos/permisos.
  Seleccionar en SSMS la MISMA base usada por el job (por ejemplo, T3QA).
  Ejecutar primero como DBA y comparar con el contexto del job si difieren.
  OBJECT_ID NULL no distingue ausencia de objeto de falta de visibilidad.
  No se debe quitar el THROW ni crear un procedimiento vacio para ocultar el error.
*/
SET NOCOUNT ON;

SELECT '01_AMBIENTE' AS Seccion, @@SERVERNAME AS Servidor,
       DB_NAME() AS BaseActual, SYSDATETIMEOFFSET() AS FechaCaptura,
       ORIGINAL_LOGIN() AS LoginOriginal, SUSER_SNAME() AS LoginActual,
       USER_NAME() AS UsuarioBase,
       IS_SRVROLEMEMBER(N'sysadmin') AS EsSysadmin,
       IS_MEMBER(N'db_owner') AS EsDbOwner,
       HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'VIEW DEFINITION') AS VerDefinicionesBase;

-- La lista contiene las dependencias directas del paso final, no todo su arbol.
SELECT '02_OBJETOS' AS Seccion, V.Nombre AS Objeto,
       O.object_id, O.type_desc, O.create_date, O.modify_date,
       CASE WHEN O.object_id IS NULL THEN N'NO ENCONTRADO O NO VISIBLE'
            WHEN O.type = 'P' THEN N'PROCEDIMIENTO TSQL VISIBLE'
            ELSE N'OBJETO VISIBLE; REVISAR TIPO ESPERADO' END AS Estado,
       HAS_PERMS_BY_NAME(V.Nombre, N'OBJECT', N'EXECUTE') AS PermisoExecute,
       HAS_PERMS_BY_NAME(V.Nombre, N'OBJECT', N'VIEW DEFINITION') AS PermisoVerDefinicion
FROM (VALUES
    (N'EAI_OWNER.RECV_INVOICE_INTERCOMPANY'),
    (N'T3.PROC_T3_OT_GENERAL'),
    (N'T3.WA_ERR_INVOICE_PAYMETHOD'),
    (N'T3.PROC_V40_GENERAR_OTROS')
) AS V(Nombre)
LEFT JOIN sys.objects AS O ON O.object_id = OBJECT_ID(V.Nombre);

-- Detecta objetos homonimos en otro esquema y sinonimos visibles.
SELECT '03_NOMBRES_Y_ESQUEMAS' AS Seccion, S.name AS Esquema,
       O.name AS Objeto, O.type_desc, SN.base_object_name AS DestinoSinonimo
FROM sys.objects AS O
INNER JOIN sys.schemas AS S ON S.schema_id = O.schema_id
LEFT JOIN sys.synonyms AS SN ON SN.object_id = O.object_id
WHERE O.name IN (N'PROC_T3_OT_GENERAL', N'WA_ERR_INVOICE_PAYMETHOD',
                 N'PROC_V40_GENERAR_OTROS')
ORDER BY O.name, S.name;

-- Comprobar la definicion instalada y su contexto; no ejecuta el coordinador.
-- Definicion NULL tambien puede deberse a permisos o a cifrado del modulo.
SELECT '04_COORDINADOR_INSTALADO' AS Seccion,
       O.modify_date, M.execute_as_principal_id,
       CASE WHEN M.execute_as_principal_id IS NULL THEN N'CALLER'
            WHEN M.execute_as_principal_id = -2 THEN N'OWNER'
            ELSE USER_NAME(M.execute_as_principal_id) END AS ContextoEjecucion,
       M.definition AS Definicion
FROM sys.objects AS O
LEFT JOIN sys.sql_modules AS M ON M.object_id = O.object_id
WHERE O.object_id = OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_INTERCOMPANY', N'P');

SELECT '05_ALCANCE' AS Seccion,
       N'Si el DBA encuentra el objeto y el job no, revisar usuario/permisos/contexto del job. '
       + N'Si tampoco existe para el DBA, revisar despliegue en esta base. '
       + N'El fuente local existe, pero estos resultados no acreditan su instalacion ni sus dependencias transitivas.' AS Observacion;

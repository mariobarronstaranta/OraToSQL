/* SOLO LECTURA. Devuelve DDL COMO TEXTO, no crea ni elimina indices.
   Candidatos para decidir DESPUES de revisar tiempos, planes e inventario real.
   El prefijo de clave no certifica equivalencia: revisar filtro, INCLUDE,
   estado, unicidad, tipos y costo de escritura. No crear todos de una vez.
   La comparacion por prefijo muestra indices existentes aunque tengan otro
   nombre y mas columnas. No reutiliza ni convierte PK o indices existentes.
*/
USE [T3QA]; SET NOCOUNT ON;
DECLARE @C table(Id int PRIMARY KEY,Tabla nvarchar(256) COLLATE DATABASE_DEFAULT,
 Nombre sysname COLLATE DATABASE_DEFAULT,Claves nvarchar(2000) COLLATE DATABASE_DEFAULT,
 Incluidas nvarchar(4000),Filtro nvarchar(4000),Motivo nvarchar(1000),DDL nvarchar(max));
INSERT @C VALUES
(1,N'T3.CFDI_COBRANZA',N'IX_PERF_COBRANZA_PENDIENTE_PROCESO',N'[Fecha_Proceso]',N'[Fecha_Envio],[Asignacion_ID],[Factura],[Fecha_Pago],[RFC],[Via_Pago],[Banco_Nombre],[Banco_Num_Cuenta],[Asignacion_Central],[Importe],[Accnt_ID],[Cliente_SAP],[Created_By],[Status]',N'[Fecha_Envio] IS NULL',N'Agrupacion y marcado recientes. Pesar selectividad y costo de mantener/remover filas pendientes.',N'CREATE NONCLUSTERED INDEX [IX_PERF_COBRANZA_PENDIENTE_PROCESO] ON [T3].[CFDI_COBRANZA] ([Fecha_Proceso]) INCLUDE ([Fecha_Envio],[Asignacion_ID],[Factura],[Fecha_Pago],[RFC],[Via_Pago],[Banco_Nombre],[Banco_Num_Cuenta],[Asignacion_Central],[Importe],[Accnt_ID],[Cliente_SAP],[Created_By],[Status]) WHERE [Fecha_Envio] IS NULL;'),
(2,N'EAI_OWNER.TMP_ACCOUNT_HEADER',N'IX_PERF_ACCOUNT_CLEARING_YEAR',N'[ClearingDocNumber],[FiscalYear]',N'[Assignment]',N'',N'Buscar compensacion/ejercicio desde cobranzas recientes; los IXDOC locales tienen otra columna inicial.',N'CREATE NONCLUSTERED INDEX [IX_PERF_ACCOUNT_CLEARING_YEAR] ON [EAI_OWNER].[TMP_ACCOUNT_HEADER] ([ClearingDocNumber],[FiscalYear]) INCLUDE ([Assignment]);'),
(3,N'T3.WA_FACTORAJE',N'IX_PERF_FACTORAJE_FACTURA',N'[Factura]',N'',N'',N'Anti join de factoraje repetido; revisar si ya hay clave inicial Factura.',N'CREATE NONCLUSTERED INDEX [IX_PERF_FACTORAJE_FACTURA] ON [T3].[WA_FACTORAJE] ([Factura]);'),
(4,N'T3.CFDI_AGRUPACION_PAGO',N'IX_PERF_AGRUPACION_ASIGNACION',N'[Agrupacion],[Asignacion_ID]',N'[Fecha_Pago]',N'',N'CHECK, detalle de generacion y marcado: localizar asignaciones por grupo.',N'CREATE NONCLUSTERED INDEX [IX_PERF_AGRUPACION_ASIGNACION] ON [T3].[CFDI_AGRUPACION_PAGO] ([Agrupacion],[Asignacion_ID]) INCLUDE ([Fecha_Pago]);'),
(5,N'T3.CFDI_COBRANZA',N'IX_PERF_COBRANZA_ASIGNACION',N'[Asignacion_ID]',N'[Nota_Venta],[UUID_Venta],[Fecha_Asignacion],[Fecha_Factura],[Factura],[Numero_Pago],[Saldo_Anterior],[Importe]',N'',N'CHECK y detalle del generador; conserva multiplicidad, no es UNIQUE.',N'CREATE NONCLUSTERED INDEX [IX_PERF_COBRANZA_ASIGNACION] ON [T3].[CFDI_COBRANZA] ([Asignacion_ID]) INCLUDE ([Nota_Venta],[UUID_Venta],[Fecha_Asignacion],[Fecha_Factura],[Factura],[Numero_Pago],[Saldo_Anterior],[Importe]);'),
(6,N'T3.CFDI_DOCUMENTOS',N'IX_PERF_DOCUMENTO_METODO',N'[Nota_Venta]',N'[Metodo_Pago]',N'',N'Cruce del CHECK con documentos; comparar con indices mas amplios existentes.',N'CREATE NONCLUSTERED INDEX [IX_PERF_DOCUMENTO_METODO] ON [T3].[CFDI_DOCUMENTOS] ([Nota_Venta]) INCLUDE ([Metodo_Pago]);'),
(7,N'T3.CFDI_AGRUPACION_CTRL',N'IX_PERF_CTRL_PENDIENTE_CENTRAL',N'[Fecha_Pago],[Agrupacion]',N'[Fecha_Envio],[Accnt_ID],[RFC]',N'[Fecha_Envio] IS NULL AND [Accnt_ID] <> ''Contado''',N'Cursor de liberacion global: mismos filtros de pendientes y exclusion Contado/NULL.',N'CREATE NONCLUSTERED INDEX [IX_PERF_CTRL_PENDIENTE_CENTRAL] ON [T3].[CFDI_AGRUPACION_CTRL] ([Fecha_Pago],[Agrupacion]) INCLUDE ([Fecha_Envio],[Accnt_ID],[RFC]) WHERE [Fecha_Envio] IS NULL AND [Accnt_ID] <> ''Contado'';'),
(8,N'T3.CFDI_RFC_SETTING',N'IX_PERF_RFC_SETTING_PARAMETRO',N'[Parametro],[RFC]',N'[Valor]',N'',N'Configuracion por RFC/parametro, con MAX(Valor); medir costo real antes de agregar.',N'CREATE NONCLUSTERED INDEX [IX_PERF_RFC_SETTING_PARAMETRO] ON [T3].[CFDI_RFC_SETTING] ([Parametro],[RFC]) INCLUDE ([Valor]);');
DECLARE @P table(Id int,Rol char(1),Posicion int,Columna sysname COLLATE DATABASE_DEFAULT);
INSERT @P VALUES
(1,N'K',1,N'Fecha_Proceso'),
(1,N'I',1,N'Fecha_Envio'),
(1,N'I',2,N'Asignacion_ID'),
(1,N'I',3,N'Factura'),
(1,N'I',4,N'Fecha_Pago'),
(1,N'I',5,N'RFC'),
(1,N'I',6,N'Via_Pago'),
(1,N'I',7,N'Banco_Nombre'),
(1,N'I',8,N'Banco_Num_Cuenta'),
(1,N'I',9,N'Asignacion_Central'),
(1,N'I',10,N'Importe'),
(1,N'I',11,N'Accnt_ID'),
(1,N'I',12,N'Cliente_SAP'),
(1,N'I',13,N'Created_By'),
(1,N'I',14,N'Status'),
(2,N'K',1,N'ClearingDocNumber'),
(2,N'K',2,N'FiscalYear'),
(2,N'I',1,N'Assignment'),
(3,N'K',1,N'Factura'),
(4,N'K',1,N'Agrupacion'),
(4,N'K',2,N'Asignacion_ID'),
(4,N'I',1,N'Fecha_Pago'),
(5,N'K',1,N'Asignacion_ID'),
(5,N'I',1,N'Nota_Venta'),
(5,N'I',2,N'UUID_Venta'),
(5,N'I',3,N'Fecha_Asignacion'),
(5,N'I',4,N'Fecha_Factura'),
(5,N'I',5,N'Factura'),
(5,N'I',6,N'Numero_Pago'),
(5,N'I',7,N'Saldo_Anterior'),
(5,N'I',8,N'Importe'),
(6,N'K',1,N'Nota_Venta'),
(6,N'I',1,N'Metodo_Pago'),
(7,N'K',1,N'Fecha_Pago'),
(7,N'K',2,N'Agrupacion'),
(7,N'I',1,N'Fecha_Envio'),
(7,N'I',2,N'Accnt_ID'),
(7,N'I',3,N'RFC'),
(8,N'K',1,N'Parametro'),
(8,N'K',2,N'RFC'),
(8,N'I',1,N'Valor');
SELECT '00_ADVERTENCIA' Seccion,'PROPUESTAS, NO MEDICIONES. No ejecutar DDL sin revisar 01/02 y planes.' Mensaje;
SELECT C.Id,C.Tabla,C.Nombre IndiceCandidato,C.Claves,C.Incluidas,C.Filtro,C.Motivo,
       CASE WHEN OBJECT_ID(C.Tabla,'U') IS NULL THEN 'TABLA AUSENTE O NO VISIBLE'
            WHEN V.Faltantes>0 THEN 'COLUMNAS AUSENTES O NO VISIBLES'
            WHEN A.name IS NULL AND EXISTS(SELECT 1 FROM sys.indexes I
              WHERE I.object_id=OBJECT_ID(C.Tabla,'U') AND I.name COLLATE DATABASE_DEFAULT=C.Nombre)
              THEN 'NOMBRE CANDIDATO OCUPADO; PREFIJO DIFERENTE'
            WHEN A.name IS NOT NULL THEN 'PREFIJO EXISTENTE: COMPARAR FILTRO/INCLUDE/ESTADO'
            ELSE 'NO SE VE PREFIJO EQUIVALENTE; MEDIR ANTES DE CREAR' END Revision,
       A.name IndiceActualConPrefijo,A.type_desc TipoActual,A.is_unique UnicoActual,A.is_primary_key EsPKActual,
       A.is_disabled Deshabilitado,A.filter_definition FiltroActual,A.ColumnasClaveActuales,
       CASE WHEN OBJECT_ID(C.Tabla,'U') IS NOT NULL AND V.Faltantes=0
              AND NOT EXISTS(SELECT 1 FROM sys.indexes I WHERE I.object_id=OBJECT_ID(C.Tabla,'U')
                AND I.name COLLATE DATABASE_DEFAULT=C.Nombre)
            THEN C.DDL END DDL_Candidato_NoEjecutado
FROM @C C
OUTER APPLY(SELECT COUNT(*) Faltantes FROM @P P
    WHERE P.Id=C.Id AND NOT EXISTS(SELECT 1 FROM sys.columns X
      WHERE X.object_id=OBJECT_ID(C.Tabla,'U') AND X.name COLLATE DATABASE_DEFAULT=P.Columna)) V
OUTER APPLY(
    SELECT I.name,I.type_desc,I.is_unique,I.is_primary_key,I.is_disabled,I.filter_definition,K.ColumnasClaveActuales
    FROM sys.indexes I
    CROSS APPLY(SELECT STUFF((SELECT N','+QUOTENAME(X.name) FROM sys.index_columns IC
        JOIN sys.columns X ON X.object_id=IC.object_id AND X.column_id=IC.column_id
        WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.key_ordinal>0
        ORDER BY IC.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'') ColumnasClaveActuales) K
    WHERE I.object_id=OBJECT_ID(C.Tabla,'U') AND I.index_id>0
      AND LEFT(K.ColumnasClaveActuales,LEN(C.Claves)) COLLATE DATABASE_DEFAULT=C.Claves
      AND (LEN(K.ColumnasClaveActuales)=LEN(C.Claves) OR SUBSTRING(K.ColumnasClaveActuales,LEN(C.Claves)+1,1)=',')
) A
ORDER BY C.Id,A.name;

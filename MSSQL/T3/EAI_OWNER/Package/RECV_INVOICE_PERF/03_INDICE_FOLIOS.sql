-- Ejecutar en T3QA, fuera del lote y de transacciones externas.
-- La captura muestra 718 mil filas y ningun indice en MX_NRIV_RELACION.
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF DB_NAME()<>N'T3QA' THROW 51940,'Seleccionar la base T3QA.',1;
IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
 THROW 51941,'Ejecutar fuera de transacciones externas/implicitas.',1;
DECLARE @obj int=OBJECT_ID(N'EAI_OWNER.MX_NRIV_RELACION',N'U');
IF @obj IS NULL THROW 51950,'MX_NRIV_RELACION no existe o no es visible.',1;
-- Una clave inicial FacturaSAP ya ofrece acceso; no duplicarla por falta de INCLUDE.
IF EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.index_columns IC
 ON IC.object_id=I.object_id AND IC.index_id=I.index_id
 JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
 WHERE I.object_id=@obj AND I.type IN(1,2) AND I.is_disabled=0
 AND I.is_hypothetical=0 AND I.has_filter=0 AND IC.key_ordinal=1 AND C.name=N'FACTURASAP')
BEGIN
 PRINT 'Ya existe acceso inicial por FacturaSAP; no se crea otro indice.';
 RETURN;
END;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@obj AND name=N'IX_RI_NRIV_RELACION_SAP_CLASE')
 THROW 51951,'El nombre propuesto ya existe con otra definicion/estado.',1;
CREATE NONCLUSTERED INDEX IX_RI_NRIV_RELACION_SAP_CLASE
 ON EAI_OWNER.MX_NRIV_RELACION (FACTURASAP,CLASE_FACTURA) INCLUDE (FACTURAT3);
PRINT 'Creado IX_RI_NRIV_RELACION_SAP_CLASE. No se cambiaron los bloqueos ni la unicidad.';

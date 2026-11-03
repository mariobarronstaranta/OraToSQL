/*
    Homologo de ORA/T3/T3/Sequences/SEQ_PAGO_CENTRAL_AGR.SQL.
    Conserva START WITH 534458, INCREMENT BY 1, MINVALUE 1,
    MAXVALUE 1000000000, CACHE 20 y CYCLE.
    NUMERIC(10,0) admite el rango y coincide con Agrupacion en #Grupos.

    ORDER, NOKEEP, NOSCALE y GLOBAL no tienen clausulas equivalentes
    directas en CREATE SEQUENCE de SQL Server y se omiten.
    No se garantiza el orden de asignacion a filas sin un orden explicito.

    El inicio corresponde al DDL exportado, no al estado actual de Oracle.
    Para una migracion con datos existentes, conciliar el inicio antes del
    primer despliegue. CYCLE conserva el reinicio en 1 al agotar el rango.
    Si ya existe, se conserva su configuracion y su valor actual.
*/
USE [T3QA];
GO
SET NOCOUNT ON;

IF SCHEMA_ID(N'T3') IS NULL
    THROW 50041, 'No existe el esquema T3.', 1;

IF OBJECT_ID(N'T3.SEQ_PAGO_CENTRAL_AGR', N'SO') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        CREATE SEQUENCE [T3].[SEQ_PAGO_CENTRAL_AGR]
            AS NUMERIC(10,0)
            START WITH 534458
            INCREMENT BY 1
            MINVALUE 1
            MAXVALUE 1000000000
            CYCLE
            CACHE 20;';
END;

-- Consulta de configuracion: no consume numeros de la secuencia.
SELECT SCHEMA_NAME(schema_id) AS Esquema, name AS Secuencia,
       start_value, increment, minimum_value, maximum_value,
       is_cycling, is_cached, cache_size, current_value
FROM sys.sequences
WHERE object_id = OBJECT_ID(N'T3.SEQ_PAGO_CENTRAL_AGR', N'SO');
GO

-- Uso en procedimientos: NEXT VALUE FOR [T3].[SEQ_PAGO_CENTRAL_AGR]

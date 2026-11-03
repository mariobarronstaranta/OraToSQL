/*
  Ajuste solicitado para evitar reutilizar agrupaciones migradas.
  Ejecutar con los jobs/procesos que consumen esta secuencia detenidos.
  Los bloqueos de tablas no impiden que otra sesion consuma NEXT VALUE FOR.
  Proximo valor = MAX(control, detalle, valor actual de secuencia) + 1.
  No consume numeros para verificar y no modifica datos de negocio.
  Conserva incremento, cache y CYCLE de la secuencia existente.
*/
USE [T3QA];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0
    THROW 52810, 'Ejecutar fuera de una transaccion existente.', 1;

DECLARE @MaxControl decimal(38,0), @MaxDetalle decimal(38,0),
        @Actual decimal(38,0), @Maximo decimal(38,0),
        @Minimo decimal(38,0), @Incremento decimal(38,0),
        @Base decimal(38,0), @Siguiente decimal(38,0), @SQL nvarchar(max);

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @MaxControl=MAX(Agrupacion)
    FROM T3.CFDI_AGRUPACION_CTRL WITH (TABLOCKX,HOLDLOCK);
    SELECT @MaxDetalle=MAX(Agrupacion)
    FROM T3.CFDI_AGRUPACION_PAGO WITH (TABLOCKX,HOLDLOCK);

    SELECT @Actual=CONVERT(decimal(38,0),current_value),
           @Maximo=CONVERT(decimal(38,0),maximum_value),
           @Minimo=CONVERT(decimal(38,0),minimum_value),
           @Incremento=CONVERT(decimal(38,0),increment)
    FROM sys.sequences
    WHERE object_id=OBJECT_ID(N'T3.SEQ_PAGO_CENTRAL_AGR',N'SO');

    IF @Maximo IS NULL
        THROW 52811, 'La secuencia no existe o no es visible.', 1;
    IF @Incremento<>1
        THROW 52812, 'Se esperaba INCREMENT BY 1; revisar la configuracion.', 1;

    SELECT @Base=MAX(V.Valor)
    FROM (VALUES (@MaxControl),(@MaxDetalle),(@Actual),(@Minimo-1)) V(Valor);

    IF @Base>=@Maximo
        THROW 52813, 'No queda rango disponible. No se reinicio la secuencia.', 1;

    SET @Siguiente=@Base+1;
    SET @SQL=N'ALTER SEQUENCE [T3].[SEQ_PAGO_CENTRAL_AGR] RESTART WITH '
             +CONVERT(nvarchar(40),@Siguiente)+N';';
    EXEC sys.sp_executesql @SQL;

    COMMIT TRANSACTION;

    SELECT @MaxControl AS MaxAgrupacionControl,
           @MaxDetalle AS MaxAgrupacionDetalle,
           @Actual AS ValorSecuenciaAntes,
           @Siguiente AS ProximoValorConfigurado;
    SELECT SCHEMA_NAME(schema_id) AS Esquema,name AS Secuencia,
           current_value,increment,maximum_value,is_cycling,cache_size
    FROM sys.sequences
    WHERE object_id=OBJECT_ID(N'T3.SEQ_PAGO_CENTRAL_AGR',N'SO');
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

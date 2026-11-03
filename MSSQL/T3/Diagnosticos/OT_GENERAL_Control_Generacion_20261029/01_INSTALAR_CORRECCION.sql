/* Solo instala el coordinador; NO ejecuta procesos ni modifica facturas.
   @Aplicar=0: muestra definicion actual y propuesta para revisar diferencias.
   @Aplicar=1: respalda en dbo.REPAIR_OT_GENERAL_20261029 e instala el ALTER
   completo adjunto. Detener ejecuciones del coordinador durante el despliegue.
   Mantener tambien la correccion numerica ya aplicada al generador. */
USE [T3QA];
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @Aplicar bit=0;
DECLARE @Actual nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID('T3.PROC_T3_OT_GENERAL')),
        @Nueva nvarchar(max)=N'ALTER PROCEDURE [T3].[PROC_T3_OT_GENERAL]
AS
BEGIN
    SET NOCOUNT ON;
    -- Correccion 2026-10-29: no acreditar ejecuciones fallidas ni regenerar
    -- documentos existentes. Conservar el parche numerico del generador.
    /*
        CONTEXTO POR FACTURA. @Limite se fija una vez por corrida y conserva
        la hora; no es un corte por dia. @Total y @TotalDetalle convierten los
        importes del origen a NUMERIC(22,2), como hacia el FETCH anterior.
        @Cabeceras cuenta todas las cabeceras del identificador; @Pendiente
        revalida fecha y marca despues de abrir la fotografia del cursor.
        @Propia/@PuntoGuardado delimitan el trabajo que esta rutina puede
        confirmar o revertir; los contadores no se devuelven como OUTPUT.
    */
    DECLARE @Factura varchar(50), @Limite datetime=DATEADD(DAY,-4,GETDATE()),
            @Cabeceras bigint, @Pendiente int, @Documentos bigint, @Layouts bigint,
            @Total numeric(22,2), @TotalDetalle numeric(22,2),
            @ErroresAntes bigint, @ErroresDespues bigint,
            @MapAntes bigint, @MapDespues bigint,
            @Propia bit=0, @PuntoGuardado bit=0,
            @DetalleError nvarchar(250), @Mensaje nvarchar(2048),
            @Generadas int=0, @Omitidas int=0, @Descuadres int=0;

    -- Una entrada por factura. Los totales se vuelven a leer bajo bloqueo;
    -- se conservan ventana de cuatro dias y redondeo a dos decimales.
    /*
        CANDIDATOS. STATIC toma la fotografia al OPEN, despues del apartado
        y la correccion del metodo de pago. LOCAL limita el cursor a este
        SP; FORWARD_ONLY/READ_ONLY permiten recorrerlo sin actualizarlo.
        DISTINCT y EXISTS evitan multiplicar entradas por el detalle.
        No certifican una cabecera unica: eso se valida dentro del ciclo.
        ORDER BY establece el recorrido por Factura. Fecha_Trn>@Limite no
        tiene limite superior: una fecha futura tambien puede cumplir.
        No se filtran Clase_Factura ni Fecha_Cancelacion de OTROS_GENERAL.
        Los estados finales de CFDI_DOCUMENTOS se revisan por separado.
    */
    DECLARE PREVENTAS CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
        SELECT DISTINCT G.Factura
        FROM T3.OTROS_GENERAL G
        WHERE G.Fecha_Trn>@Limite AND G.Fecha_Proc_BATMD IS NULL
          AND EXISTS(SELECT 1 FROM T3.OTROS_DETALLE D WHERE D.Factura=G.Factura)
        ORDER BY G.Factura;

    BEGIN TRY
        -- Apartado y correccion de metodo de pago heredados.
        /*
            1. APARTADO PREVIO. 2999-12-31 es una marca centinela, no una
            fecha real de generacion. Deja de ser pendiente y queda fuera
            del cursor que se abrira despues.
            El filtro externo alcanza pendientes recientes de cuatro dias.
            El IN busca alguna cabecera de treinta dias, sociedad MX10,
            RFC BAT030325CE9 y detalle cuyo material exista en MATERIAL;
            no impone otra condicion al tipo de material.
            La relacion por Factura puede alcanzar otras cabeceras del mismo
            identificador que cumplan el filtro externo; no usa una PK de fila.
            Este UPDATE y el helper siguiente preceden a las transacciones
            por factura; un fallo posterior no los revierte en autocommit.
        */
        UPDATE OG SET Fecha_Proc_BATMD=CONVERT(datetime,''29991231'',112)
        FROM T3.OTROS_GENERAL OG
        WHERE OG.Fecha_Trn>@Limite AND OG.Fecha_Proc_BATMD IS NULL
          AND OG.Factura IN (
            SELECT S.Factura FROM T3.OTROS_GENERAL S
            JOIN T3.OTROS_DETALLE D ON D.Factura=S.Factura
            JOIN T3.Material M ON M.Material=D.Material
            WHERE S.Fecha_Trn>DATEADD(DAY,-30,GETDATE())
              AND S.Sociedad=''MX10'' AND S.RFC=''BAT030325CE9'');
        /*
            2. METODO DE PAGO. El argumento 4 filtra Fecha_Factura en el
            helper, mientras este coordinador selecciona por Fecha_Trn.
            Busca material R900 / FIXED ASSET - External Sales y cambia
            MetodoPago=''No identificado'' a ''03'' en pendientes.
            Su alcance es propio: puede tocar cabeceras ajenas al cursor.
            Su CATCH registra en MX_EAI_MESSAGE_LOG sin THROW; este cambio
            no modifica ni vigila el contrato de errores de ese helper.
        */
        EXEC T3.WA_ERR_INVOICE_PAYMETHOD 4;

        -- 3. La fotografia excluye el apartado y ve el metodo ya corregido.
        -- Si otra sesion procesa una factura despues del OPEN, @Pendiente
        -- se revalida antes de permitir una nueva generacion.
        OPEN PREVENTAS;
        FETCH NEXT FROM PREVENTAS INTO @Factura;
        WHILE @@FETCH_STATUS=0
        BEGIN
            -- Una transaccion por factura; si hay transaccion del llamador,
            -- usar un savepoint y no confirmar ni revertir todo su trabajo.
            /*
                4. UNIDAD DE TRABAJO. Generacion, inserciones y marcado deben
                persistir juntos para esta factura. Un error detiene la
                corrida; en autocommit, las facturas anteriores ya confirmadas
                conservan sus resultados. Una transaccion externa conserva
                la decision final de COMMIT/ROLLBACK de todo su trabajo.
            */
            SET @Propia=0;
            SET @PuntoGuardado=0;
            IF @@TRANCOUNT=0
            BEGIN
                BEGIN TRANSACTION;
                SET @Propia=1;
            END
            ELSE
            BEGIN
                SAVE TRANSACTION OTGeneralFactura;
                SET @PuntoGuardado=1;
            END;

            /*
                RESERVA Y RELECTURA. UPDLOCK/HOLDLOCK conserva bloqueos de
                actualizacion y proteccion de rangos hasta terminar la
                transaccion; protege tambien la ausencia de salidas.
                Su alcance/costo depende de los indices y del plan instalado.
                Coordina ejecuciones de esta rutina; no sustituye indices
                unicos ni coordinacion con otros productores/consumidores.
                MAX obtiene un total, pero no legitima cabeceras duplicadas:
                una generacion nueva exige @Cabeceras=1 mas adelante.
            */
            SELECT @Cabeceras=COUNT_BIG(*),
                   @Pendiente=ISNULL(MAX(CASE WHEN Fecha_Proc_BATMD IS NULL
                       AND Fecha_Trn>@Limite THEN 1 ELSE 0 END),0),
                   @Total=MAX(ISNULL(Valor_Subt,0)+ISNULL(Valor_IVA,0))
            FROM T3.OTROS_GENERAL WITH(UPDLOCK,HOLDLOCK) WHERE Factura=@Factura;
            SELECT @Documentos=COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS WITH(UPDLOCK,HOLDLOCK)
            WHERE Nota_Venta=@Factura;
            SELECT @Layouts=COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR WITH(UPDLOCK,HOLDLOCK)
            WHERE Nota_Venta=@Factura;

            /*
                5. PROTECCION DE SALIDAS EXISTENTES. UUID, timbre, envio,
                confirmacion o estado final bastan para omitir la factura,
                incluso si ya no hay layout en la cola de envio.
                Un documento y un layout existentes tambien se omiten;
                aqui solo se cuentan, no se revalida su contenido historico.
                Esta proteccion prevalece sobre el rechazo de duplicados:
                las ramas de omision no borran ni completan salidas.
            */
            IF @Pendiente=0 OR EXISTS(
                SELECT 1 FROM T3.CFDI_DOCUMENTOS WHERE Nota_Venta=@Factura
                AND (NULLIF(LTRIM(RTRIM(Folio_Fiscal)),'''') IS NOT NULL
                  OR Fecha_Timbre IS NOT NULL OR Fecha_Envio IS NOT NULL
                  OR Fecha_Confirmacion IS NOT NULL
                  OR NULLIF(LTRIM(RTRIM(Id_Envio)),'''') IS NOT NULL
                  OR NULLIF(LTRIM(RTRIM(Id_Confirmacion)),'''') IS NOT NULL
                  OR Status IN (''CONFIRMADO'',''CANCELADO'',''CANCELLED'',''TIMBRADO'')))
                OR (@Documentos=1 AND @Layouts=1)
            BEGIN
                -- Sin regenerar, borrar salidas ni cambiar la fecha de proceso.
                SET @Omitidas+=1;
            END
            ELSE
            BEGIN
                -- Sin proteccion historica ni salida completa, cualquier
                -- salida previa exige revision; no se intenta regenerarla.
                IF @Documentos<>0 OR @Layouts<>0
                    THROW 53801,''Salida parcial o duplicada; revisar antes de regenerar.'',1;
                IF @Cabeceras<>1
                    THROW 53802,''Se requiere exactamente una cabecera por factura.'',1;

                /*
                    6. CONCILIACION. NULL de importe equivale a cero. El
                    detalle se suma sin multiplicarlo por la cabecera.
                    HOLDLOCK mantiene estable esta lectura en la transaccion.
                    Si desaparecio el detalle, SUM devuelve NULL y se omite.
                    Tolerancia estricta sobre dos decimales: 0.09 pasa;
                    0.10 no pasa. El descuadre queda sin marcar y podra ser
                    candidato de otra corrida mientras cumpla la ventana.
                */
                SELECT @TotalDetalle=SUM(ISNULL(Valor_Subt,0)+ISNULL(Valor_IVA,0))
                FROM T3.OTROS_DETALLE WITH(HOLDLOCK) WHERE Factura=@Factura;
                IF @TotalDetalle IS NULL OR ABS(@Total-@TotalDetalle)>=0.10
                    SET @Descuadres+=1;
                ELSE
                BEGIN
                    -- 7. Fotografiar conteos por referencia antes del EXEC.
                    -- No se borran errores previos ni se usa su sola
                    -- existencia para rechazar una generacion nueva.
                    SELECT @ErroresAntes=COUNT_BIG(*) FROM T3.RF_ERROR_LOG
                    WHERE Referencia=@Factura AND Rutina IN (''GENERAR_OTROS'',''PROC_CFDI_GENERAR_OTROS'');
                    SELECT @MapAntes=COUNT_BIG(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
                    WHERE REFERENCE=@Factura AND QUEUE_NAME=''GET_SAT_CLAVEPRODUCTO'';

                    -- El argumento es Factura, no Cliente_SAP ni un Row_ID.
                    -- El generador conserva sus validaciones fiscales y de
                    -- layout; puede retornar sin salidas y sin THROW.
                    EXEC T3.PROC_V40_GENERAR_OTROS @Factura;

                    -- El generador y su mapeo SAT pueden registrar sin THROW.
                    /*
                        8. ERRORES ABSORBIDOS. Una variacion de los conteos
                        por referencia del generador o mapeo SAT es un fallo.
                        RF_ERROR_LOG aporta la descripcion mas reciente de
                        esas rutinas para incorporarla al error devuelto.
                        No se agregan identificadores de corrida a los hijos:
                        los conteos no distinguen escritores externos para
                        la misma referencia ni sustituyen su coordinacion.
                    */
                    SELECT @ErroresDespues=COUNT_BIG(*) FROM T3.RF_ERROR_LOG
                    WHERE Referencia=@Factura AND Rutina IN (''GENERAR_OTROS'',''PROC_CFDI_GENERAR_OTROS'');
                    IF @ErroresDespues<>@ErroresAntes
                    BEGIN
                        SET @DetalleError=NULL;
                        SELECT TOP(1) @DetalleError=ERROR_DESC FROM T3.RF_ERROR_LOG
                        WHERE Referencia=@Factura AND Rutina IN (''GENERAR_OTROS'',''PROC_CFDI_GENERAR_OTROS'')
                        ORDER BY Fecha DESC;
                        SET @Mensaje=N''El generador registro un error: ''+ISNULL(@DetalleError,N''sin descripcion'');
                        THROW 53803,@Mensaje,1;
                    END;
                    SELECT @MapDespues=COUNT_BIG(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
                    WHERE REFERENCE=@Factura AND QUEUE_NAME=''GET_SAT_CLAVEPRODUCTO'';
                    IF @MapDespues<>@MapAntes
                        THROW 53804,''El mapeo SAT registro errores durante la generacion.'',1;
                    -- 9. SALIDA ACREDITADA. Exactamente un documento y un
                    -- layout de mas de diez caracteres. Valida presencia y
                    -- cardinalidad; no certifica contenido fiscal completo,
                    -- envio ni timbrado.
                    IF (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS WHERE Nota_Venta=@Factura)<>1
                      OR (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR WHERE Nota_Venta=@Factura)<>1
                      OR NOT EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS_ENVIAR
                          WHERE Nota_Venta=@Factura AND LEN(Informacion)>10)
                        THROW 53805,''No se crearon un documento y un layout valido; no se marca la factura.'',1;

                    -- 10. MARCADO FINAL. Repite pendiente y ventana; exige
                    -- una sola fila modificada. Documento, layout y esta
                    -- marca se confirman o revierten juntos.
                    UPDATE T3.OTROS_GENERAL SET Fecha_Proc_BATMD=GETDATE()
                    WHERE Factura=@Factura AND Fecha_Proc_BATMD IS NULL AND Fecha_Trn>@Limite;
                    IF @@ROWCOUNT<>1
                        THROW 53806,''No se pudo marcar exactamente una cabecera pendiente.'',1;
                    SET @Generadas+=1;
                END;
            END;

            -- Solo confirmar la transaccion iniciada por esta rutina. Con
            -- una externa, tambien los bloqueos de filas omitidas quedan
            -- sujetos al COMMIT/ROLLBACK del llamador.
            IF @Propia=1 COMMIT TRANSACTION;
            SET @Propia=0;
            SET @PuntoGuardado=0;
            FETCH NEXT FROM PREVENTAS INTO @Factura;
        END;
        -- 11. FIN NORMAL. Generadas cuenta validaciones y marcas realizadas;
        -- con transaccion externa aun dependen del COMMIT del llamador.
        -- Omitidas incluye historicos, salidas completas y filas que ya no
        -- estaban pendientes. Descuadres incluye detalle desaparecido.
        CLOSE PREVENTAS;
        DEALLOCATE PREVENTAS;
        PRINT CONCAT(''PROC_T3_OT_GENERAL: generadas='',@Generadas,
                     ''; omitidas='',@Omitidas,''; descuadradas/sin detalle='',@Descuadres,''.'');
    END TRY
    BEGIN CATCH
        /*
            12. ERROR Y LIMPIEZA. Guardar causa y factura antes del rollback.
            Sin factura, el fallo ocurrio durante la preparacion previa.
            Revertir una transaccion propia aunque no sea confirmable; para
            una externa solo revertir el savepoint si XACT_STATE()=1.
            Con XACT_STATE()=-1, el llamador debe revertir su transaccion.
            CURSOR_STATUS>=0 permite cerrar; >=-1 permite desasignar tambien
            un cursor ya cerrado. No requiere que haya llegado al OPEN.
        */
        SET @Mensaje=LEFT(CONCAT(''PROC_T3_OT_GENERAL; factura '',ISNULL(@Factura,''(preparacion)''),
            ''; error '',ERROR_NUMBER(),'': '',ERROR_MESSAGE()),2048);
        IF @Propia=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @PuntoGuardado=1 AND XACT_STATE()=1 ROLLBACK TRANSACTION OTGeneralFactura;
        IF CURSOR_STATUS(''local'',''PREVENTAS'')>=0 CLOSE PREVENTAS;
        IF CURSOR_STATUS(''local'',''PREVENTAS'')>=-1 DEALLOCATE PREVENTAS;
        -- Los errores internos de esta factura se revierten con sus salidas.
        -- Conservar el contexto en el error al llamador y, si es posible, en log.
        -- Una transaccion externa no confirmable queda a cargo del llamador.
        /*
            Los registros internos de una generacion fallida se revierten
            con sus salidas. Se intenta conservar el contexto en RF_ERROR_LOG
            con Rutina=PROC_T3_OT_GENERAL, sin asignar JOB_PID.
            El log admite aqui 250 caracteres; el THROW lleva hasta 2048.
            Con transaccion externa, este registro depende tambien de su
            confirmacion; no constituye una bitacora autonoma.
            Si escribir el log falla, se imprime el aviso y se conserva la
            causa para el THROW final. No se inserta en una transaccion no
            confirmable.
        */
        IF XACT_STATE()<>-1
        BEGIN TRY
            INSERT T3.RF_ERROR_LOG(Fecha,Rutina,Referencia,ERROR_DESC)
            VALUES(GETDATE(),''PROC_T3_OT_GENERAL'',@Factura,LEFT(@Mensaje,250));
        END TRY
        BEGIN CATCH
            PRINT ''No fue posible guardar el error del coordinador; conservar el mensaje devuelto.'';
        END CATCH;
        -- Error del coordinador con referencia y causa: el numero original
        -- queda incluido en el texto del mensaje.
        THROW 53809,@Mensaje,1;
    END CATCH;
END;
';
IF @Actual IS NULL THROW 53850,'No se puede leer la definicion instalada del coordinador.',1;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() Captura,
       CONVERT(varchar(64),HASHBYTES('SHA2_256',@Actual),2) HashActual;
IF @Aplicar=0
BEGIN
    SELECT @Actual AS [DefinicionActual],@Nueva AS [DefinicionPropuesta]
    FOR XML PATH('Revision'),TYPE;
    SELECT 'VISTA PREVIA; NO SE ALTERO NINGUN MODULO. Revisar el ALTER completo antes de @Aplicar=1.' Resultado;
    RETURN;
END;
IF @@TRANCOUNT<>0 THROW 53851,'Ejecutar despliegue sin transaccion externa.',1;
IF CHARINDEX('CAST(@Doc_tasa AS DECIMAL(38,12)) / 100.0',
    ISNULL(OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')),N''))=0
    THROW 53852,'Falta verificar el parche numerico del generador (02_CORREGIR_MODULO.sql).',1;
DECLARE @Id int,@Lock int;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @Lock=sys.sp_getapplock @Resource='REPAIR_OT_GENERAL_20261029',
        @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
    IF @Lock<0 THROW 53853,'No se obtuvo el bloqueo del despliegue.',1;
    IF @Actual<>OBJECT_DEFINITION(OBJECT_ID('T3.PROC_T3_OT_GENERAL'))
        THROW 53854,'El modulo cambio durante la revision; volver a revisar.',1;
    IF OBJECT_ID('dbo.REPAIR_OT_GENERAL_20261029','U') IS NULL
        CREATE TABLE dbo.REPAIR_OT_GENERAL_20261029(
            Id int IDENTITY PRIMARY KEY,Captura datetime2(7) NOT NULL DEFAULT SYSDATETIME(),
            DefinicionAntes nvarchar(max) NOT NULL,DefinicionDespues nvarchar(max) NULL,
            AnsiNullsAntes bit NOT NULL,QuotedIdentifierAntes bit NOT NULL,
            Reversion datetime2(7) NULL);
    IF EXISTS(SELECT 1 FROM dbo.REPAIR_OT_GENERAL_20261029
        WHERE Reversion IS NULL AND DefinicionDespues=@Actual)
    BEGIN
        COMMIT;
        SELECT 'CORRECCION YA INSTALADA; NO SE REAPLICO' Resultado;
        RETURN;
    END;
    INSERT dbo.REPAIR_OT_GENERAL_20261029(DefinicionAntes,AnsiNullsAntes,QuotedIdentifierAntes)
    SELECT @Actual,uses_ansi_nulls,uses_quoted_identifier FROM sys.sql_modules
    WHERE object_id=OBJECT_ID('T3.PROC_T3_OT_GENERAL');
    SET @Id=CONVERT(int,SCOPE_IDENTITY());
    EXEC sys.sp_executesql @Nueva;
    UPDATE dbo.REPAIR_OT_GENERAL_20261029
    SET DefinicionDespues=OBJECT_DEFINITION(OBJECT_ID('T3.PROC_T3_OT_GENERAL')) WHERE Id=@Id;
    COMMIT;
    SELECT 'CORRECCION INSTALADA; NO SE EJECUTO EL PROCEDIMIENTO' Resultado,@Id Respaldo;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
  EAI.CC_SALESDOC_LDR_TO_CIFRAS - migracion nueva desde el procedimiento Oracle.

  OBJETIVO: llevar TAO_SALES_DOCS_LDR a cifras comerciales, produccion u otros.
  No carga archivos ni cambia el cliente 53545044: eso pertenece al BAT/SQL llamador.

  PARAMETROS:
    @pTruncate = 'Y': limpia comerciales y produccion antes de cargar.
                     NO limpia la tabla de otros ni la tabla de entrada.
    @pOutput > 0   : imprime los contadores de esta ejecucion.

  CARGA PARCIAL, confirmada por el usuario:
    Cada documento se confirma por separado. Si falla, se revierte solo ese
    documento, se registra en ERROR_TABLE y se continua con los siguientes.
    Los documentos confirmados NO se deshacen ante un error posterior.
    No llamar dentro de una transaccion externa: el procedimiento administra
    sus propias transacciones y no debe confirmar o revertir las del llamador.

  RESULTADO: RETURN 0 = sin rechazos; RETURN 1 = carga parcial con rechazos;
             RETURN 2 = llamada rechazada por opciones de transaccion.
    Un error general se registra en MX_EAI_MESSAGE_LOG y se propaga con THROW.
    Ejemplo: DECLARE @rc int; EXEC @rc=EAI.CC_SALESDOC_LDR_TO_CIFRAS
                 @pTruncate='N',@pOutput=1; SELECT @rc AS Resultado;

  Se usa un cursor STATIC para conservar la foto inicial de los JOIN de Oracle.
  No se eliminan duplicados de la entrada ni de los cruces silenciosamente.
  La repeticion de un documento comercial nuevo puede producir varias filas,
  igual que el cursor Oracle. Revisar la entrada antes de ejecutar.
*/
CREATE OR ALTER PROCEDURE EAI.CC_SALESDOC_LDR_TO_CIFRAS
    @pTruncate varchar(1) = 'N',
    @pOutput int = 0
AS
BEGIN
    -- MIGRATION_VERSION: CC_SALESDOC_LDR_TO_CIFRAS_20260918
    SET NOCOUNT ON;
    -- Mensaje informativo y RETURN 2: no lanzar una excepcion que pueda afectar
    -- una transaccion externa. El llamador debe comprobar el codigo de retorno.
    IF @@TRANCOUNT<>0
    BEGIN
        RAISERROR('ERROR: ejecutar CC_SALESDOC_LDR_TO_CIFRAS sin una transaccion externa.',10,1) WITH NOWAIT;
        RETURN 2;
    END;
    IF (2 & @@OPTIONS)=2
    BEGIN
        RAISERROR('ERROR: ejecutar con IMPLICIT_TRANSACTIONS OFF.',10,1) WITH NOWAIT;
        RETURN 2;
    END;
    -- Un error revierte la transaccion del documento actual; el CATCH permite
    -- registrar el problema fuera de esa transaccion y continuar la carga.
    SET XACT_ABORT ON;
    SET ANSI_WARNINGS ON;
    SET NUMERIC_ROUNDABORT OFF;
    SET CURSOR_CLOSE_ON_COMMIT OFF;

    DECLARE @Proceso int=701, @PID bigint, @Inicio datetime2(7)=SYSDATETIME(),
            @Leidos bigint=0, @Insertados bigint=0, @Rechazados bigint=0,
            @Corregidos bigint=0, @Afectados int, @Bloqueo int,
            @TieneBloqueo bit=0, @ErrorNumero int, @ErrorMensaje nvarchar(4000);
    -- Campos de una fila del cursor: se mantienen los anchos de la entrada.
    DECLARE @Fecha varchar(8), @Distribuidor varchar(4), @Cliente varchar(20),
            @Documento varchar(20), @Pedido varchar(20),
            @Ref1 varchar(30), @Ref2 varchar(30), @Tipo varchar(4),
            @Estado varchar(1), @Neto decimal(13,3), @Impuesto decimal(13,3),
            @Cantidad decimal(13,3), @DocumentoExistente varchar(20),
            @FacturaPreventa varchar(30), @Referencia varchar(30), @FolioFiscal varchar(30);

    BEGIN TRY
        -- 1. No permitir dos ejecuciones de este procedimiento en la misma base.
        -- El propietario Session mantiene el bloqueo entre COMMIT por documento.
        EXEC @Bloqueo=sys.sp_getapplock
            @Resource=N'EAI.CC_SALESDOC_LDR_TO_CIFRAS',@LockMode='Exclusive',
            @LockOwner='Session',@LockTimeout=0;
        IF @Bloqueo<0 THROW 51402,'Otra carga de cifras de ventas esta en ejecucion.',1;
        SET @TieneBloqueo=1;

        -- 2. Registrar el inicio con las mismas dependencias que Oracle.
        SET @PID=NEXT VALUE FOR EAI_OWNER.ProcessID;
        EXEC EAI_OWNER.LOG_START @nComponent=@Proceso;
        INSERT T3.RF_PROCESOS_LOG(PID,PROCESO,FECHA_PROC_BATMD,INICIO)
        VALUES (@PID,@Proceso,NULL,@Inicio);

        IF ISNULL(@pTruncate,'N') COLLATE Latin1_General_100_BIN2='Y'
        BEGIN
            -- Operacion destructiva OPCIONAL, desactivada por defecto.
            -- Ambos vaciados se confirman juntos; luego comienza la carga parcial.
            BEGIN TRANSACTION;
            TRUNCATE TABLE EAI.T3R_SALES_DOCS_OLD;
            TRUNCATE TABLE EAI.T3R_SALES_DOCS_LDR_MX01;
            COMMIT TRANSACTION;
        END;
        UPDATE EAI.CONTROL_REPORTE SET INICIO=@Inicio,FIN=NULL
        WHERE REPORTE IN ('LOAD CIFRAS VENTAS','AUTO-UPLOAD VENTAS');

        -- 3. Foto de los documentos y sus referencias al abrir el cursor.
        -- Oracle (+) se expresa como LEFT JOIN. Se conserva su multiplicidad.
        -- La precedencia del tipo es: preventa, factura, equivalencia SAP, original.
        -- ROWID de Oracle no se necesita: no participaba en ninguna escritura.
        DECLARE Documentos CURSOR LOCAL STATIC READ_ONLY FOR
            SELECT L.DOC_DATE,L.DISTRIBUTOR,L.CUSTOMER,L.DOC_NUM_R3,L.DOC_ORD_R3,
                   L.DOC_NUM_REF2,L.DOC_NUM_REF1,
                   COALESCE(NULLIF(PG.CLASE_FACTURA,''),NULLIF(FG.TIPO_DOCTO,''),
                       CASE L.DOC_TYPE COLLATE Latin1_General_100_BIN2
                            WHEN 'ZF2' THEN 'C003' WHEN 'ZRE' THEN 'C004'
                            ELSE L.DOC_TYPE END),
                   L.DOC_STATUS,L.DOC_NETAMT,L.DOC_TAXAMT,L.DOC_QTY,
                   ISNULL(CC.DOC_NUM_R3,'NULL'),NULLIF(PG.FACTURA,'')
            FROM EAI.TAO_SALES_DOCS_LDR L
            LEFT JOIN EAI.T3R_SALES_DOCS_OLD CC ON CC.DOC_NUM_R3=L.DOC_NUM_R3
            LEFT JOIN T3.PREVENTA_GENERAL PG ON PG.ENTREGA=L.DOC_NUM_R3
            LEFT JOIN T3.FACTURA_GENERAL FG ON FG.FACTURA=L.DOC_NUM_REF1;
        OPEN Documentos;
        FETCH NEXT FROM Documentos INTO @Fecha,@Distribuidor,@Cliente,@Documento,@Pedido,
            @Ref1,@Ref2,@Tipo,@Estado,@Neto,@Impuesto,@Cantidad,@DocumentoExistente,@FacturaPreventa;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Leidos+=1;
            BEGIN TRY
                -- Un documento ya comercial no se vuelve a insertar.
                -- Se conserva el marcador 'NULL' usado por el cursor Oracle.
                IF @DocumentoExistente COLLATE Latin1_General_100_BIN2='NULL'
                BEGIN
                    -- Sin preventa: REF1 destino <- REF2 entrada; REF2 <- REF1.
                    -- Con factura de preventa: REF1 <- REF1 entrada;
                    --                         REF2 <- factura de preventa.
                    SET @Referencia=CASE WHEN @FacturaPreventa IS NOT NULL THEN @Ref2 ELSE @Ref1 END;
                    SET @FolioFiscal=COALESCE(@FacturaPreventa,@Ref2);
                    BEGIN TRANSACTION;
                    IF @Tipo COLLATE Latin1_General_100_BIN2 IN ('C003','C004','C005','C006','C0FX','C019')
                    BEGIN
                        -- COMERCIALES. SQL Server convierte CUSTOMER a numeric
                        -- y redondea importes/cantidad a los 2 decimales del destino.
                        INSERT EAI.T3R_SALES_DOCS_OLD
                            (DOC_DATE,DISTRIBUTOR,CUSTOMER,DOC_NUM_R3,DOC_ORD_R3,
                             DOC_NUM_REF1,DOC_NUM_REF2,DOC_TYPE,CREATED,
                             DOC_STATUS,DOC_NETAMT,DOC_TAXAMT,DOC_QTY)
                        VALUES (@Fecha,@Distribuidor,NULLIF(@Cliente,''),@Documento,@Pedido,
                                @Referencia,@FolioFiscal,@Tipo,SYSDATETIME(),
                                @Estado,@Neto,@Impuesto,@Cantidad);
                        SET @Afectados=1;
                    END
                    ELSE IF @Tipo COLLATE Latin1_General_100_BIN2 IN ('C020','C021','C022')
                    BEGIN
                        -- PRODUCCION. El UPDATE sin cambio se conserva por sus
                        -- posibles triggers. Bloquear la busqueda hasta COMMIT
                        -- evita que otra sesion inserte entre buscar e insertar.
                        UPDATE EAI.T3R_SALES_DOCS_LDR_MX01 WITH (UPDLOCK,HOLDLOCK)
                        SET DOC_QTY=DOC_QTY+0 WHERE DOC_NUM_R3=@Documento;
                        SET @Afectados=@@ROWCOUNT;
                        IF @Afectados=0
                        BEGIN
                            INSERT EAI.T3R_SALES_DOCS_LDR_MX01
                                (DOC_DATE,DISTRIBUTOR,CUSTOMER,DOC_NUM_R3,DOC_ORD_R3,
                                 DOC_NUM_REF1,DOC_NUM_REF2,DOC_TYPE,CREATED,
                                 DOC_STATUS,DOC_NETAMT,DOC_TAXAMT,DOC_QTY)
                            VALUES (@Fecha,@Distribuidor,NULLIF(@Cliente,''),@Documento,@Pedido,
                                    @Referencia,@FolioFiscal,@Tipo,SYSDATETIME(),
                                    @Estado,@Neto,@Impuesto,@Cantidad);
                            SET @Afectados=1;
                        END
                        ELSE SET @Afectados=0; -- No hubo insercion.
                    END
                    ELSE
                    BEGIN
                        -- OTROS. Se corrige el defecto de Oracle: aqui se debe
                        -- leer el ROWCOUNT de ESTE UPDATE, no el de otra fila.
                        UPDATE EAI.T3R_SALES_DOCS_OTHERS WITH (UPDLOCK,HOLDLOCK)
                        SET DOC_QTY=DOC_QTY+0 WHERE DOC_NUM_R3=@Documento;
                        SET @Afectados=@@ROWCOUNT;
                        IF @Afectados=0
                        BEGIN
                            INSERT EAI.T3R_SALES_DOCS_OTHERS
                                (DOC_DATE,DISTRIBUTOR,CUSTOMER,DOC_NUM_R3,DOC_ORD_R3,
                                 DOC_NUM_REF1,DOC_NUM_REF2,DOC_TYPE,CREATED,
                                 DOC_STATUS,DOC_NETAMT,DOC_TAXAMT,DOC_QTY)
                            VALUES (@Fecha,@Distribuidor,NULLIF(@Cliente,''),@Documento,@Pedido,
                                    @Referencia,@FolioFiscal,@Tipo,SYSDATETIME(),
                                    @Estado,@Neto,@Impuesto,@Cantidad);
                            SET @Afectados=1;
                        END
                        ELSE SET @Afectados=0;
                    END;
                    COMMIT TRANSACTION;
                    SET @Insertados+=@Afectados;
                END;
            END TRY
            BEGIN CATCH
                -- Solo se revierte el documento actual. Las filas anteriores
                -- ya estan confirmadas. Registrar el error despues del rollback.
                IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
                SET @Rechazados+=1;
                INSERT EAI.ERROR_TABLE(DISTRIBUTOR,PROCESS,DOC_NUM,ERR_DATE,MESSAGE,CTRO)
                VALUES (TRY_CONVERT(numeric(4,0),@Distribuidor),'CC_SALESDOC_LDR_TO_CIFRAS',
                        @Documento,SYSDATETIME(),
                        LEFT(CONCAT('PID ',@PID,'; Error SQL ',ERROR_NUMBER(),': ',ERROR_MESSAGE()),480),NULL);
            END CATCH;
            FETCH NEXT FROM Documentos INTO @Fecha,@Distribuidor,@Cliente,@Documento,@Pedido,
                @Ref1,@Ref2,@Tipo,@Estado,@Neto,@Impuesto,@Cantidad,@DocumentoExistente,@FacturaPreventa;
        END;
        CLOSE Documentos;
        DEALLOCATE Documentos;

        -- 4. Correccion posterior de impuesto/estado. Tambien usa una foto:
        -- solo selecciona pares cuyo destino estaba F, impuesto 0, y cuya
        -- entrada tiene impuesto positivo. El UPDATE alcanza todas las filas
        -- del numero de documento, como en Oracle, incluso si hay duplicados.
        DECLARE CorregirEstado CURSOR LOCAL STATIC READ_ONLY FOR
            SELECT L.DOC_NUM_R3,L.DOC_STATUS,L.DOC_TAXAMT
            FROM EAI.TAO_SALES_DOCS_LDR L
            INNER JOIN EAI.T3R_SALES_DOCS_OLD F ON F.DOC_NUM_R3=L.DOC_NUM_R3
            WHERE F.DOC_STATUS COLLATE Latin1_General_100_BIN2='F'
              AND L.DOC_TAXAMT>0 AND F.DOC_TAXAMT=0;
        OPEN CorregirEstado;
        FETCH NEXT FROM CorregirEstado INTO @Documento,@Estado,@Impuesto;
        WHILE @@FETCH_STATUS=0
        BEGIN
            -- Un error en esta fase es general, como en ScrStatusF de Oracle.
            UPDATE EAI.T3R_SALES_DOCS_OLD SET DOC_TAXAMT=@Impuesto,DOC_STATUS=@Estado
            WHERE DOC_NUM_R3=@Documento;
            SET @Corregidos+=@@ROWCOUNT;
            FETCH NEXT FROM CorregirEstado INTO @Documento,@Estado,@Impuesto;
        END;
        CLOSE CorregirEstado;
        DEALLOCATE CorregirEstado;

        -- 5. Cerrar los controles. No inventar significados para PROCESO_1..4:
        -- en Oracle se escribian 0, NULL, 0, 0 (nProceso2 nunca se asignaba).
        UPDATE EAI.CONTROL_REPORTE SET FIN=SYSDATETIME()
        WHERE REPORTE IN ('LOAD CIFRAS VENTAS','AUTO-UPLOAD VENTAS');
        UPDATE EAI_OWNER.MX_COMPONENTS SET STATUS=1 WHERE COMPONENT=@Proceso;
        UPDATE T3.RF_PROCESOS_LOG
        SET FIN=SYSDATETIME(),PROCESO_1=0,PROCESO_2=NULL,PROCESO_3=0,PROCESO_4=0
        WHERE PID=@PID;
        IF ISNULL(@pOutput,0)>0
        BEGIN
            PRINT CONCAT('PID      -> ',@PID);
            PRINT CONCAT('Starting -> ',CONVERT(varchar(19),@Inicio,120));
            PRINT CONCAT('Records  -> ',@Leidos);
            PRINT CONCAT('Inserts  -> ',@Insertados);
            PRINT CONCAT('Rejected -> ',@Rechazados);
            PRINT CONCAT('Status F -> ',@Corregidos);
            PRINT CONCAT('End      -> ',CONVERT(varchar(19),SYSDATETIME(),120));
        END;
        EXEC sys.sp_releaseapplock @Resource=N'EAI.CC_SALESDOC_LDR_TO_CIFRAS',@LockOwner='Session';
        SET @TieneBloqueo=0;
        IF @Rechazados>0
        BEGIN
            PRINT CONCAT('CARGA PARCIAL: ',@Rechazados,' registros rechazados. Revisar EAI.ERROR_TABLE; PID ',@PID,'.');
            RETURN 1;
        END;
        RETURN 0;
    END TRY
    BEGIN CATCH
        -- 6. Fallo general: liberar recursos y conservar la causa original.
        SET @ErrorNumero=ERROR_NUMBER();
        SET @ErrorMensaje=ERROR_MESSAGE();
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        IF CURSOR_STATUS('local','Documentos')>=0 CLOSE Documentos;
        IF CURSOR_STATUS('local','Documentos')>=-1 DEALLOCATE Documentos;
        IF CURSOR_STATUS('local','CorregirEstado')>=0 CLOSE CorregirEstado;
        IF CURSOR_STATUS('local','CorregirEstado')>=-1 DEALLOCATE CorregirEstado;
        IF @TieneBloqueo=1
            EXEC sys.sp_releaseapplock @Resource=N'EAI.CC_SALESDOC_LDR_TO_CIFRAS',@LockOwner='Session';
        BEGIN TRY
            INSERT EAI_OWNER.MX_EAI_MESSAGE_LOG
                (DIRECTION,ID,CREATED,MESSAGE,JOB_PID,STATUS,QUEUE_NAME,
                 SIEBEL_ERROR_MESSAGE,SOURCE,SIEBEL_ERROR_CODE,RETRY_COUNT,SEQUENCE,PARENT_ROW_ID)
            VALUES ('CifrasControl',NULL,SYSDATETIME(),NULL,@PID,'Error',
                    'CC_SALESDOC_LDR_TO_CIFRAS',LEFT(@ErrorMensaje,2000),'TSQL',
                    CONVERT(varchar(100),@ErrorNumero),NULL,NULL,NULL);
        END TRY
        BEGIN CATCH
            -- Si tambien falla el log, no ocultar el error que causo el fallo.
            PRINT CONCAT('No se pudo registrar el error general: ',ERROR_MESSAGE());
        END CATCH;
        THROW;
    END CATCH;
END;
GO

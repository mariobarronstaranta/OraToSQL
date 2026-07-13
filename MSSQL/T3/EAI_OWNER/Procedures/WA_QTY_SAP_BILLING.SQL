CREATE OR ALTER PROCEDURE EAI_Owner.WA_QTY_SAP_BILLING
(
    @pReference      VARCHAR(100),
    @pMaterial       VARCHAR(100),
    @pCantidad       DECIMAL(38,10),
    @pUnidadMedida   VARCHAR(30),
    @pCantUMV        DECIMAL(38,10) OUTPUT,
    @pUMV            VARCHAR(30) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sWorkaround       VARCHAR(500),
        @Material          VARCHAR(100),
        @Nombre_Material   VARCHAR(255),
        @Material_Group    VARCHAR(100),
        @SAT_Clave         VARCHAR(100),
        @Unidad_Med_Vta    VARCHAR(30),
        @Cig_x_CLL         DECIMAL(38,10),
        @Cig_x_PAQ         DECIMAL(38,10),
        @Cig_x_CT          DECIMAL(38,10),
        @Factor_PAQ        DECIMAL(38,10),
        @Paq_x_Carton      DECIMAL(38,10),
        @Fecha_Creacion    DATETIME,
        @Categoria         VARCHAR(30);

    BEGIN TRY
        /*
            Valores default equivalentes al inicio del procedure Oracle:
            pCantUMV := pCantidad;
            pUMV     := pUnidadMedida;
        */
        SET @pCantUMV = @pCantidad;
        SET @pUMV     = @pUnidadMedida;

        /*
            Equivalente a:
            SELECT EAI_Owner.GETCONV('ECC_V3 UOM', pUnidadMedida)
            INTO pUMV
            FROM DUAL;
        */
        SELECT @pUMV = EAI_Owner.GETCONV('ECC_V3 UOM', @pUnidadMedida);

        /*
            Reemplazo del cursor ScrProducto.
            Se usa TOP (1) porque el procedure procesa un solo material.
        */
        SELECT TOP (1)
               @Material        = Info.Material,
               @Nombre_Material = Info.Nombre_Material,
               @Material_Group  = Info.Material_Group,
               @SAT_Clave       = Info.SAT_Clave,
               @Unidad_Med_Vta  = Info.Unidad_Med_Vta,
               @Cig_x_CLL       = Info.Cig_x_CLL,
               @Cig_x_PAQ       = Info.Cig_x_PAQ,
               @Cig_x_CT        = Info.Cig_x_CT,
               @Factor_PAQ      = Info.Factor_PAQ,
               @Paq_x_Carton    = Info.Paq_x_Carton,
               @Fecha_Creacion  = Info.Fecha_Creacion,
               @Categoria       = Info.Categoria
        FROM
        (
            SELECT
                SKU.Material,
                SKU.Nombre_Material,
                SAT.SAT_Clave,
                SKU.Unidad_Med_Vta,
                COALESCE(SKU.Cig_x_CLL, 0) AS Cig_x_CLL,
                COALESCE(SKU.Cig_x_PAQ, 0) AS Cig_x_PAQ,
                COALESCE(SKU.Cig_x_CT,  0) AS Cig_x_CT,

                CASE
                    WHEN COALESCE(SKU.Cig_x_CLL, 0) = 0 THEN 0
                    ELSE COALESCE(SKU.Cig_x_PAQ, 0) / COALESCE(SKU.Cig_x_CLL, 0)
                END AS Factor_PAQ,

                CASE
                    WHEN COALESCE(SKU.Cig_x_PAQ, 0) = 0 THEN 0
                    ELSE COALESCE(SKU.Cig_x_CT, 0) / COALESCE(SKU.Cig_x_PAQ, 0)
                END AS Factor_CARTON,

                SKU.Creacion AS Fecha_Creacion,

                CASE
                    WHEN CHARINDEX('EPOD', UPPER(SKU.Nombre_Material)) > 0 THEN 'VAPOR'
                    WHEN CHARINDEX('VYPE', UPPER(SKU.Nombre_Material)) > 0 THEN 'VAPOR'
                    WHEN CHARINDEX('VUSE', UPPER(SKU.Nombre_Material)) > 0 THEN 'VAPOR'
                    WHEN CHARINDEX('VELO', UPPER(SKU.Nombre_Material)) > 0 THEN 'VELO'
                    WHEN SKU.Material LIKE '50%' THEN 'PP'
                    WHEN COALESCE(SKU.Cig_x_CLL, 0) IN (14, 15, 16, 18, 20, 24, 25) THEN 'FMC'
                    ELSE 'TBD'
                END AS Categoria,

                SKU.Nombre_Corto AS Material_Group
            FROM T3.Material AS SKU
            LEFT JOIN
            (
                SELECT
                    Material,
                    MAX(SAT_Clave) AS SAT_Clave
                FROM T3.CFDI_ProdServ
                WHERE Modulo = 'VTA'
                GROUP BY Material
            ) AS SAT
                ON SKU.Material = SAT.Material
            WHERE COALESCE(SKU.Creacion, GETDATE()) > CONVERT(DATETIME, '20150101', 112)
        ) AS Info
        WHERE Info.Material = @pMaterial;

        /*
            Si no existe el material, Oracle no entra al FOR LOOP.
            Por lo tanto, se conservan los valores ya asignados:
            @pCantUMV = @pCantidad
            @pUMV     = GETCONV(...)
        */
        IF @Material IS NULL
        BEGIN
            RETURN;
        END;

        /*
            Conversión para MIL, PZ, PCE.
        */
        IF @pUnidadMedida IN ('MIL')
        BEGIN
            IF COALESCE(@Cig_x_CLL, 0) > 0
            BEGIN
                SET @pUMV     = @Unidad_Med_Vta;
                SET @pCantUMV = @pCantidad * 1000 / COALESCE(@Cig_x_CLL, 0);
            END;
        END
        ELSE IF @pUnidadMedida IN ('PZ', 'PCE')
        BEGIN
            IF COALESCE(@Cig_x_CLL, 0) > 0
            BEGIN
                SET @pUMV     = @Unidad_Med_Vta;
                SET @pCantUMV = @pCantidad / COALESCE(@Cig_x_CLL, 0);
            END;
        END;

        /*
            Conversiones especiales para categoría FMC.
        */
        IF @Categoria = 'FMC'
        BEGIN
            IF @pUMV = 'PAQ'
            BEGIN
                IF COALESCE(@Factor_PAQ, 0) > 0
                BEGIN
                    SET @pUMV     = @Unidad_Med_Vta;
                    SET @pCantUMV = @pCantidad * @Factor_PAQ;

                    /*
                        Mejora: en Oracle esta rama inserta sWorkaround sin asignarlo antes.
                        Aquí se asigna para evitar log NULL.
                    */
                    SET @sWorkaround =
                        CONCAT(
                            'Conversion de ',
                            LTRIM(RTRIM(CONVERT(VARCHAR(50), CAST(@pCantidad AS DECIMAL(38,4))))),
                            ' ',
                            @pUnidadMedida,
                            ' -> ',
                            LTRIM(RTRIM(CONVERT(VARCHAR(50), CAST(@pCantUMV AS DECIMAL(38,4))))),
                            ' ',
                            @pUMV
                        );

                    INSERT INTO EAI_Owner.WA_Logging
                    (
                        Fecha,
                        Usuario,
                        Usuario_Red,
                        IP,
                        Terminal,
                        Documento,
                        Comentario
                    )
                    VALUES
                    (
                        GETDATE(),
                        SUSER_SNAME(),
                        ORIGINAL_LOGIN(),
                        CONVERT(VARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
                        HOST_NAME(),
                        @pReference,
                        @sWorkaround
                    );
                END;
            END
            ELSE IF @pUMV = 'CASES'
            BEGIN
                IF COALESCE(@Factor_PAQ, 0) > 0
                   AND COALESCE(@Paq_x_Carton, 0) > 0
                BEGIN
                    SET @pUMV     = @Unidad_Med_Vta;
                    SET @pCantUMV = @pCantidad * @Factor_PAQ * @Paq_x_Carton;

                    SET @sWorkaround =
                        CONCAT(
                            'Conversion de ',
                            LTRIM(RTRIM(CONVERT(VARCHAR(50), CAST(@pCantidad AS DECIMAL(38,4))))),
                            ' ',
                            @pUnidadMedida,
                            ' -> ',
                            LTRIM(RTRIM(CONVERT(VARCHAR(50), CAST(@pCantUMV AS DECIMAL(38,4))))),
                            ' ',
                            @pUMV
                        );

                    INSERT INTO EAI_Owner.WA_Logging
                    (
                        Fecha,
                        Usuario,
                        Usuario_Red,
                        IP,
                        Terminal,
                        Documento,
                        Comentario
                    )
                    VALUES
                    (
                        GETDATE(),
                        SUSER_SNAME(),
                        ORIGINAL_LOGIN(),
                        CONVERT(VARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
                        HOST_NAME(),
                        @pReference,
                        @sWorkaround
                    );
                END;
            END;
        END
        /*
            Conversiones especiales para categoría PP.
        */
        ELSE IF @Categoria = 'PP'
        BEGIN
            IF @pUMV = 'CASES'
            BEGIN
                IF COALESCE(@Factor_PAQ, 0) > 0
                   AND COALESCE(@Paq_x_Carton, 0) > 0
                BEGIN
                    SET @pUMV     = @Unidad_Med_Vta;
                    SET @pCantUMV = @pCantidad * @Paq_x_Carton;

                    SET @sWorkaround =
                        CONCAT(
                            'Conversion de ',
                            LTRIM(RTRIM(CONVERT(VARCHAR(50), CAST(@pCantidad AS DECIMAL(38,4))))),
                            ' ',
                            @pUnidadMedida,
                            ' -> ',
                            LTRIM(RTRIM(CONVERT(VARCHAR(50), CAST(@pCantUMV AS DECIMAL(38,4))))),
                            ' ',
                            @pUMV
                        );

                    INSERT INTO EAI_Owner.WA_Logging
                    (
                        Fecha,
                        Usuario,
                        Usuario_Red,
                        IP,
                        Terminal,
                        Documento,
                        Comentario
                    )
                    VALUES
                    (
                        GETDATE(),
                        SUSER_SNAME(),
                        ORIGINAL_LOGIN(),
                        CONVERT(VARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
                        HOST_NAME(),
                        @pReference,
                        @sWorkaround
                    );
                END;
            END;
        END;
    END TRY
    BEGIN CATCH
        /*
            Equivalente funcional a:
            EXCEPTION
               WHEN OTHERS THEN
                  pCantUMV := pCantidad;
                  pUMV     := pUnidadMedida;
            
            Se conserva el comportamiento original:
            no relanza error y devuelve valores originales.
        */
        SET @pCantUMV = @pCantidad;
        SET @pUMV     = @pUnidadMedida;

        /*
            Opcional recomendado:
            registrar error técnico en una tabla de errores si existe.
            No se incluye THROW para respetar el comportamiento Oracle.
        */
    END CATCH;
END;
GO
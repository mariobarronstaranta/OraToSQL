/*
    Homologo SQL Server de EAI_OWNER.WA_QTY_SAP_BILLING (Oracle).

    Convierte una cantidad facturada a la unidad de medida de venta del
    material. La conversion depende de la unidad recibida, los factores del
    maestro de materiales y la categoria calculada (FMC, PP, VAPOR, etc.).

    El procedimiento Oracle usa un cursor. Aunque normalmente Material deberia
    ser unico, aqui tambien se recorren todas las coincidencias para conservar
    el comportamiento si existen duplicados en el maestro.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_QTY_SAP_BILLING]
(
    @pReference    VARCHAR(100),
    @pMaterial     VARCHAR(100),
    @pCantidad     DECIMAL(38,10),
    @pUnidadMedida VARCHAR(30),
    @pCantUMV      DECIMAL(38,10) OUTPUT,
    @pUMV          VARCHAR(30) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    /* El WHEN OTHERS de Oracle recupera valores sin propagar el error. */
    SET XACT_ABORT OFF;

    DECLARE
        @sUnidadMedVta VARCHAR(30),
        @nCigPorCLL    DECIMAL(38,10),
        @nFactorPAQ    DECIMAL(38,10),
        @nPaqPorCarton DECIMAL(38,10),
        @sCategoria    VARCHAR(30),
        @sWorkaround   VARCHAR(500);

    BEGIN TRY
        ----------------------------------------------------------------------
        -- 1. Valores de salida iniciales y homologacion de la unidad SAP.
        ----------------------------------------------------------------------
        SET @pCantUMV = @pCantidad;
        SET @pUMV = @pUnidadMedida;

        SET @pUMV = [EAI_OWNER].[GETCONV]('ECC_V3 UOM', @pUnidadMedida);

        ----------------------------------------------------------------------
        -- 2. Maestro del material: equivalente al cursor ScrProducto.
        ----------------------------------------------------------------------
        DECLARE ScrProducto CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                SKU.Unidad_Med_Vta,
                CONVERT(DECIMAL(38,10), COALESCE(SKU.Cig_x_CLL, 0)),
                CASE
                    WHEN COALESCE(SKU.Cig_x_CLL, 0) = 0 THEN 0
                    ELSE
                        CONVERT(DECIMAL(38,10), COALESCE(SKU.Cig_x_PAQ, 0))
                        / CONVERT(DECIMAL(38,10), SKU.Cig_x_CLL)
                END AS Factor_PAQ,
                CASE
                    WHEN COALESCE(SKU.Cig_x_PAQ, 0) = 0 THEN 0
                    ELSE
                        CONVERT(DECIMAL(38,10), COALESCE(SKU.Cig_x_CT, 0))
                        / CONVERT(DECIMAL(38,10), SKU.Cig_x_PAQ)
                END AS Paq_x_Carton,
                CASE
                    WHEN CHARINDEX('EPOD', UPPER(SKU.Nombre_Material)) > 0
                        THEN 'VAPOR'
                    WHEN CHARINDEX('VYPE', UPPER(SKU.Nombre_Material)) > 0
                        THEN 'VAPOR'
                    WHEN CHARINDEX('VUSE', UPPER(SKU.Nombre_Material)) > 0
                        THEN 'VAPOR'
                    WHEN CHARINDEX('VELO', UPPER(SKU.Nombre_Material)) > 0
                        THEN 'VELO'
                    WHEN SKU.Material LIKE '50%'
                        THEN 'PP'
                    WHEN COALESCE(SKU.Cig_x_CLL, 0)
                         IN (14, 15, 16, 18, 20, 24, 25)
                        THEN 'FMC'
                    ELSE 'TBD'
                END AS Categoria
            FROM [T3].[MATERIAL] AS SKU
            LEFT JOIN
            (
                /*
                    Oracle obtiene la mayor clave SAT de VTA. La columna no se
                    usa despues, pero se conserva el join del cursor original.
                */
                SELECT
                    Material,
                    MAX(SAT_Clave) AS SAT_Clave
                FROM [T3].[CFDI_PRODSERV]
                WHERE Modulo = 'VTA'
                GROUP BY Material
            ) AS SAT
                ON SAT.Material = SKU.Material
            WHERE COALESCE(SKU.Creacion, SYSDATETIME())
                  > CONVERT(date, '20150101', 112)
              AND SKU.Material = @pMaterial;

        OPEN ScrProducto;

        FETCH NEXT FROM ScrProducto INTO
            @sUnidadMedVta,
            @nCigPorCLL,
            @nFactorPAQ,
            @nPaqPorCarton,
            @sCategoria;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            ------------------------------------------------------------------
            -- 2.1 Conversion inicial de millares o piezas a unidad de venta.
            ------------------------------------------------------------------
            IF @pUnidadMedida = 'MIL'
            BEGIN
                IF COALESCE(@nCigPorCLL, 0) > 0
                BEGIN
                    SET @pUMV = @sUnidadMedVta;
                    SET @pCantUMV = @pCantidad * 1000
                                  / COALESCE(@nCigPorCLL, 0);
                END;
            END
            ELSE IF @pUnidadMedida IN ('PZ', 'PCE')
            BEGIN
                IF COALESCE(@nCigPorCLL, 0) > 0
                BEGIN
                    SET @pUMV = @sUnidadMedVta;
                    SET @pCantUMV = @pCantidad
                                  / COALESCE(@nCigPorCLL, 0);
                END;
            END;

            ------------------------------------------------------------------
            -- 2.2 Reglas especiales para materiales FMC.
            ------------------------------------------------------------------
            IF @sCategoria = 'FMC'
            BEGIN
                IF @pUMV = 'PAQ'
                BEGIN
                    IF @nFactorPAQ > 0
                    BEGIN
                        SET @pUMV = @sUnidadMedVta;
                        SET @pCantUMV = @pCantidad * @nFactorPAQ;

                        /*
                            Oracle no asigna sWorkaround en esta rama. Por
                            compatibilidad el comentario se inserta NULL, salvo
                            que una iteracion anterior ya le haya dado valor.
                        */
                        INSERT INTO [EAI_OWNER].[WA_LOGGING]
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
                            SYSDATETIME(),
                            SUSER_SNAME(),
                            ORIGINAL_LOGIN(),
                            CONVERT(VARCHAR(50),
                                    CONNECTIONPROPERTY('client_net_address')),
                            HOST_NAME(),
                            @pReference,
                            @sWorkaround
                        );
                    END;
                END
                ELSE IF @pUMV = 'CASES'
                BEGIN
                    IF @nFactorPAQ > 0 AND @nPaqPorCarton > 0
                    BEGIN
                        SET @pUMV = @sUnidadMedVta;
                        SET @pCantUMV = @pCantidad
                                      * @nFactorPAQ
                                      * @nPaqPorCarton;

                        SET @sWorkaround = CONCAT
                        (
                            'Conversion de ',
                            CONVERT(VARCHAR(50), @pCantidad),
                            ' ', @pUnidadMedida, ' -> ',
                            CONVERT(VARCHAR(50), @pCantUMV),
                            ' ', @pUMV
                        );

                        INSERT INTO [EAI_OWNER].[WA_LOGGING]
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
                            SYSDATETIME(),
                            SUSER_SNAME(),
                            ORIGINAL_LOGIN(),
                            CONVERT(VARCHAR(50),
                                    CONNECTIONPROPERTY('client_net_address')),
                            HOST_NAME(),
                            @pReference,
                            @sWorkaround
                        );
                    END;
                END;
            END
            ------------------------------------------------------------------
            -- 2.3 Los materiales PP convierten CASES solo por cajas/carton.
            ------------------------------------------------------------------
            ELSE IF @sCategoria = 'PP'
            BEGIN
                IF @pUMV = 'CASES'
                   AND @nFactorPAQ > 0
                   AND @nPaqPorCarton > 0
                BEGIN
                    SET @pUMV = @sUnidadMedVta;
                    SET @pCantUMV = @pCantidad * @nPaqPorCarton;

                    SET @sWorkaround = CONCAT
                    (
                        'Conversion de ',
                        CONVERT(VARCHAR(50), @pCantidad),
                        ' ', @pUnidadMedida, ' -> ',
                        CONVERT(VARCHAR(50), @pCantUMV),
                        ' ', @pUMV
                    );

                    INSERT INTO [EAI_OWNER].[WA_LOGGING]
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
                        SYSDATETIME(),
                        SUSER_SNAME(),
                        ORIGINAL_LOGIN(),
                        CONVERT(VARCHAR(50),
                                CONNECTIONPROPERTY('client_net_address')),
                        HOST_NAME(),
                        @pReference,
                        @sWorkaround
                    );
                END;
            END;

            FETCH NEXT FROM ScrProducto INTO
                @sUnidadMedVta,
                @nCigPorCLL,
                @nFactorPAQ,
                @nPaqPorCarton,
                @sCategoria;
        END;

        CLOSE ScrProducto;
        DEALLOCATE ScrProducto;
    END TRY
    BEGIN CATCH
        /* Liberar el cursor sin ocultar el comportamiento del WHEN OTHERS. */
        IF CURSOR_STATUS('local', 'ScrProducto') >= 0
            CLOSE ScrProducto;

        IF CURSOR_STATUS('local', 'ScrProducto') > -2
            DEALLOCATE ScrProducto;

        /* Oracle devuelve los valores originales y no propaga la excepcion. */
        SET @pCantUMV = @pCantidad;
        SET @pUMV = @pUnidadMedida;

        RETURN;
    END CATCH;
END;
GO

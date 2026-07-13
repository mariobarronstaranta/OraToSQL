CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_REPLENISHMENT]
    @sRow_ID VARCHAR(50),
    @nRowNum INT = 1,
    @nOutput INT = 0,
    @nPID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        SF_PROC_REPLENISHMENT
        =====================
        Convierte un XML VanReplenishment en encabezado, partners y detalle.
        Despues clasifica el documento y lo envia al flujo de subdeposito,
        entrega o remision.

        Guia rapida para un developer Jr:
        1. Leer y validar el encabezado XML.
        2. Identificar partners AG, RE, WE y SB.
        3. Limpiar e insertar las tablas temporales del documento.
        4. Convertir unidades y cantidades de cada material.
        5. Calcular el volumen y el estado final.
        6. Ejecutar el procedimiento de negocio correspondiente.

        @nRowNum se conserva por compatibilidad; Oracle no lo utiliza.
    */
    
    -- DECLARACIONES
    DECLARE @sMsg NVARCHAR(500);
    DECLARE @v_ID NVARCHAR(50);
    DECLARE @sErrorCode NVARCHAR(20);
    DECLARE @sProcesar NVARCHAR(2);
    DECLARE @sLineDebug NVARCHAR(999);
    
    -- Header variables
    DECLARE @sReferenceID NVARCHAR(50);
    DECLARE @sShippingPoint NVARCHAR(50);
    DECLARE @sDeliveryType NVARCHAR(50);
    DECLARE @sDeliveryNumber NVARCHAR(20);
    DECLARE @sDeliveryDate NVARCHAR(20);
    DECLARE @sCustomerAG NVARCHAR(50);
    DECLARE @sCustomerWE NVARCHAR(50);
    DECLARE @sCustomerSB NVARCHAR(50);
    DECLARE @sCteFacturaSAP NVARCHAR(50);
    DECLARE @nItems INT;
    DECLARE @sMaterial NVARCHAR(50);
    DECLARE @sPlant NVARCHAR(50);
    DECLARE @sStorageLocation NVARCHAR(50);
    DECLARE @sActualQuantity NVARCHAR(50);
    DECLARE @sSalesUnit NVARCHAR(50);
    DECLARE @sVanName NVARCHAR(50);
    DECLARE @sUMVSAP NVARCHAR(50);
    DECLARE @sQuantityUMV NVARCHAR(50);
    DECLARE @sPOrderNumber NVARCHAR(50);
    DECLARE @sQualifier NVARCHAR(50);
    DECLARE @sRefPurchaseOrder NVARCHAR(50);
    DECLARE @sPurchaseOrder NVARCHAR(50);
    DECLARE @sDocReference NVARCHAR(50);
    DECLARE @sMaterialName NVARCHAR(500);
    DECLARE @sEmp_Row_ID NVARCHAR(50);
    DECLARE @sOrder_Num NVARCHAR(50);
    DECLARE @sOrgVentas NVARCHAR(10);
    DECLARE @sGRID NVARCHAR(80);
    DECLARE @nCounter INT;
    DECLARE @nCasePack DECIMAL(18, 6);
    DECLARE @nVolDetail NUMERIC(14, 2);
    DECLARE @sCountry NVARCHAR(80);
    DECLARE @sPartnerName NVARCHAR(80);
    DECLARE @sCity NVARCHAR(80);
    DECLARE @sDistrict NVARCHAR(80);
    DECLARE @sPostalCode NVARCHAR(80);
    DECLARE @sRegion NVARCHAR(80);
    DECLARE @sAddress NVARCHAR(80);
    DECLARE @sDocNum NVARCHAR(80);
    
    -- Partner variables (Sold-to, Bill-to, Ship-to)
    DECLARE @sSold_Customer NVARCHAR(10);
    DECLARE @sSold_Name NVARCHAR(80);
    DECLARE @sSold_Address NVARCHAR(80);
    DECLARE @sSold_District NVARCHAR(80);
    DECLARE @sSold_City NVARCHAR(80);
    DECLARE @sSold_State NVARCHAR(80);
    DECLARE @sSold_Country NVARCHAR(80);
    DECLARE @sSold_ZipCode NVARCHAR(80);
    
    DECLARE @sBill_Customer NVARCHAR(10);
    DECLARE @sBill_Name NVARCHAR(80);
    DECLARE @sBill_Address NVARCHAR(80);
    DECLARE @sBill_District NVARCHAR(80);
    DECLARE @sBill_City NVARCHAR(80);
    DECLARE @sBill_State NVARCHAR(80);
    DECLARE @sBill_Country NVARCHAR(80);
    DECLARE @sBill_ZipCode NVARCHAR(80);
    
    DECLARE @sShip_Customer NVARCHAR(10);
    DECLARE @sShip_Name NVARCHAR(80);
    DECLARE @sShip_Address NVARCHAR(80);
    DECLARE @sShip_District NVARCHAR(80);
    DECLARE @sShip_City NVARCHAR(80);
    DECLARE @sShip_State NVARCHAR(80);
    DECLARE @sShip_Country NVARCHAR(80);
    DECLARE @sShip_ZipCode NVARCHAR(80);
    
    DECLARE @sOBD NVARCHAR(80);
    DECLARE @sReferenceIDOC NVARCHAR(50);
    DECLARE @sSalesOrganization NVARCHAR(50);
    DECLARE @nFactor_KG NUMERIC(14, 4);
    DECLARE @sUM NVARCHAR(50);
    DECLARE @nCIG_X_CLL INT;
    DECLARE @nCIG_X_PAQ INT;
    DECLARE @nCAJ_x_PAQ DECIMAL(18, 6);
    
    BEGIN TRY
        -- Inicializar variables
        SET @sCountry = '';
        SET @sPartnerName = '';
        SET @sCity = '';
        SET @sDistrict = '';
        SET @sPostalCode = '';
        SET @sRegion = '';
        SET @sAddress = '';
        SET @sDeliveryType = '';  -- 🔴 INICIALIZAR ANTES DE COMPARACIÓN
        SET @nItems = 0;
        SET @nVolDetail = 0;
        SET @sOBD = 'Check OBD';
        SET @sPOrderNumber = '';
        
        -- Trace: Begin
        IF @nOutput > 0
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner] (Created, Object_Type, Object_Reference, Description)
            VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'Begin');
        END
        
        -- ==================== CURSOR 1: DATA ====================
        -- Leer header del XML
        DECLARE @xmlData XML;
        -- XML_Content ya es tipo XML en el modelo SQL Server.
        SELECT @xmlData = XML_Content
        FROM [EAI_Owner].[MX_Receive_Message_Log]
        WHERE Row_ID = @sRow_ID;

        /*
            El FOR ScrData de Oracle no ejecuta el cuerpo si ROW_ID no existe.
            Solo se conserva la traza End, sin modificar estados ni temporales.
        */
        IF @xmlData IS NULL
        BEGIN
            IF @nOutput > 0
                INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'End');

            RETURN 0;
        END;
        
        -- Extraer valores del XML
        SET @sReferenceIDOC = @xmlData.value('(/VanReplenishment/Header/Reference/ReferenceID)[1]', 'NVARCHAR(50)');
        SET @sReferenceID = @xmlData.value('(/VanReplenishment/Message/DeliveryHeader/DeliveryNumber)[1]', 'NVARCHAR(50)');
        SET @sShippingPoint = @xmlData.value('(/VanReplenishment/Message/DeliveryHeader/ShippingPoint)[1]', 'NVARCHAR(50)');
        SET @sDeliveryType = @xmlData.value('(/VanReplenishment/Message/DeliveryHeader/DeliveryType)[1]', 'NVARCHAR(50)');
        SET @sDeliveryNumber = @xmlData.value('(/VanReplenishment/Message/DeliveryHeader/DeliveryNumber)[1]', 'NVARCHAR(20)');
        SET @sSalesOrganization = @xmlData.value('(/VanReplenishment/Message/DeliveryHeader/SalesOrganization)[1]', 'NVARCHAR(50)');
        SET @sGRID = @xmlData.value('(/VanReplenishment/Message/DeliveryHeader/GRID)[1]', 'NVARCHAR(80)');
        SET @sDeliveryDate = @xmlData.value('(/VanReplenishment/Message/DeliveryHeader/DeliveryDate)[1]', 'NVARCHAR(20)');
        
        -- Validaciones de lógica inicial
        SET @v_ID = @sReferenceID;
        SET @sProcesar = 'SI';
        SET @sDocNum = @sReferenceIDOC;
        
        IF @v_ID IS NULL
        BEGIN
            SET @sProcesar = 'NO';
            IF @sReferenceIDOC IS NOT NULL
            BEGIN
                SET @sProcesar = 'SI';
                SET @v_ID = @sReferenceIDOC;
                SET @sReferenceID = @v_ID;
            END
        END
        
        -- Check DeliveryType para Stock Discard
        IF @sDeliveryType = 'Stock Discard'
        BEGIN
            SET @sProcesar = 'SD';
        END
        
        -- Si procesar = 'SI', continuar con lógica principal
        IF @sProcesar = 'SI'
        BEGIN
            SET @sShippingPoint = @sShippingPoint;
            SET @sDeliveryType = @sDeliveryType;
            SET @sDeliveryNumber = @sDeliveryNumber;
            SET @sDeliveryDate = @sDeliveryDate;
            SET @sOrgVentas = @sSalesOrganization;
            SET @sGRID = @sGRID;
            
            -- Validar fecha
            IF LEN(ISNULL(@sDeliveryDate, ' ')) < 5
            BEGIN
                SET @sDeliveryDate = FORMAT(GETDATE(), 'yyyyMMdd HH:mm:ss');
            END
            
            -- Aplicar transformación de tipo de entrega
            IF @sDeliveryType = 'BAT LEFT ON BOARD DI'
            BEGIN
                SET @sDeliveryType = 'Stock Transfer';
            END
            
            -- ==================== CURSOR 2: PARTNERS ====================
            -- Usar .nodes() para iterar sobre elementos Partner en XML
            DECLARE @PartnerFunction NVARCHAR(50);
            DECLARE @PartnerNumber NVARCHAR(50);
            DECLARE @PartnerCountry NVARCHAR(80);
            DECLARE @PartnerName NVARCHAR(80);
            DECLARE @PartnerCity NVARCHAR(80);
            DECLARE @PartnerDistrict NVARCHAR(80);
            DECLARE @PartnerPostalCode NVARCHAR(80);
            DECLARE @PartnerRegion NVARCHAR(80);
            DECLARE @PartnerAddress NVARCHAR(80);
            
            /*
                Procesar PartnerInfo directamente desde XML. La version previa
                dependia de una tabla #PartnerData que no existia al ejecutar.
            */
            DECLARE cur_Partners CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                    Partner.value('(PartnerFunction/text())[1]', 'NVARCHAR(50)'),
                    Partner.value('(PartnerNumber/text())[1]', 'NVARCHAR(50)'),
                    Partner.value('(PartnerCountry/text())[1]', 'NVARCHAR(80)'),
                    Partner.value('(PartnerName/text())[1]', 'NVARCHAR(80)'),
                    Partner.value('(PartnerCity/text())[1]', 'NVARCHAR(80)'),
                    Partner.value('(PartnerDistrict/text())[1]', 'NVARCHAR(80)'),
                    Partner.value('(PartnerPostalCode/text())[1]', 'NVARCHAR(80)'),
                    Partner.value('(PartnerRegion/text())[1]', 'NVARCHAR(80)'),
                    Partner.value('(PartnerAddress/text())[1]', 'NVARCHAR(80)')
                FROM @xmlData.nodes('/VanReplenishment/Message/DeliveryHeader/PartnerInfo') AS T(Partner);
            
            OPEN cur_Partners;
            FETCH NEXT FROM cur_Partners INTO @PartnerFunction, @PartnerNumber, @PartnerCountry, @PartnerName, @PartnerCity, @PartnerDistrict, @PartnerPostalCode, @PartnerRegion, @PartnerAddress;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Asignar valores basados en PartnerFunction
                IF @PartnerFunction = 'AG'
                BEGIN
                    SET @sCustomerAG = @PartnerNumber;
                    SET @sCountry = @PartnerCountry;
                    SET @sPartnerName = @PartnerName;
                    SET @sCity = @PartnerCity;
                    SET @sDistrict = @PartnerDistrict;
                    SET @sPostalCode = @PartnerPostalCode;
                    SET @sRegion = @PartnerRegion;
                    SET @sAddress = @PartnerAddress;
                    
                    SET @sSold_Customer = @PartnerNumber;
                    SET @sSold_Name = @PartnerName;
                    SET @sSold_Address = @PartnerAddress;
                    SET @sSold_District = @PartnerDistrict;
                    SET @sSold_City = @PartnerCity;
                    SET @sSold_State = @PartnerRegion;
                    SET @sSold_Country = @PartnerCountry;
                    SET @sSold_ZipCode = @PartnerPostalCode;
                END
                ELSE IF @PartnerFunction = 'RE'
                BEGIN
                    SET @sCteFacturaSAP = @PartnerNumber;
                    SET @sBill_Customer = @PartnerNumber;
                    SET @sBill_Name = @PartnerName;
                    SET @sBill_Address = @PartnerAddress;
                    SET @sBill_District = @PartnerDistrict;
                    SET @sBill_City = @PartnerCity;
                    SET @sBill_State = @PartnerRegion;
                    SET @sBill_Country = @PartnerCountry;
                    SET @sBill_ZipCode = @PartnerPostalCode;
                END
                ELSE IF @PartnerFunction = 'WE'
                BEGIN
                    SET @sCustomerWE = @PartnerNumber;
                    SET @sShip_Customer = @PartnerNumber;
                    SET @sShip_Name = @PartnerName;
                    SET @sShip_Address = @PartnerAddress;
                    SET @sShip_District = @PartnerDistrict;
                    SET @sShip_City = @PartnerCity;
                    SET @sShip_State = @PartnerRegion;
                    SET @sShip_Country = @PartnerCountry;
                    SET @sShip_ZipCode = @PartnerPostalCode;
                END
                ELSE IF @PartnerFunction = 'SB'
                BEGIN
                    SET @sCustomerSB = @PartnerNumber;
                END
                
                FETCH NEXT FROM cur_Partners INTO @PartnerFunction, @PartnerNumber, @PartnerCountry, @PartnerName, @PartnerCity, @PartnerDistrict, @PartnerPostalCode, @PartnerRegion, @PartnerAddress;
            END
            
            CLOSE cur_Partners;
            DEALLOCATE cur_Partners;
            
            -- Limpiar tablas temporales
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_HEADER] WHERE ReferenceID = @sReferenceID;
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_DETAIL] WHERE ReferenceID = @sReferenceID;
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS] WHERE ReferenceID = @sReferenceID;
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_PARTNERS] WHERE ReferenceID = @sReferenceID;
            
            -- Insertar header
            INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_HEADER]
                (ReferenceID, ShippingPoint, DeliveryType, Cust_to_SAP, Ship_to_SAP, Storage_SAP, PedidoV3,
                 Pais, NombreCliente, Ciudad, Colonia, Created,
                 CodigoPostal, Estado, Direccion, OrgVentas, ReferenciaBancaria,
                 FacturaSAP, DocumentDate, MetodoPago, Rep_ROWID, Incoterms)
            VALUES
                (@sReferenceID, @sShippingPoint, @sDeliveryType, @sCustomerAG, @sCustomerWE, @sCustomerSB, @sVanName,
                 @sCountry, @sPartnerName, @sCity, @sDistrict, GETDATE(),
                 @sPostalCode, @sRegion, @sAddress, @sOrgVentas, @sGRID,
                 @sDeliveryNumber, @sDeliveryDate, 'Van Replenishment', @sCustomerSB, @sDocNum);
            
            -- Evaluar OBD
            SET @sOBD = 'Check OBD';
            IF @sDeliveryType = 'Receive Other'
            BEGIN
                /*
                    FN_EVAL_REMISION_OBD es una funcion escalar que retorna
                    texto ('YES' u otro estado), no un procedimiento ni entero.
                    Su script aun no esta incluido en este repositorio.
                */
                SET @sOBD = [T3].[FN_EVAL_REMISION_OBD]('', '', @sCustomerAG);

                IF @sOBD = 'YES'
                BEGIN
                    SET @sProcesar = 'SI';
                END
            END
            
            -- Insertar partners
            INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_PARTNERS]
                (ReferenceID,
                 Sold_to_Customer, Sold_to_Name, Sold_to_Address, Sold_to_District,
                 Sold_to_City, Sold_to_State, Sold_to_Country, Sold_to_ZipCode,
                 Bill_to_Customer, Bill_to_Name, Bill_to_Address, Bill_to_District,
                 Bill_to_City, Bill_to_State, Bill_to_Country, Bill_to_ZipCode,
                 Ship_to_Customer, Ship_to_Name, Ship_to_Address, Ship_to_District,
                 Ship_to_City, Ship_to_State, Ship_to_Country, Ship_to_ZipCode)
            VALUES
                (@sReferenceID,
                 @sSold_Customer, @sSold_Name, @sSold_Address, @sSold_District,
                 @sSold_City, @sSold_State, @sSold_Country, @sSold_ZipCode,
                 @sBill_Customer, @sBill_Name, @sBill_Address, @sBill_District,
                 @sBill_City, @sBill_State, @sBill_Country, @sBill_ZipCode,
                 @sShip_Customer, @sShip_Name, @sShip_Address, @sShip_District,
                 @sShip_City, @sShip_State, @sShip_Country, @sShip_ZipCode);
            
            -- Trace: Partners
            IF @nOutput > 0
            BEGIN
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'ReferenceID   -> ' + @sReferenceID);
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'ShippingPoint -> ' + @sShippingPoint);
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'DeliveryType  -> ' + @sDeliveryType);
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'CustomerAG    -> ' + @sCustomerAG);
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'CustomerWE    -> ' + @sCustomerWE);
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'CustomerSB    -> ' + @sCustomerSB);
            END
            
            -- ==================== CURSOR 3: ITEMS (REFACTORIZADO A SET-BASED) ====================
            -- Usar .nodes() para iterar sobre DeliveryLineItem en XML
            DECLARE @Item_Content XML;
            DECLARE @nItemCount INT = 0;
            
            DECLARE cur_Items CURSOR FOR
            SELECT Item.query('.') AS ItemContent,
                   Item.value('(MaterialNumber)[1]', 'NVARCHAR(50)') AS Material,
                   Item.value('(Plant)[1]', 'NVARCHAR(50)') AS Plant,
                   Item.value('(StorageLocation)[1]', 'NVARCHAR(50)') AS StorageLocation,
                   Item.value('(ActualQuantity)[1]', 'NVARCHAR(50)') AS ActualQuantity,
                   Item.value('(SalesUnit)[1]', 'NVARCHAR(50)') AS SalesUnit,
                   Item.value('(DeliveryLineReference/PurchaseOrderNumber)[1]', 'NVARCHAR(50)') AS PurchaseOrder,
                   Item.value('(MaterialName)[1]', 'NVARCHAR(500)') AS MaterialName,
                   Item.value('(DocumentReference)[1]', 'NVARCHAR(50)') AS DocumentReference
            FROM @xmlData.nodes('/VanReplenishment/Message/DeliveryHeader/DeliveryLineItem') AS T(Item);
            
            OPEN cur_Items;
            FETCH NEXT FROM cur_Items INTO @Item_Content, @sMaterial, @sPlant, @sStorageLocation, @sActualQuantity, @sSalesUnit, 
                                           @sPurchaseOrder, @sMaterialName, @sDocReference;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @nItemCount = @nItemCount + 1;

                /*
                    DeliveryLineReference es opcional. Oracle recorre todos sus
                    nodos y conserva el ultimo PurchaseOrderNumber cuyo qualifier
                    sea 001 o 999. sPOrderNumber no se reinicia entre items para
                    reproducir exactamente ese comportamiento.
                */
                DECLARE cur_LineReferences CURSOR LOCAL FAST_FORWARD FOR
                    SELECT
                        R.N.value('(Qualifier/text())[1]', 'NVARCHAR(50)'),
                        R.N.value('(PurchaseOrderNumber/text())[1]', 'NVARCHAR(50)')
                    FROM @Item_Content.nodes('/DeliveryLineItem/DeliveryLineReference') AS R(N);

                OPEN cur_LineReferences;
                FETCH NEXT FROM cur_LineReferences INTO @sQualifier, @sRefPurchaseOrder;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF @sQualifier IN ('001', '999')
                        SET @sPOrderNumber = @sRefPurchaseOrder;

                    FETCH NEXT FROM cur_LineReferences INTO @sQualifier, @sRefPurchaseOrder;
                END;

                CLOSE cur_LineReferences;
                DEALLOCATE cur_LineReferences;
                
                -- Workaround para Return Defective
                SET @sPurchaseOrder = REPLACE(@sPurchaseOrder, '-D', '');
                
                -- GETCONV es una funcion escalar; se asigna con SET.
                SET @sSalesUnit = [EAI_OWNER].[GETCONV]('ECC_V3 UOM', @sSalesUnit);
                
                SET @sQuantityUMV = @sActualQuantity;
                
                -- Si ShippingPoint es MX05, aplicar conversión por Factor_KG
                IF @sShippingPoint = 'MX05'
                BEGIN
                    SELECT TOP (1) @nFactor_KG = ISNULL(Factor_KG, 0)
                    FROM [T3].[CFDI_PRODSERV]
                    WHERE Material = @sMaterial;
                    
                    IF @nFactor_KG > 0
                    BEGIN
                        SET @sQuantityUMV = CAST(CAST(@sActualQuantity AS NUMERIC(14, 4)) * @nFactor_KG AS NVARCHAR(50));
                        SET @sSalesUnit = 'KG';
                    END
                END
                
                -- Obtener información del Material
                SELECT TOP 1 @sUM = UM, @nCIG_X_CLL = CIG_X_CLL, @nCIG_X_PAQ = CIG_X_PAQ
                FROM [T3].[MATERIAL]
                WHERE MATERIAL = @sMaterial;
                
                -- Lógica de conversión de UOM
                IF @sSalesUnit = @sUM
                BEGIN
                    -- Unidad de medida idéntica
                    SET @sUMVSAP = @sUM;
                    SET @sQuantityUMV = @sActualQuantity;
                END
                ELSE IF @sSalesUnit = 'PAQ' AND @sUM = 'CAJ'
                BEGIN
                    -- Conversion PAQ -> CAJ
                    SET @nCasePack =
                        ISNULL
                        (
                            CONVERT(DECIMAL(18,6), @nCIG_X_PAQ)
                            / NULLIF(CONVERT(DECIMAL(18,6), @nCIG_X_CLL), 0),
                            1
                        );
                    IF @nCasePack = 0 SET @nCasePack = 1;
                    
                    SET @sUMVSAP = CONCAT(@sSalesUnit, '(Conv [*', @nCasePack, '])');
                    SET @sQuantityUMV = CONVERT
                    (
                        NVARCHAR(50),
                        CONVERT(DECIMAL(18,6), @sActualQuantity) * @nCasePack
                    );
                    SET @sSalesUnit = @sUM;
                END
                ELSE IF @sSalesUnit = 'CAJ' AND @sUM = 'PAQ'
                BEGIN
                    -- Conversion CAJ -> PAQ
                    SELECT @nCAJ_x_PAQ = MAX
                    (
                        CONVERT(DECIMAL(18,6), ISNULL(Cig_x_PAQ, 0))
                        / NULLIF(CONVERT(DECIMAL(18,6), ISNULL(Cig_X_CLL, 1)), 0)
                    )
                    FROM [T3].[MATERIAL]
                    WHERE Material = @sMaterial;
                    
                    IF @nCAJ_x_PAQ IS NULL OR @nCAJ_x_PAQ = 0
                        SET @nCAJ_x_PAQ = 1;
                    
                    SET @sUMVSAP = @sSalesUnit + '(Conv [/' + CAST(@nCAJ_x_PAQ AS NVARCHAR(10)) + '])';
                    SET @sQuantityUMV = CONVERT
                    (
                        NVARCHAR(50),
                        CONVERT(DECIMAL(18,6), @sActualQuantity)
                        / NULLIF(CONVERT(DECIMAL(18,6), @nCAJ_x_PAQ), 0)
                    );
                    SET @sSalesUnit = @sUM;
                END
                ELSE
                BEGIN
                    -- Sin conversión aplicable
                    SET @sUMVSAP = 'SAP->' + @sSalesUnit;
                    SET @sQuantityUMV = @sActualQuantity;
                END
                
                -- Trace
                IF @nOutput > 0
                BEGIN
                    SET @sLineDebug = 'Items => ' + CAST(@nItemCount AS NVARCHAR(10)) + ',' + @sMaterial + ',' +
                                     @sPlant + '-' + @sStorageLocation + ' : ' + @sActualQuantity + ' ' +
                                     @sUMVSAP + ' ==> ' + @sQuantityUMV + ' ' + @sSalesUnit;
                    INSERT INTO [EAI_Owner].[Trace_EAI_Owner] (Created, Object_Type, Object_Reference, Description)
                    VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, @sLineDebug);
                END
                
                -- Insertar detalle
                INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_DETAIL]
                    (ReferenceID, ItemID, Material, Plant, StorageLocation, Cantidad, UnidadMedida, MaterialDescripcion, Status_Producto)
                VALUES
                    (@sReferenceID, @nItemCount, @sMaterial, @sPlant, @sStorageLocation, @sQuantityUMV, @sSalesUnit, 
                     ISNULL(@sPOrderNumber, @sMaterialName), @sActualQuantity);
                
                -- Acumular volumen
                SET @nVolDetail = @nVolDetail + CAST(ISNULL(@sQuantityUMV, '0') AS NUMERIC(14, 2));
                
                -- Actualizar PedidoSAP
                UPDATE [EAI_OWNER].[TMP_DOCUMENT_HEADER] 
                SET PedidoSAP = @sDocReference
                WHERE ReferenceID = @sReferenceID;
                
                -- Trace: Referencia
                IF @nOutput > 0
                BEGIN
                    INSERT INTO [EAI_Owner].[Trace_EAI_Owner] (Created, Object_Type, Object_Reference, Description)
                    VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, CONCAT('Order Reference -> ', @sPOrderNumber));
                END
                
                FETCH NEXT FROM cur_Items INTO @Item_Content, @sMaterial, @sPlant, @sStorageLocation, @sActualQuantity, @sSalesUnit,
                                               @sPurchaseOrder, @sMaterialName, @sDocReference;
            END
            
            CLOSE cur_Items;
            DEALLOCATE cur_Items;
            
            -- Actualizar cantidad de items
            SET @nItems = @nItemCount;
            
            -- Actualizar Order_Num
            UPDATE [EAI_OWNER].[TMP_DOCUMENT_HEADER]
            SET Order_Num = @sPOrderNumber
            WHERE ReferenceID = @sReferenceID;
        END
        ELSE
        BEGIN
            SET @sProcesar = 'ED';
        END
        
        -- Validar si es CORR (Correction)
        IF SUBSTRING(UPPER(@sPOrderNumber), 1, 4) = 'CORR'
        BEGIN
            SET @sProcesar = 'AJ';
        END
        
        -- Actualizar estado en MX_RECEIVE_MESSAGE_LOG
        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        SET Reference = @sPOrderNumber,
            Processed = GETDATE(),
            Status = CASE @sProcesar
                        WHEN 'SI' THEN 'Processed'
                        WHEN 'ED' THEN 'CheckData'
                        WHEN 'SD' THEN 'Discard'
                        WHEN 'DD' THEN 'Duplicated'
                        WHEN 'NC' THEN 'NotCollect'
                        WHEN 'AJ' THEN 'Adjust SAP'
                        WHEN 'TR' THEN 'Processed'
                        ELSE 'Review'
                     END
        WHERE Row_ID = @sRow_ID;
        
        -- Validar volumen
        IF @nVolDetail = 0
        BEGIN
            IF @nOutput > 0
            BEGIN
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] (Created, Object_Type, Object_Reference, Description)
                VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'Discarding Non Volume');
            END
            
            UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
            SET Reference = CONCAT(@sPOrderNumber, '-00'),
                Processed = GETDATE(),
                Status = 'Discard-00'
            WHERE Row_ID = @sRow_ID;
            
            UPDATE [EAI_OWNER].[TMP_DOCUMENT_HEADER]
            SET Order_Num = CONCAT(Order_Num, '-00')
            WHERE ReferenceID = @sReferenceID;
            
            SET @sProcesar = '00';
        END
        
        -- Check Transportation type
        IF @sDeliveryType = 'Transportation'
        BEGIN
            SET @sProcesar = 'RG';
        END
        
        -- Trace: Final states
        IF @nOutput > 0
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'sProcesar -> ' + @sProcesar);
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'sDeliveryType -> ' + @sDeliveryType);
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'sOBD -> ' + @sOBD);
        END
        
        -- ==================== PROCESAMIENTO FINAL ====================
        IF @sProcesar = 'SI'
        BEGIN
            IF @nOutput > 0
            BEGIN
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 
                    'EAI_OWNER.PROC_REPLENISHMENT_SUBDEPOT -> ' + @sReferenceID);
            END
            
            /*
                La conversion disponible de esta dependencia sigue declarada
                en dbo. Cambiar a EAI_OWNER cuando se migre su schema.
            */
            EXEC [EAI_OWNER].[PROC_REPLENISHMENT_SUBDEPOT]
                @sReferenceID = @sReferenceID;
            
            IF @nOutput > 0
            BEGIN
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 
                    'INVOICE_TO_ENTREGA -> ' + @sReferenceID);
            END
            
            -- Llamar procedure factura/entrega
            EXEC [EAI_OWNER].[INVOICE_TO_ENTREGA]
                @sInvoiceID = @sReferenceID,
                @nOutput = @nOutput,
                @sBillingDoc = 'NOBILL';
            
            -- Si OBD = YES, procesar con OBD
            IF @sOBD = 'YES'
            BEGIN
                EXEC [T3].[DELIVERY_IDOC_TO_REMISION] @sReferenceID, 1, 0;
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 
                    'DELIVERY_IDOC_TO_REMISION (OBD) -> ' + @sReferenceID);
            END
        END
        ELSE IF @sDeliveryType = 'Transportation'
        BEGIN
            IF @nOutput > 0
            BEGIN
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 
                    'DELIVERY_IDOC_TO_REMISION -> ' + @sReferenceID);
            END
            
            UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
            SET Reference = @sReferenceID,
                Processed = GETDATE(),
                Status = 'Processed'
            WHERE Row_ID = @sRow_ID;
            
            EXEC [T3].[DELIVERY_IDOC_TO_REMISION] @sReferenceID, 1, 0;
        END
        
        -- Trace: End
        IF @nOutput > 0
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner] VALUES (GETDATE(), 'SF_PROC_REPLENISHMENT', @sRow_ID, 'End');
        END
        
    END TRY
    BEGIN CATCH
        -- Error handling
        SET @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS NVARCHAR(10)) + '-' + ERROR_MESSAGE(), 1, 250);
        
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME, 
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
             RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Processing PI', @sRow_ID, GETDATE(), NULL, @nPID, 'Error', 'SF_PROC_REPLENISHMENT', 
             @sMsg, 'T-SQL', @sErrorCode, NULL, NULL, NULL);
        
        THROW;
    END CATCH
END;
GO

USE [T3QA]
GO
/****** Object:  StoredProcedure [T3].[PROC_V40_GENERAR_MX06AD]    Script Date: 11/9/2026 12:26:27 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- GUIA PARA DESARROLLADORES
-- Objetivo: construir el texto de una factura o nota de credito para su envio.
-- No genera XML: arma registros HEADER, PARTIES, LINE, TAX y datos comerciales.
-- Los campos se separan con | y los registros con saltos de linea.
-- 
-- Parametros:
--   @pFactura: factura que se consulta y procesa.
--   @pAccnt_ID: cliente opcional; si es NULL se busca a partir de la factura.
--   @pOutput: nivel de PRINT; mayor que 0 muestra totales, mayor que 10 muestra detalle.
--             A pesar del nombre, NO es un parametro de salida.
--   @pFechaDocto: conservado por compatibilidad; esta version no lo utiliza.
-- 
-- Flujo: cliente -> cabecera -> documentos relacionados -> articulos -> cargos
--        -> datos fiscales/comerciales -> impuestos -> comparacion de totales.
-- Si la comparacion pasa, guarda el texto en CFDI_DOCUMENTOS_ENVIAR
-- y registra la liberacion en CFDI_Documentos. Tambien puede actualizar fechas
-- e insertar historia y ajustes. Ejecutarlo NO es una consulta de solo lectura.
-- 
-- DEV-FIX describe cambios aplicados. DEV-REV y DEV-ORA enlazan con las revisiones.
-- PENDIENTE significa que el problema se conoce, pero NO esta corregido ni validado
-- por el codigo actual. Esta version implementa solo la primera etapa de correccion.
-- 
CREATE OR ALTER PROCEDURE [T3].[PROC_V40_GENERAR_MX06AD_CORREGIDO]
(
    @pFactura           VARCHAR(50), -- checar tipo Factura_General.FACTURA%TYPE
    @pAccnt_ID          VARCHAR(MAX) = NULL,
    @pOutput            NUMERIC(18,0) = 0,
    @pFechaDocto        VARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    -- DEV-FIX 2026-11-09 / Etapa 1: paridad de concatenacion con Oracle.
    -- CONCAT conserva los campos NULL como vacios y mantiene los delimitadores.
    -- Las expresiones aritmeticas y el formato FN_NUM_TO_CHAR_CFDI se conservan.
    -- DEV-REV/DEV-ORA documentan la revision original; ver CAMBIOS para pendientes.

    -- VARIABLES: s indica texto; n, numero; dt, fecha.
    -- @strID identifica la factura en los errores. @sStepPLSQL guarda el ultimo paso
    -- alcanzado para ubicar el bloque que fallo.
    DECLARE @strID              VARCHAR(30);
    DECLARE @sMsg               VARCHAR(500);   
    DECLARE @sCtro              VARCHAR(4);   
    DECLARE @sStepPLSQL         VARCHAR(60);
    DECLARE @sUsoCFDI           VARCHAR(4);
    DECLARE @sRegimen           VARCHAR(4);
    DECLARE @nHDP               NUMERIC(3,0);
    -- TEXTOS CONSTRUIDOS POR PARTES:
    -- @uHEADER: datos generales, emisor y receptor. @uLINFAC: articulos y textos.
    -- @uIMPFAC: impuestos/descuentos. @uCABADD: datos adicionales del cliente.
    -- @sCABCLIE: datos comerciales. @sCFDIREL: referencias a otros comprobantes.
    -- Al final se unen en @sData. VARCHAR(MAX) evita el limite anterior de 4000 caracteres.
    -- Los campos vacios ocupan posiciones en el formato; no eliminarlos.
    DECLARE @sReturn            VARCHAR(4000);
    DECLARE @uHEADER            VARCHAR(MAX); -- DEV-FIX: conservar el segmento completo durante su armado.
    DECLARE @uIMPFAC            VARCHAR(MAX); -- DEV-FIX: conservar el segmento completo durante su armado.
    DECLARE @uLINFAC            VARCHAR(MAX); -- CLOB
    DECLARE @uCABADD            VARCHAR(MAX); -- DEV-FIX: conservar el segmento completo durante su armado.
    DECLARE @sCFDIREL           VARCHAR(MAX); -- DEV-FIX: conservar el segmento completo durante su armado.
    DECLARE @nCFDIREL           NUMERIC(3,0);   
    DECLARE @sREL_Facturas      VARCHAR(MAX); -- CLOB 
    DECLARE @nCFDI_CM           NUMERIC(3,0);   
    DECLARE @nTimbrados         NUMERIC(4,0);
    DECLARE @nTtl_CreditMemo    NUMERIC(22,2);
    DECLARE @nTtl_Assigned      NUMERIC(22,2);   
    DECLARE @dtFecha_Docto      DATETIME;
    DECLARE @sRefFactura        VARCHAR(30);   
    DECLARE @nIMPFAC            NUMERIC(3,0);
    DECLARE @nImpSubtot_TASAIVA NUMERIC(22,2);
    DECLARE @nImpSubtot_TASA00  NUMERIC(22,2);
    DECLARE @nValor_IEPS        NUMERIC(22,2); 
    DECLARE @nEnvio_Subt        NUMERIC(22,2); 
    DECLARE @nEnvio_IVA         NUMERIC(22,2);
    DECLARE @nAjusteIVA_DistFee NUMERIC(22,2);
    DECLARE @nEnvio_TASA        NUMERIC(5,2);
    DECLARE @nCredito_Subt      NUMERIC(22,2); 
    DECLARE @nCredito_IVA       NUMERIC(22,2);
    DECLARE @nCredito_TASA      NUMERIC(5,2);
    DECLARE @nTotalAmt          NUMERIC(22,2);
    DECLARE @sEnvio_ID_Code     VARCHAR(10);
    DECLARE @sEnvio_ID_UPC      VARCHAR(10);
    DECLARE @sEnvio_UM          VARCHAR(10);
    DECLARE @sEnvio_Descrip     VARCHAR(100);
    DECLARE @sEnvio_SAT_ID      VARCHAR(10);
    DECLARE @sEnvio_SAT_IDDet   VARCHAR(10);
    DECLARE @sEnvio_SAT_IDMay   VARCHAR(10);
    DECLARE @sEnvio_SAT_UM      VARCHAR(10);
    DECLARE @sCredito_ID_Code   VARCHAR(10);
    DECLARE @sCredito_ID_UPC    VARCHAR(10);
    DECLARE @sCredito_UM        VARCHAR(10);
    DECLARE @sCredito_Descrip   VARCHAR(100);
    DECLARE @sCredito_SAT_ID    VARCHAR(10);
    DECLARE @sCredito_SAT_UM    VARCHAR(10);
    DECLARE @sLista_Precio      VARCHAR(10);
    DECLARE @nTasa_LP           NUMERIC(3,0);
    DECLARE @nTasa_IEPS         NUMERIC(3,0);   
    DECLARE @dtFecha_Factura    DATETIME;
    DECLARE @sMaterial          VARCHAR(20);   
    DECLARE @sCABCLIE           VARCHAR(MAX); -- DEV-FIX: conservar el segmento completo durante su armado.
    DECLARE @sLeyMenor          VARCHAR(4000);
    DECLARE @sLeyPriv           VARCHAR(4000);
    DECLARE @sLeyVype           VARCHAR(4000);
    DECLARE @sSepLinea          VARCHAR(4);
    DECLARE @sSepCampo          VARCHAR(4);
    DECLARE @sFactura           VARCHAR(30);
    DECLARE @sRecibe_RFC        VARCHAR(30);
    DECLARE @sAdd_Migrar        VARCHAR(30);
    DECLARE @sAccnt_ID          VARCHAR(40);
    DECLARE @sAddenda           VARCHAR(2);
    DECLARE @nLineas            NUMERIC(6,0); -- DEV-NUM: Num_Linea origen admite cuatro digitos; agregar lineas comerciales no debe limitarlo a 999.
    DECLARE @nNum_Linea         NUMERIC(6,0);
    DECLARE @nNumLinea          NUMERIC(6,0);   
    -- TOTALES PARA COMPARAR:
    -- @nTotal viene de la cabecera; @nItems suma detalle y cargos; @nEDICOM acumula
    -- los importes utilizados para la salida. Se compara @nEDICOM menos @nDescuento
    -- contra @nTotal. Estas variables permiten detectar diferencias entre calculos.
    DECLARE @nTotal             NUMERIC(22,2);
    DECLARE @nItems             NUMERIC(22,2);
    DECLARE @nEDICOM            NUMERIC(22,2);
    DECLARE @nLineaTax          NUMERIC(6,0);
    DECLARE @nCantPedimento     NUMERIC(6,0);
    DECLARE @sPedimentos        VARCHAR(MAX); -- DEV-FIX: conservar el segmento completo durante su armado.
    DECLARE @nDescuento         NUMERIC(22,2);
    DECLARE @sData              VARCHAR(MAX); -- CLOB
    DECLARE @sFormaDePago       VARCHAR(60);
    DECLARE @sMetodoDePago      VARCHAR(60);
    DECLARE @sNumCtaPago        VARCHAR(60);
    DECLARE @dtFechaRollout     DATETIME;
    DECLARE @sPedido            VARCHAR(60);
    DECLARE @sNotaEnt           VARCHAR(60);
    DECLARE @sVendorNInt        VARCHAR(60);
    DECLARE @sCompradorGLN      VARCHAR(60);
    DECLARE @sLocalidadEmisor   VARCHAR(60);
    DECLARE @sLocalidadReceptor VARCHAR(60);
    DECLARE @sOrdenCompra       VARCHAR(60);
    DECLARE @sSAT_ID            VARCHAR(30);
    DECLARE @sSAT_UM            VARCHAR(30);   
    DECLARE @sIdentificacion    VARCHAR(30);
    -- nItem contiene valores del articulo actual; nDoc acumula el documento.
    -- NUMERIC(22,2) admite 22 digitos totales, con 2 posiciones decimales.
    -- Ampliar la variable no evita errores si STR limita antes el numero o si
    -- la columna destino del INSERT tiene menor capacidad.
    DECLARE @nItemValorUnitario NUMERIC(22,2);
    DECLARE @nItemImporte       NUMERIC(22,2);
    DECLARE @nItemDescuento     NUMERIC(22,2);
    DECLARE @nDoc_Descuento     NUMERIC(22,2);
    DECLARE @nDoc_Valor_sin_IVA NUMERIC(22,2);
    DECLARE @nDoc_Valor_con_IVA NUMERIC(22,2);
    DECLARE @nDoc_Valor_IEPS    NUMERIC(22,2);
    DECLARE @nDoc_Valor_IVA     NUMERIC(22,2);
    DECLARE @nDoc_Total         NUMERIC(22,2);

    -- Revision de referencia: Analisis/PROC_V40_GENERAR_MX06AD.REVISION.md. DEV-FIX describe cambios aplicados.
    -- Segunda pasada: Analisis/PROC_V40_GENERAR_MX06AD.SEGUNDA_REVISION_ORACLE.md. DEV-REV2 identifica pendientes adicionales.
    -- DEV-ORA Comparacion en Analisis/PROC_V40_GENERAR_MX06AD.COMPARACION_ORACLE.md; ver rectificacion de captura de variables al DECLARE.
    -- COMO LEER LOS CURSORES:
    -- Un cursor recorre una consulta fila por fila. DECLARE define la consulta;
    -- OPEN prepara sus filas; FETCH copia una fila a variables; WHILE procesa
    -- mientras @@FETCH_STATUS sea 0. CLOSE termina la lectura; DEALLOCATE libera
    -- el cursor y permite declararlo de nuevo con los valores de la siguiente fila.
    -- 
    -- Doc_ recibe la cabecera; Item_ el articulo; Reg_ su addenda; Inf_ la cabecera
    -- de addenda; Ped_ un pedimento; CMA_ una asignacion de cobranza;
    -- Env_ un reenvio; Info_ un texto adicional.
    -- SELECT y FETCH INTO deben conservar el mismo orden y cantidad de campos.
    -- Al agregar una columna, actualizar ambos FETCH: el inicial y el del bucle.
    -- @@FETCH_STATUS se comparte en la conexion: el FETCH de un cursor hijo lo cambia.
    -- Por eso cada bucle hace su propio FETCH antes de volver a evaluar WHILE.
    -- Variables cursores
    DECLARE @Doc_Addenda_Venta VARCHAR(MAX), @Doc_Addenda_Devol VARCHAR(MAX), @Doc_Addenda_Migrar VARCHAR(MAX), @Doc_Addenda_Tipo_Docto VARCHAR(MAX), @Doc_Ctro VARCHAR(MAX), @Doc_Fecha_Rollout VARCHAR(MAX), @Doc_Addenda_Fases VARCHAR(MAX), @Doc_Fecha_Documento DATETIME, @Doc_Fecha_Factura DATETIME, @Doc_Cadena_Comercial VARCHAR(MAX), @Doc_RFC_Cliente VARCHAR(MAX), @Doc_Factura VARCHAR(MAX), @Doc_versionCFDI VARCHAR(MAX), @Doc_Serie VARCHAR(MAX), @Doc_Folio VARCHAR(MAX), @Doc_pedidoV3 VARCHAR(MAX), @Doc_pedidoSAP VARCHAR(MAX), @Doc_facturaSAP VARCHAR(MAX), @Doc_repVentas VARCHAR(MAX), @Doc_sucursalNombre VARCHAR(MAX), @Doc_Lista_Precio VARCHAR(MAX), @Doc_fecha_Reenvio VARCHAR(MAX), @Doc_fecha VARCHAR(MAX), @Doc_tipoDeComprobante VARCHAR(MAX), @Doc_formaDePago VARCHAR(MAX), @Doc_condicionesDePago VARCHAR(MAX), @Doc_motivoDescuento VARCHAR(MAX), @Doc_Descuento NUMERIC(22,2), @Doc_ajusteEnvio NUMERIC(22,2), @Doc_subTotal NUMERIC(22,2), @Doc_total NUMERIC(22,2), @Doc_ajusteIVA_DistFee NUMERIC(22,2), @Doc_metodoDePago VARCHAR(MAX), @Doc_NumCtaPago VARCHAR(MAX), @Doc_TipoCambio VARCHAR(MAX), @Doc_Moneda VARCHAR(MAX), @Doc_LugarExpedicion VARCHAR(MAX), @Doc_Emisor_RFC VARCHAR(MAX), @Doc_Emisor_Nombre VARCHAR(MAX), @Doc_Emisor_Calle VARCHAR(MAX), @Doc_Emisor_NoExterior VARCHAR(MAX), @Doc_Emisor_NoInterior VARCHAR(MAX), @Doc_Emisor_Colonia VARCHAR(MAX), @Doc_Emisor_Localidad VARCHAR(MAX), @Doc_Emisor_Municipio VARCHAR(MAX), @Doc_Emisor_Estado VARCHAR(MAX), @Doc_Emisor_Pais VARCHAR(MAX), @Doc_Emisor_CodigoPostal VARCHAR(MAX), @Doc_Expide_calle VARCHAR(MAX), @Doc_Expide_noExterior VARCHAR(MAX), @Doc_Expide_noInterior VARCHAR(MAX), @Doc_Expide_colonia VARCHAR(MAX), @Doc_Expide_municipio VARCHAR(MAX), @Doc_Expide_estado VARCHAR(MAX), @Doc_Expide_pais VARCHAR(MAX), @Doc_Expide_codigoPostal VARCHAR(MAX), @Doc_RegimenFiscal VARCHAR(MAX), @Doc_Regimen_Fiscal_Cte VARCHAR(MAX), @Doc_Recibe_RFC VARCHAR(MAX), @Doc_Recibe_Nombre VARCHAR(MAX), @Doc_Recibe_Calle VARCHAR(MAX), @Doc_Recibe_NoExterior VARCHAR(MAX), @Doc_Recibe_NoInterior VARCHAR(MAX), @Doc_Recibe_Colonia VARCHAR(MAX), @Doc_Recibe_Municipio VARCHAR(MAX), @Doc_Recibe_Estado VARCHAR(MAX), @Doc_Recibe_Pais VARCHAR(MAX), @Doc_Recibe_codigoPostal VARCHAR(MAX), @Doc_Remite_Calle VARCHAR(MAX), @Doc_Remite_Colonia VARCHAR(MAX), @Doc_Remite_Municipio VARCHAR(MAX), @Doc_Remite_Estado VARCHAR(MAX), @Doc_Remite_Pais VARCHAR(MAX), @Doc_Remite_codigoPostal VARCHAR(MAX), @Doc_Tipo_Documento VARCHAR(MAX), @Doc_Recibe_Cliente VARCHAR(MAX), @Doc_Remite_Cliente VARCHAR(MAX), @Doc_CentroExpedicion VARCHAR(MAX), @Doc_eMail VARCHAR(MAX), @Doc_ConfirmacionPAC VARCHAR(MAX), @Doc_UsoCFDI VARCHAR(MAX), @Doc_ResidenciaFiscal VARCHAR(MAX), @Doc_RegTributarioExt VARCHAR(MAX), @Doc_TipoRelacion VARCHAR(MAX), @Doc_ImpuestosTrasladados NUMERIC(22,2), @Doc_impuesto VARCHAR(MAX), @Doc_tasa VARCHAR(MAX), @Doc_importe_IVA NUMERIC(22,2), @Doc_importe NUMERIC(22,2), @Doc_subtotal_TasaIVA NUMERIC(22,2), @Doc_subtotal_Tasa00 NUMERIC(22,2), @Doc_impSubtot_TASAIVA NUMERIC(22,2), @Doc_impSubtot_TASA00 NUMERIC(22,2), @Doc_Valor_Subt_IEPS NUMERIC(22,2), @Doc_Valor_IEPS NUMERIC(22,2);
    DECLARE @Item_numLinea NUMERIC(4,0), @Item_cantidad NUMERIC(10,0), @Item_unidad VARCHAR(MAX), @Item_noIdentificacion VARCHAR(MAX), @Item_descripcion VARCHAR(MAX), @Item_valorUnitario NUMERIC(22,2), @Item_importe NUMERIC(22,2), @Item_Descuento NUMERIC(22,2), @Item_RFD_Valor_Subt NUMERIC(22,2), @Item_RFD_Valor_IVA NUMERIC(22,2), @Item_RFD_Tasa_IVA NUMERIC(22,2), @Item_PDF_Valor_Subt NUMERIC(22,2), @Item_PDF_Valor_IVA NUMERIC(22,2), @Item_PDF_TASA_IVA NUMERIC(22,2), @Item_Envio_Subt NUMERIC(22,2), @Item_Envio_IVA NUMERIC(22,2), @Item_Credito_Subt NUMERIC(22,2), @Item_Credito_IVA NUMERIC(22,2), @Item_Subt_sin_IEPS NUMERIC(22,2), @Item_Valor_IEPS NUMERIC(22,2);
    DECLARE @Inf_GLN_BAT VARCHAR(MAX), @Inf_Sucursal_EDI VARCHAR(MAX), @Inf_SucursalName VARCHAR(MAX), @Inf_Ref_Pedido VARCHAR(MAX), @Inf_Ref_Entrada VARCHAR(MAX), @Inf_Ref_Tienda VARCHAR(MAX), @Inf_Ref_Sucursal VARCHAR(MAX), @Inf_Label VARCHAR(MAX), @Inf_Funcion VARCHAR(MAX), @Inf_Doc_Reemplazo VARCHAR(MAX), @Inf_Pedido VARCHAR(MAX), @Inf_FePedido VARCHAR(MAX), @Inf_NotaEnt VARCHAR(MAX), @Inf_FeNotaEnt VARCHAR(MAX), @Inf_VendedorGLN VARCHAR(MAX), @Inf_VendorNInt VARCHAR(MAX), @Inf_VendorIEPS VARCHAR(MAX), @Inf_CompradorGLN VARCHAR(MAX), @Inf_CompradorConti VARCHAR(MAX), @Inf_CompradorNRef VARCHAR(MAX), @Inf_ReceptorGLN VARCHAR(MAX), @Inf_ReceptorNombre VARCHAR(MAX), @Inf_ReceptorCalle VARCHAR(MAX), @Inf_ReceptorColonia VARCHAR(MAX), @Inf_ReceptorLocal VARCHAR(MAX), @Inf_ReceptorMunicip VARCHAR(MAX), @Inf_ReceptorEstado VARCHAR(MAX), @Inf_ReceptorPais VARCHAR(MAX), @Inf_ReceptorCP VARCHAR(MAX), @Inf_MonedaPrecio VARCHAR(MAX), @Inf_TCambioMPR VARCHAR(MAX), @Inf_MonedaPago VARCHAR(MAX), @Inf_TCambioMPY VARCHAR(MAX), @Inf_RefPago VARCHAR(MAX), @Inf_CondPago VARCHAR(MAX), @Inf_DPago VARCHAR(MAX), @Inf_NCheque VARCHAR(MAX), @Inf_TotNeto VARCHAR(MAX), @Inf_CPredial VARCHAR(MAX), @Inf_TotalconLetra VARCHAR(MAX), @Inf_Folio_Aviso_Pago VARCHAR(MAX), @Inf_Plaza VARCHAR(MAX), @Inf_TipoProv VARCHAR(MAX), @Inf_TipoLoc VARCHAR(MAX), @Inf_TipoBulto VARCHAR(MAX), @Inf_CumpleReqFiscales VARCHAR(MAX), @Inf_CantBulto VARCHAR(MAX), @Inf_CantPedido VARCHAR(MAX), @Inf_PedemiProv VARCHAR(MAX), @Inf_Pedido_Vend VARCHAR(MAX), @Inf_Factura_Nota VARCHAR(MAX), @Inf_Remision VARCHAR(MAX), @Inf_DestinoBM VARCHAR(MAX), @Inf_CorreoProveedor VARCHAR(MAX), @Inf_TipoPedido VARCHAR(MAX), @Inf_ComplementoCE VARCHAR(MAX);
    DECLARE @Reg_Label VARCHAR(MAX), @Reg_NumLin NUMERIC(6,0), @Reg_RefCliente VARCHAR(MAX), @Reg_RefProvee VARCHAR(MAX), @Reg_RefSerieArt VARCHAR(MAX), @Reg_IdiomaDesc VARCHAR(MAX), @Reg_Cantidad_Vta NUMERIC(22,2), @Reg_Unidad_Med_Vta VARCHAR(MAX), @Reg_CantConsum VARCHAR(MAX), @Reg_CantFree VARCHAR(MAX), @Reg_CantComer VARCHAR(MAX), @Reg_NOrdenC VARCHAR(MAX), @Reg_CalifIdentity VARCHAR(MAX), @Reg_SerieContenedor VARCHAR(MAX), @Reg_NumPaq VARCHAR(MAX), @Reg_TipPaq VARCHAR(MAX), @Reg_DescripPaq VARCHAR(MAX), @Reg_PaqMetodoPago VARCHAR(MAX), @Reg_MontoBruLin VARCHAR(MAX), @Reg_PrecioBruto VARCHAR(MAX), @Reg_FechaEntrega VARCHAR(MAX), @Reg_CRTienda VARCHAR(MAX), @Reg_Tienda VARCHAR(MAX), @Reg_FacturaInterna VARCHAR(MAX), @Reg_LineaInterna VARCHAR(MAX), @Reg_PlantaReceptora VARCHAR(MAX), @Reg_NRecipiente VARCHAR(MAX), @Reg_Release VARCHAR(MAX), @Reg_Remision VARCHAR(MAX), @Reg_Linea_con_IVA NUMERIC(22,2), @Reg_Precio_con_IVA NUMERIC(22,2);
    DECLARE @Ped_Aduana_Numero VARCHAR(MAX), @Ped_Pedimento VARCHAR(MAX), @Ped_FecPedimento VARCHAR(MAX);
    DECLARE @Env_Folio_Fiscal VARCHAR(MAX), @Env_Fecha_Factura DATETIME;
    DECLARE @Info_Linea INT, @Info_Texto VARCHAR(MAX);
    DECLARE @CMA_Created DATETIME, @CMA_Paid_Amt NUMERIC(22,2), @CMA_Invc_dt DATETIME, @CMA_Doc_Num VARCHAR(MAX), @CMA_Sub_Type_CD VARCHAR(MAX), @CMA_Folio_Fiscal VARCHAR(MAX);

    -- DEV-REV C01 RECTIFICADO: LocalDB confirma captura de variables en DECLARE. Declarar despues de asignar filtros y recrear por fila.
    -- DEV-NUM: importes y acumuladores numeric(22,2); cantidad numeric(10,0) como la tabla.
    -- 20 enteros y 2 decimales permiten sumar cobranza decimal(16,2) sin reducirla a (15,2).
    -- Los limites de PENDIENTE y AJUSTE se validan antes de sus INSERT.
    -- DEV-REV C02 RESUELTO etapa 1: orden vacia antes de declarar ScrItemAddenda. Se conserva el pedido vacio historico.

    -- 1. PREPARACION. TRY agrupa el trabajo cuyos errores se atienden en CATCH.
    -- Primero se identifica al cliente y se inicializan textos y acumuladores.
    BEGIN TRY
        SET @strID = @pFactura;
        SET @sStepPLSQL = 'Inicio';

        IF ( @pAccnt_ID IS NULL )
        BEGIN
            -- DEV-ORA ORA-02: SELECT INTO Oracle fallaba con cero/multiples filas; TOP 1 silencia ambas condiciones. Validar cardinalidad.
            SELECT TOP 1 @sAccnt_ID = Cte.Cliente_SAP
            FROM T3.Registro_Fiscal RF
            INNER JOIN T3.Cliente Cte ON RF.Cliente_SAP = Cte.Cliente_SAP
            WHERE RF.Factura = @pFactura
              AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig;
        END
        ELSE
        BEGIN
            SET @sAccnt_ID = @pAccnt_ID;   
        END;   

        -- CONCAT convierte NULL en campo vacio: CONCAT('LINE|', NULL, '|fin')
        -- produce 'LINE||fin'. Mantiene el separador y el texto construido anteriormente.
        -- Esto solo resuelve la representacion textual: NULL no equivale a cero en sumas
        -- y CONCAT no sustituye la validacion de datos obligatorios.
        SET @uHEADER        = '';
        SET @uIMPFAC        = '';
        SET @uLINFAC        = '';
        SET @uCABADD        = '';
        SET @sReturn        = ''; 
        SET @sCABCLIE       = '';
        SET @sSepLinea      = CONCAT(CHAR(13), CHAR(10));
        SET @sSepCampo      = '|';
        SET @sAddenda       = 'NO';
        SET @nTotal         = 0000;
        SET @nItems         = 0000;
        SET @nEDICOM        = 0000;
        SET @nEnvio_Subt    = 0000;
        SET @nEnvio_IVA     = 0000;
        SET @nCredito_Subt  = 0000;
        SET @nCredito_IVA   = 0000;

        -- Leyendas del documento. CHECK_VYPE_DOC selecciona el aviso de vaporizadores
        -- cuando corresponde; el aviso de privacidad se agrega como texto comercial.
        SET @sLeyVype = 'Le recordamos que la venta de vaporizadores y cartuchos de líquido vaporizable es exclusiva para mayores de edad. En caso de duda, solicite identificación oficial. Ayúdenos a que los menores de edad no tengan acceso a este tipo de productos. ';   
        SET @sLeyMenor = 'Le recordamos que las leyes prohíben y sancionan la venta de cigarros a menores de 18 años de edad y en unidades sueltas. En caso de duda solicite identificación oficial. Ayúdenos a que los menores de edad no tengan acceso a los cigarros.';
       -- SET @sLeyPriv = 'British American Tobacco México S.A. de C.V. y subsidiarias protegen los datos personales de sus clientes que son tratados por nuestra empresa. Para mayor información consultar el aviso de privacidad en www.batmexico.com.mx';
       --SET @sLeyPriv = 'British American Tobacco México, S.A. de C.V. y empresas relacionadas, con domicilio indicado arriba, utilizará los datos personales que usted entregue voluntariamente en este documento para cumplir con las políticas, procedures y requisitos legales aplicables, para llevar un registro adecuado de los proveedores y clientes, y para coordinar los servicios prestados por y para el Grupo. Para mayor información respecto al tratamiento de sus datos personales o al ejercicio de sus derechos ARCO consulte nuestro aviso de privacidad en www.batmexico.com.mx.';                  
        -- DEV-REV2 RN-02 PENDIENTE: Oracle dice 'procedimientos operativos'; este texto dice 'procedures operativos'. Es contenido del documento, no sintaxis SQL.
        SET @sLeyPriv = 'British American Tobacco México, S.A. de C.V. y sus empresas relacionadas (el "Grupo"), con domicilio en Avenida Francisco I. Madero, 2750 Pte., Centro de la Ciudad, Monterrey, N.L. C.P. 64000, utilizarán los datos personales que usted entregue voluntariamente mediante este documento para cumplir con las políticas, procedures operativos y requisitos legales aplicables y llevar un registro adecuado de los proveedores y clientes del Grupo. Para mayor información respecto al tratamiento de sus datos personales o al ejercicio de sus derechos ARCO consulte nuestro aviso de privacidad integral en www.batmexico.com.mx';

		-- Document Header

        IF ( T3.CHECK_VYPE_DOC( @pFactura ) > 0 )
        BEGIN
            SET @sLeyMenor = @sLeyVype;
        END;

        SET @sStepPLSQL = 'Before ScrDatos';

        -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
        -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
        -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
        -- 2. CABECERA. Junta factura, cliente, emisor, lugar de expedicion y totales
        -- calculados desde Registro_Fiscal_Detalle. @sAccnt_ID ya debe estar asignado.
        -- PENDIENTE: exigir una sola cabecera. Cero filas omite el bucle; varias filas
        -- pueden mezclar informacion porque hay acumuladores inicializados una sola vez.
        DECLARE ScrDatos CURSOR LOCAL FORWARD_ONLY STATIC FOR
        SELECT 
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'VENTA' ) AS Addenda_Venta,
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'DEVOL' ) AS Addenda_Devol,
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'MIGRAR' ) AS Addenda_Migrar,
              RF.Tipo_Docto AS Addenda_Tipo_Docto,
              RF.Ctro AS Ctro,
              CteX_Attrib_34 AS Fecha_Rollout,
              T3.FN_ADDENDA_PARAM( Cte.Tax_Exempt_Num, 'FASES' ) AS Addenda_Fases,
              RF.Fecha_Factura AS Fecha_Documento,
              RF.Fecha_Factura AS Fecha_Factura,
              SUBSTRING( Cad_Ou_Num, 1, 2 ) AS Cadena_Comercial,
              T3.FN_TRIM_CFDI( Cte.Tax_Exempt_Num ) AS RFC_Cliente,
              RF.Factura AS Factura,
              Cte.VersionCFDI AS versionCFDI,
              SUBSTRING( RF.Factura, 1, CHARINDEX( '-', RF.Factura ) - 1 ) AS Serie,
              SUBSTRING( REPLACE( RF.Factura, '00000', '' ), CHARINDEX( '-', REPLACE( RF.Factura, '00000', '' ) ) + 1, 30 ) AS Folio,               
              RF.Referencia AS pedidoV3,
              RF.Pedido AS pedidoSAP,
              RF.Entrega AS facturaSAP,
              Comp.Rep_ID AS repVentas,
              T3.FN_TRIM_CFDI( Cte.X_Route_Ref_1 ) AS sucursalNombre,
              SUBSTRING( LP_Name, 1, 2 ) AS Lista_Precio,
              CONCAT(CONVERT(VARCHAR(8), GETDATE(), 112), REPLACE( T3.FN_ADJUST_GMT( CONVERT(VARCHAR(8), GETDATE(), 108), DF.Dif_GMT ), ':', '' )) AS fecha_Reenvio,                  
              CONCAT(CONVERT(VARCHAR(8), RF.Fecha_Factura, 112), REPLACE( T3.FN_ADJUST_GMT( Comp.Hora_Factura, DF.Dif_GMT ), ':', '' )) AS fecha,                  
              CASE WHEN RF.Tipo_Docto IN ('Z003', 'Z005', 'Z007', 'Z014', 'Z0FX', 'Z020', 'C003', 'C005', 'C007', 'C014', 'C0FX', 'C020', 'C030') THEN 'I' ELSE 'E' END AS tipoDeComprobante,
              EAI_Owner.getConv( 'CFG Settings', 'Forma Pago' ) AS formaDePago,
              CONCAT(REPLICATE('0', 3 - LEN(ISNULL(Comp.Dias_Pago, 0))), CAST(ISNULL(Comp.Dias_Pago, 0) AS VARCHAR)),
              'Descuento' AS motivoDescuento,
              ISNULL( CFD.Descuento, 0 ) AS Descuento,
              T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ) AS ajusteEnvio,
              CAST( CFD.Valor_Subtotal + CFD.Subtotal_noIVA + ISNULL( CFD.Descuento, 0 ) + CASE WHEN RF.Desglose_IVA = 'N' THEN CFD.Valor_IVA ELSE 0 END AS DECIMAL(22,2) ) AS subTotal,
              CAST( CFD.Valor_Subtotal + CFD.Valor_IVA + CFD.Subtotal_noIVA + ISNULL( T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ), 0 ) AS DECIMAL(22,2) ) AS total,
              T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ) AS ajusteIVA_DistFee,                
              EAI_Owner.getConv( 'CFG Settings', 'Metodo Pago' ) AS metodoDePago,                      
              CASE WHEN Cte.Pay_Type_CD = 'Efectivo' THEN '' ELSE ISNULL( CteX_X_EM_Field_18, 'No identificado' ) END AS NumCtaPago, 
              '1' AS TipoCambio,
              'MXN' AS Moneda,
              Alm.Almacen_Lugar_Expide AS LugarExpedicion,   
              T3.FN_TRIM_CFDI( Soc.RFC ) AS Emisor_RFC,
              T3.FN_TRIM_CFDI( Soc.Razon_Social_HH ) AS Emisor_Nombre,
              T3.FN_TRIM_CFDI( Soc.Calle ) AS Emisor_Calle, 
              T3.FN_TRIM_CFDI( Soc.Numero_Ext ) AS Emisor_NoExterior,
              T3.FN_TRIM_CFDI( Soc.Numero_Int ) AS Emisor_NoInterior,
              T3.FN_TRIM_CFDI( Soc.Colonia ) AS Emisor_Colonia,
              T3.FN_TRIM_CFDI( Soc.Localidad ) AS Emisor_Localidad,
              T3.FN_TRIM_CFDI( Soc.Municipio ) AS Emisor_Municipio,
              T3.FN_TRIM_CFDI( EAI_Owner.getConv( 'CFDI Estado', Soc.Estado ) ) AS Emisor_Estado,
              T3.FN_TRIM_CFDI( Soc.Pais ) AS Emisor_Pais,
              T3.FN_TRIM_CFDI( Soc.Codigo_Postal ) AS Emisor_CodigoPostal,
              T3.FN_TRIM_CFDI( Alm.Almacen_Calle ) AS Expide_calle, 
              T3.FN_TRIM_CFDI( Alm.Almacen_NoExterior ) AS Expide_noExterior,
              T3.FN_TRIM_CFDI( Alm.Almacen_NoInterior ) AS Expide_noInterior,
              T3.FN_TRIM_CFDI( Alm.Almacen_Colonia ) AS Expide_colonia,
              T3.FN_TRIM_CFDI( Alm.Almacen_Municipio ) AS Expide_municipio,
              T3.FN_TRIM_CFDI( Alm.Almacen_Estado ) AS Expide_estado,
              T3.FN_TRIM_CFDI( Alm.Almacen_Pais ) AS Expide_pais,
              T3.FN_TRIM_CFDI( CONCAT(REPLICATE('0', 5 - LEN(Alm.Almacen_codigoPostal)), CAST(Alm.Almacen_codigoPostal AS VARCHAR)) ) AS Expide_codigoPostal,
              EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal' ) AS RegimenFiscal,
              Cte.RegimenFiscal AS Regimen_Fiscal_Cte,
              T3.FN_TRIM_CFDI( Cte.Tax_Exempt_Num ) AS Recibe_RFC,
              T3.FN_TRIM_CFDI( Cte.Name ) AS Recibe_Nombre,
              T3.FN_TRIM_CFDI( Bill_Addr ) AS Recibe_Calle,
              '' AS Recibe_NoExterior,
              '' AS Recibe_NoInterior,
              T3.FN_TRIM_CFDI( Bill_Addr_Line_2 ) AS Recibe_Colonia,
              T3.FN_TRIM_CFDI( Bill_City ) AS Recibe_Municipio,
              T3.FN_TRIM_CFDI( EAI_Owner.getConv( 'CFDI Estado', Bill_State ) ) AS Recibe_Estado,
              T3.FN_TRIM_CFDI( Bill_Country ) AS Recibe_Pais, 
              T3.FN_TRIM_CFDI( CONCAT(REPLICATE('0', 5 - LEN(ISNULL( Bill_ZipCode, '99999' ))), CAST(ISNULL( Bill_ZipCode, '99999' ) AS VARCHAR)) ) AS Recibe_codigoPostal,
              T3.FN_TRIM_CFDI( Ship_Addr ) AS Remite_Calle,
              T3.FN_TRIM_CFDI( Ship_Addr_Line_2 ) AS Remite_Colonia,
              T3.FN_TRIM_CFDI( Ship_City ) AS Remite_Municipio,
              T3.FN_TRIM_CFDI( EAI_Owner.getConv( 'CFDI Estado', Ship_State ) ) AS Remite_Estado,
              T3.FN_TRIM_CFDI( Ship_Country ) AS Remite_Pais, 
              T3.FN_TRIM_CFDI( CONCAT(REPLICATE('0', 5 - LEN(ISNULL( Ship_ZipCode, '99999' ))), CAST(ISNULL( Ship_ZipCode, '99999' ) AS VARCHAR)) ) AS Remite_codigoPostal,
              CASE RF.Tipo_Docto
                   WHEN 'Z003' THEN 'FACTURA' WHEN 'Z005' THEN 'FACTURA' WHEN 'Z007' THEN 'FACTURA' WHEN 'Z014' THEN 'FACTURA'
                   WHEN 'Z0FX' THEN 'FACTURA' WHEN 'Z020' THEN 'FACTURA' WHEN 'Z024' THEN 'NOTA DE CREDITO' WHEN 'Z022' THEN 'NOTA DE CREDITO'
                   WHEN 'C003' THEN 'FACTURA' WHEN 'C005' THEN 'FACTURA' WHEN 'C007' THEN 'FACTURA' WHEN 'C014' THEN 'FACTURA'
                   WHEN 'C0FX' THEN 'FACTURA' WHEN 'C020' THEN 'FACTURA' WHEN 'C030' THEN 'FACTURA' WHEN 'C024' THEN 'NOTA DE CREDITO'
                   WHEN 'C022' THEN 'NOTA DE CREDITO' ELSE 'NOTA DE CREDITO' END AS Tipo_Documento,
              Cte.Integration_ID AS Recibe_Cliente,  
              Cte.Integration_ID AS Remite_Cliente,              
              Alm.Almacen_Ctro AS CentroExpedicion,
              Cte.Pr_Con_ID AS eMail,         
              '' AS ConfirmacionPAC,
              CASE WHEN RF.Tipo_Docto IN ('C003', 'C005') THEN Cte.UsoCFDI ELSE ISNULL( UsoC.Uso_Devolucion, EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Comercial_NC' ) ) END AS UsoCFDI,
              '' AS ResidenciaFiscal,
              '' AS RegTributarioExt,
              '' AS TipoRelacion,              
              CAST( CFD.Valor_IVA + T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ) AS DECIMAL(22,2) ) AS ImpuestosTrasladados,
              'IVA' AS impuesto, 
              CASE WHEN CFD.Valor_Subtotal = 0 THEN '0' ELSE CONVERT(VARCHAR(41), CAST( ROUND( CFD.Valor_IVA * 100 / CFD.Valor_Subtotal, 0 ) AS DECIMAL(38,0) )) END AS tasa,
              -- DEV-NUM: conservar importes numericos; el ancho de STR ya no limita sus digitos.
              CAST( CFD.Valor_IVA + T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ) AS DECIMAL(22,2) ) AS importe_IVA,                                                                           
              CAST( CFD.Valor_IVA + T3.FN_DIST_FEE_TAX_ADJ( RF.Factura ) + ( CFD.Valor_IEPS * ISNULL( UsoC.Desglose_IEPS, 0 ) ) AS DECIMAL(22,2) ) AS importe,
              CAST( CFD.Valor_Subtotal AS DECIMAL(22,2) ) AS subtotal_TasaIVA,
              CAST( CFD.Subtotal_noIVA AS DECIMAL(22,2) ) AS subtotal_Tasa00,
              CFD.Valor_Subtotal AS impSubtot_TASAIVA,
              CFD.Subtotal_noIVA AS impSubtot_TASA00,
              CFD.Subt_sin_IEPS * ISNULL( UsoC.Desglose_IEPS, 0 ) AS Valor_Subt_IEPS,        
              CFD.Valor_IEPS * ISNULL( UsoC.Desglose_IEPS, 0 ) AS Valor_IEPS            
        FROM T3.Registro_Fiscal RF
        INNER JOIN (
              SELECT 
                     SUM( ISNULL( RFD.Valor_Subt, 0 ) + ISNULL( RFD.Envio_Subt, 0 ) + ISNULL( RFD.Credito_Subt, 0 ) ) AS Valor_Subt,
                     SUM( ISNULL( RFD.Valor_IVA , 0 ) + ISNULL( RFD.Envio_IVA , 0 ) + ISNULL( RFD.Credito_IVA , 0 ) ) AS Valor_IVA,
                     SUM( ISNULL( RFD.Bonif_Subt, 0 ) ) AS Descuento, 
                     SUM( CASE RF_sub.Tipo_Venta WHEN 'VD' THEN ISNULL( RFD.Bonif_Subt, 0 ) ELSE 0 END ) AS Descuento_VD,
                     SUM( CASE WHEN Tax.Fecha_Registro IS NULL THEN 0 ELSE RFD.Valor_Subt + ISNULL( RFD.Envio_Subt, 0 ) + ISNULL( RFD.Credito_Subt, 0 ) END ) AS Subtotal_noIVA,
                     SUM( (ISNULL( RFD.Valor_Subt, 0 ) + ISNULL( RFD.Envio_Subt, 0 ) + ISNULL( RFD.Credito_Subt, 0 ))
                        - CASE WHEN Tax.Fecha_Registro IS NULL THEN 0 ELSE RFD.Valor_Subt + ISNULL( RFD.Envio_Subt, 0 ) + ISNULL( RFD.Credito_Subt, 0 ) END ) AS Valor_Subtotal,
                     SUM( CASE WHEN ISNULL( RFD.Valor_IEPS, 0 ) = 0 THEN 0 ELSE RFD.Valor_Subt - ISNULL( RFD.Valor_IEPS, 0 ) END ) AS Subt_sin_IEPS,  
                     SUM( ISNULL( RFD.Valor_IEPS, 0 ) ) AS Valor_IEPS                         
              FROM T3.Registro_Fiscal_Detalle RFD
              INNER JOIN T3.Registro_Fiscal RF_sub ON RFD.Factura = RF_sub.Factura
              LEFT JOIN T3.SKU_TASA_CERO Tax ON RFD.Material = Tax.Material
              WHERE RFD.Factura = @pFactura
        ) CFD ON 1=1
        INNER JOIN T3.RF_Complemento Comp ON RF.Factura = Comp.Factura
        INNER JOIN (
              SELECT 
                     Cte_in.Cliente_SAP AS Ou_Num, 
                     CteX_in.Email AS Pr_Con_ID,
                     Cte_in.Cliente_SAP AS Integration_ID,
                     -- DEV-REV2 RN-04 PENDIENTE: ISNULL no reemplaza una cadena vacia. En Oracle '' se trata como NULL; revisar el RFC generico y los valores por defecto de configuracion.
                     ISNULL( Cte_in.RFC, 'XAXX010101000' ) AS Tax_Exempt_Num,
                     ISNULL( RS_in.Razon_Social, Cte_in.Nombre ) AS Name,
                     CteX_in.X_Route_Ref_1 AS X_Route_Ref_1,
                     Cte_in.Metodo_pago AS Pay_Type_CD,
                     ISNULL( Reg_in.Regimen_Fiscal, EAI_Owner.getConv( 'CFG Settings', 'Regimen Fiscal Cliente' ) ) AS RegimenFiscal,
                     ISNULL( CFD_in.Ver_CFDi, EAI_Owner.getConv( 'CFG Settings', 'VersionCFDI' ) ) AS VersionCFDI,  
                     ISNULL( Uso_in.UsoCFDI, ISNULL( UsoC_in.Uso_Venta, EAI_Owner.getConv( 'CFG Settings', 'UsoCFDI_Comercial' ) ) ) AS UsoCFDI,
                     CteX_in.X_EM_Field_18 AS CteX_X_EM_Field_18,
                     CteX_in.Attrib_34 AS CteX_Attrib_34,
                     Cte_in.Lista_Precio AS LP_Name,
                     CteX_in.SAP_Cadena AS Cad_OU_NUM,
                     Cte_in.Codigo_Postal_2 AS Ship_ZipCode,
                     Cte_in.Pais_2 AS Ship_Country,
                     Cte_in.Estado_2 AS Ship_State,
                     Cte_in.Ciudad_2 AS Ship_City,
                     Cte_in.Direccion_2 AS Ship_Addr,
                     Cte_in.Colonia_2 AS Ship_Addr_Line_2,
                     ISNULL( CP_in.CP, Cte_in.Codigo_Postal_3 ) AS Bill_ZipCode,
                     Cte_in.Pais_3 AS Bill_Country,
                     Cte_in.Estado_3 AS Bill_State,
                     Cte_in.Ciudad_3 AS Bill_City,
                     Cte_in.Direccion_3 AS Bill_Addr,
                     Cte_in.Colonia_3 AS Bill_Addr_Line_2
              FROM T3.Mov_Cliente Cte_in
              LEFT JOIN T3.TMD_Email CteX_in ON Cte_in.Cliente_SAP = CteX_in.Cliente_SAP
              LEFT JOIN T3.CFDI_USOCFDI_CLIENTE UsoC_in ON Cte_in.Cliente_SAP = UsoC_in.Cliente_SAP
              LEFT JOIN ( SELECT RFC, MAX( Valor ) AS Regimen_Fiscal FROM T3.CFDI_RFC_Setting WHERE Parametro = 'RegimenFiscal' GROUP BY RFC ) Reg_in ON Cte_in.RFC = Reg_in.RFC
              LEFT JOIN ( SELECT RFC, MAX( Valor ) AS Ver_CFDI FROM T3.CFDI_RFC_Setting WHERE Parametro = 'VersionCFDI' GROUP BY RFC ) CFD_in ON Cte_in.RFC = CFD_in.RFC
              LEFT JOIN ( SELECT RFC, MAX( Valor ) AS UsoCFDI FROM T3.CFDI_RFC_Setting WHERE Parametro = 'UsoCFDI' GROUP BY RFC ) Uso_in ON Cte_in.RFC = Uso_in.RFC
              LEFT JOIN ( SELECT RFC, MAX( Valor ) AS CP FROM T3.CFDI_RFC_Setting WHERE Parametro = 'CodigoPostal' GROUP BY RFC ) CP_in ON Cte_in.RFC = CP_in.RFC
              LEFT JOIN ( SELECT RFC, MAX( Valor ) AS Razon_Social FROM T3.CFDI_RFC_Setting WHERE Parametro = 'Nombre' GROUP BY RFC ) RS_in ON Cte_in.RFC = RS_in.RFC
              WHERE Cte_in.Cliente_SAP = @sAccnt_ID
        ) Cte ON Cte.Ou_Num = @sAccnt_ID
        INNER JOIN EAI.ZSDFE_Soc Soc ON Comp.Sociedad = Soc.BUKRS AND Comp.Sociedad = ISNULL( Soc.KUNNR, 'NULL' )
        INNER JOIN T3.Tipo_Documento TD ON RF.Tipo_Docto = TD.Tipo_Documento
        INNER JOIN T3.Distribuidor_Fiscal DF ON RF.Ctro = DF.Ctro
        -- DEV-FIX JOIN / ORA-01 RESUELTO: Oracle permite que el cliente no tenga configuracion UsoC.
        -- LEFT JOIN conserva la factura en ese caso y devuelve NULL en las columnas de UsoC.
        -- Los ISNULL existentes aplican sus valores alternativos. INNER JOIN descartaba la factura.
        -- Mantener esta condicion en ON; filtrar UsoC en WHERE podria volver obligatoria la relacion.
        LEFT JOIN T3.CFDI_USOCFDI_CLIENTE UsoC ON RF.Cliente_SAP = UsoC.Cliente_SAP
        INNER JOIN (
              SELECT
                    CASE WHEN Alm_in.Ctro = 'MX7A' THEN 'MXAA' WHEN Alm_in.Ctro = 'MX7B' THEN 'MXAB' WHEN Alm_in.Ctro = 'MX7D' THEN 'MXAC' ELSE Alm_in.Ctro END AS Almacen_Ctro, 
                    CONCAT(Alm_in.Municipio, ', ', EAI_Owner.getConv( 'CFDI Estado', Alm_in.Estado )) AS Almacen_Lugar_Expide,    
                   Alm_in.Calle AS Almacen_Calle, -- se quito el uso de la funcion 28/10/2026
                    Alm_in.Numero_Exterior AS Almacen_NoExterior,
                    '' AS Almacen_NoInterior,                                                                             
                     Alm_in.Colonia AS Almacen_Colonia,-- se quito el uso de la funcion 28/10/2026
                    T3.FN_TRIM_CFDI( Alm_in.Municipio ) AS Almacen_Municipio,
                    T3.FN_TRIM_CFDI( EAI_Owner.getConv( 'CFDI Estado', Alm_in.Estado ) ) AS Almacen_Estado,
                    T3.FN_TRIM_CFDI( Alm_in.Pais ) AS Almacen_Pais, 
                    T3.FN_TRIM_CFDI( Alm_in.CODIGO_POSTAL ) AS Almacen_codigoPostal             
              FROM T3.Distribuidor_Fiscal Alm_in
              WHERE Alm_in.Ctro LIKE 'MX%'
        ) Alm ON RF.Ctro = Alm.Almacen_Ctro
        WHERE RF.Factura = @pFactura
          AND RF.Tipo_Docto IN ( 'C003', 'C004', 'C005', 'C006', 'C0FX', 'C019', 'C024', 'C025', 'C030', 'C031' ) 
          AND TD.CFD = 'NO';
        OPEN ScrDatos;
        FETCH NEXT FROM ScrDatos INTO @Doc_Addenda_Venta, @Doc_Addenda_Devol, @Doc_Addenda_Migrar, @Doc_Addenda_Tipo_Docto, @Doc_Ctro, @Doc_Fecha_Rollout, @Doc_Addenda_Fases, @Doc_Fecha_Documento, @Doc_Fecha_Factura, @Doc_Cadena_Comercial, @Doc_RFC_Cliente, @Doc_Factura, @Doc_versionCFDI, @Doc_Serie, @Doc_Folio, @Doc_pedidoV3, @Doc_pedidoSAP, @Doc_facturaSAP, @Doc_repVentas, @Doc_sucursalNombre, @Doc_Lista_Precio, @Doc_fecha_Reenvio, @Doc_fecha, @Doc_tipoDeComprobante, @Doc_formaDePago, @Doc_condicionesDePago, @Doc_motivoDescuento, @Doc_Descuento, @Doc_ajusteEnvio, @Doc_subTotal, @Doc_total, @Doc_ajusteIVA_DistFee, @Doc_metodoDePago, @Doc_NumCtaPago, @Doc_TipoCambio, @Doc_Moneda, @Doc_LugarExpedicion, @Doc_Emisor_RFC, @Doc_Emisor_Nombre, @Doc_Emisor_Calle, @Doc_Emisor_NoExterior, @Doc_Emisor_NoInterior, @Doc_Emisor_Colonia, @Doc_Emisor_Localidad, @Doc_Emisor_Municipio, @Doc_Emisor_Estado, @Doc_Emisor_Pais, @Doc_Emisor_CodigoPostal, @Doc_Expide_calle, @Doc_Expide_noExterior, @Doc_Expide_noInterior, @Doc_Expide_colonia, @Doc_Expide_municipio, @Doc_Expide_estado, @Doc_Expide_pais, @Doc_Expide_codigoPostal, @Doc_RegimenFiscal, @Doc_Regimen_Fiscal_Cte, @Doc_Recibe_RFC, @Doc_Recibe_Nombre, @Doc_Recibe_Calle, @Doc_Recibe_NoExterior, @Doc_Recibe_NoInterior, @Doc_Recibe_Colonia, @Doc_Recibe_Municipio, @Doc_Recibe_Estado, @Doc_Recibe_Pais, @Doc_Recibe_codigoPostal, @Doc_Remite_Calle, @Doc_Remite_Colonia, @Doc_Remite_Municipio, @Doc_Remite_Estado, @Doc_Remite_Pais, @Doc_Remite_codigoPostal, @Doc_Tipo_Documento, @Doc_Recibe_Cliente, @Doc_Remite_Cliente, @Doc_CentroExpedicion, @Doc_eMail, @Doc_ConfirmacionPAC, @Doc_UsoCFDI, @Doc_ResidenciaFiscal, @Doc_RegTributarioExt, @Doc_TipoRelacion, @Doc_ImpuestosTrasladados, @Doc_impuesto, @Doc_tasa, @Doc_importe_IVA, @Doc_importe, @Doc_subtotal_TasaIVA, @Doc_subtotal_Tasa00, @Doc_impSubtot_TASAIVA, @Doc_impSubtot_TASA00, @Doc_Valor_Subt_IEPS, @Doc_Valor_IEPS;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- DEV-FIX: reiniciar por cabecera; el original Oracle emitia la orden vacia.
            -- Poblar el pedido es una correccion funcional separada de la paridad NULL.
            SET @sOrdenCompra = '';
            SET @nTimbrados = 0;
            SET @sFactura           = @Doc_Factura;
            SET @sRecibe_RFC        = @Doc_Recibe_RFC;    
            SET @sAdd_Migrar        = @Doc_Addenda_Migrar;
            SET @sCtro              = @Doc_Ctro;
            SET @nTotal             = @Doc_total;
            SET @nImpSubtot_TASAIVA = @Doc_impSubtot_TASAIVA;
            SET @nImpSubtot_TASA00  = @Doc_impSubtot_TASA00; 
            SET @sLista_Precio      = @Doc_Lista_Precio;
            SET @nAjusteIVA_DistFee = @Doc_ajusteIVA_DistFee;
            SET @dtFecha_Factura    = @Doc_Fecha_Factura;
            -- REGLA HEREDADA: se reemplaza la lista del documento por 10 siempre,
            -- no solamente cuando el valor original esta vacio.
            SET @sLista_Precio      = '10';      

            -- DEV-REV C03: MAX(ISNULL(...,0)) devuelve NULL sin filas; validar existencia del catalogo.
            SELECT @nTasa_LP = MAX( ISNULL( Porc_IVA, 0 ) )
            FROM T3.Conv_Lista_Grupo_Precio
            WHERE Lista_Precio = @sLista_Precio;
			-- Admon de Addenda
            -- ADDENDA: datos comerciales adicionales solicitados por ciertos clientes.
            -- Se activa segun configuracion y tipo de documento: I = ingreso, E = egreso.
            -- Si hay activacion por fases, tambien se compara contra la fecha de inicio.
            IF ( ( @Doc_tipoDeComprobante = 'I' ) AND ( @Doc_Addenda_Venta = 'SI' ) )
            BEGIN
                SET @sAddenda = 'SI';
            END;
            IF ( ( @Doc_tipoDeComprobante = 'E' ) AND ( @Doc_Addenda_Devol = 'SI' ) )
            BEGIN
                SET @sAddenda = 'SI';
            END;      
            IF ( ( @sAddenda = 'SI' ) AND ( @Doc_Addenda_Fases = 'SI' ) )
            BEGIN
                IF ( CHARINDEX( '/', @Doc_Fecha_Rollout ) > 0 )
                BEGIN
                    SET @dtFechaRollout = CONVERT(DATETIME, @Doc_Fecha_Rollout, 103);
                    IF ( @Doc_Fecha_Documento >= @dtFechaRollout )
                    BEGIN
                        SET @sAddenda = 'SI';
                    END
                    ELSE
                    BEGIN
                        SET @sAddenda = 'NO';               
                    END;   
                END
                ELSE
                BEGIN
                    SET @sAddenda = 'NO';               
                END;
            END;      

            SET @nCFDIREL = 00;
            SET @sCFDIREL = '';

            -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
            -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
            -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
            -- 3. RELACIONES. Busca comprobantes previos de @sFactura.
            -- Agrega un registro BILLREF por cada folio fiscal, con tipo de relacion 04.
            DECLARE ScrReenvio CURSOR LOCAL FORWARD_ONLY STATIC FOR
            SELECT Folio_Fiscal, Fecha_Factura
            FROM T3.CFDI_Reproceso 
            WHERE Nota_Venta = @sFactura
            ORDER BY Fecha DESC;  
            OPEN ScrReenvio;
            FETCH NEXT FROM ScrReenvio INTO @Env_Folio_Fiscal, @Env_Fecha_Factura;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @nCFDIREL = @nCFDIREL + 1;
                SET @sCFDIREL = CONCAT(@sCFDIREL, 'BILLREF', @sSepCampo);
                SET @sCFDIREL = CONCAT(@sCFDIREL, @Env_Folio_Fiscal, @sSepCampo);          
                SET @sCFDIREL = CONCAT(@sCFDIREL, '', @sSepCampo);          
                SET @sCFDIREL = CONCAT(@sCFDIREL, '', @sSepCampo);          
                SET @sCFDIREL = CONCAT(@sCFDIREL, '04', @sSepCampo);          
                SET @sCFDIREL = CONCAT(@sCFDIREL, '', @sSepCampo);          
                SET @sCFDIREL = CONCAT(@sCFDIREL, @sSepLinea);         
                FETCH NEXT FROM ScrReenvio INTO @Env_Folio_Fiscal, @Env_Fecha_Factura;
            END;
            CLOSE ScrReenvio;
            DEALLOCATE ScrReenvio;

            SET @sREL_Facturas   = '';
            SET @nCFDI_CM        = 500;

            -- NOTA DE CREDITO: revisa a que documentos se asigno su importe.
            -- Para un RFC no generico compara el total asignado con el de la nota.
            IF ( ( @Doc_tipoDeComprobante = 'E' ) )
            BEGIN
                SET @sREL_Facturas   = '';
                SET @nCFDI_CM        = 500;
                SET @nTtl_CreditMemo = @nTotal;
                SET @nTtl_Assigned   = 00;   
                IF ( @Doc_Recibe_RFC != 'XAXX010101000' )
                BEGIN
                    SET @sStepPLSQL = 'ScrCreditMemo';

                    -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
                    -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
                    -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
                    -- Lee asignaciones de cobranza para @pFactura y sus folios relacionados.
                    -- La regla existente considera timbrado un folio con mas de 20 caracteres.
                    -- PENDIENTE: CFD y WA unen la misma tabla con la misma condicion; si hay
                    -- varias filas por Nota_Venta se pueden multiplicar los importes leidos.
                    DECLARE ScrAllocation CURSOR LOCAL FORWARD_ONLY STATIC FOR
                    SELECT Cobza.Fecha_Asignacion as Created, Cobza.Importe AS Paid_Amt, Cobza.Fecha_Factura AS Invc_dt, 
                          CASE 
                              WHEN ( WA.Fecha_Liberacion IS NULL ) AND ( CFD.Fecha_Liberacion IS NOT NULL ) THEN CFD.Nota_Venta
                              WHEN ( WA.Fecha_Liberacion IS NOT NULL )                                      THEN WA.Nota_Venta
                              ELSE Cobza.Referencia
                          END AS Doc_Num,
                          CASE 
                              WHEN ( WA.Fecha_Liberacion IS NULL ) AND ( CFD.Fecha_Liberacion IS NOT NULL ) THEN 'Otro'
                              WHEN ( WA.Fecha_Liberacion IS NOT NULL )                                      THEN 'Nota de Venta'
                              ELSE 'Debit Note'
                          END AS Sub_Type_CD,
                          CASE 
                              WHEN ( WA.Fecha_Liberacion IS NULL ) AND ( CFD.Fecha_Liberacion IS NOT NULL ) THEN CFD.Folio_Fiscal
                              WHEN ( WA.Fecha_Liberacion IS NOT NULL )                                      THEN WA.Folio_Fiscal
                              ELSE Cobza.UUID_VENTA
                          END AS Folio_Fiscal
                    FROM T3.CFDI_Cobranza Cobza
                    LEFT JOIN T3.CFDI_Documentos CFD ON Cobza.Nota_Venta = CFD.Nota_Venta
                    LEFT JOIN T3.CFDI_Documentos WA ON Cobza.Nota_Venta = WA.Nota_Venta
                    WHERE Cobza.Nota_Credito = @pFactura;
                    OPEN ScrAllocation;
                    FETCH NEXT FROM ScrAllocation INTO @CMA_Created, @CMA_Paid_Amt, @CMA_Invc_dt, @CMA_Doc_Num, @CMA_Sub_Type_CD, @CMA_Folio_Fiscal;
                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        -- DEV-NUM: no inventar un cero cuando falta una base valida para dividir.
                        IF (@CMA_Paid_Amt IS NULL)
                        BEGIN
                            SET @sMsg = CONCAT('Importe de cobranza NULL; no es un abono de cero. Factura: ', @pFactura, '; linea: ', @Item_numLinea);
                            THROW 51001, @sMsg, 1;
                        END;
                        SET @nCFDI_CM      = @nCFDI_CM + 1;
                        SET @dtFecha_Docto = @CMA_Invc_dt;
                        SET @sRefFactura   = @CMA_Doc_Num;
                        IF ( LEN( ISNULL( @CMA_Folio_Fiscal, ' ' ) ) > 20 )
                        BEGIN
                            SET @sCFDIREL = CONCAT(@sCFDIREL, 'BILLREF', @sSepCampo);
                            SET @sCFDIREL = CONCAT(@sCFDIREL, @CMA_Folio_Fiscal, @sSepCampo);          
                            SET @sCFDIREL = CONCAT(@sCFDIREL, '', @sSepCampo);          
                            SET @sCFDIREL = CONCAT(@sCFDIREL, '', @sSepCampo);          
                            SET @sCFDIREL = CONCAT(@sCFDIREL, '01', @sSepCampo);          
                            SET @sCFDIREL = CONCAT(@sCFDIREL, '', @sSepCampo);          
                            SET @sCFDIREL = CONCAT(@sCFDIREL, @sSepLinea);         
                            -- DEV-REV C04 RESUELTO: contador inicializado a cero por cabecera; se conserva el incremento historico.
                            SET @nTimbrados    = @nTimbrados + 1;
                            SET @nTtl_Assigned = @nTtl_Assigned + @CMA_Paid_Amt;
                        END
                        ELSE
                        BEGIN
                            IF ( @CMA_Sub_Type_CD != 'Nota de Venta' )
                            BEGIN
                                SET @nTtl_Assigned = @nTtl_Assigned + @CMA_Paid_Amt;
                            END;   
                        END;   
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, @sSepLinea);
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, 'LINCLIE', @sSepCampo);
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, CONVERT(VARCHAR(41), CAST( @nCFDI_CM AS DECIMAL(38,0) )), @sSepCampo);
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, 'Abono a documento ', @CMA_Doc_Num, ' del ', CONVERT(VARCHAR(10), @dtFecha_Docto, 103), ' por ', CONVERT(VARCHAR(41), CAST( @CMA_Paid_Amt AS DECIMAL(38,2) )), @sSepCampo);
                        FETCH NEXT FROM ScrAllocation INTO @CMA_Created, @CMA_Paid_Amt, @CMA_Invc_dt, @CMA_Doc_Num, @CMA_Sub_Type_CD, @CMA_Folio_Fiscal;
                    END;
                    CLOSE ScrAllocation;
                    DEALLOCATE ScrAllocation;

                    IF ( CAST(@Doc_Fecha_Factura AS DATE) != CAST(GETDATE() AS DATE) )
                    BEGIN
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, @sSepLinea);
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, 'LINCLIE', @sSepCampo);
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, CONVERT(VARCHAR(41), CAST( @nCFDI_CM + 1 AS DECIMAL(38,0) )), @sSepCampo);
                        SET @sREL_Facturas = CONCAT(@sREL_Facturas, 'Fecha de documento interno ', CONVERT(VARCHAR(10), @Doc_Fecha_Factura, 103), @sSepCampo);
                    END;   
                    -- Una diferencia mayor a 5.03 registra el saldo pendiente y termina con RETURN.
                    -- En esta ruta NO se llega al armado final ni al envio. ScrDatos se libera
                    -- aqui; los cursores hijos utilizados ya se cerraron y liberaron.
                    IF ( ABS( @nTtl_CreditMemo - @nTtl_Assigned ) > 5.03 )
                    BEGIN
                        -- DEV-NUM N04 RESUELTO: cobranza decimal(16,2) se acumula en numeric(22,2); se rechazan abonos NULL.
                        -- DEV-NUM: PENDIENTE es decimal(14,2): doce enteros y dos decimales.
                        -- Validar antes del INSERT; no recortar ni redondear para hacerlo caber.
                        IF (ABS(@nTtl_CreditMemo - @nTtl_Assigned) > 999999999999.99)
                        BEGIN
                            SET @sMsg = CONCAT('Pendiente fuera del rango decimal(14,2). Factura: ', @pFactura);
                            THROW 51002, @sMsg, 1;
                        END;
                        INSERT INTO T3.CFDI_LIBERA_NOTA_CREDITO ( Factura, Fecha, Pendiente )
                        VALUES ( @sFactura, GETDATE(),  @nTtl_CreditMemo - @nTtl_Assigned );     
                        
                        CLOSE ScrDatos; DEALLOCATE ScrDatos;
                        RETURN;            
                    END;
                END;      -- Credit Memo NO Generico
                 
                -- El UPDATE mantiene la fecha, pero permite saber si existe historia mediante
                -- @@ROWCOUNT. Si no encontro filas, se inserta la historia desde Registro_Fiscal.
                UPDATE T3.CFDI_Historia_Docto_PAC 
				SET Fecha_Factura = Fecha_Factura 
                WHERE Nota_Venta = @sFactura;
                SET @nHDP = @@ROWCOUNT;
                IF ( @nHDP = 0 )
                BEGIN         
                    INSERT INTO T3.CFDI_Historia_Docto_PAC      
                       ( Nota_Venta, Nota_Venta_CFDI, Ctro, Fecha_Factura )
                    SELECT Factura, Factura, Ctro, Fecha_Factura
                    FROM T3.Registro_Fiscal
                    WHERE Factura = @sFactura;
                END;               
                UPDATE T3.Registro_Fiscal SET Fecha_Factura = CAST(DATEADD(day, -1, GETDATE()) AS DATE) 
                WHERE Factura = @sFactura
                  AND Factura LIKE 'DESC%' 
                  -- DEV-ORA ORA-06: Oracle exige Fecha_Factura exactamente a medianoche; este CAST incluye cualquier hora del dia.
                  AND CAST(Fecha_Factura AS DATE) = CAST(GETDATE() AS DATE);
            END;      

			-- Addendas con 3.3
            --IF ( @sAddenda = 'SI' ) AND ( @sAdd_Migrar = 'NO' )
            --BEGIN
            --    --EXEC T3.PROC_VSF_GENERAR_MX06 @sFactura, @sAccnt_ID; -- Oracle logic commented commitment placeholder
            --    --COMMIT TRANSACTION;
            --    --RETURN;
            --  END;

			-- Begin: Item Segment
            -- 4. ARTICULOS. Reinicia los acumuladores de esta cabecera antes del detalle.
            -- Cada articulo suma a nDoc; no reiniciar esos totales dentro del bucle.
            SET @nDoc_Descuento     = 0;
            SET @nDoc_Valor_sin_IVA = 0;
            SET @nDoc_Valor_con_IVA = 0;
            SET @nDoc_Valor_IEPS    = 0;
            SET @nDoc_Valor_IVA     = 0;
            SET @nLineas            = 0;
            SET @nNum_Linea         = 0;
            SET @sStepPLSQL = 'Before ScrDetalle';

            -- DEV-NUM: validar las mismas filas y relaciones que ScrDetalle.
            -- Una base cero no permite calcular IVA/base, aunque el IVA sea cero.
            -- La cantidad solo es divisor en VD, IEPS o la addenda comercial.
            -- Se informa el error al CATCH; no se reemplaza el resultado por cero.
            IF EXISTS (
                SELECT 1
                FROM T3.Registro_Fiscal RF
                INNER JOIN T3.Registro_Fiscal_Detalle RFD ON RF.Factura = RFD.Factura
                LEFT JOIN T3.CFDI_USOCFDI_CLIENTE UsoC ON RF.Cliente_SAP = UsoC.Cliente_SAP
                INNER JOIN T3.Material Prod ON RFD.Material = Prod.Material
                WHERE RF.Factura = @pFactura
                  AND (RFD.Valor_Subt IS NULL OR RFD.Valor_Subt = 0
                       OR ((RFD.Cantidad_Vta IS NULL OR RFD.Cantidad_Vta = 0)
                           AND (RF.Tipo_Venta = 'VD' OR @sAddenda = 'SI'
                                OR ISNULL(RFD.Valor_IEPS, 0) * ISNULL(UsoC.Desglose_IEPS, 0) > 0)))
            )
            BEGIN
                SET @sMsg = CONCAT('Detalle con base IVA o cantidad divisora nula/cero. Factura: ', @pFactura);
                THROW 51001, @sMsg, 1;
            END;


            -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
            -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
            -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
            -- Obtiene articulos ordenados por numero de linea e importes/impuestos.
            -- DEV-NUM: los importes llegan al FETCH como numeros, sin STR de ancho fijo.
            -- NULLIF protege la materializacion; las validaciones rechazan divisores invalidos.
            DECLARE ScrDetalle CURSOR LOCAL FORWARD_ONLY STATIC FOR
            SELECT
                  RFD.Num_Linea AS numLinea,
                  RFD.Cantidad_Vta AS cantidad,  
                  CASE RF.Tipo_Docto 
                       WHEN 'Z024' THEN 'DCTO' WHEN 'Z022' THEN 'DCTO' WHEN 'Z019' THEN 'UA' WHEN 'Z0FX' THEN 'UA'
                       WHEN 'C025' THEN 'DCTO' WHEN 'C024' THEN 'DCTO' WHEN 'C022' THEN 'DCTO' WHEN 'C019' THEN 'DCTO'
                       WHEN 'C0FX' THEN 'UA' ELSE Prod.Unidad_Med_Vta END AS unidad,
                  T3.FN_SAP_SKU( RFD.Material ) AS noIdentificacion, 
                  T3.FN_CFDI_SKU_NAME( Prod.Nombre_Material ) AS descripcion,
                  CASE RF.Tipo_Venta WHEN 'VD' THEN CAST( ROUND( ( RFD.Valor_Subt + ISNULL( RFD.Bonif_Subt, 0 ) ) / NULLIF(RFD.Cantidad_Vta, 0), 2 ) AS DECIMAL(22,2) ) ELSE CAST( RFD.Precio_Unit AS DECIMAL(22,2) ) END AS valorUnitario,
                  CASE RF.Tipo_Venta WHEN 'VD' THEN CAST( ( RFD.Valor_Subt + ISNULL( RFD.Bonif_Subt, 0 ) ) AS DECIMAL(22,2) ) ELSE CAST( RFD.Precio_Unit * RFD.Cantidad_Vta AS DECIMAL(22,2) ) END AS importe,
                  CAST( ISNULL( RFD.Bonif_Subt, 0 ) AS DECIMAL(22,2) ) AS Descuento,                                                                                           
                  ISNULL( RFD.Valor_Subt, 0 ) AS RFD_Valor_Subt,             
                  ISNULL( RFD.Valor_IVA , 0 ) AS RFD_Valor_IVA,
                  CAST( ROUND( RFD.Valor_IVA * 100 / NULLIF(RFD.Valor_Subt, 0), 0 ) AS DECIMAL(22,2) ) AS RFD_Tasa_IVA,
                  CAST( ISNULL( RFD.Valor_Subt, 0 ) AS DECIMAL(22,2) ) AS PDF_Valor_Subt,
                  CAST( ISNULL( RFD.Valor_IVA , 0 ) AS DECIMAL(22,2) ) AS PDF_Valor_IVA,
                  CAST( ROUND( RFD.Valor_IVA * 100 / NULLIF(RFD.Valor_Subt, 0), 2 ) AS DECIMAL(22,0) ) AS PDF_TASA_IVA,
                  ISNULL( RFD.Envio_Subt , 0 ) AS Envio_Subt,
                  ISNULL( RFD.Envio_IVA  , 0 ) AS Envio_IVA,
                  ISNULL( RFD.Credito_Subt, 0 ) AS Credito_Subt,
                  ISNULL( RFD.Credito_IVA , 0 ) AS Credito_IVA,
                  ISNULL( UsoC.Desglose_IEPS, 0 ) * ( ISNULL( RFD.Valor_Subt, 0 ) - ISNULL( RFD.Valor_IEPS, 0 )) AS Subt_sin_IEPS,                                    
                  ISNULL( RFD.Valor_IEPS, 0 ) * ISNULL( UsoC.Desglose_IEPS, 0 ) AS Valor_IEPS                                      
            FROM T3.Registro_Fiscal RF
            INNER JOIN T3.Registro_Fiscal_Detalle RFD ON RF.Factura = RFD.Factura
            LEFT JOIN T3.CFDI_USOCFDI_CLIENTE UsoC ON RF.Cliente_SAP = UsoC.Cliente_SAP
            INNER JOIN T3.Material Prod ON RFD.Material = Prod.Material 
            WHERE RF.Factura = @pFactura
            ORDER BY RFD.Num_Linea;
            OPEN ScrDetalle;
            FETCH NEXT FROM ScrDetalle INTO @Item_numLinea, @Item_cantidad, @Item_unidad, @Item_noIdentificacion, @Item_descripcion, @Item_valorUnitario, @Item_importe, @Item_Descuento, @Item_RFD_Valor_Subt, @Item_RFD_Valor_IVA, @Item_RFD_Tasa_IVA, @Item_PDF_Valor_Subt, @Item_PDF_Valor_IVA, @Item_PDF_TASA_IVA, @Item_Envio_Subt, @Item_Envio_IVA, @Item_Credito_Subt, @Item_Credito_IVA, @Item_Subt_sin_IEPS, @Item_Valor_IEPS;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- DEV-FIX: siempre inicializar, incluso con addenda SI o sin pedimentos.
                -- DEV-NUM: no inventar un cero cuando falta una base valida para dividir.
                IF (@Item_RFD_Tasa_IVA IS NULL OR @Item_valorUnitario IS NULL)
                BEGIN
                    SET @sMsg = CONCAT('Importe o base invalida en detalle. Factura: ', @pFactura, '; linea: ', @Item_numLinea);
                    THROW 51001, @sMsg, 1;
                END;
                SET @sPedimentos = '';
                SET @nNumLinea  = CAST(@Item_numLinea AS NUMERIC(6,0));
                SET @nNum_Linea = @nNum_Linea + 1;
                SET @nLineas    = @nLineas    + 1; 
                SET @nItems     = @nItems + @Item_RFD_Valor_Subt + @Item_RFD_Valor_IVA;
                
                IF ( ISNULL( @pOutput, 0 ) > 10 )
                BEGIN
                    PRINT CONCAT(@Item_numLinea, ' - ', @Item_descripcion);
                END;
                SET @sStepPLSQL = CONCAT('Item (', @Item_numLinea, ').');
                IF ( @nLineas = 1 )
                BEGIN
                    SET @uLINFAC = '';
                END
                ELSE
                BEGIN
                    SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                END;
                
                -- Consulta clave de producto y unidad del SAT. OUTPUT significa que el
                -- procedimiento llamado escribe en @sSAT_ID y @sSAT_UM para usarlas en LINE.
                EXEC T3.GET_SAT_CLAVEPRODUCTO 'VTA', @pFactura, @Item_noIdentificacion, @Item_descripcion, @Item_unidad, @sSAT_ID OUTPUT, @sSAT_UM OUTPUT;      
                SET @sIdentificacion = REPLACE( @Item_noIdentificacion, '.', '' );

				--  WA para manejo de IEPS
                -- Con IEPS se usa la base sin ese impuesto para preparar el articulo.
                -- Sin IEPS se toman los importes de ScrDetalle. El descuento queda separado
                -- para representarlo y comparar los totales posteriormente.
                IF ( @Item_Valor_IEPS > 0 )
                BEGIN
                    SET @nEDICOM = @nEDICOM + @Item_Subt_sin_IEPS + @Item_RFD_Valor_IVA + @Item_Valor_IEPS;
                    SET @nItemImporte       = @Item_Subt_sin_IEPS + @Item_Descuento;
                    -- DEV-NUM: no inventar un cero cuando falta una base valida para dividir.
                    IF (@Item_cantidad IS NULL OR @Item_cantidad = 0)
                    BEGIN
                        SET @sMsg = CONCAT('Cantidad invalida para precio unitario con IEPS. Factura: ', @pFactura, '; linea: ', @Item_numLinea);
                        THROW 51001, @sMsg, 1;
                    END;
                    SET @nItemValorUnitario = ROUND( @nItemImporte / CAST(@Item_cantidad AS NUMERIC(22,2)), 2 );  
                    SET @nItemDescuento      = @Item_Descuento;
                END
                ELSE  
                BEGIN      
                    SET @nEDICOM = @nEDICOM + @Item_importe + @Item_RFD_Valor_IVA;
                    SET @nItemValorUnitario = @Item_valorUnitario;
                    SET @nItemImporte       = @Item_importe;
                    SET @nItemDescuento      = @Item_Descuento;
                END; 

                SET @sMaterial = @sIdentificacion;
                SET @nDoc_Descuento     = @nDoc_Descuento     + @nItemDescuento;
                SET @nDoc_Valor_IEPS    = @nDoc_Valor_IEPS    + @Item_Valor_IEPS;
                IF ( @Item_RFD_Valor_IVA > 0 )
                BEGIN
                    SET @nDoc_Valor_con_IVA = @nDoc_Valor_con_IVA + @nItemImporte; 
                    SET @nDoc_Valor_IVA     = @nDoc_Valor_IVA     + @Item_RFD_Valor_IVA;
                END
                ELSE
                BEGIN
                    SET @nDoc_Valor_sin_IVA = @nDoc_Valor_sin_IVA + @nItemImporte;
                END;

				-- Pedimentos de Importacion  
                -- DEV-REV C05 RESUELTO: @sPedimentos se inicializa por item antes del IF; CONCAT conserva el campo vacio.
                IF ( @sAddenda != 'SI' )
                BEGIN
                    SET @nCantPedimento = 00;
                    SET @sPedimentos   = '';         

                    -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
                    -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
                    -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
                    DECLARE ScrPedimento CURSOR LOCAL FORWARD_ONLY STATIC FOR
                    SELECT SAT.Aduana_Numero, SAT.Pedimento,
                          -- DEV-FIX ORA-04: usar 10 caracteres para conservar DD/MM/YYYY y quitar las barras: DDMMYYYY. Si no hay fecha, el campo sigue vacio.
                          CASE WHEN SAT.Fecha_Pedimento IS NULL THEN '' ELSE REPLACE(CONVERT(VARCHAR(10), SAT.Fecha_Pedimento, 103), '/', '') END AS FecPedimento         
                    FROM T3.CFDI_PEDIMENTO_SKU SAT
                    WHERE @sMaterial = SAT.Material
                      AND @dtFecha_Factura BETWEEN SAT.Fecha_Inicio AND SAT.Fecha_Final;   
                    OPEN ScrPedimento;
                    FETCH NEXT FROM ScrPedimento INTO @Ped_Aduana_Numero, @Ped_Pedimento, @Ped_FecPedimento;
                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SET @nCantPedimento = @nCantPedimento + 1;
                        IF ( @nCantPedimento > 1 )
                        BEGIN
                            SET @sPedimentos = CONCAT(@sPedimentos, '*');
                        END;
                        SET @sPedimentos = CONCAT(@sPedimentos, @Ped_Pedimento);
                        FETCH NEXT FROM ScrPedimento INTO @Ped_Aduana_Numero, @Ped_Pedimento, @Ped_FecPedimento;
                    END;
                    CLOSE ScrPedimento;
                    DEALLOCATE ScrPedimento;
                END;              

                -- LINE es el registro principal del articulo. Cada CONCAT agrega un campo
                -- en una posicion fija. Las cadenas vacias son campos reservados: no quitarlas
                -- ni reordenar las asignaciones aunque parezcan repetitivas.
                SET @sStepPLSQL = CONCAT('LINE (', @Item_numLinea, ').');
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINE', @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, CAST(@nNum_Linea AS VARCHAR), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sSAT_ID, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @Item_descripcion, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sIdentificacion, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @Item_cantidad, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @Item_unidad, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sSAT_UM, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                IF ( @Item_Descuento > 0 )
                BEGIN
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_Descuento, 2 ), @sSepCampo);   
                END
                ELSE
                BEGIN
                    SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                END;
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nItemValorUnitario, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nItemImporte, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @nTotalAmt = @nItemImporte - @Item_Descuento; 
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nItemImporte, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '02', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nItemImporte, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nTotalAmt, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sPedimentos, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   

				-- Inicio de Segmento para Addenda
                IF ( @sAddenda = 'SI' )
                BEGIN

                    -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
                    -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
                    -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
                    -- A_LINE agrega datos comerciales del articulo: codigos, empaque y precios.
                    -- Filtra por @sFactura y @nNumLinea, asignados antes de declarar el cursor.
                    -- @sOrdenCompra sigue vacia para conservar el comportamiento historico.
                    DECLARE ScrItemAddenda CURSOR LOCAL FORWARD_ONLY STATIC FOR
                    SELECT  
                          'LINADD' AS Label,
                          RFD.Num_Linea AS NumLin,
                          T3.FN_SAP_SKU( RFD.Material ) AS RefCliente,
                          Prod.Codigo_Barras_Pres_2 AS RefProvee,
                          '' AS RefSerieArt,
                          'ES' AS IdiomaDesc,
                          RFD.Cantidad_Vta AS Cantidad_Vta,
                          RFD.Unidad_Med_Vta AS Unidad_Med_Vta,
                          '1' AS CantConsum,
                          '' AS CantFree,
                          '' AS CantComer,
                          @sOrdenCompra AS NOrdenC,
                          'SRV' AS CalifIdentity,
                          '' AS SerieContenedor,
                          '' AS NumPaq,
                          'PCE' AS TipPaq, 
                          '' AS DescripPaq,
                          '' AS PaqMetodoPago,
                          CONVERT(VARCHAR(41), CAST( ISNULL( RFD.Valor_Subt, 0 ) - CASE RF.Tipo_Venta WHEN 'VD' THEN 0 ELSE ISNULL( RFD.Bonif_Subt, 0 ) END AS DECIMAL(38,2) )) AS MontoBruLin,
                          CONVERT(VARCHAR(41), CAST( ISNULL( RFD.Precio_Unit, 0 ) AS DECIMAL(38,2) )) AS PrecioBruto,
                          '' AS FechaEntrega,
                          '' AS CRTienda,
                          '' AS Tienda,
                          '' AS FacturaInterna,
                          '' AS LineaInterna,
                          '' AS PlantaReceptora,
                          '' AS NRecipiente,
                          '' AS Release,
                          '' AS Remision,
                          RFD.Valor_Subt + RFD.Valor_IVA AS Linea_con_IVA,
                          ROUND( ( RFD.Valor_Subt + RFD.Valor_IVA ) / NULLIF(RFD.Cantidad_Vta, 0), 2 ) AS Precio_con_IVA              
                    FROM T3.Registro_Fiscal RF
                    INNER JOIN T3.Registro_Fiscal_Detalle RFD ON RF.Factura = RFD.Factura
                    INNER JOIN T3.Material Prod ON RFD.Material = Prod.Material
                    WHERE RF.Factura = @sFactura
                      AND RFD.Num_Linea = @nNumLinea;
                    OPEN ScrItemAddenda;
                    FETCH NEXT FROM ScrItemAddenda INTO @Reg_Label, @Reg_NumLin, @Reg_RefCliente, @Reg_RefProvee, @Reg_RefSerieArt, @Reg_IdiomaDesc, @Reg_Cantidad_Vta, @Reg_Unidad_Med_Vta, @Reg_CantConsum, @Reg_CantFree, @Reg_CantComer, @Reg_NOrdenC, @Reg_CalifIdentity, @Reg_SerieContenedor, @Reg_NumPaq, @Reg_TipPaq, @Reg_DescripPaq, @Reg_PaqMetodoPago, @Reg_MontoBruLin, @Reg_PrecioBruto, @Reg_FechaEntrega, @Reg_CRTienda, @Reg_Tienda, @Reg_FacturaInterna, @Reg_LineaInterna, @Reg_PlantaReceptora, @Reg_NRecipiente, @Reg_Release, @Reg_Remision, @Reg_Linea_con_IVA, @Reg_Precio_con_IVA;
                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        -- DEV-NUM: ScrItemAddenda se materializa aparte del detalle.
                        -- Comprobar su propio divisor evita emitir un precio vacio si los datos cambiaron.
                        IF (@Reg_Cantidad_Vta IS NULL OR @Reg_Cantidad_Vta = 0)
                        BEGIN
                            SET @sMsg = CONCAT('Cantidad invalida en addenda. Factura: ', @pFactura, '; linea: ', @Reg_NumLin);
                            THROW 51001, @sMsg, 1;
                        END;
                        SET @sStepPLSQL = CONCAT('A_LINE (', @Item_numLinea, ').');
                        SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                        SET @uLINFAC = CONCAT(@uLINFAC, 'A_LINE', @sSepCampo);
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_RefCliente, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_RefProvee, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_RefSerieArt, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_IdiomaDesc, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_CantConsum, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_CantFree, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_CantComer, @sSepCampo);   
                        -- DEV-REV S01 RESUELTO: NOrdenC vacio por cabecera y CONCAT conserva el separador.
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_NOrdenC, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_CalifIdentity, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_SerieContenedor, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_NumPaq, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_TipPaq, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_DescripPaq, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_PaqMetodoPago, @sSepCampo);   
                        
						-- Extra ocupa linea con IVA
                        IF ( ( @sRecibe_RFC = 'TEX9302097F3' ) )
                        BEGIN
                            SET @uLINFAC = CONCAT(@uLINFAC, CAST(@Reg_Linea_con_IVA AS VARCHAR), @sSepCampo);   
                        END
                        ELSE
                        BEGIN
                            SET @uLINFAC = CONCAT(@uLINFAC, @Reg_MontoBruLin, @sSepCampo);   
                        END;   
                        -- DEV-ORA ORA-09: numeric(22,2) se serializa con dos decimales; Oracle concatena la cantidad directa. Comparar representacion 1 frente a 1.00.
                        SET @uLINFAC = CONCAT(@uLINFAC, CAST(@Reg_Cantidad_Vta AS VARCHAR), @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_Unidad_Med_Vta, @sSepCampo);   
                        
						-- Extra ocupa linea con IVA
                        IF ( ( @sRecibe_RFC = 'TEX9302097F3' ) )
                        BEGIN
                            SET @uLINFAC = CONCAT(@uLINFAC, CAST(@Reg_Precio_con_IVA AS VARCHAR), @sSepCampo);   
                            SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                            SET @uLINFAC = CONCAT(@uLINFAC, CAST(@Reg_Precio_con_IVA AS VARCHAR), @sSepCampo);   
                            SET @uLINFAC = CONCAT(@uLINFAC, CAST(@Reg_Linea_con_IVA AS VARCHAR), @sSepCampo);   
                        END
                        ELSE
                        BEGIN
                            SET @uLINFAC = CONCAT(@uLINFAC, @Reg_PrecioBruto, @sSepCampo);   
                            SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                            SET @uLINFAC = CONCAT(@uLINFAC, @Reg_PrecioBruto, @sSepCampo);   
                            SET @uLINFAC = CONCAT(@uLINFAC, @Reg_MontoBruLin, @sSepCampo);   
                        END;   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_FechaEntrega, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_CRTienda, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_Tienda, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_FacturaInterna, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_LineaInterna, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_PlantaReceptora, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_NRecipiente, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_Release, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Reg_Remision, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @sIdentificacion, @sSepCampo);                   
                        FETCH NEXT FROM ScrItemAddenda INTO @Reg_Label, @Reg_NumLin, @Reg_RefCliente, @Reg_RefProvee, @Reg_RefSerieArt, @Reg_IdiomaDesc, @Reg_Cantidad_Vta, @Reg_Unidad_Med_Vta, @Reg_CantConsum, @Reg_CantFree, @Reg_CantComer, @Reg_NOrdenC, @Reg_CalifIdentity, @Reg_SerieContenedor, @Reg_NumPaq, @Reg_TipPaq, @Reg_DescripPaq, @Reg_PaqMetodoPago, @Reg_MontoBruLin, @Reg_PrecioBruto, @Reg_FechaEntrega, @Reg_CRTienda, @Reg_Tienda, @Reg_FacturaInterna, @Reg_LineaInterna, @Reg_PlantaReceptora, @Reg_NRecipiente, @Reg_Release, @Reg_Remision, @Reg_Linea_con_IVA, @Reg_Precio_con_IVA;
                    END;
                    CLOSE ScrItemAddenda;
                    DEALLOCATE ScrItemAddenda;

                    SET @sStepPLSQL = CONCAT('A_ADUANA (', @Item_numLinea, ').');

                    -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
                    -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
                    -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
                    DECLARE ScrPedimento CURSOR LOCAL FORWARD_ONLY STATIC FOR
                    SELECT SAT.Aduana_Numero, SAT.Pedimento,
                          -- DEV-FIX ORA-04: usar 10 caracteres para conservar DD/MM/YYYY y quitar las barras: DDMMYYYY. Si no hay fecha, el campo sigue vacio.
                          CASE WHEN SAT.Fecha_Pedimento IS NULL THEN '' ELSE REPLACE(CONVERT(VARCHAR(10), SAT.Fecha_Pedimento, 103), '/', '') END AS FecPedimento         
                    FROM T3.CFDI_PEDIMENTO_SKU SAT
                    WHERE @sMaterial = SAT.Material
                      AND @dtFecha_Factura BETWEEN SAT.Fecha_Inicio AND SAT.Fecha_Final;   
                    OPEN ScrPedimento;
                    FETCH NEXT FROM ScrPedimento INTO @Ped_Aduana_Numero, @Ped_Pedimento, @Ped_FecPedimento;
                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                        SET @uLINFAC = CONCAT(@uLINFAC, 'A_ADUANA', @sSepCampo);
                        SET @uLINFAC = CONCAT(@uLINFAC, @Ped_Aduana_Numero, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Ped_Pedimento, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, @Ped_FecPedimento, @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                        SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                        FETCH NEXT FROM ScrPedimento INTO @Ped_Aduana_Numero, @Ped_Pedimento, @Ped_FecPedimento;
                    END;
                    CLOSE ScrPedimento;         
                    DEALLOCATE ScrPedimento;

                    SET @sStepPLSQL = CONCAT('A_LINETAX (', @Item_numLinea, ').');
                    SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                    SET @uLINFAC = CONCAT(@uLINFAC, 'A_LINETAX', @sSepCampo);
                    SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '002', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_RFD_Valor_IVA, 2 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_RFD_Tasa_IVA / 100, 6 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'T', @sSepCampo);  

                    SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                    SET @uLINFAC = CONCAT(@uLINFAC, 'A_LINETAX', @sSepCampo);
                    SET @uLINFAC = CONCAT(@uLINFAC, '2', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '003', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '0', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '0', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'T', @sSepCampo);  
                END;  

				-- Fin de Segmento para Addenda - Item
                -- LINETAX describe impuestos de este articulo. El contador numera registros.
                -- Se agrega IEPS cuando aplica y despues IVA. Dividir la tasa entre 100
                -- permite emitir 16 por ciento como 0.160000. FN_NUM_TO_CHAR_CFDI decide
                -- los decimales del texto; CONCAT no reemplaza esa funcion.
                SET @nLineaTax = 0;
                IF ( @Item_Valor_IEPS > 0 )
                BEGIN
                    SET @nLineaTax = @nLineaTax + 1;
                    -- DEV-NUM: no inventar un cero cuando falta una base valida para dividir.
                    IF (@Item_Subt_sin_IEPS IS NULL OR @Item_Subt_sin_IEPS = 0)
                    BEGIN
                        SET @sMsg = CONCAT('Base invalida para calcular tasa (@Item_Subt_sin_IEPS). Factura: ', @pFactura, '; linea: ', @Item_numLinea);
                        THROW 51001, @sMsg, 1;
                    END;
                    SET @nTasa_IEPS = ROUND( @Item_Valor_IEPS * 100 / @Item_Subt_sin_IEPS, 0 ); 
                    SET @sStepPLSQL = CONCAT('LINETAX IEPS (', @Item_numLinea, ').');
                    SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);                 
                    SET @uLINFAC = CONCAT(@uLINFAC, 'LINETAX', @sSepCampo);        
                    SET @uLINFAC = CONCAT(@uLINFAC, CAST(@nLineaTax AS VARCHAR), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '003', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_Subt_sin_IEPS, 2 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_Valor_IEPS, 2 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nTasa_IEPS / 100 , 6 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'Tasa', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'T', @sSepCampo);  
                END;      
                IF ( @Item_RFD_Valor_IVA >= 0 )
                BEGIN
                    SET @nLineaTax = @nLineaTax + 1;
                    -- DEV-NUM: no inventar un cero cuando falta una base valida para dividir.
                    IF (@Item_PDF_Valor_Subt IS NULL OR @Item_PDF_Valor_Subt = 0)
                    BEGIN
                        SET @sMsg = CONCAT('Base invalida para calcular tasa (@Item_PDF_Valor_Subt). Factura: ', @pFactura, '; linea: ', @Item_numLinea);
                        THROW 51001, @sMsg, 1;
                    END;
                    SET @nTasa_IEPS = ROUND( @Item_PDF_Valor_IVA * 100 / @Item_PDF_Valor_Subt, 0 ); 
                    IF ( @nTasa_IEPS > 0 )
                    BEGIN
                        SET @nTasa_IEPS = @nTasa_LP;
                    END
                    ELSE
                    BEGIN
                        SET @nTasa_IEPS = 0;
                    END;            
                    SET @sStepPLSQL = CONCAT('LINETAX IVA (', @Item_numLinea, ').');
                    SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);                 
                    SET @uLINFAC = CONCAT(@uLINFAC, 'LINETAX', @sSepCampo);        
                    SET @uLINFAC = CONCAT(@uLINFAC, CAST(@nLineaTax AS VARCHAR), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '002', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_PDF_Valor_Subt, 2 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_PDF_Valor_IVA , 2 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nTasa_IEPS / 100 , 6 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'Tasa', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'T', @sSepCampo);  
                END
                ELSE
                BEGIN
                    SET @sStepPLSQL = CONCAT('LINETAX IVA (', @Item_numLinea, ').');
                    SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);                 
                    SET @uLINFAC = CONCAT(@uLINFAC, 'LINETAX', @sSepCampo);        
                    SET @uLINFAC = CONCAT(@uLINFAC, CAST(@nLineaTax AS VARCHAR), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '002', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @Item_PDF_Valor_Subt, 2 ), @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '0.00', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, '0.000000', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'Tasa', @sSepCampo);  
                    SET @uLINFAC = CONCAT(@uLINFAC, 'T', @sSepCampo);          
                END;
                -- Acumula cargos de envio y credito de los articulos. Al cerrar el detalle
                -- se emiten como lineas separadas, en lugar de un cargo por articulo.
                SET @nEnvio_Subt   = @nEnvio_Subt   + @Item_Envio_Subt;
                SET @nEnvio_IVA    = @nEnvio_IVA    + @Item_Envio_IVA;
                SET @nCredito_Subt = @nCredito_Subt + @Item_Credito_Subt;
                SET @nCredito_IVA  = @nCredito_IVA  + @Item_Credito_IVA;
                
                IF ( @pOutput > 10 )
                BEGIN
                    PRINT '-------------------';
                    PRINT CONCAT('SKU              : ', @sIdentificacion);
                    PRINT CONCAT('Subtotal s/IEPS  : ', CAST(@Item_Subt_sin_IEPS AS VARCHAR));
                    PRINT CONCAT('Descuento        : ', CAST(@Item_Descuento AS VARCHAR));
                    PRINT CONCAT('IEPS             : ', CAST(@Item_Valor_IEPS AS VARCHAR));
                    PRINT CONCAT('Subtotal         : ', CAST(@Item_PDF_Valor_Subt AS VARCHAR));
                    PRINT CONCAT('IVA              : ', CAST(@Item_PDF_Valor_IVA AS VARCHAR));
                END;        
                FETCH NEXT FROM ScrDetalle INTO @Item_numLinea, @Item_cantidad, @Item_unidad, @Item_noIdentificacion, @Item_descripcion, @Item_valorUnitario, @Item_importe, @Item_Descuento, @Item_RFD_Valor_Subt, @Item_RFD_Valor_IVA, @Item_RFD_Tasa_IVA, @Item_PDF_Valor_Subt, @Item_PDF_Valor_IVA, @Item_PDF_TASA_IVA, @Item_Envio_Subt, @Item_Envio_IVA, @Item_Credito_Subt, @Item_Credito_IVA, @Item_Subt_sin_IEPS, @Item_Valor_IEPS;
            END;
            CLOSE ScrDetalle;
            DEALLOCATE ScrDetalle;

			-- Desglosar Costo de Distribucion 
            -- 5. CARGOS. Si existe subtotal de envio se agrega una linea y su impuesto.
            -- getConv devuelve codigos/descripciones configurados. La tasa se fuerza
            -- a 16 mas adelante: es una regla heredada, no una validacion del calculo.
            IF ( @nEnvio_Subt > 0 )
            BEGIN
                SET @nLineas    = @nLineas    + 1; 
                SET @nNum_Linea = @nNum_Linea + 1;      
                SELECT 
                    @sEnvio_ID_Code   = EAI_Owner.getConv( 'CFG Settings', 'Envio-SKU-ID' ),
                    @sEnvio_ID_UPC    = EAI_Owner.getConv( 'CFG Settings', 'Envio-SKU-UPC' ),
                    @sEnvio_UM        = EAI_Owner.getConv( 'CFG Settings', 'Envio-UnidadMedida' ),  
                    @sEnvio_Descrip   = EAI_Owner.getConv( 'CFG Settings', 'Envio-Descripcion' ),  
                    @sEnvio_SAT_IDDet = EAI_Owner.getConv( 'CFG Settings', 'Envio-SAT-ID' ),
                    @sEnvio_SAT_IDMay = EAI_Owner.getConv( 'CFG Settings', 'Envio-SAT-ID-Mayoreo' ), 
                    @sEnvio_SAT_UM    = EAI_Owner.getConv( 'CFG Settings', 'Envio-SAT-UM' );
                
                SELECT @sEnvio_SAT_ID = MAX( SKU_SAT ) 
                FROM T3.Conv_Lista_Grupo_Precio
                WHERE Lista_Precio = @sLista_Precio;

                IF ( ISNULL( @sEnvio_SAT_ID, 'Det' ) = 'Det' )
                BEGIN
                    SET @sEnvio_SAT_ID = @sEnvio_SAT_IDDet;
                END
                ELSE
                BEGIN
                    SET @sEnvio_SAT_ID = @sEnvio_SAT_IDMay;
                END; 

                SET @sStepPLSQL = 'LINE Dist Fee';
                SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINE', @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, CAST(@nNum_Linea AS VARCHAR), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sEnvio_SAT_ID, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sEnvio_Descrip, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sEnvio_ID_Code, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sEnvio_UM, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sEnvio_SAT_UM, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_Subt, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_Subt, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_Subt, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '02', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_Subt, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_Subt, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   

                -- DEV-NUM: Oracle fija 16 inmediatamente; omitir la tasa provisional evita un desbordamiento sin cambiar la tasa usada.
                SET @nEnvio_TASA = 16;
                SET @nEnvio_IVA  = ROUND( @nEnvio_Subt * @nEnvio_TASA / 100, 2 );

                SET @nDoc_Valor_con_IVA = @nDoc_Valor_con_IVA + @nEnvio_Subt; 
                SET @nDoc_Valor_IVA     = @nDoc_Valor_IVA     + @nEnvio_IVA;
                SET @nItems  = @nItems  + @nEnvio_Subt + @nEnvio_IVA;
                SET @nEDICOM = @nEDICOM + @nEnvio_Subt + @nEnvio_IVA;

                SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);                 
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINETAX', @sSepCampo);        
                SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, '002', @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_Subt , 2 ), @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_IVA  , 2 ), @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nEnvio_TASA / 100 , 6 ), @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, 'Tasa', @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, 'T', @sSepCampo);      
            END;

			-- Desglosar Costo de Credito
            -- Agrega la linea del costo de credito y actualiza los totales.
            -- La tasa tambien se fuerza a 16; revisar esta regla queda pendiente.
            IF ( @nCredito_Subt > 0 )
            BEGIN
                SET @nLineas    = @nLineas    + 1; 
                SET @nNum_Linea = @nNum_Linea + 1;      
                SELECT 
                    @sCredito_ID_Code = EAI_Owner.getConv( 'CFG Settings', 'Credito-SKU-ID' ),
                    @sCredito_ID_UPC  = EAI_Owner.getConv( 'CFG Settings', 'Credito-SKU-UPC' ),
                    @sCredito_UM      = EAI_Owner.getConv( 'CFG Settings', 'Credito-UnidadMedida' ),  
                    @sCredito_Descrip = EAI_Owner.getConv( 'CFG Settings', 'Credito-Descripcion' ),  
                    @sCredito_SAT_ID  = EAI_Owner.getConv( 'CFG Settings', 'Credito-SAT-ID' ),
                    @sCredito_SAT_UM  = EAI_Owner.getConv( 'CFG Settings', 'Credito-SAT-UM' );

                SET @sStepPLSQL = 'LINE Credit Fee';
                SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINE', @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, CAST(@nNum_Linea AS VARCHAR), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sCredito_SAT_ID, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sCredito_Descrip, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sCredito_ID_Code, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sCredito_UM, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, @sEnvio_SAT_UM, @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nCredito_Subt AS DECIMAL(38,2) )), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nCredito_Subt AS DECIMAL(38,2) )), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nCredito_Subt, 2 ), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '02', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nCredito_Subt AS DECIMAL(38,2) )), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nCredito_Subt AS DECIMAL(38,2) )), @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   
                SET @uLINFAC = CONCAT(@uLINFAC, '', @sSepCampo);   

                -- DEV-NUM: misma regla Oracle de tasa fija 16; no calcular una tasa provisional que nunca se utiliza.
                SET @nCredito_TASA = 16;
                SET @nCredito_IVA  = ROUND( @nCredito_Subt * @nCredito_TASA / 100, 2 );

                SET @nDoc_Valor_con_IVA = @nDoc_Valor_con_IVA + @nCredito_Subt; 
                SET @nDoc_Valor_IVA     = @nDoc_Valor_IVA     + @nCredito_IVA;
                SET @nItems  = @nItems  + @nCredito_Subt + @nCredito_IVA;
                SET @nEDICOM = @nEDICOM + @nCredito_Subt + @nCredito_IVA;

                SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);                 
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINETAX', @sSepCampo);        
                SET @uLINFAC = CONCAT(@uLINFAC, '1', @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, '002', @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nCredito_Subt , 2 ), @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nCredito_IVA  , 2 ), @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, T3.FN_NUM_TO_CHAR_CFDI( @nCredito_TASA / 100, 6 ), @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, 'Tasa', @sSepCampo);  
                SET @uLINFAC = CONCAT(@uLINFAC, 'T', @sSepCampo);  
            END;

            IF ( ( @nImpSubtot_TASA00 > 0 ) AND ( @nImpSubtot_TASAIVA > 0 ) )
            BEGIN
                SET @nLineas = @nLineas + 1; 
                SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINCLIE', @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nLineas AS DECIMAL(38,0) )), @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, 'Este documento contiene:', @sSepCampo); 
                SET @nLineas = @nLineas + 1; 
                SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINCLIE', @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nLineas AS DECIMAL(38,0) )), @sSepCampo);
                -- DEV-REV2 RN-03 PENDIENTE: Oracle formatea estas leyendas con comas de miles (1,234.50); la conversion decimal a texto emite 1234.50. Cambia la presentacion, no el monto.
                SET @uLINFAC = CONCAT(@uLINFAC, 'Ingreso base 16% ', CONVERT(VARCHAR(41), CAST( ( @nDoc_Valor_con_IVA ) AS DECIMAL(38,2) )), @sSepCampo);
                SET @nLineas = @nLineas + 1; 
                SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
                SET @uLINFAC = CONCAT(@uLINFAC, 'LINCLIE', @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nLineas AS DECIMAL(38,0) )), @sSepCampo);
                SET @uLINFAC = CONCAT(@uLINFAC, 'Ingreso base 0% ', CONVERT(VARCHAR(41), CAST( @nDoc_Valor_sin_IVA AS DECIMAL(38,2) )), @sSepCampo);
            END;   -- End: Item Segment

            IF ( @pOutput > 0 )
            BEGIN
                PRINT CONCAT('Factura          : ', @pFactura);
                PRINT CONCAT('Subtotal con IVA : ', CAST(@nDoc_Valor_con_IVA AS VARCHAR));
                PRINT CONCAT('Subtotal sin IVA : ', CAST(@nDoc_Valor_sin_IVA AS VARCHAR));
                PRINT CONCAT('Descuento        : ', CAST(@nDoc_Descuento AS VARCHAR));
                PRINT CONCAT('IEPS             : ', CAST(@nDoc_Valor_IEPS AS VARCHAR));
                PRINT CONCAT('IVA              : ', CAST(@nDoc_Valor_IVA AS VARCHAR));
                PRINT CONCAT('Total            : ', CAST(( @nDoc_Valor_con_IVA + @nDoc_Valor_sin_IVA - @nDoc_Descuento + @nDoc_Valor_IEPS + @nDoc_Valor_IVA ) AS VARCHAR));
                PRINT '-------------------';
                PRINT CONCAT('Subtotal         : ', CAST(@Doc_subTotal AS VARCHAR));
                PRINT CONCAT('Descuento        : ', CAST(@Doc_Descuento AS VARCHAR));
                PRINT CONCAT('IEPS             : ', CAST(@Doc_Valor_IEPS AS VARCHAR));
                PRINT CONCAT('IVA              : ', CAST(@Doc_importe_IVA AS VARCHAR));
                PRINT CONCAT('Total            : ', CAST(@Doc_total AS VARCHAR));
                PRINT CONCAT('Ajuste Envio IVA : ', CAST(@Doc_ajusteEnvio AS VARCHAR));
            END;   

            IF ( ( @Doc_Recibe_RFC = 'TCH850701RM1' ) )
            BEGIN
                SET @sLocalidadEmisor   = 'Monterrey';
                SET @sLocalidadReceptor = 'México';
            END
            ELSE
            BEGIN
                SET @sLocalidadEmisor   = '';
                SET @sLocalidadReceptor = '';
            END;   
			-- Cabecera Factura

			--    WA cambio entre formaDePago y Metodo de Pago
            -- 6. PAGO Y CABECERA. Obtiene forma/metodo y cuenta de pago. Las condiciones
            -- siguientes adaptan la respuesta al formato del documento. Para el RFC
            -- generico se fuerzan forma 01 y metodo PUE segun la regla existente.
            -- DEV-REV2 DEPENDENCIA: la llamada se conserva, pero falta certificar su resultado contra Oracle. Revisar en el procedimiento hijo cuando scrPayments toma @dtFecha_Doc.
            EXEC T3.PROC_CFDI_GET_PAYMETHOD @pFactura, @Doc_formaDePago, @Doc_NumCtaPago, @sMetodoDePago OUTPUT, @sNumCtaPago OUTPUT;
            IF ( @sMetodoDePago != '99' )
            BEGIN
                SET @sFormaDePago  = @sMetodoDePago; 
                SET @sMetodoDePago = 'PUE';  
            END
            ELSE
            BEGIN
                SET @sFormaDePago  = @Doc_formaDePago;
                SET @sMetodoDePago = @Doc_metodoDePago;   
            END;
            IF ( @Doc_Recibe_RFC = 'XAXX010101000' )
            BEGIN
                SET @sFormaDePago  = '01'; 
                SET @sMetodoDePago = 'PUE';        
            END;

            -- Total de salida: suma las bases, resta el descuento y agrega IEPS e IVA.
            -- Se mantiene separado de @nTotal para comparar diferencias y registrar ajustes.
            SET @nDoc_Total = @nDoc_Valor_sin_IVA + @nDoc_Valor_con_IVA;
            IF ( @nDoc_Descuento > 0 )
            BEGIN
                SET @nDescuento = @nDoc_Descuento;
            END
            ELSE
            BEGIN
                SET @nDescuento = 0;
                IF ( @sAddenda = 'SI' )
                BEGIN
                    SET @nDescuento = 0;
                END;   
            END;
      
            SET @nDoc_Total = @nDoc_Total - @nDoc_Descuento;
            SET @nDoc_Total = @nDoc_Total + @nDoc_Valor_IEPS + @nDoc_Valor_IVA;

			-- HEADER
            -- DEV-REV S02 RESUELTO: CONCAT en cada campo y acumuladores VARCHAR(MAX); formato y delimitadores conservados.
            -- HEADER contiene datos generales del comprobante. Los registros PARTIES
            -- que siguen identifican emisor (E) y receptor (R), con sus datos fiscales.
            SET @uHEADER = CONCAT(@uHEADER, 'HEADER', @sSepCampo);              
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_tipoDeComprobante, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_folio, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @sFormaDePago, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            IF ( ( @nCFDIREL = 0 ) AND ( @Doc_tipoDeComprobante = 'I' ) )
            BEGIN
                SET @uHEADER = CONCAT(@uHEADER, @Doc_fecha, @sSepCampo);   
            END
            ELSE
            BEGIN
                SET @uHEADER = CONCAT(@uHEADER, @Doc_fecha_Reenvio, @sSepCampo);   
            END;
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, T3.FN_NUM_TO_CHAR_CFDI( @Doc_importe, 2 ), @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, T3.FN_NUM_TO_CHAR_CFDI( @Doc_subtotal_Tasa00, 2 ), @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, T3.FN_NUM_TO_CHAR_CFDI( @Doc_subTotal - @Doc_Valor_IEPS, 2 ), @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, T3.FN_NUM_TO_CHAR_CFDI( @Doc_importe, 2 ), @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, T3.FN_NUM_TO_CHAR_CFDI( @nDoc_Total, 2 ), @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Factura, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_condicionesDePago, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Moneda, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Serie, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            IF ( @sAddenda = 'NO' )
            BEGIN
                SET @uHEADER = CONCAT(@uHEADER, 'C', @sSepCampo);   
            END
            ELSE
            BEGIN
                SET @uHEADER = CONCAT(@uHEADER, 'A', @sSepCampo);   
            END;
            SET @uHEADER = CONCAT(@uHEADER, '01', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_versionCFDI, @sSepCampo);   
			-- PARTIES - Emisor
            SET @uHEADER = CONCAT(@uHEADER, @sSepLinea);
            SET @uHEADER = CONCAT(@uHEADER, 'PARTIES', @sSepCampo);              
            SET @uHEADER = CONCAT(@uHEADER, 'E', @sSepCampo);              
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Emisor_RFC, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Emisor_Nombre, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_LugarExpedicion, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Emisor_Calle, ' ', @Doc_Emisor_NoExterior, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Emisor_Colonia, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Emisor_Municipio, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Emisor_Estado, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_RegimenFiscal, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Expide_codigoPostal, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, 'MEX', @sSepCampo);   
			-- PARTIES - Receptor
            SET @sRegimen = @Doc_Regimen_Fiscal_Cte;
            SET @sUsoCFDI = @Doc_UsoCFDI;
            IF ( @Doc_Recibe_RFC = 'XAXX010101000' )
            BEGIN
                SET @sRegimen = '616';
                SET @sUsoCFDI = 'S01';
            END;
            SET @uHEADER = CONCAT(@uHEADER, @sSepLinea);
            SET @uHEADER = CONCAT(@uHEADER, 'PARTIES', @sSepCampo);              
            SET @uHEADER = CONCAT(@uHEADER, 'R', @sSepCampo);              
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Recibe_RFC, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Recibe_Nombre, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_SucursalNombre, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Recibe_Calle, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Recibe_Colonia, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Recibe_Municipio, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @Doc_Recibe_Estado, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @sRegimen, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, @sUsoCFDI, @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            SET @uHEADER = CONCAT(@uHEADER, '', @sSepCampo);   
            IF ( @Doc_Recibe_RFC = 'XAXX010101000' )
            BEGIN
                SET @uHEADER = CONCAT(@uHEADER, @Doc_Expide_codigoPostal, @sSepCampo);   
            END
            ELSE
            BEGIN
                SET @uHEADER = CONCAT(@uHEADER, @Doc_Recibe_CodigoPostal, @sSepCampo);   
            END;
            SET @uHEADER = CONCAT(@uHEADER, 'MEX', @sSepCampo);                    

            IF ( @sAddenda = 'SI' )
            BEGIN

                -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
                -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
                -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
                -- 7. CABECERA DE ADDENDA. Obtiene pedido, recepcion, sucursal y datos comerciales.
                -- Este bloque se ejecuta DESPUES del detalle; no debe inicializar valores
                -- que los articulos ya necesitaban, como la orden de compra.
                DECLARE ScrHeadAddenda CURSOR LOCAL FORWARD_ONLY STATIC FOR
                SELECT 
                      '7504015884004' AS GLN_BAT,
                      T3.FN_TRIM_CFDI( CteX.X_EM_Field_5 ) AS Sucursal_EDI,
                      T3.FN_TRIM_CFDI( CteX.X_Route_Ref_1 ) AS SucursalName, 
                      T3.FN_TRIM_CFDI( CFD.Pedido ) AS Ref_Pedido,
                      T3.FN_TRIM_CFDI( CFD.Entrada ) AS Ref_Entrada,
                      T3.FN_TRIM_CFDI( CteX.X_EM_Field_5 ) AS Ref_Tienda,
                      T3.FN_TRIM_CFDI( CteX.X_EM_Field_5 ) AS Ref_Sucursal,
                      'CABADD' AS Label,
                      'OR' AS Funcion,
                      '' AS Doc_Reemplazo,
                      T3.FN_TRIM_CFDI( CFD.Pedido ) AS Pedido,
                      -- DEV-FIX ORA-04: Oracle envia estas fechas como DDMMYYYY (ejemplo: 09112026).
                      -- Convertir primero a DD/MM/YYYY completo y quitar las barras; varchar(8) recortaba el anio.
                      -- FePedido conserva la hora sin dos puntos; FeNotaEnt solo contiene la fecha.
                      CONCAT(REPLACE(CONVERT(VARCHAR(10), RF.Fecha_Factura, 103), '/', ''), REPLACE( Comp.Hora_Factura, ':', '' )) AS FePedido,
                      TRIM( CFD.Entrada ) AS NotaEnt,
                      REPLACE(CONVERT(VARCHAR(10), RF.Fecha_Factura, 103), '/', '') AS FeNotaEnt,
                      '7504015884004' AS VendedorGLN,
                      ISNULL( Addenda.Num_Proveedor, '' ) AS VendorNInt, 
                      '' AS VendorIEPS,
                      ISNULL( Addenda.GLN_Comprador, '' ) AS CompradorGLN,
                      '' AS CompradorConti,
                      '' AS CompradorNRef,
                      CteX.X_EM_Field_5 AS ReceptorGLN,
                      T3.FN_TRIM_CFDI( CteX.X_Route_Ref_1 ) AS ReceptorNombre,
                      T3.FN_TRIM_CFDI( Cte.Direccion_1 ) AS ReceptorCalle,
                      T3.FN_TRIM_CFDI( Cte.Colonia_1 ) AS ReceptorColonia,
                      '' AS ReceptorLocal,
                      T3.FN_TRIM_CFDI( Cte.Ciudad_1 ) AS ReceptorMunicip,
                      T3.FN_TRIM_CFDI( EAI_Owner.getConv( 'CFDI Estado', Cte.Estado_1 ) ) AS ReceptorEstado,
                      T3.FN_TRIM_CFDI( Cte.Pais_1 ) AS ReceptorPais, 
                      T3.FN_TRIM_CFDI( CONCAT(REPLICATE('0', 5 - LEN(Cte.Codigo_Postal_1)), CAST(Cte.Codigo_Postal_1 AS VARCHAR)) ) AS ReceptorCP,
                      'MXN' AS MonedaPrecio,
                      '1.00' AS TCambioMPR,
                      'MXN' AS MonedaPago,
                      '1.00' AS TCambioMPY,
                      'FE' AS RefPago,
                      'BT' AS CondPago,
                      ISNULL( Cte.Dias_CDTO, '0' ) AS DPago,
                      '' AS NCheque,
                      CONVERT(VARCHAR(41), CAST( RF.Valor_Subtotal AS DECIMAL(38,2) )) AS TotNeto,
                      '' AS CPredial,
                      REPLACE( PR_NUM_A_LETRAS.DinTex( RF.Valor_Subtotal + RF.Valor_IVA ) , 'M.N.', 'M. N.' ) AS TotalconLetra,
                      '' AS Folio_Aviso_Pago,                                                                                 
                      '' AS Plaza,
                      '' AS TipoProv,
                      '' AS TipoLoc,
                      '1' AS TipoBulto,
                      'true' AS CumpleReqFiscales,
                      '1' AS CantBulto,
                      '1' AS CantPedido,
                      'SI' AS PedemiProv,
                      '' AS Pedido_Vend,
                      '' AS Factura_Nota,
                      RF.Factura AS Remision,
                      '' AS DestinoBM,
                      '' AS CorreoProveedor,
                      'PD' AS TipoPedido,
                      '' AS ComplementoCE       
                FROM T3.Cliente Cte
                LEFT JOIN T3.TMD_Email CteX ON Cte.Cliente_SAP = CteX.Cliente_SAP
                INNER JOIN T3.CFDI_Addenda Addenda ON Cte.RFC = Addenda.RFC
                INNER JOIN T3.Registro_Fiscal RF ON RF.Factura = @sFactura
                INNER JOIN T3.RF_Complemento Comp ON RF.Factura = Comp.Factura
                LEFT JOIN EAI.IFC_Folios_FE CFD ON RF.Factura = CFD.Var_1
                WHERE Cte.Cliente_SAP = @sAccnt_ID
                  AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig;
                OPEN ScrHeadAddenda;
                FETCH NEXT FROM ScrHeadAddenda INTO @Inf_GLN_BAT, @Inf_Sucursal_EDI, @Inf_SucursalName, @Inf_Ref_Pedido, @Inf_Ref_Entrada, @Inf_Ref_Tienda, @Inf_Ref_Sucursal, @Inf_Label, @Inf_Funcion, @Inf_Doc_Reemplazo, @Inf_Pedido, @Inf_FePedido, @Inf_NotaEnt, @Inf_FeNotaEnt, @Inf_VendedorGLN, @Inf_VendorNInt, @Inf_VendorIEPS, @Inf_CompradorGLN, @Inf_CompradorConti, @Inf_CompradorNRef, @Inf_ReceptorGLN, @Inf_ReceptorNombre, @Inf_ReceptorCalle, @Inf_ReceptorColonia, @Inf_ReceptorLocal, @Inf_ReceptorMunicip, @Inf_ReceptorEstado, @Inf_ReceptorPais, @Inf_ReceptorCP, @Inf_MonedaPrecio, @Inf_TCambioMPR, @Inf_MonedaPago, @Inf_TCambioMPY, @Inf_RefPago, @Inf_CondPago, @Inf_DPago, @Inf_NCheque, @Inf_TotNeto, @Inf_CPredial, @Inf_TotalconLetra, @Inf_Folio_Aviso_Pago, @Inf_Plaza, @Inf_TipoProv, @Inf_TipoLoc, @Inf_TipoBulto, @Inf_CumpleReqFiscales, @Inf_CantBulto, @Inf_CantPedido, @Inf_PedemiProv, @Inf_Pedido_Vend, @Inf_Factura_Nota, @Inf_Remision, @Inf_DestinoBM, @Inf_CorreoProveedor, @Inf_TipoPedido, @Inf_ComplementoCE;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @sPedido       = @Inf_Pedido;
                    SET @sNotaEnt      = @Inf_NotaEnt;
                    SET @sVendorNInt   = @Inf_VendorNInt;
                    SET @sCompradorGLN = @Inf_CompradorGLN;

                    -- Reglas por RFC/cadena: adaptan pedido, nota de entrada y sucursal al cliente.
                    -- No generalizarlas a otros clientes sin contar con casos de prueba.
                    IF ( @Doc_Recibe_RFC = 'NWM9709244W4' )
                    BEGIN
                        IF ( @Doc_Cadena_Comercial  = '78' )  
                        BEGIN   
                            SET @sVendorNInt   = '001781012';
                            SET @sCompradorGLN = '7507003100001';                
                        END
                        ELSE IF ( @Doc_Cadena_Comercial  = 'W7' )  
                        BEGIN   
                            SET @sVendorNInt   = '472592012';
                            SET @sCompradorGLN = '7507003100001';
                        END
                        ELSE IF ( @Doc_Cadena_Comercial  = '76' )  
                        BEGIN   
                            SET @sVendorNInt   = '001781019';
                            SET @sCompradorGLN = '7507003100001';
                        END
                        ELSE IF ( @Doc_Cadena_Comercial  = '77' )  
                        BEGIN   
                            SET @sVendorNInt   = '001776640';
                            SET @sCompradorGLN = '7507003100001';
                        END
                        ELSE IF ( @Doc_Cadena_Comercial  = '75' )  
                        BEGIN   
                            SET @sVendorNInt   = '001781014';
                            SET @sCompradorGLN = '7507003100001';
                        END;   
                    END;

                    IF ( ( @Doc_Recibe_RFC = 'TSO991022PB6' ) AND ( @Doc_Cadena_Comercial  = 'M8' ) ) 
                    BEGIN   
                        SET @sVendorNInt   = '907676';
                        SET @sCompradorGLN = '7505000099632';
                    END;

                    IF ( ( @Doc_Recibe_RFC = 'TSO991022PB6' ) AND ( @Doc_Cadena_Comercial  = 'U5' ) ) 
                    BEGIN   
                        SET @sVendorNInt = '142844';
                        IF ( ( ( @sPedido IS NULL ) OR ( LEN( @sPedido ) = 0 ) ) AND ( @sNotaEnt IS NOT NULL ) ) 
                        BEGIN
                            SET @sPedido  = @sNotaEnt;
                            SET @sNotaEnt = '';       
                        END;
                    END;
                    IF ( ( @Doc_Recibe_RFC = 'TSO991022PB6' ) AND ( @Doc_Cadena_Comercial != 'U5' ) ) 
                    BEGIN
                        IF ( ( @sPedido IS NULL ) OR ( LEN( @sPedido ) = 0 ) ) 
                        BEGIN
                            SET @sPedido = '0';
                        END;   
                    END;
                    IF ( ( @Doc_Recibe_RFC = 'FGU830930PD3' ) ) 
                    BEGIN
                        IF ( ( @sPedido IS NULL ) OR ( LEN( @sPedido ) = 0 ) ) 
                        BEGIN
                            SET @sPedido = '0';
                        END;   
                        IF ( ( @sNotaEnt IS NULL ) OR ( LEN( @sNotaEnt ) = 0 ) ) 
                        BEGIN
                            SET @sNotaEnt = '0';
                        END;   
                    END;
                    IF ( ( @Doc_Recibe_RFC = 'SEM980701STA' ) ) 
                    BEGIN
                        IF ( ( @sPedido IS NULL ) OR ( LEN( @sPedido ) = 0 ) ) 
                        BEGIN
                            SET @sPedido = '0';
                        END;   
                        IF ( ( @sNotaEnt IS NULL ) OR ( LEN( @sNotaEnt ) = 0 ) ) 
                        BEGIN
                            SET @sNotaEnt = '0';
                        END;   
                    END;
                    IF ( ( @Doc_Recibe_RFC = 'TCM951030A17' ) ) 
                    BEGIN
                        IF ( ( @sNotaEnt IS NULL ) OR ( LEN( @sNotaEnt ) = 0 ) ) 
                        BEGIN
                            SET @sNotaEnt = '000000';
                        END;   
                    END;
                    -- REGLA HEREDADA: se asigna Inf_Pedido y enseguida se borra con cadena vacia.
                    -- El detalle ya se genero. Cambiar esta regla para emitir el pedido requiere
                    -- una correccion funcional separada, no solo quitar una linea repetida.
                    IF ( @Doc_Recibe_RFC = 'OSA840206MK6' ) 
                    BEGIN
                        SET @sOrdenCompra  = @Inf_Pedido;       
                        SET @sOrdenCompra  = '';               
                    END
                    ELSE 
                    BEGIN
                        SET @sOrdenCompra  = '';               
                    END;

                    SET @sStepPLSQL = 'A_HEADER';
                    SET @uCABADD = CONCAT(@uCABADD, @sSepLinea);
                    -- DEV-FIX RN-01 RESUELTO: A_HEADER conserva las 76 posiciones de Oracle, incluidas las dos vacias finales. No eliminar campos reservados ni sus separadores.
                    SET @uCABADD = CONCAT(@uCABADD, 'A_HEADER', @sSepCampo);
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_Funcion, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_Doc_Reemplazo, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @sPedido, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_FePedido, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @sNotaEnt, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_FeNotaEnt, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_VendedorGLN, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @sVendorNInt, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_VendorIEPS, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @sCompradorGLN, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CompradorConti, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CompradorNRef, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorGLN, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorNombre, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorCalle, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorColonia, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorLocal, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorMunicip, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorEstado, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorPais, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_ReceptorCP, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_MonedaPrecio, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TCambioMPR, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_MonedaPago, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TCambioMPY, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_RefPago, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CondPago, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_DPago, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_NCheque, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TotNeto, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CPredial, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TotalconLetra, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_Folio_Aviso_Pago, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_Plaza, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TipoProv, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TipoLoc, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TipoBulto, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CumpleReqFiscales, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CantBulto, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CantPedido, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_PedemiProv, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_Pedido_Vend, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_Factura_Nota, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_Remision, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_DestinoBM, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_CorreoProveedor, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, @Inf_TipoPedido, @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);          
                    -- DEV-FIX RN-01: Oracle termina A_HEADER con estas dos posiciones reservadas.
                    -- Aunque no tengan datos, cada campo necesita su | para completar 76 campos.
                    -- Campo 75: Info Pedimientos (nombre del campo en el original Oracle).
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);
                    -- Campo 76: Info Compras.
                    SET @uCABADD = CONCAT(@uCABADD, '', @sSepCampo);
                    FETCH NEXT FROM ScrHeadAddenda INTO @Inf_GLN_BAT, @Inf_Sucursal_EDI, @Inf_SucursalName, @Inf_Ref_Pedido, @Inf_Ref_Entrada, @Inf_Ref_Tienda, @Inf_Ref_Sucursal, @Inf_Label, @Inf_Funcion, @Inf_Doc_Reemplazo, @Inf_Pedido, @Inf_FePedido, @Inf_NotaEnt, @Inf_FeNotaEnt, @Inf_VendedorGLN, @Inf_VendorNInt, @Inf_VendorIEPS, @Inf_CompradorGLN, @Inf_CompradorConti, @Inf_CompradorNRef, @Inf_ReceptorGLN, @Inf_ReceptorNombre, @Inf_ReceptorCalle, @Inf_ReceptorColonia, @Inf_ReceptorLocal, @Inf_ReceptorMunicip, @Inf_ReceptorEstado, @Inf_ReceptorPais, @Inf_ReceptorCP, @Inf_MonedaPrecio, @Inf_TCambioMPR, @Inf_MonedaPago, @Inf_TCambioMPY, @Inf_RefPago, @Inf_CondPago, @Inf_DPago, @Inf_NCheque, @Inf_TotNeto, @Inf_CPredial, @Inf_TotalconLetra, @Inf_Folio_Aviso_Pago, @Inf_Plaza, @Inf_TipoProv, @Inf_TipoLoc, @Inf_TipoBulto, @Inf_CumpleReqFiscales, @Inf_CantBulto, @Inf_CantPedido, @Inf_PedemiProv, @Inf_Pedido_Vend, @Inf_Factura_Nota, @Inf_Remision, @Inf_DestinoBM, @Inf_CorreoProveedor, @Inf_TipoPedido, @Inf_ComplementoCE;
                END;
                CLOSE ScrHeadAddenda;
                DEALLOCATE ScrHeadAddenda;
            END; 

			-- Cabecera Cliente
            SET @sCABCLIE = CONCAT(@sCABCLIE, 'CABCLIE', @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Recibe_Nombre, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Remite_Calle, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Remite_Colonia, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Remite_Municipio, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, '', @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Remite_Estado, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Remite_Pais, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Remite_codigoPostal, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_pedidoV3, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_sucursalNombre, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_pedidoSAP, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_facturaSAP, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Tipo_Documento, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_CentroExpedicion, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Recibe_Cliente, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_Remite_Cliente, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_LugarExpedicion, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, '', @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @sLeyMenor, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @sLeyPriv, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @Doc_eMail, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @sSepLinea);

            SET @sCABCLIE = CONCAT(@sCABCLIE, @sCFDIREL);
            SET @sCABCLIE = CONCAT(@sCABCLIE, 'PAYMET', @sSepCampo);              
            SET @sCABCLIE = CONCAT(@sCABCLIE, @sMetodoDePago, @sSepCampo);
            SET @sCABCLIE = CONCAT(@sCABCLIE, @uCABADD);

			-- Impuestos
            -- 8. IMPUESTOS DE CABECERA. A_TAX es informacion para la addenda.
            -- Los TAX siguientes describen bases, importes y tasas del documento completo;
            -- no confundirlos con LINETAX, que describe un solo articulo.
            SET @sStepPLSQL = 'A_TAX';
            IF ( @sAddenda = 'SI' )
            BEGIN
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'A_TAX', @sSepCampo);
                SET @uIMPFAC = CONCAT(@uIMPFAC, '002', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @Doc_importe_IVA, 2 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @nTasa_LP / 100, 6 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'T', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, @sSepLinea);
                IF ( @Doc_Valor_IEPS = 0 )
                BEGIN
                    SET @uIMPFAC = CONCAT(@uIMPFAC, 'A_TAX', @sSepCampo);
                    SET @uIMPFAC = CONCAT(@uIMPFAC, '003', @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, '0.00', @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, '0.000000', @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, 'T', @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, @sSepLinea);
                END;
            END;      

            SET @sStepPLSQL = 'TAX';
            SET @nIMPFAC  = 0;
            SET @nValor_IEPS = @Doc_Valor_IEPS;
            IF ( @Doc_Valor_IEPS > 0 )
            BEGIN
                    -- DEV-NUM: no inventar un cero cuando falta una base valida para dividir.
                    IF (@Doc_Valor_Subt_IEPS IS NULL OR @Doc_Valor_Subt_IEPS = 0)
                    BEGIN
                        SET @sMsg = CONCAT('Base invalida para calcular tasa (@Doc_Valor_Subt_IEPS). Factura: ', @pFactura, '; linea: ', @Item_numLinea);
                        THROW 51001, @sMsg, 1;
                    END;
                SET @nTasa_IEPS = ROUND( @Doc_Valor_IEPS * 100 / @Doc_Valor_Subt_IEPS, 0 ); 
                SET @nIMPFAC  = @nIMPFAC + 1;  
                IF ( @sAddenda = 'SI' )
                BEGIN
                    SET @uIMPFAC = CONCAT(@uIMPFAC, 'A_TAX', @sSepCampo);
                    SET @uIMPFAC = CONCAT(@uIMPFAC, '003', @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @Doc_Valor_IEPS, 2 ), @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @nTasa_IEPS / 100, 6 ), @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, 'T', @sSepCampo);  
                    SET @uIMPFAC = CONCAT(@uIMPFAC, @sSepLinea);
                END;   
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'TAX', @sSepCampo);
                SET @uIMPFAC = CONCAT(@uIMPFAC, '003', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @Doc_Valor_Subt_IEPS, 2 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @Doc_Valor_IEPS, 2 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @nTasa_IEPS / 100, 6 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'Tasa', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'T', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);          
            END;
            IF ( @Doc_subtotal_TasaIVA > 0 )
            BEGIN 
                IF ( @nIMPFAC > 0 )
                BEGIN
                    SET @uIMPFAC = CONCAT(@uIMPFAC, @sSepLinea);
                END;      
                SET @nIMPFAC = @nIMPFAC + 1; 
				-- TAX Segment
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'TAX', @sSepCampo);
                SET @uIMPFAC = CONCAT(@uIMPFAC, '002', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @Doc_subtotal_TasaIVA, 2 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @Doc_importe_IVA, 2 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @nTasa_LP / 100, 6 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'Tasa', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'T', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);          
            END;   
            IF ( @Doc_impSubtot_TASA00 > 0 )
            BEGIN
                IF ( @nIMPFAC > 0 )
                BEGIN
                    SET @uIMPFAC = CONCAT(@uIMPFAC, @sSepLinea);
                END;   
                SET @nIMPFAC = @nIMPFAC + 1; 
				-- TAX Segment
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'TAX', @sSepCampo);
                SET @uIMPFAC = CONCAT(@uIMPFAC, '002', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @Doc_impSubtot_TASA00, 2 ), @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, '0.00', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, '0.000000', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'Tasa', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, 'T', @sSepCampo);  
                SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);          
            END;      
            FETCH NEXT FROM ScrDatos INTO @Doc_Addenda_Venta, @Doc_Addenda_Devol, @Doc_Addenda_Migrar, @Doc_Addenda_Tipo_Docto, @Doc_Ctro, @Doc_Fecha_Rollout, @Doc_Addenda_Fases, @Doc_Fecha_Documento, @Doc_Fecha_Factura, @Doc_Cadena_Comercial, @Doc_RFC_Cliente, @Doc_Factura, @Doc_versionCFDI, @Doc_Serie, @Doc_Folio, @Doc_pedidoV3, @Doc_pedidoSAP, @Doc_facturaSAP, @Doc_repVentas, @Doc_sucursalNombre, @Doc_Lista_Precio, @Doc_fecha_Reenvio, @Doc_fecha, @Doc_tipoDeComprobante, @Doc_formaDePago, @Doc_condicionesDePago, @Doc_motivoDescuento, @Doc_Descuento, @Doc_ajusteEnvio, @Doc_subTotal, @Doc_total, @Doc_ajusteIVA_DistFee, @Doc_metodoDePago, @Doc_NumCtaPago, @Doc_TipoCambio, @Doc_Moneda, @Doc_LugarExpedicion, @Doc_Emisor_RFC, @Doc_Emisor_Nombre, @Doc_Emisor_Calle, @Doc_Emisor_NoExterior, @Doc_Emisor_NoInterior, @Doc_Emisor_Colonia, @Doc_Emisor_Localidad, @Doc_Emisor_Municipio, @Doc_Emisor_Estado, @Doc_Emisor_Pais, @Doc_Emisor_CodigoPostal, @Doc_Expide_calle, @Doc_Expide_noExterior, @Doc_Expide_noInterior, @Doc_Expide_colonia, @Doc_Expide_municipio, @Doc_Expide_estado, @Doc_Expide_pais, @Doc_Expide_codigoPostal, @Doc_RegimenFiscal, @Doc_Regimen_Fiscal_Cte, @Doc_Recibe_RFC, @Doc_Recibe_Nombre, @Doc_Recibe_Calle, @Doc_Recibe_NoExterior, @Doc_Recibe_NoInterior, @Doc_Recibe_Colonia, @Doc_Recibe_Municipio, @Doc_Recibe_Estado, @Doc_Recibe_Pais, @Doc_Recibe_codigoPostal, @Doc_Remite_Calle, @Doc_Remite_Colonia, @Doc_Remite_Municipio, @Doc_Remite_Estado, @Doc_Remite_Pais, @Doc_Remite_codigoPostal, @Doc_Tipo_Documento, @Doc_Recibe_Cliente, @Doc_Remite_Cliente, @Doc_CentroExpedicion, @Doc_eMail, @Doc_ConfirmacionPAC, @Doc_UsoCFDI, @Doc_ResidenciaFiscal, @Doc_RegTributarioExt, @Doc_TipoRelacion, @Doc_ImpuestosTrasladados, @Doc_impuesto, @Doc_tasa, @Doc_importe_IVA, @Doc_importe, @Doc_subtotal_TasaIVA, @Doc_subtotal_Tasa00, @Doc_impSubtot_TASAIVA, @Doc_impSubtot_TASA00, @Doc_Valor_Subt_IEPS, @Doc_Valor_IEPS;
        END;
        CLOSE ScrDatos;
        DEALLOCATE ScrDatos;

        -- ALLOCHARGE describe el descuento total cuando existe. Se agrega al bloque
        -- de impuestos/descuentos antes de unir todos los textos.
        IF ( @nDoc_Descuento > 0 )
        BEGIN
            SET @uIMPFAC = CONCAT(@uIMPFAC, @sSepLinea);
            SET @uIMPFAC = CONCAT(@uIMPFAC, 'ALLOCHARGE', @sSepCampo);
            SET @uIMPFAC = CONCAT(@uIMPFAC, '1', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, 'Descuento', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, 'Descuento', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, T3.FN_NUM_TO_CHAR_CFDI( @nDoc_Descuento, 2 ), @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);  
            SET @uIMPFAC = CONCAT(@uIMPFAC, '', @sSepCampo);  
        END;

        -- DEV-FIX CURSOR: las pruebas LocalDB mostraron que DECLARE conserva los valores
        -- disponibles al declararlo. No moverlo al inicio: los filtros podrian ser NULL.
        -- CLOSE + DEALLOCATE permite crear otro cursor con los filtros de la siguiente fila.
        -- 9. TEXTOS ADICIONALES. Crea un LINCLIE por mensaje de la factura, ordenado
        -- por fecha de creacion y linea. Un Texto NULL deja el campo vacio sin
        -- borrar los articulos que ya contiene @uLINFAC.
        DECLARE ScrTextoAdicional CURSOR LOCAL FORWARD_ONLY STATIC FOR
        SELECT 1000 + Linea AS Linea, Texto
        FROM T3.CFDI_TEXTO_ADICIONAL
        WHERE Nota_Venta = @sFactura
        ORDER BY Created, Linea;         
        OPEN ScrTextoAdicional;
        FETCH NEXT FROM ScrTextoAdicional INTO @Info_Linea, @Info_Texto;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @nLineas = @nLineas + 1; 
            SET @uLINFAC = CONCAT(@uLINFAC, @sSepLinea);
            SET @uLINFAC = CONCAT(@uLINFAC, 'LINCLIE', @sSepCampo);
            SET @uLINFAC = CONCAT(@uLINFAC, CONVERT(VARCHAR(41), CAST( @nLineas AS DECIMAL(38,0) )), @sSepCampo);
            SET @uLINFAC = CONCAT(@uLINFAC, @Info_Texto, @sSepCampo);       
            FETCH NEXT FROM ScrTextoAdicional INTO @Info_Linea, @Info_Texto;
        END;
        CLOSE ScrTextoAdicional;
        DEALLOCATE ScrTextoAdicional;

        -- 10. COMPARAR Y GUARDAR. Exige detalle mayor a 10 caracteres y diferencias
        -- menores a 0.10 entre total esperado, detalle y formato menos descuento.
        -- Una diferencia exactamente igual a 0.10 no pasa. Esto no comprueba todos
        -- los campos obligatorios. Con un total NULL, la condicion no es verdadera
        -- y se entra a la rama de diagnostico.
        IF ( ( LEN( @uLINFAC ) > 10 ) 
          AND ( ABS( @nTotal - @nItems  ) < 0.10 ) 
          AND ( ABS( @nTotal - ( @nEDICOM - @nDescuento ) ) < 0.10 ) )
        BEGIN
            SET @nAjusteIVA_DistFee = @nDoc_Total - @nTotal;   
            -- DEV-NUM: AJUSTE decimal(5,2) admite de -999.99 a 999.99.
            -- Validarlo antes de ambos INSERT de salida evita guardarlos con un ajuste invalido.
            -- No hay transaccion: esto no revierte escrituras anteriores del procedimiento.
            IF (@nAjusteIVA_DistFee IS NULL OR ABS(@nAjusteIVA_DistFee) > 999.99)
            BEGIN
                SET @sMsg = CONCAT('Ajuste NULL o fuera del rango decimal(5,2). Factura: ', @pFactura);
                THROW 51003, @sMsg, 1;
            END;
            -- Orden final: cabecera, datos comerciales, impuestos y detalle.
            -- @sSepLinea es CR+LF (CHAR(13)+CHAR(10)); separa los bloques del texto.
            SET @sData = @uHEADER;
            SET @sData = CONCAT(@sData, @sSepLinea, @sCABCLIE);
            SET @sData = CONCAT(@sData, @sSepLinea, @uIMPFAC);
            SET @sData = CONCAT(@sData, @sSepLinea, @uLINFAC);
            
            -- PENDIENTE S03: CONCAT evita perder el texto, pero no comprueba que la cabecera contenga todos los datos obligatorios.
            INSERT INTO T3.CFDI_DOCUMENTOS_ENVIAR ( Nota_Venta, Informacion )
            VALUES ( @pFactura, @sData );
            
            -- Registra liberacion, centro y metodo para el proceso posterior.
            -- Este INSERT no timbra por si mismo el documento.
            INSERT INTO T3.CFDI_Documentos ( Nota_Venta, Ctro, Fecha_Liberacion, Metodo_Pago )
            VALUES ( @pFactura, @sCtro, GETDATE(), @sMetodoDePago );      
            
            -- Guarda la diferencia entre total calculado de salida y total esperado
            -- con signo invertido. Es distinto de la tolerancia del IF anterior.
            -- Diferencia calculada y validada antes de guardar el documento.
            IF ( @nAjusteIVA_DistFee != 0 )
            BEGIN
                -- DEV-NUM: rango AJUSTE comprobado antes de guardar las salidas.
                INSERT INTO T3.CFDI_Agrupado_DIF ( Nota_VENTA_CFDI, Ajuste, Fecha )
                VALUES ( @pFactura, @nAjusteIVA_DistFee * -1, GETDATE() );    
            END;      
        END
        ELSE         
        BEGIN         
            INSERT INTO T3.RF_ERROR_LOG 
               ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
            VALUES
               ( GETDATE(), 'GENERAR_MX06', @pFactura, CONCAT('Doc=>', CAST(@nTotal AS VARCHAR), ' vs Items=> ', CAST(@nItems AS VARCHAR), ' vs EDICOM=> ', CAST(@nEDICOM AS VARCHAR), ', ', CAST(@nDescuento AS VARCHAR)) );
            
            -- PENDIENTE C06: al fallar la comparacion se llega aqui sin haber construido @sData. Por eso este INSERT guarda Informacion NULL.
            INSERT INTO T3.CFDI_DOCUMENTOS_ENVIAR_ADD ( Nota_Venta, Informacion )
            VALUES ( @pFactura, @sData );            
        END;      

    END TRY
    -- DECISION DE DISENO: MSSQL no administra transacciones propias. No agregar BEGIN TRAN, COMMIT ni ROLLBACK para imitar Oracle.
    -- 11. ERRORES. CURSOR_STATUS >= 0 indica cursor abierto; -1, cerrado pero
    -- aun declarado. Solo se cierra/libera cuando corresponde, para que la
    -- limpieza no genere un segundo error. Despues se imprime y guarda el mensaje.
    -- COMPORTAMIENTO ACTUAL: no se hace THROW y, por diseno, tampoco ROLLBACK. El error no se relanza al
    -- llamador y esta rutina no garantiza revertir escrituras previas.
    BEGIN CATCH
        IF CURSOR_STATUS('local','ScrDatos') >= 0 BEGIN CLOSE ScrDatos; DEALLOCATE ScrDatos; END ELSE IF CURSOR_STATUS('local','ScrDatos') = -1 DEALLOCATE ScrDatos;
        IF CURSOR_STATUS('local','ScrDetalle') >= 0 BEGIN CLOSE ScrDetalle; DEALLOCATE ScrDetalle; END ELSE IF CURSOR_STATUS('local','ScrDetalle') = -1 DEALLOCATE ScrDetalle;
        IF CURSOR_STATUS('local','ScrHeadAddenda') >= 0 BEGIN CLOSE ScrHeadAddenda; DEALLOCATE ScrHeadAddenda; END ELSE IF CURSOR_STATUS('local','ScrHeadAddenda') = -1 DEALLOCATE ScrHeadAddenda;
        IF CURSOR_STATUS('local','ScrItemAddenda') >= 0 BEGIN CLOSE ScrItemAddenda; DEALLOCATE ScrItemAddenda; END ELSE IF CURSOR_STATUS('local','ScrItemAddenda') = -1 DEALLOCATE ScrItemAddenda;
        IF CURSOR_STATUS('local','ScrPedimento') >= 0 BEGIN CLOSE ScrPedimento; DEALLOCATE ScrPedimento; END ELSE IF CURSOR_STATUS('local','ScrPedimento') = -1 DEALLOCATE ScrPedimento;
        IF CURSOR_STATUS('local','ScrReenvio') >= 0 BEGIN CLOSE ScrReenvio; DEALLOCATE ScrReenvio; END ELSE IF CURSOR_STATUS('local','ScrReenvio') = -1 DEALLOCATE ScrReenvio;
        IF CURSOR_STATUS('local','ScrTextoAdicional') >= 0 BEGIN CLOSE ScrTextoAdicional; DEALLOCATE ScrTextoAdicional; END ELSE IF CURSOR_STATUS('local','ScrTextoAdicional') = -1 DEALLOCATE ScrTextoAdicional;
        IF CURSOR_STATUS('local','ScrAllocation') >= 0 BEGIN CLOSE ScrAllocation; DEALLOCATE ScrAllocation; END ELSE IF CURSOR_STATUS('local','ScrAllocation') = -1 DEALLOCATE ScrAllocation;

        SET @sMsg = SUBSTRING(CONCAT(CAST(ERROR_NUMBER() AS VARCHAR), '-', ERROR_MESSAGE()), 1, 250);
        -- Esta asignacion sustituye el texto anterior por solo ERROR_MESSAGE.
        -- El numero de error agregado arriba no permanece en el mensaje guardado.
        SET @sMsg = SUBSTRING(ERROR_MESSAGE(), 1, 250);

        PRINT '--------------------------------------------------------------------------------';
        PRINT 'Problemas en la ejecucion del Procedimiento';
        PRINT 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :';
        PRINT 'Procedimiento : PROC_V40_GENERAR_MX06AD_CORREGIDO';
        PRINT CONCAT('Fecha         : ', CONVERT(VARCHAR, GETDATE(), 120));
        PRINT CONCAT('Referencia    : ', ISNULL(@strID, ''));
        PRINT CONCAT('Secuencia     : ', ISNULL(@sStepPLSQL, ''));
        PRINT CONCAT('Error         : ', ISNULL(@sMsg, ''));
        PRINT '--------------------------------------------------------------------------------';

        INSERT INTO T3.RF_ERROR_LOG ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
        VALUES ( GETDATE(), 'PROC_V40_GENERAR_MX06AD_CORREGIDO', @strID, @sMsg );

    END CATCH;
END;

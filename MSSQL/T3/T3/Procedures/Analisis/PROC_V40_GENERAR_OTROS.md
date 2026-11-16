# Analisis de T3.PROC_V40_GENERAR_OTROS

Revision del 29/10/2026 del [procedimiento SQL Server](../PROC_V40_GENERAR_OTROS.sql)
y de sus dependencias disponibles en el repositorio. La primera intervencion
agrego comentarios sin cambiar instrucciones ejecutables. Posteriormente se
preparo la correccion puntual del overflow reportado a las 14:50:26-27:
VARCHAR(40) para la tasa y conversion decimal antes de dividir entre 100.0.
El [paquete de correccion](../../../Diagnosticos/OTROS_Overflow_20261029/README.md)
incluye diagnostico, despliegue y reversion. No se ejecuto ni se altero el
modulo instalado en T3QA.

## Proposito y contrato

Recibe @pFactura VARCHAR(MAX), sin valor predeterminado, y prepara un layout
de facturacion para documentos de OTROS. La version de cabecera es la constante
4.0. El resultado normal son dos INSERT: texto en T3.CFDI_DOCUMENTOS_ENVIAR y
registro de liberacion en T3.CFDI_DOCUMENTOS con Ctro='CTRL'.

No entrega OUTPUT ni SELECT de negocio. No valida inicialmente NULL, vacio,
longitud o existencia de @pFactura; copia la referencia a @strID VARCHAR(30)
para salidas y errores. No genera PID ni RF_PROCESOS_LOG, no marca la factura
como procesada, no envia directamente al PAC y no confirma timbrado.

Se encontraron dos llamadores:

- PROC_T3_OT_GENERAL: compara cabecera/detalle con tolerancia <0.10, llama a
  este generador y despues marca Fecha_Proc_BATMD sin verificar sus INSERT.
- WA_REENVIO_EDICOM_OTROS: administra historial, borra salidas anteriores y
  ajusta Hora_Factura antes de llamar a este generador. Esas acciones pertenecen
  al llamador; el generador no las repite ni hace una sustitucion idempotente.

No se encontro una contraparte Oracle independiente con este nombre para
certificar paridad; el analisis describe el SQL Server recibido.

## Dependencias y efectos

| Objeto | Uso directo |
|---|---|
| T3.OTROS_GENERAL | Cabecera, sociedad/RFC, montos, clase, moneda y domicilio. |
| T3.RF_COMPLEMENTO | Hora_Factura y contexto obligatorio para cabecera/addenda. |
| EAI.ZSDFE_SOC | Emisor obligatorio: Sociedad debe coincidir con BUKRS y KUNNR. |
| T3.CFDI_RFC_SETTING | MAX(Valor) por RFC/parametro para datos fiscales, pagos y comercio exterior. |
| EAI_OWNER.TMP_DOCUMENT_PARTNERS | Datos opcionales Sold_to_* unidos por Factura=ReferenceID. |
| T3.OTROS_DETALLE | Todos los items de la referencia, con importes y leyendas. |
| T3.CFDI_PRODSERV | Descripcion de facturacion, fraccion y factor arancelarios para Modulo EXPO. |
| T3.OTROS_CONDICIONES | Retencion ZDD6; cursor de otras condiciones que no se abre. |
| T3.CFDI_REPROCESO | Historial de UUID para segmentos BILLREF. |
| T3.CFDI_DOCUMENTOS_ENVIAR | INSERT de Nota_Venta=@strID e Informacion=layout completo. |
| T3.CFDI_DOCUMENTOS | INSERT de Nota_Venta, CTRL y Fecha_Liberacion. |
| T3.RF_ERROR_LOG | Rechazos y excepciones, sin relanzamiento propio. |

Funciones llamadas: EAI_OWNER.GETCONV, T3.FN_TRIM_CFDI,
T3.FN_NUM_TO_CHAR_CFDI, T3.FN_USD_TCAMBIO, T3.FN_CFDI_SERVICIOS y
T3.FN_CFDI_SKU_NAME. El fuente contiene una referencia comentada a
PR_NUM_A_LETRAS; no es una llamada ejecutable.

GET_SAT_CLAVEPRODUCTO se llama por cada item con tipo EXPO, Factura, Material,
descripcion y unidad; recibe producto y unidad mediante OUTPUT. Su fuente
local puede INSERTAR un mapeo nuevo en CFDI_PRODSERV si no encuentra material
y este no empieza por R. No es una funcion de consulta pura. Para EXPO sin
coincidencia termina devolviendo claves vacias, y su CATCH escribe en
MX_EAI_MESSAGE_LOG con QUEUE_NAME='GET_SAT_CLAVEPRODUCTO', sin THROW.

## Cursores y contrato posicional

| Cursor | Columnas SELECT | Variables de cada FETCH | Papel |
|---|---:|---:|---|
| ScrDatos | 95 | 95 y 95 | Cabecera, emisor/receptor, impuestos y datos fiscales. |
| ScrDetalle | 23 | 23 y 23 | Items, mapeo, impuestos y leyendas. |
| ScrCondiciones | 12 | Sin FETCH | Declarado y desasignado; no se abre. |
| ScrHeadAddenda | 56 | 56 y 56 | Addenda/comercio exterior si Complemento_CE=CCE. |
| ScrReenvio | 2 | 2 y 2 | Todos los reprocesos de la referencia por Fecha DESC. |

LOCAL limita alcance y STATIC toma una fotografia en cada OPEN. Son
fotografias separadas: no garantizan un unico corte consistente entre
cabecera, detalles y consultas adicionales. No hay reserva exclusiva de factura.

ScrDetalle conserva en su declaracion la repeticion FORWARD_ONLY STATIC
FORWARD_ONLY STATIC del archivo original. No se cambio dentro de esta tarea.
ScriptDom acepta el texto; no se hizo una compilacion contra el motor instalado.

El SELECT y ambos FETCH de cada cursor deben cambiarse conjuntamente.
El orden de detalle se numera con ROW_NUMBER sobre ORDER BY (SELECT NULL),
por lo que no garantiza el orden del NUM_LINEA original. ScrReenvio si ordena
por Fecha DESC, pero no deduplica UUID ni limita al mas reciente.

## Recorrido y reglas

1. Consulta Sociedad-RFC de la factura. Para MX10-XEXX010101000 usa siete dias
   de desplazamiento hacia atras; en los demas casos usa cero. Afecta la fecha
   de factura y la fecha actual de reenvio, no la seleccion de un lote.
2. Inicializa acumuladores/buffers VARCHAR(MAX), separador de campos | y CRLF
   entre segmentos. La leyenda de menores inicial se vacia y despues recibe
   Observaciones; la leyenda de privacidad final es bilingue.
3. Lee CFDI_REPROCESO y agrega BILLREF por cada UUID con tipo de relacion 04.
   No modifica el historial ni cancela documentos anteriores.
4. Abre ScrDatos. Requiere coincidencias en RF_COMPLEMENTO y ZSDFE_SOC;
   sin ellas no construye la cabecera. No filtra Fecha_Proc_BATMD ni cancelacion.
5. Construye HEADER y PARTIES. La lista de clases declarada produce ingreso I;
   el ELSE produce egreso E. Existe otra lista paralela para FACTURA/NOTA DE
   CREDITO que debe mantenerse coherente.
6. Si hay reprocesos usa fecha actual ajustada; si no, fecha de factura ajustada
   mas Hora_Factura. La serie combina Sociedad y anio original de factura.
7. Para RFC extranjero generico asigna exportacion 02 con CCE o 03 sin CCE;
   para otros RFC emite 01. Esa codificacion no valida la operacion fiscal real.
8. Complemento_CE=CCE activa @sAddenda='SI', CABADD y C_COMEXT. Incluye
   constantes de lugar/emisor, Incoterms, residencia, identificador fiscal y
   tipo de cambio. No se valida el contenido completo contra catalogos SAT.
9. Construye TAX de traslado y retenciones positivas ZDD6/Retencion_IVA.
10. Abre ScrDetalle. Suma subtotal+IVA en @nItems con escala de dos decimales.
    Resuelve producto SAT y, si SAT_ProdID del item tiene longitud >3, lo usa
    como prioridad. La unidad emitida en LINE proviene de GETCONV('CFDI SAT UM',
    UnidadMedida), no de @sSAT_UM devuelta por el helper.
11. Emite LINE, LINETAX y, si aplica, C_MERC y LINCLIE. IVA no positivo produce
    importe/tasa cero de traslado; retencion positiva agrega calificador R.
12. Prioriza leyenda ES no NULL. Solo si es NULL considera EN, con longitud >2
    y centro distinto de EXPO. Una cadena ES vacia no activa ese fallback.
13. Sin CCE, Incoterms con longitud recortada >2 se agrega como leyenda.
    CABCLIE/PAYMET se construyen con el contexto de cabecera; MX15 omite los
    codigos de cliente. Moneda distinta de MXN agrega OTCUR.
14. Ensambla, valida longitud/totales e inserta las dos salidas o registra
    el rechazo. Desasigna los cursores; en excepcion limpia y registra.

## Estructura del texto de salida

El orden de ensamble es:

1. HEADER y PARTIES acumulados en @uHEADER.
2. CABCLIE, BILLREF, PAYMET y CABADD acumulados en @sCABCLIE.
3. TAX y OTCUR acumulados en @uIMPFAC.
4. LINE, LINETAX y LINCLIE acumulados en @uLINFAC.
5. C_COMEXT y C_MERC acumulados en @uCOMEXT.

Los comentarios existentes indican posiciones dentro de cada segmento.
No deben agregarse/quitarse campos por conveniencia sin revisar el contrato
del consumidor. ISNULL preserva la concatenacion pero puede producir campos
requeridos vacios; no es una validacion fiscal.

## Datos y configuracion necesarios

- Cabecera y todos sus detalles por Factura; RF_COMPLEMENTO con Hora_Factura.
- Emisor con Sociedad=BUKRS=KUNNR y datos fiscales completos.
- CFDI_RFC_SETTING por RFC: RegimenFiscal, UsoCFDI, UsoCFDI_Credito, Nombre,
  FormaPago, MetodoPago y CodigoPostal. Las entradas CE_NIF, CE_CP, CE_Estado
  y CE_Ciudad se buscan usando Clte_Factura_SAP en la columna RFC.
- GETCONV, tipo CFG Settings: Forma Pago, Metodo Pago, Regimen Fiscal,
  Regimen Fiscal Cliente, UsoCFDI_Comercial, UsoCFDI_ImportExport y
  UsoCFDI_ImportExport_NC. Tambien CFDI Estado, CFDI Pais y CFDI SAT UM.
  En el GETCONV local, faltar equivalencia conserva el texto de entrada;
  no debe interpretarse como una configuracion valida por defecto.
- CFDI_PRODSERV para producto, descripcion y fraccion/factor EXPO.
- Funciones de cambio USD/centro y sus dependencias efectivas instaladas.
- Partners opcionales del esquema EAI_OWNER; los permisos deben permitir esa
  lectura en el contexto real del llamador/job.

## Validacion final, bitacoras y limites

Se exigen LEN(@sReturn)>10, LEN(@uLINFAC)>10 y ABS(@nTotal-@nItems)<0.50.
El valor exacto 0.50 se rechaza. @nTotal conserva subtotal+IVA de la ultima
cabecera leida; no equivale al total HEADER, que descuenta retenciones.
@nItems suma los importes recibidos por item, no las lineas del cursor de
condiciones, que nunca se abre. La precision de dos decimales puede influir
en el resultado frente a las columnas monetarias originales de siete decimales.

En rechazo escribe RF_ERROR_LOG con RUTINA='GENERAR_OTROS' y el texto
Doc=>total vs Items=>total. Ese texto se usa tambien si la falla fue longitud
de buffers: no informa necesariamente el motivo completo.

En CATCH escribe RUTINA='PROC_CFDI_GENERAR_OTROS', nombre historico distinto
del modulo V40. La segunda asignacion de @sMsg reemplaza numero-mensaje por
solo mensaje. @sStepPLSQL se asigna pero no se concatena al error; no permite
ubicar por si sola el segmento fallido. Si el INSERT de error termina, no hay
THROW y el llamador puede continuar; si falla la bitacora, ese error se propaga.

No hay transaccion propia: en autocommit puede persistir el layout si falla
el INSERT del documento. No hay NOT EXISTS, borrado previo ni validacion de
salida existente: repetir la llamada puede duplicar filas. La entrega no
acredita respuesta de EDICOM, envio, UUID ni timbrado.

Otros puntos de mantenimiento:

- Los JOIN pueden producir varias cabeceras. Los buffers no se reinician por
  cada una y algunas variables quedan con los valores de la ultima fila.
  @sAddenda tampoco vuelve a NO entre cabeceras; no debe suponerse unicidad.
- MAX(Valor) y los MAX separados del catalogo no identifican una version
  temporal ni una misma fila de origen.
- @Doc_tasa es VARCHAR(100). Se corrigio su conversion inicial de VARCHAR(10)
  a VARCHAR(40), porque la tasa calculada conserva doce decimales y 16 se
  representa como 16.000000000000. Tambien se convierte explicitamente a
  DECIMAL(38,12) antes de dividir entre 100.0. El defecto se reprodujo en
  LocalDB; falta validar las seis facturas reales en T3QA.
- NULLIF protege denominadores de tasas/factores/tipo USD; el resultado NULL
  puede transformarse en campo vacio, sin que se rechace por ese motivo.
- @nEnajenado se inicializa a cero y no se incrementa; @sUsoCFDI y otros
  contextos heredados se asignan sin efecto posterior en el texto.
- El PRINT 'a' es depuracion heredada por cada cabecera, no evidencia de exito.
- @strID VARCHAR(30) limita la referencia de salida aunque @pFactura sea MAX.
- No se valida que los datos concatenados carezcan del separador | o de saltos
  de linea; debe respetarse el contrato del layout al alimentar los textos.

## Verificacion de la primera intervencion de documentacion

- TSql160Parser: cero errores antes y despues.
- 14669 tokens ejecutables identicos, comparando tipo/texto y excluyendo
  comentarios, espacios y fin de archivo.
- Se comprobaron mediante AST los conteos SELECT/FETCH de los cinco cursores.
- Se conservaron USE T3QA, ALTER PROCEDURE, opciones SET, UTF-16 LE con BOM
  y saltos CRLF. No se modificaron los llamadores ni las dependencias.
- Respaldo: tmp/proc_v40_generar_otros_comentarios_20261029/
  PROC_V40_GENERAR_OTROS.antes.sql desde la raiz del repositorio.
- SHA-256 del respaldo:
  203fda21333735548d3e80218dfb797e8c1f3c7d5450f6d0bc9cd0c66fa14dbe.
- Evidencia: tmp/proc_v40_generar_otros_comentarios_20261029/VALIDACION.txt.

La validacion sintactica no sustituye una compilacion contra los objetos de
T3QA ni una prueba fiscal. No se ejecuto el procedimiento ni se generaron
documentos para esta tarea; los puntos de atencion quedan documentados para
una revision funcional posterior.

La correccion posterior de dos expresiones tiene su propio respaldo,
diagnostico, prueba de parche y reversion en
MSSQL/T3/Diagnosticos/OTROS_Overflow_20261029. Las pruebas de documentacion
anteriores corresponden al estado previo a esa correccion.

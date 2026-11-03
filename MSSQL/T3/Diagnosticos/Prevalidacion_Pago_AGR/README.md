# Prevalidacion de PROC_CFDI_PROCESA_PAGO_AGR con @nDias=30

Analisis del codigo local el 28/10/2026. No se ejecuto el SP ni se consulto T3QA.
Los archivos instalados pueden diferir. No basta que EXEC termine sin error:
los CATCH registran errores sin relanzarlos y no hay transaccion integral.

## Orden de revision

1. Ejecutar `01_OBJETOS_Y_CONFIGURACION.sql` en T3QA. Revisar objetos ausentes,
   errores al resolver dependencias, secuencias y configuracion. El script no
   consume secuencias ni ejecuta los modulos inspeccionados.
2. Con los objetos disponibles, ejecutar `02_DATOS_30_DIAS.sql`. Usa solo
   temporales para simular la asignacion central y agrupar candidatos. Puede
   leer bastante historico para detectar detalles fuera de los 30 dias.
3. Resolver hallazgos y verificar la version instalada antes de ejecutar:
   `EXEC T3.PROC_CFDI_PROCESA_PAGO_AGR @nDias = 30;`

## Entrada y ventana

Unico parametro: @nDias NUMERIC, valor 30. Con fecha de servidor 28/10/2026,
el filtro es Fecha_Proceso > 28/09/2026 00:00:00, no Fecha_Pago ni BATMD.
No hay limite superior: tambien admite fechas futuras. La fecha efectiva usa
GETDATE del servidor. No confundir con el reloj del equipo cliente.

## Bloqueos encontrados en el fuente

- Generador PROC_V20_GENERAR_PAGO_AGR: usa RS.Razon_Social pero el subquery RS
  define MAX(Valor) AS Nombre. Es una referencia de columna inconsistente.
- Ese generador usa Alm.State; el DDL local de DISTRIBUIDOR_FISCAL solo contiene
  ESTADO. Verificar columnas y modulo instalados.
- SEQ_CFD y SEQ_PAGO_CENTRAL_AGR se usan sin esquema. Confirmar resolucion a T3.
  EAI_OWNER.ProcessID es otra secuencia, usada por el proceso 614.
- PID usa NUMERIC(8,0): los valores generados de SEQ_CFD/ProcessID deben caber
  en ocho digitos. Agrupacion usa diez. Cantidad_Pagos admite hasta 9999 e
  Importe del control DECIMAL(15,2). Inicio de secuencia no debe colisionar
  con controles ni detalles existentes; current_value no es siempre el
  siguiente valor (especialmente si aun no se ha consumido la secuencia).
- Agrupacion SI se agrega a #Grupos con ALTER TABLE antes del UPDATE. Aun asi,
  es preferible definirla al crear la temporal para evitar cambios de esquema.

## Datos requeridos por etapa

### Preparacion (109)

CFDI_Cobranza: Fecha_Envio NULL, Created_By no NULL/distinto de INTERFACE,
Via_Pago no NULL/fuera de 01, CM, AI; Status no Debit Note ni Canc Pago;
RFC no NULL/distinto de XAXX010101000; Fecha_Proceso posterior al limite;
Factura no presente en WA_Factoraje. No llama FN_VALIDA_RFC.

Agrupa por dia de Fecha_Pago, RFC, Via_Pago (NA -> 03), banco, cuenta y
Asignacion_Central. Necesita fechas/IDs/importes coherentes, cliente y cuenta
identificables. MAX(Cliente_SAP) y MAX(Accnt_ID) no aseguran un mismo cliente.

TMP_ACCOUNT_HEADER y REGISTRO_FISCAL sirven para completar Asignacion_Central:
ClearingDocNumber = SUBSTRING(Asignacion_ID,3,10), FiscalYear del anio actual,
Factura coincidente; Assignment debe superar las exclusiones de Entrega,
Referencia, B001 - Bank I, Factura+',', y prefijo 1-1. No tener coincidencia
no bloquea el SP, pero agrupa NULL como NoAsigna. Multiples coincidencias
pueden volver indeterminada la asignacion.

### Liberacion (614) y CHECK

CFDI_Agrupacion_CTRL: Fecha_Pago >= 01/01/2022, Fecha_Envio NULL y Accnt_ID
no NULL/distinto de Contado. VersionCFDI debe resultar exactamente 4.0:
MAX(Valor) por RFC en CFDI_RFC_SETTING; fallback GETCONV.

CHECK relaciona AGRUPACION_PAGO -> COBRANZA por Asignacion_ID -> DOCUMENTOS
por Nota_Venta. Exige conteo positivo y todos los UUID_Venta con LEN > 20.
Ese criterio no valida el formato UUID. Si UUIDs positivos = filas PUE con
Fecha_Asignacion y Fecha_Factura del mismo dia, marca Contado y devuelve -1.
No ejecutar CHECK como diagnostico: SI actualiza datos.
Duplicados multiplican conteos y filas; INNER JOIN puede ocultar faltantes.

### Generador agrupado

- MOV_CLIENTE por Cliente_SAP del control: RFC, nombre, direcciones fiscales,
  pais, estado y codigos postales. Confirmar RFC coherente con el agrupado.
- EAI.ZSDFE_SOC: BUKRS='MX16' y KUNNR='MX16', con datos completos del emisor.
  Es un INNER JOIN: sin coincidencia no se construye la cabecera.
- TMD_EMAIL y DISTRIBUIDOR_FISCAL son LEFT JOIN: pueden faltar sin excluir
  la fila, pero duplicados pueden multiplicar cabeceras.
- CFDI_RFC_SETTING: VersionCFDI, RegimenFiscal, Nombre y CodigoPostal;
  MAX textual selecciona valores, no la configuracion mas reciente.
- GETCONV / MX_HASHTABLE, Type='CFG Settings': VersionCFDI, Regimen Fiscal,
  Regimen Fiscal Cliente, UsoCFDI_Payment, Payment Default Time,
  Banco Def - Central, Cuenta Def - Central, Metodo Pago. Configurar valores
  aprobados para el negocio; GETCONV devuelve Source si falta una equivalencia.
  Tambien necesita equivalencias Type='CFDI Estado' para los estados usados.
- FN_CTRO_EDICOM_PAGO (fallback MXAB), FN_TRIM_CFDI, FN_NUM_TO_CHAR_CFDI y
  SeparaDireccion: definiciones productivas y sus propias dependencias.
  No se encontraron sus implementaciones de negocio en el repositorio;
  las funciones ficticias de tests NO sirven para generar comprobantes.
- Detalle por Asignacion_ID: Factura con guion y ambas partes, UUID,
  Numero_Pago, Saldo_Anterior e Importe consistentes. Sin guion, SUBSTRING
  recibe longitud negativa. Evitar saldo final negativo no justificado.
- Impuestos: REGISTRO_FISCAL por Factura, REGISTRO_FISCAL_DETALLE y
  CFDI_USOCFDI_CLIENTE por RF.Cliente_SAP. El denominador de prorrateo
  (bases 16/0 + IVA16 + IEPS) debe existir y ser distinto de cero.
  Cero causa division por cero; ausencia puede propagar NULL a importes.
- CFDI_REPROCESO: opcional para comprobantes relacionados; revisar historico
  por referencia. El generador guarda @pFactura NUMERIC(22,2) en Nota_Venta
  VARCHAR: verificar la representacion resultante (posible sufijo .00) al
  conciliar, en lugar de asumir un ID entero en texto.

## Alcance y riesgos funcionales

- El detalle omite el filtro de Fecha_Proceso. Puede incluir cobranzas
  antiguas que no forman parte de SUM/COUNT del control ni del marcado final.
- El marcado se hace por Asignacion_ID; IDs repetidos pueden afectar mas filas.
- El control se genera aunque Accnt_ID NULL luego lo excluya del liberador.
- El liberador procesa TODOS sus pendientes elegibles, no solo los nuevos;
  revisar controles previos y sus datos con los mismos requisitos del generador.
- Fecha_Pago NULL puede crear cabecera sin detalle; Fecha_Pago antigua puede
  crear control que nunca entra a 614. No es una validacion fiscal estricta.
- Cabecera del generador VARCHAR(4000) y relaciones VARCHAR(2000): no confundir
  con el caso anterior del generador individual. Los detalles agrupados y el
  resultado final son MAX, pero los buffers internos aun pueden truncarse.
- No hay proteccion contra dos ejecuciones simultaneas. Revisar job 668 y
  actividad real; Status del componente por si solo no bloquea concurrencia.
- Usar opciones de sesion compatibles con indices calculados/filtrados:
  ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT,
  CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON; NUMERIC_ROUNDABORT OFF.
  Revisar tambien opciones persistidas de modulos y permisos efectivos.

## Evidencia de exito

Proceso 109: controles, detalle e importes conciliados; Proceso_1=grupos,
Proceso_2=filas de detalle, Proceso_4=30. Proceso 614: cierre y componente 1,
sin errores en RF_ERROR_LOG/MX_EAI_MESSAGE_LOG; control con Fecha_Envio y Ctro,
documento/layout por referencia, contenido completo e importes correctos.
Generacion no acredita timbrado: comprobar posteriormente UUID y Fecha_Timbre.
Guardar baseline de controles y salidas antes de correr. No se puede garantizar
exito solo con revision estatica o metadatos; hace falta la salida de consultas.

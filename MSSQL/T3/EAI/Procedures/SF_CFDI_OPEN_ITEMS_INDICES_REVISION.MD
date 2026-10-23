# Revision del inventario recibido, 9 de octubre de 2026

Origen: resultados pegados al final de SF_CFDI_OPEN_ITEMS_DIAGNOSTICO.SQL; T3QA, compatibilidad 160, captura 10:43:27 -06:00. No se consulto el servidor directamente.

## Primera prueba: dos indices

| Tabla / filas aproximadas | Evidencia | Propuesta |
|---|---|---|
| Factura_General / 25,289,742 | FG_IDX_2 tiene solo Fecha_Factura; FACTURA_PK solo Factura. Ambos activos. | (Tipo_Docto,Fecha_Factura) INCLUDE(Factura,Cliente_SAP,Ctro). |
| Factura_Detalle / 91,612,849 | FACTURA_INDX tiene solo Factura; FACTDET_PK contiene Factura,Num_Linea. Ninguno incluye importes. | (Factura) INCLUDE(Valor_Subt,Valor_IVA,Credito_Subt,Credito_IVA,Envio_Subt,Envio_IVA). |

El problema no es ausencia de cualquier indice por fecha/folio. Falta cobertura de las columnas que lee esta etapa. Estos indices pueden evitar accesos adicionales a la tabla para obtenerlas y permitir recorridos mas estrechos. Sin plan real no se afirma que hoy existan millones de RID Lookup, ni que SQL Server vaya a elegir necesariamente un Seek. Con muchas filas elegibles puede elegir un Scan adecuado.

El archivo SF_CFDI_OPEN_ITEMS_INDICES_SELECCIONADOS.SQL contiene estos dos indices, con vista previa por defecto (@Aplicar=0). Ejecutarlo primero en la base objetivo, revisar BaseActual y luego cambiar @Aplicar=1 para crearlos en una ventana adecuada. No requiere cambiar el procedimiento. Revisa indices equivalentes por columnas y orden antes de crear; no elimina los existentes. La construccion del indice sobre 91.6 millones de detalles puede consumir tiempo, disco y log, y bloquear otras operaciones. No se impone ONLINE porque no se verificaron edicion ni condiciones de soporte.

## Propuestas descartadas o pospuestas

| Propuesta inicial | Decision y evidencia |
|---|---|
| Open Items por Nota_Venta | Descartar: CFDI_OPEN_ITEMS_IX ya tiene esa clave. |
| Cliente por SAP/vigencia | Descartar: IX_Cliente_SAP_Vigencia e IX_Ventas_Cliente_SAP_Vigencia ya cubren fechas y RFC. |
| PAC por Nota_Venta | Descartar: IX_Ventas_PAC_NotaVenta incluye Nota_Venta_CFDI. Evitar otro indice sobre 73,193,103 filas. |
| Documentos por Nota_Venta | Descartar para etapa 10: IX_Ventas_CFDI_NotaVenta incluye Folio_Fiscal. No incluye Metodo_Pago, pero esa columna no se usa en esta etapa; no crear otro por ese motivo sin medir etapas posteriores. |
| Cobranza por Factura y Nota_Credito, incluyendo Importe | Segunda prueba si cobranza sigue dominando. CFDI_COBRANZA_IDX5 y IDX4 ya buscan por esas claves pero no incluyen Importe. IX_Ventas_Cobranza_IncobrableNC es filtrado a INCOBRABLE/AI y no cubre la cobranza general. Tabla: 56,097,158 filas. |
| Preventa_General por clase/fecha | Posponer hasta medir. PG_IDX_2 solo tiene fecha. IX_PG_C005 empieza por Clase_Factura,Cliente_SAP,Fecha_Factura: su segunda clave no es fecha y no cubre todos los filtros de procesamiento/cancelacion. |
| Preventa_Detalle por Factura con importes | Posponer hasta medir. FACTURA_IDX existe, sin importes incluidos; 9,036,941 filas. |
| Factura/Preventa por Factura para cliente facturado | Posponer: FACTURA_PK y PREVG_PK ya permiten buscar el folio; falta cobertura de clientes, pero solo agregarla si etapa 90 es costosa. No introducir filtro temporal en esa etapa. |

No se eliminan indices existentes para incorporar INCLUDE: primero medir la mejora y luego revisar consolidacion con dependencias y uso de otros procesos. Los nombres *_PK del inventario no bastan para afirmar si son restricciones PRIMARY KEY; la captura no incluye esa propiedad.

## Estadisticas y bloqueos

- La captura de solicitudes activas esta vacia. No prueba ausencia de bloqueos durante la ejecucion anterior ni identifica la etapa lenta.
- FG_IDX_2 y FACTURA_PK tienen estadisticas con muestreo completo sobre 25,288,911 filas y 831 modificaciones. FACTURA_INDX y FACTDET_PK tienen 91,609,796 filas muestreadas y 3,053 modificaciones. Su antiguedad por si sola no justifica actualizar toda la base con FULLSCAN.
- Las estadisticas de CFDI_COBRANZA_IDX4/IDX5 muestran muestreo completo y cero modificaciones. Hay otras autoestadisticas de cobranza con contadores superiores a 111 millones: revisar las columnas y su uso en el plan antes de intervenir; no equivalen a ese numero de filas distintas modificadas.
- Los indices deshabilitados FG_INDX, IX_FACTURA_ENT, PK_FACTURA_FECHA_PROC y REP_FG no aportan cobertura activa. No se habilitan automaticamente; no son las dos propuestas de esta primera prueba.

Comparar tiempo y lecturas con el mismo corte temporal y las mismas fuentes, antes/despues de cada cambio. Usar @Diagnostico=1 del procedimiento RENDIMIENTO para localizar si el tiempo queda en cabeceras, detalle o cobranza. Las pruebas del procedimiento reconstruyen la misma tabla de salida y deben ejecutarse de forma exclusiva en QA.

Referencia tecnica: [Microsoft: indices con columnas incluidas](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-indexes-with-included-columns). La cobertura puede reducir acceso a la tabla base, a cambio de almacenamiento y mantenimiento adicionales.

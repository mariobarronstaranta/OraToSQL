# Documentación funcional y técnica de procedimientos CFDI

**Fecha de revisión:** 23 de septiembre de 2026.  
**Proyecto:** OraToSQL, ambiente lógico T3, esquema EAI.  
**Base del análisis:** código SQL Server disponible en el repositorio.

## 1. Alcance y fuentes

Este documento describe la función, parámetros, secuencia completa de procesamiento, reglas, llamadas y tablas de entrada/salida de los cinco procedimientos solicitados. Las reglas se obtuvieron de las instrucciones ejecutables de los archivos `.SQL`; los comentarios y documentos anteriores se utilizaron como contexto. Se documenta el comportamiento actual del código, incluso cuando contiene diferencias entre procedimientos o condiciones que requieren atención.

El análisis es estático: no acredita qué versión está desplegada en una base de datos, ni constituye una certificación de equivalencia completa con Oracle. No se ejecutaron cargas ni se modificaron procedimientos para elaborar este documento. Los archivos Oracle homónimos se conservan como referencia de origen en `ORA/T3/EAI/Procedures`.

### 1.1 Identificación de las implementaciones

| Nombre solicitado | Archivo SQL Server analizado | Nombre declarado dentro del archivo | Proceso de auditoría |
|---|---|---|---:|
| `EAI.SF_BITACORA_CFDI` | [SF_BITACORA_CFDI.SQL](../MSSQL/T3/EAI/Procedures/SF_BITACORA_CFDI.SQL) | `EAI.SF_BITACORA_CFDI` | 801 |
| `EAI.SF_BITACORA_CFDI_RESUMEN` | [SF_BITACORA_CFDI_RESUMEN.SQL](../MSSQL/T3/EAI/Procedures/SF_BITACORA_CFDI_RESUMEN.SQL) | `EAI.SF_BITACORA_CFDI_RESUMEN_OPTIMIZADO` | 802 |
| `EAI.SF_CFDI_NOTA_CREDITO` | [SF_CFDI_NOTA_CREDITO.SQL](../MSSQL/T3/EAI/Procedures/SF_CFDI_NOTA_CREDITO.SQL) | `EAI.SF_CFDI_NOTA_CREDITO` | 922 |
| `EAI.SF_CFDI_OPEN_ITEMS` | [SF_CFDI_OPEN_ITEMS.SQL](../MSSQL/T3/EAI/Procedures/SF_CFDI_OPEN_ITEMS.SQL) | `EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO` | 923 |
| `EAI.SF_CFDI_VENTA` | [SF_CFDI_VENTA.SQL](../MSSQL/T3/EAI/Procedures/SF_CFDI_VENTA.SQL) | `EAI.SF_CFDI_VENTA` | 921 |

**Discrepancia de nombres:** los archivos de resumen y partidas abiertas crean o alteran objetos con sufijo `_OPTIMIZADO`. Sin embargo, el [script de jobs](../MSSQL/T3/EAI_OWNER/Jobs/01_CREATE_OR_UPDATE_JOBS.SQL) invoca los nombres sin sufijo. Ejecutar esos archivos no actualiza por sí mismo los objetos sin sufijo. Las secciones correspondientes describen la implementación disponible e identificada arriba; para atribuirla al objeto instalado sin sufijo se necesita cotejar su definición en el ambiente destino.

### 1.2 Conceptos empleados

| Concepto | Significado en estos procedimientos |
|---|---|
| CFDI / UUID | Comprobante fiscal y su folio fiscal. La detección de UUID se basa principalmente en que `Folio_Fiscal` no sea `NULL`. |
| PAC | Fuente de estados, folios e importes del comprobante, representada aquí por `T3.CFDI_Documentos`. |
| Nota de venta / documento operativo | Identificador T3: `Factura`, `Doc_Num` o `Nota_Venta`, según la tabla. |
| Documento agrupado | Varias operaciones asociadas a un `Nota_Venta_CFDI` mediante el historial fiscal. |
| Cartera SAP | Datos locales de `EAI.T3R_Cartera_SAP_OLD`. Los SP consultan esta tabla; no realizan una conexión directa a SAP. |
| Input | Tabla leída para seleccionar, calcular o relacionar datos. |
| Output | Tabla en la que se insertan, modifican o eliminan filas. Puede ser también input durante el enriquecimiento. |
| Etapa | Umbral de inicio del procesamiento. Una condición `@nEtapa <= N` ejecuta la etapa N y permite continuar con las posteriores. |

Los cinco procedimientos producen resultados persistentes en tablas. Ninguno declara parámetros `OUTPUT`, un conjunto de resultados de negocio mediante un `SELECT` final ni un código de retorno funcional explícito. Los mensajes `PRINT` son diagnósticos, no el reporte.

### 1.3 Relación funcional

| Procedimiento | Resultado principal | Uso |
|---|---|---|
| Bitácora | `EAI.CFDI_BITACORA` | Detalle operativo/fiscal, importes T3 y SAP, fechas y referencias. |
| Resumen | `EAI.CFDI_INFORME` | Informe de CFDI individuales y agrupados con conciliación de importes. |
| Nota de crédito | `EAI.CFDI_UUID_NOTA_CREDITO` | Seguimiento de notas, saldo SAP, UUID y aplicaciones. |
| Partidas abiertas | `EAI.CFDI_OPEN_ITEMS` | Cartera SAP y documentos históricos con diferencias de cobro/aplicación. |
| Venta | `EAI.CFDI_UUID_VENTA` | Ventas de la bitácora con saldo SAP, cobranza y respaldo fiscal. |

`SF_CFDI_VENTA` necesita que la bitácora contenga el universo que se desea reportar. El resumen obtiene su carga principal de las tablas T3, pero también lee y modifica la bitácora para ventas centralizadas. Ninguno de estos cinco SP llama directamente a otro de los cinco: la relación entre ellos es por tablas compartidas y ejecución externa.

## 2. EAI.SF_BITACORA_CFDI

### 2.1 Función del procedimiento

Construye y enriquece el detalle de CFDI en `EAI.CFDI_BITACORA`. Parte de facturas y preventas, consolida importes por documento y agrega territorio, asociación con comprobantes individuales/agrupados, fechas y estado fiscal, volumen de producto, importe SAP, método y forma de pago, RFC y reglas de centro y venta centralizada.

Además de su resultado principal, puede modificar `Origen` en `EAI.CFDI_INFORME`. No genera ni timbra comprobantes; consulta la información fiscal ya existente.

### 2.2 Parámetros

| Parámetro | Tipo | Dirección | Predeterminado | Función |
|---|---|---|---|---|
| `@nEtapa` | `INT` | Entrada | `0` | Umbral desde el cual se ejecutan las etapas numeradas. |

| Valor | Comportamiento |
|---|---|
| `0` o negativo | Reconstrucción y todas las etapas. |
| `1..10` | Etapas 10, 20, 30, 40, 80, 90, 100 y final. |
| `11..20` | Desde etapa 20. |
| `21..30` | Desde etapa 30. |
| `31..40` | Desde etapa 40. |
| `41..80` | Desde etapa 80; no existen etapas ejecutables 50, 60 o 70. |
| `81..90` | Etapas 90, 100 y final. |
| `91..100` | Etapa 100 y final. |
| Mayor que `100` o `NULL` | Solo auditoría y bloque final de enriquecimiento. |

**Particularidad:** en este SP se compara directamente `@nEtapa`. Un `NULL` explícito no equivale a omitir el parámetro y no se convierte a cero.

### 2.3 Lógica completa

#### Inicio y auditoría

Obtiene un PID de `EAI_OWNER.ProcessID`, llama a `Log_Start(801)`, inserta inicio en `T3.RF_PROCESOS_LOG` y actualiza `EAI.CONTROL_REPORTE` para `Reporte = 'BITACORA CFDI - DETALLE'`, estableciendo `Inicio` y limpiando `Fin`.

#### Etapa 0: reconstrucción

1. Elimina **todas** las filas de `EAI.CFDI_BITACORA`.
2. Consulta `FC__TIME_WINDOW.Start_Date`, convertido con estilo 103 (`DD/MM/YYYY`), y toma como límite inferior esa fecha menos un mes. No aplica límite superior de fecha.
3. Obtiene facturas de `Factura_General` con su detalle. No limita esta rama a una lista de tipos: `C003` se clasifica como venta y cualquier otro tipo como devolución.
4. Relaciona opcionalmente la factura con `CFDI_Historia_Docto_PAC` para recuperar `Nota_Venta_CFDI`.
5. Agrega preventas de clases `C005`, `C006` y `C025` con `Fecha_Proc_BATMD` no nula. `C005` es venta; las demás, devolución. Su `Nota_Venta_CFDI` inicial es la propia factura y ambos clientes iniciales se toman de `PG.Cliente_SAP`.
6. Conserva preventas canceladas, pero multiplica sus importes por cero.
7. Consolida ambas fuentes mediante `UNION ALL` y agrupación por centro, documento, referencia SAP, folio CFDI, clientes, fecha, tipo y fechas operativas.
8. Inserta los siete importes: subtotal, IVA, bonificación subtotal, envío subtotal/IVA y crédito subtotal/IVA.
9. Asigna `Credit_Days = 0` a las devoluciones.
10. Reemplaza `Bonif_Subt` con la suma de `Bonif_Subt + Bonif_IVA` del registro fiscal cuando la suma fiscal de `Bonif_Subt` sea mayor que cero y el documento esté dentro de la ventana.

Para cada importe de la carga base:

```text
Importe consolidado = SUM(Signo × FactorCancelación × ISNULL(ImporteDetalle, 0))
Signo = +1 para C003 en factura o C005 en preventa; -1 en los demás casos.
FactorCancelación = 1 en factura; 1/0 en preventa vigente/cancelada.
```

La actualización posterior de bonificación utiliza el importe fiscal sin volver a aplicar ese signo o factor de cancelación; por ello puede sustituir el resultado calculado inicialmente.

#### Etapa 10: factura inmediata

Busca `Factura_General.Factura = CFDI_BITACORA.Doc_Num`. Actualiza el centro y el territorio con `SUBSTRING(Ubicacion, 15, 4)`. Guarda las filas actualizadas en `Proceso_1`.

#### Etapa 20: territorio de preventa

Cruza la bitácora con `Preventa_General` y `Entrega`, ambas por factura. Solo actualiza preventas sin cancelación cuyo año de procesamiento sea el año actual. Si `Fecha_Proc_BATMD` es nula, la comparación utiliza la fecha actual más 366 días.

El territorio toma `Entrega.Ubicacion` y, si es nula, `Preventa_General.Ubicacion`. El enlace con `Entrega` es **INNER JOIN**: sin fila de entrega no se ejecuta esa sustitución. Registra el conteo en `Proceso_2`.

#### Etapa 30: CFDI individual

Cuando `CFDI_Documentos.Nota_Venta = Doc_Num` y existe `Fecha_Proc_BATMD`, copia folio operativo fiscal, fechas de liberación, envío, timbre y CFD, estado y total fiscal. Asigna `Fecha_Venta = Invc_dt` y `Docto_Ind = 1`.

`Total_CFD = ISNULL(CFD.Valor_Subt, 0) + ISNULL(CFD.Valor_IVA, 0)`.

#### Etapa 40: CFDI agrupado

Relaciona documento original → historial → cabecera agrupada → comprobante fiscal. Requiere `H.Nota_Venta_CFDI <> H.Nota_Venta` y fecha de procesamiento no nula. Actualiza fecha de venta desde `CFDI_Agrupado.Fecha_Documento`, fechas fiscales, estado y total.

La expresión real de clasificación es `CHARINDEX(CFD.Nota_Venta, CB.Doc_Num)`: busca el identificador fiscal dentro de `Doc_Num`. Si devuelve cero, asigna `Docto_SAT = 0` y `Doctos = 0`; en otro caso asigna `Docto_SAT = 1` y `Doctos = A.Doctos`. No es una comparación de igualdad ni debe interpretarse invirtiendo sus argumentos. Registra filas actualizadas en `Proceso_3`.

#### Etapa 80: volumen por categoría

Agrega `Registro_Fiscal_Detalle` por factura, con material existente y al menos una cabecera `Registro_Fiscal` correspondiente.

| Destino | Cálculo |
|---|---|
| `Primer_Categoria` | Para material cuyo primer carácter, después de quitar espacios iniciales, es `1`: cantidad × conversión de presentación. |
| `Segunda_Categoria` | Cantidad vendida de los demás materiales. |

La conversión usa `Material.Cig_x_CLL` si `Unidad_Med_Vta = 'CAJ'`; en otro caso usa `Cig_x_PAQ`. Este bloque no sustituye conversiones nulas por uno ni aplica el signo de venta/devolución. `SUM` conserva la semántica de valores nulos de SQL Server.

#### Etapa 90: importes SAP y descuentos

Primero relaciona `T3R_Sales_Docs_Old.Doc_Num_Ref2` con `GETCONV('FolioDuplicado', Doc_Num)`, excluyendo estados `D` y `E`. Un estado nulo tampoco satisface `NOT IN`.

```text
SAP_Amount = (+1 si Tipo_Vta = 'Vta'; -1 en otro caso)
             × (Doc_NetAmt + Doc_TaxAmt)
```

Los dos importes SAP no tienen `ISNULL` en esta suma: si uno es nulo, el resultado es nulo.

Después agrupa detalle temporal para cabeceras `DeliveryType = 'C025'` y actualiza por `ReferenceID = Factura_SAP`:

```text
SAP_Amount = SUM(ISNULL(Valor_Subt, 0) + ISNULL(Valor_IVA, 0)) / -100.0
```

Esta segunda actualización tiene precedencia y convierte los importes de centavos a unidades monetarias con signo negativo.

#### Etapa 100: método y forma de pago

- Para `Doc_Num <> Nota_Venta_CFDI` con folio CFDI no nulo, asigna `Metodo_Pago = 'PUE'` y `Forma_Pago = '99'`.
- Para documentos individuales, consulta `T3.RF_Documentos.Anexo_CFD` y extrae `MetodoPago` y `FormaPago` de `cfdi:Comprobante` con namespace `http://www.sat.gob.mx/cfd/4`.
- No contiene una alternativa de lectura para otros namespaces/versiones de XML.

#### Bloque final, siempre ejecutado

1. Recalcula RFC desde `T3.Cliente` vigente en `Invc_dt`. Utiliza `MAX(RFC)`; si no encuentra cliente vigente puede asignar `NULL` aun si antes había un RFC.
2. Para coincidencias en `TAO_Cedis_Valid` con `Accnt_ID = Loc = Cliente_SAP`, cambia centro de ventas a `Ctro_HUB` y de devoluciones a `Ctro_Customer`. La condición de cambio usa `<>`; un centro actual nulo no satisface esa comparación.
3. Para clientes de `WA_VENTA_CENTRALIZADA` vigentes en la fecha del documento, copia `SAP_Amount` a `SF_Amount` y establece `Origen = 'SAP'`.
4. Propaga `Origen = 'SAP'` a `CFDI_INFORME` cuando `Folio_Interno = Doc_Num` y se cumple la regla centralizada.
5. Cierra control de reporte y auditoría. `Proceso_4` permanece en cero.

### 2.4 Reglas importantes y límites

- La etapa 0 es una sustitución completa, no una actualización incremental.
- Las etapas parciales suponen que la tabla ya está cargada. No ejecutan ni verifican automáticamente las etapas omitidas.
- La ventana de configuración se usa mediante `CROSS JOIN`: cero filas puede dejar vacía la carga y varias filas pueden multiplicar registros/importes. La rutina no valida su cardinalidad.
- La consolidación inicial incluye varias columnas; no garantiza una sola fila por `Doc_Num` ante diferencias en esas columnas o relaciones duplicadas.
- Los datos de las etapas posteriores pueden sobrescribir los anteriores: bonificación fiscal, importe C025 y reglas de centro/venta centralizada son ejemplos.
- El campo `SF_Amount` solo se modifica aquí para venta centralizada. Este SP no ejecuta `SF_BITACORA_CFDI_VENTA_SF` ni calcula de forma general importes de Salesforce.
- No abre una transacción global propia. En ejecución independiente, un error posterior al `DELETE` puede dejar una reconstrucción parcial. `XACT_ABORT ON` no crea una transacción por sí solo.

### 2.5 Llamadas y dependencias ejecutables

| Tipo | Objeto | Parámetros / uso | Efecto |
|---|---|---|---|
| Stored procedure | `EAI_OWNER.Log_Start` | `801` | Marca inicio del componente. Única llamada directa a otro SP. |
| Función escalar | `EAI_OWNER.GETCONV` | `'FolioDuplicado', CB.Doc_Num` | Traduce referencia mediante `MX_HashTable`; si no hay equivalencia conserva el valor original. |
| Secuencia | `EAI_OWNER.ProcessID` | `NEXT VALUE FOR` | Genera PID de ejecución. |

### 2.6 Tablas input

| Tabla | Información utilizada / relación |
|---|---|
| `EAI.FC__TIME_WINDOW` | Fecha de inicio para la ventana operativa. |
| `T3.Factura_General` | Cabecera, documento, clientes, fecha, entrega/referencia SAP, centro y territorio. |
| `T3.Factura_Detalle` | Importes por factura. |
| `T3.Preventa_General` | Cabecera, clase, cancelación, procesamiento y ubicación. |
| `T3.Preventa_Detalle` | Importes de preventa. |
| `T3.CFDI_Historia_Docto_PAC` | Relación entre documento operativo y CFDI. |
| `T3.Registro_Fiscal_Detalle` | Bonificación, cantidad y material por factura. |
| `T3.Registro_Fiscal` | Existencia de cabecera fiscal para volumen. |
| `T3.Entrega` | Ubicación de preventa por factura. |
| `T3.CFDI_Documentos` | Estado, fechas e importes del comprobante. |
| `T3.CFDI_Agrupado` | Fecha y cantidad de documentos agrupados. |
| `T3.Material` | Presentación y factores de conversión a cigarrillos. |
| `EAI.T3R_Sales_Docs_Old` | Referencia, estado e importes SAP. |
| `EAI_OWNER.tmp_Document_Header` | Selección de documentos C025. |
| `EAI_OWNER.tmp_Document_Detail` | Importes por `ReferenceID`. |
| `T3.RF_Documentos` | XML para método/forma de pago. |
| `T3.Cliente` | RFC según vigencia. |
| `EAI_OWNER.TAO_Cedis_Valid` | Centro HUB y centro de cliente BackOffice. |
| `EAI_OWNER.WA_VENTA_CENTRALIZADA` | Clientes y vigencias para priorizar SAP. |
| `EAI_OWNER.MX_HashTable` | Input indirecto de `GETCONV`: `Type`, `Source`, `Target`. |

### 2.7 Tablas output e input/output

| Tabla | Operaciones | Resultado |
|---|---|---|
| `EAI.CFDI_BITACORA` | `DELETE`, `INSERT`, lectura y `UPDATE` | Detalle reconstruido y enriquecido en las etapas descritas. |
| `EAI.CFDI_INFORME` | Lectura de claves y `UPDATE` | Origen SAP para folios centralizados. |
| `EAI.CONTROL_REPORTE` | `UPDATE` | Inicio y fin de `BITACORA CFDI - DETALLE`. |
| `T3.RF_PROCESOS_LOG` | `INSERT`, `UPDATE` | PID, proceso 801, inicio, fin y contadores. |
| `EAI_OWNER.MX_COMPONENTS` | `UPDATE` indirecto/directo | Inicio mediante `Log_Start`; `Status = 1` al completar. |
| `EAI_OWNER.MX_EAI_MESSAGE_LOG` | `INSERT` en error | Etapa, PID y mensaje de error. |

En error, registra `Queue_Name = 'SF_BITACORA_CFDI_1'`, `Source = 'SQL SERVER'` y un código con prefijo `ORA-` aunque el número proviene de SQL Server; después relanza con `THROW`. No ejecuta el cierre normal.

## 3. EAI.SF_BITACORA_CFDI_RESUMEN

### 3.1 Función del procedimiento

Reconstruye `EAI.CFDI_INFORME` para comparar los importes operativos T3 con los importes fiscales de CFDI individuales y agrupados de un periodo. Integra identificación fiscal del cliente, sociedad, centro, territorio, UUID, estado, lista de precio, número de documentos, volumen, envío, crédito, diferencias y addenda.

**Implementación disponible:** el archivo homónimo declara `EAI.SF_BITACORA_CFDI_RESUMEN_OPTIMIZADO`.

### 3.2 Parámetros

| Parámetro | Tipo | Dirección | Predeterminado | Significado |
|---|---|---|---|---|
| `@pFecha_Inicio` | `VARCHAR(30)` | Entrada | `NULL` | Primer día del periodo; formato esperado `YYYYMMDD`. |
| `@pFecha_Final` | `VARCHAR(30)` | Entrada | `NULL` | Último día incluido; formato esperado `YYYYMMDD`. |

Si ambos son nulos, usa desde un mes antes de `FC__TIME_WINDOW.Start_Date` hasta el día actual. Si se proporciona alguno, intenta convertir ambos con estilo 112. El filtro es `Fecha_Factura >= inicio AND Fecha_Factura < día posterior al fin`, por lo que incluye las horas del último día.

| Validación | Resultado |
|---|---|
| Ventana de configuración nula o no convertible con estilo 103 | Error `54101`. Se exige incluso si se pasan fechas explícitas. |
| Alguna fecha efectiva nula/no convertible | Error `54102`. |
| Inicio posterior al fin | Error `54103`. |

Estas validaciones ocurren antes de eliminar el informe, aunque ya se abrió la auditoría. No se valida que `FC__TIME_WINDOW` tenga exactamente una fila; varias filas dejan el valor de una asignación sin orden definido. No existe parámetro de etapa.

### 3.3 Lógica completa

#### Inicio, fechas e historial

Abre auditoría del proceso 802, resuelve y valida fechas, marca inicio del reporte `BITACORA CFDI` y elimina **todo** `EAI.CFDI_INFORME`, incluyendo cualquier periodo previamente cargado.

Filtra `CFDI_Historia_Docto_PAC.Fecha_Factura` y guarda las relaciones en `#HDocPeriodo`. Crea índices por nota original y por folio agrupado. Esta tabla temporal se reutiliza en las tres ramas de carga.

#### Carga A: individuales desde Factura_General

Selecciona relaciones donde `Nota_Venta = Nota_Venta_CFDI`. Exige coincidencia en `CFDI_Documento_Paso`, `Factura_General`, `CFDI_Documentos` y `Cliente` vigente en la fecha de factura.

- Sociedad: `MX06`.
- RFC: `CFDI_Documento_Paso.RFC_Factura`.
- Nombre y lista de precio: cliente vigente.
- Territorio: `SUBSTRING(FG.Ubicacion, 15, 4)`.
- Número de documentos: `1`.
- Factor: `+1` para `C003`; `-1` para cualquier otro tipo de esta rama.
- `Monto_T3In`: subtotal más IVA de cabecera, multiplicado por el factor.
- UUID, estado e identificadores de envío/confirmación: `CFDI_Documentos`.

No hay un filtro de clases limitado a `C003/C004` en esta rama. Las coincidencias obligatorias determinan qué filas llegan al informe.

#### Carga B: individuales desde Preventa_General

También exige igualdad de nota original y folio CFDI, cabecera de preventa, comprobante y cliente vigente. La entrega se relaciona mediante `LEFT JOIN`.

- Sociedad: `MX01` para clases `C020`, `C021`, `C022`; `MX06` en los demás casos.
- Factor: `+1` para `C005`, `C0FX`, `C020`; `-1` para las demás clases.
- RFC, nombre y lista de precio: cliente vigente.
- Territorio: ubicación de entrega, con alternativa en la ubicación de preventa.
- `Monto_T3In` inicial: cero si existe cancelación o el año de `Fecha_Proc_BATMD` es `2999`; de lo contrario subtotal más IVA de cabecera, con factor.
- Una fecha de proceso nula no cumple la condición del año 2999 y no produce cero por esa condición.

No excluye preventas canceladas ni fija una lista de clases en el `WHERE` de esta carga. La regla de cero afecta al monto inicial; enriquecimientos posteriores pueden agregar importes.

#### Regla fiscal para las dos cargas individuales

| Estado de `CFDI_Documentos` | Subtotal e IVA base |
|---|---|
| `CONFIRMADO` | Importes del comprobante PAC. |
| `PENDING` o `PUBLICADO` | Importes de la cabecera T3 correspondiente. |
| Otro estado o nulo | Cero. |

Los campos base se normalizan con `ISNULL(..., 0)`. Luego se calcula `Valor_Subt = subtotal × Factor`, `Valor_IVA = IVA × Factor` y `Valor = (subtotal + IVA) × Factor`.

#### Carga C: CFDI agrupados

1. Elimina relaciones históricas exactamente repetidas con `DISTINCT` de nota, centro, fecha y folio CFDI.
2. Para notas distintas del folio agrupado, suma desde `Factura_Detalle` subtotal, IVA, envío subtotal y envío IVA. Agrupa por centro, fecha histórica y folio CFDI. Esta suma operativa no incorpora columnas de crédito.
3. Obtiene importes fiscales desde `CFDI_Agrupado_Detalle`: subtotal/IVA más envío y crédito en sus componentes respectivos.
4. Obtiene territorio con `SUBSTRING(A.Cliente_SAP, 2, 5)` y cantidad de documentos con `MAX(A.Doctos)` dentro de la agrupación.
5. Une ambas agregaciones y el comprobante por `Nota_Venta_CFDI`.
6. Inserta sociedad `MX06`, RFC `XAXX010101000` y nombre `CLIENTE AGRUPADOR VENTAS DIA`.
7. Usa factor `+1` para `C003` y `-1` para otros tipos.

| Estado agrupado | Subtotal e IVA utilizados inicialmente |
|---|---|
| `CONFIRMADO` | Los del comprobante PAC. |
| `PENDING` | Los calculados del detalle agrupado. |
| `PUBLICADO`, otro o nulo | Cero en esta carga. Posteriormente `PUBLICADO` tiene una normalización de `Valor`. |

La carga agrupada parte de facturas generales, no de preventas. Aunque se espera un informe por folio, las agrupaciones por centro/fecha/tipo y los enlaces únicamente por folio no garantizan unicidad ante datos inconsistentes.

#### Enriquecimiento de volumen e importes individuales

Reduce `Registro_Fiscal` a una fila por factura. Calcula `Sumar_Envio = MAX(CASE WHEN Tipo_Docto IN ('C005','C006') THEN 0 ELSE 1 END)`. Si existen varias cabeceras y alguna tiene otra clase, el máximo será uno.

Agrega detalle fiscal y material. Convierte cantidad a cigarrillos usando `Cig_x_CLL` para `CAJ` o `Cig_x_PAQ` en otro caso; una conversión nula se sustituye por `1`. Actualiza cigarrillos, envío y crédito multiplicando por el factor del informe.

```text
Monto_T3In nuevo = Monto_T3In anterior
                  + Factor × (Envio_Subt + Envio_IVA + Credito_Subt + Credito_IVA)
                    × Sumar_Envio
```

Los importes de esa fórmula proceden de la agregación fiscal. La actualización se enlaza por `Registro_Fiscal_Detalle.Factura = Folio_Interno`; no tiene una condición adicional que compruebe si la fila fue insertada como individual.

#### Enriquecimiento de agrupados y lista de precio

Agrega `CFDI_Agrupado_Detalle`, validando una cabecera agrupada y un material. Actualiza cigarrillos, envío y crédito con el factor. Este bloque no cambia `Monto_T3In`.

Para un folio agrupado cuya `LP` sea nula, consulta `Fact_T3` y `Nota_T3` mediante el historial; toma `MAX(Grupo_Precio)` entre ambas fuentes. El máximo es una selección técnica, no una validación de que todas las operaciones compartan lista.

#### Ajustes, centavos y addenda

1. Suma `CFDI_Agrupado_DIF.Ajuste` a `Valor_IVA` y `Valor` cuando el ajuste es distinto de cero. El enlace es por folio y no exige una marca de agrupado.
2. Para diferencias entre `Valor` y `Monto_T3In`, ajusta únicamente si el folio no empieza por `G-`, la diferencia absoluta es **menor** que `0.06` y `Fecha >= @dVentana`.
3. Guarda la diferencia previa en `Diferencia`, la resta de `Valor_IVA` e iguala `Valor` a `Monto_T3In`.
4. Marca `Addenda = 'SI'` si existe el RFC en `CFDI_Addenda`; en otro caso, `NO`.
5. Para estado `PUBLICADO` con totales distintos, iguala `Valor = Monto_T3In`. Esta última actualización no recalcula `Valor_Subt`, `Valor_IVA` ni `Diferencia`.

La fecha usada para ajustar centavos es la fecha configurada sin restarle un mes; no es necesariamente igual al inicio del periodo solicitado. Una diferencia exacta de `0.06` no se ajusta.

#### Venta centralizada y cierre

Actualiza la bitácora para clientes centralizados vigentes: `SF_Amount = SAP_Amount`, `Origen = 'SAP'`. Propaga ese origen al informe por `Doc_Num = Folio_Interno`. Estas actualizaciones consultan la bitácora existente y no incorporan el filtro del periodo del historial.

Cierra `CONTROL_REPORTE`, componente 802 y `RF_PROCESOS_LOG`. Los contadores son: individuales de factura, individuales de preventa, agrupados insertados y filas actualizadas por `CFDI_Agrupado_DIF`, respectivamente. El total impreso suma solo las tres cargas.

### 3.4 Reglas importantes y límites

- Cada ejecución sustituye el informe completo por el periodo pedido; no conserva otros periodos.
- `CONFIRMADO`, `PENDING` y `PUBLICADO` tienen reglas distintas; `PUBLICADO` agrupado no se calcula inicialmente igual que un individual.
- El cero de una preventa cancelada/2999 corresponde al cálculo inicial; no debe asumirse que todas las columnas o el monto final serán cero.
- Después de normalizar `PUBLICADO`, `Valor` puede no coincidir con `Valor_Subt + Valor_IVA`, porque solo se cambia el total.
- La deduplicación se aplica en puntos concretos, no a todas las tablas: vigencias superpuestas de cliente, pasos repetidos o comprobantes duplicados pueden multiplicar resultados.
- No abre una transacción global. La validación protege el informe ante fechas inválidas, pero un error posterior al borrado puede dejarlo parcial.

### 3.5 Llamadas a otros objetos

| Tipo | Objeto | Uso |
|---|---|---|
| Stored procedure | `EAI_OWNER.Log_Start` | Recibe `802`; única llamada directa a otro SP. |
| Secuencia | `EAI_OWNER.ProcessID` | Identifica la ejecución. |

No llama a la bitácora, a venta ni a procedimientos de timbrado. Las conversiones, agregaciones y `CROSS APPLY` son operaciones SQL internas.

### 3.6 Tablas input

| Tabla | Uso |
|---|---|
| `EAI.FC__TIME_WINDOW` | Periodo predeterminado y fecha mínima de ajuste de centavos. |
| `T3.CFDI_Historia_Docto_PAC` | Universo temporal y relaciones de documentos/lista de precio. |
| `T3.CFDI_Documento_Paso` | RFC usado al facturar el individual de factura general. |
| `T3.Factura_General` | Cabecera, tipo, ubicación e importe individual. |
| `T3.Factura_Detalle` | Importe operativo de documentos agrupados. |
| `T3.Preventa_General` | Cabecera, sociedad por clase, cancelación, proceso e importes. |
| `T3.Cliente` | Datos del cliente vigente: nombre, RFC y lista de precio. |
| `T3.Entrega` | Ubicación opcional de preventa. |
| `T3.CFDI_Documentos` | Estado, UUID, importes e identificadores PAC. |
| `T3.CFDI_Agrupado` | Tipo, territorio, fecha y cantidad de documentos. |
| `T3.CFDI_Agrupado_Detalle` | Importes, volumen, envío y crédito agrupados. |
| `T3.Registro_Fiscal` | Clasifica el tratamiento de envío/crédito. |
| `T3.Registro_Fiscal_Detalle` | Volumen e importes complementarios individuales. |
| `T3.Material` | Factores de conversión de volumen. |
| `T3.Fact_T3` | Grupo de precio de facturas relacionadas. |
| `T3.Nota_T3` | Grupo de precio de notas relacionadas. |
| `T3.CFDI_Agrupado_DIF` | Ajuste fiscal por folio. |
| `T3.CFDI_Addenda` | Existencia de addenda por RFC. |
| `EAI_OWNER.WA_VENTA_CENTRALIZADA` | Regla de origen SAP por cliente y vigencia. |

### 3.7 Tablas output e input/output

| Tabla | Operaciones | Resultado |
|---|---|---|
| `EAI.CFDI_INFORME` | `DELETE`, tres cargas `INSERT`, lectura y `UPDATE` | Informe reconstruido y enriquecido. |
| `EAI.CFDI_BITACORA` | Lectura y `UPDATE` | Importe y origen de venta centralizada; vínculo con informe. |
| `#HDocPeriodo` | Creación mediante `SELECT INTO`, índices y lectura | Datos intermedios locales; no es salida persistente. |
| `EAI.CONTROL_REPORTE` | `UPDATE` | Inicio/fin de `BITACORA CFDI`. |
| `T3.RF_PROCESOS_LOG` | `INSERT`, `UPDATE` | Auditoría 802 y contadores. |
| `EAI_OWNER.MX_COMPONENTS` | `UPDATE` indirecto/directo | Inicio y conclusión del componente. |
| `EAI_OWNER.MX_EAI_MESSAGE_LOG` | `INSERT` en error | Etapa, PID y excepción. |

El error se registra con `Queue_Name = 'SF_BITACORA_CFDI_RESUMEN'`, `Source = 'T-SQL'`, prefijo `ERR-` y mensaje truncado a 250 caracteres; se relanza mediante `THROW`.

## 4. EAI.SF_CFDI_NOTA_CREDITO

### 4.1 Función del procedimiento

Reconstruye el inventario de notas de crédito/devoluciones en `EAI.CFDI_UUID_NOTA_CREDITO`, agrega saldo de cartera SAP y folio fiscal, y calcula sus aplicaciones en cobranza. Permite identificar importe original, saldo SAP, cantidad de aplicaciones, importe aplicado, última fecha de aplicación e incobrable.

Su universo no exige saldo pendiente ni UUID existente. Incluye documentos que cumplen los filtros operativos aunque no tengan cartera o comprobante relacionado.

### 4.2 Parámetros

| Parámetro | Tipo | Dirección | Predeterminado | Comportamiento |
|---|---|---|---|---|
| `@nEtapa` | `INT` | Entrada | `0` | Se evalúa con `ISNULL(@nEtapa, 0)`. |

- Cero, negativos o `NULL`: reconstrucción y aplicaciones.
- `1..10`: conserva filas existentes y actualiza aplicaciones.
- Mayor que `10`: solo apertura/cierre de auditoría y gestión transaccional; no modifica el reporte de negocio.

### 4.3 Lógica completa

#### Control transaccional e inicio

Captura `@@TRANCOUNT`. Si no hay transacción externa, abre una propia. Si ya existe, crea el savepoint `SF_CFDI_NC` y no asume propiedad de la transacción del llamador.

Obtiene PID, llama a `Log_Start(922)` e inserta auditoría. A diferencia de los otros cuatro SP, protege la reconstrucción, aplicaciones y cierre como una unidad transaccional en ejecución independiente.

#### Etapa 0: selección y reconstrucción

Elimina todas las filas de `CFDI_UUID_NOTA_CREDITO` y forma un universo con dos fuentes:

| Fuente | Filtros obligatorios |
|---|---|
| `Factura_General` + `Factura_Detalle` | Fecha desde `2023-01-01`, tipo `C004`, cliente vigente en fecha de factura y RFC distinto de `XAXX010101000`. |
| `Preventa_General` + `Preventa_Detalle` | Fecha desde `2023-01-01`, clase `C006`, `C019` o `C025`, proceso no nulo, cancelación nula, cliente vigente y RFC distinto del genérico. |

La fecha mínima es fija y no utiliza `FC__TIME_WINDOW`. No hay fecha máxima. La comparación `RFC <> ...` excluye también RFC nulo.

Calcula por renglón:

```text
Importe_Item = ISNULL(Valor_Subt, 0) + ISNULL(Valor_IVA, 0)
               + ISNULL(Envio_Subt, 0) + ISNULL(Envio_IVA, 0)
```

Une mediante `UNION ALL` y suma por centro, fecha, nota, cliente y RFC. No suma `Credito_Subt` ni `Credito_IVA`, no aplica un signo negativo adicional y no convierte el importe original a absoluto.

Agrega cartera SAP por `Referencia` y une opcionalmente con la nota. Aunque esa subconsulta también calcula cliente máximo y fecha mínima, la salida utiliza el saldo agregado:

```text
Saldo_SAP = ABS(ISNULL(SUM(ISNULL(SAP.Monto, 0)), 0))
```

Finalmente hace `LEFT JOIN` con `CFDI_Documentos.Nota_Venta` para cargar `Folio_Fiscal`. No exige folio fiscal no nulo. El enlace no deduplica comprobantes.

#### Etapa 10: aplicaciones de cobranza

Agrupa `CFDI_Cobranza` por `Nota_Credito` y actualiza las notas cuyo `Nota_Venta` coincide.

| Campo destino | Cálculo |
|---|---|
| `Aplica_NC` | `COUNT(Asignacion_ID)`: cantidad de asignaciones no nulas, sin `DISTINCT`. |
| `Importe_NC` | `SUM(ISNULL(Importe, 0))` de todas las vías relacionadas. |
| `Fecha_Aplicacion` | `MAX(Fecha_Asignacion)`. |
| `Incobrable` | `SUM(CASE WHEN Via_Pago = 'AI' THEN Importe ELSE 0 END)`. |

La suma de `Importe_NC` no está limitada a vía `CM`; puede incluir `AI` y cualquier otra vía con la misma `Nota_Credito`. Una asignación nula no cuenta en `Aplica_NC`, pero su importe sí puede entrar en las sumas.

El `UPDATE` usa `INNER JOIN`: una nota sin coincidencia no se modifica. El contador `Proceso_1` se incrementa dentro de la actualización por cada fila destino actualizada. `Proceso_2`, `Proceso_3` y `Proceso_4` permanecen en cero.

#### Cierre y errores

Marca componente 922 terminado y completa la auditoría. Confirma únicamente si abrió su propia transacción.

En error:

1. Captura código `SQL-<número>` y mensaje de hasta 250 caracteres.
2. Si la transacción es propia y sigue activa, ejecuta rollback completo.
3. Si la transacción es externa y permanece confirmable (`XACT_STATE() = 1`), revierte al savepoint.
4. Si la transacción externa está condenada (`XACT_STATE() = -1`), no intenta escribir el log ni volver al savepoint; corresponde al llamador hacer rollback.
5. Cuando es posible escribir, intenta registrar el error. Un fallo de este registro se captura separadamente para conservar la excepción original.
6. Relanza la excepción mediante `THROW`.

En ejecución independiente, el log de error se intenta escribir después del rollback y puede persistir aunque la carga se revierta. Con una transacción externa confirmable, la persistencia del log depende de la decisión final del llamador.

### 4.4 Reglas importantes y límites

- Este reporte usa importe de nota y saldo SAP con tratamientos distintos: solo el saldo se convierte explícitamente a absoluto.
- `Aplica_NC` es un **conteo** en este SP; no es el importe que el campo homónimo representa en ventas y partidas abiertas.
- `Importe_NC` suma todas las vías. En partidas abiertas, el campo homónimo de devoluciones solo suma `CM`.
- No comprueba si cada aplicación está timbrada; el UUID que carga es el asociado a la propia nota.
- El incobrable usa `Importe` sin `ISNULL` en la rama `AI`, por lo que conserva la semántica de nulos de `SUM`.
- Una ejecución parcial no limpia aplicaciones antiguas de notas que ya no tienen coincidencias de cobranza.
- Vigencias de cliente superpuestas o varios comprobantes por nota pueden producir multiplicación de importes o filas. La rutina no contiene una deduplicación global.

### 4.5 Llamadas

| Tipo | Objeto | Uso |
|---|---|---|
| Stored procedure | `EAI_OWNER.Log_Start` | Recibe `922`; única llamada directa a otro SP. |
| Secuencia | `EAI_OWNER.ProcessID` | PID de ejecución, almacenado aquí en variable `INT`. |

No invoca otros SP de CFDI ni funciones escalares de negocio.

### 4.6 Tablas input

| Tabla | Uso |
|---|---|
| `T3.Factura_General` | Notas C004 desde 2023, centro, fecha y cliente. |
| `T3.Factura_Detalle` | Importes de las notas de factura. |
| `T3.Preventa_General` | Notas C006/C019/C025 procesadas y no canceladas. |
| `T3.Preventa_Detalle` | Importes de las notas de preventa. |
| `T3.Cliente` | RFC y vigencia para inclusión. |
| `EAI.T3R_Cartera_SAP_OLD` | Saldo agregado por referencia. |
| `T3.CFDI_Documentos` | Folio fiscal por nota. |
| `T3.CFDI_Cobranza` | Asignaciones, importes, vías y última fecha por nota de crédito. |

### 4.7 Tablas output e input/output

| Tabla | Operaciones | Resultado |
|---|---|---|
| `EAI.CFDI_UUID_NOTA_CREDITO` | `DELETE`, `INSERT`, lectura y `UPDATE` | Identificación, importe, saldo, UUID y aplicaciones de notas. |
| `T3.RF_PROCESOS_LOG` | `INSERT`, `UPDATE` | Auditoría del proceso 922. |
| `EAI_OWNER.MX_COMPONENTS` | `UPDATE` indirecto/directo | Inicio y fin del componente. |
| `EAI_OWNER.MX_EAI_MESSAGE_LOG` | `INSERT` condicionado por estado transaccional | Error con cola `SF_CFDI_NOTA_CREDITO` y origen `T-SQL`. |

No modifica `CONTROL_REPORTE`, la bitácora detallada ni el informe resumido.

## 5. EAI.SF_CFDI_OPEN_ITEMS

### 5.1 Función del procedimiento

Construye el universo de documentos abiertos en `EAI.CFDI_OPEN_ITEMS` combinando cartera SAP con operaciones históricas que presentan diferencias contra lo cobrado/aplicado. Enriquece ventas y devoluciones con cobranza, UUID, importes fiscales, cliente facturado y referencias SAP.

**Implementación disponible:** el archivo homónimo declara `EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO`.

El término “abierto” no implica que todas las filas finales superen el mismo umbral: la cartera SAP se incorpora sin filtrar saldo cero y la tolerancia de cinco centavos se aplica a la incorporación histórica.

### 5.2 Parámetros

| Parámetro | Tipo | Dirección | Predeterminado | Función |
|---|---|---|---|---|
| `@nEtapa` | `INT` | Entrada | `0` | Inicio por umbral; `NULL` se convierte a cero. |

| Valor | Etapas ejecutadas, además de inicio y bloque final |
|---|---|
| Cero, negativos o `NULL` | 0, 10, 20, 30, 60, 70, 80, 90. |
| `1..10` | 10, 20, 30, 60, 70, 80, 90. |
| `11..20` | 20, 30, 60, 70, 80, 90. |
| `21..30` | 30, 60, 70, 80, 90. |
| `31..60` | 60, 70, 80, 90. |
| `61..70` | 70, 80, 90. |
| `71..80` | 80, 90. |
| `81..90` | 90. |
| Mayor que `90` | Ninguna numerada; sí se ejecuta el bloque final, que modifica datos. |

### 5.3 Lógica completa

#### Inicio y etapa 0: cartera SAP

Abre auditoría del proceso 923 y elimina todo `CFDI_OPEN_ITEMS` cuando corresponde reconstruir.

1. Lee `T3R_Cartera_SAP_OLD`.
2. Traduce referencias con `CFDI_Refoleo` para `Tipo_Registro = 'DOI'`. Si no hay traducción, conserva la referencia SAP.
3. Relaciona la referencia resultante con `Registro_Fiscal` para conocer la clase.
4. Excluye referencias existentes en `Otros_General`.
5. Agrupa por referencia y tipo fiscal: cliente máximo, fecha documental mínima y suma del monto con nulos como cero.
6. Convierte la fecha textual SAP mediante `TRY_CONVERT(DATE, Fecha_Doc, 112)`; una fecha inválida queda nula.
7. Inserta nota, cliente, fecha, tipo simplificado, saldo y `Last_Updated`.

| Condición | `Tipo_Docto` destino | `Saldo_SAP` destino |
|---|---|---|
| Clase `C003` o `C005` | `Vta` | Saldo con su signo original. |
| Clase `C004`, `C006`, `C019` o `C025` | `Dev` | Valor absoluto del saldo. |
| Otra clase o no identificada, saldo no negativo | `Vta` | Valor absoluto del saldo. |
| Otra clase o no identificada, saldo negativo | `Dev` | Valor absoluto del saldo. |

No filtra RFC, fecha mínima ni saldo no cero en esta rama. `Proceso_1` cuenta sus filas insertadas.

#### Etapa 10: históricos con diferencia pendiente

Consulta facturas `C003/C004` y preventas `C005/C006/C019/C025` desde `2023-01-01`. Las preventas deben estar procesadas y no canceladas. Ambas fuentes exigen cliente vigente; no excluyen RFC genérico.

El importe histórico suma subtotal, IVA, crédito subtotal/IVA y envío subtotal/IVA. Agrupa por centro, fecha, clase, nota, cliente y RFC.

Solo incorpora una nota si no existe ya en `CFDI_OPEN_ITEMS` y cumple:

```text
ABS(ISNULL(Importe_Venta, 0) - ISNULL(ImporteFunción, 0)) > 0.05

ImporteFunción = T3.FN_Cobza_Pay(Nota_Venta) para C003/C005
                T3.FN_COBZA_CM_UUID(Nota_Venta) para otras clases admitidas
```

Una diferencia de `0.05` o menor se considera saldada para esta incorporación. La comparación absoluta también puede admitir una diferencia por exceso de cobro.

Inserta centro, nota, cliente, cliente facturado inicial igual al cliente operativo, fecha, `Vta/Dev`, importe y fecha de actualización. Aunque el RFC participa en la consulta y agrupación, no se inserta en este bloque; se completa después. Tampoco se inserta aquí `Saldo_SAP`. La exclusión de `Otros_General` corresponde a etapa 0 y no se repite en esta rama histórica. `Proceso_4` cuenta estos insertados.

#### Etapa 20: cobranza de ventas

Obtiene notas distintas del reporte con `Tipo_Docto = 'Vta'`. Lee su cobranza por `CFDI_Cobranza.Factura` y relaciona tres posibles comprobantes:

1. Pago directo: `Asignacion_ID` contra `CFDI_Documentos.Nota_Venta`.
2. Pago agrupado: `CFDI_Agrupacion_Pago` y `CFDI_Agrupacion_Ctrl`; solo agrupaciones con `ISNULL(AC.Importe, 0) <> 0`, y luego su CFDI.
3. Nota de crédito: `Nota_Credito` contra `CFDI_Documentos.Nota_Venta`.

Clasifica importe de cobranza por vía:

| Vía | Campo |
|---|---|
| `01` | `Efectivo` |
| `02`, `03` | `Agrupado` |
| `CM` | `Aplica_NC` |
| `AI` | `Incobrable` |
| Cualquier vía | Participa en `Importe`, incluso si no pertenece a una de las cuatro categorías. |

Calcula `Timbrado` sumando tres indicadores, cada uno igual a uno si el respectivo `Folio_Fiscal` no es nulo. Los importes `Efectivo_UUID`, `Agrupado_UUID`, `Aplica_NC_UUID` e `Importe_UUID` se obtienen multiplicando por esa suma antes de agregar por factura.

Por tanto, `Timbrado` puede valer de cero a tres. No se comprueba formato de UUID ni estado `CONFIRMADO`. Un texto vacío no nulo cumple la condición del código. Una cobranza de 100 con dos indicadores positivos aporta 200 al importe UUID.

Actualiza solo ventas con cobranza coincidente, copia método de pago del CFDI de la propia nota y actualiza fecha. `Proceso_2` recibe el conteo de ventas actualizadas.

#### Etapa 30: aplicaciones de devoluciones

Para notas `Dev`, agrupa cobranza por `Nota_Credito`. `Importe_NC` suma únicamente la vía `CM`; `Incobrable` suma únicamente `AI`; `Fecha_Aplicacion` es la fecha máxima de todos los movimientos relacionados, sin limitarla a esas dos vías.

Actualiza las devoluciones con coincidencia y suma su conteo a `Proceso_2`.

#### Etapa 60: importe fiscal y notas de débito

Agrega `Registro_Fiscal` y su detalle para documentos del reporte, con `Mov_Cliente` opcional por cliente. Calcula subtotal, IVA, envío y crédito y actualiza `Ctro`, `RFC`, `Importe_Vta` y fecha de actualización.

Después cruza `DEBIT_NOTE_IFC.Debit_Note` con la nota abierta y exige cliente en `Mov_Cliente` por `Cust_to_SAP`. Sustituye el importe por `DEBIT_NOTE_IFC.Total_Amt` y centro/RFC por los del cliente. Esta segunda actualización prevalece sobre el cálculo fiscal cuando ambos coinciden.

`Proceso_3` acumula las dos actualizaciones.

#### Etapa 70: relación fiscal

Une la nota con `CFDI_Historia_Docto_PAC` y opcionalmente con su comprobante. Actualiza `Nota_Venta_CFDI`, `Folio_Fiscal`, `Metodo_Pago` y fecha. Esta etapa puede sobrescribir el método obtenido en etapa 20, incluso con nulo si existe historial pero no comprobante. Acumula filas en `Proceso_3`.

#### Etapa 80: importe de nota de crédito con UUID

Solo para devoluciones, busca el CFDI usando el folio del historial o, si es nulo, la nota original. Requiere coincidencia en `CFDI_Documentos` mediante `INNER JOIN`.

```text
Importe_NC_UUID = (0 si Folio_Fiscal es NULL; 1 en otro caso)
                  × ISNULL(Importe_NC, 0)
```

Si no existe fila CFDI, no actualiza: no equivale a asignar cero incondicionalmente. Acumula filas en `Proceso_3`.

#### Etapa 90: cliente facturado

Consulta facturas y preventas con `Clte_Factura_SAP` no nulo y distinto de `Cliente_SAP`. Actualiza el cliente facturado del reporte por factura y la fecha de actualización. No completa por esta vía casos donde ambos clientes son iguales. Acumula filas en `Proceso_3`.

#### Bloque final, siempre ejecutado

1. Para filas cuyo RFC es nulo, obtiene `MAX(RFC)` y `MAX(Ctro)` de `Mov_Cliente`, agrupados por nota. Actualiza ambos campos. Los máximos se calculan independientemente y pueden provenir de filas distintas. Un centro nulo con RFC ya informado no activa esta corrección.
2. Para cada devolución, suma `ISNULL(FN_GET_TAX_ISSUE(Nota_Venta), 0)` a `ISNULL(Importe_Vta, 0)`.
3. Copia `Registro_Fiscal.Pedido` a `PedidoSAP` y `Registro_Fiscal.Entrega` a `FacturaSAP`.
4. Cierra componente y auditoría. Estas actualizaciones finales de negocio no actualizan `Last_Updated` en el código.

### 5.4 Reglas importantes y límites

- La etapa 0 incluye toda la cartera admitida, incluso saldos cero. No existe una depuración final que elimine documentos después de recalcular cobros.
- **Reejecución parcial:** el ajuste fiscal final es aditivo. Si se ejecuta nuevamente sin reconstruir o recalcular `Importe_Vta`, puede volver a sumar la misma diferencia de IVA. Esto también ocurre con `@nEtapa > 90`.
- Las uniones de cobranza con comprobantes y agrupaciones no se reducen todas a una fila por clave. Duplicados pueden multiplicar importes antes de la suma; la lógica difiere de la deduplicación utilizada en `SF_CFDI_VENTA`.
- En etapa 0, múltiples refoleos o registros fiscales también pueden multiplicar montos o generar varios grupos para una referencia.
- Sin coincidencia en una actualización por `INNER JOIN`, conserva los valores previos. Las ejecuciones parciales no garantizan limpieza de información antigua.
- No aplica un signo negativo general a `Importe_Vta` de devoluciones; distingue el tipo y usa absoluto en el saldo según las reglas descritas.
- No abre transacción global propia. Un error puede dejar resultados parciales.

### 5.5 Llamadas y dependencias ejecutables

| Tipo | Objeto | Entrada / uso | Alcance conocido |
|---|---|---|---|
| Stored procedure | `EAI_OWNER.Log_Start` | `923` | Única llamada directa a otro SP. |
| Función | `T3.FN_Cobza_Pay` | Nota de venta; etapa 10 | Valor a descontar del importe histórico de ventas. Definición no localizada en los scripts revisados. |
| Función | `T3.FN_COBZA_CM_UUID` | Nota de crédito; etapa 10 | Valor a descontar para devoluciones. Definición no localizada en los scripts revisados. |
| Función | `EAI_OWNER.FN_GET_TAX_ISSUE` | Nota de venta; bloque final de devoluciones | Devuelve diferencia de IVA desde `T3.NDC_ISSUE_IVA`; cero si no hay fila o diferencia. |
| Secuencia | `EAI_OWNER.ProcessID` | `NEXT VALUE FOR` | PID de ejecución. |

No se atribuyen tablas internas ni reglas adicionales a las dos funciones de cobranza sin sus definiciones. Para `FN_GET_TAX_ISSUE`, el retorno es `DECIMAL(6,2)`; si hay varias filas por factura, la asignación sin orden no selecciona una diferencia de manera determinista y no suma las diferencias.

### 5.6 Tablas input

| Tabla | Uso |
|---|---|
| `EAI.T3R_Cartera_SAP_OLD` | Universo inicial y saldo SAP. |
| `T3.CFDI_Refoleo` | Traducción SAP → T3 para registros DOI. |
| `T3.Registro_Fiscal` | Clase, importes vinculados, centro, pedido y entrega. |
| `T3.Otros_General` | Exclusión en la carga de cartera. |
| `T3.Factura_General` | Histórico C003/C004 y cliente facturado. |
| `T3.Factura_Detalle` | Importe de históricos. |
| `T3.Preventa_General` | Histórico C005/C006/C019/C025 y cliente facturado. |
| `T3.Preventa_Detalle` | Importe de históricos de preventa. |
| `T3.Cliente` | Existencia/vigencia del cliente histórico. |
| `T3.CFDI_Cobranza` | Cobro, aplicaciones, incobrables y fechas. |
| `T3.CFDI_Documentos` | UUID de venta/pago/agrupación/nota y método de pago. |
| `T3.CFDI_Agrupacion_Pago` | Asociación de asignación con agrupación. |
| `T3.CFDI_Agrupacion_Ctrl` | Filtro de agrupaciones con importe distinto de cero. |
| `T3.Registro_Fiscal_Detalle` | Importe fiscal de los documentos abiertos. |
| `T3.Mov_Cliente` | RFC y centro actual del cliente. |
| `T3.DEBIT_NOTE_IFC` | Importe y cliente de notas de débito. |
| `T3.CFDI_Historia_Docto_PAC` | Relación nota operativa → folio CFDI. |
| `T3.NDC_ISSUE_IVA` | Input indirecto a través de `FN_GET_TAX_ISSUE`. |
| Dependencias internas de funciones de cobranza | Pendientes de identificar con sus definiciones; no se consideran inventariadas. |

### 5.7 Tablas output e input/output

| Tabla | Operaciones | Resultado |
|---|---|---|
| `EAI.CFDI_OPEN_ITEMS` | `DELETE`, `INSERT`, lectura y `UPDATE` | Cartera/históricos, cobros, aplicaciones, UUID, importes, clientes y referencias. |
| `T3.RF_PROCESOS_LOG` | `INSERT`, `UPDATE` | Auditoría 923. P1: cartera insertada; P2: ventas/devoluciones actualizadas por cobranza; P3: suma de actualizaciones de etapas 60–90; P4: históricos insertados. |
| `EAI_OWNER.MX_COMPONENTS` | `UPDATE` indirecto/directo | Inicio y fin del componente. |
| `EAI_OWNER.MX_EAI_MESSAGE_LOG` | `INSERT` en error | Cola `SF_CFDI_OPEN_ITEMS`, origen `T-SQL`, código `ERR-` y etapa. |

Los contadores de actualizaciones pueden contar varias veces un documento que pasa por distintas etapas. El error se relanza mediante `THROW`.

## 6. EAI.SF_CFDI_VENTA

### 6.1 Función del procedimiento

Genera `EAI.CFDI_UUID_VENTA` a partir de ventas de la bitácora, incorpora saldo SAP y clasifica cobranza en efectivo, agrupada, aplicada mediante nota de crédito e incobrable. Calcula también importes asociados a comprobantes con folio fiscal y recupera el método de pago.

No selecciona exclusivamente ventas con saldo abierto, no exige que la venta ya tenga UUID y no recalcula la bitácora de origen.

### 6.2 Parámetros

| Parámetro | Tipo | Dirección | Predeterminado | Comportamiento |
|---|---|---|---|---|
| `@nEtapa` | `INT` | Entrada | `0` | Se evalúa mediante `ISNULL(@nEtapa, 0)`. |

- Cero, negativos o `NULL`: reconstruye ventas y calcula cobranza.
- `1..10`: mantiene el universo existente y recalcula cobranza/método cuando hay coincidencias.
- Mayor que `10`: solo auditoría; no cambia el reporte de ventas.

### 6.3 Lógica completa

#### Inicio y etapa 0

Abre auditoría del proceso 921 y elimina todas las filas de `CFDI_UUID_VENTA` cuando corresponde reconstruir.

Selecciona de `CFDI_BITACORA` únicamente `Tipo_Vta = 'Vta'` y `ISNULL(RFC, '') <> 'XAXX010101000'`. Por tanto, admite RFC nulo o vacío; solo excluye el genérico indicado. No utiliza un filtro explícito `Doc_Num = Nota_Venta_CFDI`, por lo que la selección literal no garantiza que todos sean CFDI individuales.

Copia centro, fecha `Invc_dt`, documento `Doc_Num`, RFC y cliente, y calcula:

```text
Importe_Vta = ISNULL(Valor_Subt, 0) + ISNULL(Valor_IVA, 0)
              + ISNULL(Envio_Subt, 0) + ISNULL(Envio_IVA, 0)
              + ISNULL(Credito_Subt, 0) + ISNULL(Credito_IVA, 0)
```

Forma una lista distinta de notas para agregar cartera SAP solo de documentos relevantes. Suma `ISNULL(Monto, 0)` por referencia, conservando el signo. Une el saldo opcionalmente y usa cero si no existe cartera.

El `DISTINCT` protege la agregación de cartera; no elimina filas duplicadas de la bitácora en el `INSERT` final. No hay fecha mínima propia: el periodo depende de la bitácora.

#### Etapa 10: preparación de documentos relevantes

1. Obtiene notas distintas de la tabla de salida.
2. Selecciona cobranza cuya factura pertenece a esas notas.
3. Construye con `UNION` la lista de folios necesarios: notas de venta, asignaciones, notas de crédito y agrupaciones de pago relacionadas.
4. Reduce `CFDI_Documentos` a una fila por `Nota_Venta`, calculando `Tiene_UUID = MAX(0/1 por Folio_Fiscal no nulo)` y `Metodo_Pago = MAX(Metodo_Pago)`.
5. Reduce agrupaciones timbradas a una bandera por `Asignacion_ID`. Basta con que alguna agrupación relacionada tenga UUID.

A diferencia de partidas abiertas, esta rutina no consulta `CFDI_Agrupacion_Ctrl` ni exige un importe de control distinto de cero para aceptar la agrupación.

#### Etapa 10: clasificación y actualización

Para cada cobranza, convierte importe nulo en cero y clasifica por vía `01`, `02/03`, `CM` o `AI`. El total `Importe` suma todas las vías, incluidas las no clasificadas.

```text
Timbrado = TieneUUID(PagoDirecto)
           + TieneUUID(AlgunaAgrupaciónDelPago)
           + TieneUUID(NotaCrédito)

Importe_UUID   = SUM(Importe × Timbrado)
Efectivo_UUID  = SUM(Importe de vía 01 × Timbrado)
Agrupado_UUID  = SUM(Importe de vías 02/03 × Timbrado)
Aplica_NC_UUID = SUM(Importe de vía CM × Timbrado)
```

Agrega por factura y actualiza importes, categorías, incobrable y método de pago de la venta. El método se obtiene del CFDI de la nota de venta, no del comprobante de pago.

La actualización requiere cobranza mediante `INNER JOIN`. Una venta sin cobranza no recibe actualización del método aunque exista su CFDI. Tras ello, `Proceso_1 = COUNT(*)` de toda la tabla de ventas, incluyendo filas sin cobranza; los demás contadores permanecen en cero.

#### Cierre y errores

Marca terminado el componente 921 y actualiza fin/contadores. En error, registra etapa, PID, cola `SF_CFDI_VENTA`, origen `T-SQL`, código `ERR-` y mensaje de hasta 250 caracteres; luego relanza con `THROW`.

### 6.4 Reglas importantes y límites

- `Timbrado` es una suma de indicadores de cero a tres, no una bandera booleana. Los importes UUID pueden exceder el importe de cobranza si hay respaldo en más de una categoría de comprobante.
- No valida estructura de UUID ni estado PAC; el criterio es que el folio no sea nulo.
- La deduplicación de comprobantes y agrupaciones evita una multiplicación por esas relaciones, pero no elimina duplicados del propio origen de cobranza o de las filas finales de venta.
- `MAX(Metodo_Pago)` selecciona un valor determinista según el orden de comparación del campo, no necesariamente el más reciente.
- La cobranza no tiene filtro temporal adicional; toma todos los movimientos relacionados con las ventas presentes.
- Las ejecuciones parciales no recalculan importe original ni saldo SAP y no limpian campos de ventas que dejaron de tener cobranza.
- No aplica valor absoluto al saldo SAP. Esta regla difiere del reporte de notas de crédito.
- No existe transacción global propia; un error puede dejar resultados parciales.

### 6.5 Llamadas

| Tipo | Objeto | Uso |
|---|---|---|
| Stored procedure | `EAI_OWNER.Log_Start` | Recibe `921`; única llamada directa a otro SP. |
| Secuencia | `EAI_OWNER.ProcessID` | PID de ejecución. |

No llama a `SF_BITACORA_CFDI`, a notas de crédito ni a funciones de cobranza: sus agregaciones se resuelven directamente con consultas.

### 6.6 Tablas input

| Tabla | Uso |
|---|---|
| `EAI.CFDI_BITACORA` | Universo, identificación y seis componentes del importe de venta. |
| `EAI.T3R_Cartera_SAP_OLD` | Saldo por referencia de las notas seleccionadas. |
| `T3.CFDI_Cobranza` | Importe, vía, factura, asignación y nota de crédito. |
| `T3.CFDI_Documentos` | Existencia de UUID y método de pago por documento. |
| `T3.CFDI_Agrupacion_Pago` | Agrupaciones fiscales de una asignación. |

### 6.7 Tablas output e input/output

| Tabla | Operaciones | Resultado |
|---|---|---|
| `EAI.CFDI_UUID_VENTA` | `DELETE`, `INSERT`, lectura y `UPDATE` | Venta, saldo SAP, clasificación de cobranza e importes UUID. |
| `T3.RF_PROCESOS_LOG` | `INSERT`, `UPDATE` | Proceso 921 y conteo total de ventas si se ejecuta etapa 10. |
| `EAI_OWNER.MX_COMPONENTS` | `UPDATE` indirecto/directo | Inicio y fin del componente. |
| `EAI_OWNER.MX_EAI_MESSAGE_LOG` | `INSERT` en error | Detalle de excepción. |

El DDL de `CFDI_UUID_VENTA` contiene importes asociados a UUID, pero no una columna `Folio_Fiscal` de salida. El nombre del reporte no implica que guarde el UUID de cada venta.

## 7. Auditoría, ejecución y dependencias compartidas

### 7.1 Qué hace el SP llamado por los cinco procesos

La definición disponible de [EAI_OWNER.LOG_START](../MSSQL/T3/EAI_OWNER/Procedures/LOG_START.SQL) recibe `@nComponent INT` y ejecuta:

```sql
UPDATE EAI_OWNER.MX_COMPONENTS
SET Status = 2, Last_Run = GETDATE()
WHERE Component = @nComponent;
```

No inserta un componente si no existe, no llama a más SP y no escribe por sí mismo `RF_PROCESOS_LOG`. Cada procedimiento analizado inserta y cierra su propia fila en esa tabla. Al terminar normalmente establece `MX_COMPONENTS.Status = 1`.

La secuencia [ProcessID](../MSSQL/T3/EAI_OWNER/Sequences/README.md) identifica ejecuciones; no es una tabla ni un mecanismo de bloqueo. Un PID distinto no impide que dos ejecuciones borren o actualicen simultáneamente las mismas tablas de reporte.

### 7.2 Comportamiento de errores y transacciones

| Procedimiento | Transacción propia | Propaga error | Particularidad |
|---|---|---|---|
| Bitácora | No | Sí, `THROW` | Puede dejar detalle parcial; el bloque final también modifica el informe. |
| Resumen | No | Sí, `THROW` | Valida fechas antes del borrado, pero no revierte automáticamente toda la reconstrucción. |
| Nota de crédito | Sí, o savepoint con transacción externa | Sí, preservando el error ante fallos del log | Rollback de carga propia; comportamiento externo depende de `XACT_STATE()`. |
| Partidas abiertas | No | Sí, `THROW` | Ajuste final de IVA aditivo y posibles cargas parciales. |
| Venta | No | Sí, `THROW` | Puede dejar reconstrucción o enriquecimiento parcial. |

Todos activan `NOCOUNT` y `XACT_ABORT`. En los cuatro que no abren transacción propia, las sentencias operan normalmente en autocommit cuando el llamador tampoco tiene una transacción. Si existe una transacción externa, participan de ella y el resultado transaccional depende del llamador y del error.

Los cuatro procedimientos distintos de nota de crédito no protegen por separado el `INSERT` del log dentro de su `CATCH`; un fallo de ese registro puede impedir llegar al `THROW` original. No establecen un estado final explícito de error en `MX_COMPONENTS`. Un fallo puede dejar marcas de inicio sin fin; en nota de crédito, la reversión también puede deshacer las marcas de inicio.

### 7.3 Diferencias que deben considerarse al comparar reportes

| Tema | Bitácora / resumen | Nota de crédito | Partidas abiertas | Venta |
|---|---|---|---|---|
| Periodo de carga | Bitácora: ventana menos un mes sin tope superior. Resumen: rango del historial. | Desde 2023-01-01. | Cartera sin periodo explícito; históricos desde 2023-01-01. | Hereda universo de bitácora. |
| RFC genérico | Permitido; el resumen agrupado lo asigna expresamente. | Excluido; nulos también quedan fuera. | No se excluye. | Excluido; nulos sí se admiten. |
| `Aplica_NC` | No es el cálculo principal de estas rutinas. | Cantidad de asignaciones no nulas. | Importe de vía CM para ventas. | Importe de vía CM. |
| `Importe_NC` | No aplica al flujo descrito. | Suma todas las vías por nota. | Solo vía CM para devoluciones. | No es columna calculada por esta rutina. |
| Tratamiento de `NULL` en etapa | Bitácora: omite numeradas; resumen no tiene etapa. | Equivale a cero. | Equivale a cero. | Equivale a cero. |
| Importe con respaldo UUID | Usa datos fiscales según cada etapa/estado. | Guarda UUID de la nota, sin calcular respaldo de aplicaciones. | Ventas: suma de tres indicadores; devoluciones: bandera individual. | Suma de tres indicadores. |

Los reportes no son intercambiables ni necesariamente deben arrojar totales iguales: parten de universos, signos, componentes y reglas de aplicación diferentes.

### 7.4 Invocaciones identificadas en el repositorio

El script de jobs contiene estas llamadas. Son evidencia de configuración en archivos, no confirmación de que los jobs estén desplegados, habilitados o ejecutándose.

| Job | Invocación declarada |
|---|---|
| `ORA_568_EAI_SF_BITACORA_CFDI` | `EXEC [EAI].[SF_BITACORA_CFDI] 0;` |
| `ORA_569_EAI_SF_BITACORA_CFDI_RESUMEN` | `EXEC [EAI].[SF_BITACORA_CFDI_RESUMEN] NULL, NULL;` |
| `ORA_830_EAI_SF_CFDI_NOTA_CREDITO` | `EXEC [EAI].[SF_CFDI_NOTA_CREDITO] 0;` |
| `ORA_849_EAI_SF_CFDI_OPEN_ITEMS` | `EXEC [EAI].[SF_CFDI_OPEN_ITEMS] 0;` |
| `ORA_829_EAI_SF_CFDI_VENTA` | `EXEC [EAI].[SF_CFDI_VENTA] 0;` |

Para resumen y partidas abiertas, el nombre de esas llamadas difiere del objeto creado por los archivos analizados. No se cambió la configuración como parte de esta documentación.

### 7.5 Ejemplos de parámetros sobre los nombres realmente declarados

Los siguientes ejemplos ejecutan procesos de escritura; una ejecución completa reemplaza el contenido de sus tablas destino. Se incluyen para explicar el contrato, no se ejecutaron durante el análisis.

```sql
-- Reconstrucción completa de bitácora.
EXEC EAI.SF_BITACORA_CFDI @nEtapa = 0;

-- Reanudar bitácora desde volumen; también ejecuta SAP, pago y bloque final.
EXEC EAI.SF_BITACORA_CFDI @nEtapa = 80;

-- Resumen: periodo explícito, último día incluido.
EXEC EAI.SF_BITACORA_CFDI_RESUMEN_OPTIMIZADO
    @pFecha_Inicio = '20260901', @pFecha_Final = '20260923';

-- Resumen: periodo definido por configuración y fecha actual.
EXEC EAI.SF_BITACORA_CFDI_RESUMEN_OPTIMIZADO
    @pFecha_Inicio = NULL, @pFecha_Final = NULL;

-- Reconstrucción y aplicaciones de notas de crédito.
EXEC EAI.SF_CFDI_NOTA_CREDITO @nEtapa = 0;

-- Solo aplicaciones sobre las notas existentes.
EXEC EAI.SF_CFDI_NOTA_CREDITO @nEtapa = 10;

-- Reconstrucción de cartera e históricos, y enriquecimiento completo.
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO @nEtapa = 0;

-- Construcción del reporte de ventas a partir de la bitácora existente.
EXEC EAI.SF_CFDI_VENTA @nEtapa = 0;
```

## 8. Referencias y alcance de la verificación

### 8.1 Fuentes de soporte

- [DDL consolidado de tablas EAI](../MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql).
- [Procedimiento LOG_START](../MSSQL/T3/EAI_OWNER/Procedures/LOG_START.SQL).
- [Función GETCONV](../MSSQL/T3/EAI_OWNER/Functions/GETCONV.SQL): lectura de `MX_HashTable`; `TOP (1)` sin orden ante duplicados. Si la equivalencia existe con `Target` nulo, devuelve nulo.
- [Función FN_GET_TAX_ISSUE](../MSSQL/T3/EAI_OWNER/Functions/FN_GET_TAX_ISSUE.SQL): lectura de `NDC_ISSUE_IVA`, sin suma ni orden para duplicados.
- [Configuración de jobs](../MSSQL/T3/EAI_OWNER/Jobs/01_CREATE_OR_UPDATE_JOBS.SQL).
- [Antecedentes de pruebas transaccionales de nota de crédito](../MSSQL/T3/EAI/Procedures/tests/SF_CFDI_NOTA_CREDITO/README.md). Es evidencia documental previa; no se volvieron a ejecutar esas pruebas para este entregable.

### 8.2 Archivos Oracle de referencia

- [SF_BITACORA_CFDI](../ORA/T3/EAI/Procedures/SF_BITACORA_CFDI.SQL).
- [SF_BITACORA_CFDI_RESUMEN](../ORA/T3/EAI/Procedures/SF_BITACORA_CFDI_RESUMEN.SQL).
- [SF_CFDI_NOTA_CREDITO](../ORA/T3/EAI/Procedures/SF_CFDI_NOTA_CREDITO.SQL).
- [SF_CFDI_OPEN_ITEMS](../ORA/T3/EAI/Procedures/SF_CFDI_OPEN_ITEMS.SQL).
- [SF_CFDI_VENTA](../ORA/T3/EAI/Procedures/SF_CFDI_VENTA.SQL).

### 8.3 Límites de la documentación

Se revisaron firmas, condiciones de cada etapa, fórmulas, uniones, llamadas explícitas, modificaciones de tablas y manejo de excepciones de las cinco implementaciones SQL Server identificadas. Las tablas input/output describen operaciones directas y las dependencias indirectas de funciones cuya definición se pudo revisar. No se atribuyen efectos adicionales de triggers ni dependencias internas desconocidas de las funciones de cobranza.

La unicidad de datos, la cardinalidad real de las relaciones, los objetos instalados y los tiempos de ejecución requieren verificación en el ambiente correspondiente. Las observaciones de duplicación, nulos, acumulación y diferencias entre reportes se derivan del código; no afirman que esos casos ya estén ocurriendo en producción.

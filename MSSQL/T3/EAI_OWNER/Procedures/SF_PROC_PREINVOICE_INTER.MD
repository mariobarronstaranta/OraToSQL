# `EAI_OWNER.SF_PROC_PREINVOICE_INTER_OPTIMIZADO`

## Objetivo

Esta versión optimiza el procesamiento de facturas intercompany recibidas en XML sin modificar las reglas de negocio del procedimiento original `EAI_OWNER.SF_PROC_PREINVOICE_INTER`.

El cambio principal consiste en sustituir los cursores que recorrían organizaciones, textos y artículos por operaciones relacionales sobre el XML. El procedimiento optimizado se crea con un nombre diferente, por lo que puede instalarse y probarse sin reemplazar inmediatamente la versión productiva.

Archivo ejecutable:

- `SF_PROC_PREINVOICE_INTER_OPTIMIZADO.SQL`

Procedimientos comparados:

- MSSQL original: `MSSQL/T3/EAI_OWNER/Procedures/SF_PROC_PREINVOICE_INTER.SQL`.
- Oracle homólogo: `ORA/T3/EAI_OWNER/Procedures/SF_PROC_PREINVOICE_INTER.SQL`.

## Firma

```sql
EAI_OWNER.SF_PROC_PREINVOICE_INTER_OPTIMIZADO
    @sRow_ID VARCHAR(50),
    @nRowNum INT = 1,
    @nOutput INT = 0,
    @nPID    INT = NULL
```

Los parámetros y sus tipos permanecen iguales al procedimiento MSSQL original.

- `@sRow_ID`: identifica el mensaje de `MX_RECEIVE_MESSAGE_LOG`.
- `@nRowNum`: se conserva por compatibilidad con Oracle y con el invocador; actualmente no participa en las reglas internas.
- `@nOutput`: habilita información de diagnóstico. Para los artículos, la versión optimizada devuelve un result set ordenado en lugar de ejecutar varios `PRINT` por cada fila.
- `@nPID`: relaciona los errores con el proceso que originó la ejecución.

## Desde dónde es llamado

El procedimiento original es invocado por:

```text
SQL Agent job ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY
  -> EAI_OWNER.RECV_INVOICE_INTERCOMPANY
     -> EAI_OWNER.SF_PROC_PREINVOICE_INTER
```

El job está configurado en `EAI_OWNER/Jobs/01_CREATE_OR_UPDATE_JOBS.SQL` con una periodicidad equivalente a diez minutos.

La creación de la versión optimizada no cambia automáticamente este flujo. Después de las pruebas funcionales y de rendimiento, el DBA deberá decidir si modifica `RECV_INVOICE_INTERCOMPANY` para llamar a `SF_PROC_PREINVOICE_INTER_OPTIMIZADO`.

## Flujo funcional conservado

1. Lee `XML_CONTENT` desde `EAI_OWNER.MX_RECEIVE_MESSAGE_LOG` usando `Row_ID`.
2. Obtiene `DocumentNumber`, moneda, RFC, tipo de cambio y condición de pago.
3. Si no existe una referencia válida, marca el mensaje para revisión.
4. Convierte la descripción de moneda mediante `EAI_OWNER.CURRENCY_TEXT`.
5. Elimina información previa de la misma referencia para permitir una reejecución limpia.
6. Obtiene los partners `AG`, `RE` y `WE`.
7. Obtiene pedidos, factura V3, entrega y fechas desde `ReferenceData` y `HeaderDate`.
8. Interpreta `OrganizationData` y determina compañía, organización de ventas, asignación y clase de factura.
9. Inserta las condiciones generales en `TMP_DOCUMENT_CONDITIONS`.
10. Concatena los textos de encabezado en español.
11. Aplica los workarounds de país, estado, RFC y facturación intercompany.
12. Convierte los artículos, impuestos y leyendas del XML a tablas relacionales.
13. Inserta `TMP_DOCUMENT_HEADER`, `TMP_DOCUMENT_DETAIL`, `TMP_DOCUMENT_DETAIL_COND` y `TMP_DOCUMENT_PARTNERS`.
14. Actualiza el estado del mensaje recibido.
15. Enruta el documento hacia `INVOICE_TO_PREVENTA` o `INVOICE_TO_OTROS`.

## Cambios de rendimiento

### 1. Eliminación de cursores

El procedimiento original de SQL Server contenía cinco cursores y cinco ciclos `WHILE`:

- `OrganizationCur`.
- `HeaderTextCur`.
- `ItemCur`.
- `ItemTextCur`.
- `TextLineCur`.

La versión optimizada no contiene cursores ni ciclos `WHILE`.

Beneficios esperados:

- Menor trabajo procedural por artículo.
- Menos cambios de contexto dentro del motor.
- Menor crecimiento del tiempo cuando un XML contiene muchos artículos o leyendas.
- Código más sencillo de mantener y diagnosticar.

### 2. Organización procesada por conjunto

`OrganizationData` se consulta directamente mediante expresiones XQuery filtradas por calificador.

Oracle recorre los nodos y deja el último valor cuando un calificador aparece repetido. La versión optimizada conserva explícitamente esa regla mediante `[last()]`, sin depender del orden físico de una consulta SQL.

### 3. Textos de encabezado agregados en bloque

Las líneas de `TextIdentification` se expanden una sola vez y se concatenan mediante `STRING_AGG` respetando su orden.

Se conservan los límites originales:

- Método de pago `Z048`: 80 caracteres.
- Referencia bancaria `Z024`: 80 caracteres.
- Observaciones `Z021`: 495 caracteres.
- Incoterms `INCO1` y `INCO2`: capacidad de la variable, 200 caracteres.

Solo se consideran textos con idioma `ES`, como en Oracle.

### 4. Materialización de artículos

Cada `ItemData` se convierte una sola vez en una fila de `#InterItems`. La tabla conserva temporalmente el fragmento XML del artículo para extraer sus colecciones hijas.

Desde esa estructura se calculan en bloque:

- Número de línea.
- Cantidad y unidad de medida.
- Planta.
- Material y descripción.
- Subtotal, bonificación, IVA y precio unitario.
- Leyendas en español e inglés.

### 5. Conversión UOM reutilizable

El original llamaba `EAI_OWNER.GETCONV('ECC_V3 UOM', ...)` una vez por artículo. La versión optimizada consulta `MX_HashTable` una vez por unidad de medida distinta y guarda el resultado en `#InterUomMap`.

Si no existe conversión, conserva la unidad original, igual que `GETCONV`.

También conserva el workaround:

```text
Unidad convertida = CASES y Bill-to = IC-00-MX16
    -> Unidad final = CTN
```

### 6. Inserciones masivas

Los registros de estas tablas se insertan mediante una operación por conjunto:

- `EAI_OWNER.TMP_DOCUMENT_DETAIL`.
- `EAI_OWNER.TMP_DOCUMENT_DETAIL_COND`.

La conversión de `TaxConditionValue` continúa usando `CONVERT`, no `TRY_CONVERT`. Un valor no numérico debe producir error y entrar al manejo de excepciones, igual que en el flujo anterior.

### 7. Trabajo eliminado

La versión original extraía las condiciones `ZFSI` hacia variables que después no participaban en ninguna inserción, decisión ni llamada. Esa lectura se eliminó porque no producía un efecto observable.

### 8. Equivalencia de importes opcionales

Oracle trata una cadena vacía como `NULL`. La versión MSSQL original inicializaba algunos importes opcionales con `''`; al insertarlos en columnas numéricas, SQL Server podía convertirlos en cero.

La versión optimizada deja como `NULL` los importes ausentes de un artículo. Esto conserva mejor el comportamiento Oracle y permite distinguir entre "el XML no informó el importe" y "el importe informado fue cero".

## Reglas de negocio verificadas contra Oracle

| Regla | Resultado |
|---|---|
| `DocumentNumber` controla si el mensaje se procesa | Conservada |
| Conversión documental y local de moneda | Conservada |
| Limpieza previa de cinco tablas temporales | Conservada |
| Partners `AG`, `RE` y `WE` | Conservados |
| Calificadores de `ReferenceData` | Conservados |
| Fecha de vencimiento desde `HeaderDate` | Conservada |
| Mapeo de clases `C005`, `C006`, `IV`, `ZI01`, `ZI03`, `ZI06`, `ZI02`, `ZI04`, `ZF2`, `ZL`, `IVS`, `C021` y `C022` | Conservado |
| Excepción `ZG` para `IC-00-MX16` | Conservada |
| `IV` de cliente `PC-00-MX%` se convierte en `C020` | Conservada |
| RFC extranjero `XEXX010101000` | Conservado |
| Conversión de país y estado mediante `GETCONV` | Conservada |
| Signo de impuestos según `TaxConditionIndicator` | Conservado |
| Unidad `CASES` a `CTN` para `IC-00-MX16` | Conservada |
| `ShippingPoint` toma la planta del último artículo | Conservado explícitamente |
| Pedido V3 limitado a 30 caracteres | Conservado |
| `IVS` detiene el routing y actualiza `PedidoV3` | Conservado |
| Clases `C020`, `C021`, `C022` van a `INVOICE_TO_PREVENTA` | Conservado |
| Compañías que comienzan con `MX` van a `INVOICE_TO_OTROS` | Conservado |
| Compañías no MX se rechazan | Conservado |
| Registro de errores en `MX_EAI_MESSAGE_LOG` | Conservado |

El valor `QUEUE_NAME = 'SF_PROC_PREINVOICE_INTER'` del registro de error se conserva deliberadamente. `WA_DEPURA_MESSAGE_LOG` reconoce ese nombre; cambiarlo por el nombre optimizado requeriría modificar también dicha dependencia.

## Dependencias

### Tablas

- `EAI_OWNER.MX_RECEIVE_MESSAGE_LOG`.
- `EAI_OWNER.MX_EAI_MESSAGE_LOG`.
- `EAI_OWNER.MX_HashTable`.
- `EAI_OWNER.TMP_DOCUMENT_HEADER`.
- `EAI_OWNER.TMP_DOCUMENT_DETAIL`.
- `EAI_OWNER.TMP_DOCUMENT_CONDITIONS`.
- `EAI_OWNER.TMP_DOCUMENT_PARTNERS`.
- `EAI_OWNER.TMP_DOCUMENT_DETAIL_COND`.

### Funciones

- `EAI_OWNER.CURRENCY_TEXT`.
- `EAI_OWNER.GETCONV`, utilizada para país y estado.

### Procedimientos

- `EAI_OWNER.INVOICE_TO_PREVENTA`.
- `EAI_OWNER.INVOICE_TO_OTROS`.

### Índices existentes en el repositorio

Existen índices por `ReferenceID` para:

- `TMP_DOCUMENT_HEADER`.
- `TMP_DOCUMENT_DETAIL`.
- `TMP_DOCUMENT_PARTNERS`.
- `TMP_DOCUMENT_DETAIL_COND`.

No se encontró un script equivalente para `TMP_DOCUMENT_CONDITIONS(ReferenceID)`. Antes de crear uno debe medirse su volumen y revisar los índices reales de la base; no se agregó DDL automático al procedimiento.

También debe verificarse en el ambiente el índice de `MX_HashTable` utilizado por las conversiones. El patrón recomendado, sujeto a duplicados y estándares del DBA, es:

```sql
-- Recomendación para evaluación; no forma parte del despliegue automático.
-- CREATE INDEX IX_MX_HASHTABLE_TYPE_SOURCE
--     ON EAI_OWNER.MX_HashTable ([Type], [Source])
--     INCLUDE ([Target]);
```

## Requisitos técnicos

La implementación usa `STRING_AGG ... WITHIN GROUP`. Debe ejecutarse en una versión de SQL Server que soporte `STRING_AGG` y con un nivel de compatibilidad que permita la cláusula de ordenamiento. El repositorio ya utiliza este patrón en otros procedimientos.

## Instalación y activación

1. Ejecutar `SF_PROC_PREINVOICE_INTER_OPTIMIZADO.SQL` en la base correspondiente.
2. Confirmar que el procedimiento fue creado en el esquema `EAI_OWNER`.
3. Probarlo directamente con copias controladas de mensajes reales.
4. Comparar tablas y estados contra una ejecución de la versión original.
5. Medir duración, CPU y lecturas lógicas.
6. Solo después de aprobar las pruebas, cambiar la llamada de `RECV_INVOICE_INTERCOMPANY`.

Ejemplo de prueba individual:

```sql
EXEC EAI_OWNER.SF_PROC_PREINVOICE_INTER_OPTIMIZADO
    @sRow_ID = 'ROW_ID_DE_PRUEBA',
    @nRowNum = 1,
    @nOutput = 1,
    @nPID = NULL;
```

## Pruebas funcionales mínimas

Se recomienda cubrir al menos estos escenarios:

1. XML sin `DocumentNumber`.
2. Factura intercompany normal dirigida a `INVOICE_TO_OTROS`.
3. Clase `IV` con cliente `PC-00-MX%`.
4. Clase `ZIG2` convertida a `C021`.
5. Clase `ZG` para `IC-00-MX16` y para otro cliente.
6. Cancelación `IVS`.
7. Documento de país diferente de México.
8. Unidad `CASES` para `IC-00-MX16`.
9. Artículo con múltiples impuestos positivos y negativos.
10. Artículo con textos `ES` y `EN` de varias líneas.
11. Mensaje con varios artículos y unidades repetidas.
12. Compañía cuyo código no comience con `MX`.

Para cada escenario deben compararse:

- Filas y valores de las cinco tablas temporales.
- Estado, referencia y fecha de procesamiento del mensaje.
- Procedimiento de routing ejecutado.
- Errores generados.

## Medición de rendimiento

En un ambiente de pruebas puede utilizarse:

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

EXEC EAI_OWNER.SF_PROC_PREINVOICE_INTER_OPTIMIZADO
    @sRow_ID = 'ROW_ID_DE_PRUEBA',
    @nRowNum = 1,
    @nOutput = 0,
    @nPID = NULL;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
```

La comparación debe utilizar el mismo XML y restaurar el estado inicial antes de ejecutar cada versión.

## Rollback

Como el procedimiento optimizado tiene un nombre nuevo, la versión original no se sobrescribe. El rollback consiste en mantener o restaurar la llamada a:

```sql
EAI_OWNER.SF_PROC_PREINVOICE_INTER
```

Si se desea retirar únicamente la versión de prueba:

```sql
DROP PROCEDURE IF EXISTS EAI_OWNER.SF_PROC_PREINVOICE_INTER_OPTIMIZADO;
```

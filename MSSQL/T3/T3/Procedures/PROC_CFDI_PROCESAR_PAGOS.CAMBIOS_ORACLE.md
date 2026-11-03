# Correccion PAGOS conforme a reglas Oracle

Entrega: 23/10/2026. **Instalacion corroborada en T3QA por metadatos y marcas**,
segun resultados recibidos del usuario a las 13:49:52 -06:00 en AZCRNMXNEVTD06.
Pendiente validar un lote posterior; no se consulto directamente la base real.
La corrida real anterior de 326 filas corresponde a DATE/cursores,
no acredita esta nueva entrega. El procedimiento se llama
**T3.PROC_CFDI_PROCESAR_PAGOS**, con S final.

## Archivos para ejecutar

Orden de aplicacion entregado, ya reportado ejecutado por el usuario en T3QA:

1. [WA_CFDI_COBZA_ASIG_CTRL.sql](WA_CFDI_COBZA_ASIG_CTRL.sql).
2. [PROC_CFDI_PROCESAR_PAGOS.sql](PROC_CFDI_PROCESAR_PAGOS.sql).

Ambos son ALTER completos. Actualizan definiciones; no ejecutan el lote.
GETCONV y FN_TOTAL_FACT compartidas conservan sus fuentes, firmas y resultados.
No se agregaron columnas, indices ni claves a CFDI_COBRANZA.

La [verificacion de instalacion](../../Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VERIFICAR_INSTALACION.sql)
ya devolvio MARCAS ESPERADAS PRESENTES para ambos procedimientos. PAGOS tiene
ultimo ALTER 13:43:38.253 y control 13:46:46.050 del 23/10/2026. FechaSoloDATE
NULL en el control es no aplicable. Ver [evidencia recibida](../../Diagnosticos/Pagos_20261023/VERIFICACION_INSTALACION_20261023.md).
Esta consulta verifica indicios del texto instalado, no el resultado del lote.
La validacion funcional se realiza sobre el siguiente procesamiento normal.

SHA256 de los archivos finales probados:

- PAGOS: `E722EFE5F19949F1D2077E038C8DD0A999600BE5F6A2ADCA86A5BCE2349ED823`.
- Control: `9F83666B63727D10C7661DC739E1F134BBE9B4E7631802D77D3E07FF16311FB6`.
- GETCONV conservada: `8B8B02C5FB7944E0DE033EAF5D76356E37BC13D07AF7E70E0CF2E206CC5D982B`.
- FN_TOTAL_FACT conservada: `8F600C01D0A445C15501DE887FCAD110343DAD4CD94A5A9D7D4839733EF406CE`.

### Ampliacion posterior de comentarios del control para desarrolladores junior

El usuario solicito ampliar los comentarios de WA_CFDI_COBZA_ASIG_CTRL.
El [archivo del control](WA_CFDI_COBZA_ASIG_CTRL.sql) incorpora
guia de parametros, efectos, filtros y ventana movil, diferencias entre los dos
cursores, ejemplos de conteos/empates, marca Fecha_Envio, CURRENT OF, contadores,
transacciones propias/externas, limpieza y diagnostico de errores. Explica que
los contadores pueden repetir pagos y que una marca no acredita envio al PAC.
Las declaraciones heredadas sin uso y la referencia de error sin asignar quedan
identificadas para mantenimiento, sin retirarlas ni cambiar su comportamiento.

Verificacion de esta revision documental: **1,364 tokens SQL identicos**, en
el mismo orden, incluidos literales e identificadores, al omitir comentarios y
espacios. Se preservo UTF-16 LE con BOM. El archivo paso de 274 a 374 lineas.
No se alteraron consultas, condiciones, parametros, transacciones ni errores.

- SHA256 antes: `9F83666B63727D10C7661DC739E1F134BBE9B4E7631802D77D3E07FF16311FB6`.
- SHA256 documental actual: `18FC94F0DCB93A5790DB894D4A2935FFED957FFF2635A3F80619BFDC6A3EB0EB`.

Los hashes de las pruebas funcionales anteriores corresponden al archivo antes
de ampliar comentarios; no se reescribieron esas evidencias ni se repitieron
pruebas de negocio. Esta revision solo actualiza el fuente local; para almacenar
los comentarios en T3QA se debe aplicar su ALTER completo. La corroboracion de
instalacion recibida anteriormente sigue correspondiendo a la entrega funcional.

La [validacion de resultado](../../Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql)
es solo lectura. Ajustar fecha y, de ser posible, PID de la corrida nueva.
Ahora incluye multiplicidad CFDI y distingue una base NULL conforme a Oracle
de una parcialidad no calculada. Una corrida anterior a la ultima modificacion
del modulo se identifica como historica sin certificarla con reglas actuales.
El ALTER no exige ni autoriza volver a procesar el lote del 14/10; el proceso
conserva la ausencia de control de duplicados del original.

## Cambios del procedimiento principal

### Total fiscal: adaptar el consumidor sin modificar la funcion compartida

El cursor obtiene localmente la suma de los seis componentes de
REGISTRO_FISCAL_DETALLE, con OUTER APPLY y conversion decimal(18,2): venta,
IVA, envio e IVA, credito e IVA. Cada componente NULL aporta cero, pero
**SUM sin filas permanece NULL**. No sustituye por otra tabla ni inventa un total.

Es la formula de FN_TOTAL_FACT Oracle. La funcion SQL compartida sigue
retornando cero sin detalle para sus otros consumidores. PAGOS deja de invocarla
para este calculo. Una fila existente con componentes NULL sigue sumando cero;
una factura sin detalle puede insertar Importe_Factura y Saldo_Anterior NULL,
con parcialidad calculada. La venta T3, cancelacion o SAT pueden aportar un total
posterior segun sus reglas. Ese NULL requiere revisar los datos fiscales y no
acredita por si mismo que un comprobante sea apto para envio.

### Regla SAT omitida

- ScrPagos incorpora LEFT JOIN directo AP.Factura=CFD.Nota_Venta e importe
  ISNULL(Valor_Subt,0)+ISNULL(Valor_IVA,0), con destino NUMERIC(13,3).
- No filtra Status ni UUID. No elimina coincidencias mediante DISTINCT/MAX.
  Dos documentos CFDI pueden producir dos iteraciones, igual que el original.
- Despues de venta/penalizacion/cancelacion y antes de inicializar saldo, para
  RFC no vacio y no generico consulta Type='SAT Amount Invoice', Source=RFC.
- Calcula primero MAX textual de Target, sustituyendo NULL/vacio por '0', y
  convierte el resultado a NUMERIC(4,0). No usa GETCONV para esta regla.
- Sustituye la base solo con configuracion >1 e importe SAT >0. No cambia
  importe del movimiento, tasa, fecha, estado ni UUID por esta regla aislada.
- Configuracion invalida o fuera de precision conserva el error de conversion/
  overflow; revierte el lote. No se convierte silenciosamente en configuracion cero.

### Cadenas y cursores

Origen vacio activa INCOBRABLE; Nota_Credito vacia se trata como NULL, sin
clasificarla como CM. Inicializaciones/proyecciones vacias y valores de salida
se adaptan a NULL. Se usa DATALENGTH=0 para no eliminar una cadena de espacios.
Los resultados vacios de GETCONV se adaptan solo en este consumidor; la funcion
no cambia. Las cinco declaraciones de cursores posteriores a asignar filtros
y las comparaciones DATE autorizadas se conservan. El cursor principal es
STATIC READ_ONLY para fijar el conjunto al abrirlo.

## Cambios del control posterior 889

ScrPagos se declara dentro de la rama, despues de asignar RFC/central, y se
cierra/libera por uso. Es LOCAL FORWARD_ONLY DYNAMIC SCROLL_LOCKS, actualizable
solo en Fecha_Envio. La sentencia usa WHERE CURRENT OF ScrPagos para modificar
exactamente la fila recuperada. Funciona en el heap sin PK del DDL local,
con Asignacion_ID repetido o NULL. No cambia el esquema ni usa %%physloc%%.

Esta forma de [UPDATE posicionado](https://learn.microsoft.com/en-us/sql/t-sql/queries/update-transact-sql)
afecta una fila. El cursor dinamico puede observar cambios concurrentes al
recorrerlo; las pruebas no simulan concurrencia y no equivalen a la lectura
consistente completa de Oracle en ese aspecto.

El filtro de longitud cuenta espacios finales mediante LEN(columna+'#')-1.
La ventana sigue siendo movil de tres dias/hora, no se cambia a DATE.
Conserva umbral de conteo estricto, empate sin marca por esa rama, exclusiones
del cursor externo y seleccion amplia interna de Oracle: una CM o un pago ya
enviado puede examinarse cuando la agrupacion califica. Fecha_Envio de una fila
ya enviada no se modifica. Los contadores de pagos revisados no son iguales al
numero de nuevas marcas. No se modificaron el parametro INT pDays ni el orden
externo sin RFC; esas diferencias/condiciones siguen documentadas.

## Transacciones y errores

Sin transaccion externa:

1. LOG_START(604) queda antes del lote, como el inicio confirmado Oracle.
2. RF_PROCESOS_LOG y todas las inserciones 604 se ejecutan en una transaccion.
   Un error previo al cierre revierte esa unidad y registra el error fuera de ella.
3. Se confirma 604 antes de llamar al control 889.
4. El control confirma cada iteracion externa y su cierre final. Un error tardio
   revierte su unidad activa y conserva las anteriores ya confirmadas.

Con transaccion externa local se usan savepoints, sin COMMIT ni rollback total
del trabajo ajeno. Los cambios/logs siguen sujetos al commit/rollback del llamador.
Esto es una adaptacion deliberada: no se reproduce el COMMIT Oracle del trabajo
previo del llamador. Si XACT_STATE=-1, no es posible escribir el log ni volver a
savepoint: se relanza el error original y el propietario debe revertir todo.
En errores recuperables se mantiene el contrato de registrar sin relanzar.
Ver [savepoints](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/save-transaction-transact-sql)
y [XACT_STATE](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql).

Se usa IMPLICIT_TRANSACTIONS OFF dentro de ambos procedimientos y
CURSOR_CLOSE_ON_COMMIT OFF dentro del control. Las opciones se restauran al
volver al llamador. Las pruebas verifican la restauracion y ausencia de fugas.
No se certifica soporte de savepoints en transacciones distribuidas.

604 sigue cerrando antes de 889. Un fallo del control puede registrarse sin
relanzarse; Fin/Status=1 de 604 no acreditan exito de 889 ni timbrado.

## Pruebas y evidencia

Comprobacion posterior solicitada sobre cero: Run.ps1 -ValidarCero paso con los
fuentes completos vigentes. Una base 0 se inserta sin error; con pago anterior
100 y pago actual 50, conserva Importe_Factura=0, Saldo_Anterior=-100 y
Numero_Pago=2. Venta T3 cero conserva tasa 0 sin dividir por cero. SAT positivo
puede sustituir base 0 por 348. Evidencia:
[LastZeroAmount.txt](tests/PROC_CFDI_PROCESAR_PAGOS/LastZeroAmount.txt).

Esta comprobacion **no cambia la fuente del importe**: FN_TOTAL_FACT SQL sigue
devolviendo 0 sin detalle, pero PAGOS vigente no la invoca para ese calculo;
su SUM local conserva NULL sin filas. Aceptar cero no convierte automaticamente
la ausencia de detalle en cero. No se autorizo ni aplico un cambio adicional
de esa regla durante la comprobacion. No se accedio a la base real.

Motor: SQL Server 2025 LocalDB 17.0.4025.3. Se crearon bases desechables,
con DDL reales del repositorio y fuentes completos; EAI auxiliar tiene estructura
minima de prueba. Todas las bases temporales se eliminaron. No se accedio a
T3QA/produccion ni se ejecuto un motor Oracle.

| Prueba | Resultado / evidencia |
| --- | --- |
| Regresion funcional LOCAL/GLOBAL | Fechas, historial, CM, venta/preventa, UUID, penalizacion/cancelacion, lote vacio y limpieza tras 8115; [LastRun.txt](tests/PROC_CFDI_PROCESAR_PAGOS/LastRun.txt). |
| Veinte escenarios SAT/fiscales | Umbral, NULL/vacio/ausente, negativos/cero, redondeo NUMBER(4), MAX textual, generico y RFC vacio; [LastOracleParity.txt](tests/PROC_CFDI_PROCESAR_PAGOS/LastOracleParity.txt). |
| Ramas y cardinalidad | SAT despues de penalizacion/cancelacion/venta; dos CFDI generan dos filas. |
| Atomicidad y llamador | 8114/8115, rollback tras procesar una fila previa, savepoint, transaccion externa condenada, exito sin commit externo y opciones restauradas. |
| Control real de reglas | 8 grupos, 3 inconsistencias, 6 pagos revisados y 5 filas nuevas marcadas; IDs duplicados/NULL, empate, genericidad, espacios finales, CM y enviados. |
| Error tardio de 889 | Sobreviven las 20 inserciones 604 y grupo 889 anterior; se revierte el grupo fallido, se conserva log/error y una nueva ejecucion puede completarlo. |
| Validador | Reconoce base NULL conforme Oracle y multiplicidad CFDI sin falso excedente. |
| Muestra de lecturas 14/10 | Seis filas, cancelacion 20723.95 y parcialidades; V2363-145780 sin detalle pasa de base cero/saldo negativo a NULL/NULL; [LastRealRun.txt](tests/PROC_CFDI_PROCESAR_PAGOS/LastRealRun.txt). |

La muestra capturada no exporto configuracion SAT ni importes CFDI: se probaron
con datos sinteticos, no se dedujo su impacto real. LastRealRun_AntesParidadOracle.txt
y BaselineOracleParity conservan la etapa anterior. El modo AnalizarDependencias
reproduce el defecto usando esos fuentes historicos, no los corregidos.

Las pruebas comparan resultados esperados de la lectura Oracle contra SQL.
No certifican igualdad entre motores, NLS/collation, precision en todas las
expresiones, concurrencia o calidad fiscal de los datos reales. GETCONV con
duplicados queda expresamente conservada por decision del usuario.

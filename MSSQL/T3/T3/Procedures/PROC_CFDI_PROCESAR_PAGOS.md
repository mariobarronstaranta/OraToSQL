# T3.PROC_CFDI_PROCESAR_PAGOS

Revision: **23 de octubre de 2026**. Fuente local con DATE, `PAGOS_CURSOR_BIND_V1`
y correccion de reglas Oracle `PAGOS_ORACLE_PARITY_V1`/`PAGOS_SAT_AMOUNT_V1`.
La nueva entrega esta probada en LocalDB; la evidencia recibida a las 13:49:52
del 23/10 corrobora en T3QA las marcas esperadas de ambos procedimientos.
Pendiente validar el siguiente lote. Ver [verificacion de instalacion](../../Diagnosticos/Pagos_20261023/VERIFICACION_INSTALACION_20261023.md).
La corrida real de 326 inserciones acredita la etapa anterior de DATE/cursores.
Ver [cambios, pruebas y orden de aplicacion](PROC_CFDI_PROCESAR_PAGOS.CAMBIOS_ORACLE.md).

## Contrato y alcance

Prepara registros de `T3.CFDI_COBRANZA` desde las asignaciones del dia BATMD.
No llama directamente al PAC ni acredita envio o timbrado de comprobantes.

```sql
ALTER PROCEDURE [T3].[PROC_CFDI_PROCESAR_PAGOS]
    @dtFechaProcBATMD DATETIME
```

El parametro es obligatorio, sin valor predeterminado. Se compara como DATE,
pero se conserva su valor original, incluida la hora, al escribir BATMD en
cobranza/bitacora y Fecha_Envio del RFC generico. DATE es un tipo de dato; no se
formatean cadenas de texto para comparar. Un parametro NULL no selecciona
asignaciones; aun se ejecutan inicio, cierre y control posterior.

No hay parametros OUTPUT, conjunto de resultados ni codigo RETURN de negocio.
El resultado se verifica mediante escrituras y bitacoras. Un EXEC que termine
sin excepcion no acredita procesamiento completo: en errores recuperables el
CATCH registra sin THROW. Una transaccion externa no confirmable relanza el error.

El [analisis previo de paridad](PROC_CFDI_PROCESAR_PAGOS.PARIDAD_ORACLE.md)
identifico omisiones ahora corregidas: SAT, total fiscal NULL local, cadenas,
cursor y actualizacion del control, y limites transaccionales. GETCONV queda
sin cambios por decision del usuario. No se certifica igualdad entre motores.
La llamada esta comentada en los fuentes locales
de WA_CFDI_COBRANZA; eso no demuestra que este deshabilitado en la base instalada.

## Flujo de procesamiento

1. Obtiene un PID de `EAI_OWNER.ProcessID`; `LOG_START(604)` marca Status=2 y
   Last_Run en MX_COMPONENTS. Inserta inicio en RF_PROCESOS_LOG.
2. Lee sociedad y banco/cuenta receptores mediante GETCONV y CFG Settings.
3. ScrPagos selecciona las asignaciones del dia, exige cliente vigente y carga
   datos fiscales si existen. Ordena por cliente, fecha e identificador.
4. Reinicia salidas por asignacion, determina el documento relacionado y el
   importe de factura, y obtiene UUID cuando corresponde. Aplica la sustitucion
   SAT si RFC/configuracion/importe cumplen las condiciones Oracle.
5. Recorre historial para capturar saldo y acumulados anteriores al movimiento.
6. Inserta una fila en CFDI_COBRANZA, incluso sin UUID o con PendienteT3.
7. Libera ScrPagos, marca Status=1 y Fin. Proceso_1 cuenta iteraciones del cursor,
   no facturas distintas; Proceso_2/3/4 quedan cero.
8. Confirma la transaccion propia del lote, antes de `WA_CFDI_COBZA_ASIG_CTRL 3,0`.
   El control revisa inconsistencias de formas de
   pago por RFC/asignacion central en los ultimos tres dias segun Fecha_Proceso.
   Puede actualizar Fecha_Envio; no se limita al lote BATMD solicitado y tiene
   componente 889 y CATCH propios; confirma por iteracion si es propietario de
   la transaccion. Con llamador externo ambos usan savepoints sin confirmar su trabajo.

Fin y Status=1 del componente 604 se escriben antes del punto 8; no acreditan
el exito del control posterior ni del envio al PAC.

## Comparaciones de fecha

```sql
CAST(AP.Fecha_Proc_BATMD AS DATE) = CAST(@dtFechaProcBATMD AS DATE)

CAST(AP.Fecha_Asignacion AS DATE)
    BETWEEN CAST(Cte.Fecha_Ini_Vig AS DATE)
        AND CAST(Cte.Fecha_Fin_Vig AS DATE)

CAST(Asig.Fecha_Asignacion AS DATE) >= CONVERT(DATE, '20180901', 112)
```

La vigencia incluye los dias inicial y final completos. Vigencias NULL no
coinciden; un cliente sin vigencia coincidente excluye la asignacion por INNER
JOIN. Vigencias solapadas pueden duplicarla. No se reparan datos de vigencia.
El historial empieza el 01/09/2018 y conserva el orden cronologico con hora.
La validacion del anio centinela 2999 y los IS NULL no dependen de la hora.

## Cursores y ciclo de vida

Todos los cursores son LOCAL, independientemente de CURSOR_DEFAULT de la base.

| Cursor | Filtro y momento de declaracion | Uso |
| --- | --- | --- |
| ScrPagos | Parametro BATMD; una vez antes del TRY. | Seleccion y recorrido principal. |
| ScrDebitNote | @strFactura asignada en esta iteracion; antes de OPEN en la rama no Nota de Venta. | Busca preventa por Referencia y su CFDI. |
| ScrCancPago | @strFactura asignada; despues del recorrido de ScrDebitNote. | Busca DEBIT_NOTE_IFC y sustituye datos de cancelacion. |
| ScrT3Procesado | @strFactura asignada; dentro de la rama Nota de Venta. | Agrega detalle de factura y preventa. |
| ScrVentaUUID | @sNota_Venta recuperada del documento T3; solo en la rama procesada. | Recupera UUID con Status=CONFIRMADO. |
| ScrAsignaciones | @strID asignada; dentro de la iteracion si Factura no es INCOBRABLE literal. | Reconstruye saldo y parcialidad desde el historial. |

Los cinco internos se declaran inmediatamente antes de OPEN, se cierran y se
liberan al terminar cada recorrido. No adelantar las declaraciones: SQL Server
captura sus filtros al declararlos, como confirmaron LocalDB y el reproductor
de lectura en T3QA. Se retiraron los DEALLOCATE finales incondicionales, porque
una rama puede no haber declarado su cursor o haberlo liberado ya.
El CATCH usa CURSOR_STATUS local para limpiar los que sigan declarados.

ScrT3Procesado combina factura/preventa con UNION ALL y exige detalle por INNER
JOIN; un encabezado sin partidas no aparece. Historia PAC puede generar varios
grupos. Las busquedas de documento/UUID no tienen ORDER BY: con varias filas
se conservan los ultimos valores recuperados, sin seleccion determinista.

## Reglas de documento e importe base

| Condicion | Resultado actual |
| --- | --- |
| Sin Registro_Fiscal/Tipo_Documento.Origen | Sub_Type_CD=INCOBRABLE; no equivale a Factura literal INCOBRABLE. |
| Origen distinto de Nota de Venta | Suma fiscal local (NULL sin detalle) y estado igual al origen. Busca penalizacion y luego cancelacion. |
| Preventa por Referencia | Nota_Venta y UUID relacionado; estado DN - Penalizacion. |
| Coincidencia posterior en DEBIT_NOTE_IFC | Canc Pago; sustituye importe, fecha y Nota_Venta; vacia UUID. Prevalece sobre penalizacion. |
| Nota de Venta con detalle y fecha BATMD procesada | Importe agregado T3; referencia y documento PAC; toma el ultimo UUID CONFIRMADO recuperado. |
| Nota de Venta sin detalle o fecha BATMD NULL/anio 2999 | PendienteT3, suma fiscal local y tasa cero; no impide insertar. |
| Tasa calculada >=15.98 | Fija 16, incluso si la tasa original es mayor de 16. |
| Nota de Venta procesada sin otra condicion | Status de cobranza NULL, equivalente al vacio Oracle; CONFIRMADO es del documento fiscal. |
| RFC no vacio/no generico, configuracion SAT >1 e importe SAT >0 | Sustituye el total tras ambas ramas y antes del saldo; no exige UUID/CONFIRMADO. |
| RFC XAXX010101000 | Fecha_Envio toma el parametro BATMD; no prueba envio real. |
| Factura literal INCOBRABLE | No recorre historial; Via_Pago=AI y Nota_Credito origen. |

PAGOS obtiene localmente la suma de VALOR_SUBT, VALOR_IVA, ENVIO_SUBT, ENVIO_IVA,
CREDITO_SUBT y CREDITO_IVA de REGISTRO_FISCAL_DETALLE. Componentes NULL aportan
cero y el resultado se convierte a DECIMAL(18,2). Sin filas conserva SUM=NULL,
como FN_TOTAL_FACT Oracle, cuyo NO_DATA_FOUND no se activa por ese agregado.
La [funcion SQL compartida](../Funciones/FN_TOTAL_FACT.SQL) conserva retorno cero
sin detalle para sus otros consumidores; no se modifica ni se invoca desde PAGOS.
No suma ISSA ni bonificaciones. GETCONV conserva Source si no encuentra
una conversion; si encuentra Target NULL, mantiene NULL. No hay validacion de
longitud/contenido de esas configuraciones en el procedimiento.

Con varios matches, Oracle GETCONV conserva el ultimo recuperado y SQL TOP(1).
Sin ORDER BY ni unicidad comprobada no se garantiza igualdad con Targets
diferentes. Se mantiene GETCONV intacta por decision del usuario. El control
ya declara ScrPagos despues de asignar filtros y actualiza la fila mediante
WHERE CURRENT OF, sin usar Asignacion_ID como clave unica.

La ruta de Nota de Venta procesada puede tomar importes de FACTURA_DETALLE o
PREVENTA_DETALLE; las otras rutas usan el detalle fiscal o DEBIT_NOTE_IFC.
El SQL ahora sustituye esa base por subtotal mas IVA de CFDI_DOCUMENTOS cuando
MAX textual del catalogo SAT Amount Invoice por RFC, convertido a NUMERIC(4,0),
es >1 y el importe es positivo. Importe SAT usa NUMERIC(13,3). Se conserva el
outer join directo y su multiplicidad. Su impacto real aun no se midio.
No se compensan diferencias entre origenes. Un encabezado sin detalle procedente
de la excepcion autorizada para R044 en INVOICE_TO_FACTURA solo se trataria como
PendienteT3 si primero se clasifica como Nota de Venta y no hay otra rama de
detalle coincidente; no es una clasificacion automatica de cualquier encabezado vacio.

## Saldo, parcialidad y acumulados

El saldo empieza en el importe base de la factura. ScrAsignaciones lee toda la
historia desde 01/09/2018, no solo el lote, ordenada por Fecha_Asignacion y
Asignacion_ID. Al alcanzar la asignacion actual captura los acumulados **antes**
de aplicarla. Un pago normal recibe pagos anteriores+1; una nota de credito
conserva la secuencia de pagos. Luego acumula el movimiento y resta Paid_Amt,
respetando el signo. Sigue recorriendo el historial despues de encontrarla.

Cant_Pagos, Abono_Pagos, Cant_CM y Abono_CM representan movimientos anteriores,
no totales finales ni el movimiento actual. No se limita el saldo a cero.
Si no encuentra la asignacion, usa su fecha origen y puede mantener NULL el
saldo/numero. La factura literal INCOBRABLE tambien omite ese calculo.

Nota_Credito no NULL ni vacia clasifica Returns/CM; espacios no se eliminan.
La alternativa LEN(Referencia)>0 no se activa porque el cursor
proyecta Referencia=NULL. El JOIN del historial con CFDI_Cobranza puede multiplicar
movimientos si una asignacion tiene varias coincidencias; no hay deduplicacion.
Los Numero_Pago/Cant_CM recuperados de ese JOIN no gobiernan el calculo.

## Campos escritos en CFDI_COBRANZA

| Campos | Procedencia o regla |
| --- | --- |
| Folio_ID, Asignacion_ID, Pago_ID | Los dos primeros son Asignacion_ID de AP; Pago_ID es AP.Pago_ID. |
| Fecha_Asignacion, Fecha_Pago | Fecha_Asignacion del historial, con fallback a la de AP; Fecha_Pago usa AP.Fecha_Asignacion, no Pago.Fecha_Pago. |
| Importe, Saldo_Anterior, Numero_Pago | Importe AP o Paid_Amt al encontrar la asignacion; saldo y secuencia calculados. |
| Cant_Pagos, Abono_Pagos, Cant_CM, Abono_CM | Acumulados anteriores a la asignacion. |
| Accnt_ID, Created_By, DB_Last_Upd | Accnt_ID=''; Created_By=AP.Rep_ID; DB_Last_Upd=AP.Fecha_Trn. |
| Factura, Cliente_SAP, Ctro, RFC | Factura/cliente/centro de AP y RFC del cliente vigente. |
| Fecha_Factura, Dias_Cdto, Importe_Factura | Fecha fiscal o de cancelacion, dias del cliente vigente e importe base determinado por la ruta. |
| Banco_Nombre, Banco_Num_Cuenta, Numero_Cheque | NULL proyectado por ScrPagos, equivalente al vacio Oracle. |
| Master_Banco, Master_Cuenta, Receptor_Banco, Receptor_Cuenta | Maestros NULL; receptores de CFG Settings mediante GETCONV. GET_CUSTOMERPAYMENT_INFO no se invoca. |
| Sociedad, Fecha_Proc_BATMD, Fecha_Proceso | Sociedad configurada, parametro original y GETDATE() al insertar. |
| Nota_Venta, Referencia, UUID_Venta | Documento relacionado, referencia recuperada de T3 y UUID segun la ruta; pueden estar vacios o NULL. |
| Status, Via_Pago, Nota_Credito | Estado de ruta; metodo convertido/CM/AI; nota de credito aplicable. |
| Fecha_Envio, Tasa_IVA | Marca del RFC generico y tasa de ruta T3; en otras rutas pueden quedar NULL. El control posterior puede modificar Fecha_Envio. |

Asig_Actl_Pay_dt y Asig_Created_By se recuperan del cursor pero no se usan para
escribir Fecha_Pago/Created_By. Tampoco sCteMethod se usa en el INSERT.

## Dependencias y escrituras

| Objeto | Acceso |
| --- | --- |
| ASIGNACION_PAGO, CLIENTE | Lectura de lote, historial y vigencia. |
| REGISTRO_FISCAL, TIPO_DOCUMENTO | Lectura para fecha y clasificacion. |
| REGISTRO_FISCAL_DETALLE | Suma fiscal local con OUTER APPLY; NULL sin detalle. |
| PAGO | Lectura de tipo/metodo, fecha y representante. |
| FACTURA_GENERAL/DETALLE, PREVENTA_GENERAL/DETALLE | Lectura y agregacion de documentos. |
| CFDI_HISTORIA_DOCTO_PAC, CFDI_DOCUMENTOS, DEBIT_NOTE_IFC | Lectura de relaciones fiscales, UUID y cancelaciones. |
| CFDI_COBRANZA | Lectura en historial e INSERT de resultados; control posterior puede actualizarla. |
| RF_PROCESOS_LOG | INSERT de inicio y UPDATE de fin/contadores. |
| EAI_OWNER.MX_COMPONENTS | LOG_START actualiza Status=2/Last_Run; cuerpo marca Status=1. |
| EAI_OWNER.MX_EAI_MESSAGE_LOG | INSERT del CATCH. |
| EAI_OWNER.ProcessID | Consumo de secuencia para PID. |
| EAI_OWNER.MX_HashTable | Lectura directa de SAT Amount Invoice y lectura mediante GETCONV. |
| EAI_OWNER.GETCONV, EAI_OWNER.LOG_START | Configuracion/conversion y bitacora; sin cambios a estos objetos. |
| T3.WA_CFDI_COBZA_ASIG_CTRL | Control posterior, bitacoras y transacciones por iteracion. |

Las tablas sin prefijo en esta tabla pertenecen a T3. El inventario describe
referencias del codigo, no todos los triggers ni dependencias de la base real.

## Errores, transacciones y pendientes

El lote abre transaccion despues de LOG_START si no hay una externa y confirma
antes del control 889. El CATCH revierte la unidad activa, limpia cursores y
registra el error sin continuar a la siguiente asignacion. En ese rollback se
revierte tambien el inicio RF_PROCESOS_LOG; Status=2 de LOG_START puede persistir.
Con transaccion externa usa savepoint y respeta su propietario; si XACT_STATE=-1
relanza el error original sin intentar log ni rollback total ajeno. El control
aplica limites por iteracion y puede registrar un error sin propagarlo.
Ver contrato detallado en el informe de cambios.

Pendientes distintos de DATE/cursores: idempotencia de reejecuciones, duplicados
en JOIN, seleccion de multiples documentos, configuracion ausente, tipos
estrechos (NUMERIC(16,4), contador NUMERIC(1,0), longitudes 50 hacia 30) y estado
por defecto INCOBRABLE. No ejecutar repetidamente un lote como prueba sin
considerar que no hay DELETE/UPDATE/NOT EXISTS antes del INSERT.

## Indice conocido y rendimiento

El usuario confirmo en T3QA `IDX_T3_ASIGNACION_PAGO_FECHA_PROC_BATMD`, clave
FECHA_PROC_BATMD e INCLUDE PAGO_ID, ASIGNACION_ID, FECHA_TRN, FACTURA,
NOTA_CREDITO, CLIENTE_SAP, REP_ID, FECHA_ASIGNACION, VALOR_PAGO y CTRO.
Cubre las columnas AP de ScrPagos; no se ha recibido un plan/IO que cuantifique
la mejora con CAST AS DATE. INCLUDE no aporta el orden del cursor ni una clave
de busqueda Factura para el historial. No se confirmo despliegue en produccion.
Ver [contexto de indices](../../../../Docs/T3QA_INDICES_CONTEXTO.md).

## Validacion y evidencia

- Prueba sintetica completa con FN_TOTAL_FACT, GETCONV, LOG_START, control posterior
  y DDL T3 reales del repositorio: fechas, limites de vigencia, historial/CM,
  parcialidades, factura/preventa, UUID, penalizacion/cancelacion y lote vacio/NULL.
- Pasaron CURSOR_DEFAULT LOCAL y GLOBAL, y un 8115 controlado con cursor abierto,
  limpieza y siguiente ejecucion exitosa. Ese error esperado lo induce la prueba;
  no es un fallo pendiente de la correccion.
- [Captura del 14/10 y analisis](../../Diagnosticos/Pagos_20261014/ANALISIS.md): ocho
  facturas/diez asignaciones, seis elegibles. Con DATE y cursores corregidos se
  recuperan seis saldos/parcialidades y CHD-33522 como Canc Pago por 20723.95.
- V2363-145780 ahora conserva base/saldo NULL por ausencia de detalle, como Oracle.
  Cero y -194.05 corresponden a la etapa anterior. Faltan encabezados
  fiscales en la muestra y cuatro clientes estan fuera de vigencia. Las pruebas
  no reparan esos datos ni garantizan correccion de todas las reglas de negocio.

[Ejecutor y limites](tests/PROC_CFDI_PROCESAR_PAGOS/README.md), LastRun.txt y
LastRealRun.txt contienen la evidencia vigente. LastRealRun_AntesCursores.txt y
la captura preservan el defecto anterior. El codigo 52013 pertenece a una
asercion del ejecutor y no aparece como fallo en la prueba vigente satisfactoria.
Las bases temporales fueron eliminadas. Se indujeron errores mediante un trigger
sintetico; no se simularon los triggers, indices, concurrencia ni permisos del
ambiente instalado. Las reglas SAT y transacciones nuevas estan probadas en
[LastOracleParity.txt](tests/PROC_CFDI_PROCESAR_PAGOS/LastOracleParity.txt).

## Aplicacion y verificacion en T3QA

Para esta nueva entrega aplicar primero el control 889 y despues
[el archivo PAGOS](PROC_CFDI_PROCESAR_PAGOS.sql), completos con USE T3QA y ALTER.
Ver [orden y alcance](PROC_CFDI_PROCESAR_PAGOS.CAMBIOS_ORACLE.md).
Conservan DATETIME de entrada y UTF-16 LE. Los metadatos recibidos corroboran
ambos ALTER en T3QA; pendiente validar un lote posterior.
La corrida anterior de 326 filas solo cubre DATE/cursores. No se confirmo produccion.

Tras el siguiente procesamiento normal, comprobar la definicion instalada,
las filas de cobranza, saldos, parcialidades y documentos, ademas de las bitacoras
de procesos 604/889 y errores. Un componente cerrado sin errores no basta.
El [script de lectura](../../Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_LECTURA.sql)
permite recopilar evidencia sin ejecutar procedimientos ni alterar tablas reales.

La [validacion recibida del 23/10](../../Diagnosticos/Pagos_20261014/VALIDACION_REAL_20261023.md)
confirma PID 26515865: 326 elegibles/insertadas/contador, cero faltantes,
excedentes, errores y saldos/parcialidades NULL. Otras 144 quedaron fuera por
vigencia. Veinte calculos de historial coinciden. Las 324 facturas procesadas
carecen de encabezado fiscal en la lectura; 264 filas tienen base cero, incluida
una con saldo -194.05. La correccion de cursores no repara esos datos.
El [validador posterior](../../Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql)
selecciona el PID 604 del lote, compara elegibles contra CFDI_COBRANZA en la
ventana de ejecucion y muestra faltantes, duplicados, saldos, parcialidades,
errores y candidatos de control 889. Sus
[criterios y limites](../../Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.md)
explican por que terminar sin excepcion no acredita exito funcional.

La revision documental inicial del 23/10 preservo tokens/literales. Esta entrega
posterior si contiene cambios funcionales de paridad, detallados y probados en
CAMBIOS_ORACLE; no confundir ambas etapas.

# Analisis de T3.PROC_CFDI_PROCESA_PAGO_AGR

Revision del 27 de octubre de 2026 sobre el [fuente SQL Server](PROC_CFDI_PROCESA_PAGO_AGR.sql)
y la [contraparte Oracle](../../../../ORA/T3/T3/Procedures/PROC_CFDI_PROCESA_PAGO_AGR.SQL).
Se agregaron comentarios para developers Jr, sin modificar instrucciones
ejecutables. No se consulto ni modifico una base remota; la definicion instalada
puede diferir del archivo revisado.

## Proposito y contrato

Prepara agrupaciones de cobranza como proceso 109 y despues invoca el proceso
614, responsable de liberarlas. La implementacion SQL usa operaciones por
conjuntos y una tabla temporal local, sin cursores.

Recibe `@nDias NUMERIC = NULL`, equivalente a NUMERIC(18,0) en SQL Server.
El limite utilizado es la medianoche de GETDATE menos ISNULL(@nDias,0) dias.
Se compara Fecha_Proceso con `>`: el instante exacto de medianoche queda
fuera. NULL usa cero para filtrar, pero Proceso_4 conserva el NULL recibido.
No hay validacion de signo: un negativo desplaza el limite hacia el futuro.
Los calculos con GETDATE se repiten en distintas instrucciones y pueden
variar si la ejecucion cruza medianoche o cambio de anio.

No devuelve parametros OUTPUT ni un SELECT propio de resultados de negocio.
Puede imprimir errores y heredar mensajes del procedimiento llamado.
El catalogo de jobs contiene ORA_668_T3_PROC_CFDI_PROCESA_PAGO_AGR, con llamada
al procedimiento pasando 4. Esto no acredita el estado instalado del job.

## Recorrido de datos

1. Obtiene el PID de SEQ_CFD; no llama LOG_START para el componente 109.
2. Actualiza Asignacion_Central de cobranzas desde tmp_Account_Header,
   enlazando posiciones 3..12 de Asignacion_ID con ClearingDocNumber,
   FiscalYear del anio actual y Registro_Fiscal por Factura.
3. Selecciona pendientes recientes y resume seis claves en #Grupos.
4. Agrega un ID de SEQ_PAGO_CENTRAL_AGR por cada grupo.
5. Inserta los controles en CFDI_Agrupacion_CTRL, copiando sus agregados.
6. Vuelve a consultar CFDI_Cobranza y vincula asignaciones con los grupos
   nuevos en CFDI_AGRUPACION_PAGO.
7. Marca Fecha_Envio en cobranzas elegibles relacionadas por Asignacion_ID.
8. Elimina #Grupos e inserta inicio/fin y contadores del proceso 109.
9. Llama PROC_CFDI_LIBERA_PAGO_CENTRAL sin parametros, incluso sin grupos nuevos.

`CFDI_Cobranza.Fecha_Envio` se marca al agrupar. No significa que el layout
haya sido generado o timbrado. `CFDI_Agrupacion_CTRL.Fecha_Envio` es otra
marca: la actualiza el generador de pagos agrupados cuando prepara su salida.
El liberador revisa sus propios pendientes, no recibe los IDs de #Grupos ni
el PID de esta corrida, y puede atender controles de otras corridas.

## Filtros y claves para mantenimiento

El UPDATE inicial solo considera cobranzas recientes sin Asignacion_Central.
Excluye asignaciones iguales a Entrega, el literal B001 - Bank I, Factura
seguida de coma, prefijo 1-1 y Referencia fiscal. ISNULL(Assignment,Entrega)
participa en las comparaciones; valores NULL pueden impedir que se cumplan.
El ejercicio contable es el anio actual, aunque @nDias incluya dias del anio
anterior. Varias coincidencias de Acc para una misma cobranza no expresan una
prioridad unica en UPDATE FROM.

Para crear #Grupos se exige:

- Fecha_Envio NULL y Fecha_Proceso posterior al limite calculado.
- Created_By distinto de INTERFACE; tambien se excluye NULL con `<>`.
- Via_Pago fuera de 01, CM y AI; NULL queda fuera del NOT IN.
- Status distinto de Debit Note y Canc Pago. NULL se reemplaza por '1' y pasa.
- RFC distinto de XAXX010101000; RFC NULL queda fuera de la comparacion.
- Ausencia de la Factura en WA_Factoraje mediante NOT EXISTS.

| Clave de grupo | Normalizacion |
|---|---|
| Fecha_Pago | CAST AS DATE: agrupa por dia, sin la hora. |
| RFC | Valor de la cobranza. |
| Via_Pago | NA se convierte en 03. |
| Banco_Nombre | NULL se convierte en NoBanco. |
| Banco_Num_Cuenta | NULL se convierte en NoCuenta. |
| Asignacion_Central | NULL se convierte en NoAsigna. |

SUM(Importe) ignora NULL; si todos los importes son NULL devuelve NULL.
COUNT(Importe) cuenta solo importes no NULL, no todas las cobranzas.
MAX(Accnt_ID) y MAX(Cliente_SAP) se calculan por separado: pueden provenir
de filas diferentes. Ninguno es una clave de agrupacion.

Los centinelas se convierten en cadena vacia al insertar el control, pero
#Grupos conserva sus textos para enlazar el detalle. Un valor real NoBanco,
NoCuenta o NoAsigna comparte clave con NULL en esta implementacion.
Un Fecha_Pago NULL permite formar un grupo, pero no pasa el JOIN de detalle
por igualdad NULL=NULL. Revisar calidad de datos antes de asumir detalle
para cada control insertado.

## Dependencias y tablas afectadas

| Dependencia directa | Uso |
|---|---|
| [T3.PROC_CFDI_LIBERA_PAGO_CENTRAL](PROC_CFDI_LIBERA_PAGO_CENTRAL.sql) | Unica llamada EXEC del procedimiento. Sin parametros, despues de la bitacora del proceso 109. Ver su [analisis](PROC_CFDI_LIBERA_PAGO_CENTRAL.md). |
| SEQ_CFD | Secuencia que entrega el PID. No es EAI_OWNER.ProcessID. |
| SEQ_PAGO_CENTRAL_AGR | Secuencia que entrega Agrupacion por fila de #Grupos. |

No llama funciones de usuario directamente. GETDATE, DATEADD, YEAR,
SUBSTRING, ISNULL, CAST/CONVERT, SUM, COUNT, MAX y LEFT son funciones o
agregados del motor. Las secuencias aparecen sin esquema en el fuente;
el validador de jobs espera T3.SEQ_CFD y T3.SEQ_PAGO_CENTRAL_AGR. No se
localizaron sus CREATE SEQUENCE para certificar rangos y opciones.

Indirectamente, el liberador utiliza EAI_OWNER.LOG_START,
T3.PROC_CFDI_LIBERA_PAGO_CHECK, T3.PROC_V20_GENERAR_PAGO_AGR,
EAI_OWNER.GETCONV y EAI_OWNER.ProcessID. El generador agrega las funciones
FN_TRIM_CFDI, FN_NUM_TO_CHAR_CFDI, FN_CTRO_EDICOM_PAGO y SeparaDireccion.
No se revisan aqui nuevamente sus implementaciones completas ni se certifica
el flujo de timbrado.

| Objeto | Acceso directo |
|---|---|
| T3.CFDI_COBRANZA | Lectura; UPDATE de Asignacion_Central y Fecha_Envio. |
| EAI_OWNER.TMP_ACCOUNT_HEADER | Lectura de compensacion/ejercicio/asignacion. |
| T3.REGISTRO_FISCAL | Lectura de Entrega/Referencia para la asignacion inicial. |
| T3.WA_FACTORAJE | Lectura para excluir facturas de factoraje. |
| #Grupos | Tabla temporal local con el resumen, a la que se agrega Agrupacion. |
| T3.CFDI_AGRUPACION_CTRL | INSERT de controles. No hay reconciliacion posterior de importe, cantidad o Cliente_SAP. |
| T3.CFDI_AGRUPACION_PAGO | INSERT de relaciones Agrupacion/Asignacion_ID y lectura para el marcado. |
| T3.RF_PROCESOS_LOG | INSERT de una fila con inicio y fin al terminar la agrupacion, antes de liberar. |
| T3.RF_ERROR_LOG | INSERT del error recibido por esta rutina. |

## Contadores y significado de finalizacion

| Campo de bitacora | Significado en el SQL revisado |
|---|---|
| Proceso_1 | Numero de filas de #Grupos. Sobrescribe el @@ROWCOUNT del UPDATE inicial. |
| Proceso_2 | Filas insertadas en CFDI_AGRUPACION_PAGO; pueden diferir del conteo de importes no NULL. |
| Proceso_3 | Cero; no se incrementa. |
| Proceso_4 | @nDias original, incluido NULL. |
| Fin | Se calcula antes de llamar al liberador; no mide la duracion ni el exito del proceso 614. |

El liberador aplica filtros adicionales: Fecha_Pago desde 01/01/2022,
Accnt_ID distinto de Contado y no NULL, contadores del CHECK y version 4.0
para generar. Un control creado por 109 no queda automaticamente liberado.
Los CATCH de esa cadena pueden registrar errores sin THROW; el retorno de
EXEC no es una confirmacion funcional de generacion o timbrado.

## Diferencias con Oracle y riesgos pendientes

| Hallazgo | Diferencia o consecuencia |
|---|---|
| Importe y cantidad finales | Oracle recalcula ambos desde los detalles que realmente recorre. SQL conserva SUM/COUNT(Importe) del resumen inicial y no reconcilia despues. |
| Cliente_SAP final | Oracle obtiene MAX(NVL(RF.Clte_Factura_SAP,RF.Cliente_SAP)) mediante el detalle, cobranza y Registro_Fiscal. SQL mantiene MAX(Cobza.Cliente_SAP) del resumen. |
| Ventana del detalle y marcado | El detalle no filtra Fecha_Proceso, como tampoco lo hace ScrDetalle de Oracle. Pero SQL si limita por esa fecha el marcado final; Oracle marca por ROWID cada fila seleccionada en el detalle. |
| Identidad para marcar | SQL enlaza Asignacion_ID con EXISTS; Oracle identifica cada fila por ROWID. IDs repetidos pueden causar alcances diferentes. |
| Agrupacion de NULL/centinelas | Oracle agrupa por los campos de banco/cuenta/asignacion sin normalizar y proyecta NVL. SQL tambien normaliza en GROUP BY, lo que puede fusionar grupos que Oracle separaba. |
| Factoraje y NULL | Oracle usa NOT IN; un NULL en su subquery puede excluir filas por UNKNOWN. SQL usa NOT EXISTS y no tiene ese bloqueo global. No afirmar equivalencia bajo todos los NULL. |
| Actualizacion inicial | Oracle actualiza por Asignacion_ID desde cada fila del cursor. SQL actualiza las filas que cumplen sus JOIN/WHERE. Multiplicidad y repeticion de IDs requieren revision de equivalencia. |
| Cadena vacia | Al guardar centinelas, SQL escribe ''; en Oracle la cadena vacia se trata como NULL. Los consumidores pueden distinguirlos en SQL. |
| Transacciones | Oracle confirma tras asignacion inicial, antes y despues de liberar, y hace ROLLBACK en EXCEPTION. SQL activa XACT_ABORT sin BEGIN TRAN/COMMIT/ROLLBACK propios: no hay una unidad atomica de todo el proceso. |
| Error y contexto | @strID no se asigna; el error queda con Referencia NULL. El CATCH no usa THROW y su INSERT puede fallar con una transaccion externa invalidada. |
| Capacidad de tipos | PID NUMERIC(8,0); grupos NUMERIC(10,0); Cantidad_Pagos DECIMAL(4,0) en el DDL del control. Revisar limites antes de grandes volumenes. @nProceso4 NUMERIC(8,0) se inicializa antes del TRY. |
| Concurrencia | #Grupos solo conserva el resumen; el detalle y el marcado vuelven a leer tablas vivas. No hay reserva de candidatos ni barrera contra ejecuciones simultaneas. |

Ejemplo hipotetico derivado de los filtros, no de datos productivos: una
cobranza reciente de 100 y otra antigua de 50 comparten las seis claves y
siguen pendientes. #Grupos puede resumir solo 100/una cobranza; el INSERT
de detalle puede incluir ambas; el UPDATE de marcado puede tocar solo la
reciente. El control SQL permanece en 100/uno, mientras el detalle tiene dos
asignaciones. Oracle vuelve a contar y acumular el detalle, y marca ambas
filas por ROWID. Por ello no basta agregar un filtro al detalle sin decidir
primero que comportamiento funcional se desea conservar.

Con importes NULL tambien hay diferencias: COUNT(Importe) no cuenta la fila;
Oracle vuelve a contar iteraciones. SUM SQL ignora NULL, mientras una suma
escalar de Oracle con un operando NULL puede dejar NULL el acumulador.
No se implemento ningun cambio para estas diferencias.

Las comparaciones por dia de Fecha_Pago ya usan CAST AS DATE en agrupacion
y JOIN. Fecha_Proceso usa un limite temporal con `>`; no es una igualdad
DATETIME contra DATETIME ni un filtro parametrizado por BATMD. No se
homologaron ni modificaron fechas en esta intervencion.

Una fase posterior de performance debe medir JOIN por ClearingDocNumber/
FiscalYear, Factura, Agrupacion/Asignacion_ID y los filtros de pendientes,
asi como las estimaciones de #Grupos. No hay planes ni mediciones de esta
rutina en esta revision: no se crean indices ni se afirma una mejora medida
solo porque la implementacion sea por conjuntos.

## Cambios y comprobaciones realizadas

Solo se agregaron comentarios de etapas, parametros, claves, NULL, fechas,
contadores, dependencias, bitacora, transacciones y diferencias con Oracle.
No se alteraron los filtros ni los pasos pendientes de reconciliacion.

TSql160Parser: cero errores antes y despues. Comparacion de tokens SQL contra
el respaldo, excluyendo comentarios y espacios: identicos. Se conservaron
USE T3QA, GO, opciones SET, ALTER PROCEDURE, parametro y formato UTF-16 LE
con BOM/CRLF. No se ejecutaron operaciones de negocio ni pruebas de envio.

Respaldo de trabajo: tmp/procesa_pago_agr_documentacion_20261027/
PROC_CFDI_PROCESA_PAGO_AGR.antes.sql, SHA256
22BEF2FD9A10499864397DAB5893A2BBA342AB7DE3BF85DCA01BD5355ADB2E10.
La validacion es estatica; no equivale a compilar contra la base instalada
ni a una prueba funcional integral. No se modificaron el liberador, sus
hijos, secuencias, funciones, jobs ni datos.

# Analisis de T3.PROC_CFDI_LIBERA_PAGO_CENTRAL

Revision del 27 de octubre de 2026 sobre el [fuente SQL Server](../PROC_CFDI_LIBERA_PAGO_CENTRAL.sql)
y su [contraparte Oracle](../../../../../ORA/T3/T3/Procedures/PROC_CFDI_LIBERA_PAGO_CENTRAL.SQL).
Se agregaron comentarios para mantenimiento por developers Jr. No se alteraron
instrucciones SQL ni se consulto/modifico una base remota. La definicion
instalada puede diferir de los archivos revisados.

## Proposito y recorrido

Coordina el componente 614 para preparar pagos de agrupaciones centrales.
No recibe parametros ni devuelve un SELECT de resultados de negocio; emite
PRINT y registra bitacoras. No construye directamente el layout ni confirma
una respuesta del PAC o timbrado.

1. Selecciona controles de agrupacion pendientes y calcula su version CFDI.
2. Obtiene un PID de la secuencia compartida, llama LOG_START e inserta el
   inicio en RF_PROCESOS_LOG.
3. Por fila guarda Agrupacion como referencia, reinicia contadores y llama
   PROC_CFDI_LIBERA_PAGO_CHECK con dos parametros OUTPUT.
4. Si nItems es positivo y coincide con nUUIDs, incrementa Proceso_1. Solo
   para version 4.0 llama PROC_V20_GENERAR_PAGO_AGR.
5. Al terminar normalmente, cierra/libera el cursor, marca Status=1 en el
   componente y registra el fin por PID.
6. Ante un error recibido por el coordinador intenta limpiar el cursor e
   insertar la evidencia en MX_EAI_MESSAGE_LOG. No contiene THROW.

Proceso_1 cuenta filas de agrupacion que pasan la condicion del CHECK,
incluidas las que tienen una version no atendida o cuyo generador retorna
tras registrar un error. No cuenta todos los candidatos ni pagos generados
correctamente ni timbrados. Proceso_2/3/4 permanecen en cero.

## Seleccion y configuracion de version

| Regla | Comportamiento observado |
|---|---|
| Fecha_Pago >= CONVERT(DATETIME,'20220101',112) | Corte fijo e inclusivo al 01/01/2022, 00:00. No selecciona el dia actual ni un parametro BATMD. |
| Fecha_Envio IS NULL | Solo controles pendientes de envio. |
| Accnt_ID <> 'Contado' | Excluye Contado y tambien SQL NULL. Es un filtro adicional respecto al Oracle entregado. |
| LEFT JOIN de configuracion por RFC | Permite controles sin configuracion por RFC; en ese caso utiliza GETCONV. No valida el RFC por si mismo. |

La version tiene prioridad por RFC mediante MAX(Valor) para el parametro
VersionCFDI. Valor es texto: MAX no elige por fecha ni valida version numerica.
Si el resultado es NULL, usa GETCONV('CFG Settings','VersionCFDI'). Un valor
vacio no activa ese fallback. Sin equivalencia GETCONV devuelve su entrada,
por lo que no esta garantizada la version 4.0.

El cursor es LOCAL y sus dos FETCH reciben exactamente VersionCFD y Agrupacion.
La consulta SQL no usa Agr.*: no faltan variables para su proyeccion actual.
No declara STATIC ni orden de procesamiento, no hace DISTINCT y no reserva
candidatos para impedir que otra ejecucion los seleccione.

## Contrato real del CHECK

Se reviso [T3.PROC_CFDI_LIBERA_PAGO_CHECK](../PROC_CFDI_LIBERA_PAGO_CHECK.sql).
Sus parametros son:

| Parametro | Valor enviado o recibido |
|---|---|
| @pReference NUMERIC(18,0) | Agrupacion recibida por el coordinador como VARCHAR(50). |
| @pRecords NUMERIC(18,0) OUTPUT | Se copia a @nItems NUMERIC(6,0). |
| @pUUIDs NUMERIC(18,0) OUTPUT | Se copia a @nUUIDs NUMERIC(6,0). |

El CHECK recorre INNER JOIN entre CFDI_AGRUPACION_PAGO, CFDI_COBRANZA y
CFDI_DOCUMENTOS. Incrementa pRecords por fila resultante, no por todos los
registros originales de agrupacion de manera independiente. Filas sin
relacion se omiten; relaciones duplicadas pueden multiplicar conteos.
La igualdad de contadores no prueba integridad completa del grupo original.

Un UUID se cuenta cuando LEN(ISNULL(UUID_Venta,'NULL')) es mayor que 20.
Esto solo comprueba longitud; no valida formato, autenticidad ni unicidad.
El helper tambien cuenta filas con Metodo_Pago=PUE y fechas de asignacion
y factura del mismo dia, ambas convertidas a DATE.

Si pUUIDs>0 y pUUIDs coincide con ese contador de PUE/fechas, el CHECK marca
Accnt_ID='Contado' en CTRL y devuelve pUUIDs=-1. No debe describirse esta
condicion como prueba de que todas las filas originales sean de contado:
el IF del helper no compara pRecords con ese contador. El centinela -1 no
pasa la condicion del coordinador y el filtro Contado excluye el control
en las siguientes selecciones.

El CATCH del CHECK registra RF_ERROR_LOG sin THROW explicito. Si retorna
contadores parciales, no hay una salida adicional de exito para distinguirlos.
Su limpieza de cursor tambien usa >=-1; un fallo durante esa limpieza o el
INSERT puede producir otro error y propagarse al coordinador.
No se localizo la contraparte Oracle del CHECK en el repositorio, por lo
que no se certifica paridad completa de esa validacion.

## Dependencias directas e indirectas

| Objeto directo | Uso |
|---|---|
| [EAI_OWNER.LOG_START](../../../EAI_OWNER/Procedures/LOG_START.SQL) | Recibe 614 y actualiza MX_COMPONENTS.Status=2 y Last_Run. No es un bloqueo de doble corrida. |
| [T3.PROC_CFDI_LIBERA_PAGO_CHECK](../PROC_CFDI_LIBERA_PAGO_CHECK.sql) | Entrega los contadores y puede marcar Contado en CTRL. |
| [T3.PROC_V20_GENERAR_PAGO_AGR](../PROC_V20_GENERAR_PAGO_AGR.sql) | Prepara el pago agrupado para version 4.0. @pFactura recibe Agrupacion; @pOutput se omite y usa 0. |
| [EAI_OWNER.GETCONV](../../../EAI_OWNER/Functions/GETCONV.SQL) | Funcion que resuelve la version general desde MX_HashTable. Se mantuvo sin cambios. |
| [EAI_OWNER.ProcessID](../../../EAI_OWNER/Sequences/ProcessID.SQL) | Secuencia de identificadores; no es funcion ni procedimiento. |

El generador utiliza indirectamente EAI_OWNER.GETCONV, T3.FN_TRIM_CFDI,
T3.FN_NUM_TO_CHAR_CFDI, T3.FN_CTRO_EDICOM_PAGO y T3.SeparaDireccion.
No se observaron EXEC a otros SP dentro de los fuentes del CHECK o del
generador revisados. No se afirma haber validado las implementaciones de
todas esas funciones. FN_VALIDA_RFC no es llamada directa de este coordinador.

## Tablas y marcas de proceso

| Objeto | Acceso e implicacion |
|---|---|
| T3.CFDI_AGRUPACION_CTRL | El coordinador lee candidatos. El CHECK puede marcar Accnt_ID=Contado; el generador puede marcar Fecha_Envio y Ctro. |
| T3.CFDI_RFC_SETTING | Configuracion de version por RFC. |
| T3.RF_PROCESOS_LOG | INSERT del inicio y UPDATE del fin y contadores por PID. |
| EAI_OWNER.MX_COMPONENTS | Inicio mediante LOG_START; fin normal con Status=1. |
| EAI_OWNER.MX_EAI_MESSAGE_LOG | Error del coordinador con agrupacion y PID. |
| T3.CFDI_AGRUPACION_PAGO / CFDI_COBRANZA / CFDI_DOCUMENTOS | JOIN utilizado indirectamente por el CHECK para obtener sus filas. |
| T3.CFDI_DOCUMENTOS_ENVIAR / CFDI_DOCUMENTOS | El generador puede insertar el layout y el documento preparado. No prueba timbrado. |
| T3.RF_ERROR_LOG | Errores internos del CHECK o del generador. Este coordinador no lo consulta para excluir reintentos. |

El generador decide insertar cuando la longitud de uCABCLIE es mayor que 10.
Despues escribe Fecha_Envio/Ctro en CTRL. Su CATCH registra RF_ERROR_LOG sin
THROW explicito. Retornar de EXEC no prueba que esas escrituras ocurrieran,
y la falta de una transaccion propia no garantiza atomicidad de todo el flujo.

## Diferencias con Oracle y riesgos pendientes

| Hallazgo | Implicacion |
|---|---|
| Filtro Contado y NULL | El SQL agrega Accnt_ID<>'Contado'; Oracle no lo contiene. Conservar el filtro actual y revisar funcionalmente el efecto sobre valores NULL. |
| Version distinta de 4.0 | Oracle llama PROC_CFDI_GENERAR_PAGO_AGR en ELSE; SQL no tiene esa rama. Puede contar un grupo sin generarlo y dejarlo pendiente. |
| Limite de lote | Oracle sale al alcanzar 1,000 grupos que pasaron la condicion, no 1,000 filas leidas. SQL no tiene limite equivalente. |
| Confirmaciones | Oracle hace COMMIT cada diez grupos que pasan la condicion, al alcanzar el limite y al finalizar; SQL no tiene BEGIN TRAN/COMMIT/ROLLBACK propios. No agregar COMMIT sin definir responsabilidad sobre transacciones externas. |
| Limpieza de cursor en CATCH | La condicion >=-1 incluye el estado -1 (cerrado). CLOSE puede fallar, ocultar el error original e impedir que se escriba la bitacora siguiente. ScrCentral es LOCAL aunque el CATCH tambien consulte el alcance global. |
| Fin y propagacion de error | No hay THROW ni actualizacion de Fin/disponibilidad en CATCH. Pueden quedar Fin NULL y Status=2, o retorno normal si la bitacora se escribe. |
| Errores de hijos | Ambos hijos pueden registrar error sin relanzarlo; el coordinador no recibe una confirmacion explicita de validacion/generacion exitosa. |
| Reintentos | Un error del generador puede dejar Fecha_Envio NULL. El cursor central no excluye RF_ERROR_LOG, por lo que ese grupo puede seguir elegible en otras corridas. |
| Conteos y tipos | Contadores NUMERIC(6,0) frente a OUTPUT NUMERIC(18,0): salida superior a 999,999 puede desbordar. Agrupacion es DECIMAL(10,0) en CTRL, pasa a VARCHAR(50) y luego a los NUMERIC de los hijos. |
| Rango del PID | @nPID NUMERIC(8,0) frente al maximo de diez digitos de la secuencia. Revisar antes de alcanzar 100,000,000. |
| Concurrencia y duplicados | No hay reserva de candidatos ni garantia de unicidad de filas del control en este procedimiento. |

La comparacion principal de fecha es un corte >= contra una constante, no
una igualdad DATETIME con horas ni un filtro por dia BATMD. El CHECK ya
convierte ambas fechas a DATE para su igualdad. No se cambiaron fechas.

El catalogo de jobs del repositorio contiene
ORA_809_T3_PROC_CFDI_LIBERA_PAGO_CENTRAL y su validador historico enumera
PROC_CFDI_GENERAR_PAGO_AGR, coherente con la ruta ELSE de Oracle pero no con
una llamada activa del SQL actual. No se cambiaron jobs ni su habilitacion.

Para una fase de performance pueden revisarse accesos por Fecha_Envio/Fecha_Pago
en CTRL, configuracion RFC/Parametro y los JOIN por Agrupacion/Asignacion_ID/
Nota_Venta del CHECK. No hay mediciones ni planes instalados de esta rutina
en esta revision: no se propone crear indices sin esa evidencia.

## Cambios y validacion de esta intervencion

Se agregaron comentarios de proposito, flujo, filtros, NULL, contrato OUTPUT,
versiones, contador, tablas, manejo de errores y dependencias. Se reemplazo
el comentario que decia que faltaban variables, porque la proyeccion actual
solo entrega dos columnas y ambos FETCH tienen las dos variables requeridas.

TSql160Parser: cero errores antes y despues. Tokens SQL identicos al respaldo,
excluyendo comentarios y espacios: no se reparo ni modifico codigo ejecutable.
Se conservaron USE T3QA, GO, opciones SET, ALTER PROCEDURE, PRINT y formato
UTF-16 LE con BOM/CRLF. Ambos FETCH mantienen dos variables.

Respaldo de trabajo: tmp/libera_pago_central_documentacion_20261027/
PROC_CFDI_LIBERA_PAGO_CENTRAL.antes.sql, SHA256
48B565F5DC4443A39DC36DAFE3867F39754C5427A0AC530FA5BCB2A3F59E016D.
La comprobacion es estatica; no equivale a compilar contra todas las
dependencias instaladas ni a una prueba funcional de envio. No se ejecuto
el procedimiento ni se altero la base. Los hallazgos requieren una revision
funcional separada y no se implementaron como cambios en esta documentacion.

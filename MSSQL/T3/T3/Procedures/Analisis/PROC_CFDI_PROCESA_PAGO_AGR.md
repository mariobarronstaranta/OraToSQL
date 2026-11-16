# Guia de T3.PROC_CFDI_PROCESA_PAGO_AGR: cambios de desarrollo adoptados

Revision del 03/11/2026 del [archivo SQL actual](../PROC_CFDI_PROCESA_PAGO_AGR.sql).
Se conserva la version de **tres cursores** y el FETCH de tres columnas ya
corregido. Por instruccion expresa del usuario se adoptaron de la version
de desarrollo BKP la eliminacion de transacciones explicitas, los cursores
LOCAL, FORWARD_ONLY en ScrDetalle, su limpieza en CATCH y los PRINT de
diagnostico. Se conservaron parametros, filtros, calculos y marcado por FOLIO_ID.
Ademas, se corrigio la captura temprana de claves de ScrDetalle: ahora se declara
y libera dentro de cada grupo, despues de asignar sus variables.
El procedimiento principal mantiene su nombre y CREATE OR ALTER. La version
por conjuntos con #Grupos no corresponde a este archivo.

La [comparacion con Oracle](PROC_CFDI_PROCESA_PAGO_AGR.COMPARACION_ORACLE.md)
separa diferencias reales de comportamientos compartidos. El archivo Oracle
no fue modificado. No se consulto ni cambio T3QA ni se ejecuto la cadena fiscal.

## Estado actual: FETCH corregido con base en BKP

[ScrDetalle](../PROC_CFDI_PROCESA_PAGO_AGR.sql) selecciona tres columnas:
Folio_ID, Asignacion_ID e Importe. Ambos FETCH reciben ahora esas tres columnas
en @Det_Folio_ID, @Det_Asignacion_ID y @Det_Importe, en ese mismo orden.
Se retiro @Det_Cobza_ROWID solamente del primer FETCH, como en
[la version BKP](../PROC_CFDI_PROCESA_PAGO_AGR_BKP.SQL).

SQL Server exige que el numero de destinos coincida con las columnas del cursor.
[Microsoft: FETCH](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/fetch-transact-sql).
La version recibida tenia cuatro destinos en el primer FETCH y tres columnas,
lo que producia un error al llegar a esa ruta. Esa incompatibilidad fue corregida.
Una ejecucion sin candidatos no valida el recorrido de detalle con datos reales.

La correccion no certifica la equivalencia completa con Oracle. El marcado
por FOLIO_ID sigue pendiente de homologacion. La diferencia transaccional
con Oracle se conserva como decision expresamente aceptada al adoptar BKP.
@Det_Cobza_ROWID queda declarada como variable legada sin uso; no crea una
identidad equivalente a ROWID en SQL Server.

## Captura de variables corregida: cursor de detalle por grupo

La declaracion de ScrDetalle se movio al interior del recorrido de cabeceras,
despues de asignar las claves del grupo y antes de OPEN. Cada recorrido termina
con CLOSE y DEALLOCATE de ese cursor; el siguiente grupo crea su propio cursor
con los nuevos valores. Se retiro la desasignacion final fuera del bucle para
que una ejecucion sin grupos no intente liberar un cursor nunca declarado.
La consulta, sus filtros y los FETCH de tres columnas se conservaron.

La prueba local previa del **03/11/2026**, anterior a esta correccion, uso la
misma semilla en principal y BKP y **fallo en ambas versiones**. La reconsulta
directa encontro dos detalles elegibles por importe total 150; ambas ejecuciones
anteriores produjeron este resultado:

| Resultado historico de la fixture | Principal previo al arreglo | BKP |
|---|---:|---:|
| Cabeceras | 1 | 1 |
| Detalles / cobranzas marcadas | 0 / 0 | 0 / 0 |
| Cantidad / importe final del control | 0 / 0 | 0 / 0 |
| Cliente final | NULL | NULL |
| RF_ERROR_LOG | 0 | 0 |
| Bitacoras 109 / llamadas al stub hijo | 1 / 1 | 1 / 1 |

La comparacion previa marco IGUAL_BKP_EN_ESTA_FIXTURE, pero la regresion funcional
fallo en ambas: esperaba dos detalles y observo cero. La prueba se ejecuto
localmente con un stub del liberador; no procede de T3QA ni certifica la cadena
fiscal real. Evidencia en
[RESULTADO_DIAGNOSTICO.txt](../../../../../tmp/procesa_pago_agr_adoptar_bkp_20261103/ejecuciones/CodexAGRAdoptaBKP_d4ad2cf15409/RESULTADO_DIAGNOSTICO.txt).

El fuente anterior declaraba ScrDetalle antes de asignar las claves del grupo a
@dtFecha_Pago, @sRFC, @sVia_Pago y las variables de banco/asignacion. En ese
punto seguian NULL. Los valores de las variables de su SELECT se capturan al
DECLARE CURSOR: asignarles datos despues y hacer OPEN no actualiza esos valores.
El mismo patron de declaracion anticipada permanece en BKP, que no se modifico;
el comportamiento se reprodujo en esa version con la misma semilla.
[Microsoft: DECLARE CURSOR](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/declare-cursor-transact-sql).

Una reproduccion minima tambien lo confirmo: declarar con filtro NULL,
asignarle 1 y luego abrir produjo FETCH_STATUS=-1; declarar despues de asignar
1 devolvio esa fila con FETCH_STATUS=0.

Esta correccion es distinta del FETCH de tres columnas, que ya estaba
corregido. El procedimiento principal ahora declara el cursor con las claves
del grupo disponibles; por eso ya no coincide con BKP en ese ciclo de vida.
La evidencia previa documenta el diagnostico, no el resultado del archivo
corregido. Las cinco regresiones posteriores con el fuente actual fueron
aprobadas en LocalDB; su alcance se detalla al final de esta guia y en la
[validacion vigente](../PROC_CFDI_PROCESA_PAGO_AGR.DOCUMENTACION_VALIDACION.txt).

## Proposito, parametro y salida

El proceso 109 prepara agrupaciones de cobranza pendiente, relaciona pagos,
marca la cobranza y despues llama a T3.PROC_CFDI_LIBERA_PAGO_CENTRAL.
La tabla T3.CFDI_COBRANZA tiene aproximadamente **56 millones de registros**
en T3QA; leerla o actualizarla repetidamente requiere considerar ese volumen.

`@nDias NUMERIC = NULL` usa NUMERIC(18,0). El corte es:

```sql
Fecha_Proceso > CAST(DATEADD(DAY,-ISNULL(@nDias,0),GETDATE()) AS date)
```

Con 30, incluye posteriores a medianoche de hace 30 dias; excluye exactamente
esa medianoche. NULL/0 usa hoy a medianoche, no todo el historico. No valida
negativos. La firma SQL no conserva fracciones de dia como NUMBER de Oracle.
El corte se usa en asignacion y cabeceras, **no en ScrDetalle**.

No hay parametros OUTPUT ni SELECT de negocio propio del procedimiento.
Ademas de los mensajes del CATCH y de los hijos, imprime cuatro trazas de BKP:
inicio del procedimiento, ScrWA_Allocation, ENTRA ScrAgrPagoCentral y
ENTRA ScrDetalle. Las ultimas tres se emiten por iteracion del cursor respectivo.
El archivo no
incluye USE ni SET de sesion; desplegarlo depende del contexto de conexion.
Esta documentacion no es una instruccion de despliegue ni ejecuta el archivo.

## Recorrido para mantenimiento

1. Inicializa la hora, proceso 109 y PID obtenido de SEQ_CFD. Los numeros de
   secuencia consumidos no se recuperan con rollback.
2. Recorre ScrWA_Allocation: busca asignaciones contables y actualiza
   Asignacion_Central por Asignacion_ID, sin iniciar una transaccion propia.
3. Abre ScrAgrPagoCentral, que resume cabeceras recientes pendientes.
4. Por cabecera obtiene SEQ_PAGO_CENTRAL_AGR, copia claves a variables,
   convierte centinelas a '' e inserta CFDI_AGRUPACION_CTRL provisional.
5. Declara ScrDetalle con las claves ya asignadas al grupo, lo abre y hace
   el primer FETCH con tres destinos.
6. Por detalle inserta CFDI_AGRUPACION_PAGO, marca Fecha_Envio por FOLIO_ID
   y acumula cantidad e importe. Al acabar ese grupo cierra y desasigna ScrDetalle.
7. Reemplaza cantidad/importe del control por lo acumulado y recalcula
   Cliente_SAP desde agrupacion-pago, cobranza y registro fiscal.
8. Cierra/desasigna cursores por la ruta normal e inserta RF_PROCESOS_LOG.
9. Llama al liberador sin parametros; no inicia ni confirma una transaccion propia.
   La llamada ocurre aun sin grupos nuevos y puede atender otros pendientes.

Fecha_Envio de la cobranza es una marca de seleccion/agrupacion; no acredita
generacion, envio o timbrado de un CFDI. Fin del proceso 109 se registra antes
del liberador y no mide su duracion ni su exito.

## Los tres cursores

| Cursor | Funcion y alcance |
|---|---|
| ScrWA_Allocation | Selecciona recientes sin asignacion, enlaza SUBSTRING(Asignacion_ID,3,10) con ClearingDocNumber, FiscalYear del anio actual y Factura con Registro_Fiscal. Descarta entrega, banco reservado, factura con coma, prefijo 1-1 y referencia fiscal. |
| ScrAgrPagoCentral | Resume pendientes recientes por dia de pago, RFC, via normalizada y banco/cuenta/asignacion originales. Excluye INTERFACE, vias 01/CM/AI, estados Debit Note/Canc Pago, RFC generico y factoraje. |
| ScrDetalle | Se declara por grupo despues de asignar sus claves y se cierra/desasigna al terminar ese recorrido. Conserva las exclusiones de origen, vias 01/CM, estados y factoraje. No limita Fecha_Proceso. |

Los tres cursores son LOCAL; ScrDetalle tambien declara FORWARD_ONLY.
El CATCH utiliza CURSOR_STATUS para cerrar los que estan abiertos y desasignar
los locales existentes. Esta limpieza de recursos no confirma ni revierte datos.

El UPDATE de asignacion usa solo Asignacion_ID: no repite los filtros que
seleccionaron la fila. Como en Oracle, puede afectar otras cobranzas con ese
ID, aunque sean antiguas, enviadas o ya asignadas. No hay ORDER BY ni regla
de prioridad cuando existen varias asignaciones candidatas.

El codigo asigna las claves del grupo **antes de DECLARE**, y luego ejecuta
OPEN. Al terminar libera ScrDetalle para que la declaracion del siguiente grupo
capture sus propias claves. AI/RFC generico no se repiten literalmente en la
consulta: sus igualdades restringen el detalle a la cabecera. Fecha_Pago NULL
no satisface la igualdad del detalle. La correccion no agrega un corte de fecha:
se conserva la regla de Oracle que permite detalles historicos del mismo grupo.

## Claves, NULL y reconciliacion

| Clave | Tratamiento |
|---|---|
| Fecha_Pago | CAST AS date, agrupa por dia. |
| RFC | Valor de la cobranza. |
| Via_Pago | NA se convierte en 03. |
| Banco_Nombre | GROUP BY original; la proyeccion usa ISNULL(...,'NoBanco'). |
| Banco_Num_Cuenta | GROUP BY original; la proyeccion usa ISNULL(...,'NoCuenta'). |
| Asignacion_Central | GROUP BY original; la proyeccion usa ISNULL(...,'NoAsigna'). |

Los tres campos de banco/cuenta/asignacion **no se normalizan en GROUP BY**,
como en Oracle. Sin embargo, el detalle compara valores normalizados; un
centinela real puede coincidir con NULL en esa busqueda. Se conservan las
comparaciones y el NOT IN de Oracle. Un NULL en WA_Factoraje.Factura puede
eliminar candidatos por UNKNOWN; no se sustituyo por NOT EXISTS.

El resumen inicial usa SUM(Importe) y COUNT(Importe), que ignoran NULL.
El recuento final cuenta iteraciones y la suma escalar con un importe NULL
queda NULL. Si no hay detalles, los acumulados iniciales 0/0 reemplazan la
cabecera provisional. La variable de cantidad inicial tiene cuatro digitos:
puede desbordar antes de llegar a la reconciliacion, igual que en Oracle.

Cliente_SAP final es MAX(ISNULL(RF.Clte_Factura_SAP,RF.Cliente_SAP)) a traves
del detalle y la cobranza; no es simplemente MAX(Cobza.Cliente_SAP) del resumen.
Sin coincidencias el agregado produce NULL. Los MAX independientes no
representan una relacion garantizada entre cuenta, cliente y la misma fila.

## Dependencias y efectos directos

| Objeto | Uso |
|---|---|
| T3.CFDI_COBRANZA | Lectura; UPDATE de Asignacion_Central y Fecha_Envio. |
| EAI_OWNER.TMP_ACCOUNT_HEADER | Lectura de compensacion, ejercicio y Assignment. |
| T3.REGISTRO_FISCAL | Lectura de entrega/referencia y cliente fiscal final. |
| T3.WA_FACTORAJE | Exclusion por Factura mediante NOT IN. |
| T3.CFDI_AGRUPACION_CTRL | INSERT provisional; UPDATE de cantidad, importe y cliente. |
| T3.CFDI_AGRUPACION_PAGO | INSERT por detalle y lectura para cliente fiscal. |
| T3.RF_PROCESOS_LOG | INSERT del proceso 109 al terminar agrupacion. |
| T3.RF_ERROR_LOG | INSERT al capturar un error. |
| SEQ_CFD / SEQ_PAGO_CENTRAL_AGR | PID y numero de agrupacion, sin esquema explicito en el SQL. |
| T3.PROC_CFDI_LIBERA_PAGO_CENTRAL | Unica llamada directa a otro SP; sin parametros, despues del log 109. |

No hay #Grupos ni llamadas directas a funciones de usuario. La cadena
executeScript del primer cursor solo se almacena; no se ejecuta como SQL dinamico.
Se conservaron las variables legadas aunque varias no se utilizan.

## Bitacora y errores

| Campo | Significado |
|---|---|
| Proceso_1 | Grupos recorridos. |
| Proceso_2 | Iteraciones de detalle; no necesariamente filas afectadas por FOLIO_ID. |
| Proceso_3 | Cero. |
| Proceso_4 | @nDias original, incluido NULL. |
| Fin | Hora antes de llamar al liberador. |

Por decision del usuario, el procedimiento principal no ejecuta BEGIN TRAN,
COMMIT ni ROLLBACK propios. Sin transaccion externa y en autocommit, cada
instruccion se confirma individualmente; si despues ocurre un error, pueden
permanecer instrucciones anteriores. Oracle confirma por fases, diferencia
aceptada y documentada en el comparativo. Si existe transaccion del llamador,
las operaciones participan en ella y el llamador controla su finalizacion.
Las opciones de la conexion y el comportamiento de los hijos tambien influyen.

El CATCH cierra/desasigna los cursores locales existentes y conserva los PRINT
e INSERT de RF_ERROR_LOG; no hace rollback ni relanza el error. @strID nunca
se asigna. La segunda asignacion de @sMsg sobrescribe la primera. El INSERT
del error no tiene COMMIT explicito y participa en el modo transaccional activo.
El retorno normal del SP no prueba por si solo exito de la cadena fiscal.

## Validacion de esta revision

La revision inicial de comentarios conservo los 1,867 tokens ejecutables del
archivo recibido. Esa comprobacion es historica: despues se corrigio el primer
FETCH, se adoptaron los cambios de BKP autorizados y se corrigio el momento
de declaracion y liberacion de ScrDetalle por grupo.

La evidencia de validacion vigente se encuentra en
[DOCUMENTACION_VALIDACION](../PROC_CFDI_PROCESA_PAGO_AGR.DOCUMENTACION_VALIDACION.txt).
La comprobacion sintactica y del contrato de columnas no sustituye una prueba
funcional. La prueba fallida enlazada arriba corresponde al principal previo a
esta correccion y a BKP, ambos del 03/11/2026; no describe por si sola el resultado
del fuente corregido.

Con el fuente actual se aprobaron estas **cinco regresiones en LocalDB** el
03/11/2026. La [evidencia de resultados](../../../../../tmp/procesa_pago_agr_fix_cursor_20261103/ejecuciones/CodexAGRAdoptaBKP_0b387b50fb0d/RESULTADO.txt)
corresponde a una base temporal con datos controlados, folios unicos y un stub
del procedimiento hijo:

| Caso aprobado | Resultado comprobado |
|---|---|
| Detalle reciente e historico y repeticion | Dos pagos por total 150, cliente fiscal y bitacora correctos; repetir en la misma conexion no crea grupos nuevos. |
| Error controlado en autocommit | Se conservan operaciones previas al error, se registra el error y se permite reintentar en la misma conexion. |
| Exito con transaccion externa | El SP no confirma la transaccion; el llamador conserva el control y puede revertir los cambios. |
| Error con transaccion externa | El CATCH no revierte la transaccion del llamador, que conserva el control. |
| Dos grupos en una sola ejecucion | Cada grupo obtiene sus propios dos pagos, con totales 124 y 341 y clientes correspondientes; cuatro relaciones y cuatro cobranzas marcadas. |

Estas pruebas verifican la recreacion del cursor y el comportamiento descrito
con esos datos. No certifican el marcado por FOLIO_ID cuando existe duplicidad
o NULL, ni acreditan despliegue o ejecucion de la cadena fiscal real en T3QA.
Los archivos Oracle y BKP se conservan sin cambios.

Los anteriores 107.03 s, plan 8889 y scripts 04/05/07 de performance pertenecen
a otra version por conjuntos. Buscan UPDATE Cobza, patron ausente en esta.
No sirven para certificar su rendimiento; el indice de la tabla puede seguir
existiendo, pero su beneficio para estos cursores requiere otra medicion.

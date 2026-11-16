# Comparacion con Oracle: version con cambios de desarrollo adoptados

Revision del 03/11/2026 del [SQL Server comentado](../PROC_CFDI_PROCESA_PAGO_AGR.sql)
y del [homologo Oracle](../../../../../ORA/T3/T3/Procedures/PROC_CFDI_PROCESA_PAGO_AGR.SQL).
No se modifico Oracle. El archivo SQL conserva el FETCH corregido y adopta por
instruccion expresa del usuario los cambios de BKP: sin transacciones explicitas
propias, tres cursores LOCAL, ScrDetalle FORWARD_ONLY, limpieza en CATCH y
PRINT de diagnostico. Mantiene el nombre principal y CREATE OR ALTER.
Ademas, ScrDetalle se declara y libera por grupo, despues de asignar las claves,
para corregir la captura temprana de variables presente tambien en BKP.

**Conclusion:** la version restaurada vuelve al recorrido de tres cursores de
Oracle y recupera la reconciliacion del control y del cliente fiscal. Aun asi,
no se declara equivalente a Oracle: conserva una identidad de marcado
diferente y un manejo transaccional distinto, este ultimo aceptado expresamente
por el usuario al adoptar BKP. El FETCH incompatible ya se corrigio retirando
@Det_Cobza_ROWID del primer FETCH. Se conservan las consultas y reglas de datos.

La prueba funcional local del **03/11/2026**, anterior a la correccion de la
captura de variables, comparo principal y BKP con la misma semilla. Produjo en
ambos una cabecera con importe/cantidad 0, Cliente_SAP NULL, ningun detalle ni
cobranza marcada. La reconsulta directa obtuvo dos detalles elegibles por 150.
Ambos dejaron cero errores RF, una bitacora 109 y una llamada al stub hijo.
La adopcion resulto IGUAL_BKP_EN_ESTA_FIXTURE, pero la regresion funcional
**fallo en ambas versiones**: esperaba dos detalles y observo cero.

Se confirmo la captura temprana de variables en ScrDetalle mediante la
reproduccion de ambas versiones y un caso minimo DECLARE/SET/OPEN. El principal
ahora declara el cursor despues de asignar las claves del grupo y lo libera al
terminar cada recorrido. BKP conserva el patron anterior y no se modifico.
La prueba fallida es evidencia historica del diagnostico; no es el resultado
del principal corregido. Uso una base local y un liberador stub, no la cadena
fiscal de T3QA. Ver
[RESULTADO_DIAGNOSTICO.txt](../../../../../tmp/procesa_pago_agr_adoptar_bkp_20261103/ejecuciones/CodexAGRAdoptaBKP_d4ad2cf15409/RESULTADO_DIAGNOSTICO.txt).

Con el principal corregido se aprobaron cinco regresiones locales el 03/11/2026,
incluida la recreacion de ScrDetalle para dos grupos en una sola ejecucion.
La [evidencia actual](../../../../../tmp/procesa_pago_agr_fix_cursor_20261103/ejecuciones/CodexAGRAdoptaBKP_0b387b50fb0d/RESULTADO.txt)
usa una base temporal LocalDB, folios unicos y un liberador stub. El alcance de
las pruebas se detalla al final; no corresponde a una ejecucion en T3QA.

## Diferencias encontradas

| Prioridad | Aspecto | SQL Server actual | Oracle | Efecto |
|---|---|---|---|---|
| Corregido | Cantidad de columnas de detalle | [ScrDetalle](../PROC_CFDI_PROCESA_PAGO_AGR.sql) devuelve 3 columnas; ambos FETCH reciben @Det_Folio_ID, @Det_Asignacion_ID y @Det_Importe. Se retiro el destino sobrante del primer FETCH con base en BKP. | [ScrDetalle](../../../../../ORA/T3/T3/Procedures/PROC_CFDI_PROCESA_PAGO_AGR.SQL) devuelve ROWID, Folio_ID, Asignacion_ID, Importe; el FOR usa ese registro. | SQL ya respeta su contrato de tres columnas. Esto no resuelve la diferencia de identidad entre FOLIO_ID y ROWID. |
| Corregido | Claves capturadas por el cursor de detalle | ScrDetalle se declara dentro del grupo despues de asignar sus variables, antes de OPEN. CLOSE y DEALLOCATE terminan cada recorrido. | El FOR de ScrDetalle se ejecuta dentro del grupo, despues de asignar las claves utilizadas por la consulta. | El cursor SQL se crea con las claves del grupo actual; no reutiliza los NULL de la declaracion anticipada. La consulta conserva sus filtros. BKP mantiene el defecto anterior. |
| Alta | Fila que se marca | [WHERE FOLIO_ID=@Det_Folio_ID](../PROC_CFDI_PROCESA_PAGO_AGR.sql). | [WHERE Cobza.ROWID=Det.Cobza_ROWID](../../../../../ORA/T3/T3/Procedures/PROC_CFDI_PROCESA_PAGO_AGR.SQL). | Folio_ID no garantiza la identidad de una fila: el DDL local lo permite NULL y no declara unicidad. Puede marcar varias filas o ninguna. |
| Decision aceptada | Confirmacion de operaciones | No ejecuta BEGIN TRAN, COMMIT ni ROLLBACK propios, como BKP. | Confirma asignaciones, agrupacion y liberacion por fases; hace ROLLBACK del trabajo pendiente en EXCEPTION. | Sin transaccion externa y en autocommit SQL confirma cada instruccion. La diferencia frente a Oracle se conserva por decision expresa del usuario. |
| Media | Cadenas vacias de control | Convierte centinelas a '' y guarda una cadena vacia. | Asigna '' pero Oracle la trata como NULL. | Consumidores con IS NULL pueden observar controles diferentes. |
| Media | Tipo de parametro | @nDias NUMERIC implica NUMERIC(18,0). | nDias NUMBER sin esa restriccion de escala. | Con fracciones no son equivalentes: SQL convierte a escala cero antes de ejecutar; Oracle puede restar fracciones de dia antes de TRUNC. |
| Adoptado de BKP | Recursos de cursores en error | Tres cursores LOCAL; ScrDetalle ademas FORWARD_ONLY. CATCH cierra/desasigna los locales existentes segun CURSOR_STATUS. | Declara cursores explicitos y los recorre con FOR, que gestiona apertura, lectura y cierre automaticamente. | SQL ahora hace limpieza explicita de recursos en el CATCH. Esa limpieza no confirma ni revierte operaciones de datos. |
| Condicionada | Confirmacion del log de error | INSERT en CATCH sin rollback ni COMMIT propios. | INSERT y COMMIT en EXCEPTION. | En SQL depende del modo de transacciones de la conexion: autocommit habitual o transaccion activa del llamador. |
| Decision aceptada | Contexto transaccional externo | Las operaciones participan en la transaccion externa si existe; el SP principal no la confirma ni revierte explicitamente. | COMMIT/ROLLBACK afectan la transaccion de la sesion. | La finalizacion SQL depende de la conexion y del llamador; no se implica que el SP quede fuera de una transaccion externa. |
| Adoptado de BKP | Diagnostico | PRINT al iniciar y por iteracion de asignacion, cabecera y detalle; conserva los PRINT del CATCH. | DBMS_OUTPUT del bloque de error. | Se mantienen los mensajes de desarrollo aceptados por el usuario. |

La regla de FETCH exige igual numero de variables y columnas.
[Microsoft: FETCH](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/fetch-transact-sql).
Las cadenas vacias se tratan como NULL en Oracle.
[Oracle: NULL](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Nulls.html).
El SQL actual no declara commits propios; su participacion en una transaccion
externa depende del contexto del llamador.
Los cursores se declaran LOCAL de forma explicita, siguiendo BKP.
[Microsoft: DECLARE CURSOR](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/declare-cursor-transact-sql).
La misma referencia documenta que los valores de variables utilizados por el
SELECT del cursor no cambian despues de declararlo. Esto explica por que copiar
las claves inmediatamente antes de OPEN no reparaba el enlace realizado antes.
Ahora se asignan antes de DECLARE y se recrea el cursor para cada grupo.

## Ejemplo que separa FETCH de identidad

Supongamos dos cobranzas con el mismo FOLIO_ID: una pertenece al grupo actual
y otra no. Oracle guarda el ROWID de la primera y marca solo esa fila. El
UPDATE SQL por FOLIO_ID puede marcar ambas. Si FOLIO_ID es NULL, la igualdad
con una variable NULL no marca ninguna. Este problema permanece despues de
ajustar el primer FETCH para recibir tres valores.

El [DDL local](../../Tables/T3.CFDI_COBRANZA.Table.sql) define FOLIO_ID como
varchar(30) NULL. El archivo no acredita PK/UNIQUE sobre el campo; el estado
instalado podria ser diferente y no se consulto. Antes de homologar el marcado
hay que identificar una clave estable y unica real. No se invento un ROWID
ni se agrego una columna, PK o indice en esta revision.

## Flujo que ahora coincide

| Etapa | Comportamiento comun en los fuentes originales |
|---|---|
| Estructura | Tres cursores y recorrido por cabecera/detalle; sin #Grupos. |
| Asignacion central | Seleccion por fecha reciente/sin asignacion, compensacion, ejercicio actual y fiscal. Cada UPDATE usa solo Asignacion_ID. |
| Candidatos de cabecera | Pendientes, origen distinto de INTERFACE, vias distintas de 01/CM/AI, estados permitidos, fecha reciente, RFC no generico y NOT IN de factoraje. |
| Claves | Dia de pago, RFC, via NA->03 y banco/cuenta/asignacion originales en GROUP BY; centinelas solo en la proyeccion. |
| Seleccion de detalle | Claves del grupo y filtros comunes; SIN corte de Fecha_Proceso. SQL declara el cursor despues de asignar esas claves y lo libera por grupo. |
| Control provisional | Importe SUM, cantidad COUNT(Importe), MAX de cuenta/cliente. |
| Control final | Recuenta iteraciones y acumula importes del detalle. |
| Cliente final | MAX de Clte_Factura_SAP con fallback Cliente_SAP del fiscal via relaciones/cobranza. |
| Bitacora | Proceso 109; Proceso_1 grupos, Proceso_2 detalles, Proceso_3 cero, Proceso_4 parametro original. |
| Liberacion | Se llama despues del registro de agrupacion, sin parametros e incluso sin grupos nuevos. La confirmacion transaccional difiere como se describe arriba. |
| Errores | Mensaje y RF_ERROR_LOG; no se relanza. strID no se asigna; segunda asignacion de mensaje sobrescribe la primera. SQL limpia cursores y Oracle revierte trabajo pendiente. |

Estos pasos coincidentes de reconciliacion corresponden al flujo escrito.
La incompatibilidad del primer FETCH y la captura anticipada de claves ya se
corrigieron en el principal. La prueba previa de principal/BKP con control 0/0
queda como evidencia del defecto anterior. Los resultados de la revision actual
se documentan en la [validacion vigente](../PROC_CFDI_PROCESA_PAGO_AGR.DOCUMENTACION_VALIDACION.txt);
las pruebas locales no acreditan equivalencia completa ni ejecucion de la cadena
fiscal real en T3QA.

Las conclusiones anteriores sobre falta de reconciliacion, falta de Cliente_SAP
fiscal, NOT EXISTS, GROUP BY normalizado y UPDATE por conjuntos **ya no aplican**
a la version restaurada. Se reemplazo la guia antigua para evitar esa confusion.

## Riesgos compartidos que no deben confundirse con diferencias

- El UPDATE de asignaciones no repite fecha ni Asignacion_Central IS NULL:
  ambos pueden cambiar otras filas con el mismo Asignacion_ID. Con multiples
  Assignment no hay prioridad expresa ni ORDER BY. Ya no se trata del antiguo
  UPDATE FROM con ANY del plan 8889.
- NOT IN conserva la semantica de NULL de Oracle: un NULL en la subconsulta
  puede impedir seleccionar candidatos. Cambiarlo por NOT EXISTS seria un
  cambio funcional bajo esos datos.
- El detalle puede incorporar cobranza antigua o sin Fecha_Proceso. Agregarle
  un corte de 30 dias cambiaria la regla de Oracle. Ejemplo: una reciente de
  100 y otra antigua de 50 con las mismas claves pueden terminar con control
  recalculado en 150 y dos iteraciones, si se completa el flujo y el marcado.
- El detalle no repite AI/RFC generico literalmente, pero compara contra las
  claves de las cabeceras que aplicaron esas exclusiones.
- Fecha_Pago NULL puede formar una cabecera que no obtiene detalle por igualdad.
- NULL y un centinela real se separan en GROUP BY pero pueden coincidir en la
  consulta del detalle. El orden/visibilidad del cursor puede afectar lo observado;
  no hay reserva de candidatos contra ejecuciones concurrentes.
- COUNT(Importe) inicial omite NULL; el recuento final cuenta iteraciones y una
  suma escalar con NULL queda NULL. La cantidad provisional de cuatro digitos
  puede desbordar antes de la reconciliacion.
- MAX independientes de cuenta/cliente no garantizan una misma fila de origen.
- Fecha_Envio de cobranza no acredita timbrado. La bitacora 109 termina antes
  del liberador, cuya atencion no se restringe a grupos creados en esta corrida.

La igualdad de reglas SQL no garantiza igualdad ante cualquier dato: revisar
tipos/longitudes, cadenas vacias, collation, configuracion de fechas y reloj de
cada motor. No se consultaron configuraciones NLS ni metadata remota Oracle.
La comparacion de dias enteros asume fechas/relojes equivalentes; el tipo
NUMERIC sin escala no preserva fracciones como NUMBER.
[Microsoft: NUMERIC](https://learn.microsoft.com/en-us/sql/t-sql/data-types/decimal-and-numeric-transact-sql).

## Cambios aceptados y pendientes

Se aplico el contrato de tres columnas de BKP: el primer FETCH del procedimiento
principal recibe Folio_ID, Asignacion_ID e Importe, igual que el FETCH siguiente.
No se agrego una cuarta columna ni se modifico la variable legada declarada.
Tambien se adoptaron la eliminacion de transacciones explicitas propias,
los cursores LOCAL, ScrDetalle FORWARD_ONLY, la limpieza del CATCH y los
cuatro PRINT de diagnostico de BKP. Se conserva CREATE OR ALTER sobre el
nombre principal; no se agregaron USE ni opciones SET de despliegue.

Tambien se corrigio la captura de claves de ScrDetalle: se declara dentro del
grupo despues de asignar las variables y se cierra/desasigna por recorrido.
Se retiro el DEALLOCATE final fuera del bucle para contemplar cero grupos.
El CATCH conserva las guardas CURSOR_STATUS para los tres cursores locales.
No se modifico el SELECT del detalle ni se agrego un filtro de fecha.

Queda pendiente:

1. Definir una identidad real de cobranza que preserve el marcado de una fila
   Oracle. El FETCH corregido no resuelve este aspecto.
2. Acordar representacion de NULL/cadena vacia,
   conservando los filtros y reconciliaciones del original.
3. Validar resultados con grupos reales en un entorno controlado antes de
   medir rendimiento de esta nueva definicion.

Los tres puntos anteriores siguen pendientes. La diferencia transaccional con
Oracle es una decision aceptada, no un cambio pendiente de revertir.

## Performance y evidencia

CFDI_COBRANZA tiene aproximadamente 56 millones de registros. Esta version
repite consultas por grupo y UPDATE por detalle. Ya no delimita una transaccion
propia; puede participar en una del llamador. No se puede concluir su tiempo
a partir del codigo ni de otra version.
Los 107.03 s, query_id 32735, plan 8889 y sugerencia estimada del 63 % pertenecen
a la version anterior por conjuntos. Los scripts 04/05/07 buscan UPDATE Cobza
y no cubren los SELECT de estos cursores ni UPDATE por variable de esta version.
El indice compuesto puede permanecer, pero su uso/beneficio no esta certificado
para el fuente restaurado. No se borro ni se reconstruyo ningun indice.

La validacion inicial de comentarios comparo 1,867 tokens ejecutables identicos.
Es evidencia historica: despues se corrigio el primer FETCH y se adoptaron los
cambios de desarrollo autorizados; ahora tambien se corrigio el ciclo de vida
de ScrDetalle por grupo. Consultar la
[validacion vigente](../PROC_CFDI_PROCESA_PAGO_AGR.DOCUMENTACION_VALIDACION.txt)
para la comprobacion de los cambios. Una comprobacion sintactica o de columnas
no acredita equivalencia funcional ni el despliegue de la definicion en T3QA.
La prueba funcional local previa del 03/11/2026 no fue aprobada por detalle
vacio en el principal anterior ni BKP. La reproduccion minima tambien confirmo
la captura: DECLARE con filtro
NULL, SET 1 y OPEN devolvio FETCH_STATUS=-1; declarar despues del SET 1 devolvio
la fila 1 con FETCH_STATUS=0. El principal ahora declara/recrea el cursor por
grupo, despues del SET. Esa evidencia fallida documenta el origen del arreglo;
no describe el resultado actual.

Las **cinco regresiones posteriores fueron aprobadas en LocalDB** con el fuente
actual. Comprobaron dos pagos reciente/historico por total 150 y cliente fiscal,
repeticion sin grupos nuevos en la misma conexion, error controlado en autocommit
con registro y reintento, y conservacion de la transaccion externa tanto en exito
como en error. El quinto caso proceso dos grupos distintos en un solo EXEC:
cada grupo obtuvo dos pagos, totales 124 y 341, sus clientes correspondientes,
cuatro relaciones y cuatro cobranzas marcadas. Ver
[RESULTADO.txt](../../../../../tmp/procesa_pago_agr_fix_cursor_20261103/ejecuciones/CodexAGRAdoptaBKP_0b387b50fb0d/RESULTADO.txt).
La prueba utilizo un stub del liberador y folios unicos; no resuelve la identidad
FOLIO_ID/ROWID ni certifica la cadena fiscal real o el despliegue en T3QA.

Respaldo recibido SHA256:
DC9F70563B88A3CCE09691D10E67379F48C2508297E29D1ECB939ACA1E946ABA.
Evidencia historica de la revision de comentarios:
tmp/procesa_pago_agr_documentacion_original_20261103/VALIDACION.txt.

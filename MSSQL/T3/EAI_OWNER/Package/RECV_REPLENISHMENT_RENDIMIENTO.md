# Revision de RECV_REPLENISHMENT — 2026-10-20

## Resultado posterior al parche, 13:18

Usuario aplico el parche: Revertido=0, BloquesModificados=7.
Lote manual de 13:16:45 a 13:17:04: 178 mensajes en 19 segundos,
9.37 mensajes/segundo frente a ~2 reportados inicialmente (4.68x).
Queda pendiente confirmar que los 178 terminaron correctamente en negocio.

- SF_PROC_REPLENISHMENT: 178 llamadas desde recompilacion del parche,
  104.096 ms medios inclusivos y 1514.770 lecturas/llamada.
- UPDATE PedidoSAP: 917 ejecuciones, 0.04408 ms y 4 lecturas por ejecucion,
  frente a 107.370 ms y 11689 lecturas. Total nuevo: 40.421 ms.
- Los DELETE no aparecen entre las 40 sentencias de mayor tiempo acumulado.
  Esto no permite asignarles tiempos exactos ni confirmar individualmente
  todos los planes de acceso; requiere consulta sin TOP global si se necesita.
- T3.DELIVERY_IDOC_TO_REMISION: una llamada dentro del lote,
  7332.094 ms y 63765 lecturas. Equivale a ~38.6% de los 19 segundos del
  lote, si corresponde a la misma sesion (la cache no identifica al caller).
  Siguiente prioridad de investigacion: consulta/cursores internos, esperas,
  compilacion inicial y version desplegada. Una llamada no prueba costo estable.
- Consulta principal MATERIAL: 917 llamadas, 827.453 ms totales;
  conversion MAX CAJ/PAQ: 57 llamadas, 272.466 ms totales. Menor prioridad
  que remisiones en esta captura.
- Cierre por PID sigue con 10353 lecturas. Media acumulada de cuatro lotes:
  569.546 ms; no atribuir ese promedio exactamente al ultimo lote.
- Los promedios de RECV_REPLENISHMENT (cuatro llamadas) y de otros hijos
  mezclan ejecuciones previas al parche. No sumarlos a los tiempos del parser.
- Se observaron 165 INSERT de HEADER frente a 178 llamadas del parser.
  Hay ramas que no insertan; no inferir ni exito ni fallo de los 13 restantes
  sin estados/log y validacion funcional.

El ajuste por ReferenceID tiene evidencia directa de mejora. Mantener pendientes
los permisos del job por instruccion del usuario. Priorizar remision antes de
prometer mas throughput mediante el indice de PID o refactor de cursores.

## Evidencia recibida: captura T3QA del 20/10 a las 12:29

La captura confirma indices activos por ReferenceID en las cuatro tablas,
todas con columna VARCHAR(50). Tambien existen los accesos por
PREVENTA_GENERAL.Referencia, IFC_Folios_FE.Var_1 y REMISION_DETALLE.Factura.
No crear duplicados. El indice de folios IX_RI_NRIV_RELACION_SAP_CLASE esta activo.

| Operacion del parser | Ejecuciones | Media ms | Lecturas por ejecucion |
|---|---:|---:|---:|
| DELETE DETAIL | 2 | 2361.513 | 47974.5 |
| DELETE HEADER | 2 | 128.097 | 11688 |
| UPDATE HEADER.PedidoSAP | 7 | 107.370 | 11689 |
| UPDATE HEADER.Order_Num | 2 | 103.443 | 11689 |
| DELETE PARTNERS | 2 | 4.197 | 144 |
| SELECT MATERIAL | 7 | 0.883 | 7.286 |

Los cuatro primeros operadores acumulan 5937.695 ms en esta muestra. No sumar
este total al tiempo inclusivo del parser. SF_PROC_REPLENISHMENT tiene solo
dos llamadas en cache, media 6244.326 ms: insuficiente para caracterizar un lote
representativo. Hay conversiones implicitas en los planes, pero el XML recibido
esta truncado; no se ha identificado visualmente el operador de conversion.
La prioridad confirmada por costo es ReferenceID, incluyendo UPDATE por partida.

El plan reciente del coordinador muestra una llamada de 18.055 segundos:
seleccion del lote 3282.318 ms/7694 lecturas y cierre RF_PROCESOS_LOG
1394.778 ms/10353 lecturas. Revisar PID e indice antes de atribuir ese cierre a
bloqueo o conversion. Otra entrada del coordinador tiene 477 llamadas y el INSERT
del CATCH al log tambien tiene 477 ejecuciones: evidencia de entrada repetida en
manejo de errores; falta leer el mensaje concreto. No son 477 documentos exitosos.
Preparado RECV_REPLENISHMENT_ERRORES.SQL para consultar errores y metadatos PID.

INVOICE_TO_ENTREGA (2 llamadas, 2.299 ms, 69 lecturas) y
PROC_REPLENISHMENT_SUBDEPOT (2 llamadas, 16.710 ms, 6 lecturas) no concentran
el costo observado. WA_FOLIO_FACTURA y GET_REMISION_INFO tienen ultima ejecucion
el 19/10; no atribuir sus promedios historicos al lote del 20/10.

La captura no muestra transacciones activas en la base. No demuestra ausencia
de bloqueos durante el lote. Otra consulta (sesion 89) consume 79 millones de
lecturas y 314 segundos CPU; podria competir por recursos, pero no aparece como
bloqueador ni se dispone de su texto para atribuirle la lentitud.

La dependencia desplegada de DELIVERY_IDOC_TO_REMISION es EAI_OWNER.getConv:
la ausencia de dbo.getConv NO demuestra un error en esa version. La funcion
FN_EVAL_REMISION_OBD existe, pero su definicion recibida esta truncada. No
sustituir los procedimientos desplegados por las copias locales sin comparar.

Siguiente paso: revisar errores y respaldar/exportar SF_PROC_REPLENISHMENT
desplegado para preparar el ajuste de los cuatro DELETE y tres UPDATE por
ReferenceID, conservando sus reglas y tratamiento Unicode. Medir un lote
representativo despues; no refactorizar primero los cursores ni agregar indices
a todos los catalogos sin evidencia de costo.

## Analisis estatico previo

Actualizacion 12:37 (resultado de RECV_REPLENISHMENT_ERRORES.SQL):
los 100 registros devueltos son MSSQL-229, INSERT denegado sobre
T3.RF_PROCESOS_LOG, repetidos aproximadamente cada cinco minutos. En el flujo
revisado ese INSERT precede a la seleccion del lote; esas invocaciones fallan
antes de procesar documentos. Esto es independiente del costo medido en las
dos llamadas del parser. Confirmar propietario/contexto del job antes de
preparar permisos acotados; no asumir que la cuenta SSMS es la del job.

RF_PROCESOS_LOG.PID es DECIMAL(10,0), compatible con @nPID NUMERIC(10,0)
del coordinador local. Solo se reportan indices (FECHA_PROC_BATMD,PROCESO)
y (PROCESO,FECHA_PROC_BATMD), ninguno con PID como clave inicial.
Un indice no unico por PID es candidato concreto para acelerar el UPDATE
de cierre (10353 lecturas en la captura). No crear uno unico sin revisar
duplicados ni atribuir este acceso a una conversion de tipos no demostrada.

Analisis estatico de los archivos MSSQL locales. El usuario reporta 2 documentos
por segundo. Falta medir las sentencias y contrastar las versiones desplegadas
en AZCRNMXNEVTD06 / T3QA. No se han cambiado procedimientos ni indices para
este flujo. No se atribuye todavia un porcentaje del tiempo a cada hallazgo.

## Flujo revisado

```text
EAI_OWNER.RECV_REPLENISHMENT
  LOG_START, GETCONV, FN_CHECK_INSTANCE
  SF_PROC_REPLENISHMENT
    GETCONV (por partida)
    T3.FN_EVAL_REMISION_OBD (Receive Other; fuente local ausente)
    PROC_REPLENISHMENT_SUBDEPOT
      T3.DELIVERY_TO_SUBDEPOT (cliente habilitado y Receive Other)
        WA_FOLIO_FACTURA (SUBD)
    INVOICE_TO_ENTREGA
      FN_GET_CLIENTE_TMD
    T3.DELIVERY_IDOC_TO_REMISION (OBD YES o Transportation)
      dbo.getConv (fuente local ausente)
      T3.GET_REMISION_INFO
      WA_FOLIO_FACTURA (REM)
```

Los procedimientos SF_WA_PROC_REPLENISHMENT y WA_ERR_REPLENISHMENT no aparecen
llamados en esta ruta local. PROC_REPLENISHMENT_FILLRATE esta comentado.
El diagnostico incluye dependencias desplegadas y triggers para detectar rutas
adicionales. No se puede dar por revisado el cuerpo de las dos funciones ausentes.

## Prioridades de rendimiento

| Prioridad | Evidencia local | Accion propuesta / validacion |
|---|---|---|
| 1 | SF_PROC_REPLENISHMENT declara @sReferenceID NVARCHAR(50). Hace cuatro DELETE por ReferenceID en HEADER, DETAIL, CONDITIONS y PARTNERS. Las tres primeras columnas se observaron VARCHAR(50) en el diagnostico previo de facturas. | Medir lecturas/tiempo y conversion en el operador de acceso; confirmar tipo de PARTNERS. Adaptar predicados al tipo indexado conservando Unicode, como en el parche de facturas. El parche de SF_PROC_PREINVOICE_IFC NO modifica este parser. |
| 1 | UPDATE de HEADER.PedidoSAP por ReferenceID dentro del cursor de partidas, mas UPDATE Order_Num y rama de volumen cero con el mismo parametro Unicode. | Revisar TODOS estos accesos, no solo DELETE. Una factura con N partidas repite N veces el UPDATE de PedidoSAP. Evaluar una sola actualizacion al final, conservando ultima partida, cero partidas, triggers y semantica ante errores. |
| 2 | @sMaterial NVARCHAR(50) compara contra MATERIAL y CFDI_PRODSERV en cada partida; MATERIAL se consulta nuevamente en conversion CAJ/PAQ. | Verificar tipos/planes e indices por Material. Reutilizar datos de conversion si se garantiza unicidad; no cambiar MAX/TOP sin revisar duplicados y reglas. |
| 2 | INVOICE_TO_ENTREGA une PREVENTA_GENERAL.Referencia con Order_Num/PedidoV3, ENTREGA por Factura e IFC_Folios_FE por Var_1. | Verificar indices que comiencen con Referencia, Factura y Var_1, respectivamente. Tener indice en PREVENTA_GENERAL.Factura no resuelve por si solo Referencia. Conservar UNION y semantica de duplicados. |
| 2 | Rutas de remision consultan y actualizan REMISION_DETALLE por Factura; subdeposito consulta MOV_CLIENTE.Cliente_SAP y MX_PRINT_DELIVERY. | Revisar esos accesos segun la rama realmente usada. En este flujo REMISION_DETALLE si tiene busquedas/UPDATE/DELETE. |
| 3 | El WHILE del coordinador ejecuta COUNT_BIG(*) sobre @Records en cada vuelta. | Calcular el total una vez despues de llenar el lote fijo. Reduce trabajo creciente con el lote; no atribuirle automaticamente los 500 ms/documento. |
| 3 | Cursor de items, cursor anidado de referencias, consultas de catalogos e INSERT de detalle por partida. | Despues de corregir accesos, medir XML/CPU; evaluar extraccion por conjuntos. Preservar el ultimo qualifier 001/999 y el arrastre de sPOrderNumber entre partidas. El comentario “set-based” no coincide con el cursor real. |
| 3 | La seleccion de pendientes filtra QUEUE_NAME, CREATED y PROCESSED IS NULL y lee XML. FN_CHECK_INSTANCE se repite por mensaje. | Revisar plan e indice de pendientes antes de proponer uno filtrado. Considerar validar una vez por instancia distinta solo si es aceptable fijar configuracion durante el lote. |
| Condicional | WA_FOLIO_FACTURA se comparte con facturas y usa UPDLOCK/HOLDLOCK. | El indice IX_RI_NRIV_RELACION_SAP_CLASE ya fue creado en T3QA el 19/10. Comprobar que existe y su uso; no duplicarlo ni retirar bloqueos que protegen folios. |

NVARCHAR tiene precedencia sobre VARCHAR. Esto sustenta la hipotesis de conversion
de la columna, pero NO prueba por si solo que exista un scan en el plan desplegado.
Referencia: [Microsoft: precedencia de tipos](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql).

## Integridad, transacciones y avisos

Estos hallazgos no son mediciones de rendimiento. Requieren confirmar la version
desplegada y pruebas funcionales antes de corregir.

- El parser no inicia una transaccion que abarque borrados, reconstruccion y
  llamadas hijas. SET XACT_ABORT ON por si solo no hace atomico el documento.
  En autocommit puede quedar trabajo parcial si una sentencia posterior falla.
- Actualiza el mensaje a Processed ANTES de las llamadas finales. Varios hijos
  registran errores y no los relanzan: Processed no prueba que la entrega/remision
  haya terminado. Verificar tablas finales y log de errores para medir exito real.
- RECV_REPLENISHMENT captura y registra el error, sin THROW ni cierre del componente
  en CATCH. Puede interrumpirse el lote sin cerrar FIN/STATUS. Con una transaccion
  externa no confirmable, la escritura del propio log tambien puede fallar.
- WA_FOLIO_FACTURA inicia/termina solo su propia transaccion. Sus errores se
  silencian; no aporta atomicidad al documento completo. No hay evidencia local
  suficiente para afirmar que este flujo cause actualmente Msg 266 o una fuga:
  medir @@TRANCOUNT de entrada/salida y XACT_STATE en pruebas de exito y fallo.
- T3.DELIVERY_IDOC_TO_REMISION desasigna ScrCtroSociedad y posteriormente lo vuelve
  a abrir en la rama INSERT/origen distinto de 0000: la fuente local contiene un
  defecto de ciclo de vida del cursor. Tambien desasigna cursores de detalle
  dentro del bucle de encabezados; multiples encabezados pueden fallar.
- La conversion a cartones en esa misma rutina actualiza REMISION_DETALLE
  solamente por Factura, aunque recorre partidas individuales. Puede sobrescribir
  todas las partidas con la cantidad de una de ellas. Debe identificarse la clave
  de linea real antes de corregir; no basta agregar un indice.
- DELIVERY_TO_SUBDEPOT desasigna ScrDetail dentro del bucle de encabezados y
  acumula @nRecords entre documentos. Revisar cardinalidad de joins/duplicados.
- @nFactor_KG, @sUM y cantidades de material no se reinician antes de SELECT
  por partida. Si no existe el siguiente material, pueden conservar datos
  anteriores. Comprobar la regla deseada para productos desconocidos.
- MAX de la conversion CAJ/PAQ puede recibir NULL cuando NULLIF evita division
  por cero. Es candidato al aviso “Null value is eliminated”; corregir filtrando
  resultados nulos y conservando el fallback 1, sin desactivar ANSI_WARNINGS.
- El parser maneja referencias de 50 caracteres pero INVOICE_TO_ENTREGA recibe
  VARCHAR(30). Verificar longitudes reales antes de ampliar interfaces.
- No paralelizar consumidores antes de resolver reclamacion de pendientes y
  proteccion por documento: ambos pueden seleccionar las mismas filas pendientes
  y reconstruir simultaneamente las mismas tablas persistentes TMP_DOCUMENT.

## Medicion y siguiente paso

1. Abrir RECV_REPLENISHMENT_DIAGNOSTICO.SQL en SSMS conectado a
   AZCRNMXNEVTD06 / T3QA. Ctrl+D para cuadricula y F5 sin seleccionar texto.
   Ejecutar despues de un lote habitual; no ejecuta documentos ni cambia objetos.
2. Enviar primero las tablas 03_PROCEDIMIENTOS, 04_SENTENCIAS y 05_CLAVES.
   Guardar las otras tablas para revisar indices, dependencias y transacciones.
   Si no hay cache, volver a consultar despues del siguiente lote normal.
   Guardar XML desde la celda completa si hace falta inspeccionar el operador;
   texto truncado a 256 caracteres no sirve para confirmar el plan.
3. Para bloqueos/transacciones activas, ejecutar tambien durante el lote desde
   otra ventana. Un resultado vacio despues del lote no descarta bloqueos previos.
4. Registrar inicio, fin, documentos completados correctamente, partidas y tipo
   de entrega. Separar Receive Other/Transportation y rutas de subdeposito/OBD.
5. Con evidencia preparar un parche acotado, respaldo, reversa y pruebas de
   integridad; medir de nuevo antes de refactorizar cursores.

Los contadores de cache son acumulados y se reinician al recompilar/expulsar planes.
No sumar tiempos inclusivos de padre e hijos ni confundir llamadas por partida
con documentos completos. Los hijos compartidos pueden incluir otros flujos.
Referencia: [Microsoft: sys.dm_exec_query_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql).

No se promete repetir los 18.98 documentos/segundo de RECV_INVOICE: son rutas,
datos y cantidades de partidas diferentes. La primera prioridad es contrastar
el costo de los cuatro DELETE y los UPDATE repetidos por ReferenceID.

Validacion del diagnostico: ejecutado completo sin errores en LocalDB, sobre
master, sustituyendo el guard de base solo en memoria. Esto comprueba sintaxis,
consultas de catalogos/DMVs y manejo de objetos ausentes; no valida planes ni
rendimiento del flujo real. El archivo entregado mantiene el guard T3QA.

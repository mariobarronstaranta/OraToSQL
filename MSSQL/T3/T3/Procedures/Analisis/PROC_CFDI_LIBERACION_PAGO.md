# Analisis de T3.PROC_CFDI_LIBERACION_PAGO

Revision del 27 de octubre de 2026 sobre la definicion del repositorio.
Se agregaron comentarios al [procedimiento SQL Server](../PROC_CFDI_LIBERACION_PAGO.sql)
y se contrasto con su [contraparte Oracle](../../../../../ORA/T3/T3/Procedures/PROC_CFDI_LIBERACION_PAGO.SQL).
No se consulto ni modifico una base remota; el estado instalado puede diferir.

Actualizacion del 28/10/2026: ya esta disponible
[FN_VALIDA_RFC](../../Funciones/FN_VALIDA_RFC.SQL). La ausencia indicada en el
analisis original corresponde a la revision del 27/10. Se preparo el paquete
de [precondiciones y conciliacion](../../../Diagnosticos/Liberacion_Pago_20261028/README.md),
que consulta la funcion instalada y revisa tambien el riesgo de factura
VARCHAR(4) del generador, sin modificar procedimientos de negocio.

## Proposito y recorrido para mantenimiento

Es el coordinador del proceso 613. Selecciona cobranzas pendientes y llama
al generador de pagos cuando la version configurada es `4.0`. No calcula
los impuestos, no construye el layout directamente y no certifica timbrado.
No recibe parametros ni devuelve un resultado de negocio por OUTPUT o SELECT.

1. Define el cursor de candidatos; la consulta se abre dentro del TRY.
2. Obtiene un PID de `EAI_OWNER.ProcessID`, pone el componente en ejecucion
   mediante `LOG_START` e inserta el inicio en `RF_PROCESOS_LOG`.
3. Por cada fila guarda `Factura` como referencia de diagnostico e incrementa
   `Proceso_1`. Si `VersionCFD='4.0'`, delega al generador.
4. Tras el recorrido normal cierra/libera el cursor, marca el componente
   disponible (`Status=1`) y registra fin y contadores.
5. Si el coordinador recibe un error, imprime su contexto y escribe
   `EAI_OWNER.MX_EAI_MESSAGE_LOG`. No relanza el error en la version actual.

`Proceso_1` significa filas recorridas; no es un conteo de pagos enviados,
generados correctamente o timbrados. `Proceso_2`, `Proceso_3` y `Proceso_4`
se inicializan en cero y nunca se incrementan.

## Reglas de seleccion

| Condicion | Efecto observado |
|---|---|
| `Cobza.Nota_Venta = CFD.Nota_Venta` mediante INNER JOIN | Exige documento de venta relacionado. No garantiza una fila por asignacion si hay duplicados. |
| `Fecha_Envio` convertida a texto y reemplazada con `'null'` | En la columna de fecha actual selecciona SQL NULL. No es una comparacion por dia. |
| `Via_Pago = '01'` | Solo admite ese codigo; no se infiere aqui el significado externo del catalogo. |
| `UUID_Venta IS NOT NULL` | Exige un UUID informado; no valida su contenido. |
| `Created_By != 'INTERFACE'` | Excluye INTERFACE y tambien NULL por la semantica de la comparacion SQL. |
| `Fecha_Pago >= '20200921'` | Corte fijo inclusivo al 21/09/2020, 00:00. No filtra por dia de ejecucion ni por Fecha_Proc_BATMD. |
| `CFD.Metodo_Pago != 'PUE'` | Excluye PUE y NULL; no exige expresamente PPD. |
| Status distinto de PendienteT3 y Canc Pago | El status NULL se trata como EMPTY y pasa estas exclusiones. |
| `FN_VALIDA_RFC(RFC) > 0` | Solo admite el retorno positivo del validador. No se encontro su implementacion para describir reglas internas. |
| Asignacion fuera de RF_ERROR_LOG con rutina GENERAR_PAGO | Omite referencias ya registradas. El subquery excluye NULL para evitar su efecto en NOT IN. |

La version tiene prioridad por RFC (`CFDI_RFC_SETTING`, Parametro VersionCFDI)
y usa `MAX(Valor)` sobre texto. No selecciona por fecha ni valida que sea la
version numerica mas reciente. Solo si ese resultado es NULL usa
`GETCONV('CFG Settings','VersionCFDI')`. Un valor vacio no activa el fallback.
GETCONV devuelve la entrada si no existe equivalencia, por lo que sin
configuracion no queda garantizada la version `4.0`.

No hay comparacion de igualdad entre fechas con horas ni parametro BATMD
en este procedimiento. El corte historico `>=` es intencionalmente una
comparacion de fecha/hora contra un limite, y no se cambio a DATE.

## Procedimientos, funciones y secuencia utilizados

| Dependencia directa | Uso y contrato observado |
|---|---|
| [EAI_OWNER.LOG_START](../../../EAI_OWNER/Procedures/LOG_START.SQL) | Recibe el componente 613; actualiza `MX_COMPONENTS.Status=2` y `Last_Run`. |
| [T3.PROC_V20_GENERAR_PAGO](../PROC_V20_GENERAR_PAGO.sql) | Se invoca solo para version 4.0. Prepara el layout y, cuando procede, escribe el envio/documento y la fecha de envio de la cobranza. |
| [EAI_OWNER.GETCONV](../../../EAI_OWNER/Functions/GETCONV.SQL) | Resuelve la version general desde MX_HashTable. Se reviso su fuente y se mantuvo sin cambios. |
| `T3.FN_VALIDA_RFC` | Filtro escalar por retorno positivo. Definicion no localizada en el repositorio; esto no demuestra ausencia en la base instalada. |
| [EAI_OWNER.ProcessID](../../../EAI_OWNER/Sequences/ProcessID.SQL) | Secuencia compartida usada con NEXT VALUE FOR para identificar la corrida. No es funcion ni SP. |

La llamada al generador es posicional. Para evitar confundir los nombres
historicos de sus parametros:

| Parametro del generador | Valor enviado por el coordinador |
|---|---|
| `@pFactura` | `Cobza.Asignacion_ID`, no Cobza.Factura. |
| `@pAccnt_ID` | `Cobza.Cliente_SAP`, no Cobza.Accnt_ID. |
| `@pOutput` | `0`, sin impresiones opcionales de diagnostico del camino normal. |

El generador usa a su vez `EAI_OWNER.GETCONV`, `T3.FN_ADJUST_GMT`,
`T3.FN_TRIM_CFDI` y `T3.FN_NUM_TO_CHAR_CFDI`. Estas son dependencias
indirectas del coordinador, observadas en las llamadas del generador.
No hay EXEC adicional a otro SP en el fuente revisado de ese generador.
La revision no certifica la implementacion de todas esas funciones ni
el recorrido completo de timbrado.

## Tablas afectadas

| Objeto | Acceso desde este coordinador |
|---|---|
| T3.CFDI_COBRANZA | Lectura de los candidatos. Fecha_Envio la cambia el generador, no este coordinador directamente. |
| T3.CFDI_DOCUMENTOS | Lectura del documento relacionado y su Metodo_Pago. |
| T3.CFDI_RFC_SETTING | Lectura de la version por RFC. |
| T3.RF_ERROR_LOG | Lectura para excluir referencias fallidas de GENERAR_PAGO. |
| T3.RF_PROCESOS_LOG | INSERT del inicio y UPDATE del cierre por PID. |
| EAI_OWNER.MX_COMPONENTS | UPDATE de disponibilidad al terminar; LOG_START realiza el cambio de inicio. |
| EAI_OWNER.MX_EAI_MESSAGE_LOG | INSERT del error del coordinador. |

Indirectamente GETCONV lee MX_HashTable. El generador consulta los datos de
cobranza, cliente, emisor, documento fiscal y reproceso; en su salida normal
puede insertar `T3.CFDI_DOCUMENTOS_ENVIAR` y `T3.CFDI_DOCUMENTOS`, y actualizar
`T3.CFDI_COBRANZA.Fecha_Envio`. Su CATCH escribe `T3.RF_ERROR_LOG`.
Esas operaciones no son prueba de respuesta del PAC ni timbrado exitoso.

## Hallazgos y diferencias que requieren una revision funcional separada

| Hallazgo | Comportamiento e implicacion |
|---|---|
| Version distinta de 4.0 | Oracle tiene ELSE con PROC_CFDI_GENERAR_PAGO. SQL Server no lo tiene: cuenta la fila pero no la genera; puede seguir elegible en otra corrida. |
| Tamano del lote | Oracle sale al alcanzar 500 filas. SQL Server no tiene ese limite ni un orden explicito. |
| Transacciones | Oracle confirma cada 50 filas, al salir por limite y al final. SQL Server no contiene BEGIN TRAN/COMMIT/ROLLBACK y depende del contexto del llamador. No agregar COMMIT arbitrario sobre una transaccion externa. |
| CATCH y cursor | SQL Server no cierra/libera ScrPrompt en CATCH. El cursor tampoco declara alcance LOCAL de forma explicita. |
| Resultado del job | El CATCH no usa THROW. Si logra insertar bitacora, el llamador puede recibir retorno normal aunque el proceso quedara incompleto. |
| Bitacora sin cierre | Al fallar el TRY no se actualizan Fin ni disponibilidad del componente; pueden quedar Fin NULL y Status=2. |
| Error interno del generador | PROC_V20_GENERAR_PAGO escribe RF_ERROR_LOG sin THROW. El coordinador puede continuar y cerrar normalmente aunque una fila no generara salida. |
| Contexto de error | El coordinador registra Factura; el generador usa Folio_ID como @strID dentro de su recorrido. Verificar que Referencia en RF_ERROR_LOG corresponda al Asignacion_ID que excluye el cursor. |
| Concurrencia | No hay reserva explicita de candidatos ni bloqueo de doble corrida en este procedimiento. LOG_START actualiza estado, pero no impide por si mismo otra ejecucion. |
| Rango del PID | Variable NUMERIC(8,0) frente a secuencia cuyo maximo es 9,999,999,999. A partir de 100,000,000 hay riesgo de desbordamiento en la asignacion. |
| Mantenimiento del SELECT | El cursor y ambos FETCH contienen 17 posiciones. Algunas variables solo reciben contexto; no deben reordenarse sin revisar ambos FETCH. |

El catalogo de jobs del repositorio registra ORA_471_T3_PROC_CFDI_LIBERACION_PAGO;
su validacion historica tambien enumera PROC_CFDI_GENERAR_PAGO, coherente con
el ELSE de Oracle pero no con una llamada activa del SQL actual. No se
modificaron jobs, rutas del generador, funciones ni politicas transaccionales.

Posibles optimizaciones para otra fase: expresar Fecha_Envio IS NULL sin
convertir la columna, revisar costo de FN_VALIDA_RFC por fila, el agregado
por RFC y los accesos a RF_ERROR_LOG. Requieren plan/lecturas/indices reales;
este analisis no propone DDL ni afirma un cuello de botella medido.

## Cambios realizados y validacion

- Comentarios de proposito, reglas, contratos de parametros, NULL, version,
  cursor, contadores, bitacoras, transacciones y dependencias.
- Reparacion de un identificador partido: `@Do` seguido en la linea siguiente
  de `c_Status` se unio como `@Doc_Status` en el primer FETCH. El original
  no pasaba el analizador sintactico; no era solamente ajuste de formato.
- Se conservaron ALTER PROCEDURE, codificacion UTF-16 LE con BOM y CRLF.
- TSql160Parser: cero errores en la version documentada. Ambos FETCH con 17
  variables. Comparacion de tokens SQL contra el respaldo original tras
  reparar exclusivamente ese identificador: identicos, excluyendo espacios
  y comentarios. No hay cambios adicionales de SQL ejecutable.

Respaldo previo de trabajo: tmp/liberacion_pago_documentacion_20261027/
PROC_CFDI_LIBERACION_PAGO.antes.sql, SHA256
ACC64411B43C55A47B760106D95D5DA1E4B2BA3EA2A4F9AA43323D15287DB600.
La validacion es estatica: no equivale a compilar contra todas las dependencias
instaladas ni a probar un envio real. No se ejecuto el procedimiento ni se
altero la base. Las diferencias con Oracle quedan documentadas y pendientes
de una decision funcional; no se implementaron en esta intervencion.

# T3.PROC_T3_OT_GENERAL

Correccion funcional del 29/10/2026. La version local ahora valida el
resultado de PROC_V40_GENERAR_OTROS antes de marcar Fecha_Proc_BATMD.
No se ha instalado ni ejecutado esta correccion en T3QA desde el workspace.

## Problema corregido

El generador captura ciertos errores y retorna sin THROW. El coordinador
anterior marcaba la factura de todos modos. Tambien podia volver a llamar
al generador sobre documentos historicos ya enviados o timbrados.

El error de conversion numerica se corrige en PROC_V40_GENERAR_OTROS con el
paquete OTROS_Overflow_20261029, que el usuario reporto aplicado. Este cambio
del coordinador comprueba el resultado y evita acreditar una generacion
fallida; ambas correcciones son complementarias.

## Contrato y flujo actual

Sin parametros ni OUTPUT; no agrega SELECT de negocio. No crea PID ni
escribe RF_PROCESOS_LOG o MX_COMPONENTS. Su llamador conocido es
EAI_OWNER.RECV_INVOICE_INTERCOMPANY; procesa todos los candidatos de la
ventana, aunque pertenezcan a otros lotes.

1. Conserva el apartado Fecha_Proc_BATMD=2999-12-31 por sociedad/RFC/material
   y la llamada WA_ERR_INVOICE_PAYMETHOD(4), con sus alcances heredados.
2. Selecciona facturas distintas, pendientes, con detalle y Fecha_Trn en
   los ultimos cuatro dias. La fecha limite se fija al iniciar la corrida.
3. Por factura reserva cabecera y rangos de salida con UPDLOCK/HOLDLOCK.
   Revalida que siga pendiente; relee importes bajo bloqueo.
4. Omite documentos con UUID, timbre, envio, confirmacion o estado final,
   aunque falte layout. Omite tambien un documento y un layout ya existentes.
   No cambia por ello la fecha de proceso ni regenera salidas.
5. Rechaza salidas preexistentes parciales/duplicadas y cabeceras duplicadas.
6. Conserva la conversion de totales a numeric(22,2) y la tolerancia estricta
   menor que 0.10. Los descuadres o detalles desaparecidos quedan sin marcar.
7. Registra conteos previos de errores del generador y mapeo SAT. Despues
   del EXEC exige ausencia de errores nuevos, exactamente un documento y
   exactamente un layout con LEN(Informacion)>10, antes de marcar una unica
   cabecera pendiente.
8. Confirma la transaccion de esa factura si la inicio. Imprime contadores
   al completar la corrida y libera el cursor.

## Transacciones y errores

La generacion, sus inserciones y su marcado forman una transaccion por
factura. Un error detiene la corrida y revierte esa factura; otras facturas
ya confirmadas persisten si no hay transaccion externa. El apartado y helper
previos conservan su comportamiento original y no pertenecen a cada
transaccion de generacion.

Con transaccion externa usa SAVE TRANSACTION OTGeneralFactura. Solo revierte
ese savepoint mientras sea confirmable; si queda no confirmable, el llamador
debe revertir su transaccion. El coordinador no confirma la transaccion ajena.

Observa RF_ERROR_LOG para rutinas GENERAR_OTROS y PROC_CFDI_GENERAR_OTROS,
y EAI_OWNER.MX_EAI_MESSAGE_LOG para GET_SAT_CLAVEPRODUCTO, por referencia.
Los errores internos de una generacion fallida se revierten con sus salidas.
Intenta guardar el contexto en RF_ERROR_LOG con Rutina=PROC_T3_OT_GENERAL,
y devuelve THROW 53809 con factura y causa original. Este registro tambien
depende de la transaccion del llamador cuando exista una.

No altera el contrato del helper WA_ERR_INVOICE_PAYMETHOD ni sus errores
capturados; no agrega validaciones de cancelacion de cabecera o clase fiscal.
Los bloqueos protegen la generacion coordinada, pero no sustituyen indices
unicos ni coordinacion con otros productores/consumidores.

## Instalacion, verificacion y reversion

Usar el [paquete de instalacion](../../../Diagnosticos/OT_GENERAL_Control_Generacion_20261029/README.md).
Su 01 muestra primero definicion instalada y propuesta; @Aplicar=1 instala
el ALTER completo y respalda la definicion real de la base con sus opciones
SET. El 03 verifica sin ejecutar generadores; el 02 permite revertir solo
el modulo si no hubo modificaciones posteriores.

La fuente conserva USE T3QA, ALTER PROCEDURE, ANSI_NULLS ON,
QUOTED_IDENTIFIER ON, UTF-16 LE con BOM y CRLF. La variante SinUSE es
heredada y no se actualiza ni utiliza en este despliegue.

Las seis referencias del incidente ya tienen documentos historicos timbrados.
No desmarcarlas ni reprocesarlas para producir layouts que ya no estan en cola.

## Evidencia local

Respaldo de fuente anterior a esta correccion funcional:
tmp/proc_t3_ot_general_correccion_20261029/PROC_T3_OT_GENERAL.antes.sql.
SHA256: e81659768f8ab489b4ebc7b8e9401d1ad486173823725873a5c75cdac622cc41.
La documentacion anterior tambien esta respaldada en esa carpeta.

tests_local.py del paquete prueba el contrato con un generador simulado en
una base temporal de LocalDB: instalacion/reversion, exito, reejecucion,
proteccion de historicos, errores silenciosos/lanzados, salidas invalidas,
duplicados, tolerancia, ventana, centinela, concurrencia y transacciones
propias y externas. No certifica la generacion fiscal real ni los permisos,
rendimiento o datos de la instancia T3QA.

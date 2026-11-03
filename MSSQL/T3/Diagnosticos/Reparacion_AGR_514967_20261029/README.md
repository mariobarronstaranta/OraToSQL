# Cierre del caso 514967 y prevalidacion actual del agrupador

Preparado el 29/10/2026. Scripts generados; no ejecutados en T3QA ni Oracle.
No requiere un nuevo export: incorpora el control y detalle originales del
JSONL ya recibido. Usa un esquema independiente REPAIR_AGR514967_20261029.

## Que corrige

El grupo 514967 corresponde a julio y al RFC GOSL721114382. Oracle conserva
un control por 4306.27, con Fecha_Envio 22/07/2026 05:08:16, y una sola relacion:
514967 -> 262201489238, Fecha_Pago 21/07/2026.

T3QA tiene ademas un control de octubre y una relacion con 262201996890 que
no pertenecen a ese grupo. Se retiran esas dos asociaciones incorrectas y se
recupera el control historico correcto. Conservar la cancelacion valida NO
requiere conservar una relacion incorrecta hacia otro pago historico.

La cobranza 262201996890 permanece exactamente como esta: CHD-33522,
STATUS Canc Pago y Fecha_Envio NULL. No se crea su relacion con 529057, no se
inserta el control 529057 y no se cancela ni se regenera ningun documento.
El documento confirmado 529057 y las salidas individuales quedan protegidos.
No se cambia ninguna cobranza, secuencia, componente ni procedimiento.

## Ejecutar en orden

Mantener detenidos los procesos que modifican este alcance. Usar una ventana
nueva de SSMS en T3QA, sin transaccion externa.

1. `01_CAPTURAR.sql`: captura los dos controles y las dos relaciones actuales,
   prepara una fila original para cada tabla y guarda huellas protegidas.
   Exige el estado exacto revisado: una relacion de julio y la incorrecta de
   octubre, mas la cancelacion valida. Si cambia ese estado, se detiene.
   Debe mostrar CAPTURADO. No sobrescribe capturas anteriores.
2. `02_REVISAR.sql`: muestra ANTES y DESPUES PROPUESTO, ademas de la cancelacion.
3. `03_REPARAR.sql` con `@Aplicar = 0`: ensayo por defecto. Exigir
   `ENSAYO CORRECTO; TODOS LOS CAMBIOS REVERTIDOS`.
4. Revisado el ensayo, cambiar a `@Aplicar = 1` y ejecutarlo completo.
   Debe mostrar APLICADO. Vuelve a comprobar baseline, origen y protegidos.
5. `04_VERIFICAR.sql`: exigir dos tablas IGUAL A ORIGEN HISTORICO y cinco
   conjuntos SIN CAMBIOS. El grupo debe tener un solo control por 4306.27 y
   una sola relacion con 262201489238. No debe quedar la relacion del pago
   cancelado con 514967; esa retirada es el cambio deliberado de este paquete.
6. `06_PREVALIDAR_30_DIAS.sql`: solo lectura; revisa el estado ACTUAL antes
   de decidir la ejecucion de PROC_CFDI_PROCESA_PAGO_AGR @nDias=30.

## Prevalidacion y criterio para decidir ejecucion

La ventana usa Fecha_Proceso > CAST(DATEADD(day,-30,GETDATE()) AS date), sin
limite superior. El 29/10/2026 corresponde a >29/09/2026 00:00:00 si ese es
el dia del servidor. No reutilizar el diagnostico del 28 como fotografia actual.

La consulta entrega pendientes globales del liberador, secuencias, opciones
persistidas de los modulos, definicion instalada de LOG_START y conteo del
UPDATE inicial, que puede tocar filas aunque no haya grupos nuevos.
Luego proyecta grupos/detalle con los filtros actuales, informa mezclas de
clientes, importes, controles fuera de rango, UUID/documentos, CHECK e impuestos.
La simulacion usa solo tablas temporales; no ejecuta CHECK ni consume secuencias.

El analisis de datos admite hasta 50000 pendientes; si los supera se detiene
para evitar conclusiones sobre datos incompletos. Puede leer historico y no
es una fotografia transaccional: evitar actividad concurrente al tomarla.

Para decidir si ejecutar hay que revisar:

- Que el 04 confirme la reparacion y la cancelacion permanezca intacta.
- Si hay candidatos nuevos y cuantos. Cero candidatos significa que no se
  espera generar agrupaciones nuevas; no usar la ejecucion como prueba de altas.
- Si los grupos tienen diferencias de importe/detalle, fechas/cliente/Accnt_ID
  incompatibles, referencias fiscales faltantes o errores del CHECK.
- Que los pendientes anteriores del 614 esten identificados y conciliados.
- Que las secuencias/modulos requeridos esten disponibles y con capacidad.
- Cuantas filas podria cambiar el UPDATE inicial aunque no haya candidatos.

Los duplicados/layouts de pagos individuales de via 01 siguen pendientes de
su revision, pero no son por si solos un bloqueo de esta ruta agrupada, que
excluye via 01. Solo deben condicionar esta ejecucion si participan en sus
candidatos, sus relaciones o el UPDATE inicial. No reparar datos ajenos para
forzar que esta prevalidacion quede vacia.

El componente 614 falta tambien en Oracle. En el fuente local, LOG_START solo
hace UPDATE por Component y no falla si no encuentra filas; por tanto, su
ausencia no demuestra por si sola un bloqueo de ejecucion. El script muestra
la definicion instalada para comprobar ese contrato y distinguirlo de la
necesidad operacional de seguimiento. No se inventa un componente.

El paquete no modifica el SP de negocio, no agrega filtros para saltar datos
y no promete generacion/timbrado por el simple retorno de EXEC. La decision
se toma con la salida actual de la prevalidacion, no con reparaciones ya cerradas.

## Reversion y protecciones

`05_REVERTIR.sql` tiene `@Revertir = 0`; cambiar a 1 solo para una reversion
deliberada. Recupera los dos controles y las dos relaciones originales del
respaldo, incluso la asociacion incorrecta; no revierte la cancelacion.
Se detiene si hubo cambios posteriores en destino o en datos protegidos.

Captura/aplicacion usan una transaccion, MAXDOP 1 en las copias, espera de
bloqueo de 15 segundos y restauracion del timeout de sesion. No se garantiza
ausencia de deadlocks. Ante 1205/1222 no borrar el esquema: revisar Estado.
Se conservan los respaldos de los paquetes anteriores y del nuevo paquete.
Se rechazan triggers activos y FK entrantes sin deshabilitarlos.

## Verificacion local

Sintaxis de los seis scripts MSSQL validada con ScriptDom. Pruebas en una base
temporal aislada de LocalDB: captura, ensayo con rollback, rechazo de cambio
de cancelacion, rollback ante error despues del DELETE, aplicacion con paridad,
preservacion de cancelacion/salidas, rechazo de reaplicacion, rechazo de reversion
con documento modificado y restauracion del baseline. La base se elimino.
Evidencia: tmp/CodexAGR514967_86a719db/RESULTADO.txt desde la raiz del repo.
La prevalidacion completa requiere las tablas y datos instalados de T3QA;
no fue ejecutada en esa base ni probada como certificacion funcional integral.

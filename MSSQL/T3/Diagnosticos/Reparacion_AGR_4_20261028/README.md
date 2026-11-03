# Reparacion puntual de cuatro asignaciones: plan de ejecucion

Paquete preparado el 28/10/2026. NO se ejecuto en T3QA ni Oracle.
La preparacion incluye scripts reales, validacion de entrada, ensayo, respaldo
y reversion. Falta el export final con horas: los TXT previos no permiten
reconstruirlas. No se fabricaron fechas ni se uso medianoche como sustituto.

## Resultado esperado

| Asignacion | Factura | Grupo original octubre | Grupo julio vinculado incorrectamente |
|---|---|---:|---:|
|262201997234|V0225-134949|529120|514957|
|262201997964|V0822-105802|529096|514969|
|262201997720|V0179-67553|529050|514981|
|262201997198|V0440-70133|529179|514984|

Las cobranzas originales tienen UUID/Nota_Venta, saldo anterior igual al importe,
Status NULL y Fecha_Envio del 02/10/2026. Los cuatro controles de octubre quedan
Contado y sin Fecha_Envio. No se crean documentos ni layouts de esos grupos.
Los cuatro controles de julio se restauran completos desde Oracle, con sus
asignaciones legitimas: 262201490494, 262201491972, 262000077835 y 262201489175.
No se borran comprobantes historicos de julio.

## Orden obligatorio

### Paso 0: ventana de mantenimiento y alcance

Mantener detenidos los jobs/procesos que escriben estas tablas o consumen la
secuencia desde la captura de T3QA hasta terminar la verificacion. No ejecutar
PROC_CFDI_PROCESA_PAGO_AGR ni ninguno de los liberadores para hacer la reparacion.
Los scripts no detienen jobs automaticamente. Los bloqueos de tabla no reservan
NEXT VALUE FOR. El origen se exporta en una transaccion READ ONLY; esto tampoco
reserva numeros para una migracion posterior ni detiene Oracle.

Ejecutar todos los SQL MSSQL en T3QA, con permisos de crear esquema/tablas,
leer/escribir las cinco tablas y ALTER sobre la secuencia. No usar una
transaccion externa. Respaldos se conservan en REPAIR_AGR_20261028, sin limpieza
automatica. El paquete aborta ante triggers activos o FK entrantes activas:
no los deshabilita para forzar la correccion.

### Paso 1: exportar Oracle con horas y NULL reales

Usar SQL*Plus o SQLcl conectado a Oracle 19c o compatible con las expresiones
JSON del script. En una sesion NUEVA y desde una carpeta vacia para la salida:

```sql
@ruta/01_ORACLE_EXPORTAR.sql
```

El archivo inicia una transaccion READ ONLY y la termina con ROLLBACK; no altera
datos ni consume NEXTVAL. Genera seis JSON UTF-8 (configurar el cliente para
exportar UTF-8): CFDI_COBRANZA, CFDI_AGRUPACION_CTRL, CFDI_AGRUPACION_PAGO,
REGISTRO_FISCAL, REGISTRO_FISCAL_DETALLE y metadata. Conservar esos archivos.
JSON usa fechas YYYY-MM-DDTHH:MM:SS y NULL explicito. Si Oracle/cliente no soporta
la exportacion o emite errores, no convertir los TXT anteriores a mano.

Se exportan TODOS los detalles de las ocho agrupaciones y TODAS las relaciones
de las cuatro asignaciones. Si el origen arroja mas filas que las revisadas,
el validador exige una nueva revision del alcance en lugar de descartarlas.

### Paso 2: capturar T3QA

Ejecutar `02_MSSQL_CAPTURAR.sql`. Crea un esquema dedicado con:

- Antes_*: respaldo completo de las filas del alcance, incluidos duplicados.
- Origen_*: tablas vacias tipadas como el destino para recibir el export.
- Estado: fase del paquete, fecha, hash del export y maximo global de origen.

Se niega a sobrescribir una captura existente. La captura usa HOLDLOCK para
retener bloqueos compartidos/de rango hasta terminar; el motor puede escalar
bloqueos segun plan y volumen. Ya no solicita TABLOCKX. Usa MAXDOP 1 y espera
como maximo 15 segundos por bloqueo, restaurando LOCK_TIMEOUT al terminar.
No modifica registros de negocio. Si se necesita
una nueva captura, conservar esta y preparar otro paquete con un esquema nuevo;
no borrar el respaldo ni cambiar Fase manualmente.

Si devuelve 1205 o 1222, ejecutar `02A_DIAGNOSTICAR_DEADLOCK.sql` en una ventana
nueva. El 1205 revierte la transaccion victima; el CATCH tambien revierte ante
otros errores. Confirmar que no existe el esquema antes de reintentar el 02
completo. Si existe, revisar Estado/tablas y no borrarlo automaticamente.
El diagnostico consulta sesiones activas y hasta cinco eventos de deadlock del
ring_buffer de system_health, si hay permisos y aun estan retenidos. Las fechas
de esos eventos son UTC. No mata sesiones ni modifica opciones de la base.
Reducir bloqueos/paralelismo no garantiza ausencia de deadlocks. Mantener la
ventana de mantenimiento y conservar el grafico para identificar el ciclo real.

### Paso 3: validar JSON y generar/cargar origen

Desde PowerShell, en esta carpeta:

```powershell
.\03_PREPARAR_CARGA.ps1 -Entrada 'C:\ruta\export_oracle'
```

Alternativa con Python 3 disponible:

```text
python 03_preparar_carga.py --entrada C:\ruta\export_oracle
```

Esto genera `03_MSSQL_CARGAR_ORIGEN.sql` SOLO si pasan columnas, tipos,
longitudes, fechas, conteos y relaciones. Ese archivo no se entrega precargado
porque faltan los datos con horas. NO usar el archivo source.sql de las pruebas.
Ejecutar el archivo generado en T3QA: solo inserta en Origen_*, nunca en negocio.
Guardar el hash que devuelve. Los datos y respaldos requieren los mismos
controles de acceso que las tablas originales; no enviarlos a repositorios publicos.

Se esperan 4 cobranzas, 8 controles (4 julio + 4 octubre), 8 relaciones,
4 cabeceras fiscales y 26 detalles fiscales. No hay filas nuevas de
CFDI_USOCFDI_CLIENTE: Oracle no devolvio registros para este caso.

### Paso 4: revisar y ensayar

1. Ejecutar `03B_MSSQL_REVISAR_CAMBIOS.sql`; conservar resultado ANTES/ORACLE.
2. Ejecutar `04_MSSQL_REPARAR.sql` con `@Aplicar = 0` (predeterminado).
3. Exigir el mensaje `ENSAYO CORRECTO; TODOS LOS CAMBIOS REVERTIDOS`.

El ensayo comprueba la captura, hace la reconciliacion en una transaccion y
revierte TODO el DML. No cambia la secuencia en modo ensayo. Un error debe
investigarse: no eliminar validaciones para continuar.

### Paso 5: aplicar la reparacion revisada

En el mismo `04_MSSQL_REPARAR.sql`, cambiar exclusivamente `@Aplicar = 1`.
Ejecutarlo completo. La estrategia es reemplazo transaccional del alcance:
DELETE de las filas acotadas + INSERT de la fotografia completa de Oracle.
Se utiliza porque las tablas no tienen una clave unica que permita distinguir
sin ambiguedad todas las copias incorrectas. Se preservan fuera de ese alcance
las demas cobranzas, facturas y agrupaciones.

Antes de escribir, vuelve a comparar contra Antes_* mediante hashes SHA-256
de JSON por fila y sus multiplicidades (incluye NULL, espacios y mayusculas).
Si cambio el destino, aborta. Compara igualmente el resultado contra Origen_*.
No modificar manualmente Origen_* ni Antes_* una vez cargados.

El alcance de detalle incluye los ocho grupos y las cuatro asignaciones.
Si una asignacion ahora aparece en otra agrupacion adicional, aborta para
revisarla. Tambien aborta si ya hay documentos/layouts de los grupos Contado.

Al final ajusta la secuencia al mayor de: maximo global exportado de Oracle,
maximo local de controles, maximo local de detalles y valor actual local,
mas uno. No usa LAST_NUMBER como si fuera el proximo NEXTVAL. Con maximos
534442 y una secuencia inferior, el proximo seria 534443. Se conserva CYCLE;
el paquete no garantiza unicidad despues de agotar el rango y ciclar.

Si falla cualquier instruccion, revierte la transaccion. Si ya esta APLICADO,
no vuelve a ejecutar la reparacion. Un ensayo correcto no garantiza que una
aplicacion posterior pase si alguien modifica los datos entre ambos pasos.

### Paso 6: verificar

Ejecutar `05_MSSQL_VERIFICAR.sql` y conservar el resultado. Exigir:

- Fase APLICADO.
- Cinco tablas con IGUAL A ORIGEN dentro del alcance.
- Cuatro controles de octubre Contado, con Fecha_Envio NULL.
- Cobranzas con fechas/UUID originales, fuera de los pendientes.
- Cero documentos y layouts de las cuatro agrupaciones de octubre.
- Secuencia superior a los maximos conciliados.

Revisar `07_REVISION_OPERATIVA.sql` por separado. El componente 614 falta y
otros pendientes requieren su propia conciliacion: esta reparacion NO habilita
automaticamente una ejecucion general. No se inventa un componente parcial.
Obtener su configuracion original antes de preparar un INSERT de componente.

### Paso 7: reversion solo si resulta necesaria

`06_MSSQL_REVERTIR.sql` exige cambiar `@Revertir = 1`. Recupera la captura
Antes_*, incluidos los duplicados originales. Solo funciona si el alcance
permanece identico al origen aplicado; ante cambios posteriores se detiene.
No retrocede la secuencia para evitar reutilizar numeros. Esta reversion
restaura el estado previo, no lo convierte en un estado funcionalmente correcto.

## Comprobaciones realizadas

- SQL Server ScriptDom: sintaxis de los scripts MSSQL validada.
- LocalDB, base temporal independiente y datos SINTETICOS: carga, ensayo con
  rollback, rechazo de cambio posterior a captura, rollback ante error despues
  del DML, aplicacion y paridad de cinco tablas, rechazo de reaplicacion,
  rechazo de reversion con cambios posteriores y restauracion del baseline.
- Validador Python: rechazo de fechas sin hora; aceptacion de fixture completa.
- La base temporal se elimino al terminar. Evidencia inicial:
  `tmp/CodexRepairAGR_f6cfc7a2e9/RESULTADO.txt` desde la raiz del repositorio.
- No se ejecuto el export en Oracle: depende de su version/cliente. No se
  ejecutaron estos scripts en T3QA. La fixture usa fechas ficticias y no es
  una fuente de datos para la reparacion real.
- Tras el error 1205 reportado se repitieron satisfactoriamente las pruebas
  con la captura corregida. Evidencia: `tmp/CodexRepairAGR_24037a5612/RESULTADO.txt`.
  Estas pruebas no reproducen la concurrencia de T3QA ni identifican su deadlock.

`build_package.py` permite regenerar los scripts desde el DDL del repositorio;
no es necesario ejecutarlo para usar el paquete. `tests_local.py` solo prueba
LocalDB y crea/elimina su propia base temporal, nunca T3QA.

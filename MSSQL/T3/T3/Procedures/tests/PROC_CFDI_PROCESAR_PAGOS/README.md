# Pruebas de PROC_CFDI_PROCESAR_PAGOS

Revision: 23/10/2026. **Estado vigente: DATE/cursores y reglas Oracle corregidas
en PAGOS/control y probadas en LocalDB**. Metadatos recibidos del 23/10 13:49:52
corroboran las marcas de ambos procedimientos en T3QA; pendiente validar una corrida posterior.
GETCONV y FN_TOTAL_FACT compartidas se mantienen sin cambios. PAGOS usa suma
fiscal local con NULL sin detalle y la regla SAT restaurada.
No ejecuta motor Oracle ni certifica paridad completa. Ver
[cambios actuales](../../Analisis/PROC_CFDI_PROCESAR_PAGOS.CAMBIOS_ORACLE.md).
La corrida real anterior de 326 inserciones solo acredita DATE/cursores.

Despues de estas pruebas se ampliaron solo los comentarios del control para
mantenimiento junior. Se verificaron 1,364 tokens SQL identicos, incluidos
literales; el hash del archivo cambio por documentacion. Las evidencias
funcionales conservan el hash previo. Detalle en CAMBIOS_ORACLE, sin volver
a ejecutar pruebas de negocio por esa revision documental.

## Ejecucion funcional sintetica

Desde la raiz del repositorio, con PowerShell, SQL Server LocalDB y sqlcmd:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1
```

Crea CodexPagosDate_<identificador> con collation Latin1_General_100_CI_AS_KS_WS_SC.
Carga los 15 DDL T3 y los fuentes completos de PROCESAR_PAGOS, FN_TOTAL_FACT,
GETCONV, LOG_START y WA_CFDI_COBZA_ASIG_CTRL. Adapta USE y CREATE/ALTER a la base
temporal. EAI_OWNER auxiliar y ProcessID tienen estructura minima de prueba.
FN_TOTAL_FACT consume REGISTRO_FISCAL_DETALLE real del repositorio; no se usa
un sustituto ni la antigua tabla TestTotals.

Casos que pasaron con CURSOR_DEFAULT LOCAL y GLOBAL:

- Fecha BATMD con hora distinta de los movimientos y conservacion de horas escritas.
- Dias completos de inicio/fin de vigencia, clientes excluidos y fechas NULL.
- Diez asignaciones seleccionadas; limites del historial desde 01/09/2018.
- Saldos, parcialidades, acumulados anteriores, pagos y notas de credito.
- Factura/preventa, UUID CONFIRMADO, PendienteT3, penalizacion y cancelacion.
- Factura literal INCOBRABLE y RFC generico.
- Inicio/cierre de procesos 604/889, sin transacciones abiertas.
- Parametro NULL y dia sin asignaciones.
- 8115 inducido con ScrAsignaciones abierto: conserva el error, limpia cursores
  y permite una nueva ejecucion satisfactoria tras retirar el dato de prueba.

FunctionAssertions.sql comprueba suma de venta/envio/credito, varias lineas,
componentes NULL y cero para factura inexistente/vacia/NULL. Ese cero es la
regla de la funcion SQL compartida, conservada. PAGOS calcula su total localmente
y conserva NULL sin detalle conforme Oracle. CursorBinding.sql
reproduce por separado la causa anterior: un cursor declarado antes de SET no
recupera la factura; declarado despues si. Ese reproductor no indica un defecto
en el fuente corregido.

LastRun.txt guarda la evidencia sintetica vigente. El ejecutor retorna codigo
no cero si alguna asercion falla, aunque el procedimiento silencie la excepcion.
El 8115 del caso negativo es esperado; el 52013 se reserva a resultados funcionales
incorrectos y ya no aparece como fallo en la ejecucion satisfactoria actual.

## Reproduccion de la captura del 14 de octubre

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -CapturaReal MSSQL/T3/Diagnosticos/Pagos_20261014/Resultados_Ejecucion_LecturaPagos.txt
```

Crea una base con SQL_Latin1_General_CP1_CI_AS y CURSOR_DEFAULT GLOBAL, como la
captura. Carga diez asignaciones de ocho facturas, vigencias y documentos; prueba
primero las cinco definiciones instaladas exportadas y luego el fuente local
DATE con cursores corregidos. Los receptores bancarios omitidos se sustituyen
por valores ficticios de igual longitud. No modifica la captura original.

| Escenario comprobado | Resultado esperado |
| --- | --- |
| Instalado con parametro a medianoche | Cero filas; reproduce el defecto de seleccion temporal. |
| Instalado con hora exacta 13:27:28 | Seis filas con saldo/parcialidad NULL; reproduce el defecto de cursores. |
| Local DATE, cursores y reglas Oracle, a medianoche | Seis filas con parcialidades; CHD-33522 recupera Canc Pago/20723.95. Sin detalle fiscal, base/saldo NULL. |

V2363-145780 ahora devuelve base/saldo NULL conforme al original Oracle.
El total cero y segundo saldo -194.05 corresponden a la prueba anterior;
LastRealRun_AntesParidadOracle.txt la preserva. Los saldos se comprueban segun
los datos capturados, sin inventar detalle fiscal.
El modo actual requiere esa muestra sin cobranza previa y rechaza historiales
truncados; no es un importador general de cualquier base o captura.
La captura no contiene importes CFDI/configuracion SAT; estos se prueban con casos sinteticos.

LastRealRun.txt contiene el resultado vigente; LastRealRun_AntesCursores.txt
preserva el anterior. Ver [analisis y limites de la captura](../../../../Diagnosticos/Pagos_20261014/ANALISIS.md).

## Diagnostico de dependencias frente al fuente Oracle

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -AnalizarDependencias
```

Modo historico independiente: carga los dos fuentes de BaselineOracleParity
anteriores a la correccion y ejecuta DependencyParity.sql en base desechable.
Guarda LastDependencyParity.txt; espera deliberadamente el defecto anterior.
La ejecucion del 23/10/2026 reprodujo:

- SUM sin filas = NULL, pero FN_TOTAL_FACT SQL = 0; con fila de componentes NULL = 0.
- GETCONV conserva Source sin match y Target NULL con match; con Targets
  duplicados distintos no se presupone orden ni equivalencia Oracle.
- Control 889 con dos pagos de una via y uno de otra: dos grupos, una
  inconsistencia y cero pagos examinados, sin excepcion. Confirma el defecto
  del cursor dependiente en esa version historica.
- El predicado UPDATE por Asignacion_ID alcanza dos filas sinteticas de RFC,
  asignacion central y fechas diferentes. No demuestra duplicados en la base real.

**PASS aqui significa hallazgo reproducido, no defecto corregido ni paridad.**
No ejecuta Oracle. La semantica esperada de Oracle se obtiene leyendo el
original/documentacion. No modifica funciones/procedimientos del repositorio
ni bases reales. La evidencia anterior del control con cero grupos candidatos
no cubria esta rama activa.

## Pruebas de correccion conforme a reglas Oracle

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -ParidadOracle
```

Carga los fuentes actuales y ejecuta OracleParityAssertions.sql. Comprueba
veinte escenarios SAT/fiscales, tres ramas documentales, cardinalidad CFDI,
rollback del lote y limites numericos, transaccion externa recuperable/condenada,
opciones de sesion, control con grupos activos, IDs repetidos/NULL, empate,
espacios finales, CM/enviados, rollback externo, error tardio del control y
recuperacion. Ademas ejecuta el validador de lectura con base NULL y con dos CFDI.
LastOracleParity.txt conserva ambiente, hashes de fuentes y resultados.

Los errores 8114, 8115 y 50000 se inducen deliberadamente; se verifican sus
efectos/logs. PASS acredita las expectativas de estos casos, no un motor Oracle
ejecutado ni paridad bajo toda configuracion/concurrencia. No cambia bases reales.

## Validacion del diagnostico de lectura

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -SoloLectura
```

Ejecuta el diagnostico de lectura sobre los datos sinteticos, verifica secciones
y que no cambien asignaciones, cobranza, bitacoras o estados. No invoca el proceso
de negocio desde el diagnostico. Guarda LastRead.txt, separado de los otros modos.
La validacion previa de este modo paso; no se repite por cambios solo documentales.

## Compatibilidad con importe cero

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -ValidarCero
```

Ejecuta ZeroAmountAssertions.sql y guarda LastZeroAmount.txt con hashes/ambiente.
Se comprobaron cuatro filas: base cero con pago previo (saldo -100 y parcialidad
2), SAT positivo que sustituye cero por 348, venta T3 de total/subtotal cero sin
division por cero y ausencia de detalle. En este ultimo caso FN_TOTAL_FACT
compartida devuelve 0, pero PAGOS actual calcula SUM local y conserva NULL.
La prueba distingue aceptar un importe cero de consumir el retorno de la funcion;
no modifica esa decision ni cambia los procedimientos. Base temporal eliminada.

## Alcance y limites

El modo `-ValidarResultado` prueba el script de conciliacion posterior con diez
inserciones correctas y casos negativos de fila faltante, duplicado y saldo/numero
NULL. Guarda LastValidation.txt y usa solo la base temporal. El validador de
lectura real esta en `MSSQL/T3/Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql`;
no vuelve a ejecutar el proceso en la base real.

Las bases temporales se eliminan en finally, tambien si falla una asercion.
No se conecta a T3QA/produccion. No simula indices, triggers, concurrencia ni
permisos de la base real; no constituye un benchmark ni garantiza idempotencia.
La nueva correccion prueba limites transaccionales y propagacion segun
XACT_STATE; no repara los datos fiscales incompletos ni mide rendimiento real.

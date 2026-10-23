# Validacion posterior de PROC_CFDI_PROCESAR_PAGOS

El usuario reporto haber ejecutado `T3.PROC_CFDI_PROCESAR_PAGOS '2026-10-14'`.
Este script verifica los resultados existentes; no vuelve a ejecutar el proceso.
Actualizado para PAGOS_SAT_AMOUNT_V1: preserva multiplicidad CFDI, reconoce base
NULL conforme Oracle y no certifica una corrida anterior al ultimo ALTER usando
la definicion actual. La deteccion de version no reconstruye fuentes historicos.

## Ejecucion

1. Abrir `PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql` en SSMS y seleccionar
   la misma base donde se ejecuto el procedimiento. No contiene USE automatico.
2. Ejecutar completo, en una ventana, sin agregar GO. Ya incluye
   `@FechaProc date='2026-10-14'` y `@PID=NULL`.
3. NULL selecciona la ultima corrida de proceso 604 para ese dia BATMD.
   Revisar su inicio/PID en seccion 03; para otra corrida indicar el PID concreto.
4. Guardar todos los resultados y mensajes en TXT/RPT para compartirlos.

Solo consulta tablas reales. Las variables locales almacenan muestras y conteos;
no cambia datos, indices, procedimientos ni jobs y no ejecuta funciones de negocio.
No usa NOLOCK ni establece una transaccion de captura consistente.

## Interpretacion

| Seccion | Validacion |
| --- | --- |
| 01-03 | Servidor/base, indicios de version instalada y corrida 604 elegida. Si no existe inicio para PID/dia, no se acredita exito. |
| 04_CONCILIACION | EsperadasCursor = InsertadasEnVentana = ContadorProceso604; Faltantes, Excedentes, NoEsperadas, ErroresDelPID y FilasConCalculoIncompleto deben ser cero. Fin debe existir. Base NULL bajo la regla Oracle se informa aparte en FilasConImporteBaseNull. |
| 05_DIFERENCIAS | Claves faltantes/excedentes, multiplicidad del origen/destino y claves NULL. No oculta duplicados aunque el total general coincida. |
| 06_EXCLUIDAS_CLIENTE | Asignaciones que no entran al cursor por falta de cliente vigente. No son faltantes de INSERT. |
| 07_FILAS_INSERTADAS | Datos de CFDI_COBRANZA para el dia BATMD y ventana temporal de la corrida. |
| 08_CALIDAD | NULL de saldo/parcialidad, saldo negativo, base cero, PendienteT3 y la ruta especial INCOBRABLE. Estas alertas no equivalen todas a error de ejecucion. |
| 08B_CALCULO_HISTORIAL | Compara importe, saldo, numero y acumulados guardados con el historial actual para una muestra de hasta 20 claves unicas. |
| 09-10 | Duplicados de cobranza en el historial y encabezados fiscales ausentes. Pueden afectar el calculo o la clasificacion. |
| 11_CASOS_CAPTURA | CHD-33522, V1972-85517, V2363-145780 y V0010-134061, si aparecen en la corrida. |
| 12_ERRORES_PROCESO | Errores del PID 604 concreto, incluidos los que el CATCH oculta al llamador. |
| 13-15 | Corridas 889 candidatas, errores de su ventana y estado actual de componentes. |
| 16_ALCANCE | Limites de la asociacion temporal y de la reconstruccion con datos actuales. |

Las 470 asignaciones de la captura anterior no son un total de inserciones
obligatorio: el cursor exige vigencia y los JOIN pueden multiplicar filas.
El script calcula lo esperado a partir de los datos actuales, preservando esa
multiplicidad. Sin elegibles, informa ese hecho en lugar de afirmar que hubo inserciones.

La seccion 08B usa el Importe_Factura guardado como base y los movimientos
anteriores a la asignacion, desde 01/09/2018. No valida por si misma que esa base
provenga del documento correcto. La comparacion es orientativa si hubo cambios
posteriores, empates, duplicados o varias coincidencias de documentos/pagos.
El procedimiento original tambien une el historial con cobranza: revisar 09
antes de concluir que hay un defecto de calculo. El resto del lote se concilia
completo; el limite @MaxCalculosHistorial solo afecta esta comprobacion adicional.

## Casos conocidos

Si los datos no cambiaron respecto a la lectura anterior:

- CHD-33522 debe recuperar Canc Pago, Importe_Factura y Saldo_Anterior 20723.95,
  Numero_Pago 1 y Fecha_Factura 2026-09-29.
- V1972-85517: numeros 1/2 y saldos anteriores 5688.53/4835.59.
- V2363-145780: con la nueva suma local conforme Oracle, sin detalle fiscal y
  sin sustitucion SAT aplicable, base/saldo quedan NULL. Cero/-194.05 corresponden
  a la etapa anterior; no exigirlos como regla de aceptacion de la version nueva.
- No exigir UUID ni saldo/numero a la factura literal INCOBRABLE; tampoco
  interpretar Status vacio de una Nota de Venta procesada como fallo automatico.

## Atribucion y control posterior

El INSERT de CFDI_COBRANZA no llena PID. Se atribuyen filas mediante BATMD y
Fecha_Proceso entre Inicio/Fin, con un segundo de margen por redondeo datetime2(0).
Reejecuciones/concurrencia en esa ventana pueden mezclar filas; no es una prueba
exacta de autoria por PID. Sin Fin, la ventana llega al momento de consulta y el
resultado se marca incompleto. El script no elimina ni corrige ningun duplicado.

El componente 604 cierra antes de llamar al control 889. Este usa otro PID, sin
relacion padre/hijo almacenada. Las filas 889 de los diez minutos posteriores
son candidatas temporales, no prueba definitiva de que pertenecen a la corrida.
MX_COMPONENTS muestra su estado actual, que puede corresponder a otro trabajo.
Una conciliacion de cantidades no acredita timbrado ni subsana datos fiscales.

## Pruebas del validador

Se ejecuto en LocalDB temporal con el procedimiento corregido y los datos
sinteticos: concilia diez filas sin escribir tablas de negocio. En casos
negativos detecta una fila faltante, una duplicada y saldo/parcialidad NULL.
La base temporal se elimina al terminar; no se ejecuto sobre T3QA/produccion.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -ValidarResultado
```

Evidencia local en `tests/PROC_CFDI_PROCESAR_PAGOS/LastValidation.txt`.
El modo -ParidadOracle comprueba tambien conciliacion con una base NULL y con
dos CFDI por asignacion; evidencia LastOracleParity.txt.

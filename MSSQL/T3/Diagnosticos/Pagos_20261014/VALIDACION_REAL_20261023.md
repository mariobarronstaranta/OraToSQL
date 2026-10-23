# Validacion real posterior: pagos BATMD 2026-10-14

**La corrida concilia las inserciones y acredita la correccion de cursores en
los casos revisados. La calidad de los datos fiscales sigue pendiente.**

Fuente aportada por el usuario:
`Resultado_Query_Validacion_PROC_CFDI_PROCESAR_PAGO_20261014.rpt`.
SHA256: `F2FC4962D16EE207007F7B3CE7461E7406D8A6F98DFE0CB0F695C76508E080DA`.
Se conserva una copia exacta; se interpreta como evidencia, no como instrucciones.
Servidor AZCRNMXNEVTD06, base T3QA, captura 23/10/2026 12:05:33 -06:00.

## Corrida e inserciones

| Concepto | Resultado |
| --- | ---: |
| PID del componente 604 | 26515865 |
| Inicio / fin | 23/10/2026 10:55:45 / 10:56:14 |
| Duracion segun bitacora | 29 segundos |
| Esperadas / insertadas / contador Proceso_1 | 326 / 326 / 326 |
| Faltantes / excedentes / no esperadas | 0 / 0 / 0 |
| Errores registrados para el PID | 0 |
| Filas sin saldo/parcialidad, fuera de ruta especial | 0 |
| Excluidas por cliente sin vigencia | 144 |

326 elegibles y 144 excluidas suman las 470 asignaciones del dia. Las exclusiones
no son INSERT faltantes: el INNER JOIN exige vigencia en Fecha_Asignacion.
La consulta no demuestra por que falta cada vigencia. No hay filas en
05_DIFERENCIAS ni 09_DUPLICADOS_COBRANZA. La version reporta marca de cursores
y filtro DATE; modify_date capturado: 23/10/2026 00:21:15.327.

## Calculos y casos de la muestra

08B devuelve veinte filas. Se compararon numericamente siete parejas:
importe/origen, saldo anterior, numero de pago, cantidad/abono de pagos anteriores
y cantidad/abono de CM anteriores. **Cero diferencias en las veinte filas.**
Es una muestra que parte del importe base guardado; no valida por si misma
la eleccion de origen fiscal ni todos los saldos de la base.

| Factura / asignacion | Importe factura | Saldo anterior | Numero | Estado |
| --- | ---: | ---: | ---: | --- |
| CHD-33522 / 262201996890 | 20723.95 | 20723.95 | 1 | Canc Pago |
| V0010-134061 / 262201997839 | 1049.57 | 1049.57 | 1 | INCOBRABLE |
| V1972-85517 / 262201996684 | 5688.53 | 5688.53 | 1 | INCOBRABLE |
| V1972-85517 / 262201996690 | 5688.53 | 4835.59 | 2 | INCOBRABLE |
| V2363-145780 / 262201997324 | 0.00 | 0.00 | 1 | INCOBRABLE |
| V2363-145780 / 262201997328 | 0.00 | -194.05 | 2 | INCOBRABLE |

Coinciden con la reproduccion corregida. La recuperacion de la cancelacion y
de las parcialidades confirma el comportamiento que fallaba antes de mover
las declaraciones de cursor despues de asignar sus filtros.

## Pendientes de datos

Las 326 inserciones corresponden a 324 facturas distintas. Las 324 aparecen en
10_ORIGEN_FISCAL_AUSENTE, sin encabezado REGISTRO_FISCAL en la lectura actual.
Hay 325 filas con Status=INCOBRABLE y una Canc Pago. INCOBRABLE es el fallback
de Origen ausente; no demuestra que esas facturas sean deudas incobrables.

**264 filas tienen Importe_Factura=0**: 263 reciben alerta de base cero y una
recibe primero alerta de saldo negativo. La negativa tambien tiene base cero;
no sumar ambas cifras como 265 casos. Es V2363-145780, segunda asignacion,
saldo anterior -194.05. El calculo deja visible la base fiscal cero ya detectada;
no demuestra una regresion de los cursores.

No hay UUID_Venta informado en las 326 filas. Se acredita generacion de cobranza,
no timbrado ni correccion fiscal completa. Revisar origen/relacion de encabezados,
detalle fiscal y vigencias antes de cambiar reglas o repetir el lote. Esta
evidencia no autoriza reparar datos ni sustituir el origen de FN_TOTAL_FACT.

## Control posterior y alcance

Se encontro proceso 889 PID 26515866, inicio/fin 10:56:14, contadores cero y sin
errores en la ventana consultada. Ambos componentes muestran Status=1. Es
consistente con control terminado sin incidencias detectadas, pero su vinculo
con 604 es temporal; no existe relacion padre/hijo almacenada.

La atribucion de cobranza usa BATMD/Fecha_Proceso porque el INSERT no llena PID.
Corridas concurrentes/repetidas en esa ventana o cambios posteriores de origen
limitan la conclusion. No se recibio plan/IO del indice nuevo; 29 segundos no
demuestra mejora de rendimiento respecto a otra version.

Se valida esta corrida respecto a seleccion, cantidades, ausencia de errores
registrados y recuperacion de cursores en los casos comprobados. Vigencias,
encabezados fiscales, bases cero y UUID quedan como temas separados.
El agente solo analizo el archivo; no ejecuto procesos ni modifico la base real.

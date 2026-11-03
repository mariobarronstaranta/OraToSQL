# Segundo costo confirmado: busqueda SKU por partida

Fuente [reporte original](Captura_163038.rpt), recibido como
Resultados_Invoice_202610261631.rpt. Ambiente AZCRNMXNEVTD06/T3QA,
26 de octubre de 2026, captura 16:30:38 -06:00, final 16:31:04.
Query Store READ_WRITE, captura AUTO, esperas ON, intervalos de 60 minutos.
El filtro posterior usa la modificacion del parser, 15:24:27.020 -06:00.
Las horas UTC 21:26-21:31 del reporte equivalen a 15:26-15:31 locales.

## Estadisticas posteriores de Query Store

| Sentencia | QueryId / PlanId | Ejecuciones | Tiempo total | Media | CPU media |
|---|---|---:|---:|---:|---:|
| curSKU en SF_PROC_PREINVOICE_IFC | 18175 / 4179 | 6,714 | 33.322 s | 4.963 ms | 4.962 ms |
| DetailBase en INVOICE_TO_FACTURA | 30820 / 8103 | 1,542 | 23.349 s | 15.142 ms | 6.972 ms |
| INSERT RF_Complemento | 20736 / 4569 | 1,542 | 6.834 s | 4.432 ms | 0.079 ms |
| INSERT Factura_General | 20737 / 4570 | 1,542 | 3.966 s | 2.572 ms | 0.126 ms |

El cursor SKU consume aproximadamente 21.21 ms al repartir su tiempo entre
los 1,571 registros del lote. Es un objetivo relevante frente a la brecha
para llegar a 20-25 registros/s. No se promete recuperar todo ese tiempo:
la carga posterior debe medir el efecto real y su mezcla de partidas.

La consulta mantiene @sMaterialUOM NVARCHAR(50), derivada de SUBSTRING del
material, frente a T3.MATERIAL.MATERIAL VARCHAR(18). El indice inicial ya
existe. Se prioriza darle al optimizador una igualdad compatible con esa
clave, conservando la comparacion Unicode como residual. La consulta usa
GETCONV para la UOM y se mantiene su definicion y evaluacion en la proyeccion.

## Segunda intervencion preparada

[05_CORREGIR_BUSQUEDA_SKU.sql](05_CORREGIR_BUSQUEDA_SKU.sql) cambia una unica
declaracion de cursor de la definicion instalada. Si la clave admite ida y
vuelta sin perdida entre Unicode y VARCHAR(18), utiliza la igualdad VARCHAR
y conserva la igualdad Unicode. En otro caso declara la consulta original.
OPEN/FETCH, recorrido de todas las coincidencias, formulas, redondeos, manejo
de errores y cierre del cursor permanecen intactos. No elimina duplicados ni
sustituye el cursor por TOP(1). No modifica GETCONV ni crea indices.

Requiere los tres RI_REF_SEEK previos; los valida antes y despues. Comprueba
tipo/collation/indice de MATERIAL y formato del cursor. Respalda atomicamente
en EAI_OWNER.RECV_INVOICE_PERF_BACKUP con un nuevo RunId. La reversa generica
02 con ese RunId restaura el estado inmediatamente anterior, con ReferenceID
conservado. Se actualizo tambien el fuente mantenido del parser.

## Pruebas

Runner LocalDB repetido satisfactoriamente con collation
SQL_Latin1_General_CP1_CI_AS, DDL real de MATERIAL y GETCONV del repositorio.
Veinte casos equivalentes de cantidades, UOM, duplicados, ceros, NULL, vacios,
espacios, acento y Unicode no representable construido con NCHAR; errores
originales de cantidad invalida conservados. Se probaron aplicacion/repeticion,
permisos, preservacion de ReferenceID, reversa/repeticion y transacciones del
fuente completo. La base temporal se elimino al terminar. No se conecto al
servidor real. Ver [resultado](tests/RESULTADO.md).

Una microprueba del prototipo, 300 busquedas sobre 10,000 materiales sinteticos,
registro 897.788 ms antes y 15.999 ms despues (2.993 frente a 0.053 ms por
busqueda). Mide solo ese acceso en LocalDB: no es una mejora de 56 veces del
flujo completo ni predice la tasa real. El runner final tambien paso su prueba
aislada y la integracion del parche; no se usa su tiempo para prometer throughput.

## Otras evidencias, fuera del primer ajuste SKU

Query Store registra Buffer IO en DetailBase (12,601 ms), INSERT RF_Complemento
(6,714 ms), INSERT Factura_General (3,773 ms) y otras sentencias de factura.
Son esperas de lectura de paginas segun la categoria, no prueba de bloqueo ni
de WRITELOG. Se mantendran como segundo frente si la carga sigue por debajo
de la referencia despues del ajuste SKU. No cambiar memoria, MAXDOP, logging
o transacciones a partir de estas cifras aisladas.

El plan del hijo muestra dos Table Scan de MATERIAL en DetailBase; su codigo
contiene dos MAX correlacionados de atributos. No se modifican en este paquete:
hay que preservar multiplicidad del LEFT JOIN, valores NULL y la regla R044
que omite todo el detalle si hay material no convertible.

El UPDATE PedidoV3 del parser sigue con Index Scan, pero se ejecuto solo tres
veces y acumulo 309.6 ms; no explica la mayor parte de la brecha. Las alertas
de conversion residuales de ReferenceID o XML Reader no demuestran que el
parche anterior falle. No eliminar la condicion Unicode para borrar un aviso.

Estado: correccion SKU preparada y probada; aplicacion y nueva medicion por
el usuario aun pendientes. Objetivo 20-25 registros/s permanece abierto.

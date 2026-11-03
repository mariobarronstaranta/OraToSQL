# Medicion posterior al parche ReferenceID

El usuario aclara despues de las dos corridas que aun se esta por debajo de
las mejores marcas anteriores, que precisa en **20-25 registros/segundo**
(1,200-1,500/min). Estos resultados acreditan mejora frente a la referencia
inicial de 100/min; no cierran el objetivo de rendimiento.
Ver [continuacion del diagnostico](README.md#continuacion-recuperar-la-mejor-marca-historica).

El usuario confirmo que el parche se aplico antes de la primera ejecucion del
26 de octubre de 2026 y reporto despues otra corrida. Horarios en hora local
de Mexico.

## Primera ejecucion

| Dato | Valor |
|---|---:|
| Inicio | 2026-10-26 15:26:32 |
| Fin | 2026-10-26 15:27:22 |
| Duracion | 50 segundos |
| Registros procesados reportados | 706 |
| Registros por segundo | 14.12 |
| Registros por minuto | 847.2 |
| Tiempo medio del lote por registro | 70.82 ms |

## Segunda ejecucion

| Dato | Valor |
|---|---:|
| Inicio | 2026-10-26 15:30:32 |
| Fin | 2026-10-26 15:31:23 |
| Duracion | 51 segundos |
| Registros procesados reportados | 865 |
| Registros por segundo | 16.96 |
| Registros por minuto | 1,017.65 |
| Tiempo medio del lote por registro | 58.96 ms |

## Resultado conjunto

Las dos ejecuciones suman **1,571 registros en 101 segundos de proceso**:
15.55 registros/s, **933.27 registros/minuto** y 64.29 ms por registro.
Se divide el total de registros entre la suma de las duraciones; no se
incluye el tiempo entre lotes ni se promedian sus tasas sin ponderacion.

La meta reportada exige 40-50 ms de tiempo medio del lote por registro.
En la segunda corrida (58.96 ms/registro) queda una brecha de 8.96-18.96 ms
por registro. Para los 865 registros, la meta equivale a 34.60-43.25 segundos,
7.75-16.40 segundos menos que los 51 actuales. No se ha recibido aun el perfil
posterior que permita asignar esa brecha a sentencias o esperas concretas.

La referencia inicial del usuario era aproximadamente 100 registros/minuto
(600 ms por registro). La primera corrida alcanzo 8.47 veces esa referencia;
la segunda, 10.18 veces; las dos en conjunto, **9.33 veces**.
Es una mejora observada despues de aplicar el parche, con
una linea base aproximada; no es una prueba A/B de lotes de mezcla identica
ni una garantia para otros volumenes o clases de factura.

La aplicacion del parche y las dos mediciones quedan confirmadas por el usuario.
No se recibieron el RunId, nuevas lecturas/planes ni una conciliacion de
destinos. Los promedios por registro son tiempo total dividido entre registros;
no son nuevas mediciones por sentencia de los DELETE. No afirmar una reduccion medida
de lecturas, timbrado o integridad de inserciones por este dato.

La ultima evidencia de ambiente identifica AZCRNMXNEVTD06/T3QA. Esta medicion
de tiempos no incluyo otro encabezado de servidor/base y no acredita un
despliegue en una base diferente.

Fuentes del ajuste y pruebas: [guia](README.md),
[analisis anterior](ANALISIS_143154.md) y [pruebas LocalDB](tests/RESULTADO.md).

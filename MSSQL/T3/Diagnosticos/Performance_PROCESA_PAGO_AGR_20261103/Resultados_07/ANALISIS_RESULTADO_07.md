# Resultado 07: indice presente; medicion posterior pendiente

Fuente: `07_Reporte_Original.txt`, AZCRNMXNEVTD06 / T3QA, captura del
03/11/2026 14:07:31 -06:00. La ventana de Query Store va del
02/11/2026 14:07:31 al 03/11/2026 14:07:31, ambos con offset -06:00.

## El indice ya existe

`IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC` aparece habilitado (`is_disabled=0`),
sin filtro (`has_filter=0`) y coincide con las claves y cobertura propuestas:

| Posicion | Columna | Funcion |
|---|---|---|
| 1 | ASIGNACION_CENTRAL | Primera clave |
| 2 | FECHA_PROCESO | Segunda clave |
| INCLUDE | ASIGNACION_ID | Cobertura del cruce de compensacion |
| INCLUDE | FACTURA | Cobertura del cruce fiscal |

Esta evidencia actualiza el estado anterior: el indice ya esta en T3QA.
El reporte no incluye fecha de creacion ni el resultado de la comprobacion
de coincidencias del 06; no se puede afirmar a partir del 07 como o cuando
se creo ni que resultado arrojo esa comprobacion.

## No hay una medicion posterior visible

La fila de cache sigue siendo la misma ejecucion historica:

- UltimaEjecucion: **29/10/2026 00:17:07.210**.
- Ejecuciones en esa entrada: 1.
- Duracion: 107,029.831 ms, CPU: 16,456.611 ms.
- Lecturas logicas: 2,701,949; fisicas: 1,314,995.
- UsaIndicePropuesto: 0.

La fecha de esa ejecucion es anterior a la ventana consultada. Por eso su
valor UsaIndicePropuesto=0 no demuestra que una corrida posterior a la
creacion del indice lo haya descartado. Describe el plan historico retenido.

`04_METRICAS_POR_PLAN_QS` tiene encabezados pero **cero filas** en la ventana.
La evidencia recibida no contiene metricas de una ejecucion nueva terminada
que permita calcular mejora. No se concluye que el procedimiento nunca haya
vuelto a ejecutarse: el alcance es lo visible en este reporte y su captura.

`05_INDICES_DE_PLANES_QS` muestra 28113/7065 y 32735/8889, ambos con REGFIS_PK.
Esa seccion del script lista los planes historicos del UPDATE sin filtrar por
la ventana de runtime; que aparezcan alli no significa que se hayan ejecutado
el 03/11. No es una segunda medicion de performance.

## Siguiente paso

Conservar el indice actual. En la siguiente corrida de negocio prevista y
autorizada, usar el mismo @nDias=30 si corresponde a la prueba, y volver a
ejecutar `07_VALIDAR_MEJORA_UPDATE.sql` al terminar. El 07 no dispara el proceso.
Para separar el periodo, ajustar @Desde al momento de creacion conocido del
indice o al inicio de esa nueva corrida; los intervalos de Query Store pueden
incluir ejecuciones anteriores si cruzan el corte.

La nueva evidencia debe mostrar fecha posterior, plan usado, lecturas y tiempo.
Solo entonces comparar con 107.03 s / 2,701,949 lecturas logicas, teniendo en
cuenta datos procesables, cache y alcance. Una tabla de 56 millones de registros
puede tener diferentes cantidades de cobranzas recientes sin asignacion entre
corridas; no atribuir toda diferencia al indice sin revisar la carga.

Este resultado no justifica crear otro indice ni modificar el SP. La primera
mejora ya esta instalada y falta observarla con una ejecucion posterior.
Durante esta revision solo se archivaron resultados y se actualizaron documentos;
no se ejecutaron procedimientos ni se hicieron cambios en T3QA.

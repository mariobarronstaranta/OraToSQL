# Resultado 01: prioridad en UPDATE de Asignacion_Central

Fuente: `01_Reporte_Original.txt`, captura de AZCRNMXNEVTD06 / T3QA del
03/11/2026 13:08:51.250. SQL Server 16.0.4305.5, compatibilidad 160.
La ejecucion cacheada relevante corresponde al **29/10/2026**, no al dia de captura.
Solo existe una ejecucion cacheada del agrupador en el reporte.

## Cuello de botella observado

| Medida | Resultado |
|---|---:|
| Duracion completa cacheada de PROCESA_PAGO_AGR | 107.867574 s |
| UPDATE inicial Asignacion_Central | **107.029831 s** |
| Proporcion del UPDATE respecto del total | **99.22 %** |
| CPU del UPDATE | 16.456611 s |
| Lecturas logicas del UPDATE | **2,701,949** |
| Lecturas logicas del agrupador completo | 3,131,357 |
| Liberador central, ejecucion cacheada | 0.139014 s |
| Grupos/relaciones creados segun PID109 306664 | 0 / 0 |

El procedimiento tarda unos 108 segundos aun sin crear grupos. La demora esta
concentrada en su primer UPDATE; optimizar primero #Grupos, CHECK o generador
no resolveria esta demora observada. La diferencia entre CPU y duracion requiere
investigar esperas/lecturas fisicas; no demuestra por si sola bloqueo ni IO.
Los contadores cero no prueban que el UPDATE no cambiara Asignacion_Central:
su @@ROWCOUNT se sobrescribe con el numero de grupos y no queda auditado aparte.

La bitacora 109, de 00:17:07 a 00:18:55, es consistente con esa magnitud. La
liberacion de 00:18:55 tiene contadores cero. Los tiempos del CHECK pertenecen
al 28/10 y no deben sumarse a la corrida del agrupador del 29/10.

## Volumen e indices existentes

- CFDI_COBRANZA: 56,115,146 filas aproximadas.
- REGISTRO_FISCAL: 154,792,173 filas aproximadas.
- REGISTRO_FISCAL_DETALLE: 489,131,127 filas aproximadas.
- TMP_ACCOUNT_HEADER: 1,096,194 filas aproximadas.

Los cruces iniciales ya tienen indices que deben aprovecharse o complementarse:

| Tabla / indice | Cobertura recibida |
|---|---|
| CFDI_COBRANZA_IDX8 | FECHA_PROCESO, sin INCLUDE. |
| TMP_ACCOUNT_HEADER_IX_ACCNT | CLEARINGDOCNUMBER, FISCALYEAR, sin INCLUDE. |
| REGFIS_PK | FACTURA, unico, sin INCLUDE; no declarado como PK. |

Por ello se retira como propuesta inmediata crear otro indice ordinario con
la misma clave ClearingDocNumber/FiscalYear. Si el plan demuestra lookups
costosos de Assignment, evaluar la cobertura del indice existente en vez de
duplicarlo automaticamente. REGFIS_PK permite buscar Factura, pero no cubre
Entrega/Referencia: el plan debe mostrar si se hacen lookups o un scan.

El reporte no muestra un indice enfocado en Asignacion_Central IS NULL mas
Fecha_Proceso. Ese acceso seria candidato para el UPDATE inicial si la
selectividad y el plan lo justifican; no se instala sin esos datos.
Un filtro Fecha_Envio IS NULL no corresponde a este UPDATE: su alcance es mas
amplio y no puede reducirse a pagos pendientes de envio por conveniencia.

Las estadisticas de IDX8 tienen 296,143 filas muestreadas sobre 56,108,722
y 11,440 modificaciones; las de REGFIS_PK 519,991 sobre 154,782,596 y 9,587
modificaciones. No alcanza para atribuir el problema a estadisticas viejas ni
para justificar un FULLSCAN indiscriminado de tablas de este tamano.

## La version instalada difiere del CHECK local

Las sentencias cacheadas del CHECK muestran `SELECT @nContado=sum(1)` y
`SELECT @pUUIDs=sum(1)`. El archivo local revisado contiene un cursor.
Esto demuestra una diferencia de implementacion; no permite reconstruir
toda la definicion instalada a partir de fragmentos truncados a 256 caracteres.
Antes de sustituirlo hay que obtener el fuente instalado. En esta evidencia
el CHECK no es la prioridad de latencia del agrupador.

No aparece el generador en las estadisticas recibidas. Su ausencia de cache
no prueba que nunca se haya ejecutado; esta corrida sin grupos no mide su
rendimiento con pagos nuevos.

## Siguiente paso concreto

Ejecutar `04_AISLAR_UPDATE_ASIGNACION.sql`, de solo lectura. Devuelve:

1. Definiciones instaladas de agrupador y CHECK como XML sin el truncamiento
   habitual de texto de SSMS.
2. Metricas completas del UPDATE, incluyendo lecturas fisicas si sigue en cache.
3. Plan de esa sentencia desde cache y planes/historia/esperas de Query Store.
   Query Store esta READ_WRITE/AUTO segun el reporte; falta confirmar captura
   de esperas y existencia de la historia del periodo.
4. Organizacion heap/clustered y estadisticas relevantes sin escanear paginas.
5. Conteo opcional de recientes sin asignacion con @MedirVolumenes=1. Por defecto
   esta apagado, para evitar lecturas grandes durante la primera revision.

No ejecutar una nueva corrida de negocio para obtener un plan. Tampoco ejecutar
primero el 02 completo: materializa el pendiente historico y puede ocupar mucho
tempdb en esta base. Con el cuello de botella identificado, primero obtener el
plan focalizado; luego decidir si hacen falta conteos especificos.

Las propuestas genericas del 03 permanecen como hipotesis para otros volumenes,
no como una lista aprobada de indices por instalar. No se modificaron SP,
indices, estadisticas ni datos de T3QA al revisar este resultado.

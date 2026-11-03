# Costo dominante confirmado: DELETE por ReferenceID

Captura: AZCRNMXNEVTD06 / T3QA, 26 de octubre de 2026 a las 14:31:54 -06:00.
Fuente [reporte original](Captura_143154.rpt), recibido como
ResultadosEjecucion_202610161433.rpt. La fecha interna del reporte es el 26,
independientemente del nombre del archivo. Termino a las 14:32:19.

## Resultado

| Sentencia de SF_PROC_PREINVOICE_IFC | Llamadas | Media ms | CPU media ms | Lecturas logicas medias | Ultimo DOP |
|---|---:|---:|---:|---:|---:|
| DELETE TMP_DOCUMENT_DETAIL por ReferenceID | 976 | 427.464 | 3,074.541 | 49,256.877 | 8 |
| DELETE TMP_DOCUMENT_HEADER por ReferenceID | 976 | 106.194 | 741.852 | 11,817.206 | 8 |
| UPDATE TMP_DOCUMENT_HEADER, PedidoV3 | 3 | 107.254 | 737.779 | 11,816.000 | 8 |

Los dos DELETE suman 533.659 ms y 61,074.083 lecturas logicas por llamada.
Frente a los promedios del mismo parser de la captura anterior (976 llamadas,
680.099 ms / 63,833.574 lecturas), equivalen aproximadamente al 78.47% del
tiempo medio y 95.68% de las lecturas. Se comparan sentencias secuenciales con
igual numero de llamadas y el mismo periodo de cache observado; son promedios,
no porcentajes garantizados para cada documento ni prediccion del siguiente lote.
No se suman el tiempo del parser y el de sus sentencias hijas.

El UPDATE de PedidoV3 tambien es candidato, pero solo se ejecuto tres veces:
no justifica ampliar el primer parche ni atribuirle el costo por cada factura.

## Accesos disponibles y comparacion instalada

La captura verifica REFERENCEID **VARCHAR(50)**, collation
SQL_Latin1_General_CP1_CI_AS, e indices habilitados y sin filtro con esa columna
en primera posicion:

- HEADER: TMP_DOCUMENT_HEADER_IXREF.
- DETAIL: TMP_DOCUMENT_DETAIL_IDX.
- CONDITIONS: IX_TMP_DOCUMENT_CONDITIONS_REFERENCEID.

Los tres DELETE instalados usan `WHERE ReferenceID = @sReferenceID` y no tienen
marcas RI_REF_SEEK. El fuente del parser declara la variable NVARCHAR(30).
Hay evidencia suficiente para priorizar la igualdad compatible con la clave
ya indexada. No hace falta crear otro indice para esta primera intervencion.
El cambio mantiene el predicado Unicode original como condicion residual y
conserva la rama anterior si la referencia no soporta una conversion sin perdida.

## Alcance del XML recibido

[ShowPlanXML recibido](Plan_Diagnostico_143154.xml) contiene doce StmtSimple
del **diagnostico**, con consultas a QUERY_STATS, PROC_STATS, catalogos y
variables de tabla. No es el XML de SF_PROC_PREINVOICE_IFC, OXXO ni remision.
No se afirma haber observado en ese XML un Index Scan o CONVERT_IMPLICIT de
los DELETE de negocio. El costo dominante se acredita con el reporte de
estadisticas; el plan original del parser sigue sin exportarse correctamente.

La seccion de actividad esta vacia. Esto indica ausencia de solicitudes de
usuario visibles en la base al tomar esa foto, no ausencia de bloqueos durante
el lote anterior. No hace falta ejecutar documentos para aplicar el parche.

## Entrega

- [01_CORREGIR_REFERENCEID.sql](01_CORREGIR_REFERENCEID.sql): parche puntual
  sobre la definicion instalada de T3QA, respaldo atomico con RunId, validacion
  de predicados/tipos/opciones SET y rechazo de modulos firmados. Conserva
  permisos y correcciones ajenas al parche. No ejecuta facturas ni crea indices.
- [02_REVERTIR_REFERENCEID.sql](02_REVERTIR_REFERENCEID.sql): restaura el
  respaldo de ese RunId si la definicion no cambio posteriormente.
- Fuente mantenido SF_PROC_PREINVOICE_IFC.SQL actualizado con los mismos tres
  bloques para conservar el ajuste en futuros despliegues.
- [Pruebas sinteticas](tests/RESULTADO.md): aplicacion/repeticion, respaldo,
  permisos, referencias, transacciones, reversion y compilacion del fuente.

Pendiente aplicar y medir con un lote comparable. El costo alto de OXXO y
GET_REMISION_INFO observado en la captura anterior queda para una segunda
intervencion respaldada por sus planes; no se atribuye todo a este parche.

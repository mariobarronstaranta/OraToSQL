# Analisis de Resultados_28_Oracle.jsonl

Lectura de origen; no se modifico T3QA ni Oracle. Comparacion con el reporte 07 previo.

| Seccion | Filas |
|---|---:|
|COMPONENTES_ORACLE|1|
|CONTROLES_MISMOS_IDS|28|
|RELACIONES_ORIGINALES|102|
|CONTROLES_ORIGINALES|30|
|COBRANZAS_ORIGINALES|132|
|DETALLE_COMPLETO_GRUPOS_ORIGINALES|102|

## Hallazgos

- Los 28 controles con los mismos IDs son de julio en Oracle; en el reporte 07 tenian fecha de pago de octubre.
- De esos 28 controles, 25 tienen Fecha_Envio y tres son Contado: 514974, 514982 y 514985.
- Se recibieron 132 cobranzas unicas: 100 de julio y 32 de octubre.
- Las 32 de octubre incluyen 30 de via 01 sin relacion de agrupacion en este export y dos de vias 02/03 ya agrupadas en origen.
- No restaurar globalmente esas cobranzas ni poner Fecha_Envio NULL: T3QA ya genero salidas en la corrida individual 26517156. La comparacion de fechas debe conservar esa evidencia y distinguir los cortes.
- No basta borrar todos los detalles de los 28 IDs: contienen relaciones historicas legitimas de julio.
- El export del componente incluye solo 613; 614 no existe en la consulta de Oracle. No tratarlo como un registro olvidado en la migracion ni clonarlo sin revisar LOG_START y el contrato del proceso.

## Relaciones de octubre originales

| Asignacion | Factura | Via | Grupo | Estado control | Fecha envio control |
|---|---|---|---:|---|---|
|262201997114|V2565-35727|03|529099|Contado|NULL|
|262201996890|V0011-26521|02|529057|NULL|2026-10-02T05:08:15|

## Siguiente captura

`09_CAPTURAR_DESTINO_28.sql` obtiene controles/relaciones/cobranzas actuales y presencia de documentos y layouts. Es necesario para definir la reparacion sin deshacer la corrida individual ni duplicar salidas.
Este informe no certifica equivalencia global: faltan comparacion actual de destino y documentos originales de las dos agrupaciones de octubre.

# Comparacion 09 T3QA contra Oracle

Comparacion de reportes exportados; no sustituye el baseline transaccional antes de reparar.

| Seccion de T3QA | Filas |
|---|---:|
|01_AMBIENTE|1|
|02_CONTROLES|56|
|03_RELACIONES|132|
|04_COBRANZAS_ACTUALES|146|
|05_DOCUMENTOS_EXISTENTES|191|
|06_LAYOUTS_EXISTENTES|143|
|07_COMPONENTES|1|
|08_MULTIPLICIDAD_CONTROL|28|

- Relaciones comunes: 100.
- Relaciones adicionales en T3QA: 32.
- Relaciones de origen faltantes: 2.
- Controles historicos de julio con importe distinto de Oracle: 28.
- IDs con mas de una cobranza: 15 (no eliminar sin comparar filas).
- Cobranzas de origen ausentes en destino: 262201997114.

## Relaciones faltantes

| Agrupacion | Asignacion |
|---:|---|
|529057|262201996890|
|529099|262201997114|

## Preservar salidas actuales

Hay documentos/layouts individuales creados en T3QA sobre parte de las cobranzas de octubre. No restaurar Fecha_Envio globalmente desde el export de Oracle ni borrar estas salidas como parte de la conciliacion de agrupaciones.
Persisten layouts individuales de 4000 bytes (262201997560,262201997736,262201997738); revisar su contenido en una tarea separada, sin regenerar automaticamente.

## Alcance propuesto de la siguiente reparacion

Controles y relaciones: recuperar los 28 controles historicos de julio, eliminar sus copias incorrectas de octubre mediante reemplazo transaccional del alcance, preservar 100 relaciones legitimas y reemplazar las 32 relaciones adicionales por las dos relaciones originales de octubre.
No incluir actualizaciones de cobranza, documentos ni layouts en esa transaccion. Las diferencias de cobranza requieren conciliacion especifica porque T3QA ya genero salidas.
T3QA ya tiene el documento 529057 CONFIRMADO, UUID 906EB9B4-BE51-11F1-B5BA-215483603023 y fecha de timbre 02/10/2026 05:18:10; la consulta no encontro su layout. No reinsertar ni regenerar ese documento automaticamente. Oracle marca su control enviado.
La cobranza 262201996890 tiene una discrepancia adicional: Oracle Factura/Nota_Venta V0011-26521, estado NULL y fecha envio 02/10/2026; T3QA Factura/Nota_Venta CHD-33522, estado Canc Pago y sin fecha envio. Determinar si esos cambios de T3QA corresponden a pruebas o a una cancelacion valida antes de restaurarla.
El 09 encontro 146 filas de cobranza para 131 de los 132 IDs de origen. Hay 15 IDs con dos filas; cada par contiene una fila con estado NULL y otra INCOBRABLE. No borrarlas globalmente.
El componente 614 falta tambien en Oracle. No insertar un clon de 613 sin revisar la rutina LOG_START y el contrato operacional.

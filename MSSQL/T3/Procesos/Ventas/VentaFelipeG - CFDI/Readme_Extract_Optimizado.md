# Extract_Optimizado.sql

Versión alternativa para comparar con `Extract.sql`. El BAT y `Header.sql` siguen ejecutando el archivo original.

## Cambios

- Unifica las dos ramas de `UNION ALL` en una consulta con signo por `TIPO_DOCTO`. C003, C005 y C0FX conservan signo; C004, C006 y C025 invierten los importes correspondientes.
- Conserva las bonificaciones sin invertir signo ni agregarlas explícitamente al total.
- Conserva las uniones, vigencias y agrupaciones, incluida `VOIDDOC`, para mantener la multiplicidad de resultados.
- Expresa la suma de incobrables mediante `OUTER APPLY` por factura. Conserva todos los pagos históricos aplicables, sin introducir un filtro de fecha en cobranza.
- Añade `OPTION (RECOMPILE)` para optimizar usando los valores actuales de las fechas. Implica recompilar en cada ejecución. Referencia: [Microsoft, procesamiento de consultas](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide?view=sql-server-ver16).

## Prueba en destino

1. Abrir ambos SQL en SSMS, conectado a T3QA, y configurar el mismo periodo con fechas `YYYY-MM-DD`.
2. Ejecutarlos por separado, activando el plan de ejecución real y `SET STATISTICS IO, TIME ON;` en la sesión.
3. Comparar encabezado, número de filas, valores y cantidad de repeticiones de cada fila. Las filas empatadas en FACTURA/ENTREGA pueden cambiar de orden, igual que en el original.
4. Comparar lecturas lógicas, CPU, duración, estimaciones de filas y posibles derrames a tempdb. Repetir con periodos representativos y condiciones comparables de carga.

El índice propuesto `IX_Ventas_Cobranza_IncobrableNC`, o uno equivalente, es especialmente relevante para la búsqueda por nota de crédito. Sin acceso eficiente a cobranza, el plan de `OUTER APPLY` podría resultar más lento. El optimizador decide los accesos físicos; la reescritura no garantiza una mejora.

No se agregaron índices forzados ni lecturas con NOLOCK. No requiere objetos permanentes adicionales.

## Validación realizada

Ambos archivos se ejecutaron en la base aislada `CodexVentasMigrationTest` de LocalDB. Los CSV presentaron el mismo encabezado de 23 columnas y las mismas 5 filas ficticias, comparadas con su multiplicidad. Los datos incluyen C0FX, nota de crédito, bonificaciones, cruces opcionales, duplicados por VOIDDOC e incobrables históricos.

Esta validación comprueba equivalencia sobre el conjunto de pruebas; no constituye una medición de rendimiento con el volumen de T3QA. No se ejecutó la variante en el servidor destino.

Para adoptar la variante después de validarla, guardar una copia del `Extract.sql` original y colocar el contenido aprobado de `Extract_Optimizado.sql` en `Extract.sql`. Así se conservan los nombres que utiliza el operador. Esta sustitución no se realizó en la entrega.

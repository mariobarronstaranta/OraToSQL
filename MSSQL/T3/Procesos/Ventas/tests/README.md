# Pruebas locales de ventas

Usar exclusivamente `(localdb)\MSSQLLocalDB` y la base `CodexVentasMigrationTest`. `Schema.sql` crea esa base con copias del DDL de los siete objetos y datos ficticios. No ejecutarlo en T3QA. Si la base ya existe, la creación falla; no se elimina ni reemplaza automáticamente.

Preparación desde CMD, situado en `MSSQL\T3\Procesos\Ventas`:

```bat
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -No -b -i tests\Schema.sql
```

Copiar cada una de las tres carpetas operativas a `tests/work`, manteniendo sus nombres. Las copias sirven para probar sin generar archivos en las carpetas de entrega. Ejecutar `tests\RunLocal.bat`; este harness fija servidor, base y autenticación de LocalDB.

`Verify.py` valida los archivos de prueba con el lector CSV de Python y comprueba signos, columnas, límites de fecha, duplicados, incobrables históricos, comillas/saltos de línea y copia histórica. Python es una herramienta de QA, no una dependencia de los BAT operativos.

Para `InvalidPeriod.bat`, preparar `tests/work/invalid` con una copia de los tres archivos de `VentaFelipeG` y sustituir la fecha inicial por `2024-02-31`. La prueba espera error, ausencia de CSV finales y liberación de `.venta_lock`.

No repetir una extracción dentro del mismo minuto si existe su archivo final. Los datos y salidas de `tests/work` están excluidos de Git.

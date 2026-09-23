# Pruebas aisladas

No ejecutar estas pruebas en T3QA. Los scripts de prueba utilizan exclusivamente `CodexWebOrderTraceTest` en `(localdb)\MSSQLLocalDB`, con autenticación Windows. Los BAT operativos no requieren PowerShell.

`Schema.sql` es una copia de las definiciones relevantes del repositorio y de la función de compensación, preparada para crear una base de pruebas nueva con compatibilidad 160. No incluye datos de negocio ni credenciales. Si la base ya existe, el comando de creación falla; no elimina una base existente.

Desde la carpeta WebOrderTrace, en CMD:

```bat
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -No -b -i tests\Schema.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -No -b -d CodexWebOrderTraceTest -i soporte\sql\01_Infraestructura.sql -i soporte\sql\02_Reporte.sql -i soporte\sql\03_Procesar.sql
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -No -b -d CodexWebOrderTraceTest -i tests\Verify.sql
tests\RunSampleLocal.bat
tests\RunReportOnlyLocal.bat
```

`Verify.sql` instala datos ficticios y comprueba el lector CSV, mapeo, consumidores compartidos, compensación, periodos y reversión ante errores. Incluye un trigger de fallo inyectado, creado y eliminado solo dentro de la base de pruebas.

`RunSampleLocal.bat` copia los CSV actuales de la carpeta homóloga Oracle a `tests/work/client`, ejecuta los BAT y comprueba los conteos conocidos de la muestra (2,339 órdenes y 2,257 facturas). Si cambia la muestra original, esos conteos esperados deberán revisarse. Requiere la estructura completa del repositorio.

`RunReportOnlyLocal.bat` verifica prevalidación e instalación, genera reportes en una carpeta separada y compara los conteos y `INSERT_TS` antes y después.

`RunPublishLocal.bat` es un harness adicional para una carpeta `tests/work/publishclient` previamente preparada con los BAT y CSV de prueba. La entrega se dirige exclusivamente a su subcarpeta `delivery`. En desarrollo se usó una variante de los CSV con BOM, finales CRLF/LF, ausencia de salto final y una orden con coma y CRLF dentro del pedido del cliente; el CSV publicado se volvió a leer y se verificaron 195 registros, 26 columnas y el campo multilínea completo.

Los archivos de `tests/work` están excluidos de Git y se conservan localmente como evidencia. Una repetición dentro del mismo minuto puede detenerse por la protección contra sobrescritura del reporte; esperar al siguiente minuto y revisar `.wot_lock` antes de repetir.

El 9 de septiembre de 2026 se repitieron `RunSampleLocal.bat` y `RunPublishLocal.bat` con los nombres originales y los auxiliares en `soporte`. La exportación con `sqlcmd -y 0` se volvió a leer como CSV: 195 filas, 26 columnas, sin encabezados de herramienta adicionales y con el campo CRLF conservado. Se verificó que los siete nombres BAT/SQL de la raíz coinciden exactamente con los de Oracle.

Entorno usado: SQL Server LocalDB 17.0.4025.3, nivel de compatibilidad 160, herramientas ODBC 18. La prueba en motor 16.0.4265.3 y con datos de T3QA queda pendiente.

# Avisos NULL en el flujo RECV_INVOICE

Ejecutar `./Run.ps1` con PowerShell, sqlcmd y SQL Server LocalDB.
Se crea y elimina una base temporal con nombre unico; no se usan bases de negocio.

Se extraen cuatro consultas de los archivos reales:

- INVOICE_TO_PREVENTA: detalle por conjunto y cursor C030/C031.
- INVOICE_TO_FACTURA: cantidades y datos opcionales del material.
- T3.DELIVERY_WA_OXXO: numero de linea de envio.

Las expresiones originales se reconstruyen para obtener el resultado esperado
con ANSI_WARNINGS OFF solamente en esa fase de prueba. Las consultas corregidas
se ejecutan con ANSI_WARNINGS ON. Se comparan todas las columnas mediante EXCEPT
en ambos sentidos y el ejecutor falla si detecta el aviso 8153.

Las 16 comparaciones incluyen cantidades NULL, grupos sin valores, grupos vacios,
cantidades negativas, regla C019, materiales ausentes, duplicados, unidades vacias
y tamanos de paquete negativos. Tambien se valida la sintaxis de los tres modulos.
No se ejecuta el flujo completo de facturacion ni triggers de la base destino.

Las sumas conservan NULL cuando todos los valores originales son NULL. Los MAX
filtran sus entradas NULL en subconsultas independientes, sin eliminar filas de
los grupos ni cambiar la multiplicidad del JOIN utilizado para sumar importes.

Para desplegar, actualizar INVOICE_TO_PREVENTA, INVOICE_TO_FACTURA y
T3.DELIVERY_WA_OXXO. Tambien debe estar aplicada la version corregida de
SF_PROC_PREINVOICE_IFC preparada anteriormente. RECV_INVOICE no necesita un
cambio adicional para estos avisos. Se conservan los ajustes de transacciones.

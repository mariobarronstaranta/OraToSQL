# Exportacion Delivery_Hist compatible con BCP

El script original selecciona todas las columnas con SELECT * y usa | como
delimitador. En el archivo recibido hay 16 filas con 20 campos en vez de 19,
todas de Delivery 2656613453, con un | adicional despues del nombre del receptor.
Eso desplaza MATERIAL/MATERIALNAME/QUANTITY y explica el error de conversion
en la columna 16. Sin consultar Oracle no puede distinguirse definitivamente
si el | forma parte del nombre original o se agrego durante otra transformacion.

La sintaxis documentada de SQLcl es:

```sql
SET SQLFORMAT DELIMITED <separador> <comilla_izquierda> <comilla_derecha>
```

La instruccion recibida solo proporciona un parametro de comilla. Completarla
como `SET SQLFORMAT DELIMITED | " "` no resuelve el contrato con BCP: BCP busca
el primer terminador, sin interpretar comillas de CSV como proteccion del |.
La opcion -q afecta QUOTED_IDENTIFIER en SQL Server, no el escapado del archivo.

## Archivos y uso

1. Ejecutar `REVISAR_DELIVERY_HIST_ANTES_EXPORTAR.sql` en Oracle. Revisar
   colisiones del nuevo separador, CR/LF internos, fecha requerida, cantidades
   y longitudes. Si hay incidencias, investigarlas antes de exportar; el script
   de exportacion no las filtra ni las corrige automaticamente.
2. Ejecutar `EXPORTAR_DELIVERY_HIST_BCP.sql` completo con F5 en SQL Developer
   o como script en SQLcl. Usar salida UTF-8 y CRLF. Genera
   `Delivery_Hist_BCP.txt` en la carpeta Datos y conserva el TXT anterior.
3. El nuevo archivo tiene una cabecera y 19 campos separados por **~|~**.
   El | dentro de textos se conserva. Los NULL se representan como campos
   vacios; las fechas tienen formato yyyy-mm-dd hh:mm:ss y QUANTITY punto
   decimal con tres decimales. El filtro sigue siendo CREATED>31/07/2026 00:00:00.
4. En el comando BCP usar el archivo nuevo, mantener `-F 2`, `-C 65001`,
   `-r 0x0d0a` y cambiar el terminador a `-t "~|~"`.

Ejemplo sin contrasena escrita; BCP la solicita al omitir -P:

```powershell
bcp T3QA.T3.Delivery_Hist in "C:\Users\85233588\Documents\MigracionORA\OraToSQL\ORA\T3\T3\Datos\Delivery_Hist_BCP.txt" -S AZCRNMXNEVTD06 -U AT85233588 -c -C 65001 -t "~|~" -r 0x0d0a -F 2 -e "C:\Users\85233588\Documents\MigracionORA\OraToSQL\ORA\T3\T3\Datos\Delivery_Hist_BCP.log" -u -q
```

Antes de repetir una carga completa, revisar en destino que filas entraron en
el intento anterior: este cambio de formato no deduplica Delivery_Hist ni
retira datos previamente cargados. No se ejecuto ningun BCP ni consulta remota
desde el workspace; los scripts Oracle quedan preparados para su ejecucion.

La comprobacion de longitudes usa caracteres y el DDL local. No certifica la
representabilidad de todos los caracteres en la collation varchar del destino
ni posibles fechas anteriores al rango datetime de SQL Server. La consulta
del catalogo real en SQL Server prevalece sobre una copia local del DDL.

## Referencias

- [Oracle: SQLFORMAT DELIMITED](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/21.4/sqcug/working-sqlcl.html).
- [Microsoft: terminadores de campo/fila](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/specify-field-and-row-terminators-sql-server).
- [Microsoft: bcp y QUOTED_IDENTIFIER](https://learn.microsoft.com/en-us/sql/tools/bcp-utility).

# Exportacion de CFDI_COBRANZA: consulta de 60 dias

Abrir `EXPORTAR_CFDI_COBRANZA_BCP.sql` en una conexion Oracle y ejecutar
**todo el archivo con F5** en SQL Developer. En SQLcl, ejecutar:

```sql
SET ENCODING UTF-8
@"C:\Users\85233588\Documents\MigracionORA\OraToSQL\ORA\T3\T3\Datos\EXPORTAR_CFDI_COBRANZA_BCP.sql"
```

El spool genera o reemplaza este archivo en el equipo cliente:

```text
C:\Users\85233588\Documents\MigracionORA\OraToSQL\ORA\T3\T3\Datos\CFDI_Cobranza_BCP.txt
```

Formato: una cabecera, 42 campos separados por `|`, NULL como campo vacio y
numeros con punto decimal. El orden coincide con el DDL local MSSQL de
CFDI_COBRANZA y con las cabeceras de las exportaciones anteriores. Para cargar
con BCP, la cabecera requiere `-F 2`. Usar UTF-8 y finales de linea CRLF.
Los valores de texto se conservan y deben cumplir el contrato del separador:
sin pipes ni saltos de linea internos.

El script incluye exactamente:

```sql
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';
```

Ademas serializa explicitamente las siete fechas con esa mascara, con precision
de segundos, y configura punto decimal para los numeros. NLS_DATE_FORMAT fija
el formato de fecha de la sesion. [Oracle: NLS_DATE_FORMAT](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/NLS_DATE_FORMAT.html).

La consulta original se conserva dentro de `DatosCobranza`, incluidos sus JOIN,
el corte de 60 dias, el anio fiscal actual y sus posibles coincidencias repetidas.
El SELECT exterior convierte sus columnas en una linea de texto. El mecanismo
SPOOL guarda los resultados en un archivo del cliente.
[Oracle: comandos de SQLcl y SPOOL](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/22.1/sqcug/working-sqlcl.html).

Se verificaron estaticamente las 42 columnas, los 41 separadores y los filtros.
No se ejecuto Oracle ni se genero el TXT desde el workspace.

# Revision de EAI.SF_BITACORA_CFDI_RESUMEN

Revision: 2026-10-08. Se comparo el archivo principal MSSQL contra
`ORA/T3/EAI/Procedures/SF_BITACORA_CFDI_RESUMEN.SQL` en tres pasadas.
Las correcciones estan en `SF_BITACORA_CFDI_RESUMEN.SQL`. El archivo paralelo
`SF_BITACORA_CFDI_RESUMEN_OPTIMIZADO.SQL` NO contiene esta revision.

## Resultado

Se encontraron diferencias funcionales; no bastaba con que estuvieran presentes
todas las etapas. El archivo principal incluso declaraba el nombre _OPTIMIZADO,
pero el job 569 invoca EAI.SF_BITACORA_CFDI_RESUMEN. Se corrigio la declaracion.

Compilacion y 22 comprobaciones funcionales satisfactorias en LocalDB usando
resultados esperados derivados de las expresiones Oracle. No se ejecuto Oracle,
no se conecto a produccion y no se midio rendimiento productivo. No constituye
una certificacion de igualdad sobre datos reales.

## Pasada 1: fuentes, fechas y reglas

- Inicio NULL/vacio usa ventana y hoy, ignorando fecha final, como Oracle.
- ADD_MONTHS conserva fin de mes: 30/04 menos un mes debe ser 31/03.
  Se corrigio con EOMONTH. El periodo incluye todo el ultimo dia.
- Se conservaron las fuentes y multiplicidad de cada JOIN de las tres cargas:
  factura individual, preventa individual y CFDI agrupado.
- RFC individual procede de Paso; RFC de preventa de Cliente.
- Individual C003 positivo; otras clases negativas. Preventa C005/C0FX/C020
  positivas, otras negativas. C020/C021/C022 usan MX01, otras MX06.
- Cancelacion y anio 2999 dejan importe operativo inicial en cero; las reglas
  fiscales posteriores de envio/credito siguen aplicando.
- Entrega es opcional y su ubicacion tiene prioridad; vacio se trata como NULL.
- Agrupados conservan DISTINCT de historia y agrupacion por centro/fecha/folio.
- CONFIRMADO usa PAC; individuales PENDING/PUBLICADO usan T3. Agrupados PUBLICADO
  inicialmente tiene fiscales cero; al final Valor se normaliza a Monto_T3In.

## Pasada 2: nulos, multiplicidad y ajustes

1. Se retiraron ISNULL adicionales sobre importes PAC y CASE fiscales.
   Oracle no convierte esos NULL a cero.
2. Se retiraron ISNULL extra sobre Valor_Subt/Valor_IVA de detalle agrupado.
   Se mantienen solamente los NVL originales de envio y credito.
3. Se restauro la multiplicidad de Registro_Fiscal y CFDI_Agrupado; Oracle une
   todas sus cabeceras. Deduplicarlas cambia cantidades e importes.
   EXISTS limita los agregados fiscales a folios del informe sin multiplicarlos
   por filas repetidas de CFDI_INFORME.
4. Se suman TODOS los ajustes no nulos y distintos de cero por folio.
   Proceso_4 cuenta cada pareja fila-informe/ajuste, incluso netos iguales a cero.
5. Se conserva ABS(diferencia)<0.06, folios NOT LIKE 'G-%' y fecha de ventana.
6. Addenda conserva valores anteriores no nulos si el RFC no coincide;
   coincidencia recibe SI y el resto nulo recibe NO.
7. Centralizadas: un Doc_Num elegible actualiza TODAS sus filas en bitacora,
   incluso otra fila con distinto cliente o fecha. Cada fila toma su SAP_Amount.

## LP: pendiente de regla del cliente

Oracle sobrescribe LP con un cursor de DISTINCT Fact_T3 UNION ALL DISTINCT
Nota_T3 sin ORDER BY. MAX no es equivalente si hay varios valores posibles.

Se agrego una validacion ANTES del DELETE: si un folio del periodo existente
 en CFDI_Agrupado tiene varias LP, lanza 54104. NULL cuenta como alternativa y
vacio se normaliza a NULL. Una LP unica se recupera sin escoger arbitrariamente.

Es una diferencia deliberada: Oracle continuaba con un resultado dependiente
del orden. La validacion es conservadora: revisa folios candidatos aunque un
JOIN posterior pueda impedir insertarlos o una fila individual ya tenga LP.
Ejecutar `tests/SF_BITACORA_CFDI_RESUMEN/Prevalidacion.sql` con el periodo real.
Si devuelve conflictos, el cliente debe definir la regla; no quitar el control
ni elegir MAX/MIN para afirmar equivalencia.

## Pasada 3: ejecucion, pruebas y limites

- Se mantienen proceso 802, contadores, control de reporte y componentes.
- Una sola fila FC__TIME_WINDOW es premisa confirmada por el cliente.
- Fechas invalidas/incompletas/invertidas se rechazan antes del DELETE. Es una
  proteccion existente distinta de Oracle, que comparaba texto y podia vaciar
  el informe. Inicio NULL/vacio es la excepcion que usa fechas predeterminadas.
- SQL Server relanza errores para SQL Agent; Oracle registraba y hacia COMMIT.
  Se conserva el comportamiento MSSQL, con Source T-SQL y codigo ERR.
- Los puntos de COMMIT no son equivalentes: Oracle confirma cada 1000/5000 filas
  y por etapas; MSSQL usa sentencias por conjuntos en autocommit. Un fallo puede
  dejar informe parcial. No ejecutar concurrentemente ni envolver en transaccion
  externa sin revisar el CATCH: XACT_ABORT ON puede impedir registrar el error
  si la transaccion externa queda invalidada.
- @@ROWCOUNT se consulta inmediatamente despues de INSERT. Para una conexion
  recuperada de SSMS ejecutar SELECT 1 y GO antes del EXEC (error 4083).
- Se requieren fuentes estables y textos compatibles con el cotejamiento destino.
  No se auditaron collation, triggers ni definiciones desplegadas en produccion.
  La materializacion del historial/LP fija su lectura durante la corrida;
  Oracle abre sus cursores en momentos distintos.

## Evidencia reproducible

Ejecutar desde la raiz del proyecto:

```powershell
& .\MSSQL\T3\EAI\Procedures\tests\SF_BITACORA_CFDI_RESUMEN\Run.ps1
```

El runner crea una base aleatoria CodexResumen_* en LocalDB y la elimina al
terminar. Usa DDL real disponible. Fact_T3/Nota_T3 usan contratos minimos de
Factura/Grupo_Precio porque no se encontro su DDL. Instala LOG_START del repo
 y ejecuta el procedimiento completo.

Pruebas: 15 filas principales; cuatro estados PAC; nulos; seis clases de preventa;
cancelacion y 2999; entrega vacia/ausente; cabeceras duplicadas; material CAJ/PAQ,
conversion nula y material inexistente; historia agrupada repetida; LP unica;
ajustes multiples de uno/dos centavos y neto cero; umbral 0.05/0.06; ultimo segundo
del periodo; centralizadas con Doc_Num duplicado; contadores 7/6/2/5 y cierre.
Otras ejecuciones verifican fin de mes, inicio NULL/vacio, fecha final ignorada,
fecha invalida y LP ambigua antes del DELETE. Las advertencias por NULL en
agregados son esperadas; 54102 y 54104 se provocan intencionalmente.

Antes de aceptar el reporte productivo, conciliar con Oracle sobre el mismo
corte: filas y multiplicidad por folio, todas las columnas, totales por
sociedad/tipo/status, volumen, ajustes y marcas centralizadas. Conteos globales
o comparaciones entre dos MSSQL con el mismo defecto no bastan. Las pruebas
locales no sustituyen esa conciliacion ni una prueba de carga.

# Pruebas de ReferenceID, 26 de octubre de 2026

## Acceso no unico CLIENTE_V3

RunClienteV3.ps1: base CodexClienteV3_89647b0181, collation SQLLatin, exit0,
eliminada. DDL real CLIENTE/DISTRIBUIDOR_FISCAL/REMISION_CTRO_SOCIEDAD,
TAO_CEDIS_VALID/MX_EAI_MESSAGE_LOG/ZSDFE_SOC y GET_REMISION_INFO sin editar.
Fixture50,008filas,clusterRFC,indiceSAPactivo y CLIENTE_PKunique deshabilitado;
duplicadosV3/FechaIni conSAPdistinto. El parche07 crea acceso NO UNIQUE.
Once casos con igualdad de los once parametros de salida, sin errores,
datos/duplicados/indiceunico/definicionSP conservados. Seeks del indice nuevo
verificados en DMV. Repeticion no crea otro; reversion DROP comprobada;
otro indice previo activo porV3 impide duplicar. SQLScriptDom yPSparser pasan.
40consultasantes209.358ms/1,210lecturas/call,despues11.000ms/20lecturas.
Solo microprueba; no acredita velocidad integral, almacenamiento real,
timbrado ni casos de coincidencias multiples con domicilios distintos sin
ORDER BY. No se conecto a T3QA; aplicacion y medicion real pendientes.

## Diagnostico de IO y memoria 06

06_REVISAR_IO_Y_MEMORIA.sql paso TSql160Parser sin errores y ejecucion completa
LocalDB/MSSQLLocalDB en master, codigo 0. Se validaron columnas de memoria,
archivos/deltas, esperas, actividad y consultas de cache/indices de remision.
La base no tenia carga ni objetos de negocio: esas consultas devolvieron
filas vacias. No valida latencias productivas, equivalencia funcional ni
indices instalados en T3QA. No se conecto al servidor real ni se cambiaron
datos/configuracion local. No se repitieron pruebas de negocio sin cambios.

## Ampliacion SKU

Ultima ejecucion de Run.ps1, base CodexInvoiceRefSeek_a74263b873, codigo 0,
con collation SQL_Latin1_General_CP1_CI_AS. Mantiene todas las comprobaciones
anteriores y agrega SkuCases.ps1 con DDL real de MATERIAL, indice inicial no
unico de prueba y GETCONV real. Veinte casos de igualdad de cantidades/unidades
y errores, incluidos materiales duplicados con UM distinta, NULL, vacios,
espacios, ceros, acento y NCHAR(28450) para Unicode no representable. No se
emplea un literal Unicode dependiente de la codificacion de PowerShell 5.

Aplicacion del parche SKU devuelve un bloque y respaldo; segunda aplicacion
sin cambios. Permisos y tres ajustes ReferenceID conservados. Reversion por
RunId restaura la version ReferenceID y repeticion sin cambios. Fuente final
compilado y seis casos de transacciones satisfactorios. Sin cambios a GETCONV.
Diagnostico 04 tambien ejecutado sin errores. Base temporal eliminada.

Prototipo inicial: 300 busquedas / 10,000 materiales, 897.788 ms original,
15.999 ms corregido. No mide el lote de facturas ni su tasa final; no se
extrapola esa relacion de tiempos a produccion. Aplicacion SKU real pendiente.

## Validacion ReferenceID anterior

Ejecucion de [Run.ps1](Run.ps1) satisfactoria, codigo de salida 0.
SQL Server LocalDB, base temporal CodexInvoiceRefSeek_fa77740bec,
eliminada al terminar. No hubo conexiones a T3QA ni a produccion.

Se utilizaron los DDL reales de ocho tablas EAI_OWNER, las funciones y el
coordinador/parser mantenidos. La version anterior de los tres predicados se
reconstruye solo en memoria para probar una primera aplicacion del parche.

Comprobaciones satisfactorias:

- Tres bloques aplicados; definicion original respaldada byte por byte.
- Hash aplicado correcto; segunda aplicacion sin cambios ni respaldo extra.
- Permiso EXECUTE previo conservado tras ALTER.
- Ocho referencias: numeros, mayusculas/minusculas, espacios, vacio, NULL,
  acentos y Unicode no representable; mismo numero de filas eliminadas
  por el predicado anterior y el corregido. La tabla de prueba tiene collation
  SQL_Latin1_General_CP1_CI_AS e indice por ReferenceID.
- Seis casos de transacciones con el parche aplicado: exito autonomo, exito
  con transaccion anidada externa, error 547 con savepoint y trabajo previo
  conservado, rollback/log autonomo, transaccion externa invalidada con error
  original y rollback/log autonomo de transaccion invalidada.
- Reversion conserva cuerpo y parametros anteriores; segunda reversion sin cambios.
- Compilacion del archivo completo mantenido y repeticion de los seis casos
  de transacciones con los bloques integrados.
- Sintaxis del parche, reversion y fuente validada tambien con TSql160Parser.

Limites: los datos son sinteticos; el clasificador y las tablas de auditoria
se preparan para estos casos. Las rutas reales de PREVENTA/FACTURA/debito no
se ejecutan y sus objetos no se cargan, por lo que aparecen avisos normales
de dependencias diferidas durante CREATE/ALTER. No se prueba timbrado ni el
flujo de negocio completo. No es un benchmark de tiempo o lecturas del lote
real; no se promete una tasa de procesamiento. Faltan la aplicacion en T3QA
y la medicion/conciliacion de un lote comparable.

## Validacion adicional del diagnostico 04

Se amplio el runner con 04_REVISAR_PARSER_Y_FACTURA.sql para validar su
ejecucion de catalogos, cache y XQuery en la base temporal. Segunda ejecucion
satisfactoria, codigo 0; todas las comprobaciones anteriores se mantuvieron.
Query Store permanecio deshabilitado: no se probaron sus filas historicas
productivas ni su configuracion activa. No se conecto al servidor real ni se
modificaron SP de negocio durante esta continuacion del analisis.

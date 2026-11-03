# Paridad Oracle / SQL Server: PROC_CFDI_PROCESAR_PAGOS

**Informe historico de la revision previa a cambios.** Despues de esta revision,
el usuario autorizo corregir los pendientes manteniendo GETCONV sin cambios.
El estado vigente, decisiones transaccionales, pruebas y scripts estan en
[CAMBIOS_ORACLE](PROC_CFDI_PROCESAR_PAGOS.CAMBIOS_ORACLE.md).
Los hashes y afirmaciones de defectos/no modificaciones de este informe
corresponden a esa etapa anterior y se conservan como evidencia.

Revision: **23/10/2026**, previa a autorizar nuevos cambios de logica.
**No se puede certificar paridad completa: faltan la regla SAT, el retorno NULL
sin detalle fiscal y el recorrido efectivo del control posterior; tambien
difieren la identificacion de filas y los limites transaccionales.**
La correccion de cursores del procedimiento principal conserva
la intencion del recorrido Oracle; DATE es una diferencia funcional autorizada.

## Fuentes revisadas

- [Original Oracle](../../../../ORA/T3/T3/Procedures/PROC_CFDI_PROCESAR_PAGOS.SQL), 472 lineas.
  SHA256: `15E05322DC8F8145D778ECDFE9D988740657AA1DA2528C174A562721FF089DF2`.
- [SQL Server actual](PROC_CFDI_PROCESAR_PAGOS.sql).
  SHA256 al iniciar esta revision: `41ACCAEFBB909C389211D6842D852B27804B324EC83C46E421E93E40DAB37D0B`.
- LOG_START de ambos motores y WA_CFDI_COBRANZA de ambos motores.
- FN_TOTAL_FACT, GETCONV y WA_CFDI_COBZA_ASIG_CTRL de ambos motores, incorporados
  a esta revision despues de recibir los tres originales Oracle.
- El archivo SQL del control se actualizo externamente durante la revision.
  La version final revisada/probada tiene BEGIN TRAN/COMMIT/ROLLBACK comentados;
  SHA256: `4D727CBC3C60771CB855022F44D806D444DBDAE4EF7C7E2ED31FD42817B41184`.
  No se revirtio ni modifico ese archivo. Los hashes de los SQL cargados en la
  ultima prueba se guardan en LastDependencyParity.txt.

Las referencias de lineas de la matriz son del archivo Oracle revisado.
No se ejecuto Oracle ni se modificaron los fuentes SQL de negocio o datos reales.
Se ejecuto un diagnostico sintetico en SQL Server LocalDB con los fuentes SQL
actuales, en base temporal eliminada al terminar. Las expectativas Oracle se
obtuvieron de sus fuentes y documentacion; no es una prueba diferencial entre motores.

## Matriz de reglas

| Regla | Oracle, lineas | SQL actual / evaluacion |
| --- | --- | --- |
| Lote por Fecha_Proc_BATMD | 106 | Oracle compara fecha/hora exactas. SQL compara DATE por decision del usuario; diferencia intencional. |
| Cliente vigente | 107-108 | Ambos exigen cliente y rango inclusivo; SQL ignora horas por cambio autorizado. |
| Registro fiscal y tipo opcionales | 109-110 | LEFT JOIN conserva el outer join Oracle. |
| Origen ausente => INCOBRABLE | 88 | Conservado para NULL. Cadena vacia requiere tratar semantica Oracle. |
| Importe inicial FN_TOTAL_FACT | 90 | Llamada conservada; **Oracle devuelve NULL sin detalle, SQL devuelve 0**. Ver revision de dependencias. |
| CFDI_DOCUMENTOS por AP.Factura | 100-111 | **Falta en ScrPagos SQL**: ni JOIN ni Importe_SAT. Puede afectar importe y multiplicidad. |
| Orden de asignaciones del lote | 112 | Conservado por cliente, fecha e identificador. |
| Historial de factura desde 01/09/2018 | 114-152 | Misma seleccion y orden; SQL convierte el limite a DATE. |
| Notas de credito => Returns/CM | 121-138 | Conservado para valores NULL/no vacios; '' produce diferencia. |
| UNION ALL factura/preventa y agregados | 154-176 | Conservados, incluidos los seis componentes de importe y JOIN al detalle. |
| UUID solo CONFIRMADO | 178-181, 313-317 | Conservado. No hay orden para escoger entre varios confirmados. |
| Penalizacion por referencia | 183-188, 274-278 | Conservado. |
| Cancelacion prevalece sobre penalizacion | 190-195, 279-287 | Conservado; sustituye importe, fecha, documento y estado. |
| Tasa IVA y ajuste >=15.98 a 16 | 298-305 | Conservado, incluso para tasas superiores a 16. |
| PendienteT3: sin detalle/fecha NULL/anio 2999 | 307-310 | Conservado. No impide insertar cobranza. |
| Importe T3 para venta procesada | 311-317 | Conservado, pero SQL omite la sustitucion SAT posterior. |
| Regla SAT habilitada por RFC | 321-329 | **Ausente en SQL**. |
| Saldo inicial e importe de factura | 331-337 | Misma asignacion, pero el importe de entrada puede diferir por SAT ausente. |
| Acumulados antes del movimiento actual | 340-378 | Conservados. Pagos incrementan numero; CM conserva secuencia. |
| Factura literal INCOBRABLE | 339, 398-401 | Conservado: omite historial, Via_Pago=AI y nota de credito origen. |
| Fecha_Pago de AP.Fecha_Asignacion | 78, 235, 421 | Conservado; no se reemplaza por la fecha del pago obtenida en el historial. |
| Fecha fallback de asignacion | 382-384 | Conservado. |
| Banco/cuenta maestros vacios | 386-391 | Misma llamada bancaria comentada; SQL almacena '' donde Oracle trata NULL. |
| RFC generico: Fecha_Envio=parametro | 393-396 | Conservado; no acredita timbrado. |
| INSERT de cuarenta campos | 403-426 | Mismos nombres y expresiones finales por variable; verificacion mecanica satisfactoria. |
| PID, componente 604 y contadores | 198-213, 428-438 | Conservados; SQL no reproduce los COMMIT Oracle. |
| Control final con 3 dias, salida 0 | 440 | Llamada conservada; **su cursor SQL conserva filtros NULL y reemplaza ROWID por Asignacion_ID sin unicidad declarada**. |
| Error: rollback y log | 443-471 | SQL conserva log/ausencia de relanzamiento, pero no rollback ni transaccion propia. |

## Diferencia principal: importe SAT omitido

El cursor Oracle obtiene `Importe_SAT` como subtotal mas IVA de CFDI_DOCUMENTOS,
con NULL sustituido por cero, mediante outer join directo
`AP.Factura = CFD.Nota_Venta(+)`. No usa aqui la relacion por historia PAC.
Lo asigna a nSAT_Amount en la linea 254, declarado NUMBER(13,3).

Despues de resolver venta, penalizacion o cancelacion y **antes** de inicializar
el saldo, aplica exactamente estas condiciones:

1. RFC con longitud mayor a cero y distinto de XAXX010101000.
2. Busca `MAX(NVL(Target,'0'))` en MX_HashTable con Type='SAT Amount Invoice'
   y Source=RFC, y lo asigna a nReq_SAT_Amt NUMBER(4).
3. Si NVL(nReq_SAT_Amt,0)>1 **y** nSAT_Amount>0, sustituye nTtl_Invc_Amt por
   nSAT_Amount. Con valor 1, sin configuracion o importe no positivo, no sustituye.

No exige Status=CONFIRMADO ni UUID en este bloque. No agregar esos filtros
como si pertenecieran a la regla original. Se ejecuta tambien despues de una
cancelacion/penalizacion si cumple las condiciones, no solo en Nota de Venta.
Posteriormente nImporte_Factura y nSaldo_Pendiente reciben ese total sustituido.
La regla cambia la base de saldo, no el importe Paid_Amt de cada movimiento,
la tasa, el estado ni las fechas de la ruta por si sola.

SQL carece de las dos variables, del JOIN/campo del cursor y del bloque de
sustitucion. Por tanto los cuarenta campos del INSERT pueden estar homologados
y aun asi diferir Importe_Factura y los saldos por el valor calculado previamente.
La ausencia del JOIN tambien evita posibles filas adicionales si un documento
tiene varias coincidencias CFDI; no restaurarlo con DISTINCT o MAX arbitrarios.

### Por que aun no se puede medir su impacto real

Las lecturas anteriores exportaron Nota_Venta/Folio_Fiscal/Status, pero no los
subtotales/IVA de CFDI_DOCUMENTOS ni Type='SAT Amount Invoice'. Los casos sin UUID
no descartan esta regla, porque Oracle no exige UUID confirmado.
Para medir el alcance hacen falta esos importes/configuraciones y el numero de
coincidencias CFDI por factura. No afirmar que SAT resuelve todas las bases cero
ni sustituir FN_TOTAL_FACT por otra tabla sin esa comprobacion.

Si Target es texto, MAX antes de convertir puede no equivaler a MAX numerico.
Se necesita el tipo/catalogo Oracle para preservar conversiones, configuraciones
invalidas y limites de NUMBER(4), sin convertir silenciosamente errores a cero.

## Transacciones: diferencia funcional real

[LOG_START Oracle](../../../../ORA/T3/EAI_OWNER/Procedures/LOG_START.SQL) confirma
Status=2 mediante COMMIT; no declara transaccion autonoma y confirma tambien
cambios pendientes de la transaccion del llamador. Luego el procedimiento inserta su bitacora y procesa
el lote. Confirma el trabajo principal en la linea 439, llama al control 889 y
vuelve a confirmar en la 441. Si falla antes del primer COMMIT principal,
WHEN OTHERS ejecuta ROLLBACK; despues escribe y confirma el log del error.
El rollback no revierte lo ya confirmado por LOG_START ni por el primer COMMIT.

SQL LOG_START no hace COMMIT. El procedimiento no abre transaccion y tiene
COMMIT/ROLLBACK comentados: bajo autocommit pueden quedar filas anteriores al
fallo. La ultima version local del control 889 tambien tiene BEGIN TRAN,
COMMIT y ROLLBACK comentados: ninguno delimita ahora su propia transaccion.
Con transaccion externa ambos participan en ella. No basta con descomentar
COMMIT ni agregar un BEGIN TRAN sin definir propietario, limites y llamadas anidadas.

El original recibido del control 889 confirma ademas un COMMIT por iteracion del
cursor principal (linea 101), un COMMIT final (109) y otro del log de error (138).
La version SQL al iniciar esta revision abria una transaccion para todo el control
y tenia ROLLBACK global en CATCH; ese comportamiento dejo de aplicar al archivo
actualizado durante la lectura. El fuente final, sin transaccion propia, tampoco
reproduce la secuencia Oracle: en autocommit persisten escrituras individuales,
y con transaccion externa la persistencia depende del llamador. No presentar
la eliminacion de transacciones como paridad ya resuelta.

Ambos procedimientos principales registran y no relanzan el error. Exigir THROW
seria un cambio de contrato adicional, no una traduccion literal de Oracle.

## Cursores y fechas: separacion de traduccion y decisiones autorizadas

Oracle declara los seis cursores al principio, pero evalua sus variables al
abrirlos; FOR ... IN cursor LOOP los abre con el valor de esa iteracion.
La [referencia Oracle de cursores](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/cursors-overview.html)
documenta esa evaluacion al abrir. La prueba de T3QA mostro que la traduccion
T-SQL anterior capturaba filtros NULL al declarar. Declarar LOCAL despues de
asignar filtros y liberar por uso conserva la intencion del original; no hay
motivo en este analisis para revertir la correccion.

El tipo [DATE de Oracle](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpcc/datatypes-and-host-variables.html)
incluye hora/minuto/segundo. El original no usa TRUNC en BATMD ni vigencias.
Por tanto CAST AS DATE en SQL es una ampliacion a dias completos expresamente
autorizada por el usuario, no una equivalencia literal del parametro Oracle DATE.

WA_CFDI_COBRANZA Oracle selecciona timestamps BATMD distintos y hace MINUS contra
cobranza; su llamada a este procedimiento esta comentada. Si otro llamador pasa
varios timestamps del mismo dia al procedimiento ahora diario, puede repetir
asignaciones. No se demuestra que ocurra en el job activo con estos fuentes.

## Cadenas vacias y otras condiciones de compatibilidad

Oracle [trata la cadena vacia como NULL](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Nulls.html).
SQL diferencia ambos valores:

- TD.Origen='' activa el NVL a INCOBRABLE en Oracle; ISNULL en SQL conserva ''.
- Nota_Credito='' es NULL en Oracle y no es una CM por esa prueba; en SQL satisface
  IS NOT NULL y puede alterar tipo, via, secuencia y acumulados.
- Status, UUID, Accnt_ID, referencias y datos bancarios inicializados con '' se
  almacenan como NULL en Oracle y como vacios en SQL. Comparar ambos por contrato.

No se aplicaron normalizaciones automaticas. Los numericos conservan en general
precision/escala declaradas, pero limites, redondeo de expresiones, conversion de
texto y collation requieren pruebas diferenciales; las pruebas actuales solo
ejecutaron SQL Server. Sin el bloque SAT no se probo NUMBER(13,3)/NUMBER(4).

## Dependencias Oracle recibidas: conclusiones adicionales

### FN_TOTAL_FACT: ausencia de detalle no equivale a total cero

Fuente: [FN_TOTAL_FACT Oracle](../../../../ORA/T3/T3/Funciones/FN_TOTAL_FACT.SQL),
lineas 8-17. SHA256:
`0D05AD925C660E0F33EE44A1D45E522DFFDF7902A8E7E6AF472B7D9000EB282A`.

Ambos suman los mismos seis componentes y sustituyen cada componente NULL por
cero. La diferencia esta despues de SUM: SQL retorna cero cuando el agregado
es NULL; Oracle retorna directamente la variable del agregado. Su manejador
NO_DATA_FOUND **no se activa por ausencia de detalle**: SUM sin GROUP BY devuelve
una fila con NULL cuando no hay coincidencias. Esta semantica esta documentada
en [Aggregate Functions de Oracle](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Aggregate-Functions.html).

| Datos fiscales | Original Oracle | SQL vigente |
| --- | --- | --- |
| No hay filas de la factura | NULL | 0 |
| Hay una fila y sus seis componentes son NULL | 0 | 0 |
| Hay componentes con importe | Suma de los seis componentes | Misma formula; aun deben validarse limites/redondeo |

Por tanto las pruebas anteriores que esperaban cero sin detalle validaban el
SQL recibido, **no una regla confirmada de Oracle**. Una base cero observada
en SQL no permite concluir que Oracle habria devuelto cero. La paridad literal
puede producir Importe_Factura/saldos NULL cuando ninguna rama posterior (venta,
cancelacion o sustitucion SAT) proporciona otro total; no garantiza importes
correctos ni autoriza inventar detalle fiscal. No cambiar a NULL sin revisar
tambien el contrato de consumidores de esta funcion compartida.

SQL tambien limita el parametro a VARCHAR(50) y aplica NULLIF(@sFactura,'').
Con las comparaciones SQL pueden colapsar cadenas de espacios; Oracle no trata
una cadena no vacia de espacios como NULL. Separar este caso del vacio real.

### GETCONV: equivalencia condicionada al catalogo

Fuente: [GETCONV Oracle](../../../../ORA/T3/EAI_OWNER/Functions/GETCONV.SQL),
lineas 13-23. SHA256:
`C20CDCAC0B4C9DDE805BA6B3CEC6077CA731D6A5311982E9952AE38C1CAA9C8E`.

Sin coincidencia, ambas conservan Source; con una coincidencia, devuelven Target,
incluido NULL. Oracle recorre todas las coincidencias y conserva la ultima;
SQL usa TOP(1). **Ninguna consulta tiene ORDER BY**: no se puede determinar
una ultima/primera fila de negocio ni certificar igualdad con duplicados de
Targets diferentes. El comentario historico del fuente SQL sobre TOP(1) no
demuestra paridad Oracle y queda pendiente de corregir con la implementacion.

Antes de cambiar la funcion compartida, revisar duplicados de (Type,Source),
Targets distintos/NULL, vacios, collation y longitudes del catalogo real.
Si todos los matches entregan el mismo Target, el orden no altera ese resultado.
No imponer MAX, MIN o una restriccion UNIQUE sin resolver datos/contrato.

### WA_CFDI_COBZA_ASIG_CTRL: cursor, fila afectada y commits

Fuente: [control Oracle](../../../../ORA/T3/T3/Procedures/WA_CFDI_COBZA_ASIG_CTRL.SQL),
139 lineas. SHA256:
`DF4AF6A1262A3E50BA2C28A788951AAC93D76BF6E41CC22F21891F78A925D8DA`.

La agrupacion por RFC/asignacion/via, las exclusiones de generico/CM y la
preferencia por mayor numero de pagos proceden de Oracle. Con empate la prueba
estricta nCntPagos>CntPagos no aplica el control por esa rama en ambos motores.

1. **Cursor dependiente aun defectuoso:** SQL declara ScrPagos antes de asignar
   @sRFC/@sAsignacion. La prueba del fuente completo encontro dos grupos de
   vias (2 pagos frente a 1), conto una inconsistencia y cero pagos examinados,
   sin error. Oracle abre ScrPagos con los valores de la iteracion (lineas
   50-57,86) y revisaria/marcaria el pago de la via minoritaria. La correccion
   previa de cinco cursores del procedimiento principal no incluia este objeto.
2. **ROWID no es Asignacion_ID:** Oracle actualiza exclusivamente la fila fisica
   recuperada (90-91); SQL sustituye ROWID por Asignacion_ID y actualiza por ese
   valor sin RFC, central o fecha. El DDL local de CFDI_COBRANZA no declara una
   clave unica y permite NULL en ese campo. Con ID repetido puede actualizar
   filas adicionales, incluso fuera de la agrupacion/ventana; con ID NULL no
   encuentra la fila mediante igualdad. La prueba del predicado SQL afecto dos
   filas sinteticas de RFC/central/fechas distintos. No demuestra que existan
   duplicados en produccion. Definir identificacion estable antes de reparar el
   cursor, porque activarlo puede exponer esta actualizacion demasiado amplia.
3. **Transacciones:** Oracle confirma cada iteracion; la ultima version SQL
   tiene BEGIN TRAN/COMMIT/ROLLBACK comentados. Ver seccion transaccional y
   distinguir esta version de la inicial, que confirmaba todo el control al final.
4. **Longitud y parametros:** LENGTH cuenta espacios finales; LEN SQL los omite
   (filtro >8). Oracle pDays NUMBER admite fracciones, SQL INT no; el llamador
   principal pasa 3, por lo que esta ultima diferencia no afecta esa llamada.

No se propone normalizar a DATE la ventana movil SYSDATE-pDays de este control:
corresponde a ultimas horas/dias respecto a la ejecucion y no al lote BATMD.
El orden externo sin RFC tambien existe en Oracle; no cambiarlo como si fuera
una omision nueva de migracion.

### Reproduccion y alcance de la evidencia

Diagnostico: [DependencyParity.sql](tests/PROC_CFDI_PROCESAR_PAGOS/DependencyParity.sql).
Ejecutor: Run.ps1 -AnalizarDependencias. Resultado:
[LastDependencyParity.txt](tests/PROC_CFDI_PROCESAR_PAGOS/LastDependencyParity.txt).

El diagnostico compilo los fuentes completos, comprobo el contraste SUM NULL /
funcion SQL cero, el caso de componentes NULL, GETCONV sin match/unico/Target
NULL/duplicados, el control con inconsistencia efectiva y el predicado amplio
de actualizacion. Todas las aserciones de **reproduccion de hallazgos** pasaron;
eso confirma diferencias del SQL vigente y no certifica que esten corregidas.
Se elimino la base temporal; no se consulto ni modifico T3QA/produccion.

La corrida real del 14/10 mantuvo 326 inserciones conciliadas. Su control 889
tenia cero grupos candidatos, por lo que no demostro que ScrPagos funcionara
con inconsistencias. Los resultados funcionales anteriores conservan su valor
para SQL y cursores principales, sin extenderlos a paridad completa.

## Reglas pendientes que ya existian en Oracle

No son, por si mismas, omisiones de migracion:

- Cliente sin vigencia excluye la asignacion; Origen ausente cae en INCOBRABLE.
- No hay control de duplicados dentro de este procedimiento antes del INSERT.
- Historial unido a cobranza puede multiplicar movimientos.
- Agregados y busquedas de UUID/DN sin orden pueden conservar una ultima fila
  no determinada; UNION ALL factura/preventa es parte del original.
- No limita saldo a cero; puede producir negativos con importes insuficientes.
- El caso generico marca Fecha_Envio y la fecha escrita de pago procede de AP.
- Contadores/estado de proceso cierran antes del control posterior.

La ausencia de encabezados/detalle en la captura real sigue siendo un hallazgo
de datos, pero no autoriza cambiar el fallback, rechazar todas esas facturas ni
crear registros fiscales ficticios. La regla SAT omitida debe evaluarse antes
de cerrar la revision de importes.

## Cobertura, limites y orden para continuar

La comparacion mecanica del INSERT verifico cuarenta columnas y cuarenta
expresiones finales iguales al normalizar prefijo @, espacios y SYSDATE/GETDATE.
La lectura de los seis cursores y de todas las ramas encontro las diferencias
anteriores. Esto no prueba igualdad de resultados entre motores.

Los tres originales pendientes ya fueron revisados; sus diferencias se
documentan arriba. El Oracle recibido no acredita por si solo que sea la ultima version de
la base Oracle historica: su procedencia/version instalada debe confirmarse si
se usara como referencia de aceptacion.

Trabajo identificado para la correccion, sin aplicarlo en esta revision:

1. Restaurar JOIN/campo/regla SAT conservando condiciones, escala y cardinalidad.
   Capturar configuracion por RFC e importes/multiplicidad CFDI para medir impacto.
2. Resolver el retorno NULL/0 de FN_TOTAL_FACT con impacto en todos sus callers.
   La paridad literal es NULL sin detalle; cero necesita una decision explicita.
3. Definir una identificacion unica de cobranza y corregir ScrPagos del control
   conjuntamente, con pruebas de varias agrupaciones, IDs repetidos/NULL y empates.
4. Verificar datos de GETCONV y resolver seleccion ante duplicados si existen.
5. Definir limites transaccionales de principal/control y tratamiento de vacios;
   probar errores a mitad del lote y transaccion externa, ademas de SAT
   activado/inactivo, generico, configuracion ausente/invalida y multiples CFDI.

Estas son diferencias de codigo o de semantica demostradas; su frecuencia real
requiere lecturas de datos. No desplegar ni reprocesar solo por este informe.

No se cambio el codigo de negocio ni se desplego nada durante este analisis.
El comentario del SQL que indicaba no disponer de Oracle corresponde a la
entrega inicial; la guia y este informe incorporan el original recien agregado.
No se edito ese archivo en esta revision para conservar el alcance solicitado.

# Guia de mantenimiento de T3.DELIVERY_TO_REMISION

Revision del 02/11/2026 sobre el fuente local. Se documentaron el
[procedimiento](../DELIVERY_TO_REMISION.sql) y sus dependencias sin cambiar
instrucciones ejecutables. No se ejecuto ni modifico el SP instalado en T3QA.

## Que hace

Toma entregas de T3.Delivery_Hist y las convierte en una remision con cabecera
y lineas. El numero Delivery se usa como Factura en las dos tablas destino.
El folio interno devuelto por WA_FOLIO_FACTURA se guarda aparte en
Remision_Serie y Remision_Folio. Aqui no se genera XML ni se envia o timbra.

## Como se ejecuta

El procedimiento tiene dos banderas numericas. Los ejemplos siguientes
**ejecutan el proceso y pueden insertar o actualizar registros**:

```sql
-- Generar remisiones sin segunda conversion a carton y sin resumen impreso.
EXEC T3.DELIVERY_TO_REMISION @nConvCases=0, @nOutput=0;

-- Solicitar segunda conversion a carton y mostrar el resumen al finalizar.
EXEC T3.DELIVERY_TO_REMISION @nConvCases=1, @nOutput=1;
```

@nConvCases no es el numero de cajas ni un divisor: es una bandera mayor que
cero. Aunque sea cero, el SELECT de ScrDetail calcula conversiones iniciales
para TH, EA y PC. @nOutput solo controla PRINT; ponerlo en cero no evita
escrituras. No hay parametros OUTPUT ni un resultado SELECT por remision.

## Datos que consulta y donde escribe

| Objeto | Uso |
|---|---|
| T3.Delivery_Hist | Cabecera agrupada y detalle de las entregas recibidas. |
| EAI.ZSDFE_Soc | Sociedad visible para ScrData cuando BUKRS=KUNNR=Sociedad. |
| T3.Remision_General | Comprobar cabecera previa e insertar una nueva. |
| T3.Remision_Detalle | Insertar lineas y, opcionalmente, actualizar cantidad/unidad. |
| T3.Material | Nombre, unidad y factores de conversion de cada producto. |
| T3.REMISION_CTRO_SOCIEDAD | Relacionar centro de origen/destino con sociedad. |
| EAI_OWNER.getConv | Traduce unidad con Type='ECC_V3 UOM' en MX_HashTable; sin coincidencia conserva el valor de entrada. |
| T3.GET_REMISION_INFO | Devuelve RFC, nombre y domicilio mediante OUTPUT. |
| EAI_OWNER.WA_FOLIO_FACTURA | Busca o genera relacion/consecutivo de folio interno. |
| EAI_OWNER.MX_EAI_MESSAGE_LOG | Guarda los errores recibidos por el CATCH del coordinador. |

GET_REMISION_INFO busca primero en Distribuidor_Fiscal, despues en Cliente
y despues mediante TaO_Cedis_Valid/Cliente si no hubo coincidencia anterior.
Tambien consulta razon social y descripcion de transito. Una busqueda sin
coincidencias puede devolver vacios; el coordinador no los valida como error.

Para clase REM, WA_FOLIO_FACTURA usa la serie Non de MX_NRIV. Si encuentra
una relacion FacturaSAP/Clase_Factura previa, la devuelve. Si falta rango,
devuelve el numero SAP y registra 'Folio Interno'; no garantiza que ese texto
tenga el guion que DELIVERY_TO_REMISION espera para separarlo.

## Recorrido explicado

1. ScrData agrupa entregas con Created **mayor que** la medianoche del servidor.
   Excluye exactamente las 00:00:00, admite fechas futuras y no filtra por
   PickDate. Una sociedad NULL se transforma en MX16 antes del JOIN obligatorio
   a ZSDFE_Soc. Sin coincidencia de sociedad, no se procesa esa fila.
2. El JOIN con Remision_General produce la bandera INSERT si no encontro
   cabecera. No es una validacion de remision completa ni una reserva para
   impedir que otra sesion inserte el mismo numero.
3. Por cada fila se resuelve sociedad de Plant y se limpian los datos de
   domicilio. La sociedad de origen toma una sola coincidencia del catalogo;
   sin coincidencia conserva la del cursor principal.
4. Solo si falta cabecera se consultan emisor y receptor. Para ShiptoParty
   PC-00-xxxx se usa xxxx como centro receptor; para el resto se utiliza
   ShiptoParty_New, que da prioridad a SoldtoParty cuando no es NULL.
5. Se pide el folio usando la sociedad como centro efectivo, clase fija REM
   y PickDate. Se separa por el primer guion. La fecha de transaccion parte
   del inicio de la corrida y disminuye un segundo por nueva remision.
6. Se inserta Remision_General con Fecha_Proc_BATMD y Fecha_Cancelacion NULL.
   RFC se toma del receptor; el RFC consultado para el emisor no se inserta.
7. Se abre ScrDetail por Delivery, sin repetir el filtro Created. Se insertan
   sus lineas en Remision_Detalle. Revisar el cruce de posiciones descrito abajo.
8. Si @nConvCases>0, se calculan cartones con las cantidades ya guardadas.
   Solo se actualizan resultados enteros y positivos.
9. Al terminar se liberan los cuatro cursores. El resumen opcional cuenta
   filas leidas e intentos de alta, no remisiones completas comprobadas.

## Como leer un cursor y su FETCH

Un cursor permite recorrer filas una a una. OPEN lo prepara; FETCH carga una
fila en variables; @@FETCH_STATUS=0 indica lectura exitosa. En SQL Server el
FETCH asigna **por posicion**, no por el nombre de la columna o variable.
CLOSE cierra el recorrido y permite reabrirlo; DEALLOCATE libera su definicion.
Los cursores internos tambien cambian @@FETCH_STATUS, por eso importa que
cada bucle ejecute su propio FETCH antes de revisar otra vez el estado.

La version recibida tiene este mapa en ambos FETCH de ScrDetail:

| Posicion | Expresion del SELECT | Variable receptora | Tipo de variable |
|---|---|---|---|
| 1 | Delivery | @D_Delivery | varchar(50) |
| 2 | Num_Linea | @D_Linea | int |
| 3 | Material | @D_Material | varchar(100) |
| 4 | Nombre SKU o MaterialName | @D_Desc | varchar(200) |
| **5** | **Unidad SKU o unidad convertida** | **@D_CantCalc** | **numeric(22,7)** |
| **6** | **Cantidad calculada** | **@D_UM** | **varchar(20)** |
| 7 | UnitMeasure | @D_BaseUM | varchar(20) |
| 8 | Conv_UnitMeasure | @D_BaseUMKS | varchar(20) |
| 9 | MaterialName | @D_BaseName | varchar(200) |
| 10 | Quantity original | @D_BaseCant | numeric(22,7) |

Las posiciones 5 y 6 estan cruzadas respecto de su significado: una unidad
como CAJ o PAQ se intenta convertir a numero y puede fallar en el FETCH.
La cantidad se recibe como texto y luego se usa como UnidadMedida. Si la
conversion no falla, aun puede guardar datos que no corresponden al campo.
**Este cambio de documentacion no corrigio esas posiciones.**

## Otros puntos que debe conocer el desarrollador

- **Sociedad destino no reiniciada.** Solo la rama PC-00- establece MX16
  antes de buscar. La otra ejecuta @sSociedadDest=@sSociedadDest; puede quedar
  NULL o conservar la sociedad de otra entrega. En destino con varias
  coincidencias se conserva la ultima, sin orden definido.
- **Asignaciones sobrescritas.** recID recibe ShippingPoint, ShiptoPartyC
  y ShiptoParty_New consecutivamente: solo el ultimo valor llega al helper.
  sRem_Ctro recibe emisor/anio, pero termina siempre como sSociedad. La lista
  NOT IN contiene MXAA dos veces. No se cambiaron esas expresiones.
- **Receptor corto.** LEN(recNombre)<4 sustituye nombre y localidad, no los
  demas datos. Un nombre NULL no satisface esa condicion.
- **Direccion NULL.** La concatenacion usa + sin ISNULL para cada parte;
  con propagacion de NULL puede perderse toda la direccion.
- **Detalle historico y multiplicidad.** ScrDetail incluye todas las filas
  con la Delivery. Duplicados de Material en el catalogo multiplican el JOIN;
  empates en ROW_NUMBER por Material no tienen desempate explicito. Los
  grupos de ScrData tambien pueden repetir una misma Delivery.
- **Cartones por material.** El UPDATE usa Factura+Material, sin Num_Linea:
  modifica todas las lineas de ese material con la cantidad de la vuelta
  actual. Si el cursor lo repite, las vueltas pueden sobrescribirse.
- **Longitudes destino.** Algunas variables son mayores que las columnas
  del DDL local. Por ejemplo, Num_Linea destino es decimal(3,0), nombre de
  material varchar(100), Material varchar(10), Remision_Serie varchar(5).
  No hay validacion de longitudes/capacidad antes de los INSERT.

## Transacciones y manejo de errores

El coordinador no abre transaccion, no hace COMMIT/ROLLBACK y no establece
XACT_ABORT. En autocommit, la cabecera puede persistir aunque falle el primer
FETCH de detalle. Tambien pueden quedar solo algunas lineas. Una reejecucion
puede omitir la remision al encontrar su cabecera y no reparar el detalle.

El helper de folio tiene su propia proteccion transaccional del consecutivo
cuando la inicia, pero eso no vuelve atomica la generacion de la remision.
Con transaccion externa, la persistencia depende de su estado y del llamador.

Un error recibido por DELIVERY_TO_REMISION termina todo su recorrido y entra
al CATCH. Este intenta insertar en MX_EAI_MESSAGE_LOG, no vuelve a lanzar el
error ni limpia explicitamente los cursores en esa rama. Si el propio INSERT
del log falla, puede propagarse ese segundo error. Los helpers pueden capturar
sus errores y retornar sin THROW, por lo que el coordinador puede continuar
con datos incompletos sin entrar a su CATCH.

Para investigar, distinguir los campos del log:

| Autor local | Queue_Name | Identificador utilizado |
|---|---|---|
| DELIVERY_TO_REMISION | DELIVERY_TO_REMISION | **ID** = @v_ID; no llena REFERENCE ni JOB_PID. |
| GET_REMISION_INFO | GET_REMISION_INFO | REFERENCE = centro/identificador consultado. |
| WA_FOLIO_FACTURA | Folio Interno | REFERENCE = centro/clase o folio SAP, segun el caso. |

La etiqueta DELIVERY_TO_REMISION tambien aparece en el codigo local de
DELIVERY_IDOC_TO_REMISION. Por ello Queue_Name por si solo no prueba cual de
los dos procedimientos escribio el mensaje. SOURCE='PL/SQL' es una constante
heredada y tampoco prueba que la ejecucion ocurriera en Oracle.

No se encontro un EXEC directo a este SP en los fuentes locales revisados;
eso no excluye llamadas manuales, jobs o codigo externo/dinamico.

## Validacion de esta documentacion

Se conserva el archivo UTF-16 LE con BOM, CRLF, USE T3QA, ALTER, opciones SET,
firma, cursores, sentencias, orden de FETCH y manejo de errores. El respaldo
anterior esta en `tmp/delivery_to_remision_comentarios_20261102/DELIVERY_TO_REMISION.antes.sql`.
SHA256 anterior: `6598f9de8df61b06fd5d649b6fea1623c768ef22b140083059369c2ba91a5da8`.

La validacion compara tokens ejecutables antes/despues, excluyendo solamente
comentarios y espacios, y analiza ambos archivos con TSql160Parser. No ejecuta
el procedimiento, por lo que no certifica datos ni genera remisiones de prueba.

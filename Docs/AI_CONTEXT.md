# Contexto para IA

Usa este archivo como primer mensaje de contexto cuando pidas ayuda a una inteligencia artificial sobre este proyecto.

## Resumen del proyecto

### Diagnostico intercompany 50021, 2026-10-23

- Usuario confirma aplicacion del permiso puntual de partners en
  AZCRNMXNEVTD06/T3QA, finalizacion 2026-10-23 17:30:46.6084160 -06:00:
  login T3_SQLAGENT_OWNER, EAI_OWNER.TMP_DOCUMENT_PARTNERS, PuedeLeer=1,
  ObjectIdVisible=1280723615. Seccion previa sin permiso SELECT explicito
  en el rol. Concesion confirmada; pendiente siguiente corrida y evidencia
  de salidas. No extrapolar esta prueba a los otros 28 permisos del combinado.
  Revisar tambien colas Invoice to T3 / SF_PROC_PREINVOICE_INTER / Delivery
  to T3: algunas rutinas registran errores sin propagar al coordinador.

- Usuario reporta nuevo 229 de las 17:25: SELECT denegado sobre
  EAI_OWNER.TMP_DOCUMENT_PARTNERS en T3QA; no entrega PID/cola/referencia
  para este error. No inferir que corresponde a los once documentos anteriores
  o que los 28 permisos ya fueron verificados. Fuente T3.PROC_V40_GENERAR_OTROS
  tiene LEFT JOIN a esa tabla para cabecera; tambien la usa el auxiliar
  EAI_OWNER.INVOICE_TO_OTROS_PARTNERS. El mensaje solo no acredita cual fallo.
- Preparado `RECV_INVOICE_INTERCOMPANY_229_PERMISO_PARTNERS.sql`: GRANT SELECT
  al rol existente, verificado como login tecnico dentro de transaccion, sin
  ejecutar negocio ni modificar partners. Actualizados script E, README y
  combinado de rutas (ahora 29 permisos, antes 28). Aplicacion por usuario y
  validacion de siguiente corrida aun pendientes. No cambia SP ni estados.

- Segunda lectura de once documentos, AZCRNMXNEVTD06/T3QA, captura
  2026-10-23 17:25:53: las once parejas ROW_ID/referencia coinciden, todos
  Processed, temporal Procesado NULL; diez IV/ZL MX10 no tienen cabecera
  OTROS por FacturaSAP y el C020 MX10 1653455729 no tiene PREVENTA por ENTREGA.
  Los conteos de detalle/condicion cero estan correlacionados con cabecera:
  NO prueban ausencia de filas huerfanas. Revisarlas antes de un reproceso
  que asuma ausencia absoluta de datos anteriores.
- Definicion instalada del coordinador (4818 caracteres, modify_date
  2026-10-06 13:27:44.580) confirma el filtro R.CREATED de cinco dias
  COMENTADO. Solo filtra cola Invoice-Intercompany y PROCESSED IS NULL.
  Esto explica la seleccion de mensajes antiguos; no hay bloqueo por edad
  en esa definicion. No replicar ese cambio al fuente local ni restaurar
  el filtro de produccion sin decision del usuario. La siguiente seleccion
  de los once depende de su PROCESSED, actualmente no NULL.
- Usuario entrega explicitamente solo el resultado del segundo script;
  sigue sin recibirse la confirmacion de 28 permisos efectivos del primero.
  Pendiente esa evidencia y preparar recuperacion acotada de los once;
  no se ha reseteado ningun mensaje ni ejecutado documentos.

- Resultado del diagnostico del PID 26516078, captura 17:21:31, confirma once
  mensajes Processed pese a fallos: diez errores SQL-229 SELECT en OTROS_GENERAL
  (INVOICE_TO_OTROS registra y no relanza), y la referencia 1653455729 con
  DELETE denegado en PREVENTA_GENERAL (INVOICE_TO_PREVENTA propaga).
  El ultimo corresponde a ROW_ID 20261005111353659195000659195000.
  No son once errores de la misma factura ni documentos de negocio acreditados.
- Los once CREATED son 2026-10-04/05, fuera de la ventana de cinco dias del
  coordinador local al 23 de octubre; resultado y fuente local divergen en
  seleccion/contexto. No inferir que resetear PROCESSED los reelige.
- Preparado ajuste combinado `RECV_INVOICE_INTERCOMPANY_229_PERMISOS_RUTAS.sql`
  (28 permisos concretos, incluye preventa, otros, RF y catalogos; verificacion
  como login tecnico dentro de transaccion) y lectura
  `RECV_INVOICE_INTERCOMPANY_26516078_ESTADO_11_DOCUMENTOS.sql` con manifiesto
  de once ROW_ID/referencias, estado de temporales/salidas y definicion instalada
  en fragmentos para evitar recorte de 256 caracteres. Actualizados E y README.
  Aplicacion de permisos PREVENTA/OTROS aun no confirmada por el usuario;
  no se ha ejecutado ni entregado un reset/reproceso automatico de los once.

- Nueva corrida con datos: PID 26516078, inicio 17:15:22, FIN/PROCESO_4 NULL;
  a las 17:15:29 registra MSSQL-229, REFERENCE=YES, DELETE denegado en
  T3.PREVENTA_GENERAL. Es otro permiso, anterior al paso final T3, no retorno
  del 50021. REFERENCE=YES es respuesta de instancia, no folio de factura.
- Fuente MSSQL/Oracle INVOICE_TO_PREVENTA confirma DELETE/INSERT de general,
  detalle y condiciones; ademas UPDATE de general, RF complemento, material
  y llamada T3.DELIVERY_WA_OXXO. Preparado ajuste puntual
  `RECV_INVOICE_INTERCOMPANY_229_PERMISOS_PREVENTA.sql` en Diagnosticos:
  quince permisos concretos verificados dentro de transaccion como login del job.
  Actualizados script E y README; aplicacion por el usuario pendiente.
- `SF_PROC_PREINVOICE_INTER` local actualiza PROCESSED/STATUS antes del routing,
  sin transaccion propia. El mensaje fallido podria no reintentarse solo.
  Preparado `RECV_INVOICE_INTERCOMPANY_26516078_REVISION_MENSAJE.sql`, solo lectura,
  para obtener errores del PID y candidatos por ventana temporal; no identificar
  ROW_ID definitivamente solo por hora ni resetear mensajes masivamente.

- Resultado real de AZCRNMXNEVTD06/T3QA a las 16:58:40: job
  `ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY`, habilitado, propietario
  `T3_SQLAGENT_OWNER` (no sysadmin), paso TSQL en T3QA sin usuario alterno.
- `T3.PROC_T3_OT_GENERAL` existe. El coordinador pertenece efectivamente a
  `AT85233588`; el procedimiento T3 y sus dos procedimientos internos pertenecen
  a `dbo`. Bajo el login tecnico, OBJECT_ID del procedimiento T3 devuelve NULL
  y EXECUTE=0, mientras que EXECUTE del coordinador es 1. Rol
  `T3SqlAgentJobExecutor` confirmado. Causa: visibilidad/permisos, no falta de migracion.
- Preparado `MSSQL/T3/Diagnosticos/RECV_INVOICE_INTERCOMPANY_50021_CORREGIR_PERMISO.sql`:
  solo GRANT EXECUTE del procedimiento T3 al rol existente, prueba como login
  tecnico dentro de transaccion y rollback si falla. Actualizado tambien el
  script E de permisos para despliegues futuros. No cambia SP ni propietarios.
- Usuario confirma aplicacion del script en AZCRNMXNEVTD06/T3QA el
  2026-10-23, finalizacion 17:01:04.0840771 -06:00. Resultado
  `02_PERMISO_VERIFICADO`: login T3_SQLAGENT_OWNER, PuedeEjecutar=1,
  ObjectIdVisible=153767605 para T3.PROC_T3_OT_GENERAL. El resultado previo
  no mostro permiso EXECUTE explicito en el rol. Concesion confirmada.
- Validacion real posterior entregada por el usuario, capturada a las
  2026-10-23 17:06:38.2905223 -06:00: PID 26516072, inicio y fin
  2026-10-23 17:05:21, componente 409, PROCESO_4=0. Consulta de errores
  RECV_INVOICE_INTERCOMPANY desde 17:01:04.0840771 devuelve cero filas.
  Error 50021 resuelto en la siguiente corrida normal en T3QA; el lote vacio
  no acredita procesamiento de documentos ni generacion/timbrado CFDI.
  El coordinador llama el paso T3 incluso con cero candidatos, y ese paso
  puede seleccionar otros pendientes; no se entrego evidencia de sus salidas.
- No conceder
  permisos directos a los procedimientos internos solamente porque OBJECT_ID
  sea NULL fuera de su cadena de propiedad.

Este repositorio contiene una migracion de objetos de base de datos Oracle hacia SQL Server para el ambiente `T3`.

La carpeta `ORA` contiene los fuentes Oracle originales de los esquemas `EAI` y `EAI_OWNER`. La carpeta `MSSQL` contiene la transformacion de esos scripts hacia SQL Server.

La relacion principal del proyecto es origen-destino:

- `ORA`: fuente Oracle.
- `MSSQL`: destino SQL Server transformado o en proceso de transformacion.

Los objetos principales estan relacionados con integraciones y procesos del dominio `EAI`, incluyendo cargas de datos, bitacoras, CFDI, clientes, pagos, ventas, inventario, stock, SAP, Salesforce/Siebel y procesos de conciliacion.

## Estructura principal

- `ORA/T3/EAI/Functions`: funciones Oracle originales del esquema `EAI`.
- `ORA/T3/EAI/Indexes`: 86 DDL individuales de indices Oracle `EAI`.
- `ORA/T3/EAI/Procedures`: procedimientos Oracle originales del esquema `EAI`.
- `ORA/T3/EAI/Packages`: specification y body de packages Oracle `EAI`.
- `ORA/T3/EAI/Triggers`: triggers Oracle originales de auditoria y estatus del esquema `EAI`.
- `ORA/T3/EAI/Tables`: definicion de tablas Oracle del esquema `EAI`.
- `ORA/T3/EAI_OWNER/Functions`: funciones Oracle originales del esquema `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Indexes`: 65 DDL individuales y una exportacion consolidada auxiliar de indices Oracle `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Procedures`: procedimientos Oracle originales del esquema `EAI_OWNER` disponibles actualmente.
- `ORA/T3/EAI_OWNER/Packages`: specification y body de packages Oracle `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Sequences`: cuatro secuencias Oracle `EAI_OWNER`.
- `ORA/T3/EAI_OWNER/Tables`: tablas Oracle originales del esquema `EAI_OWNER`.
- `MSSQL/T3/EAI/Functions`: funciones transformadas a SQL Server.
- `MSSQL/T3/EAI/Indexes`: migracion completa de los 86 indices, PK y restricciones unicas `EAI`.
- `MSSQL/T3/EAI/Procedures`: procedimientos transformados a SQL Server.
- `MSSQL/T3/EAI/Packages`: miembros independientes de `EAI.PKG_ENCUESTAS_MKT`.
- `MSSQL/T3/EAI/Triggers`: triggers `EAI` convertidos a logica set-based con `inserted` y `deleted`.
- `MSSQL/T3/EAI/Tablas`: definicion de tablas transformadas a SQL Server.
- `MSSQL/T3/EAI_OWNER/Functions`: funciones SQL Server asociadas a `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Indexes`: migracion completa de 65 indices y PK; incluye instalador consolidado y 8 columnas calculadas para indices funcionales.
- `MSSQL/T3/EAI_OWNER/Procedures`: transformacion SQL Server asociada a objetos `EAI_OWNER`.
- `MSSQL/T3/EAI_OWNER/Package`: miembros independientes de `EAI_OWNER.RECV_TO_SEND_V3`.
- `MSSQL/T3/EAI_OWNER/Sequences`: homologos de las cuatro secuencias Oracle.
- `MSSQL/T3/EAI_OWNER/Jobs`: despliegue controlado de 37 `USER_JOBS` en SQL Server Agent.
- `ORA/T3/T3/Procedures`: 17 procedimientos Oracle invocados directamente por jobs `EAI_OWNER`.
- `MSSQL/T3/T3/Procedures`: 156 scripts T-SQL del schema `T3`.
- `MSSQL/T3/T3/Tables`: 404 scripts de tablas `T3`; no existe actualmente un conjunto Oracle equivalente bajo `ORA/T3/T3/Tables`.

## Reglas de trabajo para la IA

Antes de proponer cambios:

1. Revisar el archivo Oracle original y su equivalente SQL Server.
2. Identificar tablas leidas, tablas insertadas, actualizadas, truncadas o eliminadas.
3. Revisar diferencias de sintaxis y comportamiento entre Oracle PL/SQL y T-SQL.
4. No asumir que el nombre de la carpeta siempre coincide con el tipo real del objeto.
5. Si el equivalente SQL Server no existe, marcar el objeto como pendiente de transformacion.
6. Si el equivalente SQL Server existe, compararlo contra Oracle antes de sugerir cambios.
7. Marcar cualquier conversion dudosa como pendiente en lugar de inventar reglas.
8. Aplicar las convenciones documentadas en `Docs/CONVERSION_RULES.md` cuando se genere o corrija T-SQL.
9. Para packages, revisar specification y body completos; SQL Server publica cada miembro como objeto independiente.
10. Para jobs, distinguir propietario (`SCHEMA_USER`) del schema del procedimiento invocado en `WHAT`.
11. No habilitar SQL Agent Jobs solo porque exista el procedimiento directo; validar dependencias internas, permisos y calendario.
12. Para indices con nombre `_PK`, revisar la restriccion en el DDL de tablas: un indice unico Oracle no demuestra por si solo que deba crearse una `PRIMARY KEY` en SQL Server.
13. Antes de proponer indices para T3QA, consultar `Docs/T3QA_INDICES_CONTEXTO.md` y la captura `MSSQL/T3/Diagnosticos/Resultado_Indices.txt`. Contrastar claves, INCLUDE, filtros, unicidad y estado; los DDL del repositorio no bastan para conocer los indices instalados. La captura es del 22 de octubre de 2026, no una consulta en vivo.

## Inventario operativo de indices T3QA

- Referencia actual documentada: [T3QA_INDICES_CONTEXTO.md](T3QA_INDICES_CONTEXTO.md), basada en `MSSQL/T3/Diagnosticos/Resultado_Indices.txt`, captura del servidor `AZCRNMXNEVTD06`, `T3QA`, 2026-10-22 12:40:46 -06:00.
- SQL Server 2022, version `16.0.4305.5`, compatibilidad 160, collation de base `SQL_Latin1_General_CP1_CI_AS`. El inventario registra 739 objetos y 384 indices (375 activos, 9 deshabilitados), ademas de 706 heaps.
- `T3.CFDI_DOCUMENTO_PASO` ya tiene activo `IX_CFDI_Paso_BATMD_RFC_Cobertura`: claves `(FECHA_PROC_BATMD,RFC_CLIENTE)`, INCLUDE de las columnas de los cursores, filtro `VOIDDOC IS NULL`. No proponerlo de nuevo. Se valido para las consultas individuales y agrupadas de `PROC_CFDI_PROCESAR_DOCTOS`: lecturas de Paso de 8,305 a 92 por consulta, mismos resultados exportados para BATMD 2026-10-14. No extrapolar a todo el procedimiento ni a otras fechas.
- `T3.FACTURA_GENERAL.IDX_FACTURA_GENERAL_FECHA` tambien se creo para optimizar `T3.PROC_CFDI_PROCESAR_DOCTOS`, segun confirmacion del usuario del 22 de octubre de 2026. Esta activo y cubre la carga Prompt; forma parte de esta optimizacion junto con `IX_CFDI_Paso_BATMD_RFC_Cobertura`. La reduccion medida de 8,305 a 92 lecturas corresponde al indice de Paso, no a una medicion aislada de IDX_FACTURA_GENERAL_FECHA.
- El usuario confirmo el 22 de octubre de 2026 que ambos indices (`IDX_FACTURA_GENERAL_FECHA` e `IX_CFDI_Paso_BATMD_RFC_Cobertura`) ya se encuentran en la base de produccion. No tratarlos como despliegues pendientes. Esta confirmacion no es una inspeccion directa de produccion: no se aportaron nombre de servidor/base, fecha de despliegue ni mediciones de rendimiento de ese ambiente.
- Actualizacion posterior aportada por el usuario: creado en T3QA `T3.ASIGNACION_PAGO.IDX_T3_ASIGNACION_PAGO_FECHA_PROC_BATMD`, nonclustered no unico sin filtro, clave `(FECHA_PROC_BATMD)`, INCLUDE `(PAGO_ID,ASIGNACION_ID,FECHA_TRN,FACTURA,NOTA_CREDITO,CLIENTE_SAP,REP_ID,FECHA_ASIGNACION,VALOR_PAGO,CTRO)`. Cubre columnas AP del cursor ScrPagos de PROC_CFDI_PROCESAR_PAGOS; no afirmar mejora medida ni despliegue en produccion. No sustituye indice por Factura para historial ni resuelve el fallo funcional de cursores. Confirmacion posterior al inventario original, que se conserva sin cambios.
- `CLIENTE_IDX1` esta activo. `IX_Cliente_SAP_Vigencia` e `IX_Ventas_Cliente_SAP_Vigencia` estan deshabilitados. El resumen completo enumera los nueve deshabilitados.
- La captura no es autorizacion para crear, eliminar o habilitar indices. No deducir fechas individuales de indice a partir de fechas de tabla o estadisticas; el trace solo proporciona eventos retenidos. Antes de intervenir, confirmar cambios posteriores a la captura y medir consultas representativas.

## Incidente RECV_INVOICE del 22 de octubre de 2026

- Capturas de AZCRNMXNEVTD06/T3QA confirmaron 256 errores 3930 en los lotes 26515578/26515579: los CATCH de INVOICE_TO_PREVENTA e INVOICE_TO_FACTURA intentaban registrar otra excepcion dentro de una transaccion no confirmable, ocultando la causa inicial. Las lineas instaladas 718/383 eran INSERT al log.
- El usuario autorizo la correccion. Se agrego RI3930_PROPAGATE_V1 a los CATCH de esos dos hijos, INVOICE_TO_ENTREGA_PO y DELIVERY_WA_OXXO: con transaccion activa propagan mediante THROW antes de escribir. SF_PROC_PREINVOICE_IFC conserva el rollback/logging como propietario; no introducir ROLLBACK total en los hijos.
- Paquete de despliegue y pruebas: `MSSQL/T3/Diagnosticos/RECV_INVOICE_3930/README.md`. Los scripts 01/02 son aplicar/verificar en T3QA; 03 es solo reversion. El parche usa las definiciones instaladas y las respalda para no perder variantes existentes. La version instalada del padre tiene RI_REF_SEEK adicionales ausentes del fuente local; no reemplazarla completa para esta correccion.
- Estado de esta entrega: fuentes corregidos y pruebas LocalDB satisfactorias; falta confirmacion de ejecucion en T3QA. No registrar como desplegado en produccion. La causa de negocio previa al 3930 todavia no se conoce. El cambio de indices ya confirmado en produccion es independiente de esta correccion.
- Actualizacion posterior: el usuario reporto SQL-2628 en DELIVERY_WA_OXXO, linea 187, REMISION_GENERAL.REMISION_FOLIO. El INSERT sin columnas envia @Observaciones a REMISION_FOLIO por orden incorrecto; se corrigio el fuente agregando columnas explicitas. `RECV_INVOICE_3930/04_CORREGIR_COLUMNAS_REMISION.sql` aplica solo esa lista al modulo instalado y conserva el guard 3930; pruebas LocalDB satisfactorias, pendiente aplicar 04 en T3QA. No ampliar ni recortar REMISION_FOLIO por este hallazgo. Esta es una causa visible, no una explicacion probada de todos los documentos fallidos.
- Seguimiento 8114 en INVOICE_TO_FACTURA: referencia 1658415284; falta valor real del material para atribuir la causa. El prefijo liberado 202610060% tiene 466 Invoice, pero no contiene esa referencia segun consultas recibidas. La definicion instalada de RECV_INVOICE aportada por el usuario tiene **comentado** el filtro CREATED de cinco dias (linea 63): procesa Invoice pendientes de otras fechas tambien. No asumir que todo error actual corresponde al prefijo liberado ni reemplazar el modulo con la version local que si filtra fecha. El diagnostico 07 revisa el grupo y busca la referencia fuera de el entre pendientes sin fecha; no modifica el job.
- Actualizacion 8114, captura 22/10/2026 15:02: causa confirmada en material `R044`, item `000010/000010`, documento `1658415284`, ROW_ID `20261002121244302218000302218000` (2 de octubre). Un no convertible entre 2,081 filas de material. R044 tambien existe en datos historicos como OTHER RECHARGE / catalogo EXPO. Falta confirmar si esta ruta debe admitir alfanumericos o reclasificar el documento: Oracle usa TO_NUMBER y no debe cambiarse a NULL/0 ni omitirse la linea automaticamente. No generar un parche de material como si esa decision ya estuviera autorizada.
- Decision funcional posterior del usuario (22/10/2026): autoriza omitir TODO DetailBase de una factura si algun material falla conversion NUMERIC(38,0), para continuar el flujo. Reemplaza la restriccion pendiente anterior. Fuente INVOICE_TO_FACTURA actualizado con cinco TRY_CONVERT y NOT EXISTS por ReferenceID; no acepta R044 ni inserta lineas validas de una factura mixta. Script RECV_INVOICE_3930/08_DETAILBASE_VACIO_MATERIAL_INVALIDO.sql aplica solo ese bloque al modulo instalado con respaldo/RunId, reversion mediante 03. Encabezado sin detalle deja totales NULL por SUM existente y luego continua con Procesado/entrega, sujeto a otros errores. Pruebas LocalDB del CTE real, equivalencia numerica, casos invalidos/NULL/blanco, idempotencia y reversion satisfactorias; falta despliegue/validacion reales T3QA. No se modifica INVOICE_TO_FACTURA_OPTIMIZADO ni RECV_INVOICE instalado.

## PROC_CFDI_PROCESAR_PAGOS: captura real del 14/10/2026

- Evidencia y reproduccion: `MSSQL/T3/Diagnosticos/Pagos_20261014/ANALISIS.md`. Captura AZCRNMXNEVTD06/T3QA del 22/10 a las 23:31, CURSOR_DEFAULT GLOBAL. Lote 14/10: 470 asignaciones / 468 facturas, todas BATMD 13:27:28; instalado aun compara con hora, fuente local DATE no desplegado en esa captura.
- Muestra de ocho facturas/diez asignaciones con historial completo: cuatro excluidas por cliente con ultima vigencia 12/09/2026; seis elegibles. No hay encabezados REGISTRO_FISCAL ni cobranza existente para esas ocho. Hay diferencias de detalle fiscal/T3 en V0007-134295, V0008-125448, V0010-134061 y V2363-145780. CHD-33522 es cancelacion por 20723.95, sin detalle de venta.
- El reproductor en servidor confirma captura de filtro NULL al declarar cursor antes de SET. LocalDB con datos y cinco definiciones instaladas reproduce 0 filas con parametro a medianoche, 6 con hora exacta; fuente DATE genera esas 6 desde medianoche pero todas conservan saldo/numero de pago NULL. CHD no recupera cancelacion. No tratar ausencia de excepciones como procesamiento correcto ni el exito del modo CapturaReal como aprobacion funcional. No se corrigieron cursores ni datos reales.

- Correccion posterior autorizada por el usuario: `T3.PROC_CFDI_PROCESAR_PAGOS.sql` ahora declara los cinco cursores dependientes LOCAL despues de asignar sus filtros y los libera por recorrido; elimina los DEALLOCATE finales incondicionales. Marca PAGOS_CURSOR_BIND_V1. Consultas y otras instrucciones conservadas. Pasaron pruebas completas LOCAL/GLOBAL, error 8115 con cursor abierto y siguiente ejecucion, y captura real. CHD-33522 recupera Canc Pago/20723.95; seis saldos y parcialidades recuperados. V2363-145780 conserva total fiscal cero y segundo saldo -194.05. LastRun.txt/LastRealRun.txt son resultados vigentes; LastRealRun_AntesCursores.txt preserva baseline anterior. Pendiente aplicar el ALTER local completo en T3QA; no cambiar reglas de clasificacion, datos fiscales o transacciones bajo esta autorizacion de cursores.

- El usuario reporto el 23/10 una ejecucion real de PROC_CFDI_PROCESAR_PAGOS con parametro 2026-10-14 terminada sin excepcion. No equivale aun a confirmar inserciones/resultado funcional ni version instalada. Se entrego `MSSQL/T3/Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql` (solo lectura, PID 604 mas reciente o explicito) para conciliar elegibles, ventana de CFDI_COBRANZA, faltantes/excedentes, calidad y control 889. Validado en LocalDB: positivo y negativos faltante/duplicado/NULL, evidencia LastValidation.txt. La cobranza no guarda PID en ese INSERT: atribucion temporal limitada ante concurrencia/repeticiones. Pendiente recibir resultados reales.

- Validacion real recibida despues: `MSSQL/T3/Diagnosticos/Pagos_20261014/VALIDACION_REAL_20261023.md`, RPT original conservado. AZCRNMXNEVTD06/T3QA, captura 23/10 12:05:33. Marca de cursores/filtro DATE presentes; modify_date 23/10 00:21:15.327. PID 26515865 (604), 10:55:45-10:56:14, 326 esperadas/insertadas/contador; faltantes/excedentes/no esperadas/errores/NULL de saldo-parcialidad cero. 144 excluidas por vigencia; muestra de 20 calculos sin diferencias. Instalacion y corrida validadas en T3QA, no en produccion. Pendientes distintos: 324 facturas sin REGISTRO_FISCAL, 264 filas con base cero (263 alertas de base + una negativa), 325 estados INCOBRABLE por fallback y una Canc Pago; ningun UUID informado. Control 889 candidato PID26515866 cerrado, sin errores de ventana; asociacion temporal. No volver a aplicar ALTER ni reprocesar para validar, ni presentar la conciliacion tecnica como correccion fiscal completa.

- Revision Oracle posterior, solicitada antes de nuevos cambios: ya existe `ORA/T3/T3/Procedures/PROC_CFDI_PROCESAR_PAGOS.SQL`. Comparacion completa en `MSSQL/T3/T3/Procedures/T3.PROC_CFDI_PROCESAR_PAGOS.PARIDAD_ORACLE.md`. Falta en SQL el JOIN de ScrPagos a CFDI_DOCUMENTOS por AP.Factura y la regla SAT Amount Invoice por RFC (Oracle lineas 100-111,254,321-329): RFC no generico/no vacio, MAX(NVL(Target,'0')) asignado a NUMBER(4)>1 e importe CFDI subtotal+IVA>0 sustituyen nTtl_Invc_Amt antes del saldo. No exige UUID/CONFIRMADO, aplica despues de ambas ramas. Impacto en datos no medido: capturas previas no incluyen ese catalogo ni importes CFDI. No certificar paridad ni atribuir todas las bases cero solo a carga sin revisar esta omision.
- Oracle LOG_START confirma al inicio; el procedimiento confirma lote antes del control y al terminarlo, y hace rollback antes de loguear errores. SQL tiene esas sentencias comentadas y no abre transaccion: diferencia de atomicidad. Ambos no relanzan excepcion. Vacio=NULL Oracle afecta Nota_Credito/Origen y salidas, no normalizar automaticamente. DATE diario es diferencia autorizada (Oracle DATE incluye hora). La correccion LOCAL/declaracion posterior a SET conserva intencion Oracle; no revertirla. Fallback INCOBRABLE, exclusiones, duplicados potenciales y saldos negativos ya existen en el original. 40 columnas/expresiones finales comparadas iguales; faltan fuentes Oracle de FN_TOTAL_FACT, GETCONV y WA_CFDI_COBZA_ASIG_CTRL. No se cambio codigo SQL ni datos durante esta revision.

## Ampliacion de paridad PAGOS: tres auxiliares Oracle recibidos (23/10/2026)

- Sustituye la pendiente anterior de fuentes faltantes: ya se revisaron ORA/T3/T3/Funciones/FN_TOTAL_FACT.SQL, ORA/T3/EAI_OWNER/Functions/GETCONV.SQL y ORA/T3/T3/Procedures/WA_CFDI_COBZA_ASIG_CTRL.SQL. Informe vigente: MSSQL/T3/T3/Procedures/T3.PROC_CFDI_PROCESAR_PAGOS.PARIDAD_ORACLE.md. Esta entrega es analisis/documentacion/pruebas; no cambia codigo SQL de negocio ni despliega.
- FN_TOTAL_FACT Oracle devuelve NULL sin detalle: SUM sin GROUP BY genera una fila NULL y no activa NO_DATA_FOUND. SQL tiene retorno explicito 0. Los ceros esperados por pruebas/capturas anteriores describen SQL, no una regla Oracle ya validada. Con una fila cuyos componentes son NULL ambos retornan 0. La paridad literal puede producir saldos/Importe_Factura NULL sin total alternativo; no implica resolver datos fiscales. Revisar todos los consumidores antes de cambiar funcion compartida.
- GETCONV sin match conserva Source y con match unico retorna Target incluso NULL en ambos. Oracle conserva ultimo registro recuperado, SQL TOP(1); sin ORDER BY no hay seleccion de negocio determinada con duplicados distintos. El comentario historico SQL no acredita paridad. Revisar catalogo (Type,Source)/Targets/NULL/collation antes de elegir regla o imponer unicidad.
- Control 889: ScrPagos SQL aun se declara antes de asignar RFC/central y captura NULL; el arreglo previo de cinco cursores principales no lo incluia. Diagnostico completo actual con 2 pagos via01 y 1 via03: Proceso_1=2, Proceso_2=1, Proceso_3=0, ningun Fecha_Envio marcado, ningun error. Oracle abriria con filtros asignados y marcaria el minoritario. La corrida real anterior del control tenia cero grupos: no validaba esta rama.
- Ademas el control reemplaza ROWID Oracle por Asignacion_ID, sin clave unica en DDL local y nullable. Su UPDATE por solo ese valor puede alcanzar otras agrupaciones/fechas o no encontrar IDs NULL. Prueba aislada del predicado afecto 2 filas sinteticas de distintos grupos; no demuestra duplicados reales. Resolver identificacion estable junto con el cursor, porque activarlo expone ese riesgo.
- Oracle control confirma por iteracion, al final y tras log de error. Durante esta revision el archivo SQL del control se actualizo externamente: ahora BEGIN TRAN/COMMIT/ROLLBACK estan comentados (SHA256 4D727CBC3C60771CB855022F44D806D444DBDAE4EF7C7E2ED31FD42817B41184), por lo que ya no aplica al fuente final la descripcion anterior de transaccion propia/rollback global. Se preservo el cambio y se repitio el diagnostico con exito, sin afirmar paridad transaccional: bajo autocommit confirma cada sentencia; con transaccion externa depende del llamador. LENGTH frente a LEN difiere en espacios finales; pDays NUMBER frente INT difiere para fracciones (principal pasa3). La ventana movil de ultimos tres dias NO es el filtro diario BATMD y no se homologa automaticamente a DATE.
- Diagnostico Run.ps1 -AnalizarDependencias / DependencyParity.sql / LastDependencyParity.txt bajo tests/PROC_CFDI_PROCESAR_PAGOS: compilacion y aserciones de reproduccion satisfactorias, base LocalDB temporal eliminada. PASS confirma hallazgos aun presentes, no paridad ni correccion. No ejecuta Oracle ni consulta T3QA/produccion. Regla SAT ausente, transacciones y vacios de la revision anterior siguen pendientes.

## PAGOS: correccion de reglas Oracle autorizada (23/10/2026)

- El usuario pidio mantener GETCONV MSSQL sin cambios y proceder con los pendientes de PROC_CFDI_PROCESAR_PAGOS. Entrega local completa y probada; pendiente aplicar en T3QA. La corrida real anterior de 326 filas solo validaba DATE/cursores, no esta nueva logica. Informe vigente y orden de scripts: MSSQL/T3/T3/Procedures/T3.PROC_CFDI_PROCESAR_PAGOS.CAMBIOS_ORACLE.md. PARIDAD_ORACLE.md se conserva como informe historico previo.
- GETCONV.SQL y FN_TOTAL_FACT.SQL compartidas conservan hashes 8B8B02C5FB7944E0DE033EAF5D76356E37BC13D07AF7E70E0CF2E206CC5D982B y 8F600C01D0A445C15501DE887FCAD110343DAD4CD94A5A9D7D4839733EF406CE. Para no cambiar otros consumidores de FN_TOTAL_FACT, PAGOS ahora calcula localmente los seis componentes fiscales con OUTER APPLY, decimal(18,2), SUM NULL sin detalle. Una fila de componentes NULL sigue retornando cero. No crear datos fiscales ficticios ni interpretar NULL como fallo de cursores si hay parcialidad calculada.
- Marcadores PAGOS_ORACLE_PARITY_V1/PAGOS_SAT_AMOUNT_V1: ScrPagos LEFT JOIN directo a CFDI_DOCUMENTOS por AP.Factura, importe subtotal+IVA con destino NUMERIC(13,3); luego de ambas ramas, RFC no vacio/no generico, MAX textual NVL(Target,0) de SAT Amount Invoice por RFC convertido NUMERIC(4,0)>1 y SAT>0 sustituyen base antes del saldo. No requiere UUID/CONFIRMADO; mantiene multiplicidad. Configuracion invalida/overflow causa rollback del lote, no fallback cero. Se adaptan vacios exactos a NULL en Origen/Nota_Credito/salidas sin eliminar espacios; GETCONV no cambia.
- Control 889 corregido conjuntamente: ScrPagos LOCAL FORWARD_ONLY DYNAMIC SCROLL_LOCKS declarado tras filtros; UPDATE WHERE CURRENT OF identifica una sola fila aun con ID repetido/NULL en heap sin PK. Cierre/liberacion por uso. Longitud incluye espacios finales. Conserva CM/enviados del cursor interno original, empate estricto y ventana movil; no homologa ese filtro a DATE ni agrega DDL/indices. Cursor dinamico/concurrencia y collation/NLS no se certifican equivalentes al motor Oracle.
- Transacciones activas: principal abre unidad tras LOG_START y confirma antes del control; error revierte lote/RF log, registra afuera, Status2 puede persistir. Control confirma por iteracion y al final; un error tardio conserva grupos anteriores. Con TRAN externa local usan savepoint sin commit ni rollback global ajeno; con XACT_STATE=-1 relanzan error original sin escribir logs para que propietario revierta. Es adaptacion deliberada frente al COMMIT Oracle del trabajo previo del llamador. IMPLICIT_TRANSACTIONS OFF local y CURSOR_CLOSE_ON_COMMIT OFF del control se restauran al retornar, verificado. No se certifica transaccion distribuida.
- Pruebas finales LocalDB: Run.ps1 default (LOCAL/GLOBAL, 8115 y recuperacion), -ParidadOracle (20 escenarios SAT/fiscales, 3 ramas, 2 CFDI por asignacion, errores 8114/8115, savepoint/TRAN condenada, 8 grupos control/3 inconsistencias/6 revisados/5 nuevas marcas, error tardio y recuperacion, validacion NULL/multiplicidad) y -ValidarResultado positivas/negativas pasan. -CapturaReal tambien pasa con las lecturas del 14/10: seis filas y CHD20723.95; V2363-145780 ahora base/saldo NULL conforme Oracle, no cero/-194.05. La captura no exporto SAT/importes CFDI; no atribuirles impacto real. Evidencias LastRun/LastOracleParity/LastValidation/LastRealRun en tests/PROC_CFDI_PROCESAR_PAGOS; bases eliminadas, sin tocar T3QA/produccion ni ejecutar Oracle.
- BaselineOracleParity y LastRealRun_AntesParidadOracle.txt conservan la etapa anterior. AnalizarDependencias usa esos fuentes historicos para reproducir el defecto, no los corregidos. Validador de lectura actualizado para outer join CFDI segun marcador instalado, nota vacia no CM, NULL base distinto de parcialidad faltante y rechazo de certificar corrida anterior al ultimo ALTER. Scripts aplicar: primero T3.WA_CFDI_COBZA_ASIG_CTRL.StoredProcedure.sql y despues T3.PROC_CFDI_PROCESAR_PAGOS.sql; no reprocesar 14/10 automaticamente, no hay idempotencia agregada.

## PAGOS: confirmacion de aplicacion por el usuario (23/10/2026)

- Despues de entregar los dos ALTER (primero control 889 y luego PAGOS), el usuario confirma: "listo, ya los ejecute en la base de datos". En el contexto de las instrucciones entregadas se registra aplicacion reportada en T3QA, sin asumir produccion ni ejecucion del lote. Pendiente evidencia independiente de definiciones y resultado de la siguiente corrida normal. La conciliacion previa de 326 filas no valida la version nueva.
- Se entrega MSSQL/T3/Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VERIFICAR_INSTALACION.sql, solo metadatos: servidor/base, modify_date y marcas SAT/cursores/suma local/DATE/savepoints, mas funciones compartidas informativas. Esperado dos procedimientos con MARCAS ESPERADAS PRESENTES; no visible/faltante no acredita version. No ejecuta procedimientos ni reprocesa datos. Despues del siguiente lote normal usar el validador de resultado con fecha BATMD/PID nuevos. GETCONV permanece fuera del cambio.

- Actualizacion de despliegue PAGOS: resultados recibidos 23/10/2026 13:49:52.3829734 -06:00, AZCRNMXNEVTD06/T3QA. Ambos procedimientos muestran MARCAS ESPERADAS PRESENTES y VersionOracle/CursorCorregido/CalculoOActualizacion/Savepoint=1. Ultimo ALTER principal 13:43:38.253, control 13:46:46.050; FechaSoloDATE=1 solo principal y NULL en control es no aplicable. GETCONV modify_date 23/09/2026 13:23:18.753 y FN_TOTAL_FACT 09/09/2026 13:46:09.620, fechas previas a entrega, coherentes con fuera de cambio (no prueba de hash). Instalacion corroborada por metadatos, ya no pendiente de esa salida; sigue pendiente validacion de un lote posterior y no hay confirmacion de produccion ni ejecucion Oracle. Evidencia MSSQL/T3/Diagnosticos/Pagos_20261023/VERIFICACION_INSTALACION_20261023.md. No repetir ALTER/14-10 para validar instalacion; siguiente paso validador de resultado sobre corrida normal con BATMD/PID nuevos.

- Documentacion posterior solicitada por el usuario: WA_CFDI_COBZA_ASIG_CTRL ampliado para juniors con contrato/parametros, ventana Fecha_Proceso movil (sin convertir a DATE), seleccion externa frente a interna (incluye CM/enviados en interna), referencia de via/empates, CURRENT OF, contadores no unicos, transacciones propias/savepoints, limpieza y logs. Se senalan variables heredadas sin uso y strID sin asignar. Solo comentarios: 1,364 tokens ejecutables/literales identicos, UTF-16 LE BOM, de 274 a 374 lineas. SHA antes 9F83666B63727D10C7661DC739E1F134BBE9B4E7631802D77D3E07FF16311FB6; documental actual 18FC94F0DCB93A5790DB894D4A2935FFED957FFF2635A3F80619BFDC6A3EB0EB. Evidencias funcionales conservan hash previo; no se repiten ni se presentan como pruebas nuevas. Solo fuente local, no confirmado ALTER documental en T3QA. GETCONV, FN_TOTAL_FACT y PAGOS sin cambios en esta revision. Auditoria anotada en CAMBIOS_ORACLE.md.

- Aclaracion/prueba posterior sobre retorno cero de MSSQL: el usuario pregunta si estamos preparados para recibir 0 en lugar de NULL. Se reviso el codigo y se agrego Run.ps1 -ValidarCero / ZeroAmountAssertions.sql / LastZeroAmount.txt. Prueba LocalDB satisfactoria con fuentes actuales: base fiscal 0 y pago previo100 generan saldo anterior -100, parcialidad2, importe actual50; venta T3 cero genera tasa0 sin division; SAT activo sustituye0 por348. Caso sin detalle demuestra que FN_TOTAL_FACT SQL retorna0 pero PAGOS sigue obteniendo SUM local NULL. No afirmar que PAGOS consume el cero de la funcion: no la invoca en ese calculo. No se cambio ningun SP/funcion ni se asumio autorizada conversion de NULL a0 por esta pregunta. Evidencia, hashes y base temporal eliminada; sin acceso a T3QA/produccion.

- Entregable solicitado para cliente: Docs/Entregables/Informe_Tecnico_Cambios_Cobranza_CFDI.docx, documento tecnico autocontenido en espanol de ambos procedimientos. Describe fechas, cursores, suma fiscal local NULL/0 y FN_TOTAL_FACT/GETCONV conservadas, SAT, control por fila/CM/enviados/empates/contadores, transacciones/errores, mantenimiento, cobertura de validacion sin enlaces ni nombres de archivos internos, instalacion T3QA corroborada y lote operativo posterior pendiente. Sin rutas locales, referencias al repositorio, nombres de archivos de pruebas, hipervinculos ni metadatos personales. Creado con runtime Python/documentos y python-docx, preset standard_business_brief. Auditoria estructural satisfecha (geometria, tablas, contenido); siete unidades paginadas previstas, sin certificar conteo de paginas por render. LibreOffice ausente; intento Word nativo en segundo plano bloqueado y procesos propios cerrados. Revision visual no completada; informar esa limitacion en entrega. No se modificaron SP ni se ejecutaron pruebas de negocio para crear este documento.

## Diferencias Oracle -> SQL Server que suelen importar

- `SYSDATE` -> `GETDATE()` o `SYSDATETIME()`.
- `NVL` -> `ISNULL` o `COALESCE`.
- `DECODE` -> `CASE`.
- `DUAL` no existe en SQL Server.
- `VARCHAR2` -> `VARCHAR` o `NVARCHAR`, segun necesidad.
- `NUMBER` requiere decidir entre `INT`, `BIGINT`, `DECIMAL`, `NUMERIC`, etc.
- `DATE` en Oracle puede incluir hora; en SQL Server puede mapear a `datetime`, `datetime2` o `date`.
- `EXECUTE IMMEDIATE` -> SQL dinamico con `sp_executesql` cuando sea necesario.
- Manejo de transacciones y errores: `EXCEPTION` en PL/SQL vs `TRY/CATCH` en T-SQL.
- Secuencias: Oracle `sequence.NEXTVAL` vs SQL Server `NEXT VALUE FOR`.
- Cursores y variables pueden requerir ajustes de alcance y tipo.
- Evitar `dbo` si el objeto pertenece a `EAI`; preferir `[EAI].[Objeto]`.
- Evitar `dbo` si el objeto pertenece a `EAI_OWNER`; preferir `[EAI_OWNER].[Objeto]`.
- Usar `[EAI_OWNER].[ProcessID]`, `[EAI_OWNER].[Log_Start]` y `[T3].[RF_PROCESOS_LOG]` para procesos que en Oracle usan `EAI_Owner.ProcessID.NextVal`.
- Usar `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` para errores de job cuando el Oracle original registra en `MX_EAI_MESSAGE_LOG`.
- No dejar `COMMIT` o `ROLLBACK` sueltos sin `BEGIN TRANSACTION`.
- En funciones escalares T-SQL no usar `TRY/CATCH`; emular excepciones Oracle con validaciones y retornos conservadores cuando aplique.
- `DBMS_JOB` se migra a SQL Server Agent y conserva el numero Oracle mediante `dbo.Job_Oracle_SQLAgent_Map`.
- `schema.package.member` no es valido como equivalente de package: en SQL Server debe resolverse normalmente como `[schema].[member]`.

## Preguntas utiles para cada objeto

- Que problema de negocio resuelve?
- Cuales son las entradas y salidas?
- Que tablas son origen y cuales son destino?
- Hace limpieza previa con `TRUNCATE` o `DELETE`?
- Registra bitacoras o errores?
- Depende de funciones auxiliares?
- La version SQL Server conserva la logica Oracle?
- Que datos de prueba validarian el comportamiento?

## Hallazgos iniciales

- Hay 9 funciones Oracle y 9 funciones SQL Server bajo `EAI`.
- Hay 14 funciones Oracle bajo `ORA/T3/EAI_OWNER/Functions`, ya convertidas con el mismo nombre de archivo bajo `MSSQL/T3/EAI_OWNER/Functions`.
- Hay 36 funciones SQL Server bajo `MSSQL/T3/EAI_OWNER/Functions`; 22 no tienen archivo homonimo en el folder Oracle actual y deben validarse contra su origen.
- Hay 32 procedimientos Oracle bajo `ORA/T3/EAI/Procedures`.
- Hay 32 scripts de procedimiento SQL Server bajo `MSSQL/T3/EAI/Procedures`, mas el auxiliar `Procedures.slnx`.
- Hay dos triggers Oracle `EAI` y dos homologos SQL Server: `UPDATE_T3R_STATUS` y `T3R_SALES_DOCS_OLD_LOG`.
- Hay 86 indices Oracle individuales bajo `EAI` y los 86 tienen conversion homonima bajo `MSSQL/T3/EAI/Indexes`.
- Hay 65 indices Oracle individuales bajo `EAI_OWNER` y los 65 tienen conversion homonima bajo `MSSQL/T3/EAI_OWNER/Indexes`.
- Los triggers usan `[PROCEDURE]` y `[DOC_NUM_R3]` como claves logicas de emparejamiento; el DDL actual no declara llaves tecnicas y no se deben modificar esas claves dentro de las sentencias auditadas.
- Hay 86 procedimientos Oracle bajo `ORA/T3/EAI_OWNER/Procedures`, todos con archivo homonimo en `MSSQL/T3/EAI_OWNER/Procedures`.
- Hay 88 scripts SQL bajo `MSSQL/T3/EAI_OWNER/Procedures`: 86 pares homonimos, `SF_INCONSISTENCIAS_REVISAR.SQL` como variante duplicada de `SF_INCONSISTENCIAS` y `TABLA_Job_Oracle_SQLAgent_Map.SQL` como script de tabla auxiliar ubicado en la carpeta de procedimientos.
- Los procedimientos duplicados de `EAI` fueron retirados de `MSSQL/T3/EAI_OWNER/Procedures`; ambos schemas deben documentarse como conjuntos separados.
- El archivo `ORA/T3/EAI_OWNER/Tables/A51_OL_CLIENTES.SQL` esta ubicado en `Tables`, pero su contenido inicia como una funcion `CONV_45_47_CTRO`; debe revisarse antes de documentarlo como tabla.
- Se han ajustado conversiones recientes con el patron anterior: `SF_BITACORA_CFDI_RESUMEN`, `SF_BITACORA_CFDI_VENTA_SF`, `SF_CFDI_OPEN_ITEMS`, `SF_CFDI_VENTA` y `T3R_REPLICA_SALESDOC`.
- Se convirtieron recientemente las funciones `EAI_OWNER`: `GET_CLEARING_STATUS`, `GET_T3_ENABLE_EXECUTE`, `IC_MOVEMENT_TYPE`, `LETTER_TO_NUMBER`, `LINE_ITEM_TEXT`, `LOG_AUDIT_UPDATED`, `MX_CENTRO_COBZA`, `NUMBER_TO_LETTER`, `PHONE_SINTAXIS`, `SF_PAYMENT_ALLOC`, `SPECIAL_CHARS`, `SPECIAL_CHARS_EDP`, `SPECIAL_CHARS_NEW` y `WA_DN_SKU`.
- En `LOG_AUDIT_UPDATED`, el `ROWID` Oracle se mapeo a `TICKET_REFERENCIA` porque las tablas log SQL Server migradas no exponen una columna `ROWID`.
- `CURRENCY_TEXT` y `GET_4428_REFERENCE` ya se declaran bajo el schema `EAI_OWNER`; evitar reintroducir `dbo`.
- `WA_CIERRE_FLUJOS` es un wrapper transaccional: suspende todos los jobs mediante `EAI_OWNER.Job_Manage('Suspend', 'Todos')` y confirma la operacion.
- La revision mas reciente de procedimientos `WA_*` conserva comportamientos Oracle que requieren especial cuidado: commits dentro de manejadores de excepcion, cursores, `ROWNUM` sin orden explicito, cadenas CLOB fragmentadas y llamadas dinamicas o externas.
- Siete procedimientos de reproceso `WA_ERR_*` usan `MX_EAI_MESSAGE_LOG.ROW_ID` como llave origen: Customer, Intercompany, Invoice, Payment, Product, Replenishment Large y Replenishment Ampersand. El DDL de `ROW_ID` debe desplegarse antes que estos procedimientos; el identificador logico de `MX_RECEIVE_MESSAGE_LOG` se mantiene separado.
- `WA_PURGE_MX_EAI_MESSAGE_LOG` y los ocho bloques de `WA_DEPURA_MESSAGE_LOG` que limpian `MX_EAI_MESSAGE_LOG` materializan primero los `ROW_ID` candidatos y eliminan despues por esa llave. Sus relaciones de negocio solo determinan el conjunto inicial.
- `EAI_OWNER.RECV_TO_SEND_V3` se migro a 12 procedimientos con sus nombres originales, sin el prefijo del package. `GRANTS.SQL` solo concede permisos.
- `EAI.PKG_ENCUESTAS_MKT` se migro a tres procedimientos y una funcion; la publicacion CEDIS requiere linked server y sinonimo configurados por DBA.
- Los cuatro DDL Oracle de secuencias `EAI_OWNER` tienen script SQL Server. Permanecen referencias divergentes en `PURGE_ACCOUNT_HEADER` y `SF_INCONSISTENCIAS_REVISAR`.
- Los 37 jobs del inventario `USER_JOBS` pertenecen a `EAI_OWNER`: 15 llaman `EAI_OWNER`, cinco llaman `EAI` y 17 llaman `T3`. Todos se crean deshabilitados.
- Los 17 procedimientos T3 llamados directamente existen y sus firmas coinciden, pero hay diez dependencias internas pendientes por nombre exacto; consultar `Docs/JOBS_MIGRATION.md`.
- `GET_T3_ENABLE_EXECUTE` busca todavía el texto `RECV_TO_SEND_V3`; los nuevos job names y steps no lo contienen. Resolver esta compatibilidad antes de habilitar jobs.
- `JOB_MANAGE('Suspend','Todos')` usa patrones historicos de comandos que pueden no incluir los nuevos steps `ORA_*`; validar el cierre de flujos contra la tabla de mapeo.

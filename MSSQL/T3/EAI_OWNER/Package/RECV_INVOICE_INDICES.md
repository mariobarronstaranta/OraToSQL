# Revision de accesos por ReferenceID, Factura y Material

Destino informado: **AZCRNMXNEVTD06 / T3QA**. Fecha: 19 de octubre de 2026.

El servidor rechazo el inicio de sesion Windows de GLOBAL\85233588. Por ello
no se ha consultado su catalogo ni creado indices en T3QA. El inventario del
repositorio no sustituye la revision de los objetos desplegados.

El archivo [RECV_INVOICE_INDICES.SQL](RECV_INVOICE_INDICES.SQL) permite revisar
y crear los accesos faltantes sin modificar los procedimientos de negocio.

**Uso en SSMS con una cuenta autorizada**

1. Conectar a AZCRNMXNEVTD06 y seleccionar T3QA. Abrir el archivo SQL completo.
2. Ejecutar con `@Aplicar = 0` y `@SoloId = NULL`, que son los valores iniciales.
   No ejecuta CREATE INDEX. Comprobar Servidor/BaseActual y conservar los dos
   resultados: resumen por tabla e inventario detallado por columna de indice.
3. Para crear un acceso con estado FALTA_ACCESO, cambiar `@Aplicar = 1` y
   `@SoloId` al identificador de esa tabla. Ejecutar el archivo completo en una
   ventana adecuada para CREATE INDEX. Volver a ejecutar modo revision al terminar.
4. Si se decide crear todos los faltantes revisados, usar `@Aplicar = 1` y
   `@SoloId = NULL`. Antes de crear el primero, el script comprueba que no haya
   estados pendientes de revision y que la cuenta tenga permiso ALTER.

Por ejemplo, `@Aplicar = 1` y `@SoloId = 3` crea el indice de condiciones por
ReferenceID solo si falta un acceso equivalente. No modifica otra tabla.
El script no selecciona automaticamente otra base, no incluye credenciales y
no necesita ejecutar RECV_INVOICE para revisar los indices.

| Id | Tabla | Clave inicial necesaria | Operaciones del flujo |
|---:|---|---|---|
| 1 | EAI_OWNER.TMP_DOCUMENT_HEADER | REFERENCEID | Busqueda, limpieza y actualizacion de cabecera |
| 2 | EAI_OWNER.TMP_DOCUMENT_DETAIL | REFERENCEID | Limpieza, lectura y agregaciones por documento |
| 3 | EAI_OWNER.TMP_DOCUMENT_CONDITIONS | REFERENCEID | Limpieza de condiciones por documento |
| 4 | T3.PREVENTA_GENERAL | FACTURA | Validacion, limpieza y actualizacion de preventa |
| 5 | T3.PREVENTA_DETALLE | FACTURA | Limpieza, detalle y totales |
| 6 | T3.FACTURA_GENERAL | FACTURA | Validacion, limpieza y actualizacion de factura |
| 7 | T3.FACTURA_DETALLE | FACTURA | Limpieza, detalle y totales |
| 8 | T3.RF_COMPLEMENTO | FACTURA | Limpieza y reconstruccion de complemento |
| 9 | T3.REMISION_GENERAL | FACTURA | Busqueda de remision existente |
| 10 | T3.MATERIAL | MATERIAL | Conversiones y consultas repetidas por partida |

**Interpretacion del resultado**

- ACCESO_EXISTENTE: hay un indice B-tree habilitado y sin filtro que empieza
  por la clave requerida. Puede ser compuesto, UNIQUE, PK o tener otro nombre.
  No se crea otro indice. No garantiza que el optimizador lo utilice ni que
  cubra todas las columnas de cada consulta.
- FALTA_ACCESO: no se encontro ese acceso. PropuestaCreacion muestra el DDL exacto.
- REVISAR_INDICE_FILTRADO: existe un acceso inicial filtrado. Se conserva para
  revisar el predicado y el plan; no se duplica automaticamente. Un filtro
  `FACTURA IS NOT NULL`, por ejemplo, podria servir para las igualdades del flujo.
- CONFLICTO_NOMBRE: el nombre propuesto ya existe sin ofrecer el acceso requerido.
  El script no lo elimina, reemplaza ni habilita.
- Otros estados indican columnas/tablas ausentes o sin visibilidad, clustered
  deshabilitado, tipo de clave no previsto o tabla optimizada para memoria.
  Resolver la discrepancia antes de aplicar ese Id.

Una clave en segunda posicion o solo en INCLUDE no se considera equivalente.
Ejemplo: `(TIPO_DOCTO, FECHA_FACTURA) INCLUDE (FACTURA)` no sustituye un indice
que comience por FACTURA. `(FACTURA, NUM_LINEA)` si ofrece ese acceso inicial.
El orden ASC/DESC no cambia esta equivalencia para las busquedas por igualdad.

**Decision de diseño de esta primera etapa**

REMISION_DETALLE se excluye: en el flujo revisado recibe INSERT, pero no hay una busqueda por Factura que justifique agregarle este indice en esta etapa.

Los indices nuevos por ReferenceID y Factura son estrechos y no unicos. No se
incluyen importes, XML ni textos extensos. Se busca evitar recorridos completos
sin agregar mas mantenimiento del necesario a tablas con DELETE/INSERT frecuente.

Si MATERIAL no tiene un acceso inicial, se propone incluir UM, UNIDAD_MED_VTA,
CIG_X_CLL, CIG_X_PAQ, CIG_X_CT y NOMBRE_MATERIAL, utilizados por parser, conversiones
y remisiones. Si MATERIAL ya tiene un indice por su clave, se conserva aunque
no tenga esa cobertura; ampliar/reemplazarlo exige revisar lecturas y plan real.

Confirmado en archivos locales, no en produccion:

- `Indices_Consolidados_EAI_OWNER.SQL` define TMP_DOCUMENT_HEADER_IXREF y
  TMP_DOCUMENT_DETAIL_IDX con ReferenceID inicial. El script los reutilizara
  si estan desplegados y habilitados.
- `SF_PROC_PREINVOICE_IFC_OPTIMIZADO.SQL` contiene propuestas para condiciones
  y material. No es necesario desplegar ese procedimiento alternativo para
  crear los indices de esta etapa.
- `SF_CFDI_OPEN_ITEMS_INDICES_SELECCIONADOS.SQL` propone un indice que empieza
  por Factura para FACTURA_DETALLE; tambien se reutilizara si existe. Su indice
  de FACTURA_GENERAL por tipo/fecha no sustituye el acceso inicial por Factura.

CREATE INDEX puede bloquear, consumir disco/log y tardar en tablas grandes.
No se fuerza ONLINE, no se cambia recuperacion y no se reconstruyen indices
existentes. No hay transaccion global; si falla un indice, los ya creados permanecen.
El script rechaza aplicacion dentro de transaccion externa o con transacciones
implicitas. Se puede repetir despues de resolver el problema. No lanzarlo desde
dos sesiones de mantenimiento a la vez.

**Comprobacion de mejora**

Guardar inventario y diagnostico antes/despues, e identificar cada indice creado.
Primero considerar accesos faltantes de TMP_DOCUMENT_* y MATERIAL si el parser
concentra lecturas; continuar con las tablas de la rama que domine el lote.
No crear indiscriminadamente todos los propuestos solo por estar disponibles.

Con un lote equivalente al observado a 2 documentos/s, comparar documentos
completos por segundo, lecturas logicas, CPU, esperas y planes reales. Verificar
que busquedas/eliminaciones por referencia o factura dejen de recorrer tablas
completas cuando sea conveniente. Un scan en una tabla pequeña no demuestra
un problema. Un indice existente tampoco soluciona conversiones implicitas sobre
la clave ni los cursores XML; si sigue sin utilizarse, revisar esos factores.

**Pruebas realizadas**

[Run.ps1](../Procedures/tests/RECV_INVOICE_INDICES/Run.ps1) crea una base temporal
en LocalDB con los DDL reales del repositorio y la elimina al terminar. Verifica:

- Revision sin creacion de indices.
- Deteccion de indices filtrados antes de ejecutar cualquier DDL.
- Aplicacion selectiva y repeticion sin duplicados.
- Rechazo de un nombre ocupado por otra clave.
- Reutilizacion de indices con otro nombre, clave descendente y clave compuesta.
- Rechazo de la clave solo en segunda posicion.
- Creacion exacta de los faltantes y cobertura nueva de MATERIAL.
- Rechazo del nombre ocupado por un indice deshabilitado.

Estas pruebas verifican la logica del script; no son una medicion del rendimiento
de T3QA. El siguiente dato necesario es el resultado de su ejecucion en modo revision
contra esa base con una cuenta autorizada.

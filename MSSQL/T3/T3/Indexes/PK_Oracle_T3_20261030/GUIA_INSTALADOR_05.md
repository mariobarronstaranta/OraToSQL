# Instalador de PK para tablas migradas

Resultado 04 recibido de AZCRNMXNEVTD06 / T3QA, captura 2026-11-05
23:48:05.9699907 -06:00: 65 tablas con datos validos, 13 ausentes y tres
bloqueadas. VIEW DEFINITION de la base devuelve 1.

| Pendiente | Resultado |
|---|---|
| CFDI_CATALOGOS_SAT | Una fila con ID NULL; cero grupos duplicados |
| MOV_CLIENTE | Cero filas con NULL; 20,398 grupos duplicados por CLIENTE_V3 |
| USUARIOS | Cero filas con NULL; un grupo duplicado por USUARIO |

Un grupo duplicado no equivale a una fila sobrante. No se decide que registro
conservar ni se asignan identificadores automaticamente. El script 06 permite
investigar estas tres tablas sin modificarlas.

## Aplicacion en SSMS

1. Ejecutar completo `05_APLICAR_PK_TABLAS_MIGRADAS.sql` en T3QA con
   `@Aplicar=0`. Sustituye al 01 para esta intervencion; no necesita ejecutarlo.
   Esperado si los datos y metadatos siguen iguales: 65 LISTA, 13
   OMITIDA_NO_VISIBLE y tres PENDIENTE_DATOS. Los controles adicionales pueden
   reportar BLOQUEADA si hay dependencias o configuraciones no soportadas.
2. Revisar el plan y ejecutar completo con `@Aplicar=1`, en ventana sin
   escritores concurrentes ni cambios de esquema. Si hay cualquier BLOQUEADA,
   no aplica ninguna tabla. Las ausentes y pendientes conocidas no bloquean.
3. Ejecutar `02_VERIFICAR_PK_T3.sql`. Se esperan 65 PK equivalentes. Las 13
   ausentes y las tres pendientes seguiran apareciendo sin PK.

`@SoloTabla` permite aplicar una tabla. `@IncluirPendientes=0` excluye por
nombre las tres pendientes; para tratarlas una vez corregidas, seleccionar
la tabla y poner `@IncluirPendientes=1`. El script vuelve a validar sus datos.
No basta con cambiar el parametro para resolver nulos o duplicados.

## Que modifica

En las 65 tablas elegibles se esperan 61 reemplazos de indices equivalentes
y cuatro PK nuevas: CREDITO_EXPRESS, FACT_T3, FACTD_AGR_T3 y NOTA_T3.
CLIENTE_PK se reemplaza por una PK activa. USUARIO_PK permanece deshabilitado
mientras USUARIOS este pendiente.

Cada tabla se procesa en una transaccion: bloqueo exclusivo, comprobacion de
metadatos, DROP del indice equivalente si existe, ALTER COLUMN NOT NULL y
ADD CONSTRAINT PRIMARY KEY NONCLUSTERED. La creacion vuelve a exigir unicidad
y ausencia de nulos. Un fallo revierte indice, nullabilidad y PK de esa tabla
y detiene el lote; las tablas confirmadas anteriormente permanecen aplicadas.
La reejecucion reconoce PK equivalentes aun con otro nombre.

Conserva tipos, longitudes, precision, escala, collation e identidad. No
modifica filas ni elimina otros indices. Las dependencias que impidan ALTER
COLUMN pueden causar un fallo controlado y rollback por tabla.

Solo reemplaza indices del mismo nombre, unicos NONCLUSTERED, con las mismas
columnas y orden Oracle, sin INCLUDE, DESC, filtros, FK que los referencien,
propiedades extendidas, particionado o compresion. Exige las opciones simples
observadas en 04 y filegroup PRIMARY. Si encuentra otra configuracion, bloquea.
Las PK nuevas se crean en PRIMARY. Se requiere fill factor del servidor 0;
se omite FILLFACTOR en ADD CONSTRAINT porque no admite el literal 0.
Para CLIENTE_PK, que no muestra particiones/compresion por estar deshabilitado,
la PK se crea explicitamente con DATA_COMPRESSION=NONE.

El bloqueo exclusivo dura toda la transaccion de cada tabla y puede ser
costoso en tablas grandes. La vista previa tambien escanea nulos/duplicados.
Los conteos del 04 son una captura, no una garantia de que no hayan cambiado.

## Validacion local

`tests_instalador_05.py`, aprobado el 2026-11-05 sobre LocalDB:

- Vista previa sin DDL y omision de tablas inexistentes.
- Fallo forzado despues de crear PK: restaura indice y nullabilidad.
- Bloquea indice homonimo con otras columnas, INCLUDE y FK dependiente.
- 65 DDL reales del repositorio y tres tablas ficticias para las tablas
  presentes sin DDL local: 65 PK creadas, 13 ausentes y tres pendientes.
- Revalidacion detecta NULL y duplicados al incluir pendientes.
- CLIENTE_PK queda activo; reejecucion reconoce las 65 PK.

Base temporal de la prueba exitosa: CodexPK05_b9188287, eliminada al terminar.
No se ejecuto el instalador contra T3QA desde esta sesion.

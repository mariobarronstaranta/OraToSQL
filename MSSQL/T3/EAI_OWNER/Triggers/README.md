# Triggers de EAI_OWNER migrados a SQL Server

Los nueve archivos con nombres iguales a los de `ORA/T3/EAI_OWNER/Triggers`
implementan los triggers en T-SQL. No seleccionan una base con `USE`.

## Instalacion

1. Seleccionar la base destino y crear las tablas y esquemas del repositorio.
2. Ejecutar `00_AUDIT_ROW_ID.SQL`.
3. Ejecutar los nueve archivos de triggers, en cualquier orden.

Se requiere SQL Server 2016 SP1 o posterior por `CREATE OR ALTER`.
La instalacion necesita permisos para alterar las siete tablas auditadas,
crear sus indices y crear/alterar triggers. Los scripts son reejecutables.

### Clave tecnica necesaria

El DDL disponible no declara una clave unica e inmutable para relacionar
`inserted` con `deleted`. Emparejar por columnas de negocio o por ordinales
produciria auditoria incorrecta al modificar claves o tener duplicados.

`00_AUDIT_ROW_ID.SQL` agrega `AUDIT_ROW_ID bigint IDENTITY(1,1) NOT NULL`
y un indice unico no agrupado a estas tablas:

- `T3.CFDI_PRODSERV`
- `T3.CFDI_USOCFDI_CLIENTE`
- `EAI_OWNER.MX_HASHTABLE`
- `EAI_OWNER.MX_CFG_CONDITION_HAWA`
- `EAI_OWNER.XP_ASIGNACION_PAGO`
- `EAI_OWNER.X_APLICA_INCOBRABLE`
- `EAI_OWNER.X_ASIGNACION_PAGO`

La clave tambien se asigna a filas existentes. No cambia columnas de negocio,
pero altera la estructura fisica y agrega una columna a `SELECT *`. Revisar
consumidores de `SELECT *`, cargas masivas y usos de `SELECT INTO` antes de
instalar. Las inserciones deben omitir la columna tecnica; no usar
`IDENTITY_INSERT` ni reseed para reutilizar valores. Agregar la columna y el
indice a tablas grandes puede requerir tiempo, espacio y bloqueos de esquema.
El script falla si existe una columna incompatible o la tabla ya tiene otra
columna IDENTITY. Los DDL originales de tablas no fueron modificados.

## Correspondencia y comportamiento

| Archivo / trigger | Tabla | Comportamiento |
| --- | --- | --- |
| TRG_LOGGING_CFDI_PRODSERV | T3.CFDI_PRODSERV | Audita todos los INSERT, UPDATE y DELETE |
| TRG_LOGGING_HASHTABLE | EAI_OWNER.MX_HASHTABLE | Audita todos los INSERT, UPDATE y DELETE |
| TRG_LOGGING_HAWA | EAI_OWNER.MX_CFG_CONDITION_HAWA | Audita todos los INSERT, UPDATE y DELETE |
| TRG_LOGGING_USOCFDI_CLIENTE | T3.CFDI_USOCFDI_CLIENTE | Audita todos los INSERT, UPDATE y DELETE |
| TRG_XP_ASIGNACION_PAGO | EAI_OWNER.XP_ASIGNACION_PAGO | Cobranza, tipo Cobza |
| TRG_X_APLICA_INCOBRABLE | EAI_OWNER.X_APLICA_INCOBRABLE | Cobranza, tipo Incob |
| TRG_X_ASIGNACION_PAGO | EAI_OWNER.X_ASIGNACION_PAGO | Cobranza, tipo Asig |
| WA_TMP_INVOICE_TRG | EAI_OWNER.WO_TMP_INVOICE | Historico de filas eliminadas |
| Z_MX_RECV_MESSAGE | EAI_OWNER.MX_RECEIVE_MESSAGE_LOG | Extrae DOCNUM del XML antes de almacenarlo |

Los dos triggers sobre tablas T3 se crean en el esquema **T3**; SQL Server
exige que un trigger DML pertenezca al esquema de su tabla. Sus archivos
permanecen en esta carpeta para mantener la correspondencia con Oracle.

Los siete triggers de auditoria trabajan por conjuntos, incluida la modificacion
de claves de negocio y filas duplicadas. Los de cobranza siempre registran
INSERT/DELETE, y solo registran UPDATE cuando cambia un campo supervisado.
Solo llenan OLD/NEW de los campos modificados, conservando los centinelas
Oracle `NVL(texto, 'NULO')` y `NVL(importe, 0)`. Las cadenas vacias se tratan
como NULL; los espacios no se eliminan. Las comparaciones binarias detectan
cambios de mayusculas, acentos y espacios finales independientemente de la
intercalacion de SQL Server.

En XP no se usa NOTA_CREDITO: su tratamiento estaba comentado en Oracle.
En X_ASIGNACION_PAGO y X_APLICA_INCOBRABLE, fecha de asignacion y clearing
permanecen NULL en el log, igual que en los originales.

La metadata usa `SYSDATETIME()`, `SUSER_SNAME()`, `ORIGINAL_LOGIN()`,
`CONNECTIONPROPERTY('client_net_address')` y `HOST_NAME()`. Los textos de
conexion se limitan al ancho de las columnas existentes. ORIGINAL_LOGIN
identifica el login SQL/Windows original, no necesariamente el usuario del
sistema operativo del cliente. HOST_NAME es suministrado por el cliente y
la direccion IP puede ser NULL en conexiones locales.

`WA_TMP_INVOICE_TRG` usa AFTER DELETE: el historico y el borrado pertenecen
a la misma transaccion y se revierten juntos. Cambia el momento de ejecucion
respecto de otros triggers y restricciones frente al BEFORE DELETE de Oracle.
Se conservan los anchos del historico (60) aunque la tabla origen admite 512;
un valor demasiado largo impide el borrado por error de truncamiento.

### Recepcion de mensajes: diferencias con Oracle

`Z_MX_RECV_MESSAGE` usa INSTEAD OF INSERT y la ruta exacta
`/*/Header/Reference/ReferenceID`, sin ignorar namespaces. Procesa cada fila
independientemente, incluso si ROW_ID es NULL o esta repetido.

- Ruta ausente, valor vacio o XML NULL: DOCNUM queda NULL.
- Valor escalar de hasta 20 bytes: sustituye DOCNUM.
- Multiples nodos, contenido no escalar o exceso de longitud: registra el
  error y conserva el DOCNUM recibido, como la rama de excepcion Oracle.
- El codigo de error es `SQL-XML-DOCNUM`, no un codigo ORA ficticio.
- XML mal formado es rechazado por el tipo `xml` antes de ejecutar el trigger.
- **No hay transaccion autonoma:** un ROLLBACK tambien revierte el registro
  de error. Para conservar errores fuera de la transaccion se requiere un
  mecanismo externo, no incluido en estos scripts.
- Errores de infraestructura, permisos o escritura del log se propagan.
  El ID del log sigue teniendo 20 caracteres frente a los 32 de ROW_ID;
  un error XML con ROW_ID mayor de 20 puede fallar al registrar el error,
  igual que con los anchos disponibles en el modelo de origen.
- Solo puede existir un INSTEAD OF INSERT por tabla. Si el entorno tiene
  otro, se debe integrar su logica. Si se agregan columnas de negocio a
  MX_RECEIVE_MESSAGE_LOG, actualizar la lista explicita del INSERT interno.

Referencia: [CREATE TRIGGER, Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql).

## Validacion reproducible

Desde la raiz del repositorio:

```powershell
& .\MSSQL\T3\EAI_OWNER\Triggers\tests\Run.ps1
```

El runner crea una base temporal con nombre aleatorio en LocalDB, extrae el
DDL real del repositorio, instala los scripts dos veces, ejecuta aserciones
y elimina la base en `finally`. Se puede cambiar la instancia con `-Server`.
No ejecuta scripts contra la base de negocio.

Validado en SQL Server 2025 LocalDB: compilacion y reinstalacion de los nueve
triggers; INSERT/UPDATE/DELETE multiples; cambios de claves duplicadas;
sentencias sin filas; cambios solo de mayusculas; NULL/0 y vacio/NULL;
espacios significativos; campos modificados de cobranza; historico; XML
valido, ausente, vacio, largo, multiple y no escalar; y ROLLBACK.

# Plan para generar documentacion

## Fase 1: mapa del repositorio

Estado: actualizado.

Objetivo: que una IA o desarrollador entienda rapidamente que `ORA` contiene los fuentes Oracle de `EAI`, `EAI_OWNER` y el subconjunto `T3` relacionado con jobs, y que `MSSQL` contiene la transformacion hacia SQL Server.

Entregables:

- `README.md`
- `AI_CONTEXT.md`
- `INVENTORY.md`

Estado actual: creados y actualizados para incluir 86 procedimientos Oracle
`EAI_OWNER`, dos packages, cuatro secuencias, 37 jobs y 17 procedimientos Oracle
`T3` vinculados a esos jobs. Los 156 procedimientos y 404 tablas MSSQL del
schema `T3` ya aparecen en el inventario, aunque la trazabilidad Oracle de las
tablas T3 sigue pendiente.

## Fase 2: ficha por objeto

Crear una ficha Markdown por cada procedimiento, funcion o tabla importante. Cada ficha debe documentar la relacion entre el objeto Oracle original y su transformacion SQL Server.

Ruta sugerida:

```text
Docs/objects/functions/
Docs/objects/procedures/
Docs/objects/tables/
Docs/objects/packages/
Docs/objects/jobs/
```

Plantilla sugerida:

```markdown
# NombreDelObjeto

## Resumen

## Archivos

- Oracle:
- SQL Server:

## Entradas

## Salidas

## Tablas leidas

## Tablas modificadas

## Logica de negocio

## Diferencias Oracle vs SQL Server

## Riesgos o pendientes

## Pruebas sugeridas
```

## Fase 3: matriz Oracle vs SQL Server

Crear una matriz que compare cada objeto fuente en `ORA` con su destino esperado en `MSSQL`:

- Existe en Oracle?
- Existe en SQL Server?
- Mantiene el mismo nombre?
- Mantiene el mismo schema?
- Esta pendiente de transformacion?
- Tiene diferencias pendientes?
- Tiene pruebas?

Archivo sugerido:

```text
Docs/MIGRATION_MATRIX.md
```

## Fase 4: reglas de conversion

Estado: iniciado.

Documentar reglas comunes del proyecto:

- Tipos de datos.
- Fechas.
- Manejo de errores.
- Transacciones.
- Secuencias.
- Tablas temporales.
- Funciones equivalentes.
- Convenciones de schema.

Archivo sugerido:

```text
Docs/CONVERSION_RULES.md
```

Estado actual: creado con reglas de schema, equivalencias Oracle/T-SQL, logging, transacciones y validacion estatica.
Incluye reglas especificas para funciones escalares y para el caso `ROWID` Oracle sin columna equivalente directa en SQL Server.
Incluye tambien reglas para packages, secuencias y `DBMS_JOB`/SQL Server Agent.

## Fase 5: flujos de negocio

Agrupar objetos por proceso:

- CCEA data: allocation, open item, payment, sale, stock, unload.
- CFDI.
- Clientes.
- Stock e inventario.
- SAP/Salesforce/Siebel.
- Logs, errores y bitacoras.

Archivo sugerido:

```text
Docs/BUSINESS_FLOWS.md
```

## Orden recomendado

1. Documentar funciones auxiliares primero. Las 14 funciones de `ORA/T3/EAI_OWNER/Functions` ya tienen equivalente en `MSSQL/T3/EAI_OWNER/Functions`; falta generar ficha detallada por objeto.
2. Documentar los 86 procedimientos `EAI_OWNER` que ya tienen par Oracle/SQL Server.
3. Resolver los dos archivos auxiliares ubicados en `MSSQL/T3/EAI_OWNER/Procedures`: decidir si se elimina o archiva `SF_INCONSISTENCIAS_REVISAR.SQL` y reubicar `TABLA_Job_Oracle_SQLAgent_Map.SQL` en la carpeta de tablas cuando corresponda.
4. Resolver las diez dependencias internas T3 de los jobs y la busqueda
   `RECV_TO_SEND_V3` de `GET_T3_ENABLE_EXECUTE`.
5. Validar en servidor los dos packages y la publicacion CEDIS.
6. Documentar procedimientos CCEA y CFDI del schema `EAI`.
7. Documentar tablas mas usadas y obtener fuentes Oracle para las 404 tablas T3.
8. Crear matriz de diferencias.
9. Validar con pruebas o consultas de control.

## Entregables especializados completados

- `MESSAGE_LOG_ROW_ID.md`: decision y despliegue de la llave tecnica.
- `PACKAGES_MIGRATION.md`: packages `RECV_TO_SEND_V3` y `PKG_ENCUESTAS_MKT`.
- `SEQUENCES_MIGRATION.md`: cuatro secuencias `EAI_OWNER`.
- `JOBS_MIGRATION.md`: 37 jobs, calendarios, mapeo y bloqueos.

## Pendientes de liberacion

- No confundir existencia de archivo con objeto listo para produccion.
- Ejecutar `02_VALIDATE_JOBS.SQL` en la base destino.
- No habilitar jobs hasta resolver dependencias T3 y compatibilidad de nombres.
- Confirmar linked server/sinonimo CEDIS.
- Probar compilacion y datos controlados para packages y procedimientos T3.

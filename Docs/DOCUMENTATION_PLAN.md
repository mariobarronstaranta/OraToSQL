# Plan para generar documentacion

## Fase 1: mapa del repositorio

Estado: iniciado.

Objetivo: que una IA o desarrollador entienda rapidamente que `ORA` contiene los fuentes Oracle de `EAI` y `EAI_OWNER`, y que `MSSQL` contiene la transformacion hacia SQL Server.

Entregables:

- `README.md`
- `AI_CONTEXT.md`
- `INVENTORY.md`

## Fase 2: ficha por objeto

Crear una ficha Markdown por cada procedimiento, funcion o tabla importante. Cada ficha debe documentar la relacion entre el objeto Oracle original y su transformacion SQL Server.

Ruta sugerida:

```text
Docs/objects/functions/
Docs/objects/procedures/
Docs/objects/tables/
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

1. Documentar funciones auxiliares primero.
2. Documentar procedimientos CCEA.
3. Documentar procedimientos CFDI.
4. Documentar tablas mas usadas.
5. Crear matriz de diferencias.
6. Validar con pruebas o consultas de control.

# Documentacion del proyecto OraToSQL

Este directorio concentra la documentacion operativa y tecnica del proyecto de migracion de Oracle a SQL Server.

## Objetivo

El proyecto contiene los fuentes Oracle originales para los esquemas `EAI` y `EAI_OWNER`, y la transformacion de esos scripts hacia SQL Server.

La carpeta `ORA` es la fuente de verdad del codigo Oracle. La carpeta `MSSQL` contiene la version transformada, convertida o en proceso de conversion a SQL Server.

La documentacion busca servir para:

- Entender la estructura del repositorio.
- Ayudar a una IA o a un desarrollador a ubicarse rapidamente.
- Registrar reglas de migracion Oracle -> SQL Server.
- Documentar objetos criticos: tablas, funciones y procedimientos.
- Detectar diferencias, pendientes y riesgos de conversion.
- Dar contexto suficiente a una IA para analizar, comparar o transformar scripts sin perder la relacion origen-destino.

## Documentos iniciales

- [AI_CONTEXT.md](AI_CONTEXT.md): contexto breve para entregar a una IA antes de pedir ayuda.
- [INVENTORY.md](INVENTORY.md): inventario de carpetas, objetos y hallazgos.
- [DOCUMENTATION_PLAN.md](DOCUMENTATION_PLAN.md): plan sugerido para ampliar la documentacion.
- [CONVERSION_RULES.md](CONVERSION_RULES.md): reglas y convenciones usadas al convertir Oracle PL/SQL a SQL Server T-SQL.
- [MESSAGE_LOG_ROW_ID.md](MESSAGE_LOG_ROW_ID.md): decision tecnica, objetos impactados y estrategia de migracion para `MX_EAI_MESSAGE_LOG.ROW_ID`.
- [PACKAGES_MIGRATION.md](PACKAGES_MIGRATION.md): equivalencia de packages Oracle y estado de `RECV_TO_SEND_V3` y `PKG_ENCUESTAS_MKT`.
- [SEQUENCES_MIGRATION.md](SEQUENCES_MIGRATION.md): inventario, despliegue y diferencias de las secuencias `EAI_OWNER`.
- [JOBS_MIGRATION.md](JOBS_MIGRATION.md): inventario `USER_JOBS`, conversion a SQL Server Agent, dependencias y habilitacion controlada.
- [PROMPTS.md](PROMPTS.md): prompts utiles para pedir analisis o conversion asistida por IA.

## Estructura del repositorio

```text
ORA/
  T3/
    EAI/
      Functions/
      Packages/
      Procedures/
      Tables/
    EAI_OWNER/
      Functions/
      Packages/
      Procedures/
      Sequences/
      Tables/
    T3/
      Procedures/

MSSQL/
  T3/
    EAI/
      Functions/
      Packages/
      Procedures/
      Tablas/
    EAI_OWNER/
      Functions/
      Jobs/
      Package/
      Procedures/
      Sequences/
      Tables/
    T3/
      Procedures/
      Tables/

Docs/
```

## Regla principal del proyecto

Cada objeto documentado debe tratarse como una relacion entre:

- Origen: script Oracle dentro de `ORA`.
- Destino: script SQL Server dentro de `MSSQL`.

Cuando no exista equivalente en `MSSQL`, debe registrarse como pendiente de transformacion. Cuando exista en `MSSQL`, debe compararse contra el origen Oracle para validar que conserva la logica esperada.

## Convencion recomendada

Para cada objeto importante conviene documentar:

- Nombre del objeto.
- Tipo: tabla, funcion o procedimiento.
- Version origen Oracle.
- Version destino SQL Server.
- Tablas leidas.
- Tablas escritas.
- Parametros de entrada y salida.
- Reglas de negocio visibles.
- Diferencias conocidas entre Oracle y SQL Server.
- Riesgos, pendientes y pruebas sugeridas.

## Convenciones aplicadas en las conversiones recientes

- Los procedimientos Oracle del esquema `EAI` se generan como `CREATE OR ALTER PROCEDURE [EAI].[NombreObjeto]`.
- Las funciones Oracle bajo `ORA/T3/EAI_OWNER/Functions` se generan como `CREATE OR ALTER FUNCTION [EAI_OWNER].[NombreObjeto]` y se guardan con el mismo nombre de archivo bajo `MSSQL/T3/EAI_OWNER/Functions`.
- Los 86 procedimientos Oracle bajo `ORA/T3/EAI_OWNER/Procedures` tienen un archivo homonimo bajo `MSSQL/T3/EAI_OWNER/Procedures` y se generan en el schema `[EAI_OWNER]`.
- Los miembros de un package Oracle se publican como procedimientos o funciones independientes en el schema original; la carpeta `Package`/`Packages` conserva solamente la agrupacion visual.
- Los nombres publicos de los 12 miembros de `RECV_TO_SEND_V3` no llevan el prefijo del package, por decision del cliente.
- Los 37 registros `USER_JOBS` entregados para `EAI_OWNER` se despliegan como SQL Server Agent Jobs deshabilitados y se relacionan mediante `dbo.Job_Oracle_SQLAgent_Map`.
- Los 17 procedimientos `[T3]` llamados directamente por esos jobs existen en `MSSQL/T3/T3/Procedures`; deben validarse tambien sus dependencias internas antes de habilitar los jobs.
- Las tablas se referencian con schema explicito y corchetes, por ejemplo `[EAI].[CFDI_Bitacora]`.
- El logging de procesos usa `[EAI_OWNER].[ProcessID]`, `[EAI_OWNER].[Log_Start]` y `[T3].[RF_PROCESOS_LOG]` cuando el origen Oracle usa `EAI_Owner.ProcessID.NextVal` y `EAI_Owner.Log_Start`.
- El logging de errores usa `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` con `TRY/CATCH`. Usar `THROW` solo cuando Oracle propaga la excepcion; si Oracle la registra y termina, conservar ese contrato sin relanzarla.
- No se deben dejar `COMMIT` o `ROLLBACK` sueltos si no existe una transaccion explicita en T-SQL.
- En funciones escalares de SQL Server, las excepciones Oracle se deben convertir a validaciones y retornos controlados, porque `TRY/CATCH` no es valido dentro de UDFs escalares.
- Si Oracle usa `ROWID` pero la tabla migrada no conserva esa columna, documentar el identificador SQL Server usado como sustituto antes de asumir equivalencia.

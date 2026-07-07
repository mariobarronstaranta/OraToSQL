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
- [INVENTORY.md](INVENTORY.md): inventario inicial de carpetas, objetos y hallazgos.
- [DOCUMENTATION_PLAN.md](DOCUMENTATION_PLAN.md): plan sugerido para ampliar la documentacion.
- [CONVERSION_RULES.md](CONVERSION_RULES.md): reglas y convenciones usadas al convertir Oracle PL/SQL a SQL Server T-SQL.
- [PROMPTS.md](PROMPTS.md): prompts utiles para pedir analisis o conversion asistida por IA.

## Estructura del repositorio

```text
ORA/
  T3/
    EAI/
      Functions/
      Procedures/
      Tables/
    EAI_OWNER/
      Tables/

MSSQL/
  T3/
    EAI/
      Functions/
      Procedures/
      Tablas/
    EAI_OWNER/
      Procedures/

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
- Las tablas se referencian con schema explicito y corchetes, por ejemplo `[EAI].[CFDI_Bitacora]`.
- El logging de procesos usa `[EAI_OWNER].[ProcessID]`, `[EAI_OWNER].[Log_Start]` y `[T3].[RF_PROCESOS_LOG]` cuando el origen Oracle usa `EAI_Owner.ProcessID.NextVal` y `EAI_Owner.Log_Start`.
- El logging de errores usa `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` con `TRY/CATCH` y `THROW`.
- No se deben dejar `COMMIT` o `ROLLBACK` sueltos si no existe una transaccion explicita en T-SQL.

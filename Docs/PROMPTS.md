# Prompts utiles para trabajar con IA

## Analizar un procedimiento

```text
Actua como experto en Oracle PL/SQL y SQL Server T-SQL.

Voy a darte dos archivos: el procedimiento Oracle original y su version SQL Server migrada.

Necesito que generes:
1. Resumen funcional.
2. Parametros de entrada y salida.
3. Tablas leidas.
4. Tablas modificadas.
5. Funciones o procedimientos dependientes.
6. Diferencias Oracle vs SQL Server.
7. Riesgos de conversion.
8. Casos de prueba recomendados.

No inventes reglas de negocio. Si algo no se puede inferir, marcado como pendiente.
```

## Comparar Oracle contra SQL Server

```text
Compara este objeto Oracle contra su equivalente SQL Server.

Indica si la logica fue preservada, si hay cambios de comportamiento y si hay errores probables.

Presta atencion a:
- manejo de NULL
- fechas
- truncados
- commits y rollbacks
- cursores
- conversiones numericas
- funciones Oracle sin equivalente directo
- schemas distintos
- joins y filtros

Devuelve una lista de hallazgos con severidad: alta, media o baja.
```

## Generar ficha documental

```text
Genera una ficha tecnica en Markdown para este objeto.

Usa esta estructura:

# Nombre del objeto

## Resumen
## Archivos
## Entradas
## Salidas
## Tablas leidas
## Tablas modificadas
## Logica de negocio
## Diferencias Oracle vs SQL Server
## Riesgos o pendientes
## Pruebas sugeridas

Se claro y conciso. No inventes informacion que no aparezca en el SQL.
```

## Pedir ayuda para una correccion

```text
Estoy migrando este objeto de Oracle a SQL Server.

Necesito que propongas una correccion minima y segura.

Restricciones:
- No cambies la logica de negocio.
- Mantener nombres de tablas y columnas.
- Usar schema SQL Server esperado: `[EAI]`, `[EAI_OWNER]` o `[T3]`; evitar `dbo` si no esta justificado.
- Usar logging de procesos con `[EAI_OWNER].[ProcessID]`, `[EAI_OWNER].[Log_Start]` y `[T3].[RF_PROCESOS_LOG]` cuando aplique.
- Usar logging de errores con `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]` y `TRY/CATCH`.
- No dejar `COMMIT` o `ROLLBACK` sin `BEGIN TRANSACTION`.
- Explicar cada cambio.
- Marcar cualquier supuesto.
- Proponer una prueba SQL para validar el cambio.
```

## Generar version SQL Server de un procedure

```text
Genera una version compatible con SQL Server del procedimiento Oracle indicado.

Antes de convertir:
1. Lee el archivo Oracle completo.
2. Revisa si ya existe un archivo equivalente en MSSQL.
3. Compara ambos antes de reemplazar.

Reglas de conversion:
- Crear el objeto como `CREATE OR ALTER PROCEDURE [EAI].[NombreObjeto]` si el origen esta en `ORA/T3/EAI/Procedures`.
- Usar nombres calificados con corchetes: `[EAI].[Tabla]`, `[T3].[Tabla]`, `[EAI_OWNER].[Objeto]`.
- Convertir `NVL` a `ISNULL` o `COALESCE`, `DECODE` a `CASE`, `(+)` a `LEFT JOIN`, `SYSDATE` a `GETDATE()` o `SYSDATETIME()`.
- Si el Oracle usa `EAI_Owner.ProcessID.NextVal`, usar `NEXT VALUE FOR [EAI_OWNER].[ProcessID]`.
- Si el Oracle usa `EAI_Owner.Log_Start`, usar `EXEC [EAI_OWNER].[Log_Start] @nProceso`.
- Registrar inicio/fin en `[T3].[RF_PROCESOS_LOG]` si el origen lo hace.
- Registrar errores en `[EAI_OWNER].[MX_EAI_MESSAGE_LOG]`, con `TRY/CATCH` y `THROW`.
- No usar `dbo` salvo que exista una razon documentada.
- No copiar `COMMIT` sueltos de Oracle; usar transaccion explicita solo cuando sea necesaria.
- Preferir operaciones set-based sobre cursores cuando el cursor solo agrupa/actualiza por llave.

Al terminar:
- Ejecuta una revision estatica buscando restos Oracle o patrones riesgosos.
- Indica que no se ejecuto contra SQL Server si no hay conexion disponible.
```

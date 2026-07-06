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
- Explicar cada cambio.
- Marcar cualquier supuesto.
- Proponer una prueba SQL para validar el cambio.
```


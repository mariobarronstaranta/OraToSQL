# PKG_ENCUESTAS_MKT

Conversión del package Oracle `EAI.PKG_ENCUESTAS_MKT` a objetos independientes
de SQL Server. SQL Server no dispone de un objeto `PACKAGE`; el esquema `EAI`
proporciona el espacio de nombres y esta carpeta conserva la agrupación visual.

El `PACKAGE` (specification) recibido está vacío. La implementación se obtuvo de
`ORA/T3/EAI/Packages/PKG_ENCUESTAS_MKT_BODY.SQL` y contiene cuatro miembros:

| Miembro Oracle | Equivalente SQL Server | Función |
|---|---|---|
| `PRC_EJECUTA_PROCESO_ENCUESTAS` | `[EAI].[PRC_EJECUTA_PROCESO_ENCUESTAS]` | Punto de entrada; valida y genera el reporte. |
| `PRC_VALIDA_ENCUESTAS` | `[EAI].[PRC_VALIDA_ENCUESTAS]` | Valida la carga y llena válidas, inválidas, errores y bitácora. |
| `PRC_REPORTE_ENCUESTAS` | `[EAI].[PRC_REPORTE_ENCUESTAS]` | Genera el resumen y lo publica en CEDIS. |
| `FNC_REVISA_CAMPO_VALIDO` | `[EAI].[FNC_REVISA_CAMPO_VALIDO]` | Indica si un campo carece de errores. |

## Orden de despliegue

1. Tablas del esquema `EAI` en `MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql`.
2. `FNC_REVISA_CAMPO_VALIDO.SQL`.
3. `PRC_VALIDA_ENCUESTAS.SQL`.
4. `PRC_REPORTE_ENCUESTAS.SQL`.
5. `PRC_EJECUTA_PROCESO_ENCUESTAS.SQL`.
6. Configuración DBA del destino CEDIS, usando como referencia
   `CONFIGURACION_CEDIS_TEMPLATE.SQL`.

Ejemplo de ejecución:

```sql
EXEC [EAI].[PRC_EJECUTA_PROCESO_ENCUESTAS];
```

## Sustitución de `@V3CEDIS`

Oracle publica por medio del database link `@V3CEDIS`. En SQL Server se requiere
un linked server y un sinónimo llamado
`[CEDIS].[ENCUESTAS_CLIENTES_RESUMEN]`. Los nombres reales de servidor y base no
se encontraban en el repositorio, por lo que la plantilla no los inventa.

`PRC_REPORTE_ENCUESTAS` compila sin esa dependencia porque la sentencia remota
es dinámica, pero genera el error 50020 al ejecutarse si el sinónimo no existe.
La publicación conserva la secuencia Oracle: elimina el resumen remoto y después
inserta el resumen local, agregando las columnas `VALIDA` y `SUPERVISOR`.

## Decisiones de conversión

- `BULK COLLECT` y `FORALL` se sustituyeron con tablas temporales y operaciones
  set-based.
- `NVL`, `DECODE`, `TO_NUMBER` y `SYSDATE` se homologaron con `COALESCE`, `CASE`,
  `TRY_CONVERT` y `SYSDATETIME`.
- `DBMS_OUTPUT` se sustituyó por `THROW`, para que SQL Server Agent detecte el
  fallo en lugar de terminar el paso como exitoso.
- La carga se procesa completa, igual que el cursor Oracle; no se añadió un
  filtro por `PROCESADO`.
- El body Oracle agrupa por `ROWID` al actualizar el estatus, lo que en la
  práctica marca todas las encuestas válidas. El homólogo conserva ese resultado.
- Se aplicaron las reglas de rango aparentemente pretendidas para `SEMANA`
  (1–53) y `CONSECUTIVO` INEGI (1–99). Oracle usa condiciones imposibles con
  `AND`; estos dos puntos deben confirmarse con el dueño funcional.
- `FECHA_FIN` se valida directamente. El body Oracle revisa por error
  `FECHA_INICIO` en ese bloque.
- `VENTA_SEM_OTRASMARCAS` se convierte desde su propia columna. Oracle asigna
  accidentalmente `VENTA_SEM_OTRASPMI` a esa variable.
- `CUANTO_VENDE` permanece `NULL` en válidas e inválidas porque el body Oracle
  nunca asigna su variable convertida.

## Riesgo de identidad de la carga

Oracle actualiza `ENCUESTAS_CLIENTES_CARGADAS` mediante `ROWID`. La tabla SQL
Server recibida no tiene PK ni una llave técnica. La conversión usa
`IDENCUESTADO` para marcar `PROCESADO=1`; por ello se requiere que ese valor sea
único dentro de una carga. Si los duplicados son válidos para negocio, antes de
producción debe agregarse una llave técnica (`ROW_ID` con secuencia o `IDENTITY`)
y cambiar el `UPDATE` para utilizarla.

## Permisos

El código Oracle recibido no contiene sentencias `GRANT` y su specification está
vacía. Por esa razón no se generó un `GRANTS.SQL` con permisos supuestos. El DBA
debe otorgar `EXECUTE` sobre los tres procedimientos y `SELECT/REFERENCES` sobre
la función a los roles reales del ambiente.

## Pruebas mínimas

1. Carga válida de fuente `INEGI` con coincidencia exacta en el catálogo.
2. Carga válida de fuente `BARRIDO`, incluyendo consecutivo 0 y coordenadas.
3. Un valor no numérico por cada campo numérico.
4. Fuente, día, exhibidor y respuestas fuera de catálogo.
5. INEGI sin coincidencia y verificación del error `NO_EN_INEGI`.
6. Verificación de conteos y estatus 1/2/3/4 en la bitácora.
7. Ausencia del sinónimo CEDIS (error 50020) y publicación con el sinónimo listo.
8. Duplicados de `IDENCUESTADO`, para resolver el riesgo de llave antes de liberar.

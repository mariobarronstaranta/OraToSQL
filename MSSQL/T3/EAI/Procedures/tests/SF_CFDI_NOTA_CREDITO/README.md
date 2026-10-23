# Validacion de transacciones de SF_CFDI_NOTA_CREDITO

Actualizacion 2026-10-08: ademas de las pruebas transaccionales, Run.ps1 ejecuta
OracleRules.sql con 17 comprobaciones de reglas Oracle. Se corrigieron notas
sin cobranza, contador de filas recorridas y cadenas vacias. Detalle completo
en [revision Oracle](../../SF_CFDI_NOTA_CREDITO.MD).

La correccion conserva los filtros y calculos; elimina confirmaciones intermedias y confirma la reconstruccion, aplicaciones y auditoria juntas. El script principal usa CREATE OR ALTER para actualizar el objeto existente.

En ejecucion independiente, el procedimiento abre una transaccion, la confirma al terminar y la revierte ante error. Despues del rollback intenta registrar el error y relanza la excepcion original, incluso si la bitacora falla.

Si existe una transaccion externa, utiliza un savepoint y no confirma el trabajo del llamador. Si la transaccion queda condenada, el llamador debe revertirla: no se puede escribir el log dentro de ella. Si sigue siendo confirmable, se revierte al savepoint y el registro del error depende de la transaccion externa.

Ejecutar Run.ps1 desde un entorno de desarrollo con sqlcmd y SQL Server LocalDB. Es un arnes de pruebas, no un cambio a los procesos operativos BAT. Crea una base temporal de nombre aleatorio y la elimina al terminar. Schema.sql contiene dependencias minimas simuladas, incluida LOG_START; no debe ejecutarse en T3QA.

Casos validados:

- Etapas 0, 10, 20 y NULL; resultados de factura/preventa y aplicaciones.
- Cierre de auditoria sin transacciones abiertas.
- Fallo en aplicaciones despues de borrar y recargar: reporte anterior restaurado y error persistente.
- Fallo de escritura en bitacora: conserva la excepcion funcional original.
- Exito bajo transaccion externa: el llamador puede revertir los cambios.
- Fallo bajo transaccion externa condenada: error propagado y rollback del llamador.

La validacion es local con datos ficticios. No despliega el procedimiento ni modifica T3QA.

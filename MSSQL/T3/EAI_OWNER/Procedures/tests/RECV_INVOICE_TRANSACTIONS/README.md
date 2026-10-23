# Transacciones de RECV_INVOICE

Ejecutar `./Run.ps1` en PowerShell con SQL Server LocalDB y sqlcmd disponibles.
El script crea una base temporal con nombre unico y la elimina al terminar.
No modifica bases de negocio.

Se compilan y ejecutan RECV_INVOICE y SF_PROC_PREINVOICE_IFC desde sus archivos
reales. Se usan las tablas del DDL del repositorio, un catalogo de prueba y una
funcion simulada de clasificacion. Los errores se inyectan mediante una
restriccion CHECK y un trigger de prueba. QUOTED_IDENTIFIER esta habilitado
para las operaciones XML.

Casos verificados:

- Exito sin transaccion externa: contador final cero.
- Exito con contador inicial dos: se conserva y el llamador puede revertir todo.
- Error 547 con transaccion externa: rollback al savepoint, contador uno,
  transaccion valida y cambios previos conservados; se propaga el error original.
- Error 547 sin transaccion externa: rollback propio y registro del error.
- Error 51091 que invalida una transaccion externa: contador uno, XACT_STATE=-1,
  error original propagado sin intentar INSERT al log; el llamador revierte.
- Error 51091 sin transaccion externa: rollback propio y registro del error.

Alcance: control de transacciones de ambos procedimientos, no el procesamiento
completo de facturas ni sus procedimientos de negocio posteriores. Las
advertencias de dependencias ausentes al crear el procedimiento son esperadas:
estas pruebas no recorren DEBITNOTE_TO_IFC, INVOICE_TO_PREVENTA o INVOICE_TO_FACTURA.

Para aplicar la correccion, ejecutar los scripts de SF_PROC_PREINVOICE_IFC y
RECV_INVOICE en la base destino con QUOTED_IDENTIFIER ON y ANSI_NULLS ON.
Con transaccion externa, el llamador debe atender la excepcion y decidir el
rollback; si XACT_STATE()=-1, debe revertir la transaccion completa. Los cambios
y registros de log de una transaccion externa no son persistentes hasta que
el llamador confirma la transaccion.

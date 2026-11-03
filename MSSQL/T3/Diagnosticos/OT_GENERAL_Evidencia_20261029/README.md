# Consulta de evidencia diaria de PROC_T3_OT_GENERAL

Ejecutar `01_CONSULTAR_MOVIMIENTOS_HOY.sql` completo en T3QA. No ejecuta
procedimientos ni modifica tablas permanentes. Por defecto usa el dia local
de SQL Server; para revisar el 29 de octubre cambiar la declaracion a:

```sql
DECLARE @Fecha date='20261029';
```

Puede usarse tanto con la version alineada con Oracle como con la version
con controles. No presupone cual fue instalada. Muestra:

- Resumen de facturas con marca, liberacion o errores del periodo.
- Cabeceras actuales con las fechas y datos de negocio.
- Documentos relacionados, incluidos historicos, indicando si su fecha de
  liberacion cae dentro del periodo. No atribuye todos sus cambios al SP.
- Layouts actuales relacionados: bytes y vista previa; activar
  `@VerLayoutCompleto=1` para incluir Informacion completa.
- Errores RF y mensajes del helper, mapeo SAT y padre intercompany.
- Catalogo SAT con Fecha_Creacion en periodo, relacionado por material.
- Estado actual del metodo de pago R900 y de los apartados 2999-12-31,
  presentados como contexto sin fecha de cambio demostrable.

No hay identificador propio de ejecucion en este coordinador. Marcar
Fecha_Proc_BATMD no demuestra que el generador tuviera exito: Oracle y la
alternativa alineada permiten el marcado tras un error absorbido por el hijo.
Fecha_Liberacion indica la fecha almacenada; cargas historicas pueden conservarla.
CFDI_DOCUMENTOS_ENVIAR no tiene fecha ni PID; no puede atribuirse un layout
a hoy solo porque la cabecera se haya marcado hoy. Layouts consumidos o
eliminados ya no aparecen en su estado actual.

Sin auditoria previa tampoco puede recuperarse el valor anterior de
MetodoPago, fechas sobreescritas o cambios hechos hoy que no dejaron una
marca temporal consultable. Esta consulta es evidencia por fecha/referencia,
no una reconstruccion exacta de todos los INSERT/UPDATE por ejecucion.

Los distintos resultados se leen secuencialmente con el aislamiento de la
sesion; si hay procesos trabajando durante la consulta, pueden observarse
estados de momentos distintos. No utiliza NOLOCK ni cambia el aislamiento.

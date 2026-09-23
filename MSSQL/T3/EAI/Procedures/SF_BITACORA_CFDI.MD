# EAI.SF_BITACORA_CFDI_OPTIMIZADO

## Objetivo

La versión optimizada reconstruye y enriquece `EAI.CFDI_BITACORA`, conservando el procedimiento original para comparación y rollback.

Archivo: `SF_BITACORA_CFDI_OPTIMIZADO.SQL`.

## Optimizaciones principales

- Eliminación de auto-joins a `CFDI_BITACORA`: las etapas actualizan directamente por `Doc_Num`.
- Bonificaciones agregadas una sola vez; el original consultaba `Registro_Fiscal_Detalle` en una subconsulta correlacionada y nuevamente en `EXISTS`.
- Volumen calculado por factura y con `EXISTS` sobre `Registro_Fiscal`, evitando multiplicar detalle por cabeceras duplicadas.
- Importe de descuentos agregado una vez por `ReferenceID` y aplicado en bloque.
- Actualizaciones set-based para método de pago y facturación central.
- PID generado con `EAI_OWNER.ProcessID`, eliminando la condición de carrera de `MAX(PID)+1`.

## Correcciones de migración y reglas Oracle restauradas

Durante la comparación con `ORA/T3/EAI/Procedures/SF_BITACORA_CFDI.SQL` se encontraron diferencias que no eran optimizaciones, sino omisiones funcionales de la versión MSSQL original:

1. `ScrPrompt` usa `ROWID`, columna que no existe en `EAI.CFDI_BITACORA`; las demás etapas usan `ROW_ID`, pero la carga inicial tampoco lo asigna. La nueva versión usa `Doc_Num`.
2. Se restauró `EAI_OWNER.Log_Start` y la inserción inicial en `T3.RF_PROCESOS_LOG`.
3. La ventana inicial vuelve a incluir un mes anterior a `FC__TIME_WINDOW.Start_Date`.
4. Las preventas canceladas se conservan con factor cero, como Oracle, en lugar de eliminarse.
5. El importe SAP vuelve a aplicar `GETCONV('FolioDuplicado', Doc_Num)`.
6. Los descuentos vuelven a requerir `tmp_Document_Header.DeliveryType = 'C025'`.
   La conversión de centavos usa un divisor decimal explícito (`-100.0`),
   evitando que SQL Server reduzca el factor mediante división entera y
   produzca incorrectamente un importe igual a cero.
7. Se restauró la etapa `MetodoPago`, incluyendo valores agrupados `PUE`/`99` y lectura de CFDI 4.0 desde `RF_Documentos.Anexo_CFD`.
8. Se restauró `ScrFactCentral`: `SF_Amount` y `Origen='SAP'` para clientes centrales, además de `CFDI_INFORME.Origen`.
9. La actualización final de `CONTROL_REPORTE` quedó correctamente calificada como `EAI.CONTROL_REPORTE`.

Estas correcciones pueden producir filas o valores distintos a la versión MSSQL original porque recuperan reglas presentes en Oracle. Deben validarse funcionalmente antes de cambiar el job.

## Flujo por etapas

- `0`: reconstrucción desde `Factura_General` y `Preventa_General`.
- `10`: centro y territorio de facturas inmediatas.
- `20`: territorio de preventas.
- `30`: datos del CFDI individual.
- `40`: datos del CFDI agrupado.
- `80`: volumen de primera y segunda categoría.
- `90`: importe SAP y descuento C025.
- `100`: método y forma de pago.
- Final: RFC, BackOffice, facturación central y cierre de auditoría.

Si se recibe `@nEtapa = NULL` o un valor mayor a `100`, las condiciones de las
etapas numeradas no se cumplen y solamente se ejecuta el bloque final. Este es
el mismo comportamiento del procedimiento Oracle y del MSSQL original.

## Dependencias

- EAI: `CFDI_BITACORA`, `CFDI_INFORME`, `CONTROL_REPORTE`, `FC__TIME_WINDOW` y `T3R_Sales_Docs_Old`.
- EAI_OWNER: `ProcessID`, `Log_Start`, `GETCONV`, `MX_COMPONENTS`, `MX_EAI_MESSAGE_LOG`, `tmp_Document_Header`, `tmp_Document_Detail`, `TAO_Cedis_Valid` y `WA_VENTA_CENTRALIZADA`.
- T3: `Factura_General`, `Factura_Detalle`, `Preventa_General`, `Preventa_Detalle`, `Entrega`, `Registro_Fiscal`, `Registro_Fiscal_Detalle`, `Material`, `CFDI_Documentos`, `CFDI_Historia_Docto_PAC`, `CFDI_Agrupado`, `Cliente`, `RF_Documentos` y `RF_PROCESOS_LOG`.

## Caller identificado

El job `ORA_568_EAI_SF_BITACORA_CFDI` ejecuta actualmente:

```sql
EXEC [EAI].[SF_BITACORA_CFDI] 0;
```

El job no se modifica automáticamente. Debe apuntarse a `_OPTIMIZADO` solamente después de la aceptación en QA.

## Validación mínima requerida

1. Factura C003 y devolución inmediata.
2. Preventa C005, C006 y C025, incluida una cancelada.
3. Documento individual y agrupado.
4. Material de primera y segunda categoría.
5. Refoleo mediante `FolioDuplicado`.
6. Descuento con y sin cabecera C025.
7. XML CFDI 4.0 y documento agrupado.
8. Cliente BackOffice y cliente central.
9. Ejecuciones desde etapas 0, 80, 90, 100 y superior a 100.
10. Error controlado para comprobar bitácora y estado del job.

## Validación técnica realizada

La versión fue compilada y ejecutada en una base SQL Server LocalDB temporal
con cinco documentos representativos. Se comprobaron los siguientes casos:

- salida común equivalente al procedimiento MSSQL original para factura,
  devolución y preventa no cancelada;
- preventa cancelada conservada con importes en cero;
- CFDI individual y agrupado;
- cálculo de primera y segunda categoría;
- descuento C025 convertido de centavos con resultado negativo;
- lectura de `MetodoPago` y `FormaPago` desde XML CFDI 4.0;
- valores predeterminados `PUE` y `99` para CFDI agrupado;
- actualización de venta central, `CFDI_INFORME`, RFC y BackOffice;
- apertura y cierre de `RF_PROCESOS_LOG`;
- ejecución con `@nEtapa = NULL`, limitada al bloque final.

Todas estas verificaciones finalizaron correctamente. La prueba temporal es
funcional y de compilación; sus cinco filas no permiten concluir una mejora de
tiempo. El rendimiento debe medirse en QA con volumen representativo, caché
caliente, `SET STATISTICS IO, TIME ON` y el plan de ejecución real de ambas
versiones.

# Revisión y corrección de JOIN frente a Oracle

Se revisaron las consultas de `PROC_V40_GENERAR_MX06AD_CORREGIDO` contra el archivo Oracle homónimo. Se encontró una diferencia en el tipo de relación: **ScrDatos / CFDI_USOCFDI_CLIENTE UsoC**. Se corrigió INNER JOIN por LEFT JOIN, manteniendo `RF.Cliente_SAP = UsoC.Cliente_SAP`.

Oracle expresa esta relación opcional en la línea 425: `RF.Cliente_SAP = UsoC.Cliente_SAP(+)`. El cliente puede no tener configuración y la factura debe conservarse. En ese caso las columnas de UsoC son NULL y las expresiones ISNULL existentes aplican sus alternativas. Se agregó esta explicación junto al JOIN en el SQL.

## Relaciones verificadas

| Consulta | Relaciones Oracle y equivalencia MSSQL | Resultado |
|---|---|---|
| Búsqueda inicial de cliente | RF–Cliente por Cliente_SAP, con factura y vigencia | INNER conservado; TOP 1 sigue siendo una diferencia de cardinalidad fuera de este cambio. |
| ScrDatos / agregado CFD | RFD–RF por Factura; Tax opcional por Material | INNER RF y LEFT Tax conservados. CFD agregado se une con ON 1=1 como el cruce original. |
| ScrDatos / subconsulta Cte | Mov_Cliente con TMD_Email, UsoC y configuraciones de régimen/versión/uso/CP/nombre opcionales | Los siete LEFT JOIN coinciden con los `(+)` de Oracle; se conservan sus claves y filtros. |
| ScrDatos / cabecera | RF–Comp por Factura; Comp–Soc por Sociedad/BUKRS y KUNNR; RF–TD por Tipo_Docto; RF–DF por Ctro; RF–Alm por centro transformado | Relaciones obligatorias conservadas. Cte se selecciona por @sAccnt_ID, como en Oracle; no se agregó una condición nueva RF.Cliente_SAP=Cte.Ou_Num. |
| ScrDatos / UsoC exterior | RF.Cliente_SAP=UsoC.Cliente_SAP(+) | **Corregido a LEFT JOIN.** No hay un filtro WHERE sobre UsoC que vuelva obligatoria esta relación. |
| ScrDetalle | RF–RFD por Factura; RFD–Material por Material; UsoC opcional por Cliente_SAP | Dos INNER y LEFT UsoC conservados. |
| ScrItemAddenda | RF–RFD por Factura; RFD–Material por Material, filtro de artículo | INNER y condiciones conservados. |
| ScrHeadAddenda | Cliente–Email opcional; Cliente–Addenda por RFC; RF filtrada por factura; RF–Comp por Factura; CFD opcional por RF.Factura=CFD.Var_1; vigencia del cliente | LEFT Email/CFD, INNER obligatorios y filtros conservados. No se inventó una unión adicional Cliente–RF por Cliente_SAP que Oracle no contiene. |
| ScrAllocation | Cobza–CFD y Cobza–WA opcionales por Nota_Venta | Ambos LEFT JOIN conservados. No se eliminó uno ni se deduplicaron resultados: Oracle tiene las dos relaciones. |
| ScrPedimento, ScrReenvio, ScrTextoAdicional y consultas de catálogo/historia | Consultas de una tabla, sin relaciones adicionales entre tablas | No requieren cambio de JOIN. |

Se revisaron tipos de relación, claves y ubicación de filtros. Esto no certifica equivalencia ante cadenas vacías, collation, datos duplicados o diferencias de tipos: esos puntos permanecen documentados en las otras revisiones.

## Decisión sobre transacciones

Por instrucción del usuario, **MSSQL no administra transacciones propias**. No se agregaron BEGIN TRANSACTION, COMMIT ni ROLLBACK. La diferencia con Oracle se acepta como decisión de diseño y deja de ser una omisión pendiente. Si el llamador utiliza una transacción, el SP no la administra; si se ejecuta con autocommit, una escritura anterior puede persistir ante un fallo posterior.

## Validación

`tests/PROC_V40_GENERAR_MX06AD/Run.ps1` terminó correctamente en LocalDB:

- PARSEONLY de la definición completa, sin despliegue.
- Conservación de asignaciones numéricas y listas FETCH; pruebas anteriores de concatenación/cursores.
- Prueba del JOIN extraído del propio ScrDatos, sustituyendo únicamente la tabla por una variable de tabla: conserva factura sin configuración, respeta la configuración coincidente, no enlaza otro cliente, conserva la fila izquierda con clave NULL y mantiene dos resultados cuando existen dos coincidencias, como el JOIN Oracle.

No se ejecutó el procedimiento con facturas reales ni se modificó su homólogo original. El único cambio ejecutable de esta revisión es INNER → LEFT en el enlace exterior UsoC. Los pendientes de A_HEADER, fechas, textos y tipos numéricos no se modificaron.

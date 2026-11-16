# Comentarios de desarrollador: T3.PROC_V40_GENERAR_MX06AD

**Actualización de CORREGIDO:** el JOIN exterior de UsoC ya se ajustó a LEFT JOIN como Oracle. MSSQL no administrará transacciones propias por instrucción del usuario; no se debe agregar COMMIT/ROLLBACK para cerrar los hallazgos históricos. Detalle en [JOINS.md](PROC_V40_GENERAR_MX06AD.JOINS.md).

**Rectificación comprobada en LocalDB (implementación de etapa 1):** la conclusión inicial sobre DECLARE/OPEN era incorrecta. Un cursor LOCAL FORWARD_ONLY STATIC declarado con una variable NULL conservó ese valor tanto en una expresión SELECT como en un filtro, aunque se asignara antes del OPEN; reabrirlo tampoco actualizó el filtro. La versión `PROC_V40_GENERAR_MX06AD_CORREGIDO.sql` declara los cursores después de asignar sus variables y los libera/recrea por uso. Ver pruebas y [cambios de etapa 1](PROC_V40_GENERAR_MX06AD.CAMBIOS.md).

**Ampliación:** se agregó la [comparación con Oracle](PROC_V40_GENERAR_MX06AD.COMPARACION_ORACLE.md). Distingue problemas heredados de regresiones de migración y documenta diferencias adicionales en JOIN, cardinalidad, formatos numéricos, fechas y transacciones. La anulación de cadenas por NULL es una regresión de la traducción de `||` a `+`; las asignaciones tardías de orden de compra y la rama de diagnóstico sin construir sData ya existían en Oracle.

Fecha: 2026-11-09. Revisión estática del archivo local y DDL en `../Tables/`. El SQL ya tenía cambios locales; se conservan y únicamente se agregan comentarios `DEV-REV`. No se ejecutó ni desplegó el procedimiento. Los tipos documentados son los del repositorio, pendientes de corroborar contra `sys.columns` en la instancia destino. No se presupone que T3QA esté sincronizada con estos archivos.

Las líneas citadas abajo corresponden a la versión recibida, ANTES de insertar los comentarios; los identificadores DEV-REV permiten localizar los puntos en el SQL actualizado.

## 1. Cursores, inicialización y orden de ejecución

**C05 — Crítico, confirmado: @sPedimentos anula las líneas con addenda.** Se declara sin valor (91), se inicializa exclusivamente dentro de `IF @sAddenda != 'SI'` (762–779) y se concatena incondicionalmente (820). En la primera cabecera con addenda SI permanece NULL: `@uLINFAC + @sPedimentos + @sSepCampo` produce NULL. La validación final `LEN(@uLINFAC)>10` no será verdadera. Inicializar `@sPedimentos = ''` al inicio de CADA artículo, antes del IF, y tratar NULL como vacío al serializar. Esto es independiente de que existan pedimentos.

**C02 — Alta, confirmado: orden de compra calculada demasiado tarde.** `ScrItemAddenda` selecciona `@sOrdenCompra AS NOrdenC` (422); se abre en 826 y concatena `@Reg_NOrdenC` en 840. La primera asignación de la orden está en 1455, dentro de `ScrHeadAddenda`, abierto en 1364, después del detalle. Además, 1456 borra inmediatamente el valor tomado de `@Inf_Pedido`. Resolver la cabecera de addenda antes del detalle y definir si la regla requiere pedido o vacío. Mover únicamente el DECLARE no arregla el problema. Aun corrigiendo C05, C02 puede anular el mismo acumulador.

**C01 — Rectificado mediante ejecución: declarar después de asignar filtros.** Los ocho cursores son LOCAL FORWARD_ONLY STATIC. Aunque OPEN materializa el conjunto, la prueba LocalDB demostró que esto no implica tomar el valor actualizado de las variables. Declarar con NULL y asignar después produjo un SELECT escalar NULL y un filtro sin filas; reabrir conservó el filtro anterior. La corrección mueve DECLARE junto a cada OPEN, después de asignar las dependencias, y agrega DEALLOCATE al cerrar para recrear el cursor en la siguiente iteración. Las observaciones de la tabla siguiente sobre asignación antes de OPEN describen el código original y no son garantía de corrección.

| Cursor | Dependencias y revisión |
|---|---|
| ScrDatos | `@pFactura`, `@sAccnt_ID`; la cuenta se resuelve en 493–504 antes de OPEN 538. Si SELECT TOP 1 no obtiene fila, la cuenta sigue NULL. No tiene ORDER BY ni validación de ausencia/ambigüedad. |
| ScrDetalle | Usa `@pFactura`; se abre por cabecera. Sus cálculos pueden fallar al materializar por divisiones entre cero o conversiones STR. |
| ScrHeadAddenda | `@sFactura`, `@sAccnt_ID` están asignadas antes del OPEN; su posición tardía afecta a la orden de compra del detalle. |
| ScrItemAddenda | `@sFactura` y `@nNumLinea` se asignan antes del OPEN; `@sOrdenCompra` no. |
| ScrPedimento | `@sMaterial` se asigna en 748 y `@dtFecha_Factura` en 552 antes de abrirlo; se cierra antes de reabrirse. Verificar que SKU transformado coincida con SAT.Material. |
| ScrReenvio | `@sFactura` asignada en 543, OPEN 590. |
| ScrTextoAdicional | OPEN después de terminar ScrDatos: depende de que exista cabecera y usa la última factura procesada. |
| ScrAllocation | Filtra por `@pFactura`; se abre dentro de nota de crédito. |

Los bucles inspeccionados realizan un FETCH del cursor correspondiente antes de volver a evaluar su WHILE. No se identificó una salida prematura causada directamente por el estado del cursor hijo. `@@FETCH_STATUS` es compartido por la conexión: conservar ese orden si se refactoriza. Los cierres, DEALLOCATE y limpieza en CATCH están presentes.

**C03 — Alta: agregados y ausencia de datos.** `MAX(ISNULL(Porc_IVA,0))` (555) devuelve NULL si no existe fila. Validar catálogo; solo si está permitido un valor por defecto, aplicarlo al resultado: `ISNULL(MAX(Porc_IVA),0)`. En CFD (234–242), SUM también puede devolver NULL sin detalles; algunos CASE incluyen `RFD.Valor_Subt` sin normalizar. Un NULL numérico no se resuelve reemplazando concatenaciones.

**C04 — Baja, confirmado:** `@nTimbrados` nunca se inicializa y `NULL+1` continúa NULL (635). Inicializar a cero antes de ScrAllocation, o retirar el contador si no tiene uso. Actualmente no interviene en el resultado.

**Cardinalidad — Alta, riesgo dependiente de datos.** ScrDatos no exige exactamente una fila. Los JOIN pueden eliminar la cabecera o multiplicarla. Los acumuladores generales y el indicador de addenda se inicializan una vez, mientras otros se reinician por cabecera: varias filas mezclan totales/segmentos. Validar una cabecera y unicidad de las relaciones; no ocultar duplicados con DISTINCT sin explicar su origen. Con cero filas quedan variables NULL y el proceso llega a su rama de error sin diagnóstico específico.

## 2. Concatenación: NULL debe representar un campo vacío

**S01/S02 — Alta:** inicializar el acumulador con `''` no basta. Un único operando NULL en una concatenación con `+` anula todo lo construido. Hay riesgo en `@uHEADER`, `@uLINFAC`, `@uIMPFAC`, `@uCABADD`, `@sCABCLIE`, `@sCFDIREL`, `@sREL_Facturas`, `@sPedimentos` y el ensamble `@sData`.

Ejemplos concretos: C05/C02; `@Env_Folio_Fiscal` (596), `@CMA_Doc_Num`/fecha/importe (648), datos opcionales de PARTIES (1293–1358), campos de addenda obtenidos por LEFT JOIN, `@Doc_eMail` (1561), `@Info_Texto` (1682) y configuración devuelta por getConv. También revisar concatenaciones dentro de las consultas: fecha/hora (151–152, 355), lugar de expedición (294) y códigos postales. Las funciones de limpieza/formato podrían devolver NULL; no se encontraron sus definiciones MSSQL de producción para certificar su contrato.

Usar `CONCAT`, que convierte argumentos NULL en vacío; conservar los separadores como argumentos explícitos y el formato actual de los importes. [CONCAT, Microsoft](https://learn.microsoft.com/en-us/sql/t-sql/functions/concat-transact-sql?view=sql-server-ver15).

```sql
-- Propuesta, no aplicada:
SET @uLINFAC = CONCAT(@uLINFAC, @Reg_NOrdenC, @sSepCampo);
SET @uHEADER = CONCAT(CAST(@uHEADER AS varchar(max)),
                      @Doc_Emisor_Calle, ' ', @Doc_Emisor_NoExterior, @sSepCampo);
SET @uIMPFAC = CONCAT(CAST(@uIMPFAC AS varchar(max)),
                      T3.FN_NUM_TO_CHAR_CFDI(@Doc_importe_IVA, 2), @sSepCampo);
```

No usar `CONCAT(@uLINFAC, @campo + @separador)` porque el `+` interno aún pierde el separador si el campo es NULL. No basta CONCAT en el ensamble final: no recupera segmentos ya anulados. Tampoco usar CONCAT_WS directamente con campos NULL: puede omitir posiciones. Como alternativa puntual, `ISNULL(@campo,'')` con `+`, protegiendo cada operando textual nullable.

Si por «concat_null» se entiende `SET CONCAT_NULL_YIELDS_NULL OFF`, no es la solución: está obsoleto y desde SQL Server 2017 la opción permanece ON. [Documentación oficial](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-concat-null-yields-null-transact-sql?view=sql-server-ver17).

La regla de vacío aplica a la representación textual. No convertir automáticamente importes desconocidos en cero ni aceptar datos obligatorios ausentes: validar esos valores antes de generar el documento.

**S02 — Longitud:** HEADER, IMPFAC, CABADD, CABCLIE y CFDIREL son varchar(4000), Pedimentos varchar(1000). CONCAT no amplía el destino; evaluar varchar(max) de extremo a extremo y límites del receptor. INFORMACION de ambas tablas de envío es varchar(max). Una cadena truncada no se recupera al copiarla a ese destino.

**S03/C06 — Alta, confirmado:** `@sData` se asigna únicamente en la rama exitosa (1691–1694). En el ELSE se inserta NULL en CFDI_DOCUMENTOS_ENVIAR_ADD (1718). Armar la representación de diagnóstico antes del IF. Además, el IF valida longitud del detalle y totales, pero no que HEADER/CABCLIE/IMPFAC existan; podría insertar INFORMACION NULL incluso si el detalle pasa. El DDL de envío permite NULL. El texto de RF_ERROR_LOG (1715) también puede anularse si algún total es NULL: usar CONCAT y, para diagnóstico, distinguir explícitamente NULL de cero.

## 3. Matriz de tipos numéricos

`numeric` y `decimal` son equivalentes. Una precisión mayor con la misma escala no es, por sí sola, una inconsistencia perjudicial. No reducir indiscriminadamente acumuladores para que sean iguales a una sola fila de origen.

| Origen/destino en DDL | Variable o conversión | Evaluación y propuesta |
|---|---|---|
| REGISTRO_FISCAL_DETALLE: PRECIO_UNIT, VALOR_SUBT, VALOR_IVA, BONIF_SUBT, ENVIO_SUBT/IVA, CREDITO_SUBT/IVA, VALOR_IEPS decimal(15,2) | @Item_* y acumuladores numeric(22,2) | Misma escala; ampliación segura para valores directos. Sumas/productos requieren su propio presupuesto de rango. |
| REGISTRO_FISCAL: VALOR_SUBTOTAL, VALOR_IVA decimal(15,2) | STR(...,12,2) en cabecera de addenda | El formato limita el rango antes de emitirlo; mantener decimal hasta serialización. |
| RFD.CANTIDAD_VTA decimal(10,0) | STR(...,9) -> @Item_cantidad varchar(max); @Reg_Cantidad_Vta numeric(22,2) | STR solo admite nueve dígitos positivos; diez dígitos producen asteriscos. @Reg_Cantidad_Vta conserva el valor, aunque no coincide exactamente con el tipo fuente. Preferir decimal(10,0) para cantidad directa y conversión textual explícita. |
| RFD.NUM_LINEA decimal(4,0) | @Reg_NumLin y @nNumLinea numeric(6,0); texto STR(...,9) | Ampliación segura. No es pérdida de decimales. |
| CFDI_COBRANZA.IMPORTE decimal(16,2) | @CMA_Paid_Amt numeric(22,2) -> @nTtl_Assigned numeric(15,2) | **N04: reducción real de rango** en acumulación. Usar acumulador amplio según número de asignaciones; no basta igualarlo a una fila. |
| Total calculado numeric(22,2) | @nTtl_CreditMemo numeric(15,2), @nTotalAmt numeric(15,2) | Reducción de rango en 613/814; unificar con los importes calculados y validar límites. |
| CFDI_LIBERA_NOTA_CREDITO.PENDIENTE decimal(14,2) | Diferencia entre numeric(15,2) | Máximo positivo 999999999999.99. Validar antes de insertar; ampliar variables no amplía tabla. |
| CFDI_AGRUPADO_DIF.AJUSTE decimal(5,2) | @nAjusteIVA_DistFee numeric(22,2) | **N05:** destino admite ±999.99. Definir tratamiento de diferencias fuera de rango; no recortar importe. |
| CONV_LISTA_GRUPO_PRECIO.PORC_IVA decimal(2,0) | @nTasa_LP numeric(3,0) | Ampliación segura, sin pérdida fraccionaria: esta consulta NO lee TASA_IVA decimal(6,2). |
| Tasas calculadas, sin columna directa equivalente | @nTasa_IEPS numeric(3,0), @nEnvio_TASA/@nCredito_TASA numeric(5,2) | ROUND(...,0) elimina fracciones por decisión del cálculo. Confirmar contrato; declarar más escala no recupera lo redondeado. |
| CFDI_TEXTO_ADICIONAL.LINEA decimal(2,0) + 1000 | @Info_Linea int | Cabe en int; no se detecta pérdida. |
| Contadores internos | @nLineas numeric(3,0), @nCFDI_CM numeric(3,0), @nHDP numeric(3,0) | Overflow a 1000. @nCFDI_CM inicia en 500; @nLineas incluye líneas adicionales. Usar int si el formato admite esos valores. |

**N01 — STR es un cuello de botella anterior al FETCH.** STR(x,12,2) permite nueve dígitos enteros positivos y dos decimales; STR(x,10,2), siete. Los negativos requieren espacio para el signo. Un valor decimal(15,2) válido como 1000000000.00 no cabe en STR(...,12,2); los asteriscos fallarán al convertirse a numeric en FETCH. STR(cantidad,9) tampoco cubre decimal(10,0). Sustituir el viaje decimal → texto → decimal por expresiones numéricas, formateando al final con ancho suficiente y sin alterar la escala requerida.

**Tasas:** STR(ROUND(...,2),2) (328) omite el tercer argumento: su salida tiene cero decimales. STR(...,5,2) (325) no cabe para 100.00. No atribuirlo a la declaración numeric(22,2) del receptor. Las divisiones `@nTasa_LP/100` no son división entera porque el numerador es numeric.

**Divisiones por cero:** revisar 320, 325, 328, 441, 737, 933, 948 y 1600. Que IVA o IEPS sea positivo/no negativo no garantiza base distinta de cero. Validar cantidad/base y definir rechazo o tratamiento de negocio; NULLIF evita la excepción pero genera NULL, que no debe ocultarse sin decisión explícita.

**NULL aritmético:** CFDI_COBRANZA.IMPORTE admite NULL; al sumarlo anula @nTtl_Assigned y la condición ABS(diferencia)>5.03 deja de ser verdadera. Validar el importe antes de acumular. SUM(ISNULL(...)) sin filas también puede ser NULL; diagnosticar ausencia de detalle antes de generar la cabecera.

## 4. Observaciones complementarias

- @sLista_Precio se toma del documento y se sobrescribe por '10' (553). Envío/crédito calculan tasa y luego la fuerzan a 16 (1063,1131). Confirmar reglas; afectan conciliación, independientemente del tipo declarado.
- ScrAllocation une CFD y WA a la misma tabla por la misma condición (485–486). Si hay varias filas por Nota_Venta, puede multiplicar asignaciones; validar unicidad e intención de ambos alias.
- @sREL_Facturas se construye, pero no se incorpora a @sData ni @uLINFAC: sus textos no salen. Confirmar si deben incluirse.
- El cursor STATIC conserva la fecha original aunque el procedimiento actualice Registro_Fiscal.Fecha_Factura en 682. Confirmar si la salida debe usar la fecha anterior o la modificada.
- CONVERT(varchar(8),fecha,103) (355,357,450) recorta el año de dd/mm/yyyy. Revisar formato esperado antes de corregir.
- El CATCH registra e imprime, pero no relanza el error. Sin transacción propia, las escrituras previas pueden permanecer si falla el INSERT de AJUSTE; considerar contrato transaccional con el llamador. No se ejecutó el SP para esta revisión.

## 5. Criterios de validación para la corrección posterior

1. Factura con addenda SI, pedido presente/ausente y pedimentos presentes/ausentes: payload no nulo, número de separadores estable y orden correcta.
2. Campos textuales opcionales NULL en cada segmento y Texto adicional NULL: conservar posiciones vacías sin perder segmentos anteriores.
3. Factura sin cliente vigente, sin detalle, sin catálogo de tasa y con JOIN duplicado: diagnóstico explícito antes de enviar.
4. Cantidad 1000000000, importe 1000000000.00, cantidad/base cero y tasas fraccionarias: sin asteriscos ni redondeo accidental; comportamiento de rechazo documentado.
5. Cobranza NULL, monto y suma mayores al rango de numeric(15,2), PENDIENTE fuera de decimal(14,2) y AJUSTE ±1000: detectar antes de escrituras parciales.
6. Más de 999 líneas, segmentos mayores de 4000 caracteres, concatenación total mayor de 8000 y totales no conciliados: comprobar integridad y contenido de diagnóstico.

La revisión entregada no modifica cálculos ni implementa estas correcciones. Verificación realizada: trazabilidad de asignaciones/OPEN/FETCH, contraste con DDL y preservación del texto previo al insertar comentarios, conservando UTF-16 LE del SQL. No se afirma compilación ni prueba funcional contra la base destino.

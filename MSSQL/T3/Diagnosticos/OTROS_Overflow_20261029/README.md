# Desbordamiento numeric a varchar en PROC_V40_GENERAR_OTROS

Referencias reportadas: 1658507150, 1658507151, 1658516300, 1658516520,
1658520040 y 1658520050. Fecha/hora del error: 29/10/2026 14:50:26-27.

## Hallazgo reproducido y alcance de la conclusion

El cursor ScrDatos calcula la tasa con ROUND y CAST AS VARCHAR(10).
ROUND conserva la escala de su expresion decimal; no la transforma en entero.
Con el mismo tipado del DDL y SUM de retenciones, una factura de subtotal 100,
IVA 16 y retencion cero produce DECIMAL(38,12) y el texto 16.000000000000.
No cabe en diez caracteres y reproduce el error 8115 al ejecutar el CAST.

Es un defecto confirmado del codigo con valores ficticios representativos.
La consulta 01 verifica si es el punto que falla en las seis facturas reales.
Las funciones instaladas, especialmente FN_NUM_TO_CHAR_CFDI, tambien pueden
contener conversiones propias; no se debe declarar resueltos todos los errores
de esas facturas hasta revisar las consultas y la prueba controlada.

## Correccion preparada

El resultado real del script 01 (29/10/2026 15:05:37) confirmo las seis tasas
en DECIMAL(38,12): TextoAmplio=0.000000000000, 14 caracteres, ConversionActual
NULL y conversion corregida valida. Las seis cabeceras estan marcadas con
Fecha_Proc_BATMD a las 14:50:26-27 y cada una tiene un documento, cero layouts.
Esto confirma el defecto de longitud y exige revisar el documento preexistente.
Ejecutar 01B_REVISAR_DOCUMENTOS_EXISTENTES.sql antes de cualquier reproceso.
El 01B del 29/10/2026 15:10:14 confirmo que las SEIS facturas tienen documentos
CONFIRMADO, UUID y fechas de envio/timbrado del 16 al 20 de octubre. No son
facturas nuevas por generar. Ausencia de layout en la tabla de envio no
demuestra que el comprobante no exista ni autoriza regenerarlo.
No borrar documentos, crear layouts nuevos ni desmarcar cabeceras de estas seis.
Se reforzo 03 para omitir cualquier referencia con evidencia de envio/timbrado
o estado final aun si no tiene layout; sus valores predeterminados siguen
siendo de vista previa. No es necesario ejecutarlo para recuperar estas seis.

Dos expresiones del modulo:

1. VARCHAR(10) pasa a VARCHAR(40) para admitir el texto decimal calculado.
   Con precision 38, el espacio permite digitos, signo y separador decimal.
2. @Doc_tasa se convierte explicitamente a DECIMAL(38,12) y se divide entre
   100.0 antes de enviarla al formateador con seis decimales. Evita una nueva
   conversion implicita a INT/division entera del texto: 16% debe producir 0.16.

No se cambia la regla ROUND(tasa,0), la tolerancia de totales ni el layout.
El archivo local del generador contiene ya esas correcciones; no se desplego
en T3QA. El script 02 aplica exclusivamente las dos expresiones a la definicion
INSTALADA y guarda una copia completa para reversion.

## Orden para T3QA

1. Ejecutar `01_DIAGNOSTICAR.sql`. Revisar ConversionActual NULL frente al texto
   amplio y ConversionCorregida, estado de las cabeceras y salidas existentes.
   Si TextoAmplio es NULL por denominador cero, no atribuir ese caso a longitud.
   Si el diagnostico tambien falla, conservar error y definicion de la funcion.
2. Ejecutar `02_CORREGIR_MODULO.sql` con @Aplicar=0. Debe confirmar patrones
   validados. No altera el procedimiento ni crea respaldo en ese modo.
3. Si el diagnostico coincide, cambiar @Aplicar=1 y ejecutar completo. Se
   respalda el modulo en dbo.REPAIR_OTROS_8115_20261029, se altera y verifica
   dentro de una transaccion. Si no encuentra exactamente los patrones, se
   detiene; no aplicar reemplazos aproximados. Conserva otras modificaciones
   instaladas y exige ANSI_NULLS/QUOTED_IDENTIFIER persistidos en ON.
4. Con el resultado real del 01B, cerrar la recuperacion de estas seis SIN
   regeneracion. El script 03 queda disponible como vista previa/omision
   explicita; no se necesita poner @Ejecutar=1 para estas seis.
   El estado predeterminado NO reprocesa facturas.
5. La opcion @Ejecutar=1 del script 03 estaba prevista solo para referencias
   nuevas sin salidas anteriores, luego de revisar diagnostico/parche/vista
   previa. El 01B descarta esa situacion para estas seis. El script no llama
   PROC_T3_OT_GENERAL ni pone fechas de proceso en NULL para forzar seleccion.

El padre puede haber marcado Fecha_Proc_BATMD despues de retornar el generador,
porque su CATCH no relanza el error. Esa marca por si sola no demuestra salida.
No volver a ejecutar el padre para recuperar estas facturas: puede procesar
otras y no volver a seleccionar las que ya marco.

El reproceso controlado:

- Omite primero cualquier referencia con UUID, evidencia de envio/timbrado o
  estado final, aunque falte layout. Tambien omite referencias con exactamente
  un documento y un layout; no los borra ni reemplaza. La omision preserva
  los registros existentes y no es una nueva certificacion fiscal.
- Rechaza salidas parciales/duplicadas y cabeceras ausentes o multiplicadas.
- Ejecuta las nuevas generaciones en una transaccion para las seis facturas.
- Detecta nuevos errores RF_ERROR_LOG y errores del helper de mapeo SAT en
  MX_EAI_MESSAGE_LOG, aunque los hijos los absorban.
- Exige ambas salidas; si algo falla, revierte todas las nuevas salidas y
  mapeos creados por los hijos. Los errores insertados dentro de la transaccion
  tambien se revierten: conservar Mensajes y el error devuelto por el wrapper.
- No cambia las marcas existentes de OTROS_GENERAL ni confirma timbrado/PAC.

`04_REVERTIR_MODULO.sql`, con @Revertir=1, restaura solo la definicion anterior
si nadie cambio el modulo despues del parche. No elimina documentos/layouts
que ya se hubieran generado ni revierte datos de negocio.

## Pruebas

Se reprodujo el 8115 con tasa 16 y tipos del DDL en una base temporal de LocalDB.
Un procedimiento ficticio y un formateador minimo permitieron verificar el
ensayo, aplicacion exacta, resultado 0.16, rechazo de reaplicacion, valores con
signo/cero/NULL y reversion a la definicion que reproducia el error.
Evidencia: tmp/CodexOT8115_c1139fa1/RESULTADO.txt, desde la raiz del repo.
El formateador de prueba no sustituye la funcion instalada de negocio.
No se probaron las seis facturas reales ni se ejecuto el reproceso en T3QA.
No se accedio a Oracle. La base temporal se elimino al terminar.

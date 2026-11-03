# Correccion de T3.PROC_T3_OT_GENERAL

El coordinador anterior marcaba Fecha_Proc_BATMD aunque el generador
registrara un error sin lanzar una excepcion. Esta correccion exige un
documento y un layout de mas de diez caracteres, sin errores nuevos del
generador o del mapeo SAT, antes de marcar la cabecera.

El overflow numerico se corrigio previamente en PROC_V40_GENERAR_OTROS con
OTROS_Overflow_20261029/02_CORREGIR_MODULO.sql. Conservar ese parche: la
correccion del coordinador agrega controles sobre el resultado del generador.

## Instalacion

1. Abrir **01_INSTALAR_CORRECCION.sql** en SSMS, servidor AZCRNMXNEVTD06,
   base T3QA. Ejecutar primero con `@Aplicar bit=0`: muestra las definiciones
   instalada y propuesta como XML. Revisarlas porque instala un ALTER completo.
2. Con las ejecuciones del coordinador detenidas, cambiar a `@Aplicar bit=1`
   y ejecutar el archivo completo. Se guarda la definicion instalada y sus
   opciones SET en `dbo.REPAIR_OT_GENERAL_20261029`, dentro de la misma
   transaccion que instala la correccion. No ejecuta el procedimiento ni
   reprocesa facturas. Requiere permisos ALTER, lectura de definicion y
   creacion/escritura de la tabla de respaldo.
3. Ejecutar **03_VERIFICAR_INSTALACION.sql**, que solo consulta metadatos,
   respaldo, seis documentos historicos y errores del coordinador.
4. El procedimiento conserva su llamada normal sin parametros. Su ejecucion
   procesa todos los candidatos de cuatro dias; este paquete no lo ejecuta.

**02_REVERTIR_CORRECCION.sql**, con `@Revertir bit=1`, restaura solamente el
modulo respaldado si la definicion instalada sigue siendo la que se desplego.
No revierte datos ni la correccion numerica del generador. La reversion
recupera tambien el comportamiento anterior de marcado sin validar salida.

## Comportamiento

- Conserva ventana movil de cuatro dias, centinela 2999-12-31, helper de
  metodo de pago y tolerancia estricta `ABS(cabecera-detalle)<0.10`, con
  importes a dos decimales.
- Una entrada por factura. Cabeceras duplicadas impiden una generacion nueva.
- Omite documentos con UUID, envio, timbre, confirmacion o estado final,
  incluso si no tienen layout. Tambien omite salidas completas existentes.
  No cambia por ello Fecha_Proc_BATMD; el apartado y helper previos conservan
  su alcance original sobre OTROS_GENERAL.
- Una salida parcial o duplicada preexistente se conserva y devuelve un
  error para revision. No borra ni intenta completar salidas existentes.
- Bloquea cabecera y rangos de documento/layout al procesar una factura.
  Dos ejecuciones concurrentes del coordinador no deben generar la misma
  factura. Productores externos que no sigan el protocolo requieren tambien
  coordinacion operativa; no se agregaron restricciones de unicidad.
- Cada generacion, sus salidas y la marca forman una transaccion por factura.
  Un error detiene la corrida y revierte esa factura. Las facturas anteriores
  ya confirmadas persisten cuando no hay transaccion externa.
- Con transaccion externa usa un savepoint y no confirma el trabajo del
  llamador. Una transaccion externa no confirmable debe revertirla el llamador.
- Observa errores nuevos en RF_ERROR_LOG (GENERAR_OTROS y
  PROC_CFDI_GENERAR_OTROS) y MX_EAI_MESSAGE_LOG (GET_SAT_CLAVEPRODUCTO).
  Los errores internos se revierten con las salidas y el coordinador intenta
  guardar su contexto en RF_ERROR_LOG, Rutina=PROC_T3_OT_GENERAL. El THROW
  53809 incluye factura, numero y mensaje del error; conservar ese mensaje.
- Los descuadres se omiten sin marcar, como antes. Se imprimen contadores.

## Alcance y pruebas

No se ejecutaron procedimientos ni despliegues contra T3QA desde el workspace.
Las seis facturas del incidente ya tienen evidencia historica de timbrado;
no deben desmarcarse ni regenerarse para fabricar layouts faltantes.

`tests_local.py` crea una base temporal exclusiva en LocalDB y utiliza un
generador simulado para probar el contrato del coordinador, no la generacion
fiscal real. Comprueba instalacion/reversion, exito, reejecucion, historicos
sin layout, errores absorbidos y lanzados, salidas parciales/duplicadas,
cabeceras duplicadas, tolerancia, ventana, centinela, concurrencia y
transacciones propias/externas. Elimina su base temporal al terminar.

Fuente principal: `MSSQL/T3/T3/Procedures/PROC_T3_OT_GENERAL.sql`.
Respaldo local anterior: `tmp/proc_t3_ot_general_correccion_20261029/`.
La variante heredada `PROC_T3_OT_GENERAL.SinUSE.sql` no se despliega en este
paquete y conserva su version anterior; no usarla para reinstalar el modulo.

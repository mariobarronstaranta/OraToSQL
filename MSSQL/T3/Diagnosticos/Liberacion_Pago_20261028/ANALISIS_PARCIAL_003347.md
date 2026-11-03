# Primera captura parcial del diagnostico 01

Fuente: [resultados parciales](Captura_003347_PARCIAL.txt), recibidos como
Resultados_Parciales_validar_precondiciones.txt. SHA256:
0D088CBBFCF4481FE77A700A10FE97CEB7ADF17A027662E1EA0A78E1D5903D7D.
Captura inicial 2026-10-28 00:33:47 -06:00; el usuario informa mas de once
minutos y que sigue ejecutandose. El archivo termina en 05B_ULTIMAS_CORRIDAS,
sin error ni final de ejecucion en lo recibido. No es evidencia de terminacion.

## Lo que ya se conoce

- AZCRNMXNEVTD06/T3QA, compatibilidad160, SQLLatin, login AT85233588/dbo,
  TranCount=0 al comenzar la consulta. Todos los objetos requeridos estan
  visibles y todos los permisos directos consultados dan1 en esa sesion.
  No se atribuye la demora a permisos por estos resultados.
- Coordinador instalado: alter28/10 00:11:24.300, hash
  9E821922D3BCAE14A12447913501895950FEC35EF6A08C791506E7ABA9BDD0C6.
- Generador instalado: alter09/09 13:46:09.147, hash
  DFBA7B00E6DB529BD1ACCAA705C48CCA812E6312E479446681FB3844D45F50CD.
  DeclaraFacturaPagadaVarchar4=1. El riesgo de truncar la clave de impuestos
  esta confirmado en el cuerpo instalado, no solo en el archivo del repositorio.
  Faltan candidatos para cuantificar que facturas concretas afecta.
- Secuencia ProcessID actual26,516,971, no agotada; cabe en NUMERIC(8,0).
  El rango maximo de diez digitos sigue siendo un riesgo futuro, no el bloqueo
  demostrado de esta corrida. El diagnostico no consume un valor de secuencia.
- Componente613 Status1 y Last_Run13/08/2026 10:40:03. La ultima bitacora
  visible finalizo ese dia con Proceso_1=0. No prueba cero candidatos actuales
  ni ausencia de otra solicitud activa.

## Lo que falta y que no debe inferirse

No llegaron 06_CONFIG_GENERAL, candidatos07/08 ni fiscal11/hallazgos12.
Por tanto no se acredita disponibilidad de configuracion, cantidad de pagos
elegibles, integridad de sus relaciones o aptitud para ejecutar el generador.
El ultimo resultado visible no identifica con certeza la sentencia activa:
puede haber espera, compilacion, trabajo o salida aun no entregada.

La consulta siguiente a 05B arma configuracion con GETCONV. Mas adelante 01
consulta todos los pendientes de via01, evalua funciones por fila y hace
consultas correlacionadas. Es una carga potencialmente alta; @MaxDetalle=200
solo limita resultados mostrados, no el conjunto trabajado. Las pruebas
LocalDB verificaron correccion con fixtures, no rendimiento a escala T3QA.
No atribuir once minutos a un scan, funcion, bloqueo o E/S sin la solicitud activa.

## Accion inmediata

Ejecutar [03_VER_DIAGNOSTICO_EN_CURSO.sql](03_VER_DIAGNOSTICO_EN_CURSO.sql)
en otra ventana de la misma base mientras01 siga activo. Es una instantanea
de DMVs, sin WAITFOR ni consultas a tablas de negocio. Guardar solicitud,
sentencia completa, esperas y bloqueadores. Si no identifica automaticamente
la solicitud y aun existe, completar @Spid con el de la ventana del01.

Tras capturar, puede cancelarse01 con el boton Cancelar de SSMS. El script
revisado no contiene DML de negocio ni NEXT VALUE FOR y comenzo sin transaccion
externa segun la captura. No se pide KILL, reset de estados ni reproceso.
No volver a ejecutar01 completo ni iniciar el SP fiscal antes de revisar
la actividad y el riesgo VARCHAR(4). No se cambio un procedimiento de negocio.

03 paso TSql160Parser sin errores; es una consulta de inspeccion. No se
realizo una captura remota desde el agente ni se presume la causa de la demora.

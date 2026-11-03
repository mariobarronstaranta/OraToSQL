# Comparacion del manejo de errores con Oracle

Revision local: 29/10/2026. No se consulto una instancia Oracle.

No se encontro el fuente Oracle de T3.PROC_T3_OT_GENERAL ni del generador
de OTROS en los archivos disponibles bajo ORA. El fuente MSSQL anterior
es evidencia de su implementacion migrada, no prueba de paridad con Oracle.

## Evidencia disponible del llamador Oracle

Archivo: ORA/T3/EAI_OWNER/Packages/RECV_TO_SEND_V3_BODY.SQL.
Rutina: RECV_INVOICE_INTERCOMPANY.

- Linea 826: COMMIT del trabajo anterior del procedimiento padre.
- Linea 827: sInstanceChk := 'T3'.
- Linea 828: T3.PROC_T3_OT_GENERAL, sin parametros.
- Lineas 829-832: EXCEPTION WHEN OTHERS captura errores propagados y
  compone SQLCODE/SQLERRM; el mensaje se limita a 250 caracteres.
- Lineas 833-840: inserta en EAI_OWNER.MX_EAI_MESSAGE_LOG con
  QUEUE_NAME='RECV_INVOICE_INTERCOMPANY', REFERENCE=sInstanceChk,
  JOB_PID=nPID, STATUS='Error' y SOURCE='PL/SQL'.
- Linea 841: COMMIT. Este bloque no contiene ROLLBACK ni RAISE.

Este comportamiento demuestra que el padre registra una excepcion recibida
y no la vuelve a lanzar desde ese bloque. No demuestra que los errores del
generador lleguen hasta el padre, ni que el coordinador Oracle revierta
salidas o evite marcar cabeceras. Tampoco permite concluir el estado final
de cambios internos del coordinador sin conocer sus controles transaccionales.

## Comparacion que falta completar

| Punto | Evidencia Oracle necesaria |
|---|---|
| Conversion de tasa | Expresion real, tipo de variable, formato numerico y longitud destino del generador. |
| Error absorbido | EXCEPTION y eventuales RAISE, parametros OUT o retornos de cada hijo. |
| Marcado de cabecera | Posicion del UPDATE Fecha_Proc_BATMD y condicion que acredita exito. |
| Salidas parciales | COMMIT, ROLLBACK, SAVEPOINT y posibles transacciones autonomas en los hijos. |
| Historicos/duplicados | Filtros y consultas a CFDI_DOCUMENTOS y CFDI_DOCUMENTOS_ENVIAR. |

Los controles agregados al coordinador MSSQL son una correccion de su
comportamiento observado. Hasta revisar el fuente Oracle no deben presentarse
como una reproduccion certificada de los controles del homologo.

## Extraccion preparada

ORA/T3/T3/Procedures/Diagnosticos/01_EXTRAER_PROC_T3_OT_GENERAL.sql consulta
ALL_SOURCE, ALL_OBJECTS, ALL_DEPENDENCIES y ALL_SYNONYMS. No ejecuta SP,
modifica datos ni contiene COMMIT/ROLLBACK. Exporta por SPOOL al archivo:

ORA/T3/T3/Datos/Resultado_Fuentes_OT_GENERAL_Oracle.txt.

Ejecutar con F5 en SQL Developer conectado al origen Oracle. Incluye ambos
nombres posibles del generador, helper de metodo de pago, mapeo SAT y funcion
de formato. Si no hay lineas del coordinador, revisar visibilidad/permisos o
resolucion del objeto. Si el fuente es wrapped se necesita el original legible.

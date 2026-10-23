# Aplicacion en AZCRNMXNEVTD06 / T3QA

Estos archivos responden a la captura del 19/10/2026 a las 14:22:
DELETE de detalle ~420 ms y ~48,277 lecturas por llamada; DELETE de cabecera
~108 ms y ~11,583 lecturas; consulta de relacion de folios ~88 ms por llamada.
Son promedios acumulados de cache, no un benchmark controlado.

1. Conectar a AZCRNMXNEVTD06 con una cuenta autorizada y seleccionar T3QA.
   Esperar a que termine el lote/job antes de aplicar cambios. No envolver
   los scripts en BEGIN TRAN.
2. Ejecutar **01_REVISION.sql**. Guardar DefinicionAntesDelCambio como archivo
   SQL y conservar los planes/metricas de los DELETE. El archivo solo consulta.
3. Ejecutar **02_PATCH_REFERENCEID.sql** con `@Revertir=0`. Debe informar tres
   bloques modificados; si ya esta aplicado, informa que no hay cambios.
4. Ejecutar un lote comparable por el mecanismo habitual y repetir 01_REVISION.sql
   o RECV_INVOICE_DIAGNOSTICO.SQL. Comparar lecturas/tiempo medio y verificar
   resultados de negocio. Comprobar si el plan realiza busqueda por ReferenceID.
5. Cuando termine el lote, ejecutar **03_INDICE_FOLIOS.sql**. Crea el indice
   no unico por FACTURASAP, CLASE_FACTURA, incluyendo FACTURAT3, si falta acceso
   inicial por FACTURASAP. Crear el indice puede bloquear temporalmente.
6. Repetir la medicion con otro lote comparable. Separar las dos intervenciones
   permite atribuir la mejora. Si se aplican ambas en una misma ventana, medir
   el resultado conjunto, sin atribuirlo a una sola de ellas.

02 y 03 realizan cambios; no tienen un indicador Aplicar que deba activarse.
No ejecutar versiones alternativas OPTIMIZADO ni crear nuevamente indices por
ReferenceID. Tampoco actualizar todas las estadisticas o cambiar MAXDOP como
parte de este paquete.

## Alcance del parche

02 modifica solo los tres DELETE de TMP_DOCUMENT_HEADER, TMP_DOCUMENT_DETAIL y
TMP_DOCUMENT_CONDITIONS en la definicion desplegada de SF_PROC_PREINVOICE_IFC.
No sustituye el procedimiento con una copia local ni cambia sus parametros.
Busca la forma exacta de cada DELETE; si contiene otra logica, se detiene antes
de ALTER. Las correcciones existentes de transacciones y avisos NULL permanecen.

Se conserva @sReferenceID Unicode. Si convertir la referencia a VARCHAR(50) y
volver a Unicode reproduce los mismos bytes, se agrega la igualdad VARCHAR
como condicion de acceso y se conserva la comparacion Unicode como condicion
residual. Asi el optimizador dispone de una igualdad compatible con la clave.
Si no se puede representar la referencia sin perdida (o es NULL), se ejecuta
el DELETE original. Esto evita convertir silenciosamente un identificador a '?'.
La conversion de la columna en la condicion residual no debe sustituir la
busqueda por clave: verificar el plan resultante en T3QA. No se fuerzan indices.

Este paquete es un parche independiente. Si posteriormente se vuelve a desplegar
el archivo base del procedimiento sin este ajuste, habra que incorporar/reaplicar
el parche. No sustituir la version desplegada actual por una alternativa antigua.

## Reversa

Ejecutar 02_PATCH_REFERENCEID.sql con `@Revertir=1` restaura los tres predicados
originales, sin tocar el resto del procedimiento. Si el procedimiento fue editado
manualmente dentro de esos bloques despues del parche, revisar antes de revertir.
Tambien se conserva el respaldo completo obtenido en el paso 2.

El indice no se elimina automaticamente al revertir el parche. Si se decide
revertirlo, comprobar primero que IX_RI_NRIV_RELACION_SAP_CLASE fue creado en esta
intervencion y retirar exclusivamente ese indice con el DBA.

## Validacion local

Run_PerformancePatch.ps1, en Procedures/tests/RECV_INVOICE_TRANSACTIONS, verifica
aplicacion y reversa sobre el procedimiento real, repeticion sin cambios extra,
las seis pruebas de transacciones existentes, ocho casos de equivalencia de
predicados y creacion repetible del indice sobre el DDL real de MX_NRIV_RELACION.
No se ha aplicado este paquete en T3QA desde esta sesion: su cuenta Windows no
tiene acceso. Las pruebas locales no predicen la mejora exacta de throughput.

ALTER invalida planes del procedimiento: los nuevos contadores de cache no son
comparables mediante resta con el plan anterior. Comparar promedios sobre lotes
representativos, lecturas por documento y planes antes/despues; no sumar tiempos
inclusivos de RECV_INVOICE, parser y llamadas hijas.

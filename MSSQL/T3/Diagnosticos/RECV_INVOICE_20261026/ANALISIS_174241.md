# Archivo de datos, memoria y acceso CLIENTE_V3

Fuente: [captura original](Captura_174241.rpt), recibida como
Resultados_Invoice_2026102611743.rpt. SHA256:
D19335F8FD41ACCEAA19B5A02693E553A765C07A40FAEEC82BE17ADDE913A35E.
AZCRNMXNEVTD06 / T3QA; inicio 2026-10-26 17:42:41 -06:00,
fin 17:42:51. La hora de guardado del archivo no es la hora de captura.

## Medicion de archivos durante la carga

| Archivo | Ruta | Actividad en 10.004 s | Latencia media en ventana |
|---|---|---:|---:|
| T3QA, datos | G:\...\T3QA.mdf | 320 lecturas / 2.5 MB; cero escrituras | 21.416 ms por lectura |
| T3QA_log | P:\...\T3QA_log.ldf | 153 escrituras / 1.586 MB; cero lecturas | 3.458 ms por escritura |

La media HISTORICA de lectura de datos es 525.309 ms y de escritura
232.665 ms. No son las latencias de esta ventana ni acreditan una tendencia
uniforme. Las lecturas actuales de datos siguen justificando revision del
camino de E/S con el DBA, sin concluir que el disco fisico esta danado o que
la demanda de todo el volumen sea la de este archivo. Contadores por archivo
incluyen todas las sesiones de la base.

Sesion 105, en INVOICE_TO_FACTURA: PAGEIOLATCH_SH 4,138 ms/201 tareas y
PAGEIOLATCH_EX 2,851 ms/118 tareas; WRITELOG 550 ms/153 tareas. No aparece
bloqueador positivo. Al inicio y fin espera en INSERT RF_Complemento.
Las esperas de paginas siguen dominando y el log tiene menor peso en esta
ventana. No sumar como porcentajes exactos los tiempos capturados con limites
distintos ni atribuir las 153 escrituras de log a 153 documentos certificados.

## Memoria y configuracion observadas

Memoria fisica total 131,066.75 MB; disponible 11,459.69 MB. SQL usa
110,082.54 MB fisicos y max server memory esta en 110,000 MB.
Las senales system_low_memory_signal_state, process_physical_memory_low y
process_virtual_memory_low son cero. No hay evidencia de presion de memoria
en esa instantanea; no descarta episodios anteriores ni justifica aumentar RAM
o cambiar max server memory. AUTO_CLOSE y AUTO_SHRINK estan desactivados.

Los dos archivos crecen al 10%; el archivo de datos mide 1,435,209.25 MB y
el log 247,763.625 MB. Es informacion para planificar capacidad, no prueba
de un crecimiento ocurrido durante la lentitud. No se cambia autogrowth aqui.

## Candidato concreto: busqueda por CLIENTE_V3

La captura confirma CLIENTE_PK deshabilitado, con claves
(CLIENTE_V3,FECHA_INI_VIG). No hay otro indice activo inicial por CLIENTE_V3
en las filas del catalogo entregadas. CLIENTE_IDX1 SI esta habilitado por
(CLIENTE_SAP,FECHA_INI_VIG,FECHA_FIN_VIG); no duplicar ese acceso SAP.

El [inventario del 22 de octubre](../Resultado_Indices.txt) confirma que
CLIENTE_PK es UNIQUE, pero no PRIMARY KEY ni UNIQUE constraint. El usuario
respondio que desconoce por que se deshabilito; no se asume que sea un error.
El trace historico contiene Object:Altered desde SSMA for Oracle el 20/10
a las 15:56:58, sin texto SQL: no demuestra por si solo la causa o la orden
exacta de deshabilitacion. Los otros dos indices de vigencia SAP deshabilitados
tambien permanecen fuera del cambio.

GET_REMISION_INFO busca por CLIENTE_V3 en ScrCliente_T3 y en el JOIN de
ScrCliente_T3SAP. La ausencia de acceso inicial es un candidato para las
lecturas elevadas de esta ruta. El top de sentencias en cache de 09 no
explica todo el costo inclusivo del procedimiento ni acredita el plan real
del cursor mas costoso; no se presenta un scan productivo como comprobado.

Se preparo [07_CREAR_ACCESO_CLIENTE_V3.sql](07_CREAR_ACCESO_CLIENTE_V3.sql):
indice NO UNIQUE IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA, claves
(CLIENTE_V3,FECHA_INI_VIG,FECHA_FIN_VIG). Permite duplicados existentes,
mantiene CLIENTE_PK deshabilitado y no altera las reglas de unicidad.
Las columnas de domicilio se recuperan de la tabla para las filas halladas;
no se agrega una cobertura ancha sin medir su necesidad.

El script valida T3QA, tipos y ausencia de otro acceso activo inicial por V3.
Si ya existe ese acceso, devuelve IndicesCreados=0. Si aplica, devuelve 1.
No ejecuta facturas, no modifica SP, datos, GETCONV ni R044. Ejecutar solo
despues de terminar las cargas y sin procesos concurrentes sobre CLIENTE:
construir el indice necesita E/S/espacio y puede bloquear. Reversion explicita
del indice nuevo documentada como comentario; no se ejecuta automaticamente.

## Verificacion local y siguiente medicion

tests/RunClienteV3.ps1 crea una base temporal con collation SQLLatin y DDL real
de CLIENTE/dependencias, cluster por RFC e indice SAP activo. CLIENTE_PK es
unico y esta deshabilitado; los datos sinteticos incluyen duplicados de
(CLIENTE_V3,FECHA_INI_VIG) con distinto SAP. Ejecuta GET_REMISION_INFO real,
sin modificarlo, antes y despues del nuevo indice.

Once casos mantienen sus once campos de salida: V3, SAP, vencido, futuro,
vigencia NULL, duplicados con la misma salida, CEDIS, distribuidor/sociedad,
ausente, NULL y limite de vigencia del dia. Sin errores en bitacora; uso del
indice por seeks comprobado; repeticion y deteccion de otro acceso previo
sin cambios; DROP de reversion probado. Definicion del SP identica.

Ultima ejecucion: CodexClienteV3_89647b0181, codigo 0, base eliminada.
40 consultas sinteticas: 209.358 ms/1,210 lecturas por llamada antes frente
a 11.000 ms/20 lecturas despues (98.35% menos lecturas en esa prueba).
Es una microprueba con 50,008 filas, no un pronostico del lote ni prueba de
20-25 registros/s. No acredita la salida final con multiples coincidencias
de domicilio diferentes sin ORDER BY; el procedimiento conserva su cursor.

Aplicacion real aun pendiente. Tras aplicar y medir una carga normal, obtener
inicio/fin/cantidad y repetir 03 durante carga para comparar ruta PREVENTA /
OXXO / REMISION, FACTURA y esperas. La latencia del archivo de datos sigue
siendo un frente separado para el DBA. La meta integral permanece abierta.

Referencia: [Microsoft, diagnostico de E/S](https://learn.microsoft.com/es-es/troubleshoot/sql/database-engine/performance/troubleshoot-sql-io-performance)
y [indices deshabilitados](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/disable-indexes-and-constraints?view=sql-server-ver16).

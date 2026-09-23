VENTA FELIPE G - CFDI / SQL SERVER
1. Editar las dos fechas al inicio de Extract.sql (YYYY-MM-DD).
   Ejemplo: inicio 2026-07-01 y fin 2026-08-01.
   El inicio se incluye y el fin se excluye. Ambos bloques usan el mismo periodo.
2. Editar ExtractVTAAG.bat y completar set "SQLCMDPASSWORD=" al inicio.
   Colocar la clave despues de = y antes de la comilla final.
   Si contiene un signo de porcentaje, escribirlo dos veces (%%).
3. Guardar y ejecutar ExtractVTAAG.bat (tambien funciona con doble clic).
4. Se genera VTA_CFDIYYMMDD_HHMM.CSV y se copia a Processed.
5. Revisar Logs si ocurre un error. El envio por correo sigue siendo manual.
Servidor predeterminado: AZCRNMXNEVTD06. Base: T3QA. Usuario: AT85233588.
Ver ../README_Migracion_Ventas.md para detalles y pruebas.

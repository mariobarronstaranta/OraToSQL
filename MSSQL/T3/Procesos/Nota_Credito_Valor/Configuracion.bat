@echo off
rem Configuracion comun para todos los reportes.
set "NDC_SERVER=AZCRNMXNEVTD06"
set "NDC_DATABASE=T3QA"
set "NDC_USER=AT85233588"
rem Puede colocar el password entre = y la comilla final.
rem Si contiene un signo de porcentaje, escribalo dos veces en el BAT.
rem La expansion retardada permanece desactivada para admitir signos !.
rem Si ya definio SQLCMDPASSWORD en el equipo, se conserva ese valor.
if not defined SQLCMDPASSWORD set "SQLCMDPASSWORD=CAMBIAR_PASSWORD"
exit /b 0


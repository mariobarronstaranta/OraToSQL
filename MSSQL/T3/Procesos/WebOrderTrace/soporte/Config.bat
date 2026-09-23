@echo off
rem No guardar claves en este archivo. SQLCMDPASSWORD se recibe del entorno.
if not defined WOT_SERVER set "WOT_SERVER=AZCRNMXNEVTD06"
if not defined WOT_DATABASE set "WOT_DATABASE=T3QA"
if not defined WOT_USER set "WOT_USER=AT85233588"
if not defined WOT_CODEPAGE set "WOT_CODEPAGE=65001"
if not defined WOT_PUBLISH_DIR set "WOT_PUBLISH_DIR=E:\IntegrationToolBox\UploadSharePoint"
rem Variables opcionales: WOT_TRUSTED=1, WOT_SQL_EXTRA, WOT_BCP_EXTRA.
rem WOT_SQL_EXTRA / WOT_BCP_EXTRA solo deben contener opciones confiables.
where sqlcmd.exe >nul 2>&1
if errorlevel 1 exit /b 10
where bcp.exe >nul 2>&1
if errorlevel 1 exit /b 11
if "%WOT_TRUSTED%"=="1" exit /b 0
if not defined SQLCMDPASSWORD (
 echo ERROR: define SQLCMDPASSWORD en esta sesion de CMD antes de ejecutar.
 exit /b 12
)
exit /b 0

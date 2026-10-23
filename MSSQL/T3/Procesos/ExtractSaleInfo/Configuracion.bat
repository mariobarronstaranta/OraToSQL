@echo off
rem Se conservan los valores definidos por el programador o el usuario.
if not defined ESI_SERVER set "ESI_SERVER=AZCRNMXNEVTD06"
if not defined ESI_DATABASE set "ESI_DATABASE=T3QA"
if not defined ESI_DESTINO set "ESI_DESTINO=E:\IntegrationToolBox\UploadSharePoint"
rem Sin ESI_USER se utiliza autenticacion Windows.
rem Para SQL: defina ESI_USER y SQLCMDPASSWORD fuera del repositorio.
rem ESI_TRUST_CERTIFICATE=1 solo si se requiere confiar en el certificado del servidor.
exit /b 0

@echo off
rem La expansion de la clave ocurre solo aqui, sin CALL ni delayed expansion.
if "%WOT_TRUSTED%"=="1" goto trusted
bcp.exe %* -S "%WOT_SERVER%" -d "%WOT_DATABASE%" -U "%WOT_USER%" -P "%SQLCMDPASSWORD%" %WOT_BCP_EXTRA%
exit /b %errorlevel%
:trusted
bcp.exe %* -S "%WOT_SERVER%" -d "%WOT_DATABASE%" -T %WOT_BCP_EXTRA%
exit /b %errorlevel%

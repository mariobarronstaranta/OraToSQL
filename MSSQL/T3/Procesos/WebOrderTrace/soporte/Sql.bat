@echo off
rem Uso interno. Hereda Config.bat y devuelve el codigo real de sqlcmd.
if "%WOT_TRUSTED%"=="1" goto trusted
sqlcmd -S "%WOT_SERVER%" -d "%WOT_DATABASE%" -U "%WOT_USER%" -b -r1 %WOT_SQL_EXTRA% %*
exit /b %errorlevel%
:trusted
sqlcmd -S "%WOT_SERVER%" -d "%WOT_DATABASE%" -E -b -r1 %WOT_SQL_EXTRA% %*
exit /b %errorlevel%

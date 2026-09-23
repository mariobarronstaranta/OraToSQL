@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0" || exit /b 1
call Config.bat
if errorlevel 1 goto failed
call Sql.bat -i "sql\00_Prevalidar.sql"
if errorlevel 1 goto failed
popd
exit /b 0
:failed
popd
exit /b 1

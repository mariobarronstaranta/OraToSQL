SET NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
Rem Loading to input Table
sqlplus CCC_CARGA/MILAN$2023$PMO@owba030p @E:\IntegrationToolBox\RecepcionEvidencias\truncate_ldr.sql
sqlldr userid=CCC_CARGA/MILAN$2023$PMO@owba030p control=E:\IntegrationToolBox\RecepcionEvidencias\CONTROL.ctl log=process.log
sqlplus CCC_CARGA/MILAN$2023$PMO@owba030p @E:\IntegrationToolBox\RecepcionEvidencias\moveInfo.sql 

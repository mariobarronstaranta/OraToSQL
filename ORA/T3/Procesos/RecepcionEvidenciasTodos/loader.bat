SET NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
Rem Loading to input Table
sqlplus CCC_CARGA/MILAN$2023$PMO@owba030p              @E:\IntegrationToolBox\RecepcionEvidenciasTodos\truncate_ldr.sql
sqlldr userid=CCC_CARGA/MILAN$2023$PMO@owba030p control=E:\IntegrationToolBox\RecepcionEvidenciasTodos\control.ctl log=process.log  Errors=10000000
sqlplus CCC_CARGA/MILAN$2023$PMO@owba030p               @E:\IntegrationToolBox\RecepcionEvidenciasTodos\moveInfo.sql 
Pause
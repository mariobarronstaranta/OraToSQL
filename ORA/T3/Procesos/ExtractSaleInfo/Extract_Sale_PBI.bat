sqlplus EAI_APPS/TURIN$2023$PMO@owba030p @HeaderPBI.sql
call Copy_Processed.bat VENTAS.CSV
COPY VENTAS*.csv E:\IntegrationToolBox\UploadSharePoint\*.*
DEL  VENTAS*.csv 
call Extract_Diff_Sale.bat
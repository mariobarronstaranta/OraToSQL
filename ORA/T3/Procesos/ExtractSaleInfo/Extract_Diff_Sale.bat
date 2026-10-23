sqlplus EAI_APPS/TURIN$2023$PMO@owba030p @HeaderDiffSale.sql
call Copy_Processed.bat DIFF_VENTAS.CSV
COPY DIFF_VENTAS*.csv E:\IntegrationToolBox\UploadSharePoint\*.*
DEL  DIFF_VENTAS*.csv 
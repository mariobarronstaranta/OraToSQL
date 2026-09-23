DEL WebOrder*.csv 
sqlplus EAI_APPS/TURIN$2023$PMO@owba030p @Header.sql
COPY WebOrder*.csv Processed\WebOrder*.csv
COPY WebOrder*.csv E:\IntegrationToolBox\UploadSharePoint\PREVENTA_CANCELADA.csv

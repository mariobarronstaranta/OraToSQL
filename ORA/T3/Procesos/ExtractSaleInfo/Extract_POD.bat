sqlplus EAI_APPS/TURIN$2023$PMO@owba030p @HeaderPOD.sql
call Copy_Processed.bat PROOF_OF_DELIVERY.CSV
COPY PROOF_OF_DELIVERY*.csv E:\IntegrationToolBox\UploadSharePoint\*.*
DEL  PROOF_OF_DELIVERY*.csv 
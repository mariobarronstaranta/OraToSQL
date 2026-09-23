LOAD DATA 
INFILE 'E:\IntegrationToolBox\RecepcionEvidencias\Resultados7_Eleven.csv' 
BADFILE 'E:\IntegrationToolBox\RecepcionEvidencias\RecepcionEvidencias.ready.bad'
DISCARDFILE 'E:\IntegrationToolBox\RecepcionEvidencias\RecepcionEvidencias.ready.dsc'
APPEND
INTO TABLE EAI.LDR_SHAREPOINT
FIELDS TERMINATED BY ','
(
    DUMMY1,
    ItemInternalId, 
    FECHA ,
    TIENDA,
    FOLIORECEPCION,
    VOLUMENTICKET,
    FOLIOINTERNO,
    VOLUMENNOTA,
    COINCIDEVOLUMEN )
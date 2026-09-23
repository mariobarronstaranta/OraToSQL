LOAD DATA INFILE 'Venta.csv'
   BADFILE 'LoadWA_Venta.bad'
   DISCARDFILE 'LoadWA_Venta.dsc'
   TRUNCATE INTO TABLE EAI_OWNER.X_SAP_VTA_X_CLIENTE
   FIELDS TERMINATED BY ','
   TRAILING NULLCOLS
( 
   Cliente_SAP    ,
   Factura        ,
   Nota_Credito   ,
   Canc_Fact      ,
   Canc_Nota      ,
   Grand_Total    
)
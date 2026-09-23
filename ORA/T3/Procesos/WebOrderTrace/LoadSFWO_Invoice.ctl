LOAD DATA INFILE 'Invoice.csv'
   BADFILE 'LoadSFWO_Invoice.bad'
   DISCARDFILE 'LoadSFWO_Invoice.dsc'
   TRUNCATE INTO TABLE EAI_OWNER.WO_TMP_INVOICE
   TRUNCATE FIELDS TERMINATED BY ','
   TRAILING NULLCOLS
( 
Row_Name                               ,
CreatedDate                            ,
Mobile_Invoice_Number__c               ,
SAP_Invoice_Number__c                  ,
ivydsd__Order__r_Name                  ,
Order_Retailer_PO_Number__c            ,
Mobile_Order_Number__c                 ,
ivydsd__Invoice_Date__c                ,
Customer_Id                            ,
ivybat__SAP_CustomerId__c              ,
Delivery_Status__c                     ,
ivydsd__Invoice_Status__c              ,
Gross_Amount__c                        ,
CreatedBy                              ,
CreatedBy_Name                         ,
CreatedById                            
)
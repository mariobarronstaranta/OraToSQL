LOAD DATA INFILE 'Order.csv'
   BADFILE 'LoadSFWO_Order.bad'
   DISCARDFILE 'LoadSFWO_Order.dsc'
   TRUNCATE INTO TABLE EAI_OWNER.WO_TMP_ORDER
   TRUNCATE FIELDS TERMINATED BY ','
   TRAILING NULLCOLS
( 
Row_Name                        ,
CreatedDate                     ,
ivydsd__Mobile_Order_Number__c  ,
Retailer_PO_Number__c           ,
ivydsd__Order_Date__c           ,
ivydsd__Delivery_Date__c        ,
Customer_Id                     ,
ivybat__SAP_CustomerId__c       ,
ivydsd__Order_Status__c         ,
Delivery_Status__c              ,
Order_Amount__c                 ,
CreatedBy                       ,
CreatedBy_Name                  ,
CreatedById                     
)
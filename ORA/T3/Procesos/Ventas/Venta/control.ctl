LOAD DATA 
INFILE 'E:\IntegrationToolBox\Venta\factura.ready.doc' 
BADFILE 'E:\IntegrationToolBox\Venta\factura.ready.bad'
DISCARDFILE 'E:\IntegrationToolBox\Venta\factura.ready.dsc'
APPEND
INTO TABLE "TAO_SALES_DOCS_LDR"
FIELDS TERMINATED BY ','
(
    doc_ord_r3,
    doc_num_r3,
    CUSTOMER_Number NULLIF CUSTOMER_Number=BLANKS,
    distributor, 
    customer,
    doc_date, 
    doc_type,
    doc_num_ref1,
    doc_num_ref2, 
    doc_status NULLIF doc_status=BLANKS,
    DOC_NETAMT "TO_NUMBER(RTRIM(:DOC_NETAMT),'999999999.99')",
    DOC_TAXAMT "TO_NUMBER(RTRIM(:DOC_TAXAMT),'999999999.99')",
    DOC_QTY    "TO_NUMBER(RTRIM(:DOC_QTY),'999999999.999')"
)

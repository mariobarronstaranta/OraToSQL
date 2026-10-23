      SELECT Info.lineText
         FROM (
                SELECT
                       '0'                                              AS OrderBy ,
                       'Doc_Num,Proof_of_Delivery'                      AS lineText
                   FROM DUAL    
                UNION ALL   
                SELECT '1'                                              AS OrderBy ,
                       Inv.Doc_Num  || ',' || Inv.Proof_of_Delivery__C  AS lineText
                   FROM EAI_Owner.Facturas_B Inv, EAI_Owner.Client Cte
                   WHERE Inv.Proof_of_Delivery__c IS NOT NULL
                     AND Inv.Cte_SAP               = Cte.Cliente_SAP
                     AND Cte.RFC                   = 'SEM980701STA'
                     AND Inv.Invc_dt              >= TO_CHAR( SYSDATE - 10, 'YYYY-MM-DD' )
              ) Info
           ORDER BY Info.OrderBy  ;
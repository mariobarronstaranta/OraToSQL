SELECT Line_Exported                               AS Line_Exported_to_CSV
FROM (
       SELECT
               0                                   AS Row_ID ,
               '00'                                AS Row_Key,
               '"Sold to Party"'                   || ';' ||
               '"Item Number"'                     || ';' ||
               '"Plant (Item)"'                    || ';' ||
               '"Material"'                        || ';' ||
               '"Billing Date"'                    || ';' ||
               '"Item Pricing Condition Amount 1"' || ';' ||
               '"Item Pricing Condition Amount 2"' || ';' ||
               '"Total"'                           || ';' ||
               '"Area"'                            AS Line_Exported
          FROM DUAL
       UNION ALL
       SELECT 1                                    AS Row_ID ,
              NDC.Row_Key                          AS Row_Key,
              '"' || NDC.Sold_to_Party             || '";' || 
              NDC.Item_Number                      || ';'  ||
              '"' || NDC.Plant_Item                || '";' || 
              NDC.Material                         || ';'  || 
              '"' || NDC.Billing_Date              || '";' || 
              NDC.Item_Cond_Amount_1               || ';'  ||
              NDC.Item_Cond_Amount_2               || ';'  ||
              NDC.Total                            || ';'  ||
              '"' || NDC.Area                      || '"'  
                                                   AS Line_Exported
          FROM (
                 SELECT 
                        Head.Factura || LPAD( Det.Num_Linea, 5, '0')            
                                                   AS Row_Key           ,
                        Head.Cliente_SAP           AS Sold_to_Party     ,
                        Det.Num_Linea              AS Item_Number       ,
                        MC.Ctro                    AS Plant_Item        ,
                        Det.Material               AS Material          ,
                        CASE
                           WHEN Head.Fecha_Factura IS NOT NULL THEN TO_CHAR( Head.Fecha_Factura, 'DD/MM/YYYY' )
                           ELSE
                              TO_CHAR( SYSDATE, 'DD/MM/YYYY' )
                        END                        AS Billing_Date      ,
                        Det.Valor_Subt             AS Item_Cond_Amount_1,
                        Det.Valor_IVA              AS Item_Cond_Amount_2,
                        Det.Valor_Subt +
                        Det.Valor_IVA              AS Total             ,
                        Head.Area_Solicitante      AS Area
                    FROM T3.X_Propuesta_NDC      Head ,
                         T3.Mov_Cliente          MC   ,
                         T3.X_Propuesta_Detalle  Det
                    WHERE Head.Factura           = Det.Factura  
                      AND Head.Cliente_SAP       = MC.Cliente_SAP
                      AND Head.Area_Solicitante  = 'Tradicional'
                 ORDER BY Head.Factura, Det.Num_Linea
             ) NDC 
     ) Info
ORDER BY Info.Row_ID, Info.Row_Key ;

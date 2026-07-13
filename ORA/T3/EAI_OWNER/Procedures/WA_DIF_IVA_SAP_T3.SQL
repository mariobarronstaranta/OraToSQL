create or replace PROCEDURE           "WA_DIF_IVA_SAP_T3" 
   ( pDias           IN NUMBER   DEFAULT 30 )
   AS
--
   CURSOR ScrAjustes IS
      SELECT Diff.Factura                                         AS Factura       ,
             Diff.SAP_Valor_IVA - Diff.Valor_IVA                  AS Diferencia    ,
             NVL( Issue.Diferencia, 0 )                           AS Diff_Issue
         FROM (
                SELECT Info.Factura                               AS Factura       ,
                       Info.Entrega                               AS Entrega       ,
                       Info.Fecha_Factura                         AS Fecha_Factura ,
                       Info.Valor_Subt                            AS Valor_Subt    ,
                       Info.Valor_IVA                             AS Valor_IVA     ,
                       SUM( NVL( Det.Valor_Subt, 0 ) / 100 )      AS SAP_Valor_Subt,
                       SUM( NVL( Det.Valor_IVA , 0 ) / 100 )      AS SAP_Valor_IVA 
                   FROM (
                          SELECT PG.Factura                       AS Factura      ,
                                 PG.Entrega                       AS Entrega      ,
                                 PG.Fecha_Factura                 AS Fecha_Factura,
                                 SUM( NVL( PD.Valor_Subt , 0 ) )  AS Valor_Subt   ,
                                 SUM( NVL( PD.Valor_IVA  , 0 ) )  AS Valor_IVA    
                             FROM T3.Preventa_General         PG ,
                                  T3.Preventa_Detalle         PD 
                             WHERE PG.Clase_Factura = 'C025'
                               AND PG.Fecha_Factura > SYSDATE - NVL( pDias, 30 )
                               AND PG.Factura       = PD.Factura
                             GROUP BY PG.Factura, PG.Entrega, PG.Fecha_Factura
                        ) Info,
                        EAI_owner.tmp_Document_Detail Det
                      WHERE Info.Entrega = Det.ReferenceID
                      GROUP BY Info.Factura, Info.Entrega, Info.Fecha_Factura, Info.Valor_Subt, Info.Valor_IVA
                 ) Diff,
                 T3.NDC_ISSUE_IVA Issue
           WHERE Diff.Valor_IVA != Diff.SAP_Valor_IVA       
             AND Diff.Factura    = Issue.Factura(+) ;
--   
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   nPedidos              NUMBER(05)    ;
BEGIN
   nPedidos := 0 ;
   FOR Inv IN ScrAjustes LOOP
      IF ( Inv.Diff_Issue = 0 ) THEN
         nPedidos := nPedidos + 1 ;   
         INSERT INTO T3.NDC_ISSUE_IVA 
            ( Factura, Diferencia, Fecha_Insert )
         VALUES
            ( Inv.Factura, Inv.Diferencia, SYSDATE ) ;
      ELSE
         UPDATE T3.NDC_ISSUE_IVA SET Diferencia   = Inv.Diferencia,
                                     Fecha_Update = SYSDATE
            WHERE Factura = Inv.Factura  ;
      END IF ;
   END LOOP ;
   DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE          , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME         , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT        , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA Payment'       , NULL               , SYSDATE             , NULL           ,
          'Error'            , 'WA_DIF_IVA_SAP_T3', sMsg                , 'PL/SQL'       ,
           sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;   
END WA_DIF_IVA_SAP_T3 ;
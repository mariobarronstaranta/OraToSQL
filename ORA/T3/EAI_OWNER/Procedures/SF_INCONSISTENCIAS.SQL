create or replace PROCEDURE           SF_INCONSISTENCIAS
IS
--    v_ID                VARCHAR2(050) ;       
    sMsg                VARCHAR2(500) ;   
    sErrorCode          VARCHAR2(020) ;
    nPID                NUMBER(08)    ;
    nProceso            NUMBER(08)    ;
    nProceso3           NUMBER(08)    ;
    nProceso4           NUMBER(08)    ;
 --
BEGIN
    nProceso  := 1111 ;
    nPID      := EAI_Owner.ProcessID.NextVal ;
--    nPID      := 1;
    EAI_Owner.Log_Start( nProceso ) ;
    INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
       VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
    nProceso3 := 0 ;
    nProceso4 := 0 ;

--    EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI_OWNER.INCONSISTENCIAS_TOTALES' ) ;
--      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES 
--        SELECT /*+ index(det) Index(Fact FACTURAS_IDX3) Index(R RT_IDX1)*/
--        'Diferencia entre Monto de Encabezado de Factura y Monto de Detalles de Factura' As Inconsistencia,
--        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, Fact.Invc_Dt As Fecha,Fact.Delivery_Status, 
--        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
--        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt,TO_NUMBER(Det.Amt,'999999999999.99') As Fact_Det_Amt,
--        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
--        --(Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
--        --(Select  Sum(Final_Amt) from Eai_Owner.Ped_det where Order_Num = Fact.Num_Pedido group by Order_Num) as Total_Det_Ped,
--        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
--        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1
--        FROM
--        (
--        SELECT /*+ Index (FACTURAS_IDX1)*/Doc_Num, Num_Pedido,
--        TO_DATE(Invc_Dt,'YYYY-MM-DD') As Invc_Dt, 
--        Invc_Status,Delivery_Status, Cte_Sap, Ttl_Invc_Amt, Paid_Amt, Num_Items
--        --,'YYYY-MM-DD HH24:MI:SS') 
--        FROM EAI_OWNER.Facturas
--        WHERE Id != 'ID'
--        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
--        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
--        AND Delivery_Status = 'Delivered'
--        AND Tipo != 'Pre Sales'
--        --AND DOC_NUM = 'V2505-00012'
--        ) Fact,
--        (
--        SELECT Invc_Doc_Num As Doc_Num, SUM(Nvl(TO_NUMBER(Final_Amt,'999999999999.99'),0)) Amt 
--        FROM EAI_OWNER.Fact_Det d
--        WHERE Id != 'ID'
--        --AND Invc_Doc_Num = 'V2505-00012'
--        Group By Invc_Doc_Num
--        ) Det
--        ,EAI_OWNER.Recurso_Territorio R
--        WHERE Fact.Doc_Num = Det.Doc_Num(+)
--        AND Fact.Ttl_Invc_Amt != Det.Amt
--        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
--        AND R.Territorio != 'NAME';
--      COMMIT ;
      
      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'Diferencia Entre Encabezado De Factura Y Encabezado De Pedido' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, Fact.Invc_Dt As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, Ped.Order_Status as Order_Status, 
        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL AS Fact_Det_Amt,
        (Select /*+ Index(P Pedidos_IDX3) */Order_Amt from Eai_Owner.Pedidos P where Name = Fact.Num_Pedido) AS Total_Pedido, NULL AS Total_Det_Ped,
        --(Select  Sum(Final_Amt) from Eai_Owner.Ped_det where Order_Num = Fact.Num_Pedido group by Order_Num) as Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT /*+Index(f Facturas_IDX1) */Doc_Num, Num_Pedido,
        TO_DATE(Invc_Dt,'YYYY-MM-DD') As Invc_Dt, 
        Invc_Status,Delivery_Status, Cte_Sap, Ttl_Invc_Amt, Paid_Amt, Num_Items
        --,'YYYY-MM-DD Hh24:Mi:Ss') 
        FROM EAI_OWNER.Facturas F
        WHERE Id != 'ID'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Delivery_Status = 'Delivered'
        AND Tipo != 'Pre Sales'
        --AND Doc_Num = 'V2505-00012'
        )Fact,
        (
        SELECT 
         Name, Order_Number,TO_DATE(Order_Dt,'YYYY-MM-DD') As Order_Dt, Order_Status, Cte_Sap, Net_Amt, Tax_Amt, Order_Amt, Dist_Fee, Num_Items
        FROM EAI_OWNER.Pedidos p
        WHERE Id != 'ID'
        AND Order_Status = 'Invoiced'
        AND Tipo != 'Pre Sales'
        )Ped
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Fact.Num_Pedido = Ped.Name
        AND Nvl(Fact.Ttl_Invc_Amt,0) != Nvl(Ped.Order_Amt,0)
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
        AND R.Territorio != 'NAME';
      COMMIT;
      
      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+ Index(Fact Facturas_IDX1)*/'Factura Sin Pedido' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status, 
        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL AS Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        --(Select  Sum(Final_Amt) from Eai_Owner.Ped_det where Order_Num = Fact.Num_Pedido group by Order_Num) as Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM 
        EAI_OWNER.Facturas Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Id != 'ID'
        AND  TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Delivery_Status = 'Delivered'
        AND Tipo != 'Pre Sales'
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
        AND R.Territorio != 'NAME'
        AND Not Exists (SELECT /*+ Index(ped Pedidos_IDX3)*/ 1 FROM EAI_OWNER.Pedidos Ped WHERE Ped.Name = Fact.Num_Pedido);
      COMMIT;      

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+Index (Fact Facturas_IDX1)*/'Factura Con Pedido En Estatus Diferente A Invoiced' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status, 
        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL AS Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE 
        FROM 
        EAI_OWNER.Facturas Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Id != 'ID'
        AND  TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Delivery_Status = 'Delivered'
        AND Tipo != 'Pre Sales'
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
        AND R.Territorio != 'NAME'
        AND Exists (SELECT 1 FROM EAI_OWNER.Pedidos Ped WHERE Ped.Name = Fact.Num_Pedido AND Ped.Order_Status != 'Invoiced');
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'Factura Sin Folio Fiscal' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status, 
        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL AS Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE 
        FROM
        (
        SELECT /*+ Index (f Facturas_IDX1)*/Doc_Num, Num_Pedido,
        TO_DATE(Invc_Dt,'YYYY-MM-DD') As Invc_Dt, 
        Invc_Status,Delivery_Status, Cte_Sap, Ttl_Invc_Amt, Paid_Amt, Num_Items
        FROM EAI_OWNER.Facturas f
        WHERE Id != 'ID'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Delivery_Status = 'Delivered'
        AND Tipo != 'Pre Sales'
        AND Doc_Num Is NULL
        --AND Doc_Num = 'V2505-00012'
        ) Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
        AND R.Territorio != 'NAME';
      COMMIT;
      
      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'N Facturas 1 Pedido' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status, 
        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL AS Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT /*+ Index (F Facturas_IDX1)*/Doc_Num, Num_Pedido,
        TO_DATE(Invc_Dt,'YYYY-MM-DD') As Invc_Dt, 
        Invc_Status,Delivery_Status, Cte_Sap, Ttl_Invc_Amt, Paid_Amt, Num_Items
        FROM EAI_OWNER.Facturas f
        WHERE Num_Pedido In 
        ( SELECT Num_Pedido FROM EAI_OWNER.Facturas f
          WHERE TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
          AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
          AND Delivery_Status = 'Delivered'
          Group By Num_Pedido Having Count(0) >1
        )
        AND Tipo != 'Pre Sales'
        )Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
        AND R.Territorio != 'NAME';
      COMMIT;
      
--      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
--        SELECT /*+ Index(Fact Facturas_IDX4)*/
--        'Diferencia Entre Encabezado De Pedido Y Detalles De Pedido' As Inconsistencia,
--        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
--        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status, 
--        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL AS Fact_Det_Amt,
--        (Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
--        (Select  Sum(Final_Amt) from Eai_Owner.Ped_det where Order_Num = Fact.Num_Pedido group by Order_Num) as Total_Det_Ped,
--        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
--        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1
--        FROM
--        (
--        SELECT 
--         Name, Order_Number,TO_DATE(Order_Dt,'YYYY-MM-DD') As Order_Dt, Order_Status, Cte_Sap, Net_Amt, Tax_Amt, Order_Amt, Dist_Fee, Num_Items
--        FROM EAI_OWNER.Pedidos p 
--        WHERE Id != 'ID'
--        AND TO_DATE(Order_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
--        AND TO_DATE(Order_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
--        AND Order_Status = 'Invoiced'
--        AND Tipo != 'Pre Sales'
--        )Ped,
--        (
--        SELECT Order_Num, SUM(Nvl(Final_Amt,0)) As Tot_Det_Ped 
--        FROM EAI_OWNER.Ped_Det pd
--        WHERE Id != 'ID'
--        Group By Order_Num
--        )Det_Ped,
--        EAI_OWNER.Facturas Fact
--        ,EAI_OWNER.Recurso_Territorio R
--        WHERE Ped.Name = Det_Ped.Order_Num
--        AND Ped.Order_Amt != Det_Ped.Tot_Det_Ped
--        AND Ped.Name = Fact.Num_Pedido
--        AND Fact.Tipo != 'Pre Sales'
--        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
--        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
--        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
--        AND R.Territorio != 'NAME';
--      COMMIT;
      
--      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
--        SELECT /*+Index(Det_Fact) index(fact) */'Diferencia Entre Detalles De Pedido Y Detalles De Factura' As Inconsistencia,
--        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Fact.Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
--        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
--        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt,TO_NUMBER(Det_Fact.Amt,'999999999999.99') As Fact_Det_Amt,
--        NULL AS Total_Pedido, (Select  Sum(Final_Amt) from Eai_Owner.Ped_det where Order_Num = Fact.Num_Pedido group by Order_Num) AS Total_Det_Ped,
--        --(Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
--        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
--        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1
--        FROM
--        (
--        SELECT /*+Parallel (pd,5)*/Order_Num, SUM(Nvl(Final_Amt,0)) As Tot_Det_Ped 
--        FROM EAI_OWNER.Ped_Det pd
--        Group By Order_Num
--        )Ped,
--        (
--        SELECT Invc_Doc_Num As Doc_Num, Order_Num As Order_Num, SUM(Final_Amt) Amt 
--        FROM EAI_OWNER.Fact_Det fd
--        Group By Invc_Doc_Num,Order_Num
--        )Det_Fact,
--        EAI_OWNER.Facturas Fact,
--        EAI_OWNER.Pedidos Pedido
--        ,EAI_OWNER.Recurso_Territorio R
--        WHERE Det_Fact.Doc_Num = Fact.Doc_Num
--        AND Det_Fact.Order_Num = Ped.Order_Num
--        AND Ped.Order_Num = Pedido.Name
--        AND Pedido.Order_Status = 'Invoiced'
--        AND Fact.Delivery_Status = 'Delivered'
--        AND Pedido.Order_Amt != Ped.Tot_Det_Ped
--        AND Fact.Tipo != 'Pre Sales'
--        AND Pedido.Tipo != 'Pre Sales'
--        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
--        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
--        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4)
--        AND R.Territorio != 'NAME';
--      COMMIT;
      
      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        select /*+ INDEX(Pag) Index(R RECURSOS_IDX2)*/
        'Pagos duplicados' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        Pag.Id AS PAGO_NAME, Pag.mobile_id AS PAGO_MOBILE_ID, TO_DATE(Substr(Created_Date,1,10)|| ' '|| Substr(Created_Date,12,8),'YYYY-MM-DD Hh24:Mi:Ss') -5/24 AS FECHA_PAGO, TO_NUMBER(Pag.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        select to_Date(payment_dt, 'yyyy-mm-dd') as fecha, TO_NUMBER(Payment_Amt,'999999999999.99') monto, doi_name,Cte_Sap, count(0) 
        from eai_owner.pagos p
        where to_Date(payment_dt, 'yyyy-mm-dd') > TRUNC(SYSDATE,'MM') 
        group by to_Date(payment_dt, 'yyyy-mm-dd') , payment_amt, doi_name, Cte_Sap
        having count(0) >1
        )Pg,
        EAI_OWNER.Pagos Pag
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Pg.doi_name = Pag.doi_name
        AND Pag.Id != 'NAME'
        and TO_NUMBER(pg.Monto,'999999999999.99') = TO_NUMBER(pag.Payment_Amt,'999999999999.99')
        and pg.fecha = to_Date(pag.payment_dt, 'yyyy-mm-dd') 
        AND Pag.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'Pagos Totalmente Aplicados A Más De Una Factura' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        Pag.Id AS PAGO_NAME, Pag.mobile_id AS PAGO_MOBILE_ID, TO_DATE(Substr(Created_Date,1,10)|| ' '|| Substr(Created_Date,12,8),'YYYY-MM-DD Hh24:Mi:Ss')-5/24 AS FECHA_PAGO, TO_NUMBER(Pag.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT /*+ Index (p Pagos_IDX3)*/Id, Count(0)
        FROM EAI_OWNER.Pagos p
        WHERE Id != 'NAME'
        AND Doi_Status = 'Closed'
        Group By Id
        Having Count(0) >1
        )Pg,
        EAI_OWNER.Pagos Pag
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Pg.Id = Pag.Id
        AND Pag.Id != 'NAME'
        AND Pag.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+ Index(Pag) Index(pg Pagos_IDX1)*/
        'Pagos Con Importe Total 0' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        Pag.Id AS PAGO_NAME, Pag.mobile_id AS PAGO_MOBILE_ID, TO_DATE(Substr(Created_Date,1,10)|| ' '|| Substr(Created_Date,12,8),'YYYY-MM-DD Hh24:Mi:Ss')-5/24 AS FECHA_PAGO, TO_NUMBER(Pag.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT/*+ Index(p Pagos_IDX3)*/ Id
        FROM EAI_OWNER.Pagos p
        WHERE Id != 'NAME'
        AND Nvl(Payment_Amt,'0.0') = '0.0' 
        AND Doi_Status = 'Closed'
        AND TO_DATE(Substr(NVL(p.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),1,10)|| ' '|| Substr(NVL(p.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),12,8),'YYYY-MM-DD Hh24:Mi:Ss') -5/24 > TRUNC(SYSDATE,'MM') 
        )Pg,
        EAI_OWNER.Pagos Pag
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Pg.Id = Pag.Id
        AND Pag.Id != 'NAME'
        AND TO_DATE(Substr(NVL(pag.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),1,10)|| ' '|| Substr(NVL(pag.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),12,8),'YYYY-MM-DD Hh24:Mi:Ss') -5/24 > TRUNC(SYSDATE,'MM') 
        AND Pag.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+Index (doi DEBIT_OPEN_ITEM_IDX8 ) */'DOI Pagado en Exceso' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        P.Cte_Sap, P.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        P.Id AS PAGO_NAME, P.mobile_id AS PAGO_MOBILE_ID,
        TO_DATE(Substr(p.Created_Date,1,10)|| ' '|| Substr(p.Created_Date,12,8),'YYYY-MM-DD HH24:MI:SS')-5/24 AS FECHA_PAGO, 
        TO_NUMBER(P.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, P.Doi_Name AS DOI, 
        TO_DATE(Substr(NVL(DOI.Created_Date,p.Created_Date),1,10)|| ' '|| Substr(NVL(DOI.Created_Date,p.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 AS FECHA_DOI,
        DOI.Status AS STATUS_DOI, TO_NUMBER(Doi_Amt,'999999999999.99') AS MONTO_DOI, DOI.Paid_Amount AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM EAI_OWNER.Pagos p
        ,EAI_OWNER.Debit_Open_Item DOI
        ,EAI_OWNER.Recurso_Territorio R
        WHERE p.Id != 'NAME'
        AND TO_NUMBER(Payment_Amt,'999999999999.99') >  TO_NUMBER(Doi_Amt,'999999999999.99')
        AND TO_DATE(Substr(NVL(DOI.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),1,10)|| ' '|| Substr(NVL(DOI.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),12,8),'YYYY-MM-DD Hh24:Mi:Ss') -5/24 > TRUNC(SYSDATE,'MM') 
        AND Doi_Status = 'Closed'
        AND Doi.Name = P.Doi_Name
        AND p.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT Distinct 'Debit Open Item Cuyo Importe Asociado Es Menor A La SUMa De Sus Pagos' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        Pag.Id AS PAGO_NAME, Pag.mobile_id AS PAGO_MOBILE_ID,
        TO_DATE(Substr(Pag.Created_Date,1,10)|| ' '|| Substr(Pag.Created_Date,12,8),'YYYY-MM-DD HH24:MI:SS')-5/24 AS FECHA_PAGO, 
        TO_NUMBER(Pag.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, 
        TO_DATE(Substr(NVL(DOI.Created_Date,Pag.Created_Date),1,10)|| ' '|| Substr(NVL(DOI.Created_Date,Pag.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 AS FECHA_DOI,
        DOI.Status AS STATUS_DOI, TO_NUMBER(Doi_Amt,'999999999999.99') AS MONTO_DOI, DOI.Paid_Amount AS MONTO_APLICADO_DOI, TO_NUMBER(Pagr.Total_Pagos,'999999999999.99') AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT Doi_Name, SUM(TO_NUMBER(Payment_Amt,'999999999999.99')) As Total_Pagos,   TO_NUMBER(Doi_Paid_Amt,'999999999999.99') As Importe_Asignado
        FROM EAI_OWNER.Pagos p 
        WHERE Id != 'NAME'
        AND TO_DATE(Substr(NVL(p.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),1,10)|| ' '|| Substr(NVL(p.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),12,8),'YYYY-MM-DD Hh24:Mi:Ss') -5/24 > TRUNC(SYSDATE,'MM') 
        --AND Doi_Name Not In ( 'DPI-1457396','DPI-1457373','DPI-1457398','DPI-1457372')
        Group By Doi_Name,Doi_Paid_Amt
        )Pagr,
        EAI_OWNER.Pagos Pag
        ,EAI_OWNER.Debit_Open_Item DOI
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Pag.Doi_Name = Pagr.Doi_Name
        AND Pag.Id != 'NAME'
        --AND Pag.Doi_Name Not In ( 'DPI-1457396','DPI-1457373','DPI-1457398','DPI-1457372')
        AND TO_NUMBER(Pagr.Importe_Asignado,'999999999999.99') < TO_NUMBER(Pagr.Total_Pagos,'999999999999.99')
        AND TO_DATE(Substr(NVL(pag.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),1,10)|| ' '|| Substr(NVL(pag.Created_Date,to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')),12,8),'YYYY-MM-DD Hh24:Mi:Ss') -5/24 > TRUNC(SYSDATE,'MM') 
        AND Pag.Doi_Status = 'Closed'
        AND Doi.Name(+) = PAG.Doi_Name
        AND pAG.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT Distinct 'Debit Open Item Cuyo Importe Asociado Es Menor A La SUMa De Sus Pagos' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        Pag.Id AS PAGO_NAME, Pag.mobile_id AS PAGO_MOBILE_ID,
        TO_DATE(Substr(Pag.Created_Date,1,10)|| ' '|| Substr(Pag.Created_Date,12,8),'YYYY-MM-DD HH24:MI:SS')-5/24 AS FECHA_PAGO, 
        TO_NUMBER(Pag.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, 
        TO_DATE(Substr(NVL(DOI.Created_Date,Pag.Created_Date),1,10)|| ' '|| Substr(NVL(DOI.Created_Date,Pag.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 AS FECHA_DOI,
        DOI.Status AS STATUS_DOI, TO_NUMBER(Doi_Amt,'999999999999.99') AS MONTO_DOI, DOI.Paid_Amount AS MONTO_APLICADO_DOI, TO_NUMBER(Pagr.Total_Pagos,'999999999999.99') AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT Doi_Name, SUM(TO_NUMBER(Payment_Amt,'999999999999.99')) As Total_Pagos,   TO_NUMBER(Doi_Paid_Amt,'999999999999.99') As Importe_Asignado
        FROM EAI_OWNER.Pagos p 
        WHERE Id != 'NAME'
        --AND Doi_Name Not In ( 'DPI-1457396','DPI-1457373','DPI-1457398','DPI-1457372')
        Group By Doi_Name,Doi_Paid_Amt
        )Pagr,
        EAI_OWNER.Pagos Pag
        ,EAI_OWNER.Debit_Open_Item DOI
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Pag.Doi_Name = Pagr.Doi_Name
        AND Pag.Id != 'NAME'
        --AND Pag.Doi_Name Not In ( 'DPI-1457396','DPI-1457373','DPI-1457398','DPI-1457372')
        AND TO_NUMBER(Pagr.Importe_Asignado,'999999999999.99') > TO_NUMBER(Pagr.Total_Pagos,'999999999999.99')
        AND Pag.Doi_Status = 'Closed'
        AND Doi.Name(+) = PAG.Doi_Name
        AND pAG.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT  Distinct 'Debit Open Item pagada y con estatus incorrecto'  As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, 
        TO_DATE(Substr(NVL(DOI.Created_Date,Pag.Created_Date),1,10)|| ' '|| Substr(NVL(DOI.Created_Date,Pag.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 AS FECHA_DOI,
        DOI.Status AS STATUS_DOI, TO_NUMBER(Doi_Amt,'999999999999.99') AS MONTO_DOI, DOI.Paid_Amount AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT Doi_Name, SUM(TO_NUMBER(Payment_Amt,'999999999999.99')) As Total_Pagos,   TO_NUMBER(Doi_Paid_Amt,'999999999999.99') As Importe_Asignado
        FROM EAI_OWNER.Pagos p 
        WHERE Id != 'NAME'
        Group By Doi_Name,Doi_Paid_Amt
        )Pagr,
        EAI_OWNER.Pagos Pag,
        EAI_OWNER.Debit_Open_Item DOI
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Pag.Doi_Name = Pagr.Doi_Name
        AND Pag.Doi_Name = Doi.Name
        AND Pag.Id != 'NAME'
        AND TO_NUMBER(Pag.doi_amt,'999999999999.99') = TO_NUMBER(Pagr.Total_Pagos,'999999999999.99')
        and TO_DATE(Substr(Pag.Created_Date,1,10)|| ' ' || Substr(Pag.Created_Date,12,8),'YYYY-MM-DD Hh24:Mi:Ss') > TRUNC(SYSDATE,'MM') --
        AND DOI.Status != 'Closed'
        AND pAG.territorio = R.Territorio(+)
        AND (TO_DATE(DOI.EXTRACT_DT, 'YYYY-MM-DD HH24:MI:SS') - (SELECT /*+ Index(d) */TO_DATE(Substr(LAST_MOD_DT,1,10)|| ' ' || Substr(LAST_MOD_DT,12,8),'YYYY-MM-DD Hh24:Mi:Ss') AS FECHA 
                        FROM EAI_OWNER.DEBIT_OPEN_ITEM d WHERE NAME = Pag.Doi_Name)) >2;
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'Facturas Collected Sin Asignacion' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        TO_NUMBER(Paid_Amt,'999999999999.99') AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        --(Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
        --(Select  Sum(Final_Amt) from Eai_Owner.Ped_det where Order_Num = Fact.Num_Pedido group by Order_Num) as Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM EAI_OWNER.Facturas Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Id != 'ID'
        AND TO_NUMBER(Paid_Amt,'999999999999.99') = 0
        AND Invc_Status = 'Collected'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+ Index(p)*/'Pagos Sin Cliente' As Inconsistencia, 
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        Pag.Id AS PAGO_NAME, Pag.mobile_id AS PAGO_MOBILE_ID, TO_DATE(Substr(Created_Date,1,10)|| ' '|| Substr(Created_Date,12,8),'YYYY-MM-DD Hh24:Mi:Ss') -5/24 AS FECHA_PAGO, TO_NUMBER(Pag.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        --Invc_Doc_Num As Doc_Num, NULL As Det_Doc_Num, Doi_Status As Delivery_Status, Id As Num_Pedido, TO_DATE(Substr(Created_Date,1,10),'YYYY-MM-DD') As Fecha, Cte_Sap, TO_NUMBER(Payment_Amt,'999999999999.99') As Ttl_Invc_Amt, TO_NUMBER(Doi_Paid_Amt,'999999999999.99') As Order_Amt, NULL As Ped_Det_Amt, NULL As Fact_Det_Amt 
        FROM EAI_OWNER.Pagos pag
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Id != 'NAME'
        AND Nvl(Cte_Sap,0) = 0
        AND Pag.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+ Index(Fact Facturas_IDX2)*/
        'Facturas En 0' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Det_Ped,
        (Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM EAI_OWNER.Facturas Fact,
        EAI_OWNER.Recurso_Territorio R
        WHERE Id != 'ID'
        AND TO_NUMBER(Nvl(Fact.Ttl_Invc_Amt,0),'999999999999.99') = 0
        AND Fact.Delivery_Status = 'Delivered'
        AND Fact.Tipo != 'Pre Sales'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+Index (Fact Facturas_IDX1)*/
        'Facturas sin Debit Open Item' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
        NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Det_Ped,
        (Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM EAI_OWNER.Facturas Fact,
        EAI_OWNER.Recurso_Territorio R
        WHERE Fact.Id != 'ID'
        AND Fact.Tipo != 'Pre Sales'
        AND Delivery_Status = 'Delivered'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND NOT EXISTS (SELECT /*+ Index(d)*/1 FROM EAI_OWNER.DEBIT_OPEN_ITEM d WHERE DOC_NUM = Fact.Doc_Num)
        AND (TO_DATE(SUBSTR(Fact.EXTRACT_DT,1,10), 'YYYY-MM-DD') - TO_DATE(Invc_Dt,'YYYY-MM-DD'))>1  
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'Facturas Con Importe Asociado Mayor Al Total De La Factura' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
        Fact.Paid_Amt AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Det_Ped,
        (Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        --Fact.Doc_Num, NULL As Det_Doc_Num, Fact.Delivery_Status, Fact.Num_Pedido, TO_DATE(Fact.Invc_Dt,'YYYY-MM-DD') As Fecha, Fact.Cte_Sap, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, TO_NUMBER(Fact.Paid_Amt,'9999999999999.99') Order_Amt, NULL As Ped_Det_Amt, NULL As Fact_Det_Amt
        FROM EAI_OWNER.Facturas Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Fact.Id != 'ID'
        AND TO_NUMBER(Fact.Paid_Amt,'9999999999999.99') > 0 
        AND TO_NUMBER(Fact.Paid_Amt,'9999999999999.99') > TO_NUMBER(Fact.Ttl_Invc_Amt,'9999999999999.99')
        AND Fact.Tipo != 'Pre Sales'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'Facturas Con Importe Asociado Igual Al Total De La Factura Con Estatus Diferente De Collected' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
        Fact.Paid_Amt AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Det_Ped,
        (Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM EAI_OWNER.Facturas Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Fact.Id != 'ID'
        AND TO_NUMBER(Fact.Paid_Amt,'9999999999999.99') > 0
        AND TO_NUMBER(Fact.Ttl_Invc_Amt,'9999999999999.99') > 0
        AND Invc_Status != 'Collected' 
        AND TO_NUMBER(Fact.Paid_Amt,'9999999999999.99') = TO_NUMBER(Fact.Ttl_Invc_Amt,'9999999999999.99')
        AND Fact.Tipo != 'Pre Sales'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 
        'Facturas Sin Cliente' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
        Fact.Paid_Amt AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Det_Ped,
        (Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM EAI_OWNER.Facturas Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Id != 'ID'
        AND Nvl(Cte_Sap,'0') = '0' 
        AND Delivery_Status = 'Delivered'
        AND Fact.Tipo != 'Pre Sales' 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT
        'Facturas Sin Recurso Asociado' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
        Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
        Fact.Paid_Amt AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Det_Ped,
        (Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE 
        FROM EAI_OWNER.Facturas Fact
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Id != 'ID'
        AND Nvl(Recurso,'0') = '0'
        AND Delivery_Status = 'Delivered'
        AND Fact.Tipo != 'Pre Sales'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND Substr(Fact.Doc_Num, 2,4) = Substr(R.Territorio,17,4);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+ Index(pag PAGOS_IDX1)*/
        'Pagos Sin Factura' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        Pag.Cte_Sap, Pag.Invc_Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        Pag.Id AS PAGO_NAME, Pag.mobile_id AS PAGO_MOBILE_ID, TO_DATE(Substr(Created_Date,1,10)|| ' '|| Substr(Created_Date,12,8),'YYYY-MM-DD Hh24:Mi:Ss')-5/24 AS FECHA_PAGO, TO_NUMBER(Pag.Payment_Amt,'999999999999.99') AS IMPORTE_PAGO, Pag.Doi_Name AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        --Pag.Id As Doc_Num, NULL As Det_Doc_Num, Pag.Doi_Status As Delivery_Status, Pag.Doi_Name As Num_Pedido, TO_DATE(Substr(Created_Date,1,10),'YYYY-MM-DD') As Fecha, Pag.Cte_Sap, TO_NUMBER(Pag.Payment_Amt,'999999999999.99') As Ttl_Invc_Amt, TO_NUMBER(Pag.Doi_Amt,'999999999999.99') Order_Amt, NULL As Ped_Det_Amt, NULL As Fact_Det_Amt
        FROM EAI_OWNER.Recurso_Territorio R 
        ,EAI_OWNER.Pagos Pag
        WHERE Doi_Status != 'Open' 
        AND Pag.territorio = R.Territorio(+)
        and (select NVL(doc_num,'0') from eai_owner.debit_open_item where name = Pag.DOI_Name) = '0'
        AND Pag.Payment_Amt >0;
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+ Index(R RECURSOS_IDX2)*/
        'Debit Open Item Con Importe Asociado Sin Pago' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        DOI.Cliente_Sap as Cte_SAP, DOI.Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, DOI.Name AS DOI, 
        TO_DATE(Substr((DOI.Created_Date),1,10)|| ' '|| Substr((DOI.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 AS FECHA_DOI,
        DOI.Status AS STATUS_DOI, TO_NUMBER(Doi.Amount,'999999999999.99') AS MONTO_DOI, DOI.Paid_Amount AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        --Doi.Name As Doc_Num, NULL As Det_Doc_Num, Doi.Status As Delivery_Status, NULL As Num_Pedido, TO_DATE(Issued_Date,'YYYY-MM-DD') As Fecha, Doi.Cliente_Sap As Cte_Sap, Doi.Amount As Ttl_Invc_Amt, Doi.Paid_Amount Order_Amt, NULL As Ped_Det_Amt, NULL As Fact_Det_Amt 
        FROM EAI_OWNER.Debit_Open_Item Doi
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Nvl(Doi.Paid_Amount,0) >0
        AND Status = 'Closed'
        AND TO_DATE(SUBSTR(Created_Date,1,10),'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(SUBSTR(LAST_MOD_DT,1,10),'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND NOT Exists (SELECT 1 FROM EAI_OWNER.Pagos WHERE Doi_Name = Doi.Name)
        AND DOI.territorio = R.Territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT /*+ Index(R RECURSOS_IDX2)*/
        'Debit Open Item En Estatus Closed Con Monto Total Mayor Al Asociado Y Sin Monto Restante' As Inconsistencia,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        DOI.Cliente_Sap as Cte_SAP, DOI.Doc_Num as Factura, NULL As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, DOI.Name AS DOI, 
        TO_DATE(Substr((DOI.Created_Date),1,10)|| ' '|| Substr((DOI.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 AS FECHA_DOI,
        DOI.Status AS STATUS_DOI, TO_NUMBER(Doi.Amount,'999999999999.99') AS MONTO_DOI, DOI.Paid_Amount AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CONSECUTIVO_INICIAL, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE 
        FROM EAI_OWNER.Debit_Open_Item Doi
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Nvl(Amount,0) > Nvl(Doi.Paid_Amount,0)
        AND Nvl(OutstANDing_Amount,0) = 0
        AND Status = 'Closed'
        AND TO_DATE(SUBSTR(Created_Date,1,10),'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND Doi.Territorio = R.territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 'Credit Note con monto aplicado y monto restante mayor a 0 y sin flag de IS_USED' AS INCONSISTENCIA, 
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        CN.CTE_Sap as Cte_SAP, NULL as Factura, TO_DATE(Substr((CN.Created_Date),1,10)|| ' '|| Substr((CN.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, NULL AS DOI, 
        NULL AS FECHA_DOI,
        NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, CN.NAME AS CN_NAME, CN.CN_KEY AS CN_KEY, CN.STATUS AS CN_STATUS, CN.IS_USED AS CN_IS_USED_FLG, CN.SR_ORDER_NAME AS SR_ORDER_NAME,  CN.AMOUNT AS CN_AMOUNT, CN.APP_AMT AS CN_APP_AMT, CN.ACTUAL_AMT AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE 
        FROM EAI_OWNER.Credit_Notes CN
        ,EAI_OWNER.Recurso_Territorio R
        WHERE Status ='Confirmed'
        AND UPPER(Is_Used) = 'FALSE'
        AND ROUND(NVL(ACTUAL_AMT,0),2) >0
        AND ROUND(NVL(APP_AMT,0),2) > 0
        AND CN.Territorio = R.territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 'Credit Note con monto total y monto restante iguales, CON flag de IS_USED y sin monto aplicado' AS INCONSISTENCIA, 
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        CN.CTE_Sap as Cte_SAP, NULL as Factura, TO_DATE(Substr((CN.Created_Date),1,10)|| ' '|| Substr((CN.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, NULL AS DOI, 
        NULL AS FECHA_DOI,
        NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, CN.NAME AS CN_NAME, CN.CN_KEY AS CN_KEY, CN.STATUS AS CN_STATUS, CN.IS_USED AS CN_IS_USED_FLG, CN.SR_ORDER_NAME AS SR_ORDER_NAME,  CN.AMOUNT AS CN_AMOUNT, CN.APP_AMT AS CN_APP_AMT, CN.ACTUAL_AMT AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE  
        FROM EAI_OWNER.Credit_Notes CN
        ,EAI_OWNER.Recurso_Territorio R
        WHERE CN.Status ='Confirmed'
        AND UPPER(CN.Is_Used) = 'TRUE'
        AND ROUND(NVL(CN.ACTUAL_AMT,0),2) = ROUND(NVL(CN.AMOUNT,0),2)
        AND ROUND(NVL(CN.APP_AMT,0),2)= 0
        AND CN.Territorio = R.territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 'Credit Note con monto total y monto aplicado iguales, CON flag de IS_USED y con monto restante > 0' AS INCONSISTENCIA, 
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        CN.CTE_Sap as Cte_SAP, NULL as Factura, TO_DATE(Substr((CN.Created_Date),1,10)|| ' '|| Substr((CN.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, NULL AS DOI, 
        NULL AS FECHA_DOI,
        NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, CN.NAME AS CN_NAME, CN.CN_KEY AS CN_KEY, CN.STATUS AS CN_STATUS, CN.IS_USED AS CN_IS_USED_FLG, CN.SR_ORDER_NAME AS SR_ORDER_NAME, CN.AMOUNT AS CN_AMOUNT, CN.APP_AMT AS CN_APP_AMT, CN.ACTUAL_AMT AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE 
        FROM EAI_OWNER.Credit_Notes CN
        ,EAI_OWNER.Recurso_Territorio R
        WHERE CN.Status ='Confirmed'
        AND UPPER(CN.Is_Used) = 'TRUE'
        AND ROUND(NVL(CN.APP_AMT,0),2) = ROUND(NVL(CN.AMOUNT,0),2)
        AND ROUND(NVL(CN.ACTUAL_AMT,0),2) >0
        AND TO_DATE(FECHA,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND CN.Territorio = R.territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 'Credit Note SIN USAR y con asignaciones' AS INCONSISTENCIA, 
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
        CN.CTE_Sap as Cte_SAP, NULL as Factura, TO_DATE(Substr((CN.Created_Date),1,10)|| ' '|| Substr((CN.Created_Date),12,8),'YYYY-MM-DD Hh24:MI:SS')-5/24 As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, NULL AS DOI, 
        NULL AS FECHA_DOI,
        NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, CN.NAME AS CN_NAME, CN.CN_KEY AS CN_KEY, CN.STATUS AS CN_STATUS, CN.IS_USED AS CN_IS_USED_FLG, CN.SR_ORDER_NAME AS SR_ORDER_NAME, CN.AMOUNT AS CN_AMOUNT, CN.APP_AMT AS CN_APP_AMT, CN.ACTUAL_AMT AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
        ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM EAI_OWNER.Credit_Notes CN
        ,EAI_OWNER.Recurso_Territorio R
        WHERE CN.Status ='Confirmed'
        AND UPPER(CN.Is_Used) = 'FALSE'
        AND ROUND(NVL(CN.APP_AMT,0),2) = 0
        AND EXISTS (SELECT 1 FROM EAI_OWNER.PAGOS PAG WHERE PAG.CN_KEY = CN.CN_KEY )
        AND CN.Territorio = R.territorio(+);
      COMMIT;

      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT 'SKUs sin precio en LP' AS INCONSISTENCIA,
        NULL AS Region, NULL AS Area, NULL AS Territorio, NULL AS Recurso, 
        NULL AS CTE_Sap , NULL as Factura, TO_DATE(VALID_TO, 'YYYY-MM-DD') As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, NULL AS DOI, 
        NULL AS FECHA_DOI,
        NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS,
        SKU AS SKU, PRICE_LIST AS PRICE_LIST, SKU_NAME AS SKU_NAME, PRICE_ON_UOM_1 AS PRICE_UOM1, SYSDATE 
        FROM EAI_OWNER.PRECIOS
        WHERE NVL(ROUND(PRICE_ON_UOM_1,2),0) = 0;
      COMMIT;
      
      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        SELECT DISTINCT 'Desfase en la secuencia de la mascara fiscal (Invoices)' AS INCONSISTENCIA,
        R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso,
        NULL AS CTE_Sap , DOC_NUM as Factura, Fecha As Fecha,NULL AS Delivery_Status, 
        NULL AS Invc_Status, NULL AS Num_Pedido, NULL as Order_Status,
        NULL AS Paid_Amt, NULL As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
        NULL AS Total_Pedido, NULL AS Total_Det_Ped,
        NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID,
        NULL FECHA_PAGO, 
        NULL AS IMPORTE_PAGO, NULL AS DOI, 
        NULL AS FECHA_DOI,
        NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, 
        NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, 
        SUFIJO_ANTERIOR AS CONSECUTIVO_INICIAL, SUFIJO AS CONSECUTIVO_FINAL, 
        CASE WHEN ((ABS(NVL(TO_NUMBER(SUFIJO,'99999999999999999.99'),0) - NVL(TO_NUMBER(SUFIJO_ANTERIOR,'99999999999999999.99'),0)))-1)>15 
         THEN 'Posible Cambio de Transaction Secuence'
         ELSE 'Posible perdida de facturas en la sincronizacion'
        END AS POSIBLE_FALLA, 
        CASE WHEN ((ABS(NVL(TO_NUMBER(SUFIJO,'99999999999999999.99'),0) - NVL(TO_NUMBER(SUFIJO_ANTERIOR,'99999999999999999.99'),0)))-1)>15 
         THEN 'Posible Cambio de Transaction Secuence'
         ELSE TO_CHAR((ABS(NVL(TO_NUMBER(SUFIJO,'99999999999999999.99'),0) - NVL(TO_NUMBER(SUFIJO_ANTERIOR,'99999999999999999.99'),0)))-1)
        END AS FOLIOS_PERDIDOS,
        NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE
        FROM
        (
        SELECT /*+ Index(B Facturas_IDX1)*/
           RECURSO,
           DOC_NUM,
           TO_DATE(Substr(Created_Date,1,10)|| ' '|| Substr(Created_Date,12,8),'YYYY-MM-DD Hh24:Mi:Ss') FECHA,
           SUBSTR(DOC_NUM, 1,6) AS PREFIJO, 
           LAG(SUBSTR(DOC_NUM, 7,(LENGTH(DOC_NUM))),1,SUBSTR(DOC_NUM, 7,(LENGTH(DOC_NUM)))) OVER(PARTITION BY SUBSTR(DOC_NUM, 1,5) ORDER BY SUBSTR(DOC_NUM, 1,6),SUBSTR(DOC_NUM, 7,(LENGTH(DOC_NUM))) ASC) SUFIJO_ANTERIOR,
           SUBSTR(DOC_NUM, 7,(LENGTH(DOC_NUM))) SUFIJO
        FROM EAI_OWNER.FACTURAS_B B
        WHERE SUBSTR(DOC_NUM, 1,1) IN ('V','D')
        and SUBSTR(DOC_NUM, 1,1) not IN ('VP','DP')
        and SUBSTR(DOC_NUM, 6,1) != 'A'
        AND SUBSTR(DOC_NUM, 7,(LENGTH(DOC_NUM))) NOT LIKE '%TESTING%'
        AND B.Tipo != 'Pre Sales'
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') > TRUNC(SYSDATE,'MM') 
        AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        AND (DOC_NUM NOT LIKE '%-A' AND DOC_NUM NOT LIKE '%_A' AND DOC_NUM NOT LIKE '%-B' AND DOC_NUM NOT LIKE '%_B' AND DOC_NUM NOT LIKE '%-C' AND DOC_NUM NOT LIKE '%_C' AND DOC_NUM NOT LIKE '%-D' AND DOC_NUM NOT LIKE '%_D' AND DOC_NUM NOT LIKE '%-E' AND DOC_NUM NOT LIKE '%_E' AND DOC_NUM NOT LIKE '%-F' AND DOC_NUM NOT LIKE '%_F')
        --AND TO_DATE(Invc_Dt,'YYYY-MM-DD') < TRUNC(SYSDATE)
        --AND RECURSO = 'JOSE DE JESUS LOPEZ JIMENEZ'
        )da,
        eai_owner.recurso_territorio r
        where ABS(NVL(TO_NUMBER(SUFIJO,'99999999999999999.99'),0) - NVL(TO_NUMBER(SUFIJO_ANTERIOR,'99999999999999999.99'),0))>1
        and da.recurso = r.resource_name;
      COMMIT;
      
      INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
       SELECT /*+ Index(Fact FACTURAS_IDX3) Index(R RT_IDX1)*/
       'Facturas No Entregadas o Re-Programadas hace 4 dias' As Inconsistencia,
       R.Region, R.Area, R.Territorio, R.Resource_Name as Recurso, 
       Fact.Cte_Sap, Fact.Doc_Num as Factura, TO_DATE(Fact.Invc_Dt,'YYYY-MM-DD') As Fecha,Fact.Delivery_Status, 
       Fact.Invc_Status, Fact.Num_Pedido, (Select  Order_Status from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Order_Status,
       NULL AS Paid_Amt, TO_NUMBER(Fact.Ttl_Invc_Amt,'999999999999.99') As Ttl_Invc_Amt, NULL As Fact_Det_Amt,
       NULL AS Total_Pedido, NULL AS Total_Det_Ped,
       --(Select  Order_Amt from Eai_Owner.Pedidos where Name = Fact.Num_Pedido) as Total_Pedido,
       --(Select  Sum(Final_Amt) from Eai_Owner.Ped_det where Order_Num = Fact.Num_Pedido group by Order_Num) as Total_Det_Ped,
       NULL AS PAGO_NAME, NULL AS PAGO_MOBILE_ID, NULL AS FECHA_PAGO, NULL AS IMPORTE_PAGO, NULL AS DOI, NULL AS FECHA_DOI, NULL AS STATUS_DOI, NULL AS MONTO_DOI, NULL AS MONTO_APLICADO_DOI, NULL AS SUMA_PAGOS, NULL AS CN_NAME, NULL AS CN_KEY, NULL AS CN_STATUS, NULL AS CN_IS_USED_FLG, NULL AS SR_ORDER_NAME, NULL AS CN_AMOUNT, NULL AS CN_APP_AMT, NULL AS CN_MONTO_RESTANTE, NULL AS CONSECUTIVO_INICIAL, NULL AS CONSECUTIVO_FINAL, NULL AS POSIBLE_FALLA, NULL AS FOLIOS_PERDIDOS
       ,NULL AS SKU, NULL AS PRICE_LIST, NULL AS SKU_NAME, NULL AS PRICE_UOM1, SYSDATE 
       from eai_owner.facturas fact
       ,EAI_OWNER.Recurso_Territorio R
       WHERE Fact.Delivery_Terr = R.Territorio
       AND R.Territorio != 'NAME' 
       AND fact.tipo = 'Pre Sales' 
       and fact.delivery_status in ('Not delivered','Reschedule Requested')
       and to_date(fact.invc_dt,'yyyy-mm-dd') < trunc(sysdate -4); 
      COMMIT;

    UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_3 = nProceso3,
                                                  Proceso_2 = 0, Proceso_4 = nProceso4
       WHERE PID = nPID  ;          
    COMMIT ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
          ( DIRECTION          , ID                 , CREATED             , MESSAGE        , JOB_PID,
            STATUS             , QUEUE_NAME         , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE  , RETRY_COUNT        , SEQUENCE            , PARENT_ROW_ID   ) 
        VALUES  
          ( 'Job Logging'      , NULL               , SYSDATE             , NULL           , nPID   ,
            'Error'            , 'SF_INCONSISTENCIAS'   , sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL               , NULL                , NULL            ) ;
        COMMIT ;   
END SF_INCONSISTENCIAS ;
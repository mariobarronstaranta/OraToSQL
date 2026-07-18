create or replace PROCEDURE    WA_UPD_SUBDEPOSITOS
   ( pFactura IN  VARCHAR2 )
IS
   sMsg       VARCHAR2(0500) ;
   sFactura   VARCHAR2(0020) ;
   nDoctos    NUMBER(06)     ;
   sEtapa     VARCHAR2(0020) ;
   sProcesar  VARCHAR2(0004) ;
--   
   dtFecha_Proc_BATMD DATE  ;
--
   strID       VARCHAR2(050) ;
   sAccnt_ID   VARCHAR2(050) ;
   sClienteSAP VARCHAR2(010) ;
--   
   CURSOR ScrHeader IS
      SELECT MC.Cliente_SAP, MC.Cliente_V3, SUBD.Direccion_1, SUBD.Colonia_1, 
             SUBD.Ciudad_1, SUBD.Estado_1, SUBD.Codigo_Postal_1
         FROM T3.WA_SUBDEPOSITOS SUBD , T3.Mov_Cliente MC
         WHERE SUBD.Cliente_SAP IS NOT NULL
           AND SUBD.Cliente_SAP = MC.Cliente_SAP ;
--
BEGIN
   strID     := pFactura ;
   sProcesar := 'SI' ;
   FOR JAU IN ScrHeader LOOP
      UPDATE T3.Mov_Cliente SET Direccion_1     = JAU.Direccion_1    ,
                                Colonia_1       = JAU.Colonia_1      ,
                                Ciudad_1        = JAU.Ciudad_1       ,
                                Estado_1        = JAU.Estado_1       ,
                                Codigo_Postal_1 = JAU.Codigo_Postal_1
         WHERE Cliente_V3 = JAU.Cliente_V3 ;                       
   END LOOP ;
   UPDATE T3.Remision_General SET ShiptoParty = Destino
      WHERE Destino     LIKE 'MX%'
        AND Fecha_Trn      > SYSDATE - 30
        AND ShiptoParty   IS NULL ;
   UPDATE T3.Remision_General SET ShiptoParty = REPLACE( ShiptoParty, 'PC-00-', '' )
      WHERE ShiptoParty     LIKE 'PC-00-MX%'
        AND Fecha_Trn      > SYSDATE - 30 ;
  COMMIT ;
--
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'WA_UPD_SUBDEPOSITOS' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'WA_UPD_SUBDEPOSITOS', strID, sMsg ) ;
      COMMIT ;
END WA_UPD_SUBDEPOSITOS ;
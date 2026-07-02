create or replace FUNCTION     "CONV_FECHA_MANTIS" 
   ( dtFecha DATE  )  RETURN  VARCHAR2
IS
   dtReturn    DATE         ;
   nReturn     NUMBER(14)   ;
   sReturnRet  VARCHAR2(14) ;   
   
BEGIN
     SELECT 
            Info.Ref_Fecha + Info.DifFecha                                           AS Fecha_Calculada ,
            Info.Ref_Valor + ( Info.DifFecha * 86400 )                               AS Fecha_Mantis_Num
        INTO dtReturn, nReturn    
        FROM (
               SELECT dtFecha                                                           AS Fecha    ,
                      dtFecha - RD.Referencia                                           AS DifFecha ,
                      RD.Referencia                                                     AS Ref_Fecha,
                      RD.Valor_Ref                                                      AS Ref_Valor
                  FROM Z_Mantis_Date_Ref RD ) Info ;
     sReturnRet := TRIM( TO_CHAR( nReturn ) ) ;
     RETURN sReturnRet ;
END CONV_FECHA_MANTIS ;
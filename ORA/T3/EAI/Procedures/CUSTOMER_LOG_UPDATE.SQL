create or replace PROCEDURE       "CUSTOMER_LOG_UPDATE" 
   ( v_Cliente_V3  IN VARCHAR2,
     v_Opcion      IN VARCHAR2,
     v_dtFecha     IN DATE  DEFAULT SYSDATE    ) IS
--
   CURSOR ScrDatos IS
      SELECT MAX( Fecha_Replicacion ), MAX( Fecha_Insert )
         FROM EAI.CUSTOMER_LOG
         WHERE Cliente_V3 = v_Cliente_V3 ;
--
   dtFechaReplicacion    DATE         ;
   dtFechaInsert         DATE         ;
   sInsert               VARCHAR2(02) ;
BEGIN
   sInsert := 'NO' ;
   IF ( v_Opcion = 'Replicate' ) THEN
      INSERT INTO EAI.CUSTOMER_LOG
         ( Cliente_V3, Fecha_Replicacion, Fecha_Insert )
      VALUES
         ( v_Cliente_V3, v_dtFecha, SYSDATE ) ;
   ELSE
      OPEN ScrDatos ;
      FETCH ScrDatos INTO dtFechaReplicacion, dtFechaInsert ;
      IF SQL%NOTFOUND THEN
         dtFechaInsert := NULL ;
      END IF ;
      CLOSE ScrDatos ;
      IF ( dtFechaInsert IS NULL ) THEN
         sInsert := 'SI' ;
      END IF ;      
      IF ( v_Opcion = 'Sync' ) THEN
         IF ( sInsert = 'SI' ) THEN
            INSERT INTO EAI.CUSTOMER_LOG
              ( Cliente_V3, Fecha_Syncr, Fecha_Insert )
            VALUES
              ( v_Cliente_V3, v_dtFecha, SYSDATE ) ;            
         ELSE
            UPDATE EAI.CUSTOMER_LOG SET Fecha_Syncr = v_dtFecha
               WHERE Cliente_V3   = v_Cliente_V3
                 AND Fecha_Insert = dtFechaInsert ;
         END IF ;
      ELSIF ( v_Opcion = 'ProcT3' ) THEN
         IF ( sInsert = 'SI' ) THEN
            INSERT INTO EAI.CUSTOMER_LOG
              ( Cliente_V3, Fecha_Proc_BATMD, Fecha_Insert )
            VALUES
              ( v_Cliente_V3, v_dtFecha, SYSDATE ) ;            
         ELSE
            UPDATE EAI.CUSTOMER_LOG SET Fecha_Proc_BATMD = v_dtFecha
               WHERE Cliente_V3   = v_Cliente_V3
                 AND Fecha_Insert = dtFechaInsert ;
         END IF ;
      ELSIF ( v_Opcion = 'ConfSAP' ) THEN
         IF ( sInsert = 'SI' ) THEN
            INSERT INTO EAI.CUSTOMER_LOG
              ( Cliente_V3, Fecha_Update_SAP, Fecha_Insert )
            VALUES
              ( v_Cliente_V3, v_dtFecha, SYSDATE ) ;            
         ELSE
            UPDATE EAI.CUSTOMER_LOG SET Fecha_Update_SAP = v_dtFecha
               WHERE Cliente_V3   = v_Cliente_V3
                 AND Fecha_Insert = dtFechaInsert ;
         END IF ;
      ELSIF ( v_Opcion = 'ConfERP' ) THEN
         IF ( sInsert = 'SI' ) THEN
            INSERT INTO EAI.CUSTOMER_LOG
              ( Cliente_V3, Fecha_Update_ERP, Fecha_Insert )
            VALUES
              ( v_Cliente_V3, v_dtFecha, SYSDATE ) ;            
         ELSE
            UPDATE EAI.CUSTOMER_LOG SET Fecha_Update_ERP = v_dtFecha
               WHERE Cliente_V3   = v_Cliente_V3
                 AND Fecha_Insert = dtFechaInsert ;
         END IF ;
      END IF ;
   END IF ;      
END CUSTOMER_LOG_UPDATE ;
 
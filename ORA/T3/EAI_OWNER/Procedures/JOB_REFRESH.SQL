create or replace PROCEDURE             "JOB_REFRESH"     
IS
   sChar       VARCHAR2(10) ;
   nStatus     NUMBER       ;
   dtNextRun   DATE         ;
   dtNextXML   DATE         ;
   bBroken     BOOLEAN      ;
--   
   CURSOR ScrAllJobs IS
      SELECT Jobs.JOB             , Jobs.LOG_USER        , Jobs.PRIV_USER       , Jobs.SCHEMA_USER     ,
             Jobs.LAST_DATE       , Jobs.LAST_SEC        , Jobs.THIS_DATE       , Jobs.THIS_SEC        ,
             Jobs.NEXT_DATE       , Jobs.NEXT_SEC        , Jobs.TOTAL_TIME      , Jobs.BROKEN          ,
             Jobs.INTERVAL        , Jobs.FAILURES        , Jobs.WHAT            , Jobs.NLS_ENV         ,
             Jobs.INSTANCE
         FROM User_Jobs Jobs ;
BEGIN
   EXECUTE IMMEDIATE ( 'TRUNCATE TABLE EAI_OWNER.INTERNAL_JOBS' ) ;
   FOR Jobs IN ScrAllJobs LOOP 
      INSERT INTO EAI_OWNER.INTERNAL_JOBS
        ( JOBNO                , LOG_USER             , PRIV_USER            , SCHEMA_USER          ,
          LAST_DATE            , LAST_SEC             , THIS_DATE            , THIS_SEC             ,
          NEXT_DATE            , NEXT_SEC             , TOTAL_TIME           , BROKEN               ,
          INTERVAL_JOB         , FAILURES             , WHAT                 , NLS_ENV              ,
          INSTANCE_JOB          ) 
      VALUES    
        ( Jobs.JOB             , Jobs.LOG_USER        , Jobs.PRIV_USER       , Jobs.SCHEMA_USER     ,
          Jobs.LAST_DATE       , Jobs.LAST_SEC        , Jobs.THIS_DATE       , Jobs.THIS_SEC        ,
          Jobs.NEXT_DATE       , Jobs.NEXT_SEC        , Jobs.TOTAL_TIME      , Jobs.BROKEN          ,
          Jobs.INTERVAL        , Jobs.FAILURES        , Jobs.WHAT            , Jobs.NLS_ENV         ,
          Jobs.INSTANCE         ) ;
   END LOOP ;   
   COMMIT ;    
END ; -- Procedure;
 
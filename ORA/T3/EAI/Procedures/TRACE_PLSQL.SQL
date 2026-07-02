create or replace PROCEDURE       "TRACE_PLSQL" 
   ( cProc IN VARCHAR,
     cStep IN VARCHAR ) IS
BEGIN
   INSERT INTO DEBUG_T3 ( Fecha, Pedido, Comentario )
      VALUES ( SYSDATE, cProc, cStep ) ;
END ;
 
 
create or replace PROCEDURE       "INSERT_DEBITNOTE" 
   ( v_DebitNote        IN  VARCHAR2,
     v_Fecha_Proc_BATMD IN  CHAR    ,
     Var                OUT CHAR     )
IS
BEGIN
   INSERT INTO CANCELA_DEBIT_NOTE ( DebitNote, Fecha_Proc_BATMD )
      VALUES ( v_DebitNote, TO_DATE( v_Fecha_Proc_BATMD, 'yyyy-mm-dd hh24:mi:ss') ) ;
END Insert_Debitnote ;
 
 
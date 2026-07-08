create or replace FUNCTION             "MX_CENTRO_COBZA" (p_Customer VARCHAR2, p_Centro_Vta VARCHAR2)
   RETURN VARCHAR2
AS
   vReturn   VARCHAR2 (100);
   vFound    BOOLEAN;

   CURSOR cHead (vCustomer VARCHAR2)
   IS
      SELECT CTRO_COBZA
        FROM EAI_OWNER.MX_HEAD_OFFICE
       WHERE CUSTOMER = vCustomer;

   CURSOR cDistr (vCentro_Vta VARCHAR2)
   IS
      SELECT SUPL_VIA_PAGO
        FROM T3.DISTRIBUIDOR_FISCAL
       WHERE CTRO = vCentro_Vta;

BEGIN
   OPEN cHead(p_Customer);
   FETCH cHead INTO vReturn;

   vFound := cHead%FOUND;

   CLOSE cHead;

   IF NOT vFound  THEN
      OPEN cDistr(p_Centro_Vta);
      FETCH cDistr INTO vReturn;

      vFound := cDistr%FOUND;

      CLOSE cDistr;

      IF NOT vFound  THEN
         vReturn := NULL;
      END IF;
   END IF;


   RETURN vReturn;
END;
 
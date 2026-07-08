create or replace FUNCTION           NUMBER_TO_LETTER (p_value IN number) RETURN VARCHAR2 IS
 
   FUNCTION I___________NUMBER_TO_LETTER(p_value IN number, p_position IN number) RETURN VARCHAR2 AS          
        mantisa number :=0;
        residuo number :=0;
        sReturn varchar2(30);
        BEGIN
            mantisa := TRUNC((p_value-1)/26);
            residuo := MOD(p_value-1, 26)+1;
            if mantisa = 0 then
                sReturn := null;
            elsif mantisa >=1 and mantisa <=26 then
                sReturn := chr(mantisa + 64);
            else
                sReturn := I___________NUMBER_TO_LETTER(mantisa, p_position+1);
            end if;
            sReturn := sReturn || chr(residuo + 64);
            return sReturn;
        END I___________NUMBER_TO_LETTER;
        
        
BEGIN
    IF NVL(p_value, -1) > 0 THEN
        RETURN I___________NUMBER_TO_LETTER(p_value, 0);
    ELSE
        RETURN NULL;
    END IF;
END NUMBER_TO_LETTER;
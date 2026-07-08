create or replace FUNCTION           LETTER_TO_NUMBER (p_value IN VARCHAR2) RETURN NUMBER IS
sTest CHAR(1);        
    
        FUNCTION I___________LETTER_TO_NUMBER(p_value IN VARCHAR2, p_position IN NUMBER) return NUMBER AS
        nReturn NUMBER := 0;
        v_last CHAR(1);
        v_resto VARCHAR2(30);
        begin
              if p_position > 15 then
                raise_application_error(-20000, 'Not permitted . p_value="'||p_value ||'" p_position="'||p_position||'"' );
               end if;
             if p_value IS NULL then
                return 0;
             else
                nReturn := I___________LETTER_TO_NUMBER(substr(p_value, 1, length(p_value)-1),p_position+1);         
             end if;
                nReturn :=  nReturn + POWER(26, p_position) * (ASCII(substr(p_value,-1))-64);
                 
             RETURN  nReturn;  
        END I___________LETTER_TO_NUMBER;
   
BEGIN
    IF NVL(p_value, '-') != '-' THEN
        FOR I in 1..LENGTH(p_value) LOOP
            sTest := (SUBSTR(p_value, I, 1));
            IF sTest <'A' OR sTest > 'Z' THEN
                raise_application_error(-20000, 'Error in string, Character not valid ="'||sTest||'" position="'||i||'"' );
            END IF; 
        END LOOP;
        RETURN I___________LETTER_TO_NUMBER(p_value, 0);
    ELSE
        RETURN 0;
    END IF;
END LETTER_TO_NUMBER;
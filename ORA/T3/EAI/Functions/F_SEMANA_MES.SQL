create or replace FUNCTION       "F_SEMANA_MES" 
  ( nSemana IN NUMBER, nAnio IN NUMBER)
  RETURN  NUMBER IS
--
-- Funcion que en base a la semana y año
-- genera el mes a la que pertenece
--
-- MODIFICATION HISTORY
-- Person      Date       Comments
-- ---------   ---------- -------------------------------------------
-- FAGR        26-11-2004 Versión Inicial
   nMes      NUMBER;
   nFecha1   NUMBER;
   nFecha2   NUMBER;
BEGIN
    nFecha1 := (nAnio * 10000);
    nFecha2 := (nAnio * 10000);
    IF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 101, 'yyyymmdd'), 'WW') AND
       nSemana <= TO_CHAR(TO_DATE(nFecha2 + 131, 'yyyymmdd'), 'WW') THEN
       nMes := 1;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 201, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 229, 'yyyymmdd'), 'WW')  THEN
          nMes := 2;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 301, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 331, 'yyyymmdd'), 'WW')  THEN
          nMes := 3;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 401, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 430, 'yyyymmdd'), 'WW')  THEN
          nMes := 4;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 501, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 531, 'yyyymmdd'), 'WW')  THEN
          nMes := 5;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 601, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 630, 'yyyymmdd'), 'WW')  THEN
          nMes := 6;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 701, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 731, 'yyyymmdd'), 'WW')  THEN
          nMes := 7;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 801, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 831, 'yyyymmdd'), 'WW')  THEN
          nMes := 8;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 901, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 930, 'yyyymmdd'), 'WW')  THEN
          nMes := 9;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 1001, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 1031, 'yyyymmdd'), 'WW')  THEN
          nMes := 10;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 1101, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 1130, 'yyyymmdd'), 'WW')  THEN
          nMes := 11;
    ELSIF nSemana >= TO_CHAR(TO_DATE(nFecha1 + 1201, 'yyyymmdd'), 'WW')  AND
          nSemana <= TO_CHAR(TO_DATE(nFecha2 + 1231, 'yyyymmdd'), 'WW')  THEN
          nMes := 12;
    ELSE
        nMes := 0;
    END IF;
    RETURN nMes ;
END;
 
 
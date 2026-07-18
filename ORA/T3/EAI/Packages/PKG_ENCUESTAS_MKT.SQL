--------------------------------------------------------
--  DDL for Package PKG_ENCUESTAS_MKT
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE "EAI"."PKG_ENCUESTAS_MKT" AS 

  /*Procedimiento que Ejecuta PRC_VALIDA_ENCUESTAS y PRC_REPORTE_ENCUESTAS procedimientos en el orden respectivo*/
  PROCEDURE PRC_EJECUTA_PROCESO_ENCUESTAS;

  /*Procedimiento que valida la informacion de campos de las cada encuesta*/
  PROCEDURE PRC_VALIDA_ENCUESTAS;
  
  /*Procedimiento que genera la informacion resumida en un reporte de encuestas valida e invalidas*/
  PROCEDURE PRC_REPORTE_ENCUESTAS;
  
  /*Funcion que regresa como resultado un 1 si el campo enviado es invalido o 0 si no es invalido*/
  FUNCTION FNC_REVISA_CAMPO_VALIDO( P_CAMPO         NVARCHAR2,
                                    P_IDENCUESTADO  NUMBER) RETURN NUMBER;    

END PKG_ENCUESTAS_MKT;

/

  GRANT EXECUTE ON "EAI"."PKG_ENCUESTAS_MKT" TO "LEGACIES_VTA_APPS";
  GRANT EXECUTE ON "EAI"."PKG_ENCUESTAS_MKT" TO "ITX_DEV";

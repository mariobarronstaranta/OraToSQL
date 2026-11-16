--------------------------------------------------------
--  DDL for Table TMD_EMAIL
--------------------------------------------------------

  CREATE TABLE "T3"."TMD_EMAIL" 
   (	"CREADO" DATE, 
	"CREADO_POR" VARCHAR2(256 BYTE), 
	"ULTIMA_ACT" DATE, 
	"ACTUALIZADO_POR" VARCHAR2(256 BYTE), 
	"CLIENTE_ID" VARCHAR2(50 CHAR), 
	"CLIENTE_SAP" VARCHAR2(30 CHAR), 
	"SAP_CADENA" VARCHAR2(30 CHAR), 
	"X_ROUTE_REF_1" VARCHAR2(30 CHAR), 
	"X_EM_FIELD_18" VARCHAR2(100 CHAR), 
	"ATTRIB_34" VARCHAR2(50 CHAR), 
	"X_EM_FIELD_5" VARCHAR2(100 CHAR), 
	"EMAIL" VARCHAR2(350 CHAR), 
	"EMAIL_REMISION" VARCHAR2(300 BYTE)
   ) SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "LEGDB_DATA_T3_1" ;
  GRANT ALTER ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT DELETE ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT INDEX ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT INSERT ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT SELECT ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT UPDATE ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT REFERENCES ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT ON COMMIT REFRESH ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT QUERY REWRITE ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT DEBUG ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT FLASHBACK ON "T3"."TMD_EMAIL" TO "LEGACIES_VTA_APPS";
  GRANT ALTER ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT DELETE ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT INDEX ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT INSERT ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT SELECT ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT UPDATE ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT REFERENCES ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT ON COMMIT REFRESH ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT QUERY REWRITE ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT DEBUG ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT FLASHBACK ON "T3"."TMD_EMAIL" TO "EAI_OWNER";
  GRANT DELETE ON "T3"."TMD_EMAIL" TO "CC_DOCTOS_OWNER";
  GRANT INSERT ON "T3"."TMD_EMAIL" TO "CC_DOCTOS_OWNER";
  GRANT SELECT ON "T3"."TMD_EMAIL" TO "CC_DOCTOS_OWNER";
  GRANT UPDATE ON "T3"."TMD_EMAIL" TO "CC_DOCTOS_OWNER";
  GRANT DELETE ON "T3"."TMD_EMAIL" TO "INTEGRATION_ROLE";
  GRANT INSERT ON "T3"."TMD_EMAIL" TO "INTEGRATION_ROLE";
  GRANT SELECT ON "T3"."TMD_EMAIL" TO "INTEGRATION_ROLE";
  GRANT UPDATE ON "T3"."TMD_EMAIL" TO "INTEGRATION_ROLE";
  GRANT DELETE ON "T3"."TMD_EMAIL" TO "SYSADMIN_ROLE";
  GRANT INSERT ON "T3"."TMD_EMAIL" TO "SYSADMIN_ROLE";
  GRANT SELECT ON "T3"."TMD_EMAIL" TO "SYSADMIN_ROLE";
  GRANT UPDATE ON "T3"."TMD_EMAIL" TO "SYSADMIN_ROLE";
  GRANT UPDATE ON "T3"."TMD_EMAIL" TO "EAI";
  GRANT SELECT ON "T3"."TMD_EMAIL" TO "ITX_DEV";
--------------------------------------------------------
--  DDL for Index TMD_INDEX1
--------------------------------------------------------

  CREATE INDEX "T3"."TMD_INDEX1" ON "T3"."TMD_EMAIL" ("CLIENTE_SAP") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "LEGDB_DATA_T3_1" ;
--------------------------------------------------------
--  DDL for Index TMD_INDEX2
--------------------------------------------------------

  CREATE INDEX "T3"."TMD_INDEX2" ON "T3"."TMD_EMAIL" ("CLIENTE_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "LEGDB_DATA_T3_1" ;
--------------------------------------------------------
--  DDL for Trigger TRIG_TMD_EMAIL
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE TRIGGER "T3"."TRIG_TMD_EMAIL" after insert or update or delete on T3.TMD_EMAIL for each row
declare
    v_trig_date     date;
    v_status_flag   varchar2(1 char);
    v_trig_user     varchar2(50 char);
begin
    if inserting  then
        v_trig_date   := sysdate;
        v_status_flag := 'I';
        v_trig_user   := SYS_CONTEXT( 'USERENV' , 'OS_USER' );
    end if;
    if updating  then
        v_trig_date   := sysdate;
        v_status_flag := 'U';
        v_trig_user   := SYS_CONTEXT( 'USERENV' , 'OS_USER' );
    end if;
    if deleting  then
            v_trig_date   := sysdate;
            v_status_flag := 'D';
            v_trig_user   := SYS_CONTEXT( 'USERENV' , 'OS_USER' );
    end if;

DBMS_Output.Put_Line( 'fecha '||v_trig_date) ;

if deleting then
    insert into T3.TMD_EMAIL_LOG (
     Creado            ,
     Creado_Por        ,
     Ultima_Act        ,
     Actualizado_Por   , 
     Cliente_Id        ,
     Cliente_Sap       , 
     Sap_Cadena        ,
     X_Route_Ref_1     ,
     X_Em_Field_18     ,
     Attrib_34         ,
     X_Em_Field_5      ,
     Email             ,
     Fecha_Mod         ,
     Tipo_Mod          ,
     Responsable       
    )
    values
    (
     :old.Creado            ,
     :old.Creado_Por        ,
     :old.Ultima_Act        ,
     :old.Actualizado_Por   , 
     :old.Cliente_Id        ,
     :old.Cliente_Sap       , 
     :old.Sap_Cadena        ,
     :old.X_Route_Ref_1     ,
     :old.X_Em_Field_18     ,
     :old.Attrib_34         ,
     :old.X_Em_Field_5      ,
     :old.Email             ,
     v_trig_date            ,
     v_status_flag          ,
     v_trig_user       
    );
end if;

if updating or inserting then
    insert into T3.TMD_EMAIL_LOG (
     Creado            ,
     Creado_Por        ,
     Ultima_Act        ,
     Actualizado_Por   , 
     Cliente_Id        ,
     Cliente_Sap       , 
     Sap_Cadena        ,
     X_Route_Ref_1     ,
     X_Em_Field_18     ,
     Attrib_34         ,
     X_Em_Field_5      ,
     Email             ,
     Fecha_Mod         ,
     Tipo_Mod          ,
     Responsable       
    )
    values
    (
     :new.Creado            ,
     :new.Creado_Por        ,
     :new.Ultima_Act        ,
     :new.Actualizado_Por   , 
     :new.Cliente_Id        ,
     :new.Cliente_Sap       , 
     :new.Sap_Cadena        ,
     :new.X_Route_Ref_1     ,
     :new.X_Em_Field_18     ,
     :new.Attrib_34         ,
     :new.X_Em_Field_5      ,
     :new.Email             ,
     v_trig_date            ,
     v_status_flag          ,
     v_trig_user       
    );
end if;
end;
/
ALTER TRIGGER "T3"."TRIG_TMD_EMAIL" ENABLE;

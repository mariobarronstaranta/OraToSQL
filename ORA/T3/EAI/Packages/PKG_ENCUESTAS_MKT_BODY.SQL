create or replace PACKAGE BODY     "PKG_ENCUESTAS_MKT" AS

--------------------------------------------------------
--  DDL -- Procedure PRC_EJECUTA_PROCESO_ENCUESTAS create by Azael Gutierrez
--------------------------------------------------------

  PROCEDURE PRC_EJECUTA_PROCESO_ENCUESTAS AS
  BEGIN
  
    PRC_VALIDA_ENCUESTAS();
    PRC_REPORTE_ENCUESTAS();
    
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK);
  END PRC_EJECUTA_PROCESO_ENCUESTAS;

--------------------------------------------------------
--  DDL -- Procedure PRC_VALIDA_ENCUESTAS create by Azael Gutierrez
--------------------------------------------------------

  PROCEDURE PRC_VALIDA_ENCUESTAS AS 
  
  V_IDENCUESTA	                NUMBER(30,0);
  V_TERRITORIO	                NUMBER(10,0);
  V_ANIO_SEMANA	                NUMBER(6,0);
  V_DIA_SEMANA	                NUMBER(1,0);
  V_IDENCUESTADO	              NUMBER(30,0);
  V_IDENCUESTADOR	              NUMBER(30,0);
  V_FECHA_INICIO	              DATE;
  V_FECHA_FIN	                  DATE;
  V_DIRECCIONIP	                VARCHAR2(20 CHAR);
  V_E_MAIL	                    VARCHAR2(50 CHAR);
  V_NOMBRE	                    VARCHAR2(30 CHAR);
  V_APELLIDO	                  VARCHAR2(30 CHAR);
  V_DATOS_PERSONALIZADOS	      VARCHAR2(300 CHAR);
  V_FUENTE	                    VARCHAR2(10 CHAR);
  V_VENDE_CIGARRO	              VARCHAR2(50 CHAR);
  V_VISITADO_BAT	              VARCHAR2(2 CHAR);
  V_CUANTO_VENDE	              NUMBER(15,0);
  V_VENTA_SEM_PALLMALL	        NUMBER(10,0);
  V_VENTA_SEM_LUCKYSTRIKE	      NUMBER(10,0);
  V_VENTA_SEM_SHOTS	            NUMBER(10,0);
  V_VENTA_SEM_CAMEL	            NUMBER(10,0);
  V_VENTA_SEM_OTRASBAT	        NUMBER(10,0);
  V_VENTA_SEM_MARLBORO	        NUMBER(10,0);
  V_VENTA_SEM_BENSONHEADGES	    NUMBER(10,0);
  V_VENTA_SEM_DELICADOS	        NUMBER(10,0);
  V_VENTA_SEM_OTRASPMI	        NUMBER(10,0);
  V_VENTA_SEM_OTRASMARCAS	      NUMBER(10,0);
  V_COORDENADAS	                VARCHAR2(250 CHAR);
  V_TIENE_EXHIBIDOR	            VARCHAR2(10 CHAR);
  V_TELEFONO	                  NUMBER(10,0);
  V_SEMANA	                    NUMBER(5,0);
  V_DIA_VISITA	                VARCHAR2(10 CHAR);
  V_CONSECUTIVO	                NUMBER(10,0);
  V_NOMBRE_CONTACTO	            VARCHAR2(200 CHAR);
  V_DATOS_GEN_NOMBRETIENDA	    VARCHAR2(100 CHAR);
  V_DATOS_GEN_CALLEYNUMERO	    VARCHAR2(300 CHAR);
  V_DATOS_GEN_COLONIAYCIUDAD	  VARCHAR2(200 CHAR);
  V_DATOS_GEN_CODIGOPOSTAL	    NUMBER(8,0);
  V_DATOS_GEN_ESTADO	          VARCHAR2(40 CHAR);
  V_CLIENTE_POTENCIAL	          VARCHAR2(20 BYTE);
  E_Exception_Isnull            Exception;
  E_Exception_Data_Diferent     Exception;
  E_EXCEPTION_INVALID           Exception;
  V_TIEMPO_EJECUCION            VARCHAR2(10 CHAR);
  V_COUNT_VALIDAS               NUMBER := 0;
  V_COUNT_INVALIDAS_ERRORES     NUMBER := 0;
  V_COUNT_INVALIDAS_ERRORES_AUX NUMBER := 0;
  V_COUNT_INVALIDAS_INEGI       NUMBER := 0;
  V_COUNT_INVALIDAS_INEGI_AUX   NUMBER := 0;
  V_COUNT_CARGADAS              NUMBER := 0;
  V_COUNT_ENCUESTA_ERROR        NUMBER := 0;
  V_ROWID                       ROWID;
  V_IDX_VALIDAS                 NUMBER := 0;
  V_IDX_VALIDAS_UPD             NUMBER := 0;
  V_IDX_ERRORES                 NUMBER := 0;
  V_IDX_INVALIDAS               NUMBER := 0;
  V_IDX_PROCESADAS              NUMBER := 0;
  START_DATE                    DATE;
  END_DATE                      DATE;
  V_NEXT_IDEJECUCION            NUMBER := 0;
  V_NEXT_IDERROR                NUMBER := 0;
  V_NEXT_IDENCUESTA             NUMBER := 0;
  V_NEXT_IDENCUESTA_INVALIDA    NUMBER := 0;
  V_VALIDA_DESCARTE_INEGI       NUMBER := 0;
  V_STATUS                      NUMBER; --1=PROCESO COMPLETO SIN ERRORES ; 2=PROCESO COMPLETO CON ERRORES ; 3= PROCESO INCOMPLETO CON ERRORES ; 4 = PROCESO INCOMPLETO SIN ERRORES
  V_MENSAJE_BITACORA            VARCHAR2(500 CHAR);
  
  CURSOR C_ENCUESTAS IS
    SELECT  ROWID,                    IDENCUESTADO,           IDENCUESTADOR,      FECHA_INICIO,             FECHA_FIN,          DIRECCIONIP,        E_MAIL,NOMBRE,          APELLIDO,       
            DATOS_PERSONALIZADOS,     FUENTE,                 VENDE_CIGARRO,      VISITADO_BAT,             CUANTO_VENDE,       VENTA_SEM_PALLMALL, VENTA_SEM_LUCKYSTRIKE,  VENTA_SEM_SHOTS,
            VENTA_SEM_CAMEL,          VENTA_SEM_OTRASBAT,     VENTA_SEM_MARLBORO, VENTA_SEM_BENSONHEADGES,  VENTA_SEM_DELICADOS,VENTA_SEM_OTRASPMI, VENTA_SEM_OTRASMARCAS,  COORDENADAS,
            TIENE_EXHIBIDOR,          TELEFONO,               SEMANA,             DIA_VISITA,               CONSECUTIVO,        NOMBRE_CONTACTO,    DATOS_GEN_NOMBRETIENDA, DATOS_GEN_CALLEYNUMERO,
            DATOS_GEN_COLONIAYCIUDAD, DATOS_GEN_CODIGOPOSTAL, DATOS_GEN_ESTADO,   CLIENTE_POTENCIAL,        TERRITORIO
        FROM ENCUESTAS_CLIENTES_CARGADAS;
        
  CURSOR C_ENCUESTAS_VALIDAS IS
    SELECT  ROWID,                  IDENCUESTA,               TERRITORIO,             ANIO_SEMANA,            DIA_SEMANA,         IDENCUESTADO,           IDENCUESTADOR,      
            FECHA_INICIO,           FECHA_FIN,                DIRECCIONIP,            E_MAIL,                 NOMBRE,             APELLIDO,               DATOS_PERSONALIZADOS, 
            FUENTE,                 VENDE_CIGARRO,            VISITADO_BAT,           CUANTO_VENDE,           VENTA_SEM_PALLMALL, VENTA_SEM_LUCKYSTRIKE,  VENTA_SEM_SHOTS,  
            VENTA_SEM_CAMEL,        VENTA_SEM_OTRASBAT,       VENTA_SEM_MARLBORO,     VENTA_SEM_BENSONHEADGES,VENTA_SEM_DELICADOS,VENTA_SEM_OTRASPMI,     VENTA_SEM_OTRASMARCAS,
            COORDENADAS,            TIENE_EXHIBIDOR,          TELEFONO,SEMANA,        DIA_VISITA,             CONSECUTIVO,        NOMBRE_CONTACTO,        DATOS_GEN_NOMBRETIENDA,
            DATOS_GEN_CALLEYNUMERO, DATOS_GEN_COLONIAYCIUDAD, DATOS_GEN_CODIGOPOSTAL, DATOS_GEN_ESTADO,       CLIENTE_POTENCIAL,  FECHA_REGISTRO,         ESTATUS
        FROM ENCUESTAS_CLIENTES_VALIDAS;
  
  TYPE BLK_CUR_ENCUESTAS_CARGADAS IS TABLE OF C_ENCUESTAS%ROWTYPE INDEX BY BINARY_INTEGER;
  TYPE BLK_TBL_ENCUESTAS_VALIDAS IS TABLE OF ENCUESTAS_CLIENTES_VALIDAS%ROWTYPE INDEX BY BINARY_INTEGER;
  TYPE BLK_CUR_ENCUESTAS_VALIDAS IS TABLE OF C_ENCUESTAS_VALIDAS%ROWTYPE INDEX BY BINARY_INTEGER;
  TYPE BLK_TBL_ENCUESTAS_ERRORES IS TABLE OF ENCUESTAS_CLIENTES_ERRORES%ROWTYPE INDEX BY BINARY_INTEGER;
  TYPE BLK_TBL_ENCUESTAS_INVALIDAS IS TABLE OF ENCUESTAS_CLIENTES_INVALIDAS%ROWTYPE INDEX BY BINARY_INTEGER;
  TYPE BLK_ENCUESTAS_PROCESADAS IS TABLE OF ROWID;
  TYPE BLK_ENCUESTAS_BUENAS IS TABLE OF ROWID;
  
  LIST_ENCUESTAS_CARGADAS     BLK_CUR_ENCUESTAS_CARGADAS;
  LIST_ENCUESTAS_VALIDAS      BLK_TBL_ENCUESTAS_VALIDAS;
  LIST_ENCUESTAS_VALIDAS_UPD  BLK_CUR_ENCUESTAS_VALIDAS;
  LIST_ENCUESTAS_ERRORES      BLK_TBL_ENCUESTAS_ERRORES;
  LIST_ENCUESTAS_INVALIDAS    BLK_TBL_ENCUESTAS_INVALIDAS;
  LIST_ENCUESTAS_PROCESADAS   BLK_ENCUESTAS_PROCESADAS := NEW BLK_ENCUESTAS_PROCESADAS();
  LIST_ENCUESTAS_BUENAS       BLK_ENCUESTAS_BUENAS := NEW BLK_ENCUESTAS_BUENAS();
  
  BEGIN
    DBMS_OUTPUT.PUT_LINE('INICIA PROCESO DE VALIDACION');
    START_DATE:= SYSDATE;
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE EAI.ENCUESTAS_CLIENTES_VALIDAS';
    DELETE ENCUESTAS_CLIENTES_ERRORES;
    DELETE ENCUESTAS_CLIENTES_INVALIDAS;
    DELETE ENCUESTAS_CLIENTES_BITACORA;
    commit;
    
    SELECT (NVL(MAX(IDEJECUCION),0)+1) INTO V_NEXT_IDEJECUCION FROM ENCUESTAS_CLIENTES_BITACORA;
    
    LIST_ENCUESTAS_PROCESADAS.EXTEND(100);
    
    OPEN C_ENCUESTAS;
      LOOP
      fetch C_ENCUESTAS 
        BULK COLLECT INTO LIST_ENCUESTAS_CARGADAS LIMIT 100;
        EXIT WHEN LIST_ENCUESTAS_CARGADAS.COUNT = 0;
          
          LIST_ENCUESTAS_VALIDAS.DELETE;
          LIST_ENCUESTAS_INVALIDAS.DELETE;
          LIST_ENCUESTAS_ERRORES.DELETE;
          V_IDX_VALIDAS                 := 0;
          V_IDX_INVALIDAS               := 0;
          V_IDX_PROCESADAS              := 0;
          V_IDX_ERRORES                 := 0;
          V_COUNT_INVALIDAS_INEGI_AUX   := 0;
          V_COUNT_INVALIDAS_ERRORES_AUX := 0;
          
          --Inicializa al siguiente id de la encuesta invalida
          SELECT (NVL(MAX(IDENCUESTA_INVALIDA),0)+1) INTO V_NEXT_IDENCUESTA_INVALIDA FROM ENCUESTAS_CLIENTES_INVALIDAS;
          --Inicializa al siguiente id de la encuesta nueva
          SELECT (NVL(MAX(IDENCUESTA),0)+1) INTO V_NEXT_IDENCUESTA FROM ENCUESTAS_CLIENTES_VALIDAS;        
          --Inicializa al siguiente id del error
          SELECT NVL(MAX(IDERROR),0) INTO V_NEXT_IDERROR FROM ENCUESTAS_CLIENTES_ERRORES;
          
          FOR IDX IN LIST_ENCUESTAS_CARGADAS.FIRST .. LIST_ENCUESTAS_CARGADAS.LAST
          LOOP  
  
                --VALIDACION DE DATOS DE ENCUESTAS        
                
                --Inicializa todos los valores en null
                  V_TERRITORIO	                := NULL;
                  V_ANIO_SEMANA	                := NULL;
                  V_DIA_SEMANA	                := NULL;
                  V_IDENCUESTADO	              := NULL;
                  V_IDENCUESTADOR	              := NULL;
                  V_FECHA_INICIO	              := NULL;
                  V_FECHA_FIN	                  := NULL;
                  V_DIRECCIONIP	                := NULL;
                  V_E_MAIL	                    := NULL;
                  V_NOMBRE	                    := NULL;
                  V_APELLIDO	                  := NULL;
                  V_DATOS_PERSONALIZADOS	      := NULL;
                  V_FUENTE	                    := NULL;
                  V_VENDE_CIGARRO	              := NULL;
                  V_VISITADO_BAT	              := NULL;
                  V_CUANTO_VENDE	              := NULL;
                  V_VENTA_SEM_PALLMALL	        := NULL;
                  V_VENTA_SEM_LUCKYSTRIKE	      := NULL;
                  V_VENTA_SEM_SHOTS	            := NULL;
                  V_VENTA_SEM_CAMEL	            := NULL;
                  V_VENTA_SEM_OTRASBAT	        := NULL;
                  V_VENTA_SEM_MARLBORO	        := NULL;
                  V_VENTA_SEM_BENSONHEADGES	    := NULL;
                  V_VENTA_SEM_DELICADOS	        := NULL;
                  V_VENTA_SEM_OTRASPMI	        := NULL;
                  V_VENTA_SEM_OTRASMARCAS	      := NULL;
                  V_COORDENADAS	                := NULL;
                  V_TIENE_EXHIBIDOR	            := NULL;
                  V_TELEFONO	                  := NULL;
                  V_SEMANA	                    := NULL;
                  V_DIA_VISITA	                := NULL;
                  V_CONSECUTIVO	                := NULL;
                  V_NOMBRE_CONTACTO	            := NULL;
                  V_DATOS_GEN_NOMBRETIENDA	    := NULL;
                  V_DATOS_GEN_CALLEYNUMERO	    := NULL;
                  V_DATOS_GEN_COLONIAYCIUDAD	  := NULL;
                  V_DATOS_GEN_CODIGOPOSTAL	    := NULL;
                  V_DATOS_GEN_ESTADO	          := NULL;
                  V_CLIENTE_POTENCIAL	          := NULL;
                
                --Inicializacion de contador de errores por encuesta
                V_COUNT_ENCUESTA_ERROR :=0;
                
                BEGIN /*********VALIDA IDENCUESTADO**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADO IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSE
                    V_IDENCUESTADO := TO_NUMBER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADO));
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADO || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'IDENCUESTADO';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR EL DATO IDENCUESTADO: '|| LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADO || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'IDENCUESTADO';
                END;
                
                BEGIN /*********VALIDA IDENCUESTADOR**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADOR IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSE
                    V_IDENCUESTADOR := TO_NUMBER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADOR));
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADOR || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'IDENCUESTADOR';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADOR || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'IDENCUESTADOR';
                END;              
  
                BEGIN /*********VALIDA FECHA_INICIO**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).FECHA_INICIO IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSE
                    V_FECHA_INICIO := TO_DATE(LIST_ENCUESTAS_CARGADAS(IDX).FECHA_INICIO,'dd-mm-yyyy');
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).FECHA_INICIO || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'FECHA_INICIO';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).FECHA_INICIO || ' :DEBE TENER EL FORMATO DD/MM/YYYY';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'FECHA_INICIO';
                END;
                
                BEGIN /*********VALIDA FECHA_FIN**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).FECHA_INICIO IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSE
                    V_FECHA_FIN := TO_DATE(LIST_ENCUESTAS_CARGADAS(IDX).FECHA_FIN,'dd-mm-yyyy');
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).FECHA_FIN || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'FECHA_FIN';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).FECHA_FIN || ' :DEBE TENER EL FORMATO DD/MM/YYYY';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'FECHA_FIN';
                END;              
  
                BEGIN /*********VALIDA DIRECCIONIP**********/
                    V_DIRECCIONIP := TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIRECCIONIP);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DIRECCIONIP || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DIRECCIONIP';
                END;
                
                BEGIN /*********VALIDA E-MAIL**********/
                    V_E_MAIL := TRIM(LIST_ENCUESTAS_CARGADAS(IDX).E_MAIL);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).E_MAIL || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'E_MAIL';
                END;
  
                BEGIN /*********VALIDA NOMBRE**********/
                    V_NOMBRE := TRIM(LIST_ENCUESTAS_CARGADAS(IDX).NOMBRE);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).NOMBRE || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'NOMBRE';
                End;
                
               
                BEGIN /*********VALIDA APELLIDO**********/
                    V_APELLIDO := TRIM(LIST_ENCUESTAS_CARGADAS(IDX).APELLIDO);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).APELLIDO || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'APELLIDO';
                END;   
                
                BEGIN /*********VALIDA DATOS_PERSONALIZADOS**********/
                    V_DATOS_PERSONALIZADOS := TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_PERSONALIZADOS);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DATOS_PERSONALIZADOS || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_PERSONALIZADOS';
                END;
                
                BEGIN /*********VALIDA FUENTE**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).FUENTE IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) != 'INEGI' AND 
                        TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE) != 'BARRIDO' THEN
                    RAISE E_EXCEPTION_DATA_DIFERENT;
                  ELSE
                    V_FUENTE := UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE));
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).FUENTE || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'FUENTE';
                  WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || UPPER(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE) || ' :DEBE SER ''INEGI'' Ó ''BARRIDO''';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'FUENTE';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).FUENTE || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'FUENTE';
                END;
                
                  
                BEGIN /*********VALIDA VENDE_CIGARRO**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO)) != '0 - SI'AND 
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO)) != '1 - CERRADO PERMANENTE' AND
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO)) != '2 - NO VENDE CIGARRO' AND 
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO)) != '3 - NO ESTA INTERESADO' THEN
                    RAISE E_EXCEPTION_DATA_DIFERENT;
                  ELSE
                    V_VENDE_CIGARRO := UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO));
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENDE_CIGARRO';
                  WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO || ' :DEBE SER ''0 - SI'' Ó ''1 - CERRADO PERMANENTE'' Ó ''2 - NO VENDE CIGARRO'' Ó ''3 - NO ESTA INTERESADO''';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENDE_CIGARRO';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENDE_CIGARRO';
                END;
                
                Begin /*********VALIDA VISITADO_BAT**********/
                  /*
                    Modificado por: Alejandrina Valdiviezo
                    Fecha : 31/10/2016
                    Descripción: Si es BARRIDO y el en la pregunta "Visitador por BAT" responde "SI" la encuesta es Inválida.
                                 Antes del 04/Oct la pregunta “Visitado por BAT” no es obligatoria, después de esta fecha NO permite nulos.*/
                  If  (To_Date(V_Fecha_Inicio,'YYYY/MM/DD') >= To_Date('2016/10/04','YYYY/MM/DD') And List_Encuestas_Cargadas(Idx).Visitado_Bat Is Null) Then
                    Raise E_Exception_Isnull;
                  Elsif (Upper(Trim(V_Fuente)) = 'BARRIDO' And Upper(Trim(List_Encuestas_Cargadas(Idx).Visitado_Bat)) = 'SI') Then                  
                    RAISE E_EXCEPTION_INVALID;
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VISITADO_BAT)) != 'SI'AND 
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VISITADO_BAT)) != 'NO' THEN
                    RAISE E_EXCEPTION_DATA_DIFERENT;
                  ELSE
                    V_VISITADO_BAT := UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).VISITADO_BAT));
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).VISITADO_BAT || ' :NO DEBE SER NULO';
                    List_Encuestas_Errores(V_Idx_Errores).Campo_Error := 'VISITADO_BAT';
                  WHEN E_EXCEPTION_INVALID THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    List_Encuestas_Errores(V_Idx_Errores).Fecha_Registro := Sysdate;
                    List_Encuestas_Errores(V_Idx_Errores).Mensaje_Detalle := 'ERROR DE DATO INVALIDO: ' || List_Encuestas_Cargadas(Idx).Visitado_Bat || ' :RESPUESTA NO VALIDA';
                    List_Encuestas_Errores(V_Idx_Errores).Campo_Error := 'VISITADO_BAT';
                  WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || LIST_ENCUESTAS_CARGADAS(IDX).VISITADO_BAT || ' :DEBE SER ''SI'' Ó ''NO''';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VISITADO_BAT';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VISITADO_BAT || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VISITADO_BAT';
                END;              
  
                BEGIN /*********VALIDA VENTA_SEM_PALLMALL**********/
                    V_VENTA_SEM_PALLMALL := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_PALLMALL);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_PALLMALL || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_PALLMALL';
                END;   
                
                BEGIN /*********VALIDA VENTA_SEM_LUCKYSTRIKE**********/
                    V_VENTA_SEM_LUCKYSTRIKE := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_LUCKYSTRIKE);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_LUCKYSTRIKE || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_LUCKYSTRIKE';
                END;
                
                BEGIN /*********VALIDA VENTA_SEM_SHOTS**********/
                    V_VENTA_SEM_SHOTS := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_SHOTS);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_SHOTS || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_SHOTS';
                END;
                
                BEGIN /*********VALIDA VENTA_SEM_CAMEL**********/
                    V_VENTA_SEM_CAMEL := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_CAMEL);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_CAMEL || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_CAMEL';
                END;
                
                BEGIN /*********VALIDA VENTA_SEM_OTRASBAT**********/
                    V_VENTA_SEM_OTRASBAT := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASBAT);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASBAT || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_OTRASBAT';
                END;
                
                BEGIN /*********VALIDA VENTA_SEM_MARLBORO**********/
                    V_VENTA_SEM_MARLBORO := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_MARLBORO);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_MARLBORO || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_MARLBORO';
                END;
                
                BEGIN /*********VALIDA VENTA_SEM_BENSONHEADGES**********/
                    V_VENTA_SEM_BENSONHEADGES := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_BENSONHEADGES);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_BENSONHEADGES || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_BENSONHEADGES';
                END;
                
                BEGIN /*********VALIDA VENTA_SEM_DELICADOS**********/
                    V_VENTA_SEM_DELICADOS := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_DELICADOS);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_DELICADOS || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_DELICADOS';
                END;
                
                BEGIN /*********VALIDA VENTA_SEM_OTRASPMI**********/
                    V_VENTA_SEM_OTRASPMI := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASPMI);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASPMI || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_OTRASPMI';
                END;              
  
                BEGIN /*********VALIDA VENTA_SEM_OTRASMARCAS**********/
                    V_VENTA_SEM_OTRASMARCAS := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASPMI);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASMARCAS || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'VENTA_SEM_OTRASMARCAS';
                END;
                
                BEGIN /*********VALIDA COORDENADAS**********/
                  IF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'INEGI' THEN
                    SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).COORDENADAS) INTO V_COORDENADAS FROM DUAL;     
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'BARRIDO' THEN
                    IF TRIM(LIST_ENCUESTAS_CARGADAS(IDX).COORDENADAS) IS NULL OR TRIM(LIST_ENCUESTAS_CARGADAS(IDX).COORDENADAS) = '0' THEN
                      RAISE E_EXCEPTION_ISNULL;            
                    ELSE  
                      SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).COORDENADAS) INTO V_COORDENADAS  FROM DUAL;       
                    END IF;
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).COORDENADAS || ' :NO DEBE SER NULO PARA BARRIDO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'COORDENADAS';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).COORDENADAS || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'COORDENADAS';
                END;
  
                BEGIN /*********VALIDA TIENE_EXHIBIDOR**********/
                  IF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR)) != 'NO TIENE' AND 
                     UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR)) != 'BAT' AND
                     UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR)) != 'PMI' AND 
                     UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR)) != 'AMBOS' THEN
                    RAISE E_EXCEPTION_DATA_DIFERENT;
                  ELSE
                    V_TIENE_EXHIBIDOR := UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR));
                  END IF;
                EXCEPTION WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR || ' :DEBE SER ''NO TIENE'' O ''DE BAT'' O ''DE PMI'' O ''DE AMBOS''';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'TIENE_EXHIBIDOR';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'TIENE_EXHIBIDOR';
                END;
  
                BEGIN /*********VALIDA TELEFONO**********/
                    V_TELEFONO := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).TELEFONO);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).TELEFONO || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'TELEFONO';
                END;
  
                BEGIN /*********VALIDA SEMANA**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).SEMANA IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSIF TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).SEMANA) <1 AND TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).SEMANA) > 53 THEN
                    RAISE E_EXCEPTION_DATA_DIFERENT;
                  ELSE
                    V_SEMANA := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).SEMANA);
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).SEMANA || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'SEMANA';
                  WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || LIST_ENCUESTAS_CARGADAS(IDX).FUENTE || ' :DEBE SER NUMERICO ENTRE 1 y 53';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'SEMANA';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).SEMANA || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'SEMANA';
                END;
  
                BEGIN /*********VALIDA DIA_VISITA**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;            
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA)) != 'LUNES' AND 
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA)) != 'MARTES' AND
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA)) != 'MIÉRCOLES' AND 
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA)) != 'JUEVES' AND 
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA)) != 'VIERNES' AND
                        UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA)) != 'SÁBADO' THEN
                    RAISE E_EXCEPTION_DATA_DIFERENT;
                  ELSE
                    V_DIA_VISITA := UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA));
                  END IF;
                EXCEPTION  
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DIA_VISITA';
                  WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA || ' :DEBE SER ''LUNES'' O ''MARTES'' O ''MIÉRCOLES'' O ''JUEVES'' O ''VIERNES'' O ''SÁBADO''';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DIA_VISITA';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DIA_VISITA';
                END;
                
                BEGIN /*********VALIDA CONSECUTIVO**********/
                    IF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'INEGI' THEN
                      IF LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO IS NULL THEN
                        RAISE E_EXCEPTION_ISNULL;            
                      ELSIF TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO) <1 AND TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO) >99 THEN
                        RAISE E_EXCEPTION_DATA_DIFERENT;
                      ELSE  
                        SELECT NVL(TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO),0) INTO V_CONSECUTIVO  FROM DUAL;     
                      END IF;
                    ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'BARRIDO' THEN
                      IF LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO IS NULL THEN
                        RAISE E_EXCEPTION_ISNULL;            
                      ELSIF TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO) != 0 AND LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO IS NOT NULL THEN
                        RAISE E_EXCEPTION_DATA_DIFERENT;
                      ELSE  
                        SELECT NVL(TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO),0) INTO V_CONSECUTIVO  FROM DUAL;       
                      END IF;
                    END IF;
                EXCEPTION  
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'CONSECUTIVO';
                  WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO || ' y ' || LIST_ENCUESTAS_CARGADAS(IDX).FUENTE || ' :PARA ''INEGI'' DEBE SER ENTRE 1 Y 99, Y PARA ''BARRIDO'' DEBE SER 0 o NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'CONSECUTIVO';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'CONSECUTIVO';
                END;
  
                BEGIN/*********VALIDA NOMBRE_CONTACTO**********/
                /*
                Modificado por: Alejandrina Valdiviezo
                Fecha : 31/10/2016
                Descripción: El "Nombre del contacto" es requerido cuando la encuesta es de BARRIDO */
                IF V_FUENTE = 'BARRIDO' AND (TRIM(LIST_ENCUESTAS_CARGADAS(IDX).NOMBRE_CONTACTO) IS NULL OR TRIM(LIST_ENCUESTAS_CARGADAS(IDX).NOMBRE_CONTACTO) LIKE '%No proporcion%') THEN
                   RAISE E_EXCEPTION_ISNULL;
                 ELSE
                   V_Nombre_Contacto := Trim(List_Encuestas_Cargadas(Idx).Nombre_Contacto);
                END IF;
                EXCEPTION  
                WHEN E_EXCEPTION_ISNULL THEN
                     --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    List_Encuestas_Errores(V_Idx_Errores).Mensaje_Detalle := 'ERROR DE NULL: ' || List_Encuestas_Cargadas(Idx).Fecha_Fin || ' :NO DEBE SER NULO';
                    List_Encuestas_Errores(V_Idx_Errores).Campo_Error := 'NOMBRE_CONTACTO';
                 WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).NOMBRE_CONTACTO || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'NOMBRE_CONTACTO';
                END;
                
                BEGIN /*********VALIDA DATOS_GEN_NOMBRETIENDA**********/
                  IF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'INEGI' THEN
                    SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_NOMBRETIENDA) INTO V_DATOS_GEN_NOMBRETIENDA FROM DUAL;     
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'BARRIDO' THEN
                    IF TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_NOMBRETIENDA) IS NULL THEN
                      RAISE E_EXCEPTION_ISNULL;            
                    ELSE  
                      SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_NOMBRETIENDA) INTO V_DATOS_GEN_NOMBRETIENDA  FROM DUAL;       
                    END IF;
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_NOMBRETIENDA || ' :NO DEBE SER NULO PARA BARRIDO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_NOMBRETIENDA';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_NOMBRETIENDA || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_NOMBRETIENDA';
                END;
                
                BEGIN /*********VALIDA DATOS_GEN_CALLEYNUMERO**********/
                  IF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'INEGI' THEN
                    SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CALLEYNUMERO) INTO V_DATOS_GEN_CALLEYNUMERO FROM DUAL;     
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'BARRIDO' THEN
                    IF TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CALLEYNUMERO) IS NULL THEN
                      RAISE E_EXCEPTION_ISNULL;            
                    ELSE  
                      SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CALLEYNUMERO) INTO V_DATOS_GEN_CALLEYNUMERO  FROM DUAL;       
                    END IF;
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CALLEYNUMERO || ' :NO DEBE SER NULO PARA BARRIDO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_CALLEYNUMERO';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CALLEYNUMERO || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_CALLEYNUMERO';
                END;
  
                BEGIN /*********VALIDA DATOS_GEN_COLONIAYCIUDAD**********/
                  IF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'INEGI' THEN
                    SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_COLONIAYCIUDAD) INTO V_DATOS_GEN_COLONIAYCIUDAD FROM DUAL;     
                  ELSIF UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).FUENTE)) = 'BARRIDO' THEN
                    IF TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_COLONIAYCIUDAD) IS NULL THEN
                      RAISE E_EXCEPTION_ISNULL;            
                    ELSE  
                      SELECT TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_COLONIAYCIUDAD) INTO V_DATOS_GEN_COLONIAYCIUDAD  FROM DUAL;       
                    END IF;
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_COLONIAYCIUDAD || ' :NO DEBE SER NULO PARA BARRIDO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_COLONIAYCIUDAD';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_COLONIAYCIUDAD || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_COLONIAYCIUDAD';
                END;    
                
                BEGIN /*********VALIDA DATOS_GEN_CODIGOPOSTAL**********/
                  V_DATOS_GEN_CODIGOPOSTAL := TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CODIGOPOSTAL);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CODIGOPOSTAL || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_CODIGOPOSTAL';
                END;
  
                BEGIN /*********VALIDA DATOS_GEN_ESTADO**********/
                  V_DATOS_GEN_ESTADO := TRIM(LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_ESTADO);
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_COLONIAYCIUDAD || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'DATOS_GEN_ESTADO';
                END;
  
                BEGIN /*********VALIDA CLIENTE_POTENCIAL**********/
                  IF  UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).CLIENTE_POTENCIAL)) != 'SI' AND 
                      UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).CLIENTE_POTENCIAL)) != 'NO' THEN
                    RAISE E_EXCEPTION_DATA_DIFERENT;
                  ELSE
                    V_CLIENTE_POTENCIAL := UPPER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).CLIENTE_POTENCIAL));
                  END IF;
                EXCEPTION WHEN E_EXCEPTION_DATA_DIFERENT THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE RESTRICCION DE OPCIONES: ' || LIST_ENCUESTAS_CARGADAS(IDX).CLIENTE_POTENCIAL || ' :DEBE SER ''SI'' O ''NO''';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'CLIENTE_POTENCIAL';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).CLIENTE_POTENCIAL || ' :VERIFICAR EL DATO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'CLIENTE_POTENCIAL';
                END;
  
                BEGIN /*********VALIDA TERRITORIO**********/
                  IF LIST_ENCUESTAS_CARGADAS(IDX).TERRITORIO IS NULL THEN
                    RAISE E_EXCEPTION_ISNULL;
                  ELSE
                    V_TERRITORIO := TO_NUMBER(TRIM(LIST_ENCUESTAS_CARGADAS(IDX).TERRITORIO));
                  END IF;
                EXCEPTION 
                  WHEN E_EXCEPTION_ISNULL THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR DE NULL: ' || LIST_ENCUESTAS_CARGADAS(IDX).TERRITORIO || ' :NO DEBE SER NULO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'TERRITORIO';
                  WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL CONVERTIR: '|| LIST_ENCUESTAS_CARGADAS(IDX).TERRITORIO || ' :DEBE SER SOLO NUMERICO';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'TERRITORIO';
                END;
  
  
                --TRATAMIENTO DE DATOS PARA LA ENCUESTA (TERRITORIO)
                BEGIN
                  SELECT (TO_CHAR(TO_DATE(V_FECHA_INICIO, 'DD-Mon-YY HH:MI:SS'),'YYYY')||V_SEMANA) INTO V_ANIO_SEMANA FROM DUAL;
                  SELECT DECODE(V_DIA_VISITA,'LUNES',1,'MARTES',2,'MIÉRCOLES',3,'JUEVES',4,'VIERNES',5,'SÁBADO',6) INTO V_DIA_SEMANA FROM DUAL;
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL GENERAR LA CLAVE TERRITORIO + SEMANA(AÑO + SEMANA) + #DIA_VISITA';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'GENERACION_CLAVE_UNICA';
                END;
              
              
                --VALIDACION CON INFORMACION INEGI
                BEGIN
                  SELECT NVL(COUNT(*),0) INTO V_VALIDA_DESCARTE_INEGI
                    FROM ENCUESTAS_CLIENTES_INEGI ECI
                    WHERE ECI.TERRITORIO = LIST_ENCUESTAS_CARGADAS(IDX).TERRITORIO
                    AND   ECI.SEMANA = LIST_ENCUESTAS_CARGADAS(IDX).SEMANA
                    AND   ECI.DIA_DE_VISITA = LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA
                    AND   ECI.CONSECUTIVO = LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO;
                    
                  IF V_VALIDA_DESCARTE_INEGI = 0 AND V_FUENTE = 'INEGI'  THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'LA ENCUESTA NO SE ENCONTRO EN LA INFORMACION DE INEGI';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'NO_EN_INEGI';
                    
                    --Contabiliza las encuestas invalidas por INEGI
                    V_COUNT_INVALIDAS_INEGI_AUX := V_COUNT_INVALIDAS_INEGI_AUX + 1;
                  END IF;
                EXCEPTION WHEN OTHERS THEN
                    --Agregamos mas 1 para incrementar el indice para la lista de errores
                    V_IDX_ERRORES := V_IDX_ERRORES+1; V_COUNT_ENCUESTA_ERROR := V_COUNT_ENCUESTA_ERROR+1;
                    --Obtenemos el consecutivo del error
                    V_NEXT_IDERROR := V_NEXT_IDERROR+1; 
                    --Llena la lista del detalle del error
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDERROR := V_NEXT_IDERROR;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).IDENCUESTA_INVALIDA := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).FECHA_REGISTRO := SYSDATE;
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).MENSAJE_DETALLE := 'ERROR AL VALIDAR LA ENCUESTA CON LA INFORMACION DE INEGI';
                    LIST_ENCUESTAS_ERRORES(V_IDX_ERRORES).CAMPO_ERROR := 'NO_EN_INEGI';
                END;
              
                BEGIN
                
                  --AGREGA A LISTA LAS ENCUESTAS VALIDAS E INVALIDAS 
                  IF V_COUNT_ENCUESTA_ERROR != 0 THEN
                    --Contabiliza las encuestas invalidas por INEGI
                    V_COUNT_INVALIDAS_ERRORES_AUX := V_COUNT_INVALIDAS_ERRORES_AUX + 1;
  
                    --Incrementa indice de la lista de encuestas
                    V_IDX_INVALIDAS             := V_IDX_INVALIDAS + 1;
                  
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).IDENCUESTA_INVALIDA       := V_NEXT_IDENCUESTA_INVALIDA;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).TERRITORIO                := V_TERRITORIO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).ANIO_SEMANA               := V_ANIO_SEMANA;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DIA_SEMANA                := V_DIA_SEMANA;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).IDENCUESTADO              := V_IDENCUESTADO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).IDENCUESTADOR             := V_IDENCUESTADOR;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).FECHA_INICIO              := V_FECHA_INICIO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).FECHA_FIN                 := V_FECHA_FIN;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DIRECCIONIP               := V_DIRECCIONIP;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).E_MAIL                    := V_E_MAIL;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).NOMBRE                    := V_NOMBRE;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).APELLIDO                  := V_APELLIDO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DATOS_PERSONALIZADOS      := V_DATOS_PERSONALIZADOS;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).FUENTE                    := V_FUENTE;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENDE_CIGARRO             := V_VENDE_CIGARRO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VISITADO_BAT              := V_VISITADO_BAT;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).CUANTO_VENDE              := V_CUANTO_VENDE;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_PALLMALL        := V_VENTA_SEM_PALLMALL;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_LUCKYSTRIKE     := V_VENTA_SEM_LUCKYSTRIKE;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_SHOTS           := V_VENTA_SEM_SHOTS;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_CAMEL           := V_VENTA_SEM_CAMEL;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_OTRASBAT        := V_VENTA_SEM_OTRASBAT;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_MARLBORO        := V_VENTA_SEM_MARLBORO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_BENSONHEADGES   := V_VENTA_SEM_BENSONHEADGES;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_DELICADOS       := V_VENTA_SEM_DELICADOS;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_OTRASPMI        := V_VENTA_SEM_OTRASPMI;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).VENTA_SEM_OTRASMARCAS     := V_VENTA_SEM_OTRASMARCAS;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).COORDENADAS               := V_COORDENADAS;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).TIENE_EXHIBIDOR           := V_TIENE_EXHIBIDOR;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).TELEFONO                  := V_TELEFONO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).SEMANA                    := V_SEMANA;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DIA_VISITA                := V_DIA_VISITA;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).CONSECUTIVO               := V_CONSECUTIVO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).NOMBRE_CONTACTO           := V_NOMBRE_CONTACTO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DATOS_GEN_NOMBRETIENDA    := V_DATOS_GEN_NOMBRETIENDA;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DATOS_GEN_CALLEYNUMERO    := V_DATOS_GEN_CALLEYNUMERO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DATOS_GEN_COLONIAYCIUDAD  := V_DATOS_GEN_COLONIAYCIUDAD;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DATOS_GEN_CODIGOPOSTAL    := V_DATOS_GEN_CODIGOPOSTAL;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).DATOS_GEN_ESTADO          := V_DATOS_GEN_ESTADO;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).CLIENTE_POTENCIAL         := V_CLIENTE_POTENCIAL;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).FECHA_REGISTRO            := SYSDATE;
                    LIST_ENCUESTAS_INVALIDAS(V_IDX_INVALIDAS).IDEJECUCION               := V_NEXT_IDEJECUCION;
                    
                    --Incrementa el consecutivo del encuesta invalida
                    V_NEXT_IDENCUESTA_INVALIDA  := V_NEXT_IDENCUESTA_INVALIDA+1;
                  ELSE
                    --Incrementa indice de la lista de encuestas
                    V_IDX_VALIDAS                   := V_IDX_VALIDAS + 1;
  
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).IDENCUESTA                := V_NEXT_IDENCUESTA;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).TERRITORIO                := V_TERRITORIO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).ANIO_SEMANA               := V_ANIO_SEMANA;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DIA_SEMANA                := V_DIA_SEMANA;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).IDENCUESTADO              := V_IDENCUESTADO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).IDENCUESTADOR             := V_IDENCUESTADOR;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).FECHA_INICIO              := V_FECHA_INICIO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).FECHA_FIN                 := V_FECHA_FIN;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DIRECCIONIP               := V_DIRECCIONIP;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).E_MAIL                    := V_E_MAIL;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).NOMBRE                    := V_NOMBRE;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).APELLIDO                  := V_APELLIDO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DATOS_PERSONALIZADOS      := V_DATOS_PERSONALIZADOS;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).FUENTE                    := V_FUENTE;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENDE_CIGARRO             := V_VENDE_CIGARRO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VISITADO_BAT              := V_VISITADO_BAT;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).CUANTO_VENDE              := V_CUANTO_VENDE;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_PALLMALL        := V_VENTA_SEM_PALLMALL;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_LUCKYSTRIKE     := V_VENTA_SEM_LUCKYSTRIKE;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_SHOTS           := V_VENTA_SEM_SHOTS;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_CAMEL           := V_VENTA_SEM_CAMEL;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_OTRASBAT        := V_VENTA_SEM_OTRASBAT;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_MARLBORO        := V_VENTA_SEM_MARLBORO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_BENSONHEADGES   := V_VENTA_SEM_BENSONHEADGES;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_DELICADOS       := V_VENTA_SEM_DELICADOS;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_OTRASPMI        := V_VENTA_SEM_OTRASPMI;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).VENTA_SEM_OTRASMARCAS     := V_VENTA_SEM_OTRASMARCAS;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).COORDENADAS               := V_COORDENADAS;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).TIENE_EXHIBIDOR           := V_TIENE_EXHIBIDOR;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).TELEFONO                  := V_TELEFONO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).SEMANA                    := V_SEMANA;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DIA_VISITA                := V_DIA_VISITA;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).CONSECUTIVO               := V_CONSECUTIVO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).NOMBRE_CONTACTO           := V_NOMBRE_CONTACTO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DATOS_GEN_NOMBRETIENDA    := V_DATOS_GEN_NOMBRETIENDA;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DATOS_GEN_CALLEYNUMERO    := V_DATOS_GEN_CALLEYNUMERO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DATOS_GEN_COLONIAYCIUDAD  := V_DATOS_GEN_COLONIAYCIUDAD;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DATOS_GEN_CODIGOPOSTAL    := V_DATOS_GEN_CODIGOPOSTAL;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).DATOS_GEN_ESTADO          := V_DATOS_GEN_ESTADO;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).CLIENTE_POTENCIAL         := V_CLIENTE_POTENCIAL;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).FECHA_REGISTRO            := SYSDATE;
                    LIST_ENCUESTAS_VALIDAS(V_IDX_VALIDAS).ESTATUS                   := 0;
                    
                    --Incrementa el consecutivo del encuesta valida
                    V_NEXT_IDENCUESTA   := V_NEXT_IDENCUESTA+1;
                    --Incrementa el consecutivo del encuesta procesada (solo aquellas validas)
                    V_IDX_PROCESADAS    := V_IDX_PROCESADAS+1;
                    --Agrega registro a la colección para status de encuesta procesada
                    LIST_ENCUESTAS_PROCESADAS(V_IDX_PROCESADAS) := LIST_ENCUESTAS_CARGADAS(IDX).ROWID;
                END IF;
                EXCEPTION WHEN OTHERS THEN
                  DBMS_OUTPUT.PUT_LINE('ERROR EN ENCUESTA VALIDA: '|| V_NEXT_IDENCUESTA ||' '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK);
                END;
                
                --Conteo General de proceso cargados
                V_COUNT_CARGADAS := V_COUNT_CARGADAS + 1;
            END LOOP;
             
            --Inserta las encuestas validas
            FORALL IDX_VALIDAS IN LIST_ENCUESTAS_VALIDAS.FIRST .. LIST_ENCUESTAS_VALIDAS.LAST
              INSERT INTO EAI.ENCUESTAS_CLIENTES_VALIDAS VALUES LIST_ENCUESTAS_VALIDAS(idx_validas);
            
            --inserta encuestas invalidas
            FORALL IDX_INVALIDAS IN LIST_ENCUESTAS_INVALIDAS.FIRST .. LIST_ENCUESTAS_INVALIDAS.LAST
              INSERT INTO EAI.ENCUESTAS_CLIENTES_INVALIDAS VALUES LIST_ENCUESTAS_INVALIDAS(idx_invalidas);
            
            --inserta el detalle del por que las encuestas invalidas (errores)
            FORALL IDX_ERRORES IN LIST_ENCUESTAS_ERRORES.FIRST .. LIST_ENCUESTAS_ERRORES.LAST
              INSERT INTO EAI.ENCUESTAS_CLIENTES_ERRORES VALUES LIST_ENCUESTAS_ERRORES(idx_errores);
  
            --actualiza las a estatus procesado = 1 las encuestas validas
            FORALL IDX_PROCESADAS IN LIST_ENCUESTAS_PROCESADAS.FIRST .. LIST_ENCUESTAS_PROCESADAS.LAST
              UPDATE EAI.ENCUESTAS_CLIENTES_CARGADAS SET procesado = 1 WHERE ROWID = LIST_ENCUESTAS_PROCESADAS(idx_procesadas);
            
            --conteo de encuestas validas
            V_COUNT_VALIDAS := V_COUNT_VALIDAS + LIST_ENCUESTAS_VALIDAS.COUNT;
            
            --Conteo de encuestas invalidas por INEGI
            V_COUNT_INVALIDAS_INEGI := V_COUNT_INVALIDAS_INEGI + V_COUNT_INVALIDAS_INEGI_AUX;
  
            --Conteo de encuestas invalidas por errores de validacion de datos
            V_COUNT_INVALIDAS_ERRORES := V_COUNT_INVALIDAS_ERRORES + V_COUNT_INVALIDAS_ERRORES_AUX;
  
            COMMIT;
  
        END LOOP;
      CLOSE C_ENCUESTAS;
      
      --INICIA LA ACTUALIZACION DEL INDICADOR DE LAS ENCUESTAS MAS RECIENTES
      BEGIN
        LIST_ENCUESTAS_BUENAS.EXTEND(500);
        
        OPEN C_ENCUESTAS_VALIDAS;
          LOOP
          fetch C_ENCUESTAS_VALIDAS 
            BULK COLLECT INTO LIST_ENCUESTAS_VALIDAS_UPD LIMIT 100;
            EXIT WHEN LIST_ENCUESTAS_VALIDAS_UPD.COUNT = 0;
              
            V_IDX_VALIDAS_UPD               := 0;
            
            FOR IDX IN LIST_ENCUESTAS_VALIDAS_UPD.FIRST .. LIST_ENCUESTAS_VALIDAS_UPD.LAST
            LOOP  
  
                --Verifica si la encuesta es de BARRIDO o INEGI
                IF LIST_ENCUESTAS_VALIDAS_UPD(IDX).FUENTE = 'BARRIDO' THEN
                  V_IDX_VALIDAS_UPD := V_IDX_VALIDAS_UPD + 1;
                  LIST_ENCUESTAS_BUENAS(V_IDX_VALIDAS_UPD) := LIST_ENCUESTAS_VALIDAS_UPD(IDX).ROWID;
                ELSIF LIST_ENCUESTAS_VALIDAS_UPD(IDX).FUENTE = 'INEGI' THEN
                  --Busca cual es la encuesta mas actual
                  FOR ENCUESTA IN (SELECT MAX(FECHA_INICIO) MAS_ACTUAL, ROWID CLAVE FROM EAI.ENCUESTAS_CLIENTES_VALIDAS ECV
                                      WHERE ECV.TERRITORIO = LIST_ENCUESTAS_VALIDAS_UPD(IDX).TERRITORIO
                                      AND   ECV.ANIO_SEMANA = LIST_ENCUESTAS_VALIDAS_UPD(IDX).ANIO_SEMANA
                                      AND   ECV.DIA_SEMANA = LIST_ENCUESTAS_VALIDAS_UPD(IDX).DIA_SEMANA
                                      AND   ECV.CONSECUTIVO = LIST_ENCUESTAS_VALIDAS_UPD(IDX).CONSECUTIVO
                                      GROUP BY ROWID) LOOP
  
                    V_IDX_VALIDAS_UPD := V_IDX_VALIDAS_UPD+1;
                    LIST_ENCUESTAS_BUENAS(V_IDX_VALIDAS_UPD) := ENCUESTA.CLAVE;
                                    
                  END LOOP;
                END IF;
  
            END LOOP;
            
            --actualiza las a estatus procesado = 1 las encuestas validas
            FORALL IDX_BUENAS IN LIST_ENCUESTAS_BUENAS.FIRST .. LIST_ENCUESTAS_BUENAS.LAST
              UPDATE EAI.ENCUESTAS_CLIENTES_VALIDAS SET estatus = 1 WHERE ROWID = LIST_ENCUESTAS_BUENAS(idx_buenas);
    
            COMMIT;
    
          END LOOP;
        CLOSE C_ENCUESTAS_VALIDAS;
      EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK);
        V_MENSAJE_BITACORA := 'error en actualizacion para encuestas mas recientes: '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK;
        IF C_ENCUESTAS_VALIDAS%ISOPEN THEN
          CLOSE C_ENCUESTAS_VALIDAS;
        END IF;
      END;      
      
      --Parte Final - Inserta informacion en Bitacora
      DBMS_OUTPUT.PUT_LINE('Registros Validados: ' || V_COUNT_CARGADAS);
  
      end_date:= SYSDATE;
      SELECT TRUNC(ROUND(((end_date-start_date)*24),2))||':'||TO_CHAR(TO_DATE(ROUND((ROUND(((end_date-start_date)*24),2)-TRUNC(ROUND(((end_date-start_date)*24),2)))*60),'mi'),'mi') INTO V_TIEMPO_EJECUCION 
        FROM DUAL;
      
      --Asignacion ESTATUS
      IF (V_COUNT_INVALIDAS_ERRORES+V_COUNT_INVALIDAS_INEGI) != 0 THEN
        V_STATUS := 2;
        v_mensaje_bitacora := 'Verifique el excel de resultados de validación.';
      ELSE
        V_STATUS := 1;
        v_mensaje_bitacora := 'Successfull';
      END IF;
      
      INSERT INTO EAI.ENCUESTAS_CLIENTES_BITACORA(IDEJECUCION,FECHA_HORA,TIEMPO_EJECUCION,ESTATUS,CARGADOS,DESCARTADOS_INEGI,DESCARTADOS_ERRORES, CARGADAS_VALIDAS, MENSAJE)
      VALUES(V_NEXT_IDEJECUCION, SYSDATE, V_TIEMPO_EJECUCION, V_STATUS, V_COUNT_CARGADAS, V_COUNT_INVALIDAS_INEGI, V_COUNT_INVALIDAS_ERRORES, V_COUNT_VALIDAS, v_mensaje_bitacora);
      
      COMMIT;
      
      DBMS_OUTPUT.PUT_LINE('Tiempo de Ejecución: Horas:Minutos - '||V_TIEMPO_EJECUCION);
      DBMS_OUTPUT.PUT_LINE('Ejecución y validación completa.');
      DBMS_OUTPUT.PUT_LINE('TERMINA PROCESO');
  EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK);
      SELECT TRUNC(ROUND(((SYSDATE-start_date)*24),2))||':'||TO_CHAR(TO_DATE(ROUND((ROUND(((SYSDATE-start_date)*24),2)-TRUNC(ROUND(((SYSDATE-start_date)*24),2)))*60),'mi'),'mi') INTO V_TIEMPO_EJECUCION 
        FROM DUAL;
      DBMS_OUTPUT.PUT_LINE('Tiempo de Ejecución: Horas:Minutos - '||V_TIEMPO_EJECUCION);
      dbms_output.put_line('Ocurrio un error durante la ejecución.');
      DBMS_OUTPUT.PUT_LINE('TERMINA PROCESO');
      
      IF C_ENCUESTAS%ISOPEN  THEN
        CLOSE C_ENCUESTAS;
      END IF;
      ROLLBACK;
      --Asignacion ESTATUS
      IF (V_COUNT_INVALIDAS_ERRORES+V_COUNT_INVALIDAS_INEGI) != 0 THEN
        V_STATUS := 4;
      ELSE
        V_STATUS := 3;
      END IF;
      
      INSERT INTO EAI.ENCUESTAS_CLIENTES_BITACORA(IDEJECUCION,FECHA_HORA,TIEMPO_EJECUCION,ESTATUS,CARGADOS,DESCARTADOS_INEGI,DESCARTADOS_ERRORES, CARGADAS_VALIDAS, MENSAJE)
      VALUES(V_NEXT_IDEJECUCION, SYSDATE, V_TIEMPO_EJECUCION, V_STATUS, V_COUNT_CARGADAS, V_COUNT_INVALIDAS_INEGI, V_COUNT_INVALIDAS_ERRORES, V_COUNT_VALIDAS, 'error: '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK);
      COMMIT;
  END PRC_VALIDA_ENCUESTAS;
  
--------------------------------------------------------
--  DDL -- Procedure PRC_REPORTE_ENCUESTAS create by Azael Gutierrez
--------------------------------------------------------  
  PROCEDURE PRC_REPORTE_ENCUESTAS AS
  
    V_IDX_RESUMEN                 NUMBER := 0;
    V_IDENCUESTADO	              NUMBER(30,0);
    
    CURSOR C_ENCUESTAS IS
    SELECT  ROWID,                    IDENCUESTADO,           IDENCUESTADOR,      FECHA_INICIO,             FECHA_FIN,          DIRECCIONIP,        E_MAIL,NOMBRE,          APELLIDO,       
            DATOS_PERSONALIZADOS,     FUENTE,                 VENDE_CIGARRO,      VISITADO_BAT,             CUANTO_VENDE,       VENTA_SEM_PALLMALL, VENTA_SEM_LUCKYSTRIKE,  VENTA_SEM_SHOTS,
            VENTA_SEM_CAMEL,          VENTA_SEM_OTRASBAT,     VENTA_SEM_MARLBORO, VENTA_SEM_BENSONHEADGES,  VENTA_SEM_DELICADOS,VENTA_SEM_OTRASPMI, VENTA_SEM_OTRASMARCAS,  COORDENADAS,
            TIENE_EXHIBIDOR,          TELEFONO,               SEMANA,             DIA_VISITA,               CONSECUTIVO,        NOMBRE_CONTACTO,    DATOS_GEN_NOMBRETIENDA, DATOS_GEN_CALLEYNUMERO,
            DATOS_GEN_COLONIAYCIUDAD, DATOS_GEN_CODIGOPOSTAL, DATOS_GEN_ESTADO,   CLIENTE_POTENCIAL,        TERRITORIO,         SUPERVISOR
        FROM ENCUESTAS_CLIENTES_CARGADAS;
        
    TYPE BLK_CUR_ENCUESTAS_CARGADAS IS TABLE OF C_ENCUESTAS%ROWTYPE INDEX BY BINARY_INTEGER;
    TYPE BLK_TBL_ENCUESTAS_RESUMEN IS TABLE OF ENCUESTAS_CLIENTES_RESUMEN%ROWTYPE INDEX BY BINARY_INTEGER;
    
    LIST_ENCUESTAS_CARGADAS     BLK_CUR_ENCUESTAS_CARGADAS;
    LIST_ENCUESTAS_RESUMEN      BLK_TBL_ENCUESTAS_RESUMEN;    
    
  BEGIN
    
    --EXECUTE IMMEDIATE 'TRUNCATE TABLE EAI.ENCUESTAS_CLIENTES_RESUMEN';
    DELETE FROM CEDIS.ENCUESTAS_CLIENTES_RESUMEN@V3CEDIS;
    
    OPEN C_ENCUESTAS;
      LOOP
      fetch C_ENCUESTAS 
        BULK COLLECT INTO LIST_ENCUESTAS_CARGADAS LIMIT 100;
        EXIT WHEN LIST_ENCUESTAS_CARGADAS.COUNT = 0;
          
          LIST_ENCUESTAS_RESUMEN.DELETE;
          V_IDX_RESUMEN     := 0;
          
          FOR IDX IN LIST_ENCUESTAS_CARGADAS.FIRST .. LIST_ENCUESTAS_CARGADAS.LAST
          LOOP

              DELETE EAI.ENCUESTAS_CLIENTES_RESUMEN WHERE IDENCUESTADO = LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADO;
              COMMIT;
              
              V_IDX_RESUMEN := V_IDX_RESUMEN+1;
              
              SELECT NVL(TO_NUMBER(LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADO),0) INTO V_IDENCUESTADO  FROM DUAL;
              
              --LLENA DATOS DE LAS ENCUESTAS CARGADAS
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).TERRITORIO                    := LIST_ENCUESTAS_CARGADAS(IDX).TERRITORIO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).IDENCUESTADO                  := LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).IDENCUESTADOR                 := LIST_ENCUESTAS_CARGADAS(IDX).IDENCUESTADOR;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).FECHA_INICIO                  := LIST_ENCUESTAS_CARGADAS(IDX).FECHA_INICIO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).FECHA_FIN                     := LIST_ENCUESTAS_CARGADAS(IDX).FECHA_FIN;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DIRECCIONIP                   := LIST_ENCUESTAS_CARGADAS(IDX).DIRECCIONIP;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).E_MAIL                        := LIST_ENCUESTAS_CARGADAS(IDX).E_MAIL;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).NOMBRE                        := LIST_ENCUESTAS_CARGADAS(IDX).NOMBRE;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).APELLIDO                      := LIST_ENCUESTAS_CARGADAS(IDX).APELLIDO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DATOS_PERSONALIZADOS          := LIST_ENCUESTAS_CARGADAS(IDX).DATOS_PERSONALIZADOS;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).FUENTE                        := LIST_ENCUESTAS_CARGADAS(IDX).FUENTE;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENDE_CIGARRO                 := LIST_ENCUESTAS_CARGADAS(IDX).VENDE_CIGARRO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VISITADO_BAT                  := LIST_ENCUESTAS_CARGADAS(IDX).VISITADO_BAT;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).CUANTO_VENDE                  := LIST_ENCUESTAS_CARGADAS(IDX).CUANTO_VENDE;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_PALLMALL            := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_PALLMALL;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_LUCKYSTRIKE         := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_LUCKYSTRIKE;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_SHOTS               := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_SHOTS;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_CAMEL               := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_CAMEL;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_OTRASBAT            := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASBAT;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_MARLBORO            := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_MARLBORO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_BENSONHEADGES       := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_BENSONHEADGES;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_DELICADOS           := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_DELICADOS;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_OTRASPMI            := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASPMI;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VENTA_SEM_OTRASMARCAS         := LIST_ENCUESTAS_CARGADAS(IDX).VENTA_SEM_OTRASMARCAS;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).COORDENADAS                   := LIST_ENCUESTAS_CARGADAS(IDX).COORDENADAS;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).TIENE_EXHIBIDOR               := LIST_ENCUESTAS_CARGADAS(IDX).TIENE_EXHIBIDOR;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).TELEFONO                      := LIST_ENCUESTAS_CARGADAS(IDX).TELEFONO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).SEMANA                        := LIST_ENCUESTAS_CARGADAS(IDX).SEMANA;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DIA_VISITA                    := LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).CONSECUTIVO                   := LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).NOMBRE_CONTACTO               := LIST_ENCUESTAS_CARGADAS(IDX).NOMBRE_CONTACTO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DATOS_GEN_NOMBRETIENDA        := LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_NOMBRETIENDA;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DATOS_GEN_CALLEYNUMERO        := LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CALLEYNUMERO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DATOS_GEN_COLONIAYCIUDAD      := LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_COLONIAYCIUDAD;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DATOS_GEN_CODIGOPOSTAL        := LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_CODIGOPOSTAL;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).DATOS_GEN_ESTADO              := LIST_ENCUESTAS_CARGADAS(IDX).DATOS_GEN_ESTADO;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).CLIENTE_POTENCIAL             := LIST_ENCUESTAS_CARGADAS(IDX).CLIENTE_POTENCIAL;
              --SEGUNDA PARTE LLENA CUALES CAMPOS DE LAS ENCUESTAS CARGADAS SON INVALIDOS o NO
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_NO_EN_INEGI               := FNC_REVISA_CAMPO_VALIDO('NO_EN_INEGI', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_TERRITORIO                := FNC_REVISA_CAMPO_VALIDO('TERRITORIO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_IDENCUESTADO              := FNC_REVISA_CAMPO_VALIDO('IDENCUESTADO', V_IDENCUESTADO); 
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_IDENCUESTADOR             := FNC_REVISA_CAMPO_VALIDO('IDENCUESTADOR', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_FECHA_INICIO              := FNC_REVISA_CAMPO_VALIDO('FECHA_INICIO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_FECHA_FIN                 := FNC_REVISA_CAMPO_VALIDO('FECHA_FIN', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DIRECCIONIP               := FNC_REVISA_CAMPO_VALIDO('DIRECCIONIP', V_IDENCUESTADO); 
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_E_MAIL                    := FNC_REVISA_CAMPO_VALIDO('E_MAIL', V_IDENCUESTADO); 
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_NOMBRE                    := FNC_REVISA_CAMPO_VALIDO('NOMBRE', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_APELLIDO                  := FNC_REVISA_CAMPO_VALIDO('APELLIDO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DATOS_PERSONALIZADOS      := FNC_REVISA_CAMPO_VALIDO('DATOS_PERSONALIZADOS', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_FUENTE                    := FNC_REVISA_CAMPO_VALIDO('FUENTE', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENDE_CIGARRO             := FNC_REVISA_CAMPO_VALIDO('VENDE_CIGARRO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VISITADO_BAT              := FNC_REVISA_CAMPO_VALIDO('VISITADO_BAT', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_CUANTO_VENDE              := FNC_REVISA_CAMPO_VALIDO('CUANTO_VENDE', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_PALLMALL        := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_PALLMALL', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_LUCKYSTRIKE     := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_LUCKYSTRIKE', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_SHOTS           := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_SHOTS', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_CAMEL           := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_CAMEL', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_OTRASBAT        := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_OTRASBAT', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_MARLBORO        := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_MARLBORO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_BENSONHEADGES   := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_BENSONHEADGES', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_DELICADOS       := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_DELICADOS', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_OTRASPMI        := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_OTRASPMI', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_VENTA_SEM_OTRASMARCAS     := FNC_REVISA_CAMPO_VALIDO('VENTA_SEM_OTRASMARCAS', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_COORDENADAS               := FNC_REVISA_CAMPO_VALIDO('COORDENADAS', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_TIENE_EXHIBIDOR           := FNC_REVISA_CAMPO_VALIDO('TIENE_EXHIBIDOR', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_TELEFONO                  := FNC_REVISA_CAMPO_VALIDO('TELEFONO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_SEMANA                    := FNC_REVISA_CAMPO_VALIDO('SEMANA', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DIA_VISITA                := FNC_REVISA_CAMPO_VALIDO('DIA_VISITA', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_CONSECUTIVO               := FNC_REVISA_CAMPO_VALIDO('CONSECUTIVO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_NOMBRE_CONTACTO           := FNC_REVISA_CAMPO_VALIDO('NOMBRE_CONTACTO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DATOS_GEN_NOMBRETIENDA    := FNC_REVISA_CAMPO_VALIDO('DATOS_GEN_NOMBRETIENDA', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DATOS_GEN_CALLEYNUMERO    := FNC_REVISA_CAMPO_VALIDO('DATOS_GEN_CALLEYNUMERO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DATOS_GEN_COLONIAYCIUDAD  := FNC_REVISA_CAMPO_VALIDO('DATOS_GEN_COLONIAYCIUDAD', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DATOS_GEN_CODIGOPOSTAL    := FNC_REVISA_CAMPO_VALIDO('DATOS_GEN_CODIGOPOSTAL', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_DATOS_GEN_ESTADO          := FNC_REVISA_CAMPO_VALIDO('DATOS_GEN_ESTADO', V_IDENCUESTADO);
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).VLD_CLIENTE_POTENCIAL         := FNC_REVISA_CAMPO_VALIDO('CLIENTE_POTENCIAL', V_IDENCUESTADO);
              
              --LLENA DATOS DE INEGI
              IF LIST_ENCUESTAS_CARGADAS(IDX).FUENTE = 'INEGI' THEN
                BEGIN
                  SELECT  NOM_ESTAB,                                                CALLE,              
                          NUMERO_EXT,                                               COLONIA,              
                          COD_POSTAL,                                               ENTIDAD,            
                          MUNICIPIO,                                                LOCALIDAD,              
                          TELEFONO,                                                 LATITUD,      
                          LONGITUD,                                                 ID_BAT,                   
                          CLAVE
                     INTO LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_NOM_ESTAB,    LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_CALLE,
                          LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_NUMERO_EXT,   LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_COLONIA,
                          LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_COD_POSTAL,   LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_ENTIDAD,
                          LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_MUNICIPIO,    LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_LOCALIDAD,
                          LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_TELEFONO,     LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_LATITUD,
                          LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_LONGITUD,     LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_ID_BAT,
                          LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).INEGI_CLAVE
                  FROM ENCUESTAS_CLIENTES_INEGI ECI
                  WHERE ECI.TERRITORIO = LIST_ENCUESTAS_CARGADAS(IDX).TERRITORIO
                  AND   ECI.SEMANA = LIST_ENCUESTAS_CARGADAS(IDX).SEMANA
                  AND   ECI.DIA_DE_VISITA = LIST_ENCUESTAS_CARGADAS(IDX).DIA_VISITA
                  AND   ECI.CONSECUTIVO = LIST_ENCUESTAS_CARGADAS(IDX).CONSECUTIVO;
                EXCEPTION WHEN OTHERS THEN
                  NULL;
                END;
              END IF;
              LIST_ENCUESTAS_RESUMEN(V_IDX_RESUMEN).SUPERVISOR                    := LIST_ENCUESTAS_CARGADAS(IDX).SUPERVISOR;
            
          END LOOP;
           
          --Inserta las encuestas validas
          FORALL IDX_RESUMEN IN LIST_ENCUESTAS_RESUMEN.FIRST .. LIST_ENCUESTAS_RESUMEN.LAST
            INSERT INTO EAI.ENCUESTAS_CLIENTES_RESUMEN VALUES LIST_ENCUESTAS_RESUMEN(IDX_RESUMEN);
          COMMIT;

      END LOOP;
    CLOSE C_ENCUESTAS;          
    
    --INSERTA LA INFORMACION DE ENCUESTAS VALIDAS A BO
    INSERT INTO CEDIS.ENCUESTAS_CLIENTES_RESUMEN@V3CEDIS 
    SELECT  ECR.TERRITORIO, ECR.IDENCUESTADOR, ECR.IDENCUESTADO, ECR.FECHA_INICIO, ECR.FECHA_FIN, ECR.DIRECCIONIP, ECR.E_MAIL, ECR.NOMBRE, ECR.APELLIDO
            , ECR.DATOS_PERSONALIZADOS, ECR.FUENTE, ECR.VENDE_CIGARRO, ECR.VISITADO_BAT, ECR.CUANTO_VENDE, ECR.VENTA_SEM_PALLMALL, ECR.VENTA_SEM_LUCKYSTRIKE
            , ECR.VENTA_SEM_SHOTS, ECR.VENTA_SEM_CAMEL, ECR.VENTA_SEM_OTRASBAT, ECR.VENTA_SEM_MARLBORO, ECR.VENTA_SEM_BENSONHEADGES, ECR.VENTA_SEM_DELICADOS
            , ECR.VENTA_SEM_OTRASPMI, ECR.VENTA_SEM_OTRASMARCAS, ECR.COORDENADAS, ECR.TIENE_EXHIBIDOR, ECR.TELEFONO, ECR.SEMANA, ECR.DIA_VISITA, ECR.CONSECUTIVO
            , ECR.NOMBRE_CONTACTO, ECR.DATOS_GEN_NOMBRETIENDA, ECR.DATOS_GEN_CALLEYNUMERO, ECR.DATOS_GEN_COLONIAYCIUDAD, ECR.DATOS_GEN_CODIGOPOSTAL, ECR.DATOS_GEN_ESTADO
            , ECR.CLIENTE_POTENCIAL, ECR.VLD_NO_EN_INEGI, ECR.VLD_TERRITORIO, ECR.VLD_IDENCUESTADO, ECR.VLD_IDENCUESTADOR, ECR.VLD_FECHA_INICIO, ECR.VLD_FECHA_FIN
            , ECR.VLD_DIRECCIONIP, ECR.VLD_E_MAIL, ECR.VLD_NOMBRE, ECR.VLD_APELLIDO, ECR.VLD_DATOS_PERSONALIZADOS, ECR.VLD_FUENTE, ECR.VLD_VENDE_CIGARRO, ECR.VLD_VISITADO_BAT
            , ECR.VLD_CUANTO_VENDE, ECR.VLD_VENTA_SEM_PALLMALL, ECR.VLD_VENTA_SEM_LUCKYSTRIKE, ECR.VLD_VENTA_SEM_SHOTS, ECR.VLD_VENTA_SEM_CAMEL, ECR.VLD_VENTA_SEM_OTRASBAT
            , ECR.VLD_VENTA_SEM_MARLBORO, ECR.VLD_VENTA_SEM_BENSONHEADGES, ECR.VLD_VENTA_SEM_DELICADOS, ECR.VLD_VENTA_SEM_OTRASPMI, ECR.VLD_VENTA_SEM_OTRASMARCAS, ECR.VLD_COORDENADAS
            , ECR.VLD_TIENE_EXHIBIDOR, ECR.VLD_TELEFONO, ECR.VLD_SEMANA, ECR.VLD_DIA_VISITA, ECR.VLD_CONSECUTIVO, ECR.VLD_NOMBRE_CONTACTO, ECR.VLD_DATOS_GEN_NOMBRETIENDA
            , ECR.VLD_DATOS_GEN_CALLEYNUMERO, ECR.VLD_DATOS_GEN_COLONIAYCIUDAD, ECR.VLD_DATOS_GEN_CODIGOPOSTAL, ECR.VLD_DATOS_GEN_ESTADO, ECR.VLD_CLIENTE_POTENCIAL
            , ECR.INEGI_NOM_ESTAB, ECR.INEGI_CALLE, ECR.INEGI_NUMERO_EXT, ECR.INEGI_COLONIA, ECR.INEGI_COD_POSTAL, ECR.INEGI_ENTIDAD, ECR.INEGI_MUNICIPIO, ECR.INEGI_LOCALIDAD
            , ECR.INEGI_TELEFONO, ECR.INEGI_LATITUD, ECR.INEGI_LONGITUD, ECR.INEGI_ID_BAT, ECR.INEGI_CLAVE, DECODE(ECI.TERRITORIO,NULL,1,0) VALIDA, ECR.SUPERVISOR
      FROM EAI.ENCUESTAS_CLIENTES_RESUMEN ECR, ENCUESTAS_CLIENTES_INVALIDAS ECI
      WHERE ECI.TERRITORIO(+) = ECR.TERRITORIO
      AND   ECI.IDENCUESTADO(+) = ECR.IDENCUESTADO;
    COMMIT;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK);
  END PRC_REPORTE_ENCUESTAS;
  
  --------------------------------------------------------
  --  DDL -- Function FNC_REVISA_CAMPO_VALIDO create by Azael Gutierrez
  --------------------------------------------------------  
  FUNCTION FNC_REVISA_CAMPO_VALIDO( P_CAMPO         NVARCHAR2,
                                    P_IDENCUESTADO  NUMBER) RETURN NUMBER
  IS
    v_valido number;
  BEGIN
      SELECT  CASE WHEN NVL(COUNT(*),0) > 0 THEN 0 
              ELSE 1
              END INTO V_VALIDO
        FROM ENCUESTAS_CLIENTES_INVALIDAS ECI, ENCUESTAS_CLIENTES_ERRORES ECE
        WHERE ECI.IDENCUESTA_INVALIDA = ECE.IDENCUESTA_INVALIDA
        AND   ECI.IDENCUESTADO = P_IDENCUESTADO
        AND   ECE.CAMPO_ERROR = P_CAMPO;
        
      RETURN V_VALIDO;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||DBMS_UTILITY.FORMAT_ERROR_STACK);
  END FNC_REVISA_CAMPO_VALIDO;


End Pkg_Encuestas_Mkt;
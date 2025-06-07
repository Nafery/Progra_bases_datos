--CREACION DEL TRIGGER
CREATE OR REPLACE TRIGGER tr_resultado
BEFORE INSERT ON detalle_puntaje_postulacion
FOR EACH ROW
DECLARE
    v_resultado VARCHAR2(20);
BEGIN
    IF :NEW.ptje_annos_exp + :NEW.ptje_horas_trab +
        :NEW.ptje_zona_extrema + :NEW.ptje_ranking_inst +
        :NEW.ptje_extra_1 + :NEW.ptje_extra_2 > 4500 THEN 
        v_resultado := 'SELECCIONADO';
    ELSE
        v_resultado := 'NO SELECCIONADO';
    END IF;
    INSERT INTO resultado_postulacion
    VALUES (:NEW.run_postulante, :NEW.ptje_annos_exp + :NEW.ptje_horas_trab +
        :NEW.ptje_zona_extrema + :NEW.ptje_ranking_inst +
        :NEW.ptje_extra_1 + :NEW.ptje_extra_2, v_resultado); 
END tr_resultado;
/
--PROCEDIMIENTO PARA MANEJAR ERRORES
CREATE OR REPLACE PROCEDURE sp_salvame (
    p_run NUMBER, p_subp VARCHAR2, p_msg VARCHAR2
)
AS
    v_sql VARCHAR2(300);
BEGIN
    v_sql := 'INSERT INTO error_proceso
              VALUES (:1, :2, :3)';
    EXECUTE IMMEDIATE v_sql USING p_run, p_subp, p_msg;
END sp_salvame;
/

--FUNCION PARA OBTENER LA EXPERIENCIA
CREATE OR REPLACE FUNCTION fn_annos (
    p_run NUMBER, p_fecha DATE
) RETURN NUMBER
AS
    v_annos NUMBER;
    v_sql VARCHAR2(300);
BEGIN
    v_sql := 'SELECT ROUND((:1 - MIN(fecha_contrato))/365)
              FROM antecedentes_laborales
              WHERE numrun = :2';
    EXECUTE IMMEDIATE v_sql INTO v_annos USING p_fecha, p_run;
    RETURN v_annos;
END fn_annos;
/
    
--FUNCIÓN PARA OBTENER EL PUNTAJE POR EXPERIENCIA
CREATE OR REPLACE FUNCTION fn_ptjexp (
    p_annos NUMBER, p_run NUMBER
) RETURN NUMBER
AS
    v_ptjexp NUMBER;
    v_sql VARCHAR2(300);
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        v_sql := 'SELECT ptje_experiencia
                  FROM ptje_annos_experiencia
                  WHERE :1 BETWEEN rango_annos_ini AND rango_annos_ter';
        EXECUTE IMMEDIATE v_sql INTO v_ptjexp USING p_annos;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_ptjexp := 0;
            v_msg := SQLERRM;
            sp_salvame(p_run,'Error en '||$$PLSQL_UNIT||' al obtener el puntaje con años de experiencia: '||p_annos, v_msg);
    END;
    RETURN v_ptjexp;        
END fn_ptjexp;
/

--FUNCION PARA OBTENER LAS HORAS TRABAJADAS
CREATE OR REPLACE FUNCTION fn_horas(
    p_run NUMBER
) RETURN NUMBER
AS
    v_horas NUMBER;
    v_sql VARCHAR2(300);
BEGIN
    v_sql := 'SELECT SUM(horas_semanales)
              FROM antecedentes_laborales
              WHERE numrun = :1';
    EXECUTE IMMEDIATE v_sql INTO v_horas USING p_run;
    RETURN v_horas;
END fn_horas;
/

--FUNCION PARA CALCULAR EL PUNTAJE POR HORAS TRABAJADAS
CREATE OR REPLACE FUNCTION fn_ptjhoras(
    p_horas NUMBER, p_run NUMBER
) RETURN NUMBER
AS
    v_ptjhoras NUMBER;
    v_sql VARCHAR2(300);
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        v_sql := 'SELECT ptje_horas_trab
                  FROM ptje_horas_trabajo
                  WHERE :1 BETWEEN rango_horas_ini AND rango_horas_ter';
        EXECUTE IMMEDIATE v_sql INTO v_ptjhoras USING p_horas;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_ptjhoras := 0;
            v_msg := SQLERRM;
            sp_salvame(p_run,'Error en '|| $$PLSQL_UNIT||' al obtener puntaje con horas de trabajo semanal: '||p_horas, v_msg);
    END;
    RETURN v_ptjhoras;
END fn_ptjhoras;
/

--FUNCION PARA OBTENER EL SERVICIO DE SALUD
CREATE OR REPLACE FUNCTION fn_zona (
    p_run NUMBER
)RETURN NUMBER
AS
    v_servicio NUMBER;
    v_sql VARCHAR2(300);
    v_zona NUMBER;
BEGIN
    v_sql := 'SELECT MIN(cod_serv_salud)
              FROM antecedentes_laborales
              WHERE numrun = :1';
    EXECUTE IMMEDIATE v_sql INTO v_servicio USING p_run;
    
    SELECT NVL(zona_extrema,0)
    INTO v_zona
    FROM servicio_salud
    WHERE cod_serv_salud = v_servicio;
    
    RETURN v_zona;
END fn_zona;
/

--FUNCION PARA OBTENER EL RANKING DE LA INSTITUCION
CREATE OR REPLACE FUNCTION fn_rank (
    p_run NUMBER
) RETURN NUMBER
AS
    v_rank NUMBER;
    v_sql VARCHAR2(300);
BEGIN
    v_sql := 'SELECT i.ranking
              FROM institucion i
              JOIN programa_especializacion pe
              ON i.cod_inst = pe.cod_inst
              JOIN postulacion_programa_espec ppe
              ON pe.cod_programa = ppe.cod_programa
              WHERE ppe.numrun = :1';
    EXECUTE IMMEDIATE v_sql INTO v_rank USING p_run;
    RETURN v_rank;
END fn_rank;
/


--PAQUETE (FUNCION PUNTAJE ZONA EXTREMA, FUNCION PUNTAJE RANKING INSTITUCION)
--ENCABEZADO DEL PACKAGE
CREATE OR REPLACE PACKAGE pkg_post AS
    vp_ptjrank NUMBER;
    vp_ptjzona NUMBER;
    FUNCTION fn_ptjzona (p_zona NUMBER) RETURN NUMBER;
    FUNCTION fn_ptjrank (p_rank NUMBER) RETURN NUMBER;
END pkg_post;
/

--CUERPO DEL PACKAGE
CREATE OR REPLACE PACKAGE BODY pkg_post AS
    
    FUNCTION fn_ptjzona(
        p_zona NUMBER
    ) RETURN NUMBER
    AS
        v_ptjzona NUMBER;
        v_sql VARCHAR2(300);
    BEGIN
        BEGIN
            v_sql := 'SELECT ptje_zona
                      FROM ptje_zona_extrema
                      WHERE zona_extrema = :1';
            EXECUTE IMMEDIATE v_sql INTO v_ptjzona USING p_zona;
        EXCEPTION
            WHEN OTHERS THEN
                v_ptjzona := 0;
        END;
    RETURN v_ptjzona;
    END fn_ptjzona;
    
    
    FUNCTION fn_ptjrank(
        p_rank NUMBER
    ) RETURN NUMBER
    AS
        v_ptjrank NUMBER;
        v_sql VARCHAR2(300);
    BEGIN
        v_sql := 'SELECT ptje_ranking
                  FROM ptje_ranking_inst
                  WHERE :1 BETWEEN rango_ranking_ini AND rango_ranking_ter';
        EXECUTE IMMEDIATE v_sql INTO v_ptjrank USING p_rank;
    RETURN v_ptjrank;
    END fn_ptjrank;
    
END pkg_post;
/

--PROCEDIMIENTO PRINCIPAL
CREATE OR REPLACE PROCEDURE sp_postulacion (
    p_fecha DATE, p_ptjextra1 NUMBER, p_ptjextra2 NUMBER
)
AS
    --CURSOR QUE RECUPERA LOS DATOS
    CURSOR c_post IS
    SELECT ap.numrun, ap.dvrun, ap.pnombre||' '||ap.snombre||' '||ap.apaterno||' '||ap.amaterno nombre, 
            ap.fecha_nacimiento
    FROM antecedentes_personales ap
    ORDER BY ap.numrun;
    
    --DECLARACION DE VARIABLES
    v_edad NUMBER;
    v_sumptj NUMBER;
    v_ptjextra1 NUMBER;
    v_ptjextra2 NUMBER;
    v_ptjexp NUMBER;
    v_ptjhoras NUMBER;
    v_ptjrank NUMBER;
    v_ptjzona NUMBER;
BEGIN
    --TRUNCAMOS LAS TABLAS
    EXECUTE IMMEDIATE 'TRUNCATE TABLE error_proceso';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_puntaje_postulacion';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE resultado_postulacion';
    
    FOR r_post IN c_post LOOP
        
        --CALCULAMOS LA EDAD
        v_edad := ROUND((p_fecha - r_post.fecha_nacimiento)/365);
        
        v_ptjexp := fn_ptjexp(fn_annos(r_post.numrun, p_fecha), r_post.numrun);
        
        v_ptjhoras := fn_ptjhoras(fn_horas(r_post.numrun), r_post.numrun);
        
        v_ptjrank := pkg_post.fn_ptjrank(fn_rank(r_post.numrun));
        
        v_ptjzona := pkg_post.fn_ptjzona(fn_zona(r_post.numrun));
        
        --SUMAMOS LOS PUNTAJES PARA CALCULAR EXTRAS
        v_sumptj := v_ptjexp + v_ptjhoras + v_ptjrank + v_ptjzona;
        
        --CALCULAMOS EL PRIMER EXTRA
        v_ptjextra1 := CASE
                        WHEN v_edad < 45 AND fn_horas(r_post.numrun) > 30 THEN v_sumptj * (p_ptjextra1/100)
                        ELSE 0
                    END;
                    
        v_ptjextra2 := CASE
                        WHEN fn_annos(r_post.numrun, p_fecha) > 25 THEN v_sumptj * (p_ptjextra2/100)
                        ELSE 0
                   END; 
    
        dbms_output.put_line(r_post.numrun||'-'||r_post.dvrun
        ||' '||r_post.nombre
        ||' '||v_ptjexp
        ||' '||v_ptjhoras
        ||' '||v_ptjzona
        ||' '||v_ptjrank
        ||' '||v_ptjextra1
        ||' '||v_ptjextra2);
        
        --INSERTAMOS LOS DATOS
        EXECUTE IMMEDIATE 'INSERT INTO detalle_puntaje_postulacion
                            VALUES(:1, :2, :3, :4, :5, :6, :7, :8)'
        USING r_post.numrun||'-'||r_post.dvrun, r_post.nombre, v_ptjexp, v_ptjhoras
        , v_ptjzona, v_ptjrank, v_ptjextra1, v_ptjextra2;
    END LOOP;
END;
/

BEGIN
    sp_postulacion(TO_DATE('30/06/2023', 'DD/MM/YYYY'), 30, 15);
END;
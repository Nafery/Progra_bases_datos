/*CREATE OR REPLACE PROCEDURE sp_salva_errores (
    p_datos errores%ROWTYPE
) AS
BEGIN
    INSERT INTO errores
    VALUES 
END sp_salva_errores;
*/

-- CREAMOS LA FUNCIÓN PARA EL CÁLCULO DE LA COMISIÓN
CREATE OR REPLACE FUNCTION fn_getcomision (
    p_numproyectos NUMBER, p_sueldo NUMBER
) RETURN NUMBER
AS
    v_comision NUMBER;
    TYPE t_arr IS VARRAY(4) OF NUMBER;
    v_arr t_arr := t_arr(0.3, 0.2, 0.1, 0.05);
BEGIN
    --CALCULO DE LA COMISION
    v_comision := p_sueldo *
        ROUND(CASE
            WHEN p_numproyectos > 8 THEN v_arr(1)
            WHEN p_numproyectos > 6 THEN v_arr(2)
            WHEN p_numproyectos > 3 THEN v_arr(3)
            WHEN p_numproyectos >= 1 THEN v_arr(4)
            ELSE 0
        END);
    RETURN v_comision;
END fn_getcomision;
/

-- CREAMOS LA FUNCIÓN PARA EL CÁLCULO DE LA ANTIGÜEDAD
CREATE OR REPLACE FUNCTION fn_getanti (
        p_fecha DATE
    ) RETURN NUMBER
    AS
    BEGIN
        RETURN ROUND(MONTHS_BETWEEN(SYSDATE, p_fecha) / 12);
END fn_getanti;
/

--EL PACKAGE SE CREA ANTES DEL PROCEDIMIENTO PORQUE CON EL PROCEDIMIENTO LLAMAREMOS AL PACKAGE
--ENCABEZADO DEL PACKAGE
CREATE OR REPLACE PACKAGE pkg_asigna AS
    --CONSTRUCTORES PUBLICOS DEL PKG
    vp_edad NUMBER;
    vp_pct NUMBER;
    FUNCTION fn_getedad (p_fecha DATE) RETURN NUMBER;
    --FUNCTION fn_lista (p_puntaje NUMBER) RETURN NUMBER;
END pkg_asigna;
/

--BODY DEL PACKAGE
CREATE OR REPLACE PACKAGE BODY pkg_asigna AS

    FUNCTION fn_getedad (
        p_fecha DATE
    ) RETURN NUMBER
    AS
    BEGIN
        RETURN ROUND(MONTHS_BETWEEN(SYSDATE, p_fecha) / 12);
    END fn_getedad;
    
    /*FUNCTION fn_lista (
        p_puntaje NUMBER
    ) RETURN NUMBER
    AS
        v_pct NUMBER;
    BEGIN
        SELECT pct
        INTO v_pct
        FROM lista
        WHERE p_puntaje BETWEEN punt_min AND punt_max;
        RETURN v_pct;
    END fn_lista;*/
END pkg_asigna;
/

CREATE OR REPLACE PROCEDURE sp_asigna (
    p_fecha DATE -- TAMBIÉN LO PODEMOS COLOCAR COMO p_fecha IN DATE PARA DECLARARLO COMO PARAMETRO DE ENTRADA, PERO NO ES NECESARIO
                    -- YA QUE POR DEFECTO ESTÁN DEFINIDOS COMO PARAMETROS DE ENTRADA
)
AS
    -- CURSOR PARA RECUPERAR DATOS DE LAS EMPRESAS
    CURSOR c_empre IS
    SELECT *
    FROM empresa;
    
    -- CURSOR PARA RECUPERAR DATOS DE LOS EMPLEADOS
    CURSOR c_emple (p_empresa NUMBER) IS
    SELECT rut||'-'||dv run_empleado, nombres||' '||apellidos empleado,
            sueldo, fecnac, fecingreso, numproyectos
    FROM empleado
    WHERE rutempresa = p_empresa;
    
    -- VARIABLES ESCALARES
    v_bono_antig NUMBER;
    v_asiedad NUMBER;
    v_asicat NUMBER;
BEGIN
    -- ITERAMOS SOBRE EL CURSOR DE EMPRES
    FOR r_empre IN c_empre LOOP
        
        FOR r_emple IN c_emple (r_empre.rut) LOOP
        
            -- ITERAMOS SOBRE EL CURSOR DE EMPLEADO
            
            -- CALCULAMOS EL BONO POR ANTIGÜEDAD
            IF fn_getanti(r_emple.fecingreso) > 15 THEN
                v_bono_antig := ROUND(r_emple.sueldo * 0.3);
            ELSE
                v_bono_antig := ROUND(r_emple.sueldo * 0.15);
            END IF;
            
            -- CALCULO DE LA ASIG POR EDAD
            IF pkg_asigna.fn_getedad(r_emple.fecnac) >= 65 THEN
                v_asiedad := ROUND(r_emple.sueldo * 0.08);
            ELSIF pkg_asigna.fn_getedad(r_emple.fecnac) >= 55 THEN
                v_asiedad := ROUND(r_emple.sueldo * 0.05);
            ELSIF pkg_asigna.fn_getedad(r_emple.fecnac) >= 50 THEN
                v_asiedad := ROUND(r_emple.sueldo * 0.03);
            ELSE
                v_asiedad := 0;
            END IF;
            
            -- CALCULO DE LA ASIGNACIÓN POR CATEGORÍA
            --v_asicat := ROUND(r_emple.sueldo * pkg_asigna.fn_lista(r_emple.puntaje));
        
            dbms_output.put_line(TO_CHAR(p_fecha, 'MMYYYY')
            ||' '||r_emple.run_empleado
            ||' '||r_emple.empleado
            ||' '||r_empre.razonsocial
            ||' '||r_emple.sueldo
            ||' '||pkg_asigna.fn_getedad(r_emple.fecnac)
            ||' '||fn_getanti(r_emple.fecingreso)
            ||' '||v_bono_antig
            ||' '||fn_getcomision(r_emple.numproyectos, r_emple.sueldo)
            ||' '||v_asiedad
            );
        END LOOP;
        
    END LOOP;
END sp_asigna;
/

BEGIN
    sp_asigna(SYSDATE);
END;
/
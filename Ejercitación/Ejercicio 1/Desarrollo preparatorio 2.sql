CREATE OR REPLACE TRIGGER calcular_calificacion_empleado
BEFORE INSERT ON detalle_haberes_mensual
FOR EACH ROW
DECLARE
  v_total_haberes NUMBER;
  v_calificacion VARCHAR2(400);
BEGIN
  -- Calcular el total de haberes (reglas a-e)
  v_total_haberes := :NEW.sueldo_base + :NEW.asig_colacion + :NEW.asig_movilizacion + :NEW.asig_especial_ant + :NEW.asig_escolaridad;

  -- Determinar la calificación (regla f)
  IF v_total_haberes BETWEEN 400000 AND 700000 THEN
    v_calificacion := 'Empleado con Salario Bajo Promedio';
  ELSIF v_total_haberes BETWEEN 700001 AND 900000 THEN
    v_calificacion := 'Empleado con Salario Promedio';
  ELSE
    v_calificacion := 'Empleado con Salario Sobre el Promedio';
  END IF;

  -- Insertar en la tabla calificacion_mensual_empleado
  INSERT INTO calificacion_mensual_empleado (mes, anno, run_empleado, total_haberes, calificacion)
  VALUES (:NEW.mes, :NEW.anno, :NEW.run_empleado, v_total_haberes, v_calificacion);
END;
/

--CREACIÓN DEL PACKAGE 
CREATE OR REPLACE PACKAGE pkg_empleado AS
    vp_ventas NUMBER;
    FUNCTION fn_ventas (p_runempleado VARCHAR2, p_fecha VARCHAR2) RETURN NUMBER;
    PROCEDURE salva_errores(p_iderror NUMBER, p_subp VARCHAR2, p_msg VARCHAR2);
END pkg_empleado;
/

CREATE OR REPLACE PACKAGE BODY pkg_empleado AS
    
    --FUNCIÓN PARA CALCULAR EL TOTAL DE VENTAS POR EMPLEADO
    FUNCTION fn_ventas (
        p_runempleado VARCHAR2, p_fecha VARCHAR2
    ) RETURN NUMBER
    AS
        v_totalventas NUMBER;
    BEGIN
        SELECT NVL(SUM(monto_total_boleta), 0)
        INTO v_totalventas
        FROM boleta
        WHERE run_empleado = p_runempleado
        AND TO_CHAR(fecha, 'MMYYYY') = p_fecha;
        RETURN v_totalventas;
    END fn_ventas;
    
    --PROCEDIMIENTO PARA INSERTAR ERRORES AL OBTENER PORCENTAJES
    --PARA ASIG POR ANTIGÜEDAD Y ESCOLARIDAD
    
    PROCEDURE salva_errores (
        p_iderror NUMBER, p_subp VARCHAR2, p_msg VARCHAR2
    )
    AS
        v_sql VARCHAR2(300);
    BEGIN
        v_sql := 'INSERT INTO error_calc
                  VALUES (:1, :2, :3) ';
        EXECUTE IMMEDIATE v_sql USING p_iderror, p_subp, p_msg;
    END salva_errores;
        
    
    
    
END pkg_empleado;
/

--FUNCIÓN ALMACENADA QUE RETORNA EL PORCENTAJE POR ANTIGÜEDAD
CREATE OR REPLACE FUNCTION fn_pctantig (
    p_antiguedad NUMBER
) RETURN NUMBER
AS
    v_pctantig NUMBER;
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'SELECT porc_antiguedad / 100
                           FROM porcentaje_antiguedad
                           WHERE :1 BETWEEN annos_antiguedad_inf 
                           AND annos_antiguedad_sup'
        INTO v_pctantig USING p_antiguedad;
    EXCEPTION
        WHEN OTHERS THEN
            v_pctantig := 0;
            v_msg := SQLERRM;
            pkg_empleado.salva_errores(SEQ_ERROR.NEXTVAL,
                'Error en la funcion '||$$PLSQL_UNIT||' al obtener el porcentaje asociado a '
                ||p_antiguedad||' años de antiguedad', v_msg);
    END;
    RETURN v_pctantig;
END fn_pctantig;
/

--FUNCION ALMACENADA QUE RETORNA EL PORCENTAJE POR ESCOLARIDAD
CREATE OR REPLACE FUNCTION fn_pctesco (
    p_codesco VARCHAR2
) RETURN NUMBER
AS
    v_pctesco NUMBER;
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'SELECT porc_escolaridad / 100
                           FROM porcentaje_escolaridad
                           WHERE cod_escolaridad = :1'
        INTO v_pctesco USING p_codesco;
    EXCEPTION
        WHEN OTHERS THEN
            v_pctesco := 0;
            v_msg := SQLERRM;
            pkg_empleado.salva_errores(SEQ_ERROR.NEXTVAL,
                'Error en la funcion '||$$PLSQL_UNIT||
                ' al obtener el porcentaje asociado al código escolaridad '
                ||p_codesco, v_msg);
    END;
    RETURN v_pctesco;
END fn_pctesco;
/

CREATE OR REPLACE PROCEDURE sp_haberes (
    p_fecha VARCHAR2, p_mov NUMBER, p_cola NUMBER
) 
AS
    --CURSOR PARA OBTENER LOS DATOS DEL EMPLEADO
    CURSOR c_empleado IS
    SELECT DISTINCT e.run_empleado run, TO_CHAR(b.fecha, 'MMYYYY') fecha, e.nombre||' '||e.paterno||' '||e.materno nombre,
            e.sueldo_base, e.fecha_contrato,
            e.cod_escolaridad
    FROM empleado e JOIN boleta b
    ON e.run_empleado = b.run_empleado
    WHERE TO_CHAR(b.fecha, 'MMYYYY') = p_fecha
    ORDER BY 3;
    
    --DECLARACION DE VARIABLES
    v_asig_ant NUMBER;
    v_antig NUMBER;
    v_asig_esc NUMBER;
    v_pctcom NUMBER;
    v_comision NUMBER;
    v_haberes NUMBER;
BEGIN

    --TRUNCAMOS LAS TABLAS
    EXECUTE IMMEDIATE 'TRUNCATE TABLE calificacion_mensual_empleado';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_haberes_mensual';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE error_calc';
    FOR r_empleado IN c_empleado LOOP
        
        --CALCULAMOS LA ANTIGÜEDAD
        v_antig := ROUND(MONTHS_BETWEEN(SYSDATE, r_empleado.fecha_contrato) / 12);
        --CALCULAMOS LA ASIGNACIÓN POR ANTIGÜEDAD
        v_asig_ant := ROUND(pkg_empleado.fn_ventas(r_empleado.run, p_fecha) * fn_pctantig(v_antig));
        --CALCULAMOS LA ASIGNACION POR ESCOLARIDAD
        v_asig_esc := r_empleado.sueldo_base * fn_pctesco(r_empleado.cod_escolaridad);
        
        SELECT porc_comision / 100
        INTO v_pctcom
        FROM porcentaje_comision_venta
        WHERE pkg_empleado.fn_ventas(r_empleado.run, p_fecha) BETWEEN venta_inf AND venta_sup;
        
        v_comision := ROUND(v_pctcom * pkg_empleado.fn_ventas(r_empleado.run, p_fecha));
        
        v_haberes := r_empleado.sueldo_base + p_cola + p_mov + v_asig_ant + v_asig_esc + v_comision;
        
        --INSERTAMOS LOS DATOS EN LA TABLA DETALLE_HABERES_MENSUAL
        EXECUTE IMMEDIATE 'INSERT INTO detalle_haberes_mensual
                           VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11)'
        USING SUBSTR(p_fecha,1,2), SUBSTR(p_fecha,3,4), r_empleado.run, r_empleado.nombre, r_empleado.sueldo_base, p_cola, p_mov, v_asig_ant, v_asig_esc, v_comision, v_haberes;
        
        dbms_output.put_line(SUBSTR(r_empleado.fecha,1,2)
        ||' '||SUBSTR(r_empleado.fecha,3,4)
        ||' '||r_empleado.run
        ||' '||r_empleado.nombre
        ||' '||r_empleado.sueldo_base
        ||' '||p_cola
        ||' '||p_mov
        ||' '||v_asig_ant
        ||' '||v_asig_esc
        ||' '||v_comision
        );
        
    END LOOP;
END sp_haberes;
/
BEGIN
    sp_haberes('062022', 60000, 75000);
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_error';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_error';
END;
/
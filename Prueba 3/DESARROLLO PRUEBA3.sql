CREATE OR REPLACE PACKAGE pkg_asignaciones AS
    vp_asignacion NUMBER;
    PROCEDURE sp_salvaerrores (p_subp VARCHAR2, p_msg VARCHAR2);
    FUNCTION fn_asignacion (p_total NUMBER) RETURN NUMBER;
END pkg_asignaciones;
/

CREATE OR REPLACE PACKAGE BODY pkg_asignaciones AS
    
    --PROCEDIMIENTO ERRORES
    PROCEDURE sp_salvaerrores (
        p_subp VARCHAR2, p_msg VARCHAR2
    )
    AS
        v_sql VARCHAR2(300);
    BEGIN
        v_sql := 'INSERT INTO errores
                  VALUES (:1, :2, :3)';
        EXECUTE IMMEDIATE v_sql USING secuencia_error.NEXTVAL, p_subp, p_msg;
    END sp_salvaerrores;
    
    --FUNCION QUE RETORNA PCT ASIGNACION
    FUNCTION fn_asignacion (
        p_total NUMBER
    ) RETURN NUMBER
    AS
        v_pctasignacion NUMBER;
        v_asignacion NUMBER;
    BEGIN
        SELECT pct_asignacion
        INTO v_pctasignacion
        FROM pct_asignacion_ventas
        WHERE p_total BETWEEN monto_inf AND monto_sup;
        
        v_asignacion := ROUND(p_total * v_pctasignacion);
        RETURN v_asignacion;
    END fn_asignacion;
    
END pkg_asignaciones;
/

--FUNCIÓN PARA RECUPERAR CATEGORIA
CREATE OR REPLACE FUNCTION fn_categoria (
    p_idcat NUMBER
) RETURN VARCHAR2
AS
    v_sql VARCHAR2(300);
    v_categoria VARCHAR2(30);
BEGIN
    BEGIN
        v_sql := 'SELECT nom_categ
                  FROM categoria  
                  WHERE id_categ = :1';
        EXECUTE IMMEDIATE v_sql INTO v_categoria USING p_idcat;
    EXCEPTION
        WHEN OTHERS THEN
            v_categoria := 'Categoria no asignada';
    END;
    RETURN v_categoria;
END fn_categoria;
/

--FUNCION DE PCT POR CATEGORIA
CREATE OR REPLACE FUNCTION fn_pctcat (
    p_idcat NUMBER, p_run VARCHAR2
) RETURN NUMBER
AS
    v_sql VARCHAR2(300);
    v_pctcat NUMBER;
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        v_sql := 'SELECT comis_categ
                  FROM categoria
                  WHERE id_categ = :1';
        EXECUTE IMMEDIATE v_sql INTO v_pctcat USING p_idcat;
    EXCEPTION
        WHEN OTHERS THEN
            v_pctcat := .05;
            v_msg := SQLERRM;
            pkg_asignaciones.sp_salvaerrores('Error en la funcion '||$$PLSQL_UNIT||
            ' al recuperar el % correspondiente a la categoria del empleado run Nro. '||p_run,
            v_msg);
    END;
    RETURN v_pctcat;
END fn_pctcat;
/
--FUNCION PARA OBTENER LA DIRECCION DE LA SUCURSAL
CREATE OR REPLACE FUNCTION fn_sucursal (
    p_idsucursal NUMBER, p_idpedido NUMBER
)RETURN VARCHAR2
AS 
    v_sql VARCHAR2(300);
    v_direccion VARCHAR2(50);
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        v_sql := 'SELECT dir_suc
                  FROM sucursal
                  WHERE id_suc = :1';
        EXECUTE IMMEDIATE v_sql INTO v_direccion USING p_idsucursal;
    EXCEPTION
        WHEN OTHERS THEN
            v_direccion := 'Sucursal desconocida';
            v_msg := SQLERRM;
            pkg_asignaciones.sp_salvaerrores('Error en la funcion '||$$PLSQL_UNIT||
            ' al recuperar la sucursal en que se atendió el pedido '||p_idpedido,
            v_msg);
    END;
    RETURN v_direccion;
END fn_sucursal;
/

--PROCEDIMIENTO PRINCIPAL
CREATE OR REPLACE PROCEDURE sp_asignaciones (
    p_fecha VARCHAR2
)
AS

    --CURSOR QUE RECUPERA EMPLEADOS
    CURSOR c_emp IS
    SELECT p.id_pedido, e.numempleado, e.runempleado, e.nombreemp, 
            e.id_categ, p.fec_pedido, p.total, e.id_suc
    FROM empleado e JOIN pedido p
    ON e.numempleado = p.numempleado
    JOIN categoria c
    ON e.id_categ = c.id_categ
    WHERE TO_CHAR(p.fec_pedido, 'MMYYYY') = p_fecha
    ORDER BY 1;
    
    --DECLARACION DE VARIABLES
    v_asignacion NUMBER;
    v_asigcateg NUMBER;
    v_totalasig NUMBER;
BEGIN
    
    EXECUTE IMMEDIATE 'TRUNCATE TABLE errores';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalleasignaciones_mes';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE asignaciones_mes_proceso';
    
    FOR r_emp IN c_emp LOOP
    
    --CALCULO DE ASIGNACION POR STATUS
    v_asigcateg := ROUND(fn_pctcat(r_emp.id_categ, r_emp.runempleado) * r_emp.total);
    
    --CALCULO DEL TOTAL DE LAS ASIGNACIONES
    v_totalasig := v_asigcateg + pkg_asignaciones.fn_asignacion(r_emp.total);
    
    --GUARDAMOS LOS DATOS EN LA TABLA
    EXECUTE IMMEDIATE 'INSERT INTO detalleasignaciones_mes
                       VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11)' 
    USING SUBSTR(p_fecha,1,2)
        , SUBSTR(p_fecha,3,4)
        , r_emp.id_pedido
        , r_emp.fec_pedido
        , r_emp.runempleado
        , r_emp.nombreemp
        , fn_categoria(r_emp.id_categ)
        , fn_sucursal(r_emp.id_suc, r_emp.id_pedido)
        , pkg_asignaciones.fn_asignacion(r_emp.total)
        , v_asigcateg
        , v_totalasig;
        
        
        dbms_output.put_line(SUBSTR(p_fecha,1,2)
        ||' '||SUBSTR(p_fecha,3,4)
        ||' '||r_emp.id_pedido
        ||' '||r_emp.fec_pedido
        ||' '||r_emp.runempleado
        ||' '||r_emp.nombreemp
        ||' '||fn_categoria(r_emp.id_categ)
        ||' '||fn_sucursal(r_emp.id_suc, r_emp.id_pedido)
        ||' '||pkg_asignaciones.fn_asignacion(r_emp.total)
        ||' '||v_asigcateg
        ||' '||v_totalasig);
    END LOOP;
END sp_asignaciones;
/
BEGIN
    sp_asignaciones('092023');
    EXECUTE IMMEDIATE 'DROP SEQUENCE secuencia_error';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE secuencia_error';
END;
/
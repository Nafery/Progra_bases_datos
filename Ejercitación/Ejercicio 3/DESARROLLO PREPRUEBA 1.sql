--PROCEDIMIENTO DE ERROR
CREATE OR REPLACE PROCEDURE sp_salvame (
    p_errorid NUMBER, p_subp VARCHAR2, p_msg VARCHAR2
)
AS
    v_sql VARCHAR2(300);
BEGIN
    v_sql := 'INSERT INTO reg_errores
              VALUES (:1, :2, :3)';
    EXECUTE IMMEDIATE v_sql USING p_errorid, p_subp, p_msg;
END sp_salvame;
/

--FUNCIÓN ALMACENADA PARA AGENCIA USANDO EXECUTE IMMEDIATE
--TAMBIÉN AGREGAR EL CONTROLADOR DE ERRORES Y AGREGAR A TABLA
--REG_ERRORES, DEVOLVIENDO MENSAJE "NO REGISTRA AGENCIA"
CREATE OR REPLACE FUNCTION fn_agencia (
    p_agenciaid NUMBER
) RETURN VARCHAR2
AS
    v_sql VARCHAR2(300);
    v_agencia VARCHAR2(50);
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        v_sql := 'SELECT nom_agencia
                  FROM agencia
                  WHERE id_agencia = :1';
        EXECUTE IMMEDIATE v_sql INTO v_agencia USING p_agenciaid;
    EXCEPTION
        WHEN OTHERS THEN
            v_agencia := 'NO REGISTRA AGENCIA';
            v_msg := SQLERRM;
            sp_salvame(sq_error.NEXTVAL, $$PLSQL_UNIT, v_msg);
    END;
    RETURN v_agencia;
END fn_agencia;
/

--CUERPO DEL PACKAGE
CREATE OR REPLACE PACKAGE pkg_montos AS
    
END pkg_montos;
/

CREATE OR REPLACE PACKAGE BODY pkg_montos AS
    FUNCTION fn_mtotour (
        
END pkg_montos;
/

--FUNCIÓN ALMACENADA PARA DETERMINAR EL MONTO EN DÓLARES DE LOS CONSUMOS HUESPED
--LA CONSULTA SE EFECTUA SOBRE TOTAL_CONSUMOS. SI NO REGISTRA CONSUMOS DEVOLVER 0
--USAR EXECUTE IMMEDIATE.

--PROCEDIMIENTO ALMACENADO PARA EL CÁLCULO DE LOS PAGOS.
--PROCESAR HUESPEDES CUYA SALIDA ES EL MES 08/2023
--CAMBIO DE DOLAR DE $840, ESTOS VALORES DEBEN SER INGRESADOS COMO PARÁMETROS

CREATE OR REPLACE PROCEDURE sp_procesa_huespedes (
    p_fecha VARCHAR2
)
AS
    CURSOR c_det IS
    SELECT h.id_huesped, h.nom_huesped||' '||h.appat_huesped||' '||h.apmat_huesped nombre, 
            h.id_agencia, r.ingreso
    FROM huesped h JOIN reserva r
    ON h.id_huesped = r.id_huesped
    WHERE TO_CHAR(r.ingreso, 'MMYYYY') = p_fecha;
    
BEGIN
    
    FOR r_det IN c_det LOOP
        dbms_output.put_line(r_det.id_huesped
        ||' '||r_det.nombre
        ||' '||fn_agencia(r_det.id_agencia)
        );
    END LOOP;
    
END sp_procesa_huespedes;
/
BEGIN
    sp_procesa_huespedes ('082023');
END;
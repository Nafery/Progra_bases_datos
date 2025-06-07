VAR b_com NUMBER;
EXEC :b_com := 70000;
DECLARE
    --CREAMOS EL CURSOR PARA LA TABLA RESUMEN RECAUDACION
    CURSOR c_res IS
    SELECT TO_CHAR(f.fecha, 'MMYYYY') fecha, p.codunidad, um.descripcion
    FROM factura f JOIN detalle_factura df 
    ON f.numfactura = df.numfactura
    JOIN producto p
    ON df.codproducto = p.codproducto
    JOIN unidad_medida um
    ON p.codunidad = um.codunidad
    WHERE TO_CHAR(f.fecha, 'YYYY') = TO_CHAR(SYSDATE, 'YYYY') - 1 AND um.descripcion IN ('CENTIMETRO', 'METRO')
    GROUP BY TO_CHAR(f.fecha, 'MMYYYY'), um.descripcion, p.codunidad
    ORDER BY TO_CHAR(f.fecha, 'MMYYYY'), um.descripcion;
    
    --CREAMOS EL CURSOR PARA LA TABLA DETALLE_RECAUDACION
    CURSOR c_det(p_fec VARCHAR2, p_cod VARCHAR2) IS
    SELECT f.numfactura, f.fecha, v.nombre||' '||v.paterno||' '||v.materno nombre, df.codproducto,  SUM(df.totallinea) totallinea,
            v.status_vendedor
    FROM vendedor v JOIN factura f
    ON f.run_vendedor = v.run_vendedor
    JOIN detalle_factura df
    ON f.numfactura = df.numfactura
    JOIN producto p 
    ON df.codproducto = p.codproducto 
    WHERE TO_CHAR(f.fecha, 'MMYYYY') = p_fec 
            AND p.codunidad = p_cod
    group by f.numfactura, f.fecha, v.nombre||' '||v.paterno||' '||v.materno, df.codproducto, 
    v.status_vendedor
    ORDER BY f.numfactura, f.fecha, df.codproducto;
            
    --DECLARACION DE VARIABLES
    v_pct NUMBER;
    v_comision_status NUMBER;
    v_limcomision EXCEPTION;
    v_code NUMBER;
    v_msg VARCHAR2(400);
    v_pct_sindicato NUMBER;
    
BEGIN

    --TRUNCAMOS TABLAS
    EXECUTE IMMEDIATE 'TRUNCATE TABLE error_calc';
    
    --ITERAMOS SOBRE EL PRIMER CURSOR
    FOR r_res IN c_res LOOP
        --ITERAMOS SOBRE EL SEGUNDO CURSOR
        FOR r_det IN c_det (r_res.fecha, r_res.codunidad) LOOP
        
            SELECT pct / 100
            INTO v_pct
            FROM status_vendedor
            WHERE id_status = r_det.status_vendedor;
            
        --CALCULAMOS LA COMISION POR STATUS
        v_comision_status := ROUND(r_det.totallinea * v_pct);
        
        BEGIN
        IF v_comision_status > 70000 THEN
            RAISE v_limcomision;
        END IF;
        EXCEPTION
            WHEN v_limcomision THEN
                v_code := -20001;
                v_msg := 'SE SUPERO EL LIMITE DE COMISION EN LA FACTURA: ';
                v_comision_status := 70000;
                INSERT INTO error_calc
                VALUES(seq_error.NEXTVAL, v_code, v_msg||' '||r_det.numfactura, 
                'SE ASIGNA EL LIMITE DE COMISION DE $70000');
        END;
        
        --CALCULAMOS COMISION DEL SINDICATO POR VENTAS
        BEGIN
            SELECT pct / 100
            INTO v_pct_sindicato
            FROM porc_ventas_vendedor
            WHERE r_det.totallinea BETWEEN monto_vta_inf AND mto_vta_sup;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_code := SQLCODE;
                v_msg := SQLERRM;
                v_pct_sindicato := 0;
                INSERT INTO error_calc
                VALUES (seq_error.NEXTVAL, v_code, v_msg,
                'NO SE ENCONTRO % PARA EL MONTO '||r_det.totallinea);
        END;
        
        
            
        dbms_output.put_line(r_det.numfactura||' '||r_det.fecha||' '||r_det.nombre||' '||r_det.codproducto||' '||r_res.descripcion||' '||r_res.codunidad||' '||r_det.totallinea);    
        END LOOP;
    END LOOP;
END;
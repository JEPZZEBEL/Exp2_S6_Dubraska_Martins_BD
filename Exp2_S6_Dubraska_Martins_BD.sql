-- DESAFIO 1

-- Crear la tabla RECAUDACION_BONOS_MEDICOS para almacenar los datos procesados
CREATE TABLE RECAUDACION_BONOS_MEDICOS (
    RUT_MEDICO VARCHAR2(12) NOT NULL, -- RUT completo con dígito verificador
    NOMBRE_MEDICO VARCHAR2(50) NOT NULL, -- Nombre completo del médico
    TOTAL_RECAUDADO NUMBER(10, 2) NOT NULL, -- Total recaudado por bonos
    UNIDAD_MEDICA VARCHAR2(40) NOT NULL -- Unidad médica donde trabaja el médico
);

-- Insertar datos en la tabla RECAUDACION_BONOS_MEDICOS
INSERT INTO RECAUDACION_BONOS_MEDICOS (RUT_MEDICO, NOMBRE_MEDICO, TOTAL_RECAUDADO, UNIDAD_MEDICA)
SELECT 
    m.rut_med || '-' || m.dv_run AS RUT_MEDICO, -- Concatenar el RUT con el dígito verificador
    m.pnombre || ' ' || m.apaterno || ' ' || m.amaterno AS NOMBRE_MEDICO, -- Nombre completo del médico
    SUM(bc.costo) AS TOTAL_RECAUDADO, -- Sumar los costos de los bonos
    uc.nombre AS UNIDAD_MEDICA -- Unidad médica donde trabaja el médico
FROM 
    BONO_CONSULTA bc
JOIN MEDICO m ON bc.rut_med = m.rut_med -- Relación con la tabla de médicos
JOIN UNIDAD_CONSULTA uc ON m.uni_id = uc.uni_id -- Relación con la unidad médica
WHERE 
    EXTRACT(YEAR FROM bc.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) - 1 -- Bonos del año anterior
    AND m.car_id NOT IN (100, 500, 600) -- Excluir médicos con ciertos cargos
GROUP BY 
    m.rut_med, m.dv_run, m.pnombre, m.apaterno, m.amaterno, uc.nombre -- Agrupar por médico y unidad médica
ORDER BY 
    TOTAL_RECAUDADO ASC;
-- Consulta del primer caso
SELECT 
    m.rut_med || '-' || m.dv_run AS RUT_MEDICO,
    m.pnombre || ' ' || m.apaterno || ' ' || m.amaterno AS NOMBRE_MEDICO,
    SUM(bc.costo) AS TOTAL_RECAUDADO
FROM 
    BONO_CONSULTA bc
JOIN MEDICO m ON bc.rut_med = m.rut_med -- Relación con médicos
WHERE 
    EXTRACT(YEAR FROM bc.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) - 1 -- Bonos del año anterior
    AND m.car_id NOT IN (100, 500, 600) -- Excluir ciertos cargos
GROUP BY 
    m.rut_med, m.dv_run, m.pnombre, m.apaterno, m.amaterno -- Agrupación
HAVING 
    SUM(bc.costo) > (
        SELECT AVG(costo_promedio)
        FROM (
            SELECT SUM(bc2.costo) AS costo_promedio
            FROM BONO_CONSULTA bc2
            WHERE EXTRACT(YEAR FROM bc2.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) - 1
            GROUP BY bc2.rut_med
        )
    )
ORDER BY TOTAL_RECAUDADO DESC;
   

-- DESAFIO 2

-- Generar un reporte de especialidades médicas con bonos incobrables y pérdidas
SELECT 
    em.nombre AS Especialidad_Medica, -- Nombre de la especialidad médica
    COUNT(bc.id_bono) AS Cantidad_Bonos, -- Contar la cantidad de bonos por especialidad
    SUM(CASE 
            WHEN pg.fecha_pago IS NULL THEN bc.costo -- Si no hay pago, es incobrable
            ELSE 0
        END) AS Monto_Perdida, -- Calcular el monto perdido por bonos incobrables
    MIN(bc.fecha_bono) AS Fecha_Bono, -- Fecha del bono más antiguo
    CASE 
        WHEN pg.fecha_pago IS NULL THEN 'INCOBRABLE' -- Si no está pagado
        ELSE 'COBRABLE' -- Si está pagado
    END AS Estado_De_Cobro -- Estado de cobro
FROM 
    BONO_CONSULTA bc
JOIN DET_ESPECIALIDAD_MED dem ON bc.rut_med = dem.rut_med AND bc.esp_id = dem.esp_id -- Relacionar bonos con especialidades médicas
JOIN ESPECIALIDAD_MEDICA em ON dem.esp_id = em.esp_id -- Información de especialidades médicas
LEFT JOIN PAGOS pg ON bc.id_bono = pg.id_bono -- Relación con pagos para determinar estado
WHERE 
    EXTRACT(YEAR FROM bc.fecha_bono) >= 2022 -- Bonos desde 2022
GROUP BY 
    em.nombre, 
    CASE 
        WHEN pg.fecha_pago IS NULL THEN 'INCOBRABLE' 
        ELSE 'COBRABLE' 
    END
ORDER BY 
    Monto_Perdida DESC; -- Ordenar por monto perdido en orden descendente 
    

--DESAFIO 3

WITH BONOS_PACIENTES AS (
    -- Subconsulta que calcula la cantidad de bonos por paciente y calcula su edad
    SELECT 
        bc.pac_run || '-' || p.dv_run AS RUT_PACIENTE, -- Concatenar el RUT del paciente con dígito verificador
        p.pnombre || ' ' || p.apaterno || ' ' || p.amaterno AS NOMBRE_PACIENTE, -- Nombre completo del paciente
        COUNT(bc.id_bono) AS CANTIDAD_BONOS, -- Cantidad de bonos emitidos para el paciente
        FLOOR(MONTHS_BETWEEN(SYSDATE, p.fecha_nacimiento) / 12) AS EDAD -- Calcular la edad usando fecha de nacimiento
    FROM 
        BONO_CONSULTA bc
    JOIN PACIENTE p ON bc.pac_run = p.pac_run -- Relación con la tabla de pacientes
    WHERE 
        EXTRACT(YEAR FROM bc.fecha_bono) = EXTRACT(YEAR FROM SYSDATE) - 1 -- Bonos del año anterior
    GROUP BY 
        bc.pac_run, p.dv_run, p.pnombre, p.apaterno, p.amaterno, p.fecha_nacimiento
),
-- Subconsulta para calcular el promedio redondeado de bonos por paciente
PROMEDIO_BONOS AS (
    SELECT 
        ROUND(AVG(CANTIDAD_BONOS), 0) AS PROMEDIO_REDONDEADO -- Promedio redondeado de bonos
    FROM 
        BONOS_PACIENTES
)
-- Consulta final que incluye el filtro de la cantidad de bonos no superior al promedio redondeado
SELECT 
    bp.RUT_PACIENTE,
    bp.NOMBRE_PACIENTE,
    bp.CANTIDAD_BONOS,
    pb.PROMEDIO_REDONDEADO,
    bp.EDAD
FROM 
    BONOS_PACIENTES bp,
    PROMEDIO_BONOS pb
WHERE 
    bp.CANTIDAD_BONOS <= pb.PROMEDIO_REDONDEADO -- Filtrar pacientes con bonos menores o iguales al promedio
ORDER BY 
    bp.CANTIDAD_BONOS ASC,  -- Ordenar por la cantidad de bonos (menor a mayor)
    bp.EDAD DESC            -- En caso de empate, ordenar por edad (mayor a menor)
FETCH FIRST 43 ROWS ONLY; -- Limitar los resultados a los primeros 43 registros






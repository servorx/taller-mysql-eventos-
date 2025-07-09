-- -- 1
-- -- SOLUCION 
-- -- procedimiento
-- DELIMITER $$

-- CREATE PROCEDURE ev_resumen_diario_unico (
--   rvp_fecha DATE,
--   rvp_total_pedidos INT,
--   rvp_total_ingresos DECIMAL(12,2)
-- ) 
-- BEGIN
--   INSERT INTO resumen_ventas(fecha, total_pedidos, total_ingresos) 
--   VALUES (rvp_fecha, rvp_total_pedidos, rvp_total_ingresos);
-- END $$

-- DELIMITER ;

-- -- evento
-- DELIMITER $$

-- CREATE EVENT resumen_ventas_event 
-- ON SCHEDULE  
--   AT TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 SECOND))
-- ON COMPLETION NOT PRESERVE 
-- ENABLE 
-- COMMENT 'evento que saca resumen una vez al dia sin guardarse automaticamente'
-- DO
-- BEGIN 
--   CALL ev_resumen_diario_unico('2025-09-09', 13, 41000.00);
-- END $$

-- DELIMITER ;
-- -- verificar despues del minuto 
-- SELECT * FROM resumen_ventas;

-- 2 
-- procedimiento
DELIMITER $$

CREATE PROCEDURE pr_resumen_general(
  pr_fecha NOW(),
  pr_total_pedidos INT,
  pr_total_ingresos DECIMAL(12,2)
)
BEGIN
  INSERT 
END $$

DELIMITER ;
-- evento
DELIMITER $$
CREATE EVENT ev_resumen_general
DO 
BEGIN 
  CALL pr_resumen_general();
END $$

DELIMITER ; 
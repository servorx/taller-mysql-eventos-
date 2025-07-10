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





-- -- 2 
-- -- procedimiento
-- DELIMITER $$

-- CREATE PROCEDURE pr_resumen_general()
-- BEGIN
--   DECLARE pr_fecha DATE;
--   DECLARE pr_total_pedidos INT;
--   DECLARE pr_total_ingresos DECIMAL(12,2);

--   SET pr_fecha = DATE_SUB(CURDATE(), INTERVAL 7 DAY);

--   SELECT COUNT(*), SUM(total)
--   INTO pr_total_pedidos, pr_total_ingresos
--   FROM pedidos
--   WHERE YEARWEEK(fecha, 1) = YEARWEEK(CURDATE() - INTERVAL 1 WEEK, 1);

--   INSERT INTO resumen_ventas(fecha, total_pedidos, total_ingresos) VALUES (pr_fecha, pr_total_pedidos, pr_total_ingresos);
-- END $$

-- DELIMITER ;
-- -- evento
-- DELIMITER $$
-- CREATE EVENT ev_resumen_general
-- ON SCHEDULE 
--   EVERY 1 WEEK 
--   STARTS TIMESTAMP(CURRENT_DATE + INTERVAL (8 - WEEKDAY(CURRENT_DATE)) DAY + INTERVAL 1 HOUR)
-- ON COMPLETION PRESERVE
-- ENABLE
-- COMMENT 'crear un evento de creacion de resumen de ventas cada lunes en la mañana'
-- DO 
-- BEGIN 
--   CALL pr_resumen_general();
-- END $$

-- DELIMITER ; 
-- -- probar para ver si funciona 
-- -- esto es para ver la existencia del EVENTO y el procedimiento
-- SHOW EVENTS;
-- SHOW PROCEDURE STATUS WHERE Db = "hola";




-- 3
-- procedimiento
-- generar estos inserts y luego esperar
INSERT INTO ingredientes (nombre, categoria, stock)
VALUES 
  ('Queso Mozzarella', 'Lácteo', 10),
  ('Harina de Trigo', 'Cereal', 8),
  ('Salsa de Tomate', 'Salsas', 12);
INSERT INTO ingredientes (nombre, categoria, stock)
VALUES 
  ('Albahaca', 'Hierbas', 2),
  ('Aceitunas Negras', 'Vegetales', 1),
  ('Jamón Serrano', 'Cárnicos', 4);

DELIMITER $$

CREATE PROCEDURE pr_alerta_stock()
BEGIN 
  DECLARE stock INT;
  -- se insertan los valores de alerta_stock con el select en lugar de VALUES  
  INSERT INTO alerta_stock (ingrediente_id, stock_actual, fecha_alerta)
  SELECT id, stock, NOW()
  FROM ingredientes
  WHERE stock < 5;
END $$

DELIMITER ;
-- evento
DELIMITER $$

CREATE EVENT ev_alerta_stock
ON SCHEDULE
AT INTERVAL 15 SECOND
ON COMPLETION NOT PRESERVE
ENABLE
COMMENT 'alerta de stock bajo'
DO 
BEGIN
  CALL pr_alerta_stock();
END $$

DELIMITER ;
-- PROBAR para ver si funciona el evento
SHOW EVENTS \G

-- luego de 20 segundos ejecutar 
SELECT * FROM alerta_stock;




-- 4
-- procedimiento
DELIMITER $$

CREATE PROCEDURE pr_monitor_stock_bajo()
BEGIN 
  INSERT INTO alerta_stock (ingrediente_id, stock_actual, fecha_alerta)
  SELECT id, stock, NOW()
  FROM ingredientes
  WHERE stock < 10;
END $$

DELIMITER ;
-- evento
DELIMITER $$

CREATE EVENT ev_monitor_stock_bajo
ON SCHEDULE
EVERY 30 MINUTE
STARTS NOW()
ON COMPLETION PRESERVE
ENABLE
COMMENT 'monitoreo constante de ingredientes con stock bajo'
DO 
BEGIN
  CALL pr_monitor_stock_bajo();
END $$

DELIMITER ;
-- PRUEBA
SELECT * FROM alerta_stock;

-- 5 
-- procedimiento
DELIMITER $$

CREATE PROCEDURE pr_purgar_resumen_antiguo()
BEGIN 
  DELETE FROM resumen_ventas
  WHERE fecha < CURDATE() - INTERVAL 365 DAY;
END $$

DELIMITER ;
-- evento 
DELIMITER $$

CREATE EVENT ev_purgar_resumen_antiguo
ON SCHEDULE
AT NOW() + INTERVAL 1 MINUTE
ON COMPLETION NOT PRESERVE
ENABLE
COMMENT 'Limpieza única de resúmenes con más de 1 año de antigüedad'
DO 
BEGIN
  CALL pr_purgar_resumen_antiguo();
END $$

DELIMITER ;
-- prueba
SELECT * FROM resumen_ventas;
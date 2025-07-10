## Actividad

Haciendo uso de las siguientes tablas para la base de datos de `pizza` realice los siguientes ejercicios de `Events`  centrados en el uso de **ON COMPLETION PRESERVE** y **ON COMPLETION NOT PRESERVE** :

```sql
CREATE DATABASE cocina;
USE cocina;

CREATE TABLE IF NOT EXISTS resumen_ventas (
fecha       DATE      PRIMARY KEY,
total_pedidos INT,
total_ingresos DECIMAL(12,2),
creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ingredientes (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80),
    categoria VARCHAR(80),
    stock INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS alerta_stock (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  ingrediente_id  INT NOT NULL,
  stock_actual    INT NOT NULL,
  fecha_alerta    DATETIME NOT NULL,
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ingrediente_id) REFERENCES ingredientes(id)
);
```

## 1
1. Resumen Diario Único : crear un evento que genere un resumen de ventas **una sola vez** al finalizar el día de ayer y luego se elimine automáticamente llamado `ev_resumen_diario_unico`.
```sql
-- 1
-- SOLUCION 
-- procedimiento
DELIMITER $$

CREATE PROCEDURE ev_resumen_diario_unico (
  rvp_fecha DATE,
  rvp_total_pedidos INT,
  rvp_total_ingresos DECIMAL(12,2)
) 
BEGIN
  INSERT INTO resumen_ventas(fecha, total_pedidos, total_ingresos) 
  VALUES (rvp_fecha, rvp_total_pedidos, rvp_total_ingresos);
END $$

DELIMITER ;

-- evento
DELIMITER $$

CREATE EVENT resumen_ventas_event 
ON SCHEDULE  
  AT TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 SECOND))
ON COMPLETION NOT PRESERVE 
ENABLE 
COMMENT 'evento que saca resumen una vez al dia sin guardarse automaticamente'
DO
BEGIN 
  CALL ev_resumen_diario_unico('2025-09-09', 13, 41000.00);
END $$

DELIMITER ;
-- verificar despues del evento 
SELECT * FROM resumen_ventas;
```
![alt text](image.png)


## 2
2. Resumen Semanal Recurrente: cada lunes a las 01:00 AM, generar el total de pedidos e ingresos de la semana pasada, **manteniendo** el evento para que siga ejecutándose cada semana llamado `ev_resumen_semanal`.
```sql
-- solucion
-- procedimiento
DELIMITER $$

CREATE PROCEDURE pr_resumen_general()
BEGIN
  DECLARE pr_fecha DATE;
  DECLARE pr_total_pedidos INT;
  DECLARE pr_total_ingresos DECIMAL(12,2);

  SET pr_fecha = DATE_SUB(CURDATE(), INTERVAL 7 DAY);

  SELECT COUNT(*), SUM(total)
  INTO pr_total_pedidos, pr_total_ingresos
  FROM pedidos
  WHERE YEARWEEK(fecha, 1) = YEARWEEK(CURDATE() - INTERVAL 1 WEEK, 1);

  INSERT INTO resumen_ventas(fecha, total_pedidos, total_ingresos) VALUES (pr_fecha, pr_total_pedidos, pr_total_ingresos);
END $$

DELIMITER ;
-- evento
DELIMITER $$
CREATE EVENT ev_resumen_general
ON SCHEDULE 
  EVERY 1 WEEK 
  STARTS TIMESTAMP(CURRENT_DATE + INTERVAL (8 - WEEKDAY(CURRENT_DATE)) DAY + INTERVAL 1 HOUR)
ON COMPLETION PRESERVE
ENABLE
COMMENT 'crear un evento de creacion de resumen de ventas cada lunes en la mañana'
DO 
BEGIN 
  CALL pr_resumen_general();
END $$

DELIMITER ; 
-- probar para ver si funciona 
-- esto es para ver la existencia del EVENTO y el procedimiento
SHOW EVENTS;
SHOW PROCEDURE STATUS WHERE Db = "hola";
```
![alt text](image-1.png)
## 3
3. Alerta de Stock Bajo Única: en un futuro arranque del sistema (requerimiento del sistema), generar una única pasada de alertas (`alerta_stock`) de ingredientes con stock < 5, y luego autodestruir el evento.
```sql
-- solucion
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
```
![alt text](image-3.png)

## 4 
4. Monitoreo Continuo de Stock: cada 30 minutos, revisar ingredientes con stock < 10 e insertar alertas en `alerta_stock`, **dejando** el evento activo para siempre llamado `ev_monitor_stock_bajo`.
```sql
-- solucion
```
![alt text](image-2.png)
## 5
5. Limpieza de Resúmenes Antiguos: una sola vez, eliminar de `resumen_ventas` los registros con fecha anterior a hace 365 días y luego borrar el evento llamado `ev_purgar_resumen_antiguo`.
```sql
-- solucion
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
```
![alt text](image-4.png)
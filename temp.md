# MySQL EVENT

Los **Eventos** en MySQL son objetos programados que permiten ejecutar de forma automática sentencias SQL en un momento futuro o de forma periódica, sin necesidad de un disparador externo ni de un CRON externo. Se configuran y gestionan dentro del propio servidor de base de datos.

> En **MySQL**, los **eventos** (`EVENTS`) son una funcionalidad del **programador de eventos (Event Scheduler)** que permite ejecutar instrucciones SQL **automáticamente en momentos específicos o de forma recurrente**, sin intervención manual. Es como una **alarma programada** para que una tarea suceda dentro de la base de datos.

> ### 🧒 Explicación simple (como si tuvieras 10 años):
>
> Imagina que tienes un robot que puede hacer tareas por ti, como **borrar archivos viejos cada noche**, o **agregar puntos a jugadores cada hora**. En MySQL, puedes decirle al robot cuándo hacer esas tareas usando **eventos**.
>
> Pdta: Asegurase de ejecutar los eventos y crearlos.

### 🧑‍🎓 Explicación avanzada (nivel universitario):

Un **evento** en MySQL es un objeto de base de datos que define una acción (por ejemplo, una consulta `INSERT`, `UPDATE` o `DELETE`) que se ejecuta **una vez** o de **forma repetitiva** en un horario específico. Se utiliza el **Event Scheduler**, que debe estar habilitado con:

```bash
SET GLOBAL event_scheduler = ON;
```

## Estructura básica de un EVENT

```sql
DELIMITER //
  CREATE [ DEFINER = usuario@host ] -- DEFINER: usuario bajo cuyo contexto se ejecuta.
    EVENT [ IF NOT EXISTS ] nombre_evento
    ON SCHEDULE				-- ON SCHEDULE: define si ocurre AT (una sola vez) o EVERY (recurrente).
      { AT timestamp_exacto
      | EVERY intervalo
        [ STARTS timestamp_inicio ] -- STARTS/ENDS: fecha y hora de arranque o fin de la programación.
        [ ENDS   timestamp_final ]
      } 
    [ ON COMPLETION { PRESERVE | NOT PRESERVE } ] -- ON COMPLETION PRESERVE: conserva el evento tras ejecutarse (por defecto NOT PRESERVE lo elimina si era AT)
    [ ENABLE | DISABLE | DISABLE ON SLAVE ] -- ENABLE/DISABLE: activa o desactiva el evento.
    [ COMMENT '' ]
    DO				-- bloque de sentencias SQL que se ejecutan.
    BEGIN
      bloque_sql;
    END //
  
  DELIMITER ;

```

> **Requisito**: el *event scheduler* debe estar activo: 
>
> ```sql
> SET GLOBAL event_scheduler = ON;
> ```
>
> **Valida el estado de event_scheduler** 
>
> ```sql
>   SHOW GLOBAL VARIABLES LIKE 'event_scheduler';
>   SELECT @@global.event_scheduler AS event_scheduler;
> ```

## Modificar un Evento

```sql
ALTER EVENT [IF EXISTS] nombre_evento
  ON SCHEDULE
    { AT fecha_exacta
    | EVERY intervalo
      [ STARTS fecha_inicio ]
      [ ENDS   fecha_final ]
    }
  [ON COMPLETION { PRESERVE | NOT PRESERVE }]
  [COMMENT 'nuevo comentario'];
```

### Cambiar un evento a periodico

```sql
ALTER EVENT nombre_evento
  ON SCHEDULE
    EVERY 30 MINUTE
    STARTS NOW() + INTERVAL 30 MINUTE
    ENDS NOW() + INTERVAL 7 DAY
  COMMENT 'Ahora alerta cada 30 minutos durante una semana';

```

### Cambiar a un evento UNICO

```sql
ALTER EVENT nombre_evento
  ON SCHEDULE
    AT CONCAT(CURDATE() + INTERVAL 1 DAY, ' 03:00:00')
  ON COMPLETION NOT PRESERVE
  COMMENT 'Reprogramado para mañana a las 03:00';

```

### Verificación

```sql
SHOW CREATE EVENT nombre_evento;
```

### Activar o Desactivar un Evento

```sql
ALTER EVENT [IF EXISTS] nombre_evento
  ENABLE | DISABLE
```

### Ver estado Actual o Status del Evento

```sql
SELECT 
  EVENT_NAME,
  STATUS
FROM information_schema.EVENTS
WHERE EVENT_SCHEMA = DATABASE()
  AND EVENT_NAME IN (
    'nombre_evento',
    'nombre_evento2'
  );
```

### Ejemplo

Generar cada día a las 00:10 AM (u otra hora) un registro en una tabla de resumen (`resumen_ventas`) con totales de pedidos:

```sql
DROP EVENT IF EXISTS ev_resumen_ventas_diario;
CREATE EVENT IF NOT EXISTS ev_resumen_ventas_diario
ON SCHEDULE
  EVERY 1 DAY
  STARTS NOW() + INTERVAL 1 MINUTE
ON COMPLETION PRESERVE
COMMENT 'Resumen de pedidos e ingresos diarios'
DO
BEGIN
  DECLARE v_total_pedidos   INT;
  DECLARE v_total_ingresos  DECIMAL(12,2);

  SELECT COUNT(*), SUM(total)
    INTO v_total_pedidos, v_total_ingresos
    FROM pedido
   WHERE DATE(fecha_recogida) = CURDATE() - INTERVAL 1 DAY;

  INSERT INTO resumen_ventas (fecha, total_pedidos, total_ingresos)
    VALUES (CURDATE() - INTERVAL 1 DAY,
            IFNULL(v_total_pedidos, 0),
            IFNULL(v_total_ingresos, 0.00))
  ON DUPLICATE KEY UPDATE
    total_pedidos = VALUES(total_pedidos),
    total_ingresos = VALUES(total_ingresos);
END;
```

Cada hora, si algún ingrediente baja de 10 unidades, registrar alerta en una tabla:

```sql
DROP EVENT IF EXISTS ev_alerta_stock_bajo;
CREATE EVENT IF NOT EXISTS ev_alerta_stock_bajo
ON SCHEDULE
  EVERY 1 HOUR
  STARTS NOW() + INTERVAL 1 MINUTE
ON COMPLETION PRESERVE
COMMENT 'Alerta si ingrediente stock < 10'
DO
  INSERT INTO alerta_stock (ingrediente_id, stock_actual, fecha_alerta)
  SELECT id, stock, NOW()
    FROM ingrediente
   WHERE stock < 10;
```

### 🛠️ Ejemplo de caso de uso:

> Supón que quieres borrar automáticamente datos de una tabla `logs` cada semana para evitar que se llene demasiado:

```sql
CREATE EVENT limpiar_logs
ON SCHEDULE EVERY 1 WEEK
DO
  DELETE FROM logs WHERE fecha < NOW() - INTERVAL 30 DAY;
```

**En esta actividad Vamos a crear paso a paso un evento en MySQL. Consistirá en enseñarle a un robot a hacer una tarea en piloto automático. Usaremos como ejemplo un evento que borre registros viejos de una tabla llamada `logs`.**

**⚙️ PASOS PARA CREAR UN EVENTO EN MYSQL**

**🥇 Paso 1: Activar el programador de eventos**

Primero, asegúrate de que el *Event Scheduler* está activo. Ejecuta:

```sql
SET GLOBAL event_scheduler = ON;
```

> ⚠️ Nota: Si no eres `SUPER` o `ADMIN`, puede que no te dejen cambiar esto. En ese caso, pide permisos al administrador del sistema.

------

**🥈 Paso 2: Crear la tabla (si no existe)**

Creamos una tabla simple llamada `logs`, con una fecha para simular que guardamos registros:

```sql
CREATE TABLE logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  mensaje VARCHAR(255),
  fecha DATETIME
);
```

Luego insertamos unos datos de prueba:

```
INSERT INTO logs (mensaje, fecha) VALUES ('registro viejo', NOW() - INTERVAL 40 DAY),('registro nuevo', NOW());
```

------

**🥉 Paso 3: Crear el evento**

Ahora sí, creamos el evento que **borra registros más viejos de 30 días**:

```
CREATE EVENT borrar_logs_antiguos
ON SCHEDULE EVERY 1 DAY
DO
  DELETE FROM logs WHERE fecha < NOW() - INTERVAL 30 DAY;
```

------

**🧪 Paso 4: Verificar que el evento se creó**

Puedes ver todos los eventos con:

```sql
SHOW EVENTS;
```

Y revisar detalles de un evento específico:

```sql
SHOW CREATE EVENT borrar_logs_antiguos\G
```

------

**📅 Opción: Crear un evento que se ejecute una sola vez**

```sql
CREATE EVENT borrar_una_vez
ON SCHEDULE AT NOW() + INTERVAL 1 MINUTE
DO
  DELETE FROM logs WHERE fecha < NOW() - INTERVAL 30 DAY;
```

Este evento se ejecutará una sola vez dentro de un minuto.

**Desactive el evento**

```sql
ALTER EVENT borrar_una_vez DISABLE;
```

**Por defecto, MySQL borra eventos de una sola ejecución justo después que corren. Pero tú puedes pedirle *que no lo haga* con esta opción:**

```sql
ON COMPLETION PRESERVE
```

```sql
CREATE EVENT evento_persistente
ON SCHEDULE AT NOW() + INTERVAL 1 MINUTE
ON COMPLETION PRESERVE
DO
  INSERT INTO logs (mensaje, fecha)
  VALUES ('Evento ejecutado', NOW());
```

# Otros casos

## 🧪 EJEMPLO 1: Cambiar el horario del evento

```sql
ALTER EVENT evento_persistente
ON SCHEDULE AT NOW() + INTERVAL 10 MINUTE;
```

Este comando cambia el evento para que se ejecute dentro de 10 minutos.

------

## 🔁 EJEMPLO 2: Hacer que el evento sea recurrente

```sql
ALTER EVENT evento_persistente
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE;
```

Esto convierte tu evento en uno que se ejecuta **una vez al día** y no se borra.

------

## 🛑 EJEMPLO 3: Desactivar un evento

```sql
ALTER EVENT evento_persistente DISABLE;
```

Esto pausa la ejecución del evento sin borrarlo.

------

## ✅ EJEMPLO 4: Habilitar un evento

```sql
ALTER EVENT evento_persistente ENABLE;
```

------

## ✏️ EJEMPLO 5: Cambiar la acción (`DO`)

```sql
ALTER EVENT evento_persistente
DO
  INSERT INTO logs (mensaje, fecha)
  VALUES ('Evento modificado', NOW());
```

Esto modifica lo que el evento hace cuando se ejecuta.

------

## 🕵️ VERIFICAR CAMBIOS

Después de modificar, puedes ver los detalles con:

```sql
SHOW CREATE EVENT evento_persistente\G
```

## Actividad

Haciendo uso de las siguientes tablas para la base de datos de `pizza` realice los siguientes ejercicios de `Events`  centrados en el uso de **ON COMPLETION PRESERVE** y **ON COMPLETION NOT PRESERVE** :

```sql

CREATE TABLE IF NOT EXISTS resumen_ventas (
fecha       DATE      PRIMARY KEY,
total_pedidos INT,
total_ingresos DECIMAL(12,2),
creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS alerta_stock (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  ingrediente_id  INT UNSIGNED NOT NULL,
  stock_actual    INT NOT NULL,
  fecha_alerta    DATETIME NOT NULL,
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ingrediente_id) REFERENCES ingrediente(id)
);
```

1. Resumen Diario Único : crear un evento que genere un resumen de ventas **una sola vez** al finalizar el día de ayer y luego se elimine automáticamente llamado `ev_resumen_diario_unico`.
2. Resumen Semanal Recurrente: cada lunes a las 01:00 AM, generar el total de pedidos e ingresos de la semana pasada, **manteniendo** el evento para que siga ejecutándose cada semana llamado `ev_resumen_semanal`.
3. Alerta de Stock Bajo Única: en un futuro arranque del sistema (requerimiento del sistema), generar una única pasada de alertas (`alerta_stock`) de ingredientes con stock < 5, y luego autodestruir el evento.
4. Monitoreo Continuo de Stock: cada 30 minutos, revisar ingredientes con stock < 10 e insertar alertas en `alerta_stock`, **dejando** el evento activo para siempre llamado `ev_monitor_stock_bajo`.
5. Limpieza de Resúmenes Antiguos: una sola vez, eliminar de `resumen_ventas` los registros con fecha anterior a hace 365 días y luego borrar el evento llamado `ev_purgar_resumen_antiguo`.
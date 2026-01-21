
# pg_logify 📝✨

**pg_logify** es un framework de logging con una funcion avanzada para PostgreSQL que transforma los mensajes `NOTICE` estándar en registros enriquecidos, visualmente atractivos y persistentes.

Con **pg_logify**, puedes dar formato a tus mensajes con colores ANSI, estilos tipográficos Unicode (negritas, burbujas, cursivas) y dirigirlos automáticamente a la consola o simplemente retornarlo para guardarlo en alguna variable y reutlizarlo despues , 
también guardar el texto en un archivos del sistema operativo o a tablas de auditoría bien estructurada y estandarizada.



Un framework define una forma estándar de hacer las cosas. En lugar de que cada desarrollador use su propio RAISE NOTICE, todos usan pg_logify. Esto garantiza que todos los logs de tu servidor tengan el mismo formato, la misma zona horaria y el mismo estilo


---

## 🚀 Características Principales

* **🎨 Estilo Visual:** Soporte completo para colores ANSI (Rojo, Verde, Azul, etc.) y estilos (Negrita, Parpadeo, Subrayado).
* **🔡 Tipografías Unicode:** Motor de transformación de texto integrado para usar tipografías como 𝗯𝗼𝗹𝗱, ⓑⓤⓑⓑⓛⓔ, ⁱᵗᵃˡⁱᶜ y más.
* **💾 Persistencia Multi-destino:**
    * **Consola:** Salida formateada directamente en `psql`.
    * **Archivo:** Escritura en archivos de logs a nivel de Servidor (S.O.).
    * **Tabla:** (En desarrollo) Registro automático en el esquema `logs` para auditoría SQL.
* **🧠 Inteligencia de Cliente:** Detecta automáticamente si el cliente es `psql` para aplicar formatos o texto plano.

---

## 🛠️ Instalación

1. Ejecuta el script en tu base de datos:
```bash
psql -d tu_db -f pg_logify.sql

```



---

## 📖 Guía de Uso

 
```sql

---------------------------------------------------------
-- 1) RETORNO DE TEXTO (Para asignar a variables)
---------------------------------------------------------
-- Nota: p_is_return = FALSE devuelve el valor TEXT sin imprimir NOTICE
SELECT 'Resultado capturado: ' || systools.pg_logify('Texto para variable', 'cyan', 'bold', FALSE) AS test_variable;

---------------------------------------------------------
-- 2) PRUEBA DE COLORES ANSI (Solo visibles en psql)
---------------------------------------------------------
SELECT systools.pg_logify('Color: BLACK',   'black',   'bold');
SELECT systools.pg_logify('Color: RED',     'red',     'bold');
SELECT systools.pg_logify('Color: GREEN',   'green',   'bold');
SELECT systools.pg_logify('Color: YELLOW',  'yellow',  'bold');
SELECT systools.pg_logify('Color: BLUE',    'blue',    'bold');
SELECT systools.pg_logify('Color: MAGENTA', 'magenta', 'bold');
SELECT systools.pg_logify('Color: CYAN',    'cyan',    'bold');
SELECT systools.pg_logify('Color: WHITE',   'white',   'bold');

---------------------------------------------------------
-- 3) PRUEBA DE ESTILOS ANSI
---------------------------------------------------------
SELECT systools.pg_logify('Estilo: NEGRITA ',   '', 'bold');
SELECT systools.pg_logify('Estilo: ITALIC',     '', 'italic');
SELECT systools.pg_logify('Estilo: SUBRAYADO',  '', 'underline');
SELECT systools.pg_logify('Estilo: PARPADEANTE','', 'blink');
SELECT systools.pg_logify('Estilo: dim',        '', 'dim');
SELECT systools.pg_logify('Estilo: reverse',    '', 'reverse');
SELECT systools.pg_logify('Estilo: hidden',     '', 'hidden');

---------------------------------------------------------
-- 4) TRANSFORMACIONES UNICODE (Tipografía)
---------------------------------------------------------

SELECT systools.pg_logify('Tipografia: BOLD',          '', '', TRUE, NULL, FALSE, NULL, 'bold');
SELECT systools.pg_logify('Tipografia: ITALIC',        '', '', TRUE, NULL, FALSE, NULL, 'italic');
SELECT systools.pg_logify('Tipografia: BUBBLE',        '', '', TRUE, NULL, FALSE, NULL, 'bubble');
SELECT systools.pg_logify('Tipografia: INVERTED',      '', '', TRUE, NULL, FALSE, NULL, 'inverted');
SELECT systools.pg_logify('Tipografia: bold_italic',   '', '', TRUE, NULL, FALSE, NULL, 'bold_italic');
SELECT systools.pg_logify('Tipografia: underlined',    '', '', TRUE, NULL, FALSE, NULL, 'underlined');
SELECT systools.pg_logify('Tipografia: strikethrough', '', '', TRUE, NULL, FALSE, NULL, 'strikethrough');
SELECT systools.pg_logify('Tipografia: superscript',   '', '', TRUE, NULL, FALSE, NULL, 'superscript');
SELECT systools.pg_logify('Tipografia: subscript',     '', '', TRUE, NULL, FALSE, NULL, 'subscript');




---------------------------------------------------------
-- 5) COMBINACIONES (Color + Estilo + Tipografía + Timestamp)
---------------------------------------------------------
-- Texto en cian, negrita, con timestamp y tipografía bubble
SELECT systools.pg_logify('Log de Sistema OK', 'cyan', 'bold', TRUE, NULL, TRUE, NULL, 'bold');

-- Texto en rojo, con timestamp y transformación a mayúsculas (UPPER)
SELECT systools.pg_logify('Error critico detectado', 'red', 'bold', TRUE, NULL, TRUE, 'upper');



---------------------------------------------------------
-- 6) Guardar en un archivo y tabla
---------------------------------------------------------
-- Después de ejecutar los ejemplos anteriores, verifica que se registraron correctamente

SELECT systools.pg_logify(
    p_text      := 'ERROR: Fallo de conexión con API externa',
    p_color     := 'red',
    p_style     := 'bold',
    p_log_path  := '/tmp/msg_pg_logify.log',
    p_add_timestamp := false,
    p_case      := 'upper'
);

 
---------------------------------------------------------
-- 7) VALIDACIÓN DE LOGS (Auditoría Corporativa)
---------------------------------------------------------
-- Después de ejecutar los ejemplos anteriores, verifica que se registraron correctamente
SELECT 
    log_id, 
    status, 
    fun_name, 
    user_name, 
    msg, 
    date_insert 
FROM logs.functions 
WHERE fun_name = 'systools.pg_logify'
ORDER BY date_insert DESC 
LIMIT 10;





-- 1. Prueba de Overrides completos (Campos válidos)
SELECT systools.pg_logify(
    p_text       := 'Evento de Seguridad Detectado',
    p_color      := 'red',
    p_typography := 'italic',
    p_extra_data := '{
        "log_level": "CRITICAL",
        "category": "SECURITY",
        "detail": "Intento de fuerza bruta en login",
        "app_user": "firewall_admin",
        "request_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
        "app_name"  : "contabilidad.exe",
        "line_number": 1024,
        "sql_state": "XX000"
    }'::jsonb
);



-- 2. Prueba de Sanitización (Evitando inyección y tipos erróneos)
-- Aquí enviamos basura en request_id y line_number, y un log_level inexistente.
-- El sistema debe usar defaults seguros.
SELECT systools.pg_logify(
    p_text       := 'Prueba Sanitizacion',
    p_extra_data := '{
        "log_level": "NIVEL_HACKER", 
        "line_number": "no_soy_un_numero",
        "request_id": "no_soy_un_uuid",
        "sql_state": "CODIGO_MUY_LARGO_PARA_SQL_STATE"
    }'::jsonb
);

--- 3 
SELECT systools.pg_logify(
    'Procesamiento de nómina completado',
    'green',
    p_extra_data := jsonb_build_object(
        'log_level', 'INFO',
        'category',  'FINANCE',
        'app_user',  'admin_contable',
        'request_id', gen_random_uuid() -- Generas el ID de rastreo al vuelo
    )
);

```

---

## 🎨 Tipografías Soportadas

| Comando | Resultado |
| --- | --- |
| `bold` | **𝗮𝗯𝗰𝗱** |
| `bubble` | ⓐⓑⓒⓓ |
| `italic` | *𝑎𝑏𝑐𝑑* |
| `subscript` | ₐᵦcd |
| `inverted` | ɐqɔp |



### **¿Qué puedes hacer con pg_logify? (Casos de uso)**

* **Dashboards en Terminal:** Crear reportes visuales con semáforos de colores (verde, amarillo, rojo) para ver el estado de salud de la DB de un vistazo.
* **Auditoría Forense:** Registrar quién, cuándo y desde qué aplicación se ejecutó un proceso, guardándolo en una tabla de logs imposible de borrar por el usuario.
* **Monitoreo de ETLs:** Rastrear cargas de datos masivas en tiempo real, usando barras de colores para identificar en qué lote ocurrió un error.
* **Debug de Scripts Complejos:** Reemplazar el `RAISE NOTICE` aburrido por mensajes con tipografías especiales (negritas, cursivas, burbujas) para diferenciar variables de sistema.
* **Caja Negra de Funciones:** Grabar automáticamente el inicio y fin de funciones críticas en archivos externos del servidor para depuración posterior.
* **UX para DBAs:** Crear menús e interfaces interactivas en `psql` más elegantes y legibles mediante estilos de texto (subrayados, invertidos, parpadeos).
* **Alertas Visuales:** Hacer que los errores críticos "parpadeen" en la consola para que el administrador los detecte inmediatamente.

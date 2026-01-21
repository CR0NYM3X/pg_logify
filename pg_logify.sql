CREATE SCHEMA IF NOT EXISTS logs;

-- DROP TABLE logs.system_events;
-- TRUNCATE TABLE logs.system_events RESTART IDENTITY ;
CREATE TABLE IF NOT EXISTS logs.system_events (
    -- Identificadores básicos
    log_id          BIGSERIAL PRIMARY KEY,
    
    -- Clasificación (Crucial para filtros rápidos)
    log_level       VARCHAR(20) NOT NULL CHECK (log_level IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    category        VARCHAR(50), -- Ej: 'AUTH', 'INVENTORY', 'PAYMENT'
    
    -- Detalles del Mensaje
    message         TEXT,
    detail          TEXT, -- El "hint" o detalle técnico de PostgreSQL
    
    -- Trazabilidad del Código (¿Dónde falló?)
    objetct_name    TEXT NOT NULL, -- Nombre de la Función, Trigger o Script
    line_number     INTEGER,
    sql_state       varchar(300), -- El código de error estándar de SQL (ej: '23505')
    
    -- Contexto de Ejecución (¿Quién y desde dónde?)
    db_name         VARCHAR(300),
    db_user         NAME DEFAULT CURRENT_USER,
	app_name        VARCHAR(100), -- nombre de la aplicación generando este evento
    app_user        VARCHAR(100), -- ID del usuario de tu aplicación
    client_ip       INET,
    request_id      UUID, -- Para correlacionar con logs de backend/microservicios
    
    -- Datos Críticos (El estado de las variables al momento del error)
    -- payload         JSONB, -- Captura los parámetros de entrada o el estado del registro

    -- control del tiempo
    start_time    TIMESTAMPTZ,
    date_insert   TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),


    -- Metadatos de Auditoría
    is_resolved     BOOLEAN DEFAULT FALSE,
    resolved_at     TIMESTAMPTZ,
    resolved_by     VARCHAR(100),
    comments        TEXT
);


-- Índices estratégicos para rendimiento
CREATE INDEX idx_logs_level_time ON logs.system_events (log_level, log_time DESC);
CREATE INDEX idx_logs_request_id ON logs.system_events (request_id);
CREATE INDEX idx_logs_payload ON logs.system_events USING GIN (payload); -- Búsqueda rápida dentro del JSON

-- Comentarios estratégicos
COMMENT ON TABLE logs.system_events IS 'Framework centralizado para el registro de logs, errores y auditoría del sistema.';
COMMENT ON COLUMN logs.system_events.log_id IS 'Identificador único secuencial de la entrada de log.';
COMMENT ON COLUMN logs.system_events.log_time IS 'Fecha y hora exacta de la ejecución (con zona horaria) usando clock_timestamp().';
COMMENT ON COLUMN logs.system_events.log_level IS 'Nivel de severidad: DEBUG, INFO, WARNING, ERROR, CRITICAL.';
COMMENT ON COLUMN logs.system_events.category IS 'Módulo o área funcional (ej: PAGOS, LOGIN, NOMINA).';
COMMENT ON COLUMN logs.system_events.message IS 'Descripción principal del evento o error.';
COMMENT ON COLUMN logs.system_events.detail IS 'Información técnica adicional o el HINT devuelto por la base de datos.';
COMMENT ON COLUMN logs.system_events.objetct_name IS 'Ubicación en el código: Nombre de la función, procedimiento o trigger.';
COMMENT ON COLUMN logs.system_events.line_number IS 'Línea específica del código donde se disparó el evento.';
COMMENT ON COLUMN logs.system_events.sql_state IS 'Código de error estándar de SQL (SQLSTATE).';
COMMENT ON COLUMN logs.system_events.db_user IS 'Usuario de la base de datos que ejecutó la instrucción.';
COMMENT ON COLUMN logs.system_events.app_user IS 'ID o username del usuario final dentro de la aplicación.';
COMMENT ON COLUMN logs.system_events.client_ip IS 'Dirección IP desde la cual se originó la petición.';
COMMENT ON COLUMN logs.system_events.request_id IS 'ID único de seguimiento (Correlation ID) para trazabilidad con el Backend.';
-- COMMENT ON COLUMN logs.system_events.payload IS 'Datos en formato JSON de las variables o el registro afectado en ese momento.';
COMMENT ON COLUMN logs.system_events.is_resolved IS 'Bandera de auditoría para marcar errores ya corregidos.';
COMMENT ON COLUMN logs.system_events.resolved_at IS 'Fecha y hora en que se marcó como solucionado.';
COMMENT ON COLUMN logs.system_events.resolved_by IS 'Nombre o ID del técnico que resolvió el incidente.';



/* -- Ver los comentarios 
SELECT 
    cols.column_name, 
    (SELECT pg_catalog.col_description(c.oid, cols.ordinal_position::int)
     FROM pg_catalog.pg_class c
     WHERE c.relname = cols.table_name) AS column_comment
FROM 
    information_schema.columns cols
WHERE 
    cols.table_name = 'system_events' -- Nombre de tu tabla
    AND cols.table_schema = 'logs'; -- Tu esquema
*/





/*
 @Function: systools.pg_logify
 @Creation Date: 20/01/2026
 @Description: Formatea logs con estándares ANSI/Unicode, permite escritura en disco mediante shell 
                y gestiona auditoría dinámica en la tabla logs.system_events.
 @Parameters:
   - @p_text (text): Mensaje principal a procesar y registrar.
   - @p_color (text): Color ANSI para consola psql (red, green, blue, etc.).
   - @p_style (text): Estilo ANSI para consola psql (bold, dim, italic, underline, etc.).
   - @p_is_return (boolean): TRUE para emitir RAISE NOTICE; FALSE para retornar el texto formateado.
   - @p_log_path (text): Ruta absoluta en el servidor para persistencia física (via COPY PROGRAM).
   - @p_add_timestamp (boolean): Indica si se añade prefijo [YYYY-MM-DD HH24:MI:SS] al texto.
   - @p_case (text): Transformación de caja ('upper' o 'lower').
   - @p_typography (text): Estilo de fuente Unicode (bold, italic, bubble, inverted, etc.).
   - @p_save_table (boolean): Controla si el evento se registra en la tabla logs.system_events.
   - @p_extra_data (jsonb): Objeto para sobreescribir columnas de auditoría (log_level, category, request_id, etc.).
 @Returns: text - NULL si p_is_return es TRUE, o el texto formateado si es FALSE.
 @Author: CR0NYM3X
 ---------------- HISTORY ----------------
 @Date: 20/01/2026
 @Change: Refactorización integral: eliminación de columna payload, sanitización de JSONB 
           y soporte para mapeo dinámico de columnas de auditoría.
 @Author: CR0NYM3X
*/
 
 ---------------- COMMENT ----------------
COMMENT ON FUNCTION systools.pg_logify(text, text, text, boolean, text, boolean, text, text, boolean, jsonb) IS
'Herramienta universal de logging y formateo.
- Formato: ANSI Colors, Estilos psql y Tipografías Unicode.
- Persistencia: Shell Append (p_log_path) y DB (logs.system_events).
- Flexibilidad: p_extra_data permite modificar dinámicamente: log_level, category, detail, line_number, sql_state, app_name, app_user y request_id.
- Seguridad: Sanitización estricta de tipos y bind parameters contra inyección SQL.';


CREATE SCHEMA IF NOT EXISTS systools;

-- DROP FUNCTION IF EXISTS systools.pg_logify(TEXT, TEXT, TEXT, BOOLEAN, TEXT, BOOLEAN, TEXT, TEXT, BOOLEAN, JSONB);
CREATE OR REPLACE FUNCTION systools.pg_logify(
    p_text              TEXT,
    p_color             TEXT    DEFAULT '',
    p_style             TEXT    DEFAULT '',
    p_is_return         BOOLEAN DEFAULT TRUE,
    p_log_path          TEXT    DEFAULT NULL,
    p_add_timestamp     BOOLEAN DEFAULT FALSE,
    p_case              TEXT    DEFAULT NULL,
    p_typography        TEXT    DEFAULT NULL,
    p_save_table        BOOLEAN DEFAULT TRUE,
    p_extra_data        JSONB   DEFAULT '{}'::jsonb
)
RETURNS TEXT 
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET client_min_messages = 'notice'
SET search_path = 'systools, logs, pg_catalog, pg_temp'
AS $func$
DECLARE
    -- Diagnóstico e Infraestructura
    v_sql_state     TEXT;
    v_message       TEXT;
    v_context       TEXT;
    v_detail        TEXT;
    v_start_time    TIMESTAMPTZ := clock_timestamp();
    
    -- Variables de Auditoría (Sanitizadas)
    v_log_level     TEXT    := 'INFO';
    v_category      TEXT    := 'UTILITY';
    v_aud_detail    TEXT;
    v_line_number   INTEGER;
    v_aud_sql_state CHAR(5) := '00000';
    v_app_name      TEXT    := current_setting('application_name', true);
    v_app_user      TEXT;
    v_request_id    UUID;

    -- Lógica de Formato
    v_color_code    TEXT := '';
    v_style_code    TEXT := '';
    v_reset_code    TEXT := E'\033[0m';
    v_is_psql       BOOLEAN;
    v_final_text    TEXT;
    v_prefix        TEXT := '';
    v_processed     TEXT;

    -- Query de Auditoría (13 parámetros - Sin Payload)
    v_log_query TEXT := $sql$
        INSERT INTO logs.system_events (
            log_level, category, message, detail, objetct_name, 
            line_number, sql_state, db_name, app_name, app_user, 
            client_ip, request_id, start_time
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, current_database(), $8, $9, $10, $11, $12)
    $sql$;
BEGIN
    -- 1. Detección de entorno
    v_is_psql := current_setting('application_name', true) ILIKE 'psql%';
    v_processed := p_text;

    -- 2. Sanitización y Mapeo desde p_extra_data
    IF p_extra_data IS NOT NULL AND p_extra_data <> '{}'::jsonb THEN
        v_log_level := CASE 
            WHEN upper(p_extra_data->>'log_level') IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL') 
            THEN upper(p_extra_data->>'log_level') 
            ELSE v_log_level END;

        v_category      := COALESCE(NULLIF(trim(p_extra_data->>'category'), ''), v_category);
        v_aud_detail    := NULLIF(trim(p_extra_data->>'detail'), '');
        v_app_name      := COALESCE(NULLIF(trim(p_extra_data->>'app_name'), ''), v_app_name);
        v_app_user      := NULLIF(trim(p_extra_data->>'app_user'), '');
        v_aud_sql_state := COALESCE(left(NULLIF(trim(p_extra_data->>'sql_state'), ''), 5), v_aud_sql_state);

        BEGIN v_line_number := (p_extra_data->>'line_number')::INTEGER; EXCEPTION WHEN OTHERS THEN v_line_number := NULL; END;
        BEGIN v_request_id  := (p_extra_data->>'request_id')::UUID;   EXCEPTION WHEN OTHERS THEN v_request_id  := NULL; END;
    END IF;

    -- 3. Transformaciones de base
    IF p_add_timestamp THEN 
        v_prefix := '[' || to_char(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || '] '; 
    END IF;

    IF lower(p_case) = 'upper' THEN v_processed := upper(v_processed);
    ELSIF lower(p_case) = 'lower' THEN v_processed := lower(v_processed);
    END IF;

    -- 4. Bloque Completo de Tipografía Unicode
    IF p_typography IS NOT NULL THEN
        CASE lower(p_typography)
            WHEN 'bold'           THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '𝗮𝗯𝗰𝗱𝗲𝗳𝗴𝗵𝗶ｼ𝗸𝗹𝗺𝗻𝗼𝗽𝗾𝗿𝘀𝘁𝘂𝘃𝘄𝗅𝘆𝘇𝗔𝗕𝗖𝗗𝗘𝗙𝗚𝗛𝗜𝗝𝗞𝑳𝗠𝗡𝗢𝗣𝗤𝗥𝗦𝗧𝗨𝗩𝗪𝗫𝗬𝗭');
            WHEN 'italic'         THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '𝑎𝑏𝑐𝑑𝑒𝑓𝑔ℎ𝑖𝑗𝑘𝑙𝑚 n𝑜𝑝𝑞𝑟𝑠𝑡𝑢𝑣𝑤𝑥𝑦𝑧𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁');
            WHEN 'bold_italic'    THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '𝒂𝒃𝒄𝒅𝒆𝒇𝒉𝒊𝒋𝒌𝒍𝒎𝒏𝒐𝒑𝒒𝒓𝒔𝒕𝒖𝒗𝒘𝒙𝒚𝒛𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁');
            WHEN 'underlined'     THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'a̲b̲c̲d̲e̲f̲g̲h̲i̲j̲k̲l̲m̲n̲o̲p̲q̲r̲s̲t̲u̲v̲w̲x̲y̲z̲A̲B̲C̲D̲E̲F̲G̲H̲I̲J̲K̲L_M_N_O_P_Q_R_S_T_U_V_W_X_Y_Z_');
            WHEN 'strikethrough'  THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'a̶b̶c̶d̶e̶f̶g̶h̶i̶j̶k̶l̶m̶n̶o̶p̶q̶r̶s̲t̲u̲v̲w̲x̲y̲z̲A̲B̲C̲D̲E̲F̲G̲H_I_J_K_L_M_N_O_P_Q_R_S_T_U_V_W_X_Y_Z_');
            WHEN 'superscript'    THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 'ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖᵠʳˢᵗᵘᵛʷˣʸᶻᴬᴮᶜᴰᴱᶠᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᵠᴿˢᵀᵁⱽᵂˣʸᶻ⁰¹²³⁴⁵⁶⁷⁸⁹');
            WHEN 'subscript'      THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 'ₐₑᵢₒᵤᵢₑᵢₒᵤₖₗₘₙₒₚₓᵩᵣₛₜᵤ₥ₙₓₓₓ₀₁₂₃₄₅₆₇₈₉');
            WHEN 'bubble'         THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 'ⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩⒶⒷⒸⒹⒺⒻⒼⒽⒾⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏ⓪①②③④⑤⑥⑦⑧⑨');
            WHEN 'inverted'       THEN v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'ɐqɔpǝɟƃɥᴉɾʞןɯuodbɹsʇnʌʍxʎz∀ԐↃpƎℲ⅁HIſ⋊⅃WNOԀΌɹS⊥∩ΛMX⅄Z');
            ELSE RAISE EXCEPTION 'Tipografía no soportada: %', p_typography;
        END CASE;
    END IF;

    -- 5. Estilos ANSI
    IF v_is_psql THEN
        v_color_code := CASE lower(p_color)
            WHEN 'black' THEN E'\033[30m' WHEN 'red' THEN E'\033[31m' WHEN 'green' THEN E'\033[32m' 
            WHEN 'yellow' THEN E'\033[33m' WHEN 'blue' THEN E'\033[34m' WHEN 'magenta' THEN E'\033[35m' 
            WHEN 'cyan' THEN E'\033[36m' WHEN 'white' THEN E'\033[37m' ELSE '' END;
        v_style_code := CASE lower(p_style)
            WHEN 'bold' THEN E'\033[1m' WHEN 'dim' THEN E'\033[2m' WHEN 'italic' THEN E'\033[3m' 
            WHEN 'underline' THEN E'\033[4m' WHEN 'blink' THEN E'\033[5m' WHEN 'reverse' THEN E'\033[7m' 
            WHEN 'hidden' THEN E'\033[8m' ELSE '' END;
        IF v_color_code = '' AND v_style_code = '' THEN v_reset_code := ''; END IF;
        v_final_text := v_style_code || v_color_code || v_prefix || v_processed || v_reset_code;
    ELSE
        v_final_text := v_prefix || v_processed;
    END IF;

    -- 6. Escritura en Shell
    IF p_log_path IS NOT NULL THEN
        BEGIN
            EXECUTE format('COPY (SELECT 1) TO PROGRAM %L', format('echo %L >> %I', to_char(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || '| ' || p_text, p_log_path));
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Fallo en escritura física en %. Revisar permisos.', p_log_path;
        END;
    END IF;

    -- 7. Auditoría Corporativa (Sin Payload)
    IF p_save_table THEN
        EXECUTE v_log_query USING 
            v_log_level, v_category, p_text, v_aud_detail, 'systools.pg_logify', 
            v_line_number, v_aud_sql_state, v_app_name, v_app_user, 
            COALESCE(inet_client_addr(), '127.0.0.1'), v_request_id, v_start_time;
    END IF;

    -- 8. Retorno
    IF p_is_return THEN
        RAISE NOTICE '%', v_final_text;
        RETURN NULL;
    ELSE
        RETURN v_final_text;
    END IF;

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_message = MESSAGE_TEXT, v_sql_state = RETURNED_SQLSTATE, v_context = PG_EXCEPTION_CONTEXT, v_detail = PG_EXCEPTION_DETAIL;
    EXECUTE v_log_query USING 
        'ERROR', 'SYSTEM_FAIL', v_message, v_detail, 'systools.pg_logify', 
        NULL, v_sql_state, v_app_name, 'SYSTEM', 
        COALESCE(inet_client_addr(), '127.0.0.1'), NULL, v_start_time;
    RAISE EXCEPTION 'Error crítico en pg_logify: %', v_message;
END;
$func$;







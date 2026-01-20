---------------- LOG ----------------
CREATE SCHEMA IF NOT EXISTS logs;

-- DROP TABLE logs.functions;
-- TRUNCATE TABLE logs.functions RESTART IDENTITY ;

-- LOG (Infraestructura de Logging)
CREATE TABLE IF NOT EXISTS logs.functions (
    log_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status        text NOT NULL CHECK (status IN ('successful','failed')),
    db_name       text NOT NULL,
    fun_name      text NOT NULL,
    ip_client     inet,
    user_name     text NOT NULL,
    query         text,
    msg           text,
    start_time    timestamptz NOT NULL,
    date_insert   timestamptz NOT NULL DEFAULT clock_timestamp(),
    app_name      text,
    txid          bigint DEFAULT txid_current()
);

-- select * from logs.functions;



/*
 @Function: systools.pg_logify
 @Creation Date: 20/01/2026
 @Description: Formatea texto con colores ANSI (psql), tipografías Unicode y permite persistencia en archivos.
 @Parameters:
   - @p_text (text): Texto base a procesar.
   - @p_color (text): Color ANSI (red, green, blue, etc.).
   - @p_style (text): Estilo ANSI (bold, italic, underline, etc.).
   - @p_is_return (boolean): TRUE para RAISE NOTICE y retornar NULL; FALSE para retornar el TEXT formateado.
   - @p_log_path (text): Ruta opcional para escribir el log en disco (requiere adminpack).
   - @p_add_timestamp (boolean): Incluye prefijo de fecha/hora.
   - @p_case (text): 'upper' o 'lower'.
   - @p_typography (text): Estilos Unicode (bold, italic, bubble, etc.).
 @Returns: text - El texto formateado o NULL según p_is_return.
 @Author: CR0NYM3X
 ---------------- HISTORY ----------------
 @Date: 20/01/2026
 @Change: Refactorización a estándar corporativo, optimización de lógica de retorno y manejo de excepciones.
 @Author: CR0NYM3X
*/

---------------- COMMENT ----------------
COMMENT ON FUNCTION systools.pg_logify(text, text, text, boolean, text, boolean, text, text) IS
'Herramienta de formateo de logs y consola.
- Soporta: Colores ANSI, estilos psql, transformaciones Unicode y escritura en archivo.
- Volatilidad: STABLE.
- Seguridad: SECURITY DEFINER con search_path fijo.
- Notas: La escritura en archivo requiere la extensión adminpack y permisos de superusuario o pg_write_server_files.';



CREATE SCHEMA IF NOT EXISTS systools;



-- DROP FUNCTION IF EXISTS systools.pg_logify(TEXT, TEXT, TEXT, BOOLEAN, TEXT, BOOLEAN, TEXT, TEXT);
CREATE OR REPLACE FUNCTION systools.pg_logify(
    p_text              TEXT,
    p_color             TEXT    DEFAULT '',
    p_style             TEXT    DEFAULT '',
    p_is_return         BOOLEAN DEFAULT TRUE,
    p_log_path          TEXT    DEFAULT NULL,
    p_add_timestamp     BOOLEAN DEFAULT FALSE,
    p_case              TEXT    DEFAULT NULL,
    p_typography        TEXT    DEFAULT NULL
)
RETURNS TEXT 
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET client_min_messages = 'notice'
SET search_path = 'systools, pg_catalog, pg_temp'
AS $func$
DECLARE
    -- Diagnóstico e Infraestructura
    ex_message      TEXT;
    ex_context      TEXT;
    v_start_time    TIMESTAMPTZ := clock_timestamp();
    v_status        TEXT        := 'successful';
    
    -- Lógica de Formato
    v_color_code    TEXT := '';
    v_style_code    TEXT := '';
    v_reset_code    TEXT := E'\033[0m';
    v_is_psql       BOOLEAN;
    v_final_text    TEXT;
    v_prefix        TEXT := '';
    v_processed     TEXT;
    
    v_shell_cmd TEXT;
    v_log_line  TEXT;


    -- Auditoría Corporativa
    v_log_query TEXT := $sql$
        INSERT INTO logs.functions (fun_name, db_name, ip_client, user_name, start_time, status, msg, app_name)
        VALUES ('systools.pg_logify', current_database(), COALESCE(inet_client_addr(), '127.0.0.1'), session_user, $1, $2, $3, current_setting('application_name', true))
    $sql$;
BEGIN
    -- 1. Detección de entorno
    v_is_psql := current_setting('application_name', true) ILIKE 'psql%';
    v_processed := p_text;

    -- 2. Transformaciones de base (Case & Timestamp)
    IF p_add_timestamp THEN 
        v_prefix := '[' || to_char(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || '] '; 
    END IF;

    IF lower(p_case) = 'upper' THEN v_processed := upper(v_processed);
    ELSIF lower(p_case) = 'lower' THEN v_processed := lower(v_processed);
    END IF;

    -- 3. Bloque Completo de Tipografía Unicode
    IF p_typography IS NOT NULL THEN
        CASE lower(p_typography)
            WHEN 'bold' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '𝗮𝗯𝗰𝗱𝗲𝗳𝗴𝗵𝗶𝗷𝗸𝗹𝗺𝗻𝗼𝗽𝗾𝗿𝘀𝘁𝘂𝘃𝘄𝗅𝘆𝘇𝗔𝗕𝗖𝗗𝗘𝗙𝗚𝗛𝗜𝗝𝗞𝗟𝗠𝗡𝗢𝗣𝗤𝗥𝗦𝗧𝗨𝗩𝗪𝗫𝗬𝗭');
            WHEN 'italic' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '𝑎𝑏𝑐𝑑𝑒𝑓𝑔ℎ𝑖𝑗𝑘𝑙𝑚𝑛𝑜𝑝𝑞𝑟𝑠𝑡𝑢𝑣𝑤𝑥𝑦𝑧𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁');
            WHEN 'bold_italic' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '𝒂𝒃𝒄𝒅𝒆𝒇𝒈𝒉𝒊𝒋𝒌𝒍𝗺𝒏𝒐𝒑𝒒𝒓𝒔𝒕𝒖𝒗𝒘𝒙𝒚𝒛𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁');
            WHEN 'underlined' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'a̲b̲c̲d̲e̲f̲g̲h̲i̲j̲k̲l̲m̲n̲o̲p̲q̲r̲s̲t̲u̲v̲w̲x̲y̲z̲A̲B̲C̲D̲E̲F̲G̲H̲I̲J̲K̲L̲M̲N̲O̲P̲Q̲R̲S̲T̲U̲V̲W̲X̲Y̲Z̲');
            WHEN 'strikethrough' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'a̶b̶c̶d̶e̶f̶g̶h̶i̶j̶k̶l̶m̶n̶o̶p̶q̶r̶s̶t̶u̶v̶w̶x̶y̶z̶A̶B̶C̶D̶E̶F̶G̶H_I_J_K_L_M_N_O_P_Q_R_S_T_U_V_W_X_Y_Z_');
            WHEN 'superscript' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 'ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖᵠʳˢᵗᵘᵛʷˣʸᶻᴬᴮᶜᴰᴱᶠᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᵠᴿˢᵀᵁⱽᵂˣʸᶻ⁰¹²³⁴⁵⁶⁷⁸⁹');
            WHEN 'subscript' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 'ₐₑᵢₒᵤᵢₑᵢₒᵤₖₗₘₙₒₚₓᵩᵣₛₜᵤᵥₓₜₜₘₙₓₓₓ₀₁₂₃₄₅₆₇₈₉');
            WHEN 'bubble' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 'ⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩⒶⒷⒸⒹⒺⒻⒼⒽⒾⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏ⓪①②③④⑤⑥⑦⑧⑨');
            WHEN 'inverted' THEN 
                v_processed := TRANSLATE(v_processed, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'ɐqɔpǝɟƃɥᴉɾʞןɯuodbɹsʇnʌʍxʎz∀ԐↃpƎℲ⅁HIſ⋊⅃WNOԀΌɹS⊥∩ΛMX⅄Z');
            ELSE 
                RAISE EXCEPTION 'Tipografía no soportada: %', p_typography;
        END CASE;
    END IF;

    -- 4. Bloque Completo de Estilos ANSI
    IF v_is_psql THEN
        -- Colores
        v_color_code := CASE lower(p_color)
            WHEN 'black'   THEN E'\033[30m' WHEN 'red'     THEN E'\033[31m'
            WHEN 'green'   THEN E'\033[32m' WHEN 'yellow'  THEN E'\033[33m'
            WHEN 'blue'    THEN E'\033[34m' WHEN 'magenta' THEN E'\033[35m'
            WHEN 'cyan'    THEN E'\033[36m' WHEN 'white'   THEN E'\033[37m'
            ELSE '' END;
        -- Estilos ANSI
        v_style_code := CASE lower(p_style)
            WHEN 'bold'      THEN E'\033[1m' WHEN 'dim'       THEN E'\033[2m'
            WHEN 'italic'    THEN E'\033[3m' WHEN 'underline' THEN E'\033[4m'
            WHEN 'blink'     THEN E'\033[5m' WHEN 'reverse'   THEN E'\033[7m'
            WHEN 'hidden'    THEN E'\033[8m'
            ELSE '' END;
            
        IF v_color_code = '' AND v_style_code = '' THEN v_reset_code := ''; END IF;
        v_final_text := v_style_code || v_color_code || v_prefix || v_processed || v_reset_code;
    ELSE
        v_final_text := v_prefix || v_processed;
    END IF;

 
    ---------------------------------------------------------
    -- 5. Escritura en archivo (Uso de COPY PROGRAM)
    ---------------------------------------------------------
    IF p_log_path IS NOT NULL THEN
        BEGIN
            -- Preparar la línea de log (escapando comillas simples para el shell)
            v_log_line := to_char(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || '| '  || replace(p_text, '''', '''''');
            
            -- Construir comando: echo "mensaje" >> /ruta/al/archivo
            -- Se usa format para manejar identificadores y literales de forma segura
            v_shell_cmd := format($cmd$echo %L >> %I$cmd$, v_log_line, p_log_path);

            -- Ejecutar vía COPY (técnica para ejecutar comandos de sistema)
            -- Nota: Se redirige a una tabla temporal nula para que no retorne nada
            EXECUTE format('COPY (SELECT 1) TO PROGRAM %L', v_shell_cmd);

        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS ex_message = MESSAGE_TEXT;
            RAISE WARNING 'Fallo al escribir en archivo via COPY PROGRAM: %', ex_message;
        END;
    END IF;

    -- 6. Auditoría y Retorno
    EXECUTE v_log_query USING v_start_time, v_status, p_text;

    IF p_is_return THEN
        RAISE NOTICE '%', v_final_text;
        RETURN NULL;
    ELSE
        RETURN v_final_text;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS ex_message = MESSAGE_TEXT, ex_context = PG_EXCEPTION_CONTEXT;
        v_status := 'failed';
        EXECUTE v_log_query USING v_start_time, v_status, ex_message;
        RAISE EXCEPTION 'Error critico en pg_logify: %', ex_message;
END;
$func$; 





REVOKE ALL ON FUNCTION  systools.pg_logify(TEXT, TEXT, TEXT, BOOLEAN, TEXT, BOOLEAN, TEXT, TEXT) FROM PUBLIC;
-- GRANT EXECUTE ON FUNCTION  systools.pg_logify(TEXT, TEXT, TEXT, BOOLEAN, TEXT, BOOLEAN, TEXT, TEXT) TO dba_role;

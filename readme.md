
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

### 1. Formato de Color y Estilo

Perfecto para resaltar alertas o estados en scripts de mantenimiento.

```sql
SELECT pg_logify('PROCESO FINALIZADO', 'green', 'bold');

```

### 2. Transformación de Tipografía

Haz que tus mensajes destaquen con estilos únicos:

```sql
-- Texto en burbujas
SELECT pg_logify('Hola Mundo', typography => 'bubble'); 
-- Resultado: ⓗⓞⓛⓐ ⓜⓤⓝⓓⓞ

-- Texto invertido
SELECT pg_logify('Alerta de Seguridad', typography => 'inverted'); 
-- Resultado: ɐןǝɹʇɐ pǝ sǝƃnuᴉpɐp

```

### 3. Registro en Archivo (Logging)

Registra eventos directamente en un archivo del servidor:

```sql
SELECT pg_logify(
    'Error en ETL', 
    'red', 
    log_to_file => '/var/log/postgres/etl_errors.log',
    include_timestamp => true
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

---



### **¿Qué puedes hacer con pg_logify? (Casos de uso)**

* **Dashboards en Terminal:** Crear reportes visuales con semáforos de colores (verde, amarillo, rojo) para ver el estado de salud de la DB de un vistazo.
* **Auditoría Forense:** Registrar quién, cuándo y desde qué aplicación se ejecutó un proceso, guardándolo en una tabla de logs imposible de borrar por el usuario.
* **Monitoreo de ETLs:** Rastrear cargas de datos masivas en tiempo real, usando barras de colores para identificar en qué lote ocurrió un error.
* **Debug de Scripts Complejos:** Reemplazar el `RAISE NOTICE` aburrido por mensajes con tipografías especiales (negritas, cursivas, burbujas) para diferenciar variables de sistema.
* **Caja Negra de Funciones:** Grabar automáticamente el inicio y fin de funciones críticas en archivos externos del servidor para depuración posterior.
* **UX para DBAs:** Crear menús e interfaces interactivas en `psql` más elegantes y legibles mediante estilos de texto (subrayados, invertidos, parpadeos).
* **Alertas Visuales:** Hacer que los errores críticos "parpadeen" en la consola para que el administrador los detecte inmediatamente.

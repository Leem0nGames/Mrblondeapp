# Guía de Configuración y Uso

Este documento contiene las instrucciones para configurar y poner en marcha la aplicación.

## 1. Configuración de la Base de Datos

El paso más importante es configurar la base de datos para que coincida con la aplicación.

### a. Ejecutar el Script de Esquema

El script SQL en `src/lib/supabase/schema.sql` está diseñado para ser **idempotente**, lo que significa que puedes ejecutarlo de forma segura en cualquier momento, ya sea en una base de datos nueva o en una existente. Se encargará de limpiar y reconfigurar las tablas automáticamente.

1.  **Abre el archivo `src/lib/supabase/schema.sql`** en este proyecto.
2.  **Copia todo el contenido** de ese archivo.
3.  **Ve al "SQL Editor"** en tu panel de Supabase.
4.  **Pega el script** en el editor y haz clic en **"RUN"**.

### b. (Opcional) Cargar Datos de Ejemplo

Si quieres empezar con productos, precios y promociones de ejemplo, puedes ejecutar el script de "seed".

1.  **Abre el archivo `src/lib/supabase/seed.sql`**.
2.  **Copia todo el contenido**.
3.  **Pega el script** en el SQL Editor de Supabase y haz clic en **"RUN"**.

## 2. Crear el Usuario Administrador

La aplicación te guiará para crear el primer usuario administrador la primera vez que la ejecutes. Después de configurar la base de datos y las variables de entorno, simplemente inicia la aplicación.

1.  **Inicia la aplicación** (ej. `npm run dev`).
2.  Serás redirigido a `/signup`.
3.  **Crea la cuenta** con tu email y una contraseña segura.
4.  Una vez creada, serás redirigido a `/login`, donde podrás iniciar sesión.

Con esto, tu aplicación estará lista para usarse.

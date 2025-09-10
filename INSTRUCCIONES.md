# Guía de Configuración y Uso

Este documento contiene las instrucciones para configurar y poner en marcha la aplicación.

## 1. Configuración de la Base de Datos

El paso más importante es configurar la base de datos para que coincida con la aplicación.

### Cómo borrar las tablas existentes:

Si necesitas empezar de cero, sigue estos pasos para borrar las tablas desde la interfaz de Supabase:

1.  **Ir al Editor de Tablas**: En el panel de tu proyecto de Supabase, ve a la sección "Table Editor" (el ícono de una tabla en el menú lateral).
2.  **Borrar cada tabla**:
    *   Haz clic en una tabla (ej. `agreement_products`).
    *   Haz clic en el menú de tres puntos junto al nombre de la tabla y selecciona **"Delete table"**.
    *   Confirma escribiendo el nombre de la tabla.
3.  **Repite el proceso** para todas las tablas de la aplicación. El orden importa debido a las relaciones. Empieza por:
    *   `agreement_products`
    *   `agreement_promotions`
    *   `access_tokens`
    *   Y finalmente `agreements`, `products`, y `promotions`.

### Ejecutar el Script SQL

Una vez que la base de datos esté limpia:
1.  Copia todo el contenido del archivo `database.sql` de este proyecto.
2.  Ve a la sección **"SQL Editor"** en tu panel de Supabase.
3.  Pega el contenido en la ventana de consulta y haz clic en **"RUN"**.

## 2. Crear el Usuario Administrador

La aplicación necesita un usuario administrador para funcionar.

1.  **Ir a Autenticación**: En el panel de Supabase, ve a la sección **"Authentication"**.
2.  **Añadir Nuevo Usuario**: Haz clic en el botón **"Add user"**.
3.  **Rellenar los datos**:
    *   **Email**: `admin@blonde.com`
    *   **Password**: `admin1234`
    *   **Importante**: Desactiva la opción "Send confirmation email".
4.  Haz clic en **"Create user"**.

Con esto, tu aplicación estará lista para usarse. Puedes acceder al panel de administrador con el PIN configurado (`1234` por defecto).

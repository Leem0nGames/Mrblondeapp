# Guía de Configuración y Uso

Este documento contiene las instrucciones para configurar y poner en marcha la aplicación.

## 1. Configuración de la Base de Datos

El paso más importante es configurar la base de datos para que coincida con la aplicación.

### Cómo borrar las tablas existentes:

Si necesitas empezar de cero, sigue estos pasos para borrar las tablas desde la interfaz de Supabase:

1.  **Ir al Editor de Tablas**: En el panel de tu proyecto de Supabase, ve a la sección "Table Editor" (el ícono de una tabla en el menú lateral).
2.  **Borrar cada tabla**:
    *   En la lista de tablas de la izquierda, pasa el ratón sobre una tabla (ej. `agreement_products`).
    *   Haz clic en el menú de **tres puntos (`...`)** que aparece a la derecha del nombre.
    *   Selecciona la opción **"Delete table"**.
    *   Confirma la acción escribiendo el nombre de la tabla cuando se te pida.
3.  **Repite el proceso** para todas las tablas de la aplicación. Es posible que necesites seguir un orden específico debido a las relaciones entre ellas. Si recibes un error, prueba a borrar en este orden:
    *   Primero: `agreement_products`, `agreement_promotions`, `access_tokens`.
    *   Después: `agreements`, `products`, y `promotions`.

### Ejecutar el Script SQL

Una vez que la base de datos esté limpia (sin tablas):
1.  Copia todo el contenido del archivo `database.sql` de este proyecto.
2.  Ve a la sección **"SQL Editor"** en tu panel de Supabase (el ícono que parece una página con `SQL`).
3.  Pega el contenido en la ventana de consulta y haz clic en el botón verde **"RUN"**.

**Nota sobre cambios**: Si se realiza un cambio en la estructura de la base de datos (como añadir una restricción `UNIQUE` a la columna `token`), la forma más segura de aplicarlo es borrar las tablas y volver a ejecutar el script SQL actualizado.

## 2. Crear el Usuario Administrador

La aplicación necesita un usuario administrador para funcionar.

1.  **Ir a Autenticación**: En el panel de Supabase, ve a la sección **"Authentication"** (el ícono de una persona).
2.  **Añadir Nuevo Usuario**: Haz clic en el botón **"Add user"**.
3.  **Rellenar los datos**:
    *   **Email**: `admin@blonde.com`
    *   **Password**: `admin1234`
    *   **Importante**: Desactiva la opción "Send confirmation email".
4.  Haz clic en **"Create user"**.

Con esto, tu aplicación estará lista para usarse. Puedes acceder al panel de administrador con el PIN por defecto: `1234`.

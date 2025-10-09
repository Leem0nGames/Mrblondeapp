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
    *   Primero: `agreement_products`, `agreement_promotions`.
    *   Después: `clients`, `agreements`, `products`, y `promotions`.

### Ejecutar el Script SQL

Una vez que la base de datos esté limpia (sin tablas), ejecuta el script que se encuentra en `src/lib/supabase/schema.sql`.

1.  **Abre el archivo `src/lib/supabase/schema.sql`** en este proyecto.
2.  **Copia todo el contenido** de ese archivo.
3.  **Ve al "SQL Editor"** en tu panel de Supabase.
4.  **Pega el script** en el editor y haz clic en **"RUN"**.

Con esto, tu base de datos estará completamente configurada y lista para funcionar con la aplicación.

## 2. Crear el Usuario Administrador (Opcional)

La aplicación ahora te guiará para crear el primer usuario administrador la primera vez que la ejecutes. Sin embargo, si necesitas crear un usuario manually, puedes seguir estos pasos:

1.  **Ir a Autenticación**: En el panel de Supabase, ve a la sección **"Authentication"** (el ícono de una persona).
2.  **Añadir Nuevo Usuario**: Haz clic en el botón **"Add user"**.
3.  **Rellenar los datos**:
    *   **Email**: Introduce el email que quieras para el administrador.
    *   **Password**: Introduce una contraseña segura.
    *   **Importante**: Desactiva la opción "Send confirmation email".
4.  Haz clic en **"Create user"**.

Con esto, tu aplicación estará lista para usarse.

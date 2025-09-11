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
    *   Después: `agreements`, `products`, y `promotions`.
    *   También borra la `VIEW` llamada `agreements_with_counts` si existe.

### Ejecutar el Script SQL

Una vez que la base de datos esté limpia (sin tablas), ejecuta el siguiente script en el **"SQL Editor"** de Supabase.

```sql
-- Tabla de Productos
CREATE TABLE products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  base_price DECIMAL(10, 2) NOT NULL,
  stock INTEGER DEFAULT 0,
  category TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla de Promociones Generales
CREATE TABLE promotions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  rules JSONB NOT NULL, -- e.g., {"type": "buy_x_get_y_free", "buy": 8, "get": 2}
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla de Convenios
CREATE TABLE agreements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agreement_name TEXT NOT NULL UNIQUE,
  client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla de muchos a muchos: Productos en Convenios (con precio específico)
CREATE TABLE agreement_products (
  agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  price DECIMAL(10, 2) NOT NULL,
  PRIMARY KEY (agreement_id, product_id)
);

-- Tabla de muchos a muchos: Promociones en Convenios
CREATE TABLE agreement_promotions (
  agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
  promotion_id UUID REFERENCES promotions(id) ON DELETE CASCADE,
  PRIMARY KEY (agreement_id, promotion_id)
);

-- Vista para contar productos y promociones por convenio de forma eficiente
CREATE OR REPLACE VIEW agreements_with_counts AS
SELECT
  a.id,
  a.agreement_name,
  a.client_type,
  a.created_at,
  (SELECT COUNT(*) FROM agreement_products ap WHERE ap.agreement_id = a.id) AS product_count,
  (SELECT COUNT(*) FROM agreement_promotions apromo WHERE apromo.agreement_id = a.id) AS promotion_count
FROM
  agreements a;

-- Habilitar Row Level Security (RLS) en todas las tablas
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;

-- Políticas de Acceso
-- 1. Permitir acceso público de lectura a productos.
CREATE POLICY "Allow public read access to products" ON products FOR SELECT USING (true);

-- 2. Permitir acceso de lectura a convenios, productos y promociones asociados a un convenio específico (para la página de pedido)
--    Esto se controla en el backend, por lo que no es estrictamente necesaria una policy de lectura pública aquí si las consultas son desde el servidor.
--    No obstante, añadimos políticas para permitir la lectura desde el cliente si fuera necesario en el futuro.
CREATE POLICY "Allow public read access to agreements" ON agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreement_products" ON agreement_products FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreement_promotions" ON agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to promotions" ON promotions FOR SELECT USING (true);


-- 3. Permitir a los usuarios autenticados (admins) gestionar toda la información
CREATE POLICY "Allow full access to authenticated users" ON products FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON promotions FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON agreements FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON agreement_products FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON agreement_promotions FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

```

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

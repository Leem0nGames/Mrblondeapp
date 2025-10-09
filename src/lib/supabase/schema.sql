-- ### SETUP:
-- 1. Borrar todas las tablas existentes desde la UI de Supabase para evitar conflictos.
-- 2. Pegar y ejecutar este script completo en el SQL Editor de Supabase.

-- --- EXTENSIONS & TYPES ---

-- Habilitar la extensión para manejar UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --- TABLES ---

-- Tabla de Productos (Catálogo General)
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  base_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  category TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de Listas de Precios (Contenedor de precios específicos)
CREATE TABLE IF NOT EXISTS price_lists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de Items de Listas de Precios (Relaciona productos con precios)
CREATE TABLE IF NOT EXISTS price_list_items (
    price_list_id UUID REFERENCES price_lists(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL,
    volume_price NUMERIC(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);


-- Tabla de Convenios (Agrupa clientes, precios y promociones)
CREATE TABLE IF NOT EXISTS agreements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agreement_name TEXT NOT NULL UNIQUE,
  client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
  price_list_id UUID REFERENCES price_lists(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tipo ENUM para el estado del cliente
CREATE TYPE client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');

-- Tabla de Clientes
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token UUID NOT NULL DEFAULT uuid_generate_v4(),
    agreement_id UUID REFERENCES agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- Tabla de Promociones
CREATE TABLE IF NOT EXISTS promotions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  rules JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla Pivot: Convenios y Promociones
CREATE TABLE IF NOT EXISTS agreement_promotions (
  agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
  promotion_id UUID REFERENCES promotions(id) ON DELETE CASCADE,
  PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Pedidos
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
  agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  total_amount NUMERIC(10, 2) NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'completed')),
  client_name_cache TEXT NOT NULL
);

-- Tabla de Items de Pedido
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);

-- --- VIEWS ---

-- Vista para contar promociones por convenio
CREATE OR REPLACE VIEW agreements_with_counts AS
SELECT 
    a.*, 
    (SELECT COUNT(*) FROM agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT row_to_json(pl) FROM price_lists pl WHERE pl.id = a.price_list_id) as price_lists
FROM 
    agreements a;


-- --- DASHBOARD TABLES ---
-- Tablas pre-agregadas para simplificar las consultas del dashboard.
-- En una aplicación real, se actualizarían con Triggers o Cron Jobs.

CREATE TABLE IF NOT EXISTS dashboard_stats (
    id INT PRIMARY KEY,
    total_revenue NUMERIC(12, 2) DEFAULT 0,
    month_revenue NUMERIC(12, 2) DEFAULT 0,
    active_clients INT DEFAULT 0
);

-- Insertar una fila inicial si no existe
INSERT INTO dashboard_stats (id)
SELECT 1
WHERE NOT EXISTS (SELECT 1 FROM dashboard_stats WHERE id = 1);


-- --- ROW LEVEL SECURITY (RLS) ---

-- Habilitar RLS en todas las tablas
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Limpiar políticas antiguas
DROP POLICY IF EXISTS "Public can read products" ON products;
DROP POLICY IF EXISTS "Admins can do everything on products" ON products;
DROP POLICY IF EXISTS "Public can read price lists" ON price_lists;
DROP POLICY IF EXISTS "Admins can do everything on price lists" ON price_lists;
DROP POLICY IF EXISTS "Public can read price list items" ON price_list_items;
DROP POLICY IF EXISTS "Admins can do everything on price list items" ON price_list_items;
DROP POLICY IF EXISTS "Public can read agreements" ON agreements;
DROP POLICY IF EXISTS "Admins can do everything on agreements" ON agreements;
DROP POLICY IF EXISTS "Admins can do everything on clients" ON clients;
DROP POLICY IF EXISTS "Public can read promotions" ON promotions;
DROP POLICY IF EXISTS "Admins can do everything on promotions" ON promotions;
DROP POLICY IF EXISTS "Public can read agreement_promotions" ON agreement_promotions;
DROP POLICY IF EXISTS "Admins can do everything on agreement_promotions" ON agreement_promotions;
DROP POLICY IF EXISTS "Admins can do everything on orders" ON orders;
DROP POLICY IF EXISTS "Admins can do everything on order_items" ON order_items;


-- --- Políticas para ROL: authenticated (Cualquier usuario logueado en el Admin Panel) ---

-- POLÍTICAS: Los admins autenticados pueden realizar cualquier acción en estas tablas.
CREATE POLICY "Admins can do everything on products" ON products
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can do everything on price lists" ON price_lists
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can do everything on price list items" ON price_list_items
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  
CREATE POLICY "Admins can do everything on agreements" ON agreements
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  
CREATE POLICY "Admins can do everything on clients" ON clients
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can do everything on promotions" ON promotions
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  
CREATE POLICY "Admins can do everything on agreement_promotions" ON agreement_promotions
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  
CREATE POLICY "Admins can do everything on orders" ON orders
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
  
CREATE POLICY "Admins can do everything on order_items" ON order_items
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- --- Políticas para ROL: anon (Usuarios no logueados, ej: Clientes con link de pedido) ---

-- POLÍTICAS: Los usuarios anónimos (clientes) pueden leer la información necesaria para la página de pedido.
-- No pueden modificar nada, solo leer lo que el link de convenio les permite.
CREATE POLICY "Anon users can read agreements, products, and promotions" ON agreements
  FOR SELECT USING (true);

CREATE POLICY "Anon users can read products" ON products
  FOR SELECT USING (true);
  
CREATE POLICY "Anon users can read promotions" ON promotions
  FOR SELECT USING (true);

CREATE POLICY "Anon users can read agreement_promotions" ON agreement_promotions
  FOR SELECT USING (true);
  
CREATE POLICY "Anon users can read price lists" ON price_lists
  FOR SELECT USING (true);

CREATE POLICY "Anon users can read price list items" ON price_list_items
  FOR SELECT USING (true);

-- POLÍTICA DE ONBOARDING: Cualquier usuario (anon) puede actualizar su propia fila de cliente
-- si conoce el `onboarding_token` secreto.
CREATE POLICY "Anon users can update their own client record via onboarding token" ON clients
    FOR UPDATE USING (
        (SELECT onboarding_token FROM clients WHERE id = clients.id) = current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token'
    );
-- También pueden leer su propia fila
CREATE POLICY "Anon users can read their own client record" ON clients
    FOR SELECT USING (
         (SELECT onboarding_token FROM clients WHERE id = clients.id) = current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token'
    );
    
-- POLÍTICA DE PEDIDOS: Cualquier usuario (anon) puede crear un pedido
CREATE POLICY "Anon can create orders" ON orders
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Anon can create order_items" ON order_items
    FOR INSERT WITH CHECK (true);

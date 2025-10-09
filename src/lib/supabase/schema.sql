-- 1. Tabla de Productos
-- Almacena el catálogo de productos base.
CREATE TABLE products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  base_price DECIMAL(10, 2) NOT NULL,
  stock INTEGER DEFAULT 0,
  category TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Tabla de Promociones Generales
-- Define las reglas de las promociones que pueden ser asignadas a convenios.
CREATE TABLE promotions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  rules JSONB NOT NULL, -- e.g., {"type": "buy_x_get_y_free", "buy": 8, "get": 2}
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Tabla de Convenios
-- Agrupa reglas de precios y promociones para diferentes tipos de clientes.
CREATE TABLE agreements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agreement_name TEXT NOT NULL UNIQUE,
  client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Tabla de Clientes
-- Almacena la información de los clientes onboardeados.
CREATE TABLE clients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status TEXT NOT NULL DEFAULT 'pending_onboarding' CHECK (status IN ('pending_onboarding', 'pending_agreement', 'active')),
    onboarding_token UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id UUID REFERENCES agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Tabla de muchos a muchos: Productos en Convenios
-- Asigna productos a un convenio con un precio específico.
CREATE TABLE agreement_products (
  agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  price DECIMAL(10, 2) NOT NULL,
  PRIMARY KEY (agreement_id, product_id)
);

-- 6. Tabla de muchos a muchos: Promociones en Convenios
-- Asigna promociones a un convenio.
CREATE TABLE agreement_promotions (
  agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
  promotion_id UUID REFERENCES promotions(id) ON DELETE CASCADE,
  PRIMARY KEY (agreement_id, promotion_id)
);

-- Habilitar Row Level Security (RLS) en todas las tablas
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;

-- Políticas de Acceso

-- 1. Políticas públicas (lectura anónima)
-- Permiten que CUALQUIERA (anónimo) lea la información necesaria para
-- las páginas públicas, como el formulario de pedido y el de onboarding.
CREATE POLICY "Allow public read access" ON products FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON agreement_products FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read for onboarding" ON clients FOR SELECT USING (true);


-- 2. Políticas para usuarios autenticados (admins)
-- Permite control total (Crear, Leer, Actualizar, Borrar) a los administradores logueados.
CREATE POLICY "Allow full access to authenticated users" ON products FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON promotions FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON agreements FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON agreement_products FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON agreement_promotions FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow full access to authenticated users" ON clients FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- 3. Políticas específicas para clientes (onboarding)
-- Permite a un cliente (sin estar logueado) actualizar SUS PROPIOS datos 
-- durante el proceso de onboarding, pero solo si conoce su token secreto.
-- Esta es una política crucial para la seguridad, ya que no permite que un
-- cliente modifique los datos de otro.
-- NOTA: Esta política es solo para UPDATE. El cliente no puede crear ni borrar.
CREATE POLICY "Allow client to update their own data during onboarding" ON clients
FOR UPDATE USING (onboarding_token::text = (current_setting('request.jwt.claims', true)::json->>'onboarding_token'))
WITH CHECK (onboarding_token::text = (current_setting('request.jwt.claims', true)::json->>'onboarding_token'));

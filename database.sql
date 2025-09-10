
-- Tabla de Productos
CREATE TABLE products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    base_price numeric(10, 2) NOT NULL CHECK (base_price >= 0),
    stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla de Promociones
CREATE TABLE promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla de Convenios
CREATE TABLE agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL,
    client_type text NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    price_adjustment numeric(5, 2) DEFAULT 0,
    link_token uuid NOT NULL UNIQUE,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabla de Unión: Convenios y Productos (con precio específico)
CREATE TABLE agreement_products (
    agreement_id uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (agreement_id, product_id)
);

-- Tabla de Unión: Convenios y Promociones
CREATE TABLE agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;

-- Políticas de Acceso
-- Permitir lectura pública de productos y convenios (necesario para la página de pedido)
CREATE POLICY "Public read access for products" ON products FOR SELECT USING (true);
CREATE POLICY "Public read access for agreements" ON agreements FOR SELECT USING (true);
CREATE POLICY "Public read access for agreement_products" ON agreement_products FOR SELECT USING (true);
CREATE POLICY "Public read access for agreement_promotions" ON agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Public read access for promotions" ON promotions FOR SELECT USING (true);


-- Permitir acceso completo a los administradores autenticados
CREATE POLICY "Admin full access" ON products FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admin full access" ON promotions FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admin full access" on agreements FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admin full access" on agreement_products FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admin full access" on agreement_promotions FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

    
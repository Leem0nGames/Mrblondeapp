
-- Habilitar la extensión pgcrypto si aún no está habilitada
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "public";

-- Tabla de Productos
CREATE TABLE products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying(255) NOT NULL,
    description text,
    base_price numeric(10, 2) NOT NULL,
    stock integer NOT NULL DEFAULT 0,
    category character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Promociones
CREATE TABLE promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying(255) NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name character varying(255) NOT NULL,
    client_type character varying(50) NOT NULL,
    price_adjustment numeric(5, 2) DEFAULT 0 NOT NULL,
    link_token uuid NOT NULL UNIQUE,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Asociación: Convenios y Productos (con precios personalizados)
CREATE TABLE agreement_products (
    agreement_id uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    PRIMARY KEY (agreement_id, product_id)
);

-- Tabla de Asociación: Convenios y Promociones
CREATE TABLE agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Políticas de Seguridad de Acceso a Nivel de Fila (RLS)
-- Asegúrate de que RLS esté habilitado para cada tabla en la interfaz de Supabase.

-- Para products: Habilitar RLS y permitir lectura a todos.
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access for products" ON products FOR SELECT USING (true);
CREATE POLICY "Allow admins to manage products" ON products FOR ALL USING (auth.role() = 'service_role');


-- Para promotions: Habilitar RLS y permitir lectura a todos.
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access for promotions" ON promotions FOR SELECT USING (true);
CREATE POLICY "Allow admins to manage promotions" ON promotions FOR ALL USING (auth.role() = 'service_role');


-- Para agreements: Habilitar RLS y permitir lectura a todos (necesario para la página de pedido).
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access for agreements" ON agreements FOR SELECT USING (true);
CREATE POLICY "Allow admins to manage agreements" ON agreements FOR ALL USING (auth.role() = 'service_role');


-- Para agreement_products: Habilitar RLS y permitir lectura a todos.
ALTER TABLE agreement_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access for agreement_products" ON agreement_products FOR SELECT USING (true);
CREATE POLICY "Allow admins to manage agreement_products" ON agreement_products FOR ALL USING (auth.role() = 'service_role');


-- Para agreement_promotions: Habilitar RLS y permitir lectura a todos.
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access for agreement_promotions" ON agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow admins to manage agreement_promotions" ON agreement_promotions FOR ALL USING (auth.role() = 'service_role');


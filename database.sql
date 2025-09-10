
-- Habilitar la extensión pgcrypto si no está habilitada (para gen_random_uuid())
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enum para el tipo de cliente
CREATE TYPE client_type AS ENUM ('barberia', 'distribuidor', 'especial');

-- Tabla de Productos
CREATE TABLE products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    base_price numeric(10, 2) NOT NULL DEFAULT 0.00,
    stock integer NOT NULL DEFAULT 0,
    category text,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Promociones
CREATE TABLE promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL,
    client_type client_type NOT NULL,
    price_adjustment numeric(5, 2) NOT NULL DEFAULT 0.00,
    link_token uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT agreements_link_token_key UNIQUE (link_token)
);

-- Tabla de Unión: Productos en Convenio
CREATE TABLE agreement_products (
    agreement_id uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    PRIMARY KEY (agreement_id, product_id)
);

-- Tabla de Unión: Promociones en Convenio
CREATE TABLE agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Habilitar Row Level Security (RLS) para todas las tablas
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS:
-- Los usuarios autenticados (admins) pueden gestionar todo.
CREATE POLICY "Allow full access to authenticated users" ON products
FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access to authenticated users" ON promotions
FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access to authenticated users" ON agreements
FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access to authenticated users" ON agreement_products
FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access to authenticated users" ON agreement_promotions
FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Los usuarios anónimos (clientes con link) pueden leer datos de convenios específicos.
-- Se asume que el acceso se valida en el backend mediante el link_token.
-- Por simplicidad, permitimos la lectura pública en tablas de solo lectura para el cliente.
CREATE POLICY "Allow public read access" ON products
FOR SELECT TO anon USING (true);

CREATE POLICY "Allow public read access" ON promotions
FOR SELECT TO anon USING (true);

CREATE POLICY "Allow public read access" ON agreements
FOR SELECT TO anon USING (true);

CREATE POLICY "Allow public read access" ON agreement_products
FOR SELECT TO anon USING (true);

CREATE POLICY "Allow public read access" ON agreement_promotions
FOR SELECT TO anon USING (true);

-- Users table (managed by Supabase Auth)
-- This is just a reference, do not run this. Supabase handles it.
-- create table auth.users ( ... );

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    base_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Clients table
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    city TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Promotions table
CREATE TABLE IF NOT EXISTS promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Agreements table
CREATE TABLE IF NOT EXISTS agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    price_adjustment NUMERIC(5, 2) NOT NULL DEFAULT 0, -- e.g., -10.5 for a 10.5% discount
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Agreement-Products join table (for custom pricing)
CREATE TABLE IF NOT EXISTS agreement_products (
    agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (agreement_id, product_id)
);

-- Agreement-Promotions join table
CREATE TABLE IF NOT EXISTS agreement_promotions (
    agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);


-- Access Tokens table
CREATE TABLE IF NOT EXISTS access_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    client_name TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Order Logs table
CREATE TABLE IF NOT EXISTS order_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_id UUID REFERENCES agreements(id),
    order_data JSONB,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- Enable RLS for all tables
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_logs ENABLE ROW LEVEL SECURITY;

-- Policies for authenticated users (admins) to manage data
DROP POLICY IF EXISTS "Allow full access to authenticated users" ON products;
CREATE POLICY "Allow full access to authenticated users" ON products
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow full access to authenticated users" ON clients;
CREATE POLICY "Allow full access to authenticated users" ON clients
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow full access to authenticated users" ON promotions;
CREATE POLICY "Allow full access to authenticated users" ON promotions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow full access to authenticated users" ON agreements;
CREATE POLICY "Allow full access to authenticated users" ON agreements
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow full access to authenticated users" ON agreement_products;
CREATE POLICY "Allow full access to authenticated users" ON agreement_products
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow full access to authenticated users" ON agreement_promotions;
CREATE POLICY "Allow full access to authenticated users" ON agreement_promotions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow full access to authenticated users" ON access_tokens;
CREATE POLICY "Allow full access to authenticated users" ON access_tokens
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow full access to authenticated users" ON order_logs;
CREATE POLICY "Allow full access to authenticated users" ON order_logs
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Policies for public access (for order pages)
-- Public can read products
DROP POLICY IF EXISTS "Allow public read access" ON products;
CREATE POLICY "Allow public read access" ON products
FOR SELECT USING (true);

-- Public can read specific access tokens
DROP POLICY IF EXISTS "Allow public read access" ON access_tokens;
CREATE POLICY "Allow public read access" ON access_tokens
FOR SELECT USING (true);

-- Public can read agreements via access tokens
DROP POLICY IF EXISTS "Allow public read access" ON agreements;
CREATE POLICY "Allow public read access" ON agreements
FOR SELECT USING (true);

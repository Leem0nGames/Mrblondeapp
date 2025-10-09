-- Drop existing policies if they exist, then recreate them.
-- This makes the script idempotent.

-- Create custom types if they don't exist
DO $$ BEGIN
    CREATE TYPE client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE client_type AS ENUM ('barberia', 'distribuidor', 'especial');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM ('pending', 'completed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;


-- Products Table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    base_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    stock INT NOT NULL DEFAULT 0,
    category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Price Lists Table
CREATE TABLE IF NOT EXISTS price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Price List Items (Junction Table)
CREATE TABLE IF NOT EXISTS price_list_items (
    price_list_id UUID NOT NULL,
    product_id UUID NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    volume_price NUMERIC(10, 2),
    PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT fk_price_list FOREIGN KEY (price_list_id) REFERENCES price_lists(id) ON DELETE CASCADE,
    CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Agreements Table
CREATE TABLE IF NOT EXISTS agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name TEXT NOT NULL UNIQUE,
    client_type client_type NOT NULL,
    price_list_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_price_list FOREIGN KEY (price_list_id) REFERENCES price_lists(id) ON DELETE SET NULL
);

-- Clients Table
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token UUID NOT NULL DEFAULT gen_random_uuid(),
    agreement_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_agreement FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE SET NULL
);


-- Promotions Table
CREATE TABLE IF NOT EXISTS promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Agreement-Promotions (Junction Table)
CREATE TABLE IF NOT EXISTS agreement_promotions (
    agreement_id UUID NOT NULL,
    promotion_id UUID NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT fk_agreement FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE CASCADE,
    CONSTRAINT fk_promotion FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE CASCADE
);

-- Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    agreement_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_amount NUMERIC(10, 2) NOT NULL,
    status order_status NOT NULL DEFAULT 'pending',
    client_name_cache TEXT, -- Denormalized for easy display
    CONSTRAINT fk_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_agreement FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE RESTRICT
);

-- Order Items Table
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity INT NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL,
    CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

-- Dashboard Stats Table (for pre-aggregated data)
CREATE TABLE IF NOT EXISTS dashboard_stats (
    id INT PRIMARY KEY, -- Only one row
    total_revenue NUMERIC(15, 2) DEFAULT 0.00,
    month_revenue NUMERIC(15, 2) DEFAULT 0.00,
    active_clients INT DEFAULT 0,
    CONSTRAINT single_row CHECK (id = 1)
);

-- Insert the single row for dashboard stats if it doesn't exist
INSERT INTO dashboard_stats (id) VALUES (1) ON CONFLICT (id) DO NOTHING;


-- Enable Row Level Security for all tables
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_stats ENABLE ROW LEVEL SECURITY;

-- Drop existing policies before creating new ones
DROP POLICY IF EXISTS "Allow all for authenticated users" ON products;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON price_lists;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON price_list_items;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON agreements;
DROP POLICY IF EXISTS "Allow client public read access" ON agreements;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON clients;
DROP POLICY IF EXISTS "Allow public read for onboarding" ON clients;
DROP POLICY IF EXISTS "Allow client to update their own data during onboarding" ON clients;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON agreement_promotions;
DROP POLICY IF EXISTS "Allow client public read access" ON agreement_promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON orders;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON order_items;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON dashboard_stats;

-- RLS Policies

-- Full access for authenticated admins on most tables
CREATE POLICY "Allow all for authenticated users" ON products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON dashboard_stats FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- Agreements: Admins have full access, any user can read (for order page)
CREATE POLICY "Allow all for authenticated users" ON agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow client public read access" ON agreements FOR SELECT USING (true);


-- Clients: Admins have full access.
CREATE POLICY "Allow all for authenticated users" ON clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
-- Allow public read for a client trying to onboard
CREATE POLICY "Allow public read for onboarding" ON clients FOR SELECT USING (onboarding_token::text = (SELECT nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'onboarding_token'));
-- Allow a client to update their own data during onboarding
CREATE POLICY "Allow client to update their own data during onboarding" ON clients FOR UPDATE USING (onboarding_token::text = (SELECT nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'onboarding_token'));


-- Agreement-Promotions: Admins have full access, any user can read (for order page)
CREATE POLICY "Allow all for authenticated users" ON agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow client public read access" ON agreement_promotions FOR SELECT USING (true);


-- Create a view for agreements with promotion counts
CREATE OR REPLACE VIEW agreements_with_counts AS
SELECT
    a.*,
    (SELECT count(*) FROM agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count
FROM
    agreements a;

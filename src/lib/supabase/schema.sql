
-- 1. Enum Types for status fields
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_status') THEN
        CREATE TYPE client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
        CREATE TYPE order_status AS ENUM ('pending', 'completed', 'cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'agreement_client_type') THEN
        CREATE TYPE agreement_client_type AS ENUM ('barberia', 'distribuidor', 'especial');
    END IF;
END
$$;

-- 2. Products Table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    base_price NUMERIC(10, 2) NOT NULL CHECK (base_price >= 0),
    stock INT NOT NULL CHECK (stock >= 0),
    category TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Price Lists Table
CREATE TABLE IF NOT EXISTS price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Price List Items Table (Junction table for Price Lists and Products)
CREATE TABLE IF NOT EXISTS price_list_items (
    price_list_id UUID REFERENCES price_lists(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    volume_price NUMERIC(10, 2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

-- 5. Agreements Table
CREATE TABLE IF NOT EXISTS agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name TEXT NOT NULL UNIQUE,
    client_type agreement_client_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    price_list_id UUID REFERENCES price_lists(id) ON DELETE SET NULL
);

-- 6. Clients Table
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
    onboarding_token TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid()::TEXT,
    agreement_id UUID REFERENCES agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Promotions Table
CREATE TABLE IF NOT EXISTS promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Agreement Promotions Junction Table
CREATE TABLE IF NOT EXISTS agreement_promotions (
    agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
    promotion_id UUID REFERENCES promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- 9. Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    agreement_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    total_amount NUMERIC(10, 2) NOT NULL,
    status order_status NOT NULL DEFAULT 'pending',
    client_name_cache TEXT,
    CONSTRAINT fk_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_agreement FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE RESTRICT
);

-- 10. Order Items Table
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE RESTRICT,
    quantity INT NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);

-- 11. Dashboard Stats Table (for simplified demo purposes)
CREATE TABLE IF NOT EXISTS dashboard_stats (
    id INT PRIMARY KEY,
    total_revenue NUMERIC(15, 2),
    month_revenue NUMERIC(15, 2),
    active_clients INT
);

-- Seed initial dashboard stats if not exists
INSERT INTO dashboard_stats (id, total_revenue, month_revenue, active_clients)
SELECT 1, 0, 0, 0
WHERE NOT EXISTS (SELECT 1 FROM dashboard_stats WHERE id = 1);

-- 12. Views for aggregated data
CREATE OR REPLACE VIEW agreements_with_counts AS
SELECT 
    a.*,
    (SELECT COUNT(*) FROM agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count
FROM agreements a;


-- Enable RLS for all tables
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


-- Create policies
-- Public access for specific scenarios (e.g., order page might not need auth)
-- For simplicity, we'll allow read on products and related things.
-- In a real app, you'd be more granular.

DROP POLICY IF EXISTS "Public can read products" ON products;
CREATE POLICY "Public can read products" ON products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can read pricelists" ON price_lists;
CREATE POLICY "Public can read pricelists" ON price_lists FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can read pricelist items" ON price_list_items;
CREATE POLICY "Public can read pricelist items" ON price_list_items FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can read agreements" ON agreements;
CREATE POLICY "Public can read agreements" ON agreements FOR SELECT USING (true);

DROPPOLICY IF EXISTS "Public can read promotions" ON promotions;
CREATE POLICY "Public can read promotions" ON promotions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can read agreement promotions" ON agreement_promotions;
CREATE POLICY "Public can read agreement promotions" ON agreement_promotions FOR SELECT USING (true);

-- Authenticated users (admins) can do anything.
-- This assumes your API access is already restricted to authenticated users.
DROP POLICY IF EXISTS "Admins can manage everything" ON products;
CREATE POLICY "Admins can manage everything" ON products FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage everything" ON price_lists;
CREATE POLICY "Admins can manage everything" ON price_lists FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage everything" ON price_list_items;
CREATE POLICY "Admins can manage everything" ON price_list_items FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage everything" ON agreements;
CREATE POLICY "Admins can manage everything" ON agreements FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage everything" ON promotions;
CREATE POLICY "Admins can manage everything" ON promotions FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() 'authenticated');

DROP POLICY IF EXISTS "Admins can manage everything" ON agreement_promotions;
CREATE POLICY "Admins can manage everything" ON agreement_promotions FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Clients are more complex.
-- Allow read for admins. Allow update for anyone during onboarding.
DROP POLICY IF EXISTS "Admins can read clients" ON clients;
CREATE POLICY "Admins can read clients" ON clients FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Anyone can update their own client record during onboarding" ON clients;
CREATE POLICY "Anyone can update their own client record during onboarding" ON clients FOR UPDATE
USING (onboarding_token IS NOT NULL)
WITH CHECK (onboarding_token IS NOT NULL);

DROP POLICY IF EXISTS "Admins can insert clients" ON clients;
CREATE POLICY "Admins can insert clients" ON clients FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can archive clients" ON clients;
CREATE POLICY "Admins can archive clients" ON clients FOR UPDATE
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Orders and Order Items
-- Allow insert for anyone (as it's done from public page)
DROP POLICY IF EXISTS "Anyone can create orders" ON orders;
CREATE POLICY "Anyone can create orders" ON orders FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can create order items" ON order_items;
CREATE POLICY "Anyone can create order items" ON order_items FOR INSERT WITH CHECK (true);

-- Allow read/update for admins
DROP POLICY IF EXISTS "Admins can manage orders" ON orders;
CREATE POLICY "Admins can manage orders" ON orders FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can read order items" ON order_items;
CREATE POLICY "Admins can read order items" ON order_items FOR SELECT
USING (auth.role() = 'authenticated');

-- Dashboard Stats
DROP POLICY IF EXISTS "Admins can read dashboard stats" ON dashboard_stats;
CREATE POLICY "Admins can read dashboard stats" ON dashboard_stats FOR SELECT
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can update dashboard stats" ON dashboard_stats;
CREATE POLICY "Admins can update dashboard stats" ON dashboard_stats FOR UPDATE
USING (auth.role() = 'authenticated');


-- Users table - handled by Supabase Auth
-- Products table
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  base_price NUMERIC(10, 2) NOT NULL CHECK (base_price >= 0),
  stock INTEGER NOT NULL CHECK (stock >= 0),
  category TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Agreements table
CREATE TABLE agreements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  client_type TEXT NOT NULL, -- 'barberia', 'distribuidor', 'especial'
  price_adjustment NUMERIC(5, 2) NOT NULL DEFAULT 0, -- e.g., -10.5 for 10.5% discount
  promo_override JSONB, -- Can hold specific promo rules like { "threshold": 10, "bonus": 1 }
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Access Tokens table
CREATE TABLE access_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id UUID NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
  client_name TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Order Logs table
CREATE TABLE order_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  access_token_id UUID REFERENCES access_tokens(id),
  order_data JSONB,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- Enable RLS for all tables
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_logs ENABLE ROW LEVEL SECURITY;


-- Allow public read access to products
DROP POLICY IF EXISTS "Public can read products" ON products;
CREATE POLICY "Public can read products" ON products FOR SELECT
USING (true);

-- Allow public read access to access_tokens and related agreements
DROP POLICY IF EXISTS "Public can read access_tokens and agreements" ON access_tokens;
CREATE POLICY "Public can read access_tokens and agreements" ON access_tokens FOR SELECT
USING (true);

-- Allow admin users (authenticated role) to manage everything
DROP POLICY IF EXISTS "Admins can manage products" ON products;
CREATE POLICY "Admins can manage products" ON products FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage agreements" ON agreements;
CREATE POLICY "Admins can manage agreements" ON agreements FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage access_tokens" ON access_tokens;
CREATE POLICY "Admins can manage access_tokens" ON access_tokens FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage order_logs" ON order_logs;
CREATE POLICY "Admins can manage order_logs" ON order_logs FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');


-- Create Products Table
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  base_price REAL NOT NULL,
  stock INTEGER NOT NULL,
  category TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create Client Prices Table
CREATE TABLE client_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor')),
  price REAL NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create Promotions Table
CREATE TABLE promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor')),
  name TEXT NOT NULL,
  description TEXT,
  threshold INTEGER NOT NULL,
  bonus INTEGER NOT NULL,
  is_global BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create Agreements Table
CREATE TABLE agreements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_name TEXT NOT NULL,
  client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor')),
  price_adjustment REAL,
  promo_override JSONB,
  token TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create Order Logs Table
CREATE TABLE order_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id UUID REFERENCES agreements(id) ON DELETE SET NULL,
  order_data JSONB,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

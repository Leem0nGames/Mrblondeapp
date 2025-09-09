-- Enable RLS for all tables
-- Make sure to set up policies in the Supabase dashboard for security.
-- Default policy should be to deny all access, then create specific policies for admin roles and public access.

-- Table for Products
CREATE TABLE products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  base_price DECIMAL(10,2) NOT NULL,
  stock INTEGER DEFAULT 0,
  category TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;


-- Table for Prices by Client Type (barberia/distribuidor)
CREATE TABLE client_prices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  client_type TEXT NOT NULL,  -- 'barberia' or 'distribuidor'
  price DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.client_prices ENABLE ROW LEVEL SECURITY;


-- Table for Global Promotions
CREATE TABLE promotions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  client_type TEXT NOT NULL,  -- 'barberia' or 'distribuidor'
  name TEXT NOT NULL,
  description TEXT,
  threshold INTEGER NOT NULL,
  bonus INTEGER NOT NULL,
  is_global BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;


-- Table for Agreements (for personalized links)
CREATE TABLE agreements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  client_name TEXT NOT NULL,
  client_type TEXT NOT NULL, -- 'barberia' or 'distribuidor'
  price_adjustment DECIMAL(10,2) DEFAULT 0,
  promo_override JSONB,
  token TEXT UNIQUE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;


-- Table for Order Logs (optional for tracking)
CREATE TABLE order_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agreement_id UUID REFERENCES agreements(id),
  order_data JSONB,
  sent_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.order_logs ENABLE ROW LEVEL SECURITY;


-- Create Policies for public read access to products
CREATE POLICY "Public can read products"
ON public.products
FOR SELECT
USING (true);

CREATE POLICY "Public can read client_prices"
ON public.client_prices
FOR SELECT
USING (true);

CREATE POLICY "Public can read promotions"
ON public.promotions
FOR SELECT
USING (true);

CREATE POLICY "Public can read agreements via token"
ON public.agreements
FOR SELECT
USING (true);


-- Create Policies for admin access (assuming you will use Supabase Auth)
-- Make sure authenticated users have an 'admin' role or similar identifier.
-- Example policy for products (repeat for other tables):
CREATE POLICY "Admins can manage products"
ON public.products
FOR ALL
USING (auth.role() = 'authenticated') -- Adjust this based on your auth setup
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage client_prices"
ON public.client_prices
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage promotions"
ON public.promotions
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage agreements"
ON public.agreements
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage order_logs"
ON public.order_logs
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- 1. CLEANUP (DROP in reverse order of creation)
-- Drop Policies
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin write on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin update on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin write on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin update on product_images" ON storage.objects;

DROP POLICY IF EXISTS "Allow anon write on order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.order_items;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.order_items;
DROP POLICY IF EXISTS "Allow anon write on orders" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.orders;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.orders;
DROP POLICY IF EXISTS "Allow anon write on clients for onboarding" ON public.clients;
DROP POLICY IF EXISTS "Allow anon read on clients for order page" ON public.clients;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.clients;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.clients;
DROP POLICY IF EXISTS "Allow anon read on app_settings" ON public.app_settings;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.app_settings;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.app_settings;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow anon read on agreements" ON public.agreements;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.agreements;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreements;
DROP POLICY IF EXISTS "Allow anon read on sales_conditions" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow anon read on promotions" ON public.promotions;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.promotions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.promotions;
DROP POLICY IF EXISTS "Allow anon read on price_list_items" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow anon read on price lists" ON public.price_lists;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.price_lists;
DROP POLICY IF EXISTS "Allow anon read on products" ON public.products;
DROP POLICY IF EXISTS "Allow authenticated users to manage" ON public.products;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.products;

-- Drop Views
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
-- Drop Functions
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_clients_heatmap_data() CASCADE;
-- Drop Tables
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
-- Drop Types
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;


-- 2. TYPES & TABLES CREATION
-- Create Types
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');

-- Create Tables
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.price_list_items (
    price_list_id UUID NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    volume_price NUMERIC(10, 2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  rules JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  rules JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_name TEXT NOT NULL UNIQUE,
  client_type public.client_type NOT NULL,
  price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.agreement_promotions (
  agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
  promotion_id UUID NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
  PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
  agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
  sales_condition_id UUID NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
  PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cuit TEXT UNIQUE,
  contact_name TEXT,
  contact_dni TEXT,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  delivery_window TEXT,
  email TEXT UNIQUE,
  instagram TEXT,
  status public.client_status NOT NULL DEFAULT 'pending_onboarding',
  onboarding_token TEXT UNIQUE,
  agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
  fiscal_status TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id),
  agreement_id UUID NOT NULL REFERENCES public.agreements(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  total_amount NUMERIC(10, 2) NOT NULL,
  status public.order_status NOT NULL,
  client_name_cache TEXT NOT NULL,
  notes TEXT
);

CREATE TABLE public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  quantity INT NOT NULL,
  price_per_unit NUMERIC(10, 2) NOT NULL
);

CREATE TABLE public.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT
);


-- 3. VIEWS & FUNCTIONS
-- Create Views
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
  agr.id,
  agr.agreement_name,
  agr.client_type,
  agr.price_list_id,
  agr.created_at,
  (SELECT COUNT(*) FROM public.agreement_promotions WHERE agreement_id = agr.id) AS promotion_count,
  (SELECT COUNT(*) FROM public.agreement_sales_conditions WHERE agreement_id = agr.id) AS sales_condition_count
FROM
  public.agreements AS agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*)::int FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COUNT(*)::int FROM public.clients WHERE status != 'archived') as total_clients,
    (SELECT COUNT(*)::int FROM public.price_lists) as total_pricelists,
    (SELECT COUNT(*)::int FROM public.promotions) as total_promotions,
    (SELECT COUNT(*)::int FROM public.sales_conditions) as total_sales_conditions,
    (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;


-- Create Functions
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS table (pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending'),
    (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
    (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days'));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS table (total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
  SELECT
    COALESCE(SUM(total_amount), 0) as total_spent,
    COALESCE(AVG(total_amount), 0) as average_order_value,
    COUNT(id) as total_orders
  FROM public.orders
  WHERE client_id = p_client_id AND status = 'completed';
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE sql
AS $$
  -- This is a placeholder. In a real, high-concurrency app, you'd use a more robust
  -- system for aggregated stats, perhaps a separate table or a dedicated analytics service.
  -- For this MVP, this RPC is sufficient but not scalable.
$$;

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk int)
LANGUAGE sql
AS $$
  SELECT
    c.id,
    c.contact_name AS name,
    COALESCE(SUM(o.total_amount), 0) AS value,
    (
      SELECT COUNT(*)::int FROM public.orders AS ro
      WHERE ro.client_id = c.id
      AND ro.status = 'pending'
      AND ro.created_at < (now() - interval '7 days')
    ) AS risk
  FROM public.clients c
  LEFT JOIN public.orders o ON c.id = o.client_id AND o.status = 'completed'
  WHERE c.status = 'active'
  GROUP BY c.id, c.contact_name;
$$;


-- 4. ROW-LEVEL SECURITY (RLS)
-- Enable RLS for all tables
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Create Policies

-- POLICIES FOR: products
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on products" ON public.products FOR SELECT USING (true);

-- POLICIES FOR: price_lists
CREATE POLICY "Allow all for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on price lists" ON public.price_lists FOR SELECT USING (true);

-- POLICIES FOR: price_list_items
CREATE POLICY "Allow all for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on price list items" ON public.price_list_items FOR SELECT USING (true);

-- POLICIES FOR: promotions
CREATE POLICY "Allow all for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on promotions" ON public.promotions FOR SELECT USING (true);

-- POLICIES FOR: sales_conditions
CREATE POLICY "Allow all for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on sales_conditions" ON public.sales_conditions FOR SELECT USING (true);

-- POLICIES FOR: agreements
CREATE POLICY "Allow all for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on agreements" ON public.agreements FOR SELECT USING (true);

-- POLICIES FOR: agreement_promotions
CREATE POLICY "Allow all for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- POLICIES FOR: agreement_sales_conditions
CREATE POLICY "Allow all for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- POLICIES FOR: clients
CREATE POLICY "Allow all for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on clients for order page" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow anon write on clients for onboarding" ON public.clients FOR UPDATE USING (onboarding_token IS NOT NULL);

-- POLICIES FOR: orders
CREATE POLICY "Allow all for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon write on orders" ON public.orders FOR INSERT WITH CHECK (true);

-- POLICIES FOR: order_items
CREATE POLICY "Allow all for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon write on order_items" ON public.order_items FOR INSERT WITH CHECK (true);

-- POLICIES FOR: app_settings
CREATE POLICY "Allow all for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to manage" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read on app_settings" ON public.app_settings FOR SELECT USING (true);


-- 5. STORAGE POLICIES
-- Policy for product images
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

CREATE POLICY "Allow admin write on product_images" ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'service_role' );

CREATE POLICY "Allow admin update on product_images" ON storage.objects FOR UPDATE
USING ( bucket_id = 'product_images' AND auth.role() = 'service_role' );

-- Policy for app assets (like logo)
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT
USING ( bucket_id = 'app_assets' );

CREATE POLICY "Allow admin write on app_assets" ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'app_assets' AND auth.role() = 'service_role' );

CREATE POLICY "Allow admin update on app_assets" ON storage.objects FOR UPDATE
USING ( bucket_id = 'app_assets' AND auth.role() = 'service_role' );

-- 6. INITIAL DATA SEEDING
-- Insert base settings, do nothing if they already exist
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT(key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '') ON CONFLICT(key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('logo_url', null) ON CONFLICT(key) DO NOTHING;

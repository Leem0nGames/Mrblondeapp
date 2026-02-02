-- 1. Cleanup and Reset
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;

-- Drop existing policies first
DROP POLICY IF EXISTS "Allow admin to manage agreements" ON public.agreements;
DROP POLICY IF EXISTS "Allow anon read for order page" ON public.agreements;
DROP POLICY IF EXISTS "Allow admin to manage agreement promotions" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow admin to manage agreement sales conditions" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow admin to manage app_settings" ON public.app_settings;
DROP POLICY IF EXISTS "Allow anon read for public settings" ON public.app_settings;
DROP POLICY IF EXISTS "Allow admin to manage clients" ON public.clients;
DROP POLICY IF EXISTS "Allow individual client access to their own data" ON public.clients;
DROP POLICY IF EXISTS "Allow client to update their own data on onboarding" ON public.clients;
DROP POLICY IF EXISTS "Allow admin to manage orders" ON public.orders;
DROP POLICY IF EXISTS "Allow anon user to create orders" ON public.orders;
DROP POLICY IF EXISTS "Allow admin to manage order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow anon user to create order items" ON public.order_items;
DROP POLICY IF EXISTS "Allow admin to manage price_lists" ON public.price_lists;
DROP POLICY IF EXISTS "Allow admin to manage price_list_items" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow anon read for order page" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow admin to manage products" ON public.products;
DROP POLICY IF EXISTS "Allow admin to manage promotions" ON public.promotions;
DROP POLICY IF EXISTS "Allow admin to manage sales_conditions" ON public.sales_conditions;

-- Drop tables and types in reverse order of creation
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;

DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.agreement_client_type CASCADE;


-- 2. Create Types (Enums)
CREATE TYPE public.client_status AS ENUM (
    'pending_onboarding',
    'pending_agreement',
    'active',
    'archived'
);

CREATE TYPE public.order_status AS ENUM (
    'pending',
    'completed'
);

CREATE TYPE public.agreement_client_type AS ENUM (
    'barberia',
    'distribuidor',
    'especial'
);

-- 3. Create Tables
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2)
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.agreement_client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status,
    onboarding_token text UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text,
    latitude double precision,
    longitude double precision
);

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL,
    volume_price numeric,
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.app_settings (
    key text NOT NULL PRIMARY KEY,
    value jsonb
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric NOT NULL,
    status public.order_status DEFAULT 'pending'::public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);

-- 4. Create Views and Functions
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
  (SELECT COALESCE(sum(total_amount), (0)::numeric) AS sum FROM public.orders WHERE (status = 'completed'::public.order_status)) AS total_revenue,
  (SELECT COALESCE(sum(total_amount), (0)::numeric) AS sum FROM public.orders WHERE ((status = 'completed'::public.order_status) AND (date_trunc('month'::text, created_at) = date_trunc('month'::text, now())))) AS month_revenue,
  (SELECT count(*) AS count FROM public.clients WHERE (status = 'active'::public.client_status)) AS active_clients,
  (SELECT count(*) AS count FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count,
  (SELECT count(*) AS count FROM public.clients) AS total_clients,
  (SELECT count(*) AS count FROM public.price_lists) AS total_pricelists,
  (SELECT count(*) AS count FROM public.promotions) AS total_promotions,
  (SELECT count(*) AS count FROM public.sales_conditions) AS total_sales_conditions;

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
  a.id,
  a.agreement_name,
  a.client_type,
  a.created_at,
  a.price_list_id,
  (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
  (SELECT count(*) FROM public.agreement_sales_conditions ascnd WHERE ascnd.agreement_id = a.id) AS sales_condition_count
FROM public.agreements a;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS record
LANGUAGE sql
AS $$
  SELECT
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending') AS pending_orders_count,
    (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count
$$;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS record
LANGUAGE sql
AS $$
  SELECT
    COALESCE(SUM(total_amount), 0) AS total_spent,
    COALESCE(AVG(total_amount), 0) AS average_order_value,
    COUNT(id) AS total_orders
  FROM public.orders
  WHERE client_id = p_client_id AND status = 'completed';
$$;

-- Placeholder function, in a real scenario this might be a trigger or more complex logic
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- This is a placeholder. In a real application, you would likely have a
  -- summary table that you would update. For this application's simplicity,
  -- we rely on the dashboard_stats view, so this function does nothing.
END;
$$;


-- 5. Enable Row-Level Security (RLS)
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS Policies
-- Agreements
CREATE POLICY "Allow admin to manage agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read for order page" ON public.agreements FOR SELECT USING (true);

-- Agreement Promotions
CREATE POLICY "Allow admin to manage agreement promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Agreement Sales Conditions
CREATE POLICY "Allow admin to manage agreement sales conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- App Settings
CREATE POLICY "Allow admin to manage app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read for public settings" ON public.app_settings FOR SELECT USING (true);

-- Clients
CREATE POLICY "Allow admin to manage clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow individual client access to their own data" ON public.clients FOR SELECT USING (((auth.jwt() ->> 'token'::text) = onboarding_token));
CREATE POLICY "Allow client to update their own data on onboarding" ON public.clients FOR UPDATE USING (((auth.jwt() ->> 'token'::text) = onboarding_token)) WITH CHECK (((auth.jwt() ->> 'token'::text) = onboarding_token));

-- Orders
CREATE POLICY "Allow admin to manage orders" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon user to create orders" ON public.orders FOR INSERT WITH CHECK (true);

-- Order Items
CREATE POLICY "Allow admin to manage order items" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon user to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Price Lists
CREATE POLICY "Allow admin to manage price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Price List Items
CREATE POLICY "Allow admin to manage price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read for order page" ON public.price_list_items FOR SELECT USING (true);

-- Products
CREATE POLICY "Allow admin to manage products" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Promotions
CREATE POLICY "Allow admin to manage promotions" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Sales Conditions
CREATE POLICY "Allow admin to manage sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- 7. Storage Policies
DROP POLICY IF EXISTS "Allow read on app_assets" ON storage.objects;
CREATE POLICY "Allow read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');

DROP POLICY IF EXISTS "Allow all on product_images for admins" ON storage.objects;
CREATE POLICY "Allow all on product_images for admins" ON storage.objects FOR ALL
USING (bucket_id = 'product_images' AND auth.role() = 'authenticated')
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

-- 8. Initial Data Seeding
INSERT INTO public.app_settings (key, value) VALUES
    ('whatsapp_number', '"5491123456789"'),
    ('vat_percentage', '21')
ON CONFLICT(key) DO NOTHING;

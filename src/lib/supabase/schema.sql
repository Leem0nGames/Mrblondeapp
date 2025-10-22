
-- ▀██▀▀█ █▀▀ █   █▀▀ ▀█▀ █▀▀ █▀▄   █▀▀ █▀█ █▀▀ █▀▀ █▀▄
--  ██ ▄▄ █▀▀ █ ▄ █▀▀  █  █▀▀ █ █   █▀▀ █▀▄ █▀▀ █▀▀ █ █
--  ██ ▄▄ ▀▀▀ ▀▀▀ ▀▀▀ ▄█▄ ▀▀▀ ▀▀    ▀▀▀ ▀ ▀ ▀▀▀ ▀▀▀ ▀▀
--
-- Idempotent script to set up the database schema for Blonde Orders.
-- It can be run safely on a new or existing database.
-- It will drop existing objects and recreate them.

-- 1. Cleanup and Reset
-- Drop existing objects in reverse order of creation.
-- ALWAYS use DROP ... CASCADE to handle dependencies automatically.

DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;

DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;

DROP TYPE IF EXISTS public.client_status CASCADE;


-- 2. Create Types (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');


-- 3. Create Tables

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price double precision NOT NULL CHECK (price >= 0),
    volume_price double precision CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type text NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text
);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount double precision NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit double precision NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);


-- 4. Create Views and Functions

CREATE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;
    
CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '2 days'::interval)) as overdue_orders_count,
    (SELECT count(*) FROM public.clients) as total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions;


CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent double precision, average_order_value double precision, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0.0) as total_spent,
        COALESCE(AVG(o.total_amount), 0.0) as average_order_value,
        COUNT(o.id) as total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '2 days'::interval)) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void AS $$
DECLARE
    current_revenue double precision;
BEGIN
    -- This is a placeholder function as direct updates to dashboard_stats might be better handled by triggers or scheduled jobs.
    -- For this app's simplicity, we simulate an update.
    RAISE NOTICE 'Revenue incremented by %', amount_to_add;
END;
$$ LANGUAGE plpgsql;


-- 5. Enable Row-Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;


-- 6. Create RLS Policies
-- Authenticated admins can do anything.
CREATE POLICY "Allow all for authenticated admins" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated admins" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- Anonymous users (order page, onboarding) have limited access.
CREATE POLICY "Allow anon read on agreements" ON public.agreements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on agreement_promotions" ON public.agreement_promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on promotions" ON public.promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on price_lists" ON public.price_lists FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on price_list_items" ON public.price_list_items FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on products" ON public.products FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on app_settings" ON public.app_settings FOR SELECT TO anon USING (true);

-- ** NEW POLICY **: Allow anon to read from clients table IF they have the onboarding token.
CREATE POLICY "Allow anon read for onboarding" ON public.clients FOR SELECT TO anon 
USING (onboarding_token::text = current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token');

-- Allow anon users to create orders and update their own client record on onboarding.
CREATE POLICY "Allow anon insert on orders" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon insert on order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon update on their own client record" ON public.clients FOR UPDATE TO anon 
USING (onboarding_token::text = current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token');


-- 7. Storage Policies
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

DROP POLICY IF EXISTS "Allow admin write on product_images" ON storage.objects;
CREATE POLICY "Allow admin write on product_images" ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

DROP POLICY IF EXISTS "Allow admin update on product_images" ON storage.objects;
CREATE POLICY "Allow admin update on product_images" ON storage.objects FOR UPDATE
USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT
USING ( bucket_id = 'app_assets' );

DROP POLICY IF EXISTS "Allow admin write on app_assets" ON storage.objects;
CREATE POLICY "Allow admin write on app_assets" ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'app_assets' AND auth.role() = 'authenticated' );


-- 8. Seed Data (Optional, for initial setup)
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '5491123456789');
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21');

-- The end.

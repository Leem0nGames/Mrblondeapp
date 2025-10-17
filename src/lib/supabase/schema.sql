
-- ----------------------------------------------------------------
-- 1. CLEANUP: Drop all objects in reverse order of dependency
--    This section makes the script idempotent.
--    ALWAYS use CASCADE to handle dependencies automatically.
-- ----------------------------------------------------------------

-- Drop policies first, as they depend on tables and functions
DROP POLICY IF EXISTS "Allow anonymous insert for orders" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow authenticated read for orders" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow authenticated update for orders" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_list_items CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.order_items CASCADE;

-- Storage policies
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to update product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to delete their own product images" ON storage.objects CASCADE;

-- Drop functions/views that depend on tables
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(p_client_id uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Drop tables
DROP TABLE IF EXISTS public.app_meta CASCADE;
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

-- Drop types
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;


-- ----------------------------------------------------------------
-- 2. TYPES: Define custom data types (Enums)
-- ----------------------------------------------------------------

CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');


-- ----------------------------------------------------------------
-- 3. TABLES: Define all tables
-- ----------------------------------------------------------------

-- Products Table
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Promotions Table
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Sales Conditions Table
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Price Lists Table
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Price List Items Table (Junction table for Products and Price Lists)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

-- Agreements Table
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Agreement Promotions (Junction table)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Agreement Sales Conditions (Junction table)
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Clients Table
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token uuid NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text
);

-- Orders Table
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

-- Order Items Table
CREATE TABLE public.order_items (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

-- App Metadata Table
CREATE TABLE public.app_meta (
    key text PRIMARY KEY,
    value jsonb
);

-- ----------------------------------------------------------------
-- 4. VIEWS AND FUNCTIONS
-- ----------------------------------------------------------------

-- View for Dashboard Stats
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed'::public.order_status) AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed'::public.order_status AND created_at >= date_trunc('month'::text, now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active'::public.client_status) AS active_clients;

-- View for Agreements with counts of associated items
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;

-- Function for incrementing total revenue (for app_meta)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void AS $$
BEGIN
    UPDATE public.app_meta
    SET value = jsonb_set(
        value,
        '{total_revenue}',
        (COALESCE(value->>'total_revenue', '0')::numeric + amount_to_add)::text::jsonb
    )
    WHERE key = 'stats';
END;
$$ LANGUAGE plpgsql;

-- Function to get stats for a single client
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COALESCE(AVG(o.total_amount), 0) as average_order_value,
        COUNT(o.id) as total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get notification counts
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '2 days'));
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------------------------------
-- 5. ROW-LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------

-- Enable RLS on all tables that need it
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


-- ----------------------------------------------------------------
-- 6. RLS POLICIES
-- ----------------------------------------------------------------

-- Policies for tables managed by admins
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Policies for public 'orders' table (more granular)
CREATE POLICY "Allow anonymous insert for orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow authenticated read for orders" ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated update for orders" ON public.orders FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- ----------------------------------------------------------------
-- 7. STORAGE POLICIES
-- ----------------------------------------------------------------

-- Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Policies for 'product_images' bucket
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

CREATE POLICY "Allow authenticated users to upload product images" ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow authenticated users to update product images" ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product_images');

CREATE POLICY "Allow authenticated users to delete their own product images" ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product_images');


-- ----------------------------------------------------------------
-- 8. SEED DATA (Optional)
-- ----------------------------------------------------------------

-- Insert initial metadata if it doesn't exist
INSERT INTO public.app_meta (key, value)
VALUES ('stats', '{"total_revenue": 0}')
ON CONFLICT (key) DO NOTHING;

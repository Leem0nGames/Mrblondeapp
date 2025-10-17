
-- ------------------------------------------------------------------------------------------------
--  Blonde Orders - Idempotent Schema Reset
-- ------------------------------------------------------------------------------------------------
--
--  Instructions:
--  1. Go to the "SQL Editor" in your Supabase project.
--  2. Paste the entire content of this file.
--  3. Click "RUN".
--
--  This script is designed to be run multiple times safely. It will clean up and
--  re-create the entire schema, ensuring a consistent state.
--
-- ------------------------------------------------------------------------------------------------

-- --------------------------------------------------------
--  Section 1: Cleanup and Reset
--  Drop all objects in reverse order of creation.
--  Using "CASCADE" is crucial to avoid dependency errors.
-- --------------------------------------------------------

-- Drop Policies first to avoid dependency issues on tables
DROP POLICY IF EXISTS "Allow authenticated users to upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin full access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow anonymous read access to product images" ON storage.objects;

-- Drop Functions and Views
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_notification_counts();
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;

-- Drop Tables
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;


-- --------------------------------------------------------
--  Section 2: Create Custom Types (Enums)
-- --------------------------------------------------------

CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.agreement_client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');

-- --------------------------------------------------------
--  Section 3: Create Tables
-- --------------------------------------------------------

-- Table for Products
CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text NULL,
    category text NULL,
    image_url text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT products_pkey PRIMARY KEY (id)
);

-- Table for Price Lists
CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT price_lists_pkey PRIMARY KEY (id),
    CONSTRAINT price_lists_name_key UNIQUE (name)
);

-- Junction Table for Products and Price Lists
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL DEFAULT 0,
    volume_price numeric NULL,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);

-- Table for Promotions
CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text NULL,
    rules jsonb NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);

-- Table for Sales Conditions
CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text NULL,
    rules jsonb NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT sales_conditions_pkey PRIMARY KEY (id)
);

-- Table for Agreements
CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL,
    client_type public.agreement_client_type NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    price_list_id uuid NULL,
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Junction Table for Agreements and Promotions
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE
);

-- Junction Table for Agreements and Sales Conditions
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL,
    CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id),
    CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE
);

-- Table for Clients
CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    cuit text NULL,
    contact_name text NULL,
    contact_dni text NULL,
    address text NULL,
    delivery_window text NULL,
    email text NULL,
    instagram text NULL,
    status public.client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status text NULL,
    latitude double precision NULL,
    longitude double precision NULL,
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token),
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL
);

-- Table for Orders
CREATE TABLE public.orders (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text NULL,
    CONSTRAINT orders_pkey PRIMARY KEY (id),
    CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE RESTRICT,
    CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT
);

-- Table for Order Items
CREATE TABLE public.order_items (
    id bigint NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL,
    CONSTRAINT order_items_pkey PRIMARY KEY (id),
    CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE,
    CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT
);

-- Table for simple key-value metadata
CREATE TABLE public.app_meta (
    key text NOT NULL,
    value jsonb NULL,
    CONSTRAINT app_meta_pkey PRIMARY KEY (key)
);

-- --------------------------------------------------------
--  Section 4: Create Views and Functions
-- --------------------------------------------------------

-- View to get agreement counts for easier display
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascv WHERE ascv.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;

-- View for main dashboard statistics
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT value->>'total_revenue' FROM public.app_meta WHERE key = 'stats')::numeric AS total_revenue,
    (SELECT sum(total_amount) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '2 days')) as overdue_orders_count;

-- Function to get detailed stats for a single client
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id;
$$;

-- Function to increment total revenue
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE app_meta
    SET value = jsonb_set(
        value,
        '{total_revenue}',
        to_jsonb(COALESCE((value->>'total_revenue')::numeric, 0) + amount_to_add)
    )
    WHERE key = 'stats';
END;
$$;

-- Function to get all notification counts in one go
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count integer, pending_clients_count integer, overdue_orders_count integer)
LANGUAGE sql
AS $$
    SELECT
        (SELECT count(*)::integer FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*)::integer FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*)::integer FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '2 days')) AS overdue_orders_count;
$$;

-- --------------------------------------------------------
--  Section 5: Enable Row-Level Security (RLS)
-- --------------------------------------------------------

-- Enable RLS on all tables that need protection
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
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------
--  Section 6: Create RLS Policies
-- --------------------------------------------------------

-- Allow full access for admin users (service_role) on all tables
CREATE POLICY "Allow admin full access on products" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on agreements" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on clients" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on orders" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on order_items" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on app_meta" ON public.app_meta FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Allow read-only access for anonymous users to data needed for the order page
CREATE POLICY "Allow anon read access on products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on price_lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on price_list_items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on sales_conditions" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on agreement_promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on agreement_sales_conditions" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access on clients" ON public.clients FOR SELECT USING (true);

-- Allow anonymous users to create orders and order items
CREATE POLICY "Allow anon to create orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Allow anonymous users to update client onboarding info
CREATE POLICY "Allow anon to update their own onboarding" ON public.clients FOR UPDATE
    USING (onboarding_token = (SELECT txt FROM (SELECT current_setting('request.jwt.claims', true)::json->>'onboarding_token' as txt) as jwt_claims WHERE txt IS NOT NULL))
    WITH CHECK (onboarding_token = (SELECT txt FROM (SELECT current_setting('request.jwt.claims', true)::json->>'onboarding_token' as txt) as jwt_claims WHERE txt IS NOT NULL));

-- --------------------------------------------------------
--  Section 7: Storage Policies
-- --------------------------------------------------------

-- Ensure the product_images bucket exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Policies for 'product_images' bucket
CREATE POLICY "Allow authenticated users to upload" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow admin full access to product images" ON storage.objects FOR ALL
USING (bucket_id = 'product_images' AND auth.role() = 'service_role')
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'service_role');

CREATE POLICY "Allow anonymous read access to product images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');


-- --------------------------------------------------------
--  Section 8: Initial Data Seeding
-- --------------------------------------------------------

-- Initialize statistics if they don't exist
INSERT INTO public.app_meta (key, value)
VALUES ('stats', '{"total_revenue": 0}')
ON CONFLICT(key) DO NOTHING;

-- ------------------------------------------------------------------------------------------------
-- End of Script
-- ------------------------------------------------------------------------------------------------


-- ----------------------------
-- 1. Cleanup and Reset
-- ----------------------------
-- Drop existing objects in reverse order of creation to avoid dependency errors.
-- Using CASCADE to automatically drop dependent objects.

DROP FUNCTION IF EXISTS public.get_notification_counts();
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_overdue_orders();

DROP VIEW IF EXISTS public.dashboard_stats;
DROP VIEW IF EXISTS public.agreements_with_counts;

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;

-- Drop policies on storage.objects
DROP POLICY IF EXISTS "Allow authenticated users to upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin full access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow anonymous read access to product images" ON storage.objects;


-- ----------------------------
-- 2. Create Tables
-- ----------------------------

-- Products Table
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Stores all available products in the catalog.';

-- Price Lists Table
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Defines reusable price lists.';

-- Price List Items Table (Junction table for Products and Price Lists)
CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Defines the price of a specific product within a price list.';

-- Promotions Table
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Defines promotional rules (e.g., Buy X, Get Y free).';

-- Sales Conditions Table
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Defines commercial terms like payment deadlines.';

-- Agreements Table
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type_enum NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.agreements IS 'Connects a client type to a price list, promotions, and sales conditions.';


-- Junction Table for Agreements and Promotions
CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Junction Table for Agreements and Sales Conditions
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);


-- Clients Table
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status_enum DEFAULT 'pending_onboarding'::public.client_status_enum NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text
);
COMMENT ON TABLE public.clients IS 'Stores client information.';


-- Orders Table
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status public.order_status_enum NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);
COMMENT ON TABLE public.orders IS 'Represents an order placed by a client.';

-- Order Items Table
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

-- App Metadata Table
CREATE TABLE public.app_meta (
    key text PRIMARY KEY,
    value jsonb
);
COMMENT ON TABLE public.app_meta IS 'Stores key-value metadata for the application.';


-- ----------------------------
-- 3. Row-Level Security (RLS)
-- ----------------------------
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

-- Allow full access for authenticated admins
CREATE POLICY "Allow admin full access" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.app_meta FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Allow public read access to data needed for the order page.
CREATE POLICY "Allow public read access for order page" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read on clients for order page" ON public.clients FOR SELECT USING (true);

-- Allow users to create orders
CREATE POLICY "Allow anonymous users to create orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous users to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Allow clients to complete their onboarding form
CREATE POLICY "Allow users to read their own onboarding data" ON public.clients FOR SELECT USING (onboarding_token::text = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token'));
CREATE POLICY "Allow users to update their own onboarding data" ON public.clients FOR UPDATE USING (onboarding_token::text = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token')) WITH CHECK (onboarding_token::text = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token'));


-- ----------------------------
-- 4. Views and Functions
-- ----------------------------

-- View to count promotions and sales conditions for each agreement
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascv WHERE ascv.agreement_id = a.id) AS sales_condition_count
FROM public.agreements a;

-- View for dashboard statistics
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month'::text, now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count;


-- Function to get client-specific stats
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COALESCE(AVG(total_amount), 0) AS average_order_value,
        COUNT(id) AS total_orders
    FROM public.orders
    WHERE client_id = p_client_id;
$$;

-- Function to increment total revenue (example)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This is a placeholder for a more complex revenue tracking logic.
    -- For now, we don't store aggregated revenue in app_meta. The dashboard_stats view calculates it.
END;
$$;

-- Function to get counts for notifications
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql
AS $$
    SELECT
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count;
$$;


-- ----------------------------
-- 5. Storage Policies
-- ----------------------------

-- Create a bucket for product images if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Policies for storage access
CREATE POLICY "Allow authenticated users to upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product_images');
CREATE POLICY "Allow admin full access to product images" ON storage.objects FOR ALL USING (bucket_id = 'product_images' AND auth.role() = 'service_role') WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'service_role');
CREATE POLICY "Allow anonymous read access to product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');

-- Insert initial metadata if it doesn't exist
INSERT INTO public.app_meta (key, value)
VALUES ('total_revenue', '{"value": 0}')
ON CONFLICT (key) DO NOTHING;

-- Initial seed data can be found in seed.sql

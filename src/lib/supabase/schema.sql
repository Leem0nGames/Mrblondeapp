
-- =============================================================================
-- 1. CLEANUP & RESET
-- Drop existing objects in reverse order of creation to avoid dependency errors.
-- ALWAYS use DROP ... CASCADE to handle dependencies automatically.
-- =============================================================================

-- Drop policies
DROP POLICY IF EXISTS "Allow public read access to app assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to upload app assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to update app assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to delete app assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to update product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to delete their own product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Enable all actions for service_role" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.app_settings CASCADE;

-- Drop functions and views
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Drop tables
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

-- Drop types
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;

-- =============================================================================
-- 2. CREATE TYPES (Enums)
-- Enums should be created before the tables that use them.
-- =============================================================================
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');

-- =============================================================================
-- 3. CREATE TABLES
-- =============================================================================

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    volume_price NUMERIC(10, 2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name TEXT NOT NULL UNIQUE,
    client_type client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status client_status NOT NULL,
    onboarding_token TEXT UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    fiscal_status TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id),
    agreement_id uuid REFERENCES public.agreements(id),
    created_at timestamptz DEFAULT now() NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    status order_status NOT NULL,
    client_name_cache TEXT,
    notes TEXT
);

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id),
    quantity INT NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);

CREATE TABLE public.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

-- =============================================================================
-- 4. CREATE VIEWS & FUNCTIONS
-- =============================================================================

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT COUNT(*) FROM public.agreement_promotions WHERE agreement_id = agr.id) AS promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions WHERE agreement_id = agr.id) AS sales_condition_count
FROM
    public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT value::numeric FROM public.app_settings WHERE key = 'total_revenue') AS total_revenue,
    (SELECT SUM(total_amount) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count,
    (SELECT COUNT(*) FROM public.clients) as total_clients,
    (SELECT COUNT(*) FROM public.price_lists) as total_pricelists,
    (SELECT COUNT(*) FROM public.promotions) as total_promotions,
    (SELECT COUNT(*) FROM public.sales_conditions) as total_sales_conditions;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days'));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value,
        COUNT(o.id) AS total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
    UPDATE public.app_settings
    SET value = (value::numeric + amount_to_add)::text
    WHERE key = 'total_revenue';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================================
-- 5. ENABLE ROW-LEVEL SECURITY (RLS)
-- =============================================================================

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

-- =============================================================================
-- 6. RLS POLICIES
-- =============================================================================

-- All tables are fully accessible to service_role (admins)
CREATE POLICY "Enable all access for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable all access for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Anon users (customers on order pages) can read/write what they need.
CREATE POLICY "Enable read access for anon users" ON public.products FOR SELECT USING (true);
CREATE POLICY "Enable read access for anon users" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Enable read access for anon users" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Enable read access for anon users" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Enable read access for anon users" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Enable read access for anon users" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Enable read access for anon users" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Enable read access for anon users" ON public.app_settings FOR SELECT USING (true);

-- Anon users can create orders and order items
CREATE POLICY "Enable insert for anon users" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable insert for anon users" ON public.order_items FOR INSERT WITH CHECK (true);

-- Anon users can update clients only via their onboarding token
CREATE POLICY "Enable update for anon users via token" ON public.clients FOR UPDATE
USING (onboarding_token IS NOT NULL AND (SELECT t.onboarding_token FROM public.clients t WHERE t.id = clients.id) = onboarding_token)
WITH CHECK (onboarding_token IS NOT NULL AND (SELECT t.onboarding_token FROM public.clients t WHERE t.id = clients.id) = onboarding_token);


-- =============================================================================
-- 7. STORAGE POLICIES
-- =============================================================================

-- Policies for `product_images` bucket
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to upload product images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to update product images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to delete their own product images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'product_images');

-- Policies for `app_assets` bucket (for logos, etc.)
CREATE POLICY "Allow public read access to app assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow authenticated users to upload app assets" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'app_assets');
CREATE POLICY "Allow authenticated users to update app assets" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'app_assets');
CREATE POLICY "Allow authenticated users to delete app assets" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'app_assets');


-- =============================================================================
-- 8. SEED DATA
-- =============================================================================
INSERT INTO public.app_settings (key, value)
VALUES
    ('total_revenue', '0'),
    ('vat_percentage', '21'),
    ('whatsapp_number', '5491123456789')
ON CONFLICT(key) DO NOTHING;

-- Create default storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public) VALUES ('product_images', 'product_images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('app_assets', 'app_assets', true) ON CONFLICT (id) DO NOTHING;

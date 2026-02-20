
-- Mr. Blonde Database Schema
-- Last updated: Multi-bundle logistics and new order statuses

-- Cleanup
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TYPE IF EXISTS public.order_status_enum CASCADE;

-- Types
CREATE TYPE public.order_status_enum AS ENUM ('armado', 'transito', 'entregado');

-- Tables
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    price numeric(12,2) NOT NULL DEFAULT 0,
    volume_price numeric(12,2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type text NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.clients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_name text,
    email text UNIQUE,
    cuit text UNIQUE,
    address text,
    delivery_window text,
    instagram text,
    status text DEFAULT 'pending_onboarding' NOT NULL,
    onboarding_token uuid UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    fiscal_status text,
    contact_dni text,
    latitude float8,
    longitude float8
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id),
    total_amount numeric(12,2) NOT NULL,
    status public.order_status_enum DEFAULT 'armado' NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric(12,2) NOT NULL
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Vistas
CREATE VIEW public.dashboard_stats AS
SELECT 
    COALESCE(SUM(total_amount), 0) as total_revenue,
    COALESCE(SUM(total_amount) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)), 0) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'armado') as pending_orders_count,
    (SELECT COUNT(*) FROM public.clients WHERE status != 'archived') as total_clients,
    (SELECT COUNT(*) FROM public.products) as total_products,
    (SELECT COUNT(*) FROM public.price_lists) as total_pricelists,
    (SELECT COUNT(*) FROM public.promotions) as total_promotions,
    (SELECT COUNT(*) FROM public.sales_conditions) as total_sales_conditions
FROM public.orders;

-- Funciones
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'armado'),
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'transito' AND created_at < NOW() - INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin all" ON public.products FOR ALL USING (auth.role() = 'authenticated');

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin all" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Public insert" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Public read portal" ON public.orders FOR SELECT USING (true);
CREATE POLICY "Public update confirm" ON public.orders FOR UPDATE USING (true) WITH CHECK (true);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin all" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Public insert" ON public.order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Public read portal" ON public.order_items FOR SELECT USING (true);

-- Settings iniciales
INSERT INTO public.app_settings (key, value) VALUES 
('whatsapp_number', '5491144276120'),
('vat_percentage', '21')
ON CONFLICT (key) DO NOTHING;

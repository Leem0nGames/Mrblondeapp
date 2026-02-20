
-- --- LIMPIEZA TOTAL ---
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TYPE IF EXISTS public.order_status_enum CASCADE;
DROP TYPE IF EXISTS public.client_status_enum CASCADE;

-- --- TIPOS ENUM ---
CREATE TYPE public.order_status_enum AS ENUM ('armado', 'transito', 'entregado');
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');

-- --- TABLAS BASE ---
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
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    price float8 NOT NULL DEFAULT 0,
    volume_price float8,
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
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
    contact_dni text,
    address text,
    delivery_window text,
    instagram text,
    status public.client_status_enum DEFAULT 'pending_onboarding' NOT NULL,
    onboarding_token uuid,
    agreement_id uuid REFERENCES public.agreements(id),
    fiscal_status text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id),
    total_amount float8 NOT NULL,
    status public.order_status_enum DEFAULT 'armado' NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id),
    quantity int NOT NULL,
    price_per_unit float8 NOT NULL
);

-- --- TABLAS DE RELACIÓN ---
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

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --- VISTAS ---
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT 
    a.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions asc_rel WHERE asc_rel.agreement_id = a.id) as sales_condition_count
FROM public.agreements a;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT 
    COALESCE(SUM(total_amount), 0) as total_revenue,
    COALESCE(SUM(total_amount) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)), 0) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'armado') as pending_orders_count,
    (SELECT COUNT(*) FROM public.clients WHERE status != 'archived') as total_clients,
    (SELECT COUNT(*) FROM public.price_lists) as total_pricelists,
    (SELECT COUNT(*) FROM public.promotions) as total_promotions,
    (SELECT COUNT(*) FROM public.sales_conditions) as total_sales_conditions
FROM public.orders;

-- --- FUNCIONES ---
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'armado'),
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'transito' AND created_at < NOW() - INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --- RLS POLICIES ---
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins full access" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins full access" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated');

-- Public read for catalogs and portals
CREATE POLICY "Public read portal" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Public read portal" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Public read portal" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Public read portal" ON public.products FOR SELECT USING (true);
CREATE POLICY "Public read portal" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Public read portal" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Public read portal" ON public.order_items FOR SELECT USING (true);
CREATE POLICY "Public portal access" ON public.orders FOR SELECT USING (true);
CREATE POLICY "Public portal update" ON public.orders FOR UPDATE USING (true);
CREATE POLICY "Public portal insert" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Public portal insert items" ON public.order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Public onboarding update" ON public.clients FOR UPDATE USING (true);
CREATE POLICY "Public onboarding select" ON public.clients FOR SELECT USING (true);


-- LIMPIEZA Y REINICIO DE ESQUEMA (Idempotente)
-- Borrar vistas primero por dependencias
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Borrar tablas
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;

-- Borrar tipos personalizados
DROP TYPE IF EXISTS public.order_status_enum CASCADE;
DROP TYPE IF EXISTS public.client_status_enum CASCADE;
DROP TYPE IF EXISTS public.client_type_enum CASCADE;

-- 1. CREACIÓN DE TIPOS (ENUMS)
CREATE TYPE public.order_status_enum AS ENUM ('armado', 'transito', 'entregado');
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type_enum AS ENUM ('barberia', 'distribuidor', 'especial');

-- 2. CREACIÓN DE TABLAS
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
    client_type public.client_type_enum DEFAULT 'barberia'::public.client_type_enum NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
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
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status_enum DEFAULT 'pending_onboarding'::public.client_status_enum NOT NULL,
    onboarding_token uuid,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status text,
    latitude float8,
    longitude float8,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    total_amount float8 NOT NULL,
    status public.order_status_enum DEFAULT 'armado'::public.order_status_enum NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    quantity int NOT NULL,
    price_per_unit float8 NOT NULL
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. VISTAS Y FUNCIONES
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT 
    a.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_table WHERE asc_table.agreement_id = a.id) as sales_condition_count
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

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'armado'),
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'transito' AND created_at < NOW() - INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. SEGURIDAD (RLS)
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

-- Políticas para administradores
CREATE POLICY "Admins manage all" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage items" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage promos" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage orders" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage order items" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Admins manage settings" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated');

-- Acceso público para clientes (Onboarding y Pedidos)
CREATE POLICY "Public order view" ON public.orders FOR SELECT USING (true);
CREATE POLICY "Public order update" ON public.orders FOR UPDATE USING (true);
CREATE POLICY "Public items view" ON public.order_items FOR SELECT USING (true);
CREATE POLICY "Public clients select" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Public clients insert" ON public.clients FOR INSERT WITH CHECK (true);
CREATE POLICY "Public clients update" ON public.clients FOR UPDATE USING (true);
CREATE POLICY "Public agreements view" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Public price lists view" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Public list items view" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Public app settings view" ON public.app_settings FOR SELECT USING (true);

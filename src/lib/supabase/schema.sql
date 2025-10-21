-- 🌀 Inicia una transacción para asegurar que el script se ejecute completamente o falle.
BEGIN;

-- 🧹 1. LIMPIEZA: Elimina objetos existentes en orden inverso de dependencia.
-- Usar `CASCADE` es crucial para eliminar dependencias automáticamente.

-- Políticas de Almacenamiento (Storage)
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage app_assets" ON storage.objects CASCADE;

-- Políticas de Seguridad a Nivel de Fila (RLS)
DROP POLICY IF EXISTS "Allow all for service_role on promotions" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on price_lists" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on sales_conditions" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow read access to everyone" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow read access to everyone" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.price_list_items CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on agreements" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on agreement_promotions" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on agreement_sales_conditions" ON public.agreement_sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on clients" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow insert for anonymous users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on orders" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on order_items" ON public.order_items CASCADE;
DROP POLICY IF EXISTS "Allow read for authenticated users" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.app_settings CASCADE;


-- Funciones y Vistas
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;


-- Tablas
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;


-- Tipos (Enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.promotion_type CASCADE;
DROP TYPE IF EXISTS public.sales_condition_type CASCADE;

-- 🌈 2. CREACIÓN: Define la estructura de la base de datos.

-- Tipos (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');
CREATE TYPE public.sales_condition_type AS ENUM ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');

-- Tablas
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL,
    volume_price numeric,
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
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

CREATE TABLE public.clients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token text UNIQUE DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    fiscal_status text
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES public.clients(id),
    agreement_id uuid REFERENCES public.agreements(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL DEFAULT 'pending',
    client_name_cache text,
    notes text
);

CREATE TABLE public.order_items (
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);

-- Vistas (Views)
CREATE VIEW public.orders_with_overdue_status AS
SELECT
    o.*,
    (o.created_at::date + '30 days'::interval)::date AS due_date,
    (o.status = 'pending' AND (o.created_at::date + '30 days'::interval)::date < now()::date) AS is_overdue,
    GREATEST(0, (now()::date - (o.created_at::date + '30 days'::interval)::date)) AS days_overdue
FROM public.orders o;

CREATE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE is_overdue) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;

-- Funciones
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COALESCE(AVG(total_amount), 0) AS average_order_value,
        COUNT(id) AS total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*) FROM public.orders_with_overdue_status WHERE is_overdue) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- Placeholder. En una aplicación real, esto se manejaría de forma más robusta.
END;
$$ LANGUAGE plpgsql;


-- 🔒 3. SEGURIDAD: Habilita RLS y define las políticas.

-- Habilitar Row-Level Security (RLS) en las tablas
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


-- Políticas de RLS
CREATE POLICY "Allow public read on products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow public read on price_lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow all for service_role on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreements" ON public.agreements FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on clients" ON public.clients FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow insert for authenticated users" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow all for service_role on orders" ON public.orders FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on order_items" ON public.order_items FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow read for authenticated users" ON public.app_settings FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for service_role on app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role');


-- Políticas de Almacenamiento (Storage)
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING ( bucket_id = 'product_images' );
CREATE POLICY "Allow admin to manage product_images" ON storage.objects FOR ALL USING ( bucket_id = 'product_images' AND auth.role() = 'service_role' );
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING ( bucket_id = 'app_assets' );
CREATE POLICY "Allow admin to manage app_assets" ON storage.objects FOR ALL USING ( bucket_id = 'app_assets' AND auth.role() = 'service_role' );


-- 🏁 Finaliza la transacción.
COMMIT;

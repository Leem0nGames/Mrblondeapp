
-- Habilita la extensión pgcrypto para gen_random_uuid() si no está habilitada
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Limpieza y Reseteo
-- Elimina políticas de almacenamiento existentes para evitar errores de duplicados.
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;

-- Elimina objetos de la base de datos en orden inverso a su creación.
-- Usar CASCADE para manejar dependencias automáticamente.
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;

-- 2. Creación de Tipos (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');

-- 3. Creación de Tablas
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL,
    volume_price numeric,
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
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
    onboarding_token text DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status text
);

CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
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
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL DEFAULT 'pending',
    client_name_cache text NOT NULL,
    notes text,
    payment_due_date date
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);

-- 4. Creación de Vistas y Funciones
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT count(*) FROM public.agreement_promotions apro WHERE apro.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
    o.*,
    (o.status = 'pending' AND o.payment_due_date IS NOT NULL AND o.payment_due_date < now()::date) AS overdue,
    GREATEST(0, (now()::date - o.payment_due_date)) AS days_overdue
FROM public.orders o;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::int FROM public.orders_with_overdue_status WHERE overdue = true);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk int) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.contact_name AS name,
        COALESCE(SUM(o.total_amount), 0) AS value,
        (SELECT count(*)::int FROM public.orders_with_overdue_status WHERE client_id = c.id AND overdue = true) AS risk
    FROM public.clients c
    LEFT JOIN public.orders o ON c.id = o.client_id AND o.status = 'completed'
    WHERE c.status = 'active'
    GROUP BY c.id, c.contact_name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- Placeholder. En una app real, esta lógica estaría en un trigger o sería más robusta.
END;
$$ LANGUAGE plpgsql;

-- 5. Habilitación de Row-Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 6. Creación de Políticas RLS para tablas
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreements" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on clients" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Políticas para la tabla de pedidos
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated users" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow read/update/delete for service_role on orders" ON public.orders FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for service_role on order_items" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- 7. Políticas de Almacenamiento (Storage)
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow authenticated insert on product_images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product_images');
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');

-- 8. Datos Iniciales (Opcional)
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT (key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '') ON CONFLICT (key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('logo_url', null) ON CONFLICT (key) DO NOTHING;

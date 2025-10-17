
-- Versión 2.0 del Script de Base de Datos - Idempotente y Robusto

-- 1. LIMPIEZA Y REINICIO
-- Elimina objetos existentes en orden inverso a su creación, usando CASCADE.

-- Policies de Storage
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to update product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to delete their own product images" ON storage.objects CASCADE;

-- Policies de Tablas (si existen)
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_list_items CASCADE;
DROP POLICY IF EXISTS "Allow anonymous insert for orders" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow read for authenticated users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow update for authenticated users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.order_items CASCADE;


-- Funciones y Vistas
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision) CASCADE;

-- Tablas
DROP TABLE IF EXISTS public.app_meta CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;

-- Tipos (Enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;

-- 2. CREACIÓN DE TIPOS (ENUMS)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');


-- 3. CREACIÓN DE TABLAS
CREATE TABLE public.app_meta (
    key TEXT PRIMARY KEY,
    value JSONB
);

CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.price_list_items (
    price_list_id UUID NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price DOUBLE PRECISION NOT NULL,
    volume_price DOUBLE PRECISION,
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name TEXT NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status public.client_status NOT NULL,
    onboarding_token TEXT UNIQUE,
    agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    fiscal_status TEXT
);

CREATE TABLE public.agreement_promotions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id UUID NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id),
    agreement_id UUID NOT NULL REFERENCES public.agreements(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_amount DOUBLE PRECISION NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    quantity INTEGER NOT NULL,
    price_per_unit DOUBLE PRECISION NOT NULL
);


-- 4. VISTAS Y FUNCIONES

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;


CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(value ->> 'total_revenue', '0')::double precision FROM app_meta WHERE key = 'revenue_stats') as total_revenue,
    (SELECT COUNT(*) FROM clients WHERE status = 'active') as active_clients,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;


CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id UUID)
RETURNS TABLE(total_spent DOUBLE PRECISION, average_order_value DOUBLE PRECISION, total_orders BIGINT) AS $$
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


CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count BIGINT, pending_clients_count BIGINT, overdue_orders_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') as pending_orders_count,
        (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') as pending_clients_count,
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void AS $$
DECLARE
    current_revenue double precision;
BEGIN
    SELECT (value ->> 'total_revenue')::double precision INTO current_revenue FROM app_meta WHERE key = 'revenue_stats';
    IF current_revenue IS NULL THEN
        current_revenue := 0;
    END IF;
    INSERT INTO app_meta (key, value)
    VALUES ('revenue_stats', jsonb_build_object('total_revenue', current_revenue + amount_to_add))
    ON CONFLICT (key) DO UPDATE
    SET value = jsonb_set(app_meta.value, '{total_revenue}', to_jsonb((app_meta.value->>'total_revenue')::double precision + amount_to_add));
END;
$$ LANGUAGE plpgsql;


-- 5. HABILITACIÓN DE RLS (ROW-LEVEL SECURITY)
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
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;

-- 6. CREACIÓN DE POLÍTICAS RLS

-- Acceso total para administradores (autenticados) a tablas de gestión
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.app_meta FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Políticas para Pedidos (Orders)
CREATE POLICY "Allow anonymous insert for orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow read for authenticated users" ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow update for authenticated users" ON public.orders FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anonymous insert for order items" ON public.order_items FOR INSERT WITH CHECK (true);


-- 7. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to upload product images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to update product images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to delete their own product images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'product_images');


-- 8. DATOS INICIALES
INSERT INTO public.app_meta(key, value) VALUES ('revenue_stats', '{"total_revenue": 0}') ON CONFLICT(key) DO NOTHING;

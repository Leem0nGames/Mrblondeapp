
-- Script de Base de Datos para Blonde Orders
-- Versión: 1.0
-- Este script es idempotente y puede ser ejecutado de forma segura.

-- 1. Limpieza y Reseteo (en orden inverso de creación)
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision) CASCADE;

DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;

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

DROP TYPE IF EXISTS public.client_status_enum CASCADE;
DROP TYPE IF EXISTS public.order_status_enum CASCADE;
DROP TYPE IF EXISTS public.agreement_client_type_enum CASCADE;


-- 2. Creación de Tipos (Enums)
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status_enum AS ENUM ('pending', 'completed');
CREATE TYPE public.agreement_client_type_enum AS ENUM ('barberia', 'distribuidor', 'especial');


-- 3. Creación de Tablas
CREATE TABLE public.app_settings (
    key TEXT PRIMARY KEY,
    value TEXT
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
    base_price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage DOUBLE PRECISION,
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
    rules JSONB,
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
    client_type public.agreement_client_type_enum,
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
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

CREATE TABLE public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status public.client_status_enum NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token TEXT UNIQUE,
    agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id),
    agreement_id UUID NOT NULL REFERENCES public.agreements(id),
    total_amount DOUBLE PRECISION NOT NULL,
    status public.order_status_enum NOT NULL DEFAULT 'pending',
    client_name_cache TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    quantity INTEGER NOT NULL,
    price_per_unit DOUBLE PRECISION NOT NULL
);

-- 4. Creación de Vistas
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    (SELECT count(*) FROM public.agreement_promotions WHERE agreement_id = agr.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions WHERE agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < now() - interval '3 days') as overdue_orders_count,
    (SELECT count(*) FROM public.clients) as total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions;

-- 5. Creación de Funciones (RPC)
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending' AND created_at < now() - interval '3 days');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent double precision, average_order_value double precision, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(sum(total_amount), 0.0) as total_spent,
        COALESCE(avg(total_amount), 0.0) as average_order_value,
        count(*)::bigint as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void AS $$
BEGIN
    -- Esta función se deja vacía intencionalmente.
    -- Las agregaciones se manejan mediante la vista dashboard_stats para mayor consistencia.
END;
$$ LANGUAGE plpgsql;


-- 6. Habilitación de Row-Level Security (RLS)
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


-- 7. Creación de Políticas RLS
-- El rol 'service_role' tiene acceso total, usado por las Server Actions.
-- Los usuarios anónimos y autenticados no tienen acceso por defecto.
CREATE POLICY "Allow full access for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow full access for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- app_settings puede ser leído por cualquiera, pero solo modificado por service_role.
CREATE POLICY "Allow read access for all" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Allow write access for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- 8. Creación de Buckets y Políticas de Storage
-- Crear buckets si no existen.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('app_assets', 'app_assets', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas para product_images
DROP POLICY IF EXISTS "Allow public read on product images" ON storage.objects;
CREATE POLICY "Allow public read on product images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

DROP POLICY IF EXISTS "Allow admin write on product images" ON storage.objects;
CREATE POLICY "Allow admin write on product images"
ON storage.objects FOR ALL
USING (bucket_id = 'product_images' AND auth.role() = 'service_role')
WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'service_role' );

-- Políticas para app_assets
DROP POLICY IF EXISTS "Allow public read on app assets" ON storage.objects;
CREATE POLICY "Allow public read on app assets"
ON storage.objects FOR SELECT
USING ( bucket_id = 'app_assets' );

DROP POLICY IF EXISTS "Allow admin write on app assets" ON storage.objects;
CREATE POLICY "Allow admin write on app assets"
ON storage.objects FOR ALL
USING ( bucket_id = 'app_assets' AND auth.role() = 'service_role' )
WITH CHECK ( bucket_id = 'app_assets' AND auth.role() = 'service_role' );

-- 9. Inserción de Datos Iniciales (Seeding)
INSERT INTO public.app_settings (key, value) VALUES
('vat_percentage', '21'),
('whatsapp_number', '5491112345678')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

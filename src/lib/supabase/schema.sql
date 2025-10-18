
-- ▀█▀.█▄█.█▀▀.█▄.█.█▄▀   █▄█.█▀█.█▀▀.█▀▄   █▀▀.█▀█.█▀.█▀▀.█▄.█.█▀█.█▀▀.▀█▀
-- .█..█.█.█▀..█.▀█.█.█   █.█.█▄█.█▀..█▄▀   █▀..█.█.█▀.█▀..█.▀█.█▄█.█▀..-█-
-- =================================================================


-- 1. Limpieza y Reseteo
-- =================================================================
-- Elimina todos los objetos en el orden inverso de dependencia para evitar errores.
-- Usamos CASCADE para manejar dependencias automáticamente.

DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

DROP POLICY IF EXISTS "Allow public read access to logo" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin access to assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin access to product images" ON storage.objects;

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;

DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;


-- 2. Creación de Tipos (Enums)
-- =================================================================

CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');


-- 3. Creación de Tablas
-- =================================================================

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

CREATE TABLE public.price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name TEXT NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL
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
    fiscal_status TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);

CREATE TABLE public.price_list_items (
    price_list_id UUID NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL,
    volume_price NUMERIC(10, 2),
    PRIMARY KEY (price_list_id, product_id)
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
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_amount NUMERIC(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);


-- 4. Creación de Vistas
-- =================================================================

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id)::int AS promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions asc_link WHERE asc_link.agreement_id = agr.id)::int AS sales_condition_count
FROM
    public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*)::int FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COUNT(*)::int FROM public.clients) AS total_clients,
    (SELECT COUNT(*)::int FROM public.price_lists) AS total_pricelists,
    (SELECT COUNT(*)::int FROM public.promotions) AS total_promotions,
    (SELECT COUNT(*)::int FROM public.sales_conditions) AS total_sales_conditions,
    (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count,
    (SELECT value FROM public.app_settings WHERE key = 'vat_percentage')::numeric AS vat_percentage
;

-- 5. Creación de Funciones
-- =================================================================

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS table (pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days'));
END;
$$;


CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS table(total_spent numeric, total_orders bigint, average_order_value numeric)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COUNT(o.id) as total_orders,
        COALESCE(AVG(o.total_amount), 0) as average_order_value
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE sql
AS $$
    -- This is a placeholder for a more robust revenue tracking system.
    -- In a real-world scenario, you might update an aggregated stats table.
    -- For this app, the `dashboard_stats` view calculates this dynamically,
    -- so this function is effectively a no-op but kept for conceptual integrity.
$$;


-- 6. Políticas de Seguridad a Nivel de Fila (RLS)
-- =================================================================
-- Habilitar RLS en todas las tablas relevantes
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Políticas para Administradores (rol 'service_role')
CREATE POLICY "Allow admin full access on products" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on agreements" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on clients" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on orders" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on order_items" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access on app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');


-- Políticas para Acceso Anónimo/Público (rol 'anon')
-- Los usuarios anónimos pueden leer la información necesaria para la página de pedido.
CREATE POLICY "Allow anon read on agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow anon read on agreement_promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read on promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read on price_lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow anon read on price_list_items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow anon read on products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow anon read on clients for order" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow anon read on settings for order" ON public.app_settings FOR SELECT USING (true);

-- Permitir a usuarios anónimos (clientes) crear pedidos y sus items
CREATE POLICY "Allow anon to create orders and items" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Permitir a usuarios anónimos (clientes) completar su onboarding
CREATE POLICY "Allow anon to read their onboarding" ON public.clients FOR SELECT USING (onboarding_token IS NOT NULL);
CREATE POLICY "Allow anon to update their onboarding" ON public.clients FOR UPDATE USING (onboarding_token IS NOT NULL);


-- 7. Políticas de Almacenamiento (Storage)
-- =================================================================
CREATE POLICY "Allow public read access to logo" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow admin access to assets" ON storage.objects FOR ALL USING (bucket_id = 'app_assets' AND auth.role() = 'service_role') WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin access to product images" ON storage.objects FOR ALL USING (bucket_id = 'product_images' AND auth.role() = 'service_role') WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'service_role');


-- 8. Datos Iniciales (Seed)
-- =================================================================
-- Inserta la configuración inicial de la aplicación si no existe.
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT (key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '5491123456789') ON CONFLICT (key) DO NOTHING;

-- ▀█▀.█▄█.█▀▀.█▄.█.█▄▀   █▄█.█▀█.█▀▀.█▀▄   █▀▀.█▀█.█▀.█▀▀.█▄.█.█▀█.█▀▀.▀█▀
-- .█..█.█.█▀..█.▀█.█.█   █.█.█▄█.█▀..█▄▀   █▀..█.█.█▀.█▀..█.▀█.█▄█.█▀..-█-
-- =================================================================
-- Fin del script

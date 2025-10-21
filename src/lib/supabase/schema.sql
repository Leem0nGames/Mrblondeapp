-- ------------------------------------------------------------------------------------------------
--  Blonde Orders - Supabase Schema
--  Version: 2.0
--
--  Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier momento.
--  Se encargará de limpiar y reconfigurar el esquema de la base de datos por completo.
-- ------------------------------------------------------------------------------------------------

-- Iniciar una transacción para asegurar que todo el script se ejecute o falle como una unidad.
BEGIN;

-- ------------------------------------------------------------------------------------------------
--  1. LIMPIEZA Y REINICIO DE ESQUEMA
--  Drop de todos los objetos en orden inverso a su creación para evitar errores de dependencia.
--  Se utiliza `CASCADE` para eliminar automáticamente objetos dependientes (vistas, políticas, etc.).
-- ------------------------------------------------------------------------------------------------

-- Drop Policies (Storage)
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated write on app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated write on product_images" ON storage.objects CASCADE;

-- Drop Policies (Tables)
DROP POLICY IF EXISTS "Allow all for service_role on sales_conditions" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on price_lists" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role on promotions" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow read for authenticated users" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow insert for anonymous users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow read for related client or admin" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.app_settings CASCADE;

-- Drop Functions & Views
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Drop Tables
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;

-- Drop Types
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.promotion_type CASCADE;
DROP TYPE IF EXISTS public.sales_condition_type CASCADE;


-- ------------------------------------------------------------------------------------------------
--  2. CREACIÓN DE TIPOS (ENUMS)
-- ------------------------------------------------------------------------------------------------
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');
CREATE TYPE public.sales_condition_type AS ENUM ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');


-- ------------------------------------------------------------------------------------------------
--  3. CREACIÓN DE TABLAS
-- ------------------------------------------------------------------------------------------------

CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    description text,
    category text,
    image_url text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2)
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
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
    status public.client_status NOT NULL,
    onboarding_token text NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);

CREATE TABLE public.agreement_promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    UNIQUE(agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    UNIQUE(agreement_id, sales_condition_id)
);

CREATE TABLE public.price_list_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL,
    volume_price numeric,
    UNIQUE(price_list_id, product_id)
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value jsonb
);

-- ------------------------------------------------------------------------------------------------
--  4. CREACIÓN DE VISTAS
-- ------------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
    o.*,
    (o.created_at::date + '30 days'::interval) AS due_date,
    (o.status = 'pending' AND (o.created_at::date + '30 days'::interval) < now()::date) AS overdue,
    GREATEST(0, (now()::date - (o.created_at::date + '30 days'::interval)::date)) AS days_overdue
FROM public.orders o;

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

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

-- ------------------------------------------------------------------------------------------------
--  5. CREACIÓN DE FUNCIONES (RPC)
-- ------------------------------------------------------------------------------------------------

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
        COALESCE(sum(o.total_amount), 0) AS total_spent,
        COALESCE(avg(o.total_amount), 0) AS average_order_value,
        count(o.id) AS total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk int) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.contact_name AS name,
        COALESCE(sum(o.total_amount), 0) AS value,
        (SELECT count(*)::int FROM public.orders_with_overdue_status o_overdue WHERE o_overdue.client_id = c.id AND o_overdue.overdue = true) AS risk
    FROM public.clients c
    LEFT JOIN public.orders o ON c.id = o.client_id
    WHERE c.status = 'active'
    GROUP BY c.id, c.contact_name
    ORDER BY value DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- Placeholder. En una app real, esto sería más robusto o se manejaría de otra forma.
END;
$$ LANGUAGE plpgsql;


-- ------------------------------------------------------------------------------------------------
--  6. HABILITACIÓN DE RLS Y CREACIÓN DE POLÍTICAS
-- ------------------------------------------------------------------------------------------------

-- Habilitar RLS en todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Políticas de Seguridad
CREATE POLICY "Allow all for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Política para que usuarios anónimos (clientes) puedan crear pedidos
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);

-- Política para lectura pública de imágenes de producto
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
-- Política para que admins puedan subir imágenes de producto
CREATE POLICY "Allow authenticated write on product_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write on product_images for update" ON storage.objects FOR UPDATE WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
-- Política para lectura pública del logo
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
-- Política para que admins puedan subir logo
CREATE POLICY "Allow authenticated write on app_assets" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated write on app_assets for update" ON storage.objects FOR UPDATE WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');

-- ------------------------------------------------------------------------------------------------
--  7. DATOS INICIALES (Opcional, para configuración básica)
-- ------------------------------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value) VALUES
('whatsapp_number', '"5491112345678"'),
('vat_percentage', '21')
ON CONFLICT(key) DO NOTHING;

-- Finalizar la transacción
COMMIT;

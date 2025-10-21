
-- 1. Limpieza y Reseteo
-- Drop policies first
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage product_images" ON storage.objects CASCADE;

-- Then drop other objects
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.promotion_type CASCADE;
DROP TYPE IF EXISTS public.sales_condition_type CASCADE;

-- 2. Crear Tipos (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed', 'cancelled');
CREATE TYPE public.promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');
CREATE TYPE public.sales_condition_type AS ENUM ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');


-- 3. Crear Tablas
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2) DEFAULT 0.00,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
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
    status public.client_status NOT NULL,
    onboarding_token text UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text,
    latitude double precision,
    longitude double precision
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
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

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value jsonb
);

-- 4. Crear Vistas y Funciones
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    (SELECT count(*) FROM public.agreement_promotions apro WHERE apro.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
    o.*,
    (now()::date - o.created_at::date) as days_since_creation,
    CASE
        WHEN o.status = 'pending' AND (now()::date - o.created_at::date) > 2 THEN true
        ELSE false
    END as is_overdue,
    (o.created_at::date + '30 days'::interval)::date as due_date
FROM public.orders o;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE is_overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql
AS $$
    SELECT
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::int FROM public.orders_with_overdue_status WHERE is_overdue = true);
$$;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- This is a placeholder. A real implementation would be more robust and might update an aggregate table.
END;
$$ LANGUAGE plpgsql;

-- 5. Habilitar Row-Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 6. Crear Políticas de RLS
-- Políticas permisivas para administradores autenticados
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated');

-- Políticas de lectura pública para datos necesarios en páginas no autenticadas (pedido)
-- (No se necesitan si el acceso se hace con anon key que saltea RLS, pero es buena práctica)

-- 7. Configurar Storage y Políticas
-- Insertar buckets y sus políticas
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true),
       ('app_assets', 'app_assets', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Allow public read on product_images" ON storage.objects
FOR SELECT USING (bucket_id = 'product_images');

CREATE POLICY "Allow admin to manage product_images" ON storage.objects
FOR ALL USING (bucket_id = 'product_images' AND auth.role() = 'authenticated');

CREATE POLICY "Allow public read on app_assets" ON storage.objects
FOR SELECT USING (bucket_id = 'app_assets');

CREATE POLICY "Allow admin to manage app_assets" ON storage.objects
FOR ALL USING (bucket_id = 'app_assets' AND auth.role() = 'authenticated');

-- 8. Datos Iniciales (Opcional)
INSERT INTO public.app_settings (key, value) VALUES 
    ('vat_percentage', '21'),
    ('whatsapp_number', '"5491112345678"'),
    ('logo_url', 'null')
ON CONFLICT(key) DO UPDATE SET value = EXCLUDED.value;

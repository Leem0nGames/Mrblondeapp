
-- 1. Limpieza Inicial (Idempotencia)
-- Elimina todos los objetos en orden inverso de dependencia para evitar errores.
-- El uso de CASCADE simplifica la eliminación de dependencias.

-- Drop Policies first
DROP POLICY IF EXISTS "Allow all for service_role on sales_conditions" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all for service_role on price_lists" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all for service_role on promotions" ON public.promotions;
DROP POLICY IF EXISTS "Allow insert for anonymous users" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated users to read their own orders" ON public.orders;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.clients;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreements;
DROP POLICY IF EXISTS "Allow read access to everyone" ON public.products;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.products;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.app_settings;

-- Storage policies
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow insert for authenticated users on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow insert for authenticated users on app_assets" ON storage.objects;

-- Drop Views
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Drop Functions
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;

-- Drop Tables
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;

-- Drop Types
DROP TYPE IF EXISTS public.client_status_enum;
DROP TYPE IF EXISTS public.client_type_enum;
DROP TYPE IF EXISTS public.order_status_enum;
DROP TYPE IF EXISTS public.promotion_type_enum;
DROP TYPE IF EXISTS public.sales_condition_type_enum;


-- 2. Creación de Tipos (ENUMs)
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type_enum AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status_enum AS ENUM ('pending', 'completed');
CREATE TYPE public.promotion_type_enum AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');
CREATE TYPE public.sales_condition_type_enum AS ENUM ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');


-- 3. Creación de Tablas
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
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2)
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type_enum NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
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
    status public.client_status_enum NOT NULL,
    onboarding_token text DEFAULT gen_random_uuid() UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status public.order_status_enum NOT NULL,
    client_name_cache text,
    notes text,
    due_date date GENERATED ALWAYS AS (((created_at AT TIME ZONE 'UTC')::date + '30 days'::interval)) STORED
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10,2) NOT NULL
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);

-- 4. Vistas y Funciones
CREATE VIEW public.orders_with_overdue_status AS
SELECT
    *,
    (status = 'pending' AND due_date < (now() AT TIME ZONE 'UTC')::date) AS is_overdue,
    GREATEST(0, ((now() AT TIME ZONE 'UTC')::date - due_date)) as days_overdue
FROM public.orders;

CREATE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE is_overdue = true) as overdue_orders_count,
    (SELECT count(*) FROM public.clients) as total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::int FROM public.orders_with_overdue_status WHERE is_overdue = true);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(sum(total_amount), 0) as total_spent,
        COALESCE(avg(total_amount), 0) as average_order_value,
        count(*)::bigint as total_orders
    FROM public.orders
    WHERE client_id = p_client_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
    -- This is a placeholder. In a real scenario, you'd update an aggregate table.
$$ LANGUAGE plpgsql;

-- 5. Habilitar Row Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 6. Políticas de RLS
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow read access to everyone" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow all for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to read their own orders" ON public.orders FOR SELECT TO authenticated USING (auth.uid() = client_id);
CREATE POLICY "Allow insert for authenticated users" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow all for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');


-- 7. Storage Policies
-- Policies for the 'product_images' bucket
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow insert for authenticated users on product_images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product_images');

-- Policies for the 'app_assets' bucket
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow insert for authenticated users on app_assets" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'app_assets');

-- 8. Seed de Datos Iniciales (opcional pero recomendado)
INSERT INTO app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT (key) DO NOTHING;
INSERT INTO app_settings (key, value) VALUES ('whatsapp_number', '5491123456789') ON CONFLICT (key) DO NOTHING;

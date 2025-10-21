
-- 1. Limpieza y Reseteo
-- Drop policies first to avoid dependency issues
DROP POLICY IF EXISTS "Allow all for service_role" ON public.app_settings;
DROP POLICY IF EXISTS "Allow anon read" ON public.app_settings;
DROP POLICY IF EXISTS "Allow insert for anon" ON public.orders;
DROP POLICY IF EXISTS "Allow insert for authenticated" ON public.orders;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.orders;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.orders;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.clients;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreements;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.agreements;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.promotions;
DROPPOLICY IF EXISTS "Allow anon read-only" ON public.promotions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.products;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.products;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.price_lists;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.order_items;
DROP POLICY IF EXISTS "Allow anon read-only" ON public.order_items;
DROP POLICY IF EXISTS "Give anon access to public folder" ON storage.objects;
DROP POLICY IF EXISTS "Give auth users access to folder" ON storage.objects;

-- Drop views and functions that depend on tables
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_clients_heatmap_data() CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue CASCADE;


-- Drop tables
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;


-- Drop types (enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;

-- 2. Creación de Tipos (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');

-- 3. Creación de Tablas
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2) CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    price numeric NOT NULL,
    volume_price numeric,
    PRIMARY KEY (price_list_id, product_id)
);
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status client_status NOT NULL,
    onboarding_token uuid,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    fiscal_status text
);
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    total_amount numeric NOT NULL,
    status order_status NOT NULL,
    client_name_cache text,
    notes text,
    due_date date GENERATED ALWAYS AS ((created_at + '30 days'::interval')) STORED
);
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);

-- 4. Creación de Vistas y Funciones
CREATE OR REPLACE VIEW public.orders_with_overdue AS
SELECT
    *,
    (status = 'pending' AND due_date < CURRENT_DATE) AS overdue
FROM
    public.orders;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COUNT(*) FROM public.orders_with_overdue WHERE overdue = true) as overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    agr.agreement_name,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This is a placeholder. In a real app, you would update a summary table.
    -- For this MVP, dashboard_stats view calculates it on the fly.
END;
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

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint)
LANGUAGE sql
AS $$
    SELECT
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') as pending_orders_count,
        (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') as pending_clients_count,
        (SELECT COUNT(*) FROM public.orders_with_overdue WHERE overdue = true) as overdue_orders_count;
$$;

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk integer)
LANGUAGE sql
AS $$
    WITH client_revenue AS (
        SELECT
            c.id,
            c.contact_name,
            COALESCE(SUM(o.total_amount), 0) AS total_revenue
        FROM
            public.clients c
        LEFT JOIN
            public.orders o ON c.id = o.client_id AND o.status = 'completed'
        WHERE c.status = 'active'
        GROUP BY
            c.id, c.contact_name
    ),
    client_risk AS (
        SELECT
            client_id,
            COUNT(*) AS overdue_count
        FROM
            public.orders_with_overdue
        WHERE
            overdue = true
        GROUP BY
            client_id
    )
    SELECT
        cr.id,
        cr.contact_name,
        cr.total_revenue AS value,
        COALESCE(risk.overdue_count, 0)::integer AS risk
    FROM
        client_revenue cr
    LEFT JOIN
        client_risk risk ON cr.id = risk.client_id
    WHERE cr.total_revenue > 0
    ORDER BY total_revenue DESC;
$$;


-- 5. Habilitar Row-Level Security (RLS)
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- 6. Políticas de RLS
CREATE POLICY "Allow all for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow anon read" ON public.app_settings FOR SELECT TO anon USING (true);
CREATE POLICY "Allow insert for anon" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Enable read access for all users" ON public.orders FOR SELECT USING (true);
CREATE POLICY "Allow all for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.clients FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.agreements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.agreement_promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.agreement_sales_conditions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.sales_conditions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.products FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.price_lists FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.price_list_items FOR SELECT TO anon USING (true);
CREATE POLICY "Allow all for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Allow anon read-only" ON public.order_items FOR SELECT TO anon USING (true);


-- 7. Políticas de Storage
-- Allow anonymous access to the public 'app_assets' folder
CREATE POLICY "Give anon access to public folder" ON storage.objects FOR SELECT
    TO anon
    USING (bucket_id = 'app_assets');
-- Allow authenticated users to manage their own product images
CREATE POLICY "Give auth users access to folder" ON storage.objects FOR ALL
    TO authenticated
    USING (bucket_id = 'product_images');


-- 8. Inserción de Datos Iniciales
INSERT INTO public.app_settings (key, value) VALUES 
('whatsapp_number', '5491123456789'),
('vat_percentage', '21')
ON CONFLICT(key) DO NOTHING;

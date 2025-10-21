
-- 1. LIMPIEZA Y REINICIO
-- Elimina los objetos existentes en el orden inverso a su creación para evitar errores de dependencia.
-- SIEMPRE usa DROP ... CASCADE para manejar las dependencias automáticamente.

DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_clients_heatmap_data() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;

DROP TYPE IF EXISTS public.client_status_enum CASCADE;
DROP TYPE IF EXISTS public.client_type_enum CASCADE;
DROP TYPE IF EXISTS public.order_status_enum CASCADE;
DROP TYPE IF EXISTS public.promotion_type_enum CASCADE;

-- 2. CREACIÓN DE TIPOS (ENUMS)
-- Los enums deben crearse antes que las tablas que los utilizan.

CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type_enum AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status_enum AS ENUM ('pending', 'completed');
CREATE TYPE public.promotion_type_enum AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');

-- 3. CREACIÓN DE TABLAS

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    price numeric NOT NULL,
    volume_price numeric,
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name character varying NOT NULL UNIQUE,
    client_type client_type_enum NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit character varying UNIQUE,
    contact_name character varying,
    contact_dni character varying,
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email character varying UNIQUE,
    instagram character varying,
    status client_status_enum NOT NULL,
    onboarding_token text DEFAULT gen_random_uuid() UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status character varying
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric NOT NULL,
    status order_status_enum NOT NULL,
    client_name_cache character varying NOT NULL,
    notes text,
    due_date date GENERATED ALWAYS AS (((created_at AT TIME ZONE 'UTC')::date + '30 days'::interval)) STORED
);

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);

CREATE TABLE public.app_settings (
    key character varying PRIMARY KEY,
    value text
);

-- 4. CREACIÓN DE VISTAS Y FUNCIONES

CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
    *,
    (status = 'pending' AND due_date < (now() at time zone 'utc')::date) AS overdue,
    GREATEST(0, ((now() at time zone 'utc')::date - due_date)) AS days_overdue
FROM
    public.orders;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;
    
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint)
LANGUAGE sql
AS $$
    SELECT
        (SELECT count(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count;
$$;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COALESCE(AVG(total_amount), 0) AS average_order_value,
        COUNT(id) AS total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
$$;

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name character varying, value numeric, risk integer)
LANGUAGE sql
AS $$
    SELECT
        c.id,
        c.contact_name AS name,
        COALESCE(sum(o.total_amount), 0) AS value,
        COALESCE(sum(CASE WHEN o.status = 'pending' AND o.due_date < (now() at time zone 'utc')::date THEN 1 ELSE 0 END), 0)::integer AS risk
    FROM
        public.clients c
    LEFT JOIN
        public.orders o ON c.id = o.client_id
    WHERE c.status = 'active'
    GROUP BY c.id, c.contact_name;
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This is a placeholder function as direct manipulation of aggregated stats is complex.
    -- In a real scenario, you might update a summary table or rely on the view.
END;
$$;

-- 5. HABILITACIÓN DE ROW-LEVEL SECURITY (RLS)
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

-- 6. CREACIÓN DE POLÍTICAS DE RLS

-- Políticas para permitir acceso total al rol de servicio (administrador del backend)
CREATE POLICY "Allow all for service_role on products" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreements" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on clients" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on orders" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on order_items" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Políticas para acceso público/anónimo
CREATE POLICY "Allow anon read on products" ON public.products FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on price_lists" ON public.price_lists FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on price_list_items" ON public.price_list_items FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on promotions" ON public.promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on agreements" ON public.agreements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on agreement_promotions" ON public.agreement_promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on clients" ON public.clients FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on app_settings" ON public.app_settings FOR SELECT TO anon USING (true);

-- Política para que usuarios anónimos (clientes) puedan crear pedidos
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for anonymous users on order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);

-- Política para que clientes puedan actualizar sus propios datos durante el onboarding
CREATE POLICY "Allow update for onboarding clients" ON public.clients FOR UPDATE TO anon
USING (onboarding_token IS NOT NULL)
WITH CHECK (onboarding_token IS NOT NULL);

-- 7. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
CREATE POLICY "Allow all on product_images" ON storage.objects FOR ALL
USING (bucket_id = 'product_images')
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow all on app_assets" ON storage.objects FOR ALL
USING (bucket_id = 'app_assets')
WITH CHECK (bucket_id = 'app_assets');


-- 8. DATOS INICIALES
INSERT INTO public.app_settings (key, value)
VALUES ('whatsapp_number', ''), ('vat_percentage', '21'), ('logo_url', null)
ON CONFLICT(key) DO NOTHING;

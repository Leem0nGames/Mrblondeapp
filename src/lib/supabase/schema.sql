
-- Versión del esquema: 2.0
-- Limpieza y reseteo del entorno
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;

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
DROP TABLE IF EXISTS public.app_meta CASCADE;

DROP TYPE IF EXISTS public.client_status;
DROP TYPE IF EXISTS public.client_type;
DROP TYPE IF EXISTS public.order_status;

-- Creación de Tipos (ENUMS)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');

-- Creación de Tablas
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price double precision NOT NULL,
    volume_price double precision,
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name character varying NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    contact_name text,
    contact_dni text,
    cuit text UNIQUE,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount double precision NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text,
    notes text
);

CREATE TABLE public.order_items (
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit double precision NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE public.app_meta (
    key character varying PRIMARY KEY,
    value jsonb
);

-- Vistas
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count;


-- Funciones RPC
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent double precision, total_orders bigint, average_order_value double precision) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0.0) as total_spent,
        COUNT(o.id) as total_orders,
        COALESCE(AVG(o.total_amount), 0.0) as average_order_value
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void AS $$
DECLARE
    current_revenue double precision;
BEGIN
    -- This function is a placeholder for a more complex logic.
    -- In a real-world scenario, you might update a summary table.
    -- For now, this function doesn't do anything to avoid concurrency issues
    -- with the dashboard_stats view. The view calculates revenue dynamically.
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;


-- Habilitar Row-Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
-- Tablas públicas (lectura para todos)
CREATE POLICY "Allow public read access" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.agreement_sales_conditions FOR SELECT USING (true);

-- Permisos de escritura para administradores (autenticados)
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.app_meta FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- Políticas para Clientes (usuarios anónimos)
CREATE POLICY "Allow anonymous insert for orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous insert for order items" ON public.order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous update for clients" ON public.clients FOR UPDATE USING (onboarding_token = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token')::uuid) WITH CHECK (onboarding_token = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token')::uuid);


-- Políticas para Administradores sobre Pedidos
CREATE POLICY "Allow admin read access to orders" ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin update access to orders" ON public.orders FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin read access to order items" ON public.order_items FOR SELECT USING (auth.role() = 'authenticated');

-- Políticas para Storage (Imágenes de productos)
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow admin write access to product images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
CREATE POLICY "Allow admin update access to product images" ON storage.objects FOR UPDATE WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');

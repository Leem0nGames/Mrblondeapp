
-- Versión 1.2.0 - Refactorización de Políticas y Vistas

-- 1. Limpieza y Reseteo (Orden Inverso de Creación)
-- Drop de Vistas que dependen de tablas
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;

-- Drop de Políticas
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.clients;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow read for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow update for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow anonymous insert for orders" ON public.orders;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.order_items;

-- Drop de Funciones
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.get_notification_counts();

-- Drop de Tablas (CASCADE para manejar dependencias automáticamente)
DROP TABLE IF EXISTS public.app_meta CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;

-- Drop de Tipos (Enums)
DROP TYPE IF EXISTS public.client_status;
DROP TYPE IF EXISTS public.client_type;
DROP TYPE IF EXISTS public.order_status;


-- 2. Creación de Tipos (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');

-- 3. Creación de Tablas
CREATE TABLE public.app_meta (
    key text PRIMARY KEY,
    value jsonb
);

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token uuid NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
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

-- 4. Creación de Vistas
CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;

CREATE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;

-- 5. Creación de Funciones
CREATE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
DECLARE
    current_revenue numeric;
BEGIN
    SELECT (value->>'total_revenue')::numeric INTO current_revenue FROM app_meta WHERE key = 'stats';
    IF current_revenue IS NULL THEN
        current_revenue := 0;
    END IF;
    UPDATE app_meta SET value = jsonb_set(value, '{total_revenue}', (current_revenue + amount_to_add)::text::jsonb) WHERE key = 'stats';
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value,
        COUNT(o.id) AS total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;

-- 6. Habilitación de RLS (Row-Level Security)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;

-- 7. Creación de Políticas RLS
-- Políticas permisivas para usuarios administradores autenticados
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.app_meta FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Políticas para la tabla de pedidos
CREATE POLICY "Allow read for authenticated users" ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow update for authenticated users" ON public.orders FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anonymous insert for orders" ON public.orders FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anonymous insert for order items" ON public.order_items FOR INSERT WITH CHECK (true);


-- 8. Políticas de Almacenamiento (Storage)
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to upload product images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users to update product images" ON storage.objects FOR UPDATE WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');

-- 9. Datos Iniciales
INSERT INTO public.app_meta (key, value) VALUES ('version', '"1.0.0"');
INSERT INTO public.app_meta (key, value) VALUES ('stats', '{"total_revenue": 0}');

-- 1. Limpieza y Reset
-- Eliminar objetos existentes en orden inverso a su creación.
-- SIEMPRE usar DROP ... CASCADE para manejar dependencias automáticamente.

-- Funciones y Vistas
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Tablas
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;


-- 2. Creación de Tablas
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN DEFAULT true NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage NUMERIC(5, 2) CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL,
    volume_price NUMERIC(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name TEXT NOT NULL UNIQUE,
    client_type TEXT NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status TEXT NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token TEXT UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    fiscal_status TEXT,
    latitude double precision,
    longitude double precision
);
CREATE INDEX ON public.clients(status);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    client_name_cache text NOT NULL,
    notes TEXT
);
CREATE INDEX ON public.orders(status);
CREATE INDEX ON public.orders(created_at);

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);

CREATE TABLE public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB
);

-- 3. Creación de Vistas y Funciones

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions WHERE agreement_id = a.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions WHERE agreement_id = a.id) as sales_condition_count
FROM
    public.agreements a;


CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement')) as total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) as overdue_orders_count;


CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent NUMERIC, average_order_value NUMERIC, total_orders BIGINT)
LANGUAGE plpgsql
AS $$
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
$$;


CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql
AS $$
  SELECT
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
    (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval))
$$;

-- 4. Habilitación de RLS
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
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 5. Creación de Políticas RLS

-- Políticas para 'products'
CREATE POLICY "Allow all access for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.products FOR SELECT USING (true);

-- Políticas para 'price_lists'
CREATE POLICY "Allow all access for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.price_lists FOR SELECT USING (true);

-- Políticas para 'price_list_items'
CREATE POLICY "Allow all access for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.price_list_items FOR SELECT USING (true);

-- Políticas para 'promotions'
CREATE POLICY "Allow all access for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.promotions FOR SELECT USING (true);

-- Políticas para 'sales_conditions'
CREATE POLICY "Allow all access for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.sales_conditions FOR SELECT USING (true);

-- Políticas para 'agreements'
CREATE POLICY "Allow all access for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.agreements FOR SELECT USING (true);

-- Políticas para 'clients'
CREATE POLICY "Allow all access for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users based on token" ON public.clients FOR SELECT USING (onboarding_token = current_setting('request.headers', true)::json->>'x-onboarding-token');
CREATE POLICY "Allow anonymous update for onboarding" ON public.clients FOR UPDATE USING (onboarding_token IS NOT NULL AND status = 'pending_onboarding') WITH CHECK (onboarding_token IS NOT NULL);

-- Políticas para 'agreement_promotions'
CREATE POLICY "Allow all access for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.agreement_promotions FOR SELECT USING (true);

-- Políticas para 'agreement_sales_conditions'
CREATE POLICY "Allow all access for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access for anonymous users" ON public.agreement_sales_conditions FOR SELECT USING (true);

-- Políticas para 'orders'
CREATE POLICY "Allow all access for authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT WITH CHECK (true);

-- Políticas para 'order_items'
CREATE POLICY "Allow all access for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow insert for anonymous users" ON public.order_items FOR INSERT WITH CHECK (true);

-- Políticas para 'app_settings'
CREATE POLICY "Allow read access to everyone" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Allow all access for authenticated users" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 6. Políticas de Almacenamiento (Storage)
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');

DROP POLICY IF EXISTS "Allow authenticated write on app_assets" ON storage.objects;
CREATE POLICY "Allow authenticated write on app_assets" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');

DROP POLICY IF EXISTS "Allow authenticated write on product_images" ON storage.objects;
CREATE POLICY "Allow authenticated write on product_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated update on product_images" ON storage.objects FOR UPDATE WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');

-- 7. Datos Iniciales (Opcional)
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21'::jsonb), ('whatsapp_number', '""'::jsonb)
ON CONFLICT(key) DO NOTHING;

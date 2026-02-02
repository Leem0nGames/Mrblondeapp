-- 1. Script de Limpieza
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision) CASCADE;

-- 2. Tipos
DROP TYPE IF EXISTS public.client_status;
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');

DROP TYPE IF EXISTS public.order_status;
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');

DROP TYPE IF EXISTS public.promotion_type;
CREATE TYPE public.promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');

DROP TYPE IF EXISTS public.sales_condition_type;
CREATE TYPE public.sales_condition_type AS ENUM ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');

-- 3. Tablas
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN DEFAULT true NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage NUMERIC(5, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    volume_price NUMERIC(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE IF NOT EXISTS public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name TEXT NOT NULL UNIQUE,
    client_type TEXT NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status public.client_status NOT NULL,
    onboarding_token TEXT UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    fiscal_status TEXT,
    latitude double precision,
    longitude double precision
);
CREATE INDEX IF NOT EXISTS clients_status_idx ON public.clients(status);
CREATE INDEX IF NOT EXISTS clients_agreement_id_idx ON public.clients(agreement_id);

CREATE TABLE IF NOT EXISTS public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache TEXT,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS public.order_items (
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE IF NOT EXISTS public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE IF NOT EXISTS public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB
);

-- 4. Vistas
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM
    public.agreements agr;


CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
  (SELECT COALESCE(sum(total_amount), (0)::numeric) AS sum FROM orders WHERE (status = 'completed'::order_status)) AS total_revenue,
  (SELECT COALESCE(sum(total_amount), (0)::numeric) AS sum FROM orders WHERE ((status = 'completed'::order_status) AND (created_at > (now() - '30 days'::interval)))) AS month_revenue,
  (SELECT count(*) AS count FROM clients WHERE (status = 'active'::client_status)) AS active_clients,
  (SELECT count(*) AS count FROM clients) AS total_clients,
  (SELECT count(*) AS count FROM price_lists) AS total_pricelists,
  (SELECT count(*) AS count FROM promotions) AS total_promotions,
  (SELECT count(*) AS count FROM sales_conditions) AS total_sales_conditions,
  (SELECT count(*) AS count FROM orders WHERE status = 'pending' AND created_at < (now() - '7 days'::interval)) as overdue_orders_count;


-- 5. Funciones
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COALESCE(AVG(o.total_amount), 0) as average_order_value,
        COUNT(o.id) as total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This function is a placeholder. In a real application, you might update
    -- an aggregated statistics table or emit an event.
    -- For simplicity, we'll just log it to the Postgres logs for now.
    RAISE LOG 'Incrementing total revenue by: %', amount_to_add;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql
AS $$
  SELECT
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending') AS pending_orders_count,
    (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - '7 days'::interval)) AS overdue_orders_count;
$$;


-- 6. Políticas de Seguridad (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.products FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.products FOR SELECT
USING (true);

ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.price_lists FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.price_lists FOR SELECT
USING (true);

ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.price_list_items FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.price_list_items FOR SELECT
USING (true);

ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.promotions FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.promotions FOR SELECT
USING (true);

ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.sales_conditions FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.sales_conditions FOR SELECT
USING (true);

ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.agreements FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.agreements FOR SELECT
USING (true);

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.clients FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow read access based on token or agreement" ON public.clients FOR SELECT
USING (
  (onboarding_token IS NOT NULL AND status = 'pending_onboarding') OR
  (agreement_id IS NOT NULL AND status = 'active')
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.orders FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow insert for any user" ON public.orders FOR INSERT
WITH CHECK (true);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.order_items FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow insert for any user" ON public.order_items FOR INSERT
WITH CHECK (true);

ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.agreement_promotions FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.agreement_promotions FOR SELECT
USING (true);

ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.agreement_sales_conditions FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.agreement_sales_conditions FOR SELECT
USING (true);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated admin" ON public.app_settings FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.app_settings FOR SELECT
USING (true);


-- 7. Políticas de Storage
DROP POLICY IF EXISTS "Allow public read access on product_images" ON storage.objects;
CREATE POLICY "Allow public read access on product_images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

DROP POLICY IF EXISTS "Allow insert and update for admin on product_images" ON storage.objects;
CREATE POLICY "Allow insert and update for admin on product_images" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
CREATE POLICY "Allow update for admin on product_images" ON storage.objects FOR UPDATE
USING (bucket_id = 'product_images' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow public read access on app_assets" ON storage.objects;
CREATE POLICY "Allow public read access on app_assets" ON storage.objects FOR SELECT
USING (bucket_id = 'app_assets');

DROP POLICY IF EXISTS "Allow insert and update for admin on app_assets" ON storage.objects;
CREATE POLICY "Allow insert and update for admin on app_assets" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');
CREATE POLICY "Allow update for admin on app_assets" ON storage.objects FOR UPDATE
USING (bucket_id = 'app_assets' AND auth.role() = 'authenticated');

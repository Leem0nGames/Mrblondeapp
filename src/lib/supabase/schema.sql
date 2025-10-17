-- ----------------------------
-- Cleanup and Reset
-- ----------------------------
-- Drop existing objects in reverse order of creation, using CASCADE to handle dependencies.
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;


-- ----------------------------
-- Types (Enums)
-- ----------------------------
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');


-- ----------------------------
-- Tables
-- ----------------------------
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT products_name_key UNIQUE (name)
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_lists_name_key UNIQUE (name)
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name character varying NOT NULL,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name)
);

CREATE TABLE public.clients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    cuit character varying,
    contact_name character varying,
    contact_dni character varying,
    address text,
    delivery_window text,
    email character varying,
    instagram character varying,
    status public.client_status NOT NULL,
    onboarding_token uuid NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status character varying,
    latitude double precision,
    longitude double precision,
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email)
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
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache character varying NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric(10,2) NOT NULL
);

CREATE TABLE public.app_meta (
    key character varying PRIMARY KEY,
    value jsonb
);

-- ----------------------------
-- Views
-- ----------------------------
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascnt FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;


CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month'::text, now())) AS month_revenue,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count;


-- ----------------------------
-- Functions
-- ----------------------------
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value,
        COUNT(o.id) AS total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
AS $$
DECLARE
    current_revenue numeric;
BEGIN
    -- This is a simplified example. A real-world scenario might use a transactions table.
    -- For simplicity, we use a single value in app_meta.
    SELECT (value->>'total_revenue')::numeric INTO current_revenue FROM public.app_meta WHERE key = 'metrics';

    IF current_revenue IS NULL THEN
        current_revenue := 0;
    END IF;

    UPDATE public.app_meta
    SET value = jsonb_set(COALESCE(value, '{}'::jsonb), '{total_revenue}', to_jsonb(current_revenue + amount_to_add))
    WHERE key = 'metrics';

    IF NOT FOUND THEN
        INSERT INTO public.app_meta(key, value) VALUES ('metrics', jsonb_build_object('total_revenue', amount_to_add));
    END IF;
END;
$$ LANGUAGE plpgsql;


-- ----------------------------
-- RLS (Row-Level Security)
-- ----------------------------
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;

-- Allow all access for authenticated service roles (admins)
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.app_meta FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Allow public read access to necessary tables for anonymous users
CREATE POLICY "Allow public read for products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read for price lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read for agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read for clients" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow public read for price list items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read for promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read for agreement_promotions" ON public.agreement_promotions FOR SELECT USING (true);

-- Allow anonymous users to submit onboarding forms (update their own client record)
CREATE POLICY "Allow anon update for their own client record" ON public.clients
FOR UPDATE USING (
  (SELECT onboarding_token FROM public.clients WHERE id = clients.id) = (
    current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token'
  )::uuid
);

-- Allow anonymous insert for orders
CREATE POLICY "Allow anonymous insert for orders" ON public.orders FOR INSERT
WITH CHECK (true);

-- Allow anonymous insert for order_items
CREATE POLICY "Allow anonymous insert for order_items" ON public.order_items FOR INSERT
WITH CHECK (true);

-- ----------------------------
-- Storage Policies
-- ----------------------------
CREATE POLICY "Allow public read on product images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

CREATE POLICY "Allow admin to upload product images" ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow admin to update product images" ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product_images');

-- ----------------------------
-- Initial Data
-- ----------------------------
INSERT INTO public.app_meta (key, value) VALUES ('version', '"1.0.0"')
ON CONFLICT(key) DO UPDATE SET value = '"1.0.0"';

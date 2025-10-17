
-- 1. Cleanup and Reset
DROP POLICY IF EXISTS "Allow anonymous insert for orders" ON public.orders;
DROP POLICY IF EXISTS "Allow read for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow update for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.order_items;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.clients;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Allow read access to everyone" ON storage.objects;
DROP POLICY IF EXISTS "Allow authorized write access" ON storage.objects;

DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;

DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision);
DROP FUNCTION IF EXISTS public.get_notification_counts();

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;

DROP TYPE IF EXISTS public.client_status;


-- 2. Create Types (Enums)
CREATE TYPE public.client_status AS ENUM (
    'pending_onboarding',
    'pending_agreement',
    'active',
    'archived'
);

-- 3. Create Tables
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token text NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE TABLE public.app_meta (
    key text PRIMARY KEY,
    value jsonb
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid REFERENCES public.agreements(id),
    total_amount double precision NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit double precision NOT NULL
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

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price double precision NOT NULL,
    volume_price double precision,
    PRIMARY KEY (price_list_id, product_id)
);


-- 4. Create Views & Functions

-- Function to increment total_revenue in app_meta
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void AS $$
DECLARE
    current_revenue double precision;
BEGIN
    -- Get current value
    SELECT (value->>'total_revenue')::double precision INTO current_revenue FROM public.app_meta WHERE key = 'business_stats';

    -- If null, initialize
    IF current_revenue IS NULL THEN
        current_revenue := 0;
    END IF;

    -- Update value
    UPDATE public.app_meta
    SET value = jsonb_set(
        COALESCE(value, '{}'::jsonb),
        '{total_revenue}',
        to_jsonb(current_revenue + amount_to_add)
    )
    WHERE key = 'business_stats';
END;
$$ LANGUAGE plpgsql;


-- Dashboard Stats View
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
    COALESCE((SELECT (value->>'total_revenue')::numeric FROM public.app_meta WHERE key = 'business_stats'), 0) AS total_revenue,
    (
        SELECT COALESCE(SUM(total_amount), 0)
        FROM public.orders
        WHERE
            status = 'completed' AND
            created_at >= date_trunc('month', now()) AND
            created_at < date_trunc('month', now()) + interval '1 month'
    ) AS month_revenue,
    (
        SELECT COUNT(*) 
        FROM public.orders 
        WHERE status = 'pending' AND created_at < (now() - interval '3 days')
    ) AS overdue_orders_count;


-- Agreements with counts view
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;


-- Function to get client stats
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent double precision, total_orders bigint, average_order_value double precision) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0.0)::double precision as total_spent,
        COUNT(o.id)::bigint as total_orders,
        (COALESCE(SUM(o.total_amount), 0.0) / NULLIF(COUNT(o.id), 0))::double precision as average_order_value
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Function to get notification counts
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count integer, pending_clients_count integer, overdue_orders_count integer) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::integer FROM public.orders WHERE status = 'pending') as pending_orders_count,
        (SELECT COUNT(*)::integer FROM public.clients WHERE status = 'pending_agreement') as pending_clients_count,
        (SELECT COUNT(*)::integer FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;
END;
$$ LANGUAGE plpgsql;


-- 5. Enable Row-Level Security (RLS)
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


-- 6. Create RLS Policies
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
CREATE POLICY "Allow all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Policies for 'orders' table
CREATE POLICY "Allow anonymous insert for orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow read for authenticated users" ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow update for authenticated users" ON public.orders FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 7. Storage Policies
CREATE POLICY "Allow read access to everyone" ON storage.objects FOR SELECT USING (true);
CREATE POLICY "Allow authorized write access" ON storage.objects FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- 8. Initial Data Seeding
INSERT INTO public.app_meta (key, value)
VALUES ('business_stats', '{"total_revenue": 0}')
ON CONFLICT (key) DO NOTHING;

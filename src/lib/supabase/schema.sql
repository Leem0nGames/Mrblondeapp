-- ------------------------------------------------------------------------------------------------
-- 1. Cleanup and Reset
--
-- This section drops all existing custom objects in the correct order to avoid dependency
-- errors. Using `CASCADE` is crucial to ensure a clean slate.
-- ------------------------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;

-- Drop storage policies before recreating buckets/tables they depend on.
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow all for authenticated users on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow all for service_role on app_assets" ON storage.objects;


-- ------------------------------------------------------------------------------------------------
-- 2. Create Types (Enums)
--
-- Enums are defined first as tables will depend on them.
-- ------------------------------------------------------------------------------------------------
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');


-- ------------------------------------------------------------------------------------------------
-- 3. Create Tables
--
-- Main table definitions with columns, primary keys, foreign keys, and constraints.
-- ------------------------------------------------------------------------------------------------

CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now()
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
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
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
    status public.client_status NOT NULL,
    onboarding_token text DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status text
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

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    due_date date GENERATED ALWAYS AS ((created_at::date + '30 days'::interval)::date) STORED
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);


-- ------------------------------------------------------------------------------------------------
-- 4. Create Views
--
-- Views provide virtual tables based on query results. Used for calculated fields and stats.
-- ------------------------------------------------------------------------------------------------

-- View to dynamically calculate overdue status and days for orders
CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
  o.*,
  (o.status = 'pending' AND o.due_date < now()::date) AS overdue,
  (CASE WHEN o.status = 'pending' AND o.due_date < now()::date THEN (now()::date - o.due_date) ELSE 0 END) AS days_overdue
FROM
  public.orders o;


-- View to get counts of promotions and sales conditions for each agreement.
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


-- View for main dashboard statistics.
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
  (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
  (SELECT COUNT(*) FROM public.clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) AS total_clients,
  (SELECT COUNT(*) FROM public.price_lists) AS total_pricelists,
  (SELECT COUNT(*) FROM public.promotions) AS total_promotions,
  (SELECT COUNT(*) FROM public.sales_conditions) AS total_sales_conditions,
  (SELECT COUNT(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count;


-- ------------------------------------------------------------------------------------------------
-- 5. Create Functions
--
-- Custom PostgreSQL functions for complex queries.
-- ------------------------------------------------------------------------------------------------

-- Function to get client statistics
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
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


-- Function to get notification counts
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
    (SELECT COUNT(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;


-- Function to get heatmap data
CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk integer) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.contact_name AS name,
    COALESCE(SUM(o.total_amount), 0) AS value,
    (SELECT COUNT(*)::integer FROM public.orders_with_overdue_status WHERE client_id = c.id AND overdue = true) AS risk
  FROM public.clients c
  LEFT JOIN public.orders o ON c.id = o.client_id AND o.status = 'completed'
  WHERE c.status = 'active'
  GROUP BY c.id, c.contact_name
  ORDER BY value DESC;
END;
$$ LANGUAGE plpgsql;


-- Function to increment total revenue (placeholder)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- This is a placeholder. A real implementation would be more robust,
  -- likely updating a summary table in a transaction to avoid race conditions.
END;
$$ LANGUAGE plpgsql;


-- ------------------------------------------------------------------------------------------------
-- 6. Enable Row-Level Security (RLS)
--
-- RLS is enabled on all tables that store user or sensitive data.
-- ------------------------------------------------------------------------------------------------
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


-- ------------------------------------------------------------------------------------------------
-- 7. Create RLS Policies
--
-- Policies define the rules for who can access or modify data.
-- `service_role` is used by server-side actions with admin privileges.
-- `authenticated` is for any logged-in user (the admin).
-- `anon` is for unauthenticated users (clients on the order page).
-- ------------------------------------------------------------------------------------------------

-- Policies for admin-only tables (full access for service_role)
CREATE POLICY "Allow all for service_role on products" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreements" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on clients" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Policies for `orders` table
CREATE POLICY "Allow read for admins" ON public.orders FOR SELECT USING (auth.role() = 'service_role');
CREATE POLICY "Allow update for admins" ON public.orders FOR UPDATE USING (auth.role() = 'service_role');
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated users" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);

-- Policies for `order_items` table
CREATE POLICY "Allow read for admins on order_items" ON public.order_items FOR SELECT USING (auth.role() = 'service_role');
CREATE POLICY "Allow insert for anonymous users on order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated users on order_items" ON public.order_items FOR INSERT TO authenticated WITH CHECK (true);


-- ------------------------------------------------------------------------------------------------
-- 8. Storage Policies
--
-- Policies for Supabase Storage buckets.
-- ------------------------------------------------------------------------------------------------

-- Policies for 'product_images' bucket
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow all for authenticated users on product_images" ON storage.objects FOR ALL TO authenticated USING (bucket_id = 'product_images');

-- Policies for 'app_assets' bucket (for logo, etc.)
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow all for service_role on app_assets" ON storage.objects FOR ALL TO service_role USING (bucket_id = 'app_assets');


-- ------------------------------------------------------------------------------------------------
-- 9. Initial Data Seeding
--
-- Insert essential data. Use `seed.sql` for larger, optional datasets.
-- ------------------------------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', ''), ('vat_percentage', '21') ON CONFLICT(key) DO NOTHING;

-- ------------------------------------------------------------------------------------------------
-- --- Idempotent Script to Setup Database Schema for Blonde Orders ---
-- ------------------------------------------------------------------------------------------------
-- This script can be run safely multiple times.
-- It will clean up the existing structure and recreate it from scratch.

-- --- 1. Drop existing objects in reverse order of dependency ---
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;


-- --- 2. Create tables ---

-- Products Table
CREATE TABLE public.products (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "base_price" numeric(10, 2) NOT NULL,
    "category" text,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Price Lists Table
CREATE TABLE public.price_lists (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL UNIQUE,
    "prices_include_vat" boolean DEFAULT true NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;

-- Price List Items Table (Junction table for products and price lists)
CREATE TABLE public.price_list_items (
    "price_list_id" uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    "price" numeric(10, 2) NOT NULL,
    "volume_price" numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;

-- Promotions Table
CREATE TABLE public.promotions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;

-- Sales Conditions Table
CREATE TABLE public.sales_conditions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;

-- Agreements Table
CREATE TABLE public.agreements (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "agreement_name" text NOT NULL UNIQUE,
    "client_type" text NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "price_list_id" uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;

-- Agreement Promotions (Junction table for agreements and promotions)
CREATE TABLE public.agreement_promotions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "promotion_id" uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;

-- Agreement Sales Conditions (Junction table for agreements and sales_conditions)
CREATE TABLE public.agreement_sales_conditions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "sales_condition_id" uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;

-- Clients Table
CREATE TABLE public.clients (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "cuit" text UNIQUE,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text UNIQUE,
    "instagram" text,
    "status" text DEFAULT 'pending_onboarding'::text NOT NULL CHECK (status IN ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    "onboarding_token" uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    "agreement_id" uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Orders Table
CREATE TABLE public.orders (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "client_id" uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "total_amount" numeric(10, 2) NOT NULL,
    "status" text DEFAULT 'pending'::text NOT NULL CHECK (status IN ('pending', 'completed')),
    "client_name_cache" text NOT NULL
);
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Order Items Table
CREATE TABLE public.order_items (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "order_id" uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    "quantity" integer NOT NULL,
    "price_per_unit" numeric(10, 2) NOT NULL
);
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;


-- --- 3. Create Views for aggregated data ---

-- View to get agreements with counts of associated promotions and sales conditions
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;

-- View for dashboard statistics (can be materialized for performance)
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients;


-- --- 4. Create Database Functions ---

-- Function to get statistics for a single client
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
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

-- Function to safely increment total revenue.
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This function is a placeholder for a more robust atomic operation.
    -- In a high-concurrency environment, this should be handled with care.
    -- For the dashboard_stats view, this function doesn't directly update it.
    -- The view recalculates on its own. This function is conceptual for now.
END;
$$;


-- --- 5. Set up Row Level Security (RLS) policies ---
-- This is a basic setup. Adjust as per your app's security requirements.

-- Products
CREATE POLICY "Allow public read-only access to products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to products" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Price Lists
CREATE POLICY "Allow public read-only access to price lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to price lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Price List Items
CREATE POLICY "Allow public read-only access to price list items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to price list items" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Promotions
CREATE POLICY "Allow public read-only access to promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Sales Conditions
CREATE POLICY "Allow public read-only access to sales conditions" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to sales conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Agreements
CREATE POLICY "Allow public read-only access to agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to agreements" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Agreement Promotions
CREATE POLICY "Allow public read-only access to agreement promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to agreement promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Agreement Sales Conditions
CREATE POLICY "Allow public read-only access to agreement sales conditions" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow admin full access to agreement sales conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Clients
CREATE POLICY "Allow public read access based on token" ON public.clients FOR SELECT USING (onboarding_token::text = current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token');
CREATE POLICY "Allow clients to update their own data via onboarding" ON public.clients FOR UPDATE USING (onboarding_token::text = current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token');
CREATE POLICY "Allow admin full access to clients" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all to create clients" ON public.clients FOR INSERT WITH CHECK (true);

-- Orders & Order Items
CREATE POLICY "Allow admin full access to orders" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all to create orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow admin full access to order items" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

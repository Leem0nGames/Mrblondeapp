
-- Supabase Schema for Blonde Orders
-- Version: 5
-- Date: 2024-08-01
--
-- This script is designed to be idempotent, meaning it can be run multiple
-- times without causing errors. It will clean up and recreate the necessary
-- database structures.
--

-- 1. Initial Cleanup: Drop existing objects if they exist
-- --------------------------------------------------------
BEGIN;

-- Drop functions first to remove dependencies
DROP FUNCTION IF EXISTS public.get_notification_counts();
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_client_stats(p_client_id uuid);

-- Drop views
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;

-- Drop policies before tables, especially for storage
DROP POLICY IF EXISTS "Allow authenticated users to upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin full access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow anonymous read access to product images" ON storage.objects;

-- Drop tables in reverse order of creation due to foreign key constraints
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.revenue_stats;

-- Drop custom types
DROP TYPE IF EXISTS public.client_status;
DROP TYPE IF EXISTS public.order_status;
DROP TYPE IF EXISTS public.client_type;

COMMIT;

-- 2. Create Custom Types
-- -----------------------
CREATE TYPE public.client_status AS ENUM (
  'pending_onboarding',
  'pending_agreement',
  'active',
  'archived'
);

CREATE TYPE public.order_status AS ENUM (
  'pending',
  'completed'
);

CREATE TYPE public.client_type AS ENUM (
  'barberia',
  'distribuidor',
  'especial'
);

-- 3. Create Tables
-- ----------------
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

CREATE TABLE public.agreements (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  agreement_name text NOT NULL UNIQUE,
  client_type public.client_type NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
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
  status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
  onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
  agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  fiscal_status text,
  latitude double precision,
  longitude double precision
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
  price numeric(10,2) NOT NULL,
  volume_price numeric(10,2),
  PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status public.order_status DEFAULT 'pending'::public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity integer NOT NULL,
  price_per_unit numeric(10,2) NOT NULL
);

CREATE TABLE public.revenue_stats (
  id int PRIMARY KEY DEFAULT 1,
  total_revenue numeric(15, 2) DEFAULT 0 NOT NULL,
  CONSTRAINT single_row CHECK (id = 1)
);
INSERT INTO public.revenue_stats (id, total_revenue) VALUES (1, 0) ON CONFLICT(id) DO NOTHING;


-- 4. Enable Row Level Security (RLS)
-- ---------------------------------
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_stats ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS Policies
-- -----------------------
-- Policies for public access (for order page)
CREATE POLICY "Allow public read access to required order data" ON public.agreements
  FOR SELECT USING (true);
CREATE POLICY "Allow public read access to required order data" ON public.price_lists
  FOR SELECT USING (true);
CREATE POLICY "Allow public read access to required order data" ON public.price_list_items
  FOR SELECT USING (true);
CREATE POLICY "Allow public read access to required order data" ON public.products
  FOR SELECT USING (true);
CREATE POLICY "Allow public read access to required order data" ON public.promotions
  FOR SELECT USING (true);
CREATE POLICY "Allow public read access to required order data" ON public.agreement_promotions
  FOR SELECT USING (true);
CREATE POLICY "Allow public read access for client lookup by agreement" ON public.clients
  FOR SELECT USING (true);

-- Policies for authenticated admins
CREATE POLICY "Allow admin full access" ON public.products FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.price_lists FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreements FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.clients FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.promotions FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.sales_conditions FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreement_promotions FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreement_sales_conditions FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.price_list_items FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.orders FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.order_items FOR ALL
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.revenue_stats FOR ALL
  USING (auth.role() = 'authenticated');

-- Policies for onboarding form (token-based access)
CREATE POLICY "Allow client to read their own data via token" ON public.clients
  FOR SELECT USING (onboarding_token::text = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'sub'));
CREATE POLICY "Allow client to update their own data" ON public.clients
  FOR UPDATE USING (onboarding_token::text = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'sub'));

-- Allow anyone to submit an order
CREATE POLICY "Allow public access to create orders" ON public.orders
  FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public access to create order items" ON public.order_items
  FOR INSERT WITH CHECK (true);

-- 6. Create Database Views
-- -------------------------
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascv WHERE ascv.agreement_id = a.id) AS sales_condition_count
FROM public.agreements a;


CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
  (SELECT total_revenue FROM public.revenue_stats WHERE id = 1) AS total_revenue,
  (SELECT coalesce(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
  (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
  (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;


-- 7. Create Database Functions
-- ---------------------------
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql
AS $$
  SELECT
    (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending'),
    (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
    (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days'));
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.revenue_stats
  SET total_revenue = total_revenue + amount_to_add
  WHERE id = 1;
END;
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
  WHERE client_id = p_client_id;
$$;


-- 8. Setup Storage
-- -----------------

-- Bucket para imágenes de productos
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for product_images bucket
CREATE POLICY "Allow authenticated users to upload" ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow admin full access to product images" ON storage.objects
FOR ALL
TO authenticated
USING (bucket_id = 'product_images')
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow anonymous read access to product images" ON storage.objects
FOR SELECT
TO anon, authenticated
USING (bucket_id = 'product_images');

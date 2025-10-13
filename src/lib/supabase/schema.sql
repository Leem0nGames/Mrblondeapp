
-- Dropping tables with CASCADE to handle dependencies
DROP TABLE IF EXISTS "public"."order_items" CASCADE;
DROP TABLE IF EXISTS "public"."orders" CASCADE;
DROP TABLE IF EXISTS "public"."agreement_promotions" CASCADE;
DROP TABLE IF EXISTS "public"."agreement_sales_conditions" CASCADE;
DROP TABLE IF EXISTS "public"."agreement_products" CASCADE; -- This table seems unused, but let's be safe
DROP TABLE IF EXISTS "public"."clients" CASCADE;
DROP TABLE IF EXISTS "public"."agreements" CASCADE;
DROP TABLE IF EXISTS "public"."promotions" CASCADE;
DROP TABLE IF EXISTS "public"."sales_conditions" CASCADE;
DROP TABLE IF EXISTS "public"."price_list_items" CASCADE;
DROP TABLE IF EXISTS "public"."price_lists" CASCADE;
DROP TABLE IF EXISTS "public"."products" CASCADE;
DROP TABLE IF EXISTS "public"."dashboard_stats" CASCADE;


-- Products Table
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    description text,
    base_price numeric NOT NULL,
    category text
);
ALTER TABLE public.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);

-- Price Lists Table
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    prices_include_vat boolean DEFAULT true NOT NULL
);
ALTER TABLE public.price_lists ADD CONSTRAINT price_lists_pkey PRIMARY KEY (id);
ALTER TABLE public.price_lists ADD CONSTRAINT price_lists_name_key UNIQUE (name);

-- Price List Items Table (Junction table for Products and Price Lists)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL,
    volume_price numeric
);
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id);
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE;
ALTER TABLE public.price_list_items ADD CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


-- Promotions Table
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    description text,
    rules jsonb
);
ALTER TABLE public.promotions ADD CONSTRAINT promotions_pkey PRIMARY KEY (id);


-- Sales Conditions Table
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    description text,
    rules jsonb
);
ALTER TABLE public.sales_conditions ADD CONSTRAINT sales_conditions_pkey PRIMARY KEY (id);

-- Agreements Table
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    agreement_name text NOT NULL,
    client_type public.client_type NOT NULL,
    price_list_id uuid
);
ALTER TABLE public.agreements ADD CONSTRAINT agreements_pkey PRIMARY KEY (id);
ALTER TABLE public.agreements ADD CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name);
ALTER TABLE public.agreements ADD CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL;


-- Client Type ENUM
CREATE TYPE public.client_type AS ENUM (
    'barberia',
    'distribuidor',
    'especial'
);
CREATE TYPE public.client_status AS ENUM (
    'pending_onboarding',
    'pending_agreement',
    'active',
    'archived'
);

-- Clients Table
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    cuit text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text,
    instagram text,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid
);
ALTER TABLE public.clients ADD CONSTRAINT clients_pkey PRIMARY KEY (id);
ALTER TABLE public.clients ADD CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token);
ALTER TABLE public.clients ADD CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL;
ALTER TABLE public.clients ADD CONSTRAINT clients_cuit_key UNIQUE (cuit);
ALTER TABLE public.clients ADD CONSTRAINT clients_email_key UNIQUE (email);


-- Junction Table for Agreements and Promotions
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL
);
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id);
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;
ALTER TABLE public.agreement_promotions ADD CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE;


-- Junction Table for Agreements and Sales Conditions
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL
);
ALTER TABLE public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id);
ALTER TABLE public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;
ALTER TABLE public.agreement_sales_conditions ADD CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE;


-- Orders Table
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric NOT NULL,
    status public.order_status DEFAULT 'pending'::public.order_status NOT NULL,
    client_name_cache text
);
ALTER TABLE public.orders ADD CONSTRAINT orders_pkey PRIMARY KEY (id);
ALTER TABLE public.orders ADD CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT;
ALTER TABLE public.orders ADD CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE RESTRICT;


-- Order Status ENUM
CREATE TYPE public.order_status AS ENUM (
    'pending',
    'completed'
);

-- Order Items Table
CREATE TABLE public.order_items (
    id bigint GENERATED BY DEFAULT AS IDENTITY NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);
ALTER TABLE public.order_items ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);
ALTER TABLE public.order_items ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
ALTER TABLE public.order_items ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

-- View for Agreements with counts
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;
    
-- Table for Dashboard Stats
CREATE TABLE public.dashboard_stats (
  id int8 NOT NULL,
  total_revenue numeric,
  month_revenue numeric,
  active_clients int8,
  CONSTRAINT dashboard_stats_pkey PRIMARY KEY (id)
);
INSERT INTO public.dashboard_stats (id, total_revenue, month_revenue, active_clients) VALUES (1, 0, 0, 0);

-- Function to increment total revenue
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  UPDATE public.dashboard_stats
  SET total_revenue = total_revenue + amount_to_add,
      month_revenue = month_revenue + amount_to_add -- This is a simplification
  WHERE id = 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get client stats
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric) AS $$
DECLARE
    v_total_spent numeric;
    v_completed_orders_count bigint;
BEGIN
    -- Calculate total spent on completed orders
    SELECT COALESCE(SUM(total_amount), 0)
    INTO v_total_spent
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';

    -- Count total orders (completed)
    SELECT COUNT(*)
    INTO v_completed_orders_count
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';

    -- Return the results, handling division by zero
    RETURN QUERY
    SELECT
        v_total_spent,
        v_completed_orders_count as total_orders,
        CASE
            WHEN v_completed_orders_count > 0 THEN v_total_spent / v_completed_orders_count
            ELSE 0
        END AS average_order_value;
END;
$$ LANGUAGE plpgsql;

-- Enable RLS for all tables
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
ALTER TABLE public.dashboard_stats ENABLE ROW LEVEL SECURITY;


-- Policies for authenticated users (admins)
CREATE POLICY "Allow admin full access" ON public.products FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access" ON public.price_lists FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access" ON public.price_list_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access" ON public.promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access" ON public.sales_conditions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access" ON public.agreements FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access" ON public.agreement_promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access" ON public.agreement_sales_conditions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin read access on clients" ON public.clients FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow admin to update clients" ON public.clients FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow admin to create clients" ON public.clients FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow admin full access on orders" ON public.orders FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow admin full access on order_items" ON public.order_items FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow admin read access to dashboard_stats" ON public.dashboard_stats FOR SELECT TO authenticated USING (true);


-- Policies for anonymous users (public access)
CREATE POLICY "Allow public read access to agreements for order page" ON public.agreements FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access to price lists for order page" ON public.price_lists FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access to price list items for order page" ON public.price_list_items FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access to products for order page" ON public.products FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access to promotions for order page" ON public.promotions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access to agreement_promotions for order page" ON public.agreement_promotions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access to clients for order page" ON public.clients FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public user to submit onboarding" ON public.clients FOR UPDATE TO anon, authenticated USING ((onboarding_token = (SELECT trim(both '"' from (auth.jwt() ->> 'onboarding_token'))::uuid)));
CREATE POLICY "Allow public to create orders" ON public.orders FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Allow public to create order items" ON public.order_items FOR INSERT TO anon, authenticated WITH CHECK (true);

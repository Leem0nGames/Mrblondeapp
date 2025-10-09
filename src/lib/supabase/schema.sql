-- ----------------------------
-- 0. Helper Functions & Types
-- ----------------------------

-- Custom types
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_type') THEN
        CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_status') THEN
        CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active');
    END IF;
END$$;


-- ----------------------------
-- 1. Tables
-- ----------------------------

-- Products Table
CREATE TABLE IF NOT EXISTS public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text NULL,
    base_price numeric NOT NULL DEFAULT 0,
    stock integer NOT NULL DEFAULT 0,
    category text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT products_pkey PRIMARY KEY (id)
);

-- Price Lists Table
CREATE TABLE IF NOT EXISTS public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT price_lists_pkey PRIMARY KEY (id),
    CONSTRAINT price_lists_name_key UNIQUE (name)
);

-- Price List Items Table (Junction table)
CREATE TABLE IF NOT EXISTS public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL,
    volume_price numeric NULL,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);

-- Agreements Table
CREATE TABLE IF NOT EXISTS public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL,
    client_type public.client_type NOT NULL,
    price_list_id uuid NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Promotions Table
CREATE TABLE IF NOT EXISTS public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text NULL,
    rules jsonb NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);

-- Agreement Promotions Table (Junction table)
CREATE TABLE IF NOT EXISTS public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE
);

-- Clients Table
CREATE TABLE IF NOT EXISTS public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    cuit text NULL,
    contact_name text NULL,
    contact_dni text NULL,
    address text NULL,
    delivery_window text NULL,
    email text NULL,
    instagram text NULL,
    status public.client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token),
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL
);


-- ----------------------------
-- 2. Row Level Security (RLS)
-- ----------------------------

-- PRODUCTS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.products;
CREATE POLICY "Allow all access to authenticated users" ON public.products
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- PRICE LISTS
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.price_lists;
CREATE POLICY "Allow all access to authenticated users" ON public.price_lists
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow public read access" ON public.price_lists;
CREATE POLICY "Allow public read access" ON public.price_lists
FOR SELECT USING (true);


-- PRICE LIST ITEMS
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.price_list_items;
CREATE POLICY "Allow all access to authenticated users" ON public.price_list_items
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow public read access" ON public.price_list_items;
CREATE POLICY "Allow public read access" ON public.price_list_items
FOR SELECT USING (true);


-- AGREEMENTS
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.agreements;
CREATE POLICY "Allow all access to authenticated users" ON public.agreements
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow public read access" ON public.agreements;
CREATE POLICY "Allow public read access" ON public.agreements
FOR SELECT USING (true);


-- PROMOTIONS
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.promotions;
CREATE POLICY "Allow all access to authenticated users" ON public.promotions
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');


-- AGREEMENT PROMOTIONS
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.agreement_promotions;
CREATE POLICY "Allow all access to authenticated users" ON public.agreement_promotions
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow public read access" ON public.agreement_promotions;
CREATE POLICY "Allow public read access" ON public.agreement_promotions
FOR SELECT USING (true);


-- CLIENTS
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to authenticated admins" ON public.clients;
CREATE POLICY "Allow all access to authenticated admins" ON public.clients
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow anon read for onboarding" ON public.clients;
CREATE POLICY "Allow anon read for onboarding" ON public.clients
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow anon update for onboarding" ON public.clients;
CREATE POLICY "Allow anon update for onboarding" ON public.clients
FOR UPDATE
USING (status = 'pending_onboarding')
WITH CHECK (status = 'pending_onboarding');

-- ----------------------------
-- 3. Views
-- ----------------------------
-- This view is a helper to count promotions per agreement easily.
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count
FROM
    public.agreements a;

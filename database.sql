
-- Roles and Policies will be managed through the Supabase dashboard.
-- This script focuses on creating the necessary tables and relationships.

-- 1. PRODUCTS TABLE
-- Stores the catalog of all products available.
CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    base_price numeric(10,2) DEFAULT 0.00 NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    category character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
-- Anyone can view products.
CREATE POLICY "Enable read access for all users" ON "public"."products"
AS PERMISSIVE FOR SELECT
TO public
USING (true);
-- Only authenticated users can modify products (for now, assumes admin role is handled by app logic).
CREATE POLICY "Enable insert for authenticated users only" ON "public"."products"
AS PERMISSIVE FOR INSERT
TO authenticated
WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users only" ON "public"."products"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users only" ON "public"."products"
AS PERMISSIVE FOR DELETE
TO authenticated
USING (true);


-- 2. PROMOTIONS TABLE
-- Stores all available promotions and their rules.
CREATE TABLE IF NOT EXISTS public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
-- Anyone can view promotions.
CREATE POLICY "Enable read access for all users" ON "public"."promotions"
AS PERMISSIVE FOR SELECT
TO public
USING (true);
-- Only authenticated users can modify promotions.
CREATE POLICY "Enable insert for authenticated users only" ON "public"."promotions"
AS PERMISSIVE FOR INSERT
TO authenticated
WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users only" ON "public"."promotions"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users only" ON "public"."promotions"
AS PERMISSIVE FOR DELETE
TO authenticated
USING (true);


-- 3. AGREEMENTS TABLE
-- Defines specific agreements for clients or client types.
CREATE TABLE IF NOT EXISTS public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name character varying NOT NULL,
    client_type character varying NOT NULL,
    price_adjustment numeric(5,2) DEFAULT 0.00 NOT NULL,
    link_token uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agreements_link_token_key UNIQUE (link_token)
);
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
-- Anyone can view agreements (needed for order page via token).
CREATE POLICY "Enable read access for all users" ON "public"."agreements"
AS PERMISSIVE FOR SELECT
TO public
USING (true);
-- Only authenticated users can modify agreements.
CREATE POLICY "Enable insert for authenticated users only" ON "public"."agreements"
AS PERMISSIVE FOR INSERT
TO authenticated
WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users only" ON "public"."agreements"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users only" ON "public"."agreements"
AS PERMISSIVE FOR DELETE
TO authenticated
USING (true);

-- 4. AGREEMENT_PRODUCTS JUNCTION TABLE
-- Links products to agreements with a specific price.
CREATE TABLE IF NOT EXISTS public.agreement_products (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL,
    PRIMARY KEY (agreement_id, product_id)
);
ALTER TABLE public.agreement_products ENABLE ROW LEVEL SECURITY;
-- Anyone can view these relationships (needed for order page).
CREATE POLICY "Enable read access for all users" ON "public"."agreement_products"
AS PERMISSIVE FOR SELECT
TO public
USING (true);
-- Only authenticated users can modify these relationships.
CREATE POLICY "Enable insert for authenticated users only" ON "public"."agreement_products"
AS PERMISSIVE FOR INSERT
TO authenticated
WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users only" ON "public"."agreement_products"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users only" ON "public"."agreement_products"
AS PERMISSIVE FOR DELETE
TO authenticated
USING (true);


-- 5. AGREEMENT_PROMOTIONS JUNCTION TABLE
-- Links promotions to agreements.
CREATE TABLE IF NOT EXISTS public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
-- Anyone can view these relationships (needed for order page).
CREATE POLICY "Enable read access for all users" ON "public"."agreement_promotions"
AS PERMISSIVE FOR SELECT
TO public
USING (true);
-- Only authenticated users can modify these relationships.
CREATE POLICY "Enable insert for authenticated users only" ON "public"."agreement_promotions"
AS PERMISSIVE FOR INSERT
TO authenticated
WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users only" ON "public"."agreement_promotions"
AS PERMISSIVE FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
CREATE POLICY "Enable delete for authenticated users only" ON "public"."agreement_promotions"
AS PERMISSIVE FOR DELETE
TO authenticated
USING (true);

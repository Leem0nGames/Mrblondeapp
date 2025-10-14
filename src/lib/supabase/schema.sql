
-- -----------------------------------------------------------------------------
-- BLONDE ORDERS - ESQUEMA DE BASE DE DATOS
-- -----------------------------------------------------------------------------
-- Este script es idempotente. Puedes ejecutarlo de forma segura en cualquier
-- momento. Limpiará y reconfigurará la base de datos al estado inicial.
-- -----------------------------------------------------------------------------

-- 1. Limpieza de objetos existentes
-- Usamos DROP ... CASCADE para eliminar tablas y todas sus dependencias (vistas, etc.)
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
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
DROP FUNCTION IF EXISTS public.get_client_stats;
DROP FUNCTION IF EXISTS public.increment_total_revenue;

-- 2. Creación de tablas

CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT products_pkey PRIMARY KEY (id)
);

CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT price_lists_pkey PRIMARY KEY (id),
    CONSTRAINT price_lists_name_key UNIQUE (name)
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL DEFAULT 0,
    volume_price numeric,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists (id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products (id) ON DELETE CASCADE
);

CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);

CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    rules jsonb NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT sales_conditions_pkey PRIMARY KEY (id)
);

CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_name character varying NOT NULL,
    client_type character varying NOT NULL,
    price_list_id uuid,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists (id) ON DELETE SET NULL
);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements (id) ON DELETE CASCADE,
    CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions (id) ON DELETE CASCADE
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL,
    CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id),
    CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements (id) ON DELETE CASCADE,
    CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions (id) ON DELETE CASCADE
);

CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    cuit character varying UNIQUE,
    contact_name character varying,
    contact_dni character varying,
    address character varying,
    delivery_window character varying,
    email character varying UNIQUE,
    instagram character varying,
    status character varying NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid,
    fiscal_status character varying,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements (id) ON DELETE SET NULL
);

CREATE TABLE public.orders (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric NOT NULL,
    status character varying NOT NULL DEFAULT 'pending',
    client_name_cache character varying,
    CONSTRAINT orders_pkey PRIMARY KEY (id),
    CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients (id),
    CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements (id)
);

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL,
    CONSTRAINT order_items_pkey PRIMARY KEY (id),
    CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders (id) ON DELETE CASCADE,
    CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products (id)
);

ALTER TABLE public.order_items ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- 3. Creación de Vistas

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) as sales_condition_count
FROM
    public.agreements a;
    
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue;

-- 4. Creación de Funciones RPC

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql STABLE
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Esta función es un placeholder. En una app real, la lógica
    -- para actualizar estadísticas sería más compleja y robusta,
    -- probablemente actualizando una tabla de estadísticas pre-calculadas.
    -- Por ahora, no hacemos nada para evitar complejidad.
END;
$$;

-- 5. Creación de Storage Bucket
-- Esto debe hacerse desde la UI de Supabase, pero lo documentamos aquí.
-- Se crea un bucket 'product_images' y se hace público.

-- Insertar políticas de RLS para el bucket 'product_images'
-- Estas políticas permiten a cualquiera leer las imágenes, pero solo los usuarios autenticados pueden subir/modificar.
-- Supabase UI es la forma recomendada de gestionar esto.

-- 6. Políticas de Seguridad (RLS)
-- Habilitamos RLS para todas las tablas y definimos las políticas.
-- La política general será que solo los usuarios autenticados pueden acceder.

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.products;
CREATE POLICY "Authenticated users can manage all data" ON public.products FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.price_lists;
CREATE POLICY "Authenticated users can manage all data" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.price_list_items;
CREATE POLICY "Authenticated users can manage all data" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.promotions;
CREATE POLICY "Authenticated users can manage all data" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.sales_conditions;
CREATE POLICY "Authenticated users can manage all data" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.agreements;
CREATE POLICY "Authenticated users can manage all data" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.agreement_promotions;
CREATE POLICY "Authenticated users can manage all data" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.agreement_sales_conditions;
CREATE POLICY "Authenticated users can manage all data" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated');

-- Para clientes, cualquiera puede crear (a través del link de onboarding) pero solo admins leen/modifican
DROP POLICY IF EXISTS "Allow public insert for new clients" ON public.clients;
CREATE POLICY "Allow public insert for new clients" ON public.clients FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow authenticated read/update/delete for clients" ON public.clients;
CREATE POLICY "Allow authenticated read/update/delete for clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.orders;
CREATE POLICY "Authenticated users can manage all data" ON public.orders FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can manage all data" ON public.order_items;
CREATE POLICY "Authenticated users can manage all data" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');

-- Políticas para el Storage (documentación)
-- Se recomienda crear estas políticas desde el Dashboard de Supabase en Storage > Policies.
-- CREATE POLICY "Public read access for product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
-- CREATE POLICY "Authenticated users can upload images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
-- CREATE POLICY "Authenticated users can update their own images" ON storage.objects FOR UPDATE USING (auth.uid() = owner) WITH CHECK (bucket_id = 'product_images');


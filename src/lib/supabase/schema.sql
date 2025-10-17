-- Deshabilitar temporalmente los triggers para evitar problemas de dependencias
SET session_replication_role = 'replica';


-- 1. Limpieza Inicial
-- Eliminar vistas, tablas y tipos existentes en orden inverso de creación
DROP VIEW IF EXISTS public.dashboard_stats;
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP FUNCTION IF EXISTS public.get_notification_counts();
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;

-- Eliminar los tipos ENUM. Requieren un paso adicional.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_status') THEN
        DROP TYPE public.client_status;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
        DROP TYPE public.order_status;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'client_type') THEN
        DROP TYPE public.client_type;
    END IF;
END$$;

-- 2. Creación de Tipos ENUM
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');

-- 3. Creación de Tablas
CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text NULL,
    category character varying NULL,
    image_url text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT products_pkey PRIMARY KEY (id)
);

CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    prices_include_vat boolean NOT NULL DEFAULT true,
    CONSTRAINT price_lists_pkey PRIMARY KEY (id),
    CONSTRAINT price_lists_name_key UNIQUE (name)
);

CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_name character varying NOT NULL,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    price_list_id uuid NULL,
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);

CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text NULL,
    rules jsonb NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);

CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text NULL,
    rules jsonb NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT sales_conditions_pkey PRIMARY KEY (id)
);

CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    cuit character varying NULL,
    contact_name character varying NULL,
    contact_dni character varying NULL,
    address text NULL,
    delivery_window text NULL,
    email character varying NULL,
    instagram character varying NULL,
    status public.client_status NOT NULL,
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status character varying NULL,
    latitude double precision,
    longitude double precision,
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email),
    CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL,
    volume_price numeric NULL,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);

CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL,
    CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id),
    CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE
);

CREATE TABLE public.orders (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache character varying NOT NULL,
    notes text NULL,
    CONSTRAINT orders_pkey PRIMARY KEY (id),
    CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE RESTRICT,
    CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT
);

CREATE TABLE public.order_items (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL,
    CONSTRAINT order_items_pkey PRIMARY KEY (id),
    CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE,
    CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT
);


-- 4. Creación de Vistas
CREATE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascv WHERE ascv.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;

CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month'::text, now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count;


-- 5. Creación de Funciones
CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric)
LANGUAGE sql STABLE
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COUNT(id) AS total_orders,
        COALESCE(AVG(total_amount), 0) AS average_order_value
    FROM
        public.orders
    WHERE
        client_id = p_client_id AND status = 'completed';
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE sql
AS $$
  -- Esta función está vacía intencionadamente.
  -- El RPC se usa principalmente para invalidar el cache de Next.js.
  -- La lógica real está en la VISTA dashboard_stats.
$$;

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count integer, pending_clients_count integer, overdue_orders_count integer)
LANGUAGE sql
AS $$
    SELECT
        (SELECT count(*)::integer FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*)::integer FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*)::integer FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count;
$$;


-- Reactivar los triggers
SET session_replication_role = 'origin';

-- Habilitar RLS para todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;

-- 6. Políticas de Seguridad (RLS)

-- Los administradores autenticados pueden hacer todo.
CREATE POLICY "Allow all access to authenticated admins"
ON public.products FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.price_lists FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.agreements FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.promotions FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.clients FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.price_list_items FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.agreement_promotions FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.orders FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.order_items FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.sales_conditions FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all access to authenticated admins"
ON public.agreement_sales_conditions FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);


-- El acceso anónimo (no autenticado) está muy restringido.
-- Se permite leer información necesaria para las páginas de pedido y alta.
CREATE POLICY "Allow anonymous read for order pages"
ON public.agreements FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow anonymous read for order pages"
ON public.agreement_promotions FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow anonymous read for order pages"
ON public.promotions FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow anonymous read for order pages"
ON public.price_lists FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow anonymous read for order pages"
ON public.price_list_items FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow anonymous read for order pages"
ON public.products FOR SELECT
TO anon
USING (true);

CREATE POLICY "Allow anonymous read for onboarding"
ON public.clients FOR SELECT
TO anon
USING (onboarding_token IS NOT NULL);

CREATE POLICY "Allow anonymous update for onboarding form"
ON public.clients FOR UPDATE
TO anon
USING (onboarding_token IS NOT NULL)
WITH CHECK (onboarding_token IS NOT NULL);

-- Los usuarios anónimos pueden crear nuevos pedidos
CREATE POLICY "Allow anonymous insert for orders"
ON public.orders FOR INSERT
TO anon
WITH CHECK (true);

CREATE POLICY "Allow anonymous insert for order_items"
ON public.order_items FOR INSERT
TO anon
WITH CHECK (true);

-- Permisos para almacenamiento (Storage)
CREATE POLICY "Allow admin full access to product images"
ON storage.objects FOR ALL
TO authenticated
USING (bucket_id = 'product_images')
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow anonymous read access to product images"
ON storage.objects FOR SELECT
TO anon
USING (bucket_id = 'product_images');


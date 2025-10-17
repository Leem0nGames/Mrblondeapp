
-- -------------------------------------------------------------------------------------
-- BLONDE ORDERS - SUPABASE SCHEMA
--
-- Este script es idempotente. Puedes ejecutarlo de forma segura en cualquier momento.
-- Se encargará de limpiar (DROP) y recrear (CREATE) todos los objetos de la base
-- de datos para asegurar un estado consistente.
--
-- Orden de ejecución:
-- 1. Limpieza de Vistas, Funciones y Vistas (en orden inverso de dependencia).
-- 2. Creación de Tipos (Enums).
-- 3. Creación de Tablas.
-- 4. Creación de Vistas y Funciones.
-- 5. Habilitación de RLS (Row Level Security).
-- 6. Creación de Políticas de RLS.
-- 7. Limpieza y Creación de Políticas de Almacenamiento (Storage).
-- 8. Creación de datos iniciales (Seed).
-- -------------------------------------------------------------------------------------


-- 1. Limpieza de Objetos Existentes
-- -------------------------------------------------------------------------------------
-- Se utiliza `CASCADE` para eliminar automáticamente objetos dependientes (p.ej., políticas en tablas).

DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(double precision) CASCADE;

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;

DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;


-- 2. Creación de Tipos (Enums)
-- -------------------------------------------------------------------------------------

CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');


-- 3. Creación de Tablas
-- -------------------------------------------------------------------------------------

CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT products_pkey PRIMARY KEY (id),
    CONSTRAINT products_name_key UNIQUE (name)
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
    price double precision NOT NULL,
    volume_price double precision,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_check CHECK ((price >= 0)),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);

CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_name character varying NOT NULL,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    price_list_id uuid,
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);

CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    cuit character varying,
    contact_name character varying,
    contact_dni character varying,
    address text,
    delivery_window text,
    email character varying,
    instagram character varying,
    status public.client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status character varying,
    latitude double precision,
    longitude double precision,
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email),
    CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL
);

CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);

CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT sales_conditions_pkey PRIMARY KEY (id)
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
    agreement_id uuid,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount double precision NOT NULL,
    status public.order_status NOT NULL DEFAULT 'pending',
    client_name_cache character varying NOT NULL,
    notes text,
    CONSTRAINT orders_pkey PRIMARY KEY (id),
    CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL,
    CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE
);

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit double precision NOT NULL,
    CONSTRAINT order_items_pkey PRIMARY KEY (id),
    CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE,
    CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT
);
ALTER TABLE public.order_items ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (SEQUENCE NAME public.order_items_id_seq START WITH 1 INCREMENT BY 1);


CREATE TABLE public.app_meta (
    key character varying NOT NULL,
    value jsonb,
    CONSTRAINT app_meta_pkey PRIMARY KEY (key)
);


-- 4. Creación de Vistas y Funciones
-- -------------------------------------------------------------------------------------

CREATE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = agr.id) as sales_condition_count
FROM
    public.agreements agr;


CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT value->>0 FROM public.app_meta WHERE key = 'total_revenue')_text::double precision AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0::double precision) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month'::text, now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '2 days'::interval)) AS overdue_orders_count;


CREATE FUNCTION public.get_notification_counts()
RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
  result record;
BEGIN
  SELECT
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '2 days'::interval)) AS overdue_orders_count
  INTO result;
  RETURN result;
END;
$$;

CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
  result record;
BEGIN
  SELECT
    COALESCE(SUM(total_amount), 0) as total_spent,
    COALESCE(AVG(total_amount), 0) as average_order_value,
    COUNT(id) as total_orders
  FROM public.orders
  WHERE client_id = p_client_id AND status = 'completed'
  INTO result;
  RETURN result;
END;
$$;

CREATE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  current_revenue double precision;
BEGIN
  -- 1. Obtener el valor actual y bloquear la fila
  SELECT (value->>0)::double precision INTO current_revenue
  FROM app_meta
  WHERE key = 'total_revenue'
  FOR UPDATE;

  -- 2. Si no existe, inicializarlo
  IF NOT FOUND THEN
    INSERT INTO app_meta (key, value)
    VALUES ('total_revenue', to_jsonb(amount_to_add))
    ON CONFLICT (key) DO NOTHING;
  ELSE
    -- 3. Si existe, actualizarlo
    UPDATE app_meta
    SET value = to_jsonb(current_revenue + amount_to_add)
    WHERE key = 'total_revenue';
  END IF;
END;
$$;


-- 5. Habilitación de RLS (Row Level Security)
-- -------------------------------------------------------------------------------------

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;


-- 6. Creación de Políticas de RLS
-- -------------------------------------------------------------------------------------

-- Políticas para permitir acceso total a usuarios autenticados (administradores)
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.app_meta FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- Políticas para la tabla de pedidos (lectura y actualización para admin, inserción para anónimos)
CREATE POLICY "Allow read for authenticated users" ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow update for authenticated users" ON public.orders FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anonymous insert for orders" ON public.orders FOR INSERT WITH CHECK (true);

-- Políticas para la tabla de ítems de pedido
CREATE POLICY "Allow read for authenticated users" ON public.order_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow anonymous insert for order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Políticas para acceso público de lectura en tablas necesarias para la página de pedidos
CREATE POLICY "Allow public read on agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read on promotions" ON public.promotions FOR SELECT USING (true);
CREATE "Allow public read on agreement_promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read on price_lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read on price_list_items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read on products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read on clients" ON public.clients FOR SELECT USING (true);

-- 7. Limpieza y Creación de Políticas de Almacenamiento (Storage)
-- -------------------------------------------------------------------------------------

-- Limpieza de políticas existentes para el bucket 'product_images'
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert to product images" ON storage.objects;

-- Creación de políticas para el bucket 'product_images'
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

CREATE POLICY "Allow authenticated insert to product images" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');


-- 8. Datos Iniciales (Seed)
-- -------------------------------------------------------------------------------------

INSERT INTO public.app_meta (key, value) VALUES ('version', '"1.0.0"')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.app_meta (key, value) VALUES ('total_revenue', '0')
ON CONFLICT (key) DO NOTHING;

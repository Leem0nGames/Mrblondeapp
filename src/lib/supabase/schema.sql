-- ----------------------------------------------------
-- Archivo de esquema de base de datos para Blonde Orders
-- Idempotente y seguro para ejecutar.
-- ----------------------------------------------------

-- 1. Limpieza y Reseteo
-- Elimina objetos en orden inverso a la creación para evitar errores de dependencia.
-- Siempre usa CASCADE para manejar dependencias automáticamente.
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;

DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_clients_heatmap_data() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;

DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;

DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.promotion_type CASCADE;
DROP TYPE IF EXISTS public.sales_condition_type CASCADE;

-- 2. Creación de Tipos (Enums)
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');
CREATE TYPE public.sales_condition_type AS ENUM ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');


-- 3. Creación de Tablas
CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying(255) NOT NULL,
    description text,
    category character varying(100),
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX products_name_key ON public.products(name);

CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying(255) NOT NULL,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2)
);
CREATE UNIQUE INDEX price_lists_name_key ON public.price_lists(name);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying(255) NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying(255) NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name character varying(255) NOT NULL,
    client_type client_type NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX agreements_agreement_name_key ON public.agreements(agreement_name);


CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit character varying(11),
    contact_name character varying(255),
    contact_dni character varying(10),
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email character varying(255),
    instagram character varying(100),
    status client_status NOT NULL,
    onboarding_token text DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status character varying(100)
);
CREATE UNIQUE INDEX clients_cuit_key ON public.clients(cuit);
CREATE UNIQUE INDEX clients_email_key ON public.clients(email);

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
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric(10, 2) NOT NULL,
    status order_status NOT NULL DEFAULT 'pending',
    client_name_cache character varying(255) NOT NULL,
    notes text,
    due_date date GENERATED ALWAYS AS ((created_at AT TIME ZONE 'UTC')::date + interval '30 days') STORED
);

CREATE TABLE public.order_items (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

CREATE TABLE public.app_settings (
    key character varying(50) PRIMARY KEY,
    value text
);


-- 4. Creación de Vistas
CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
    *,
    (status = 'pending' AND due_date < CURRENT_DATE) as overdue,
    GREATEST(0, (CURRENT_DATE - due_date)) as days_overdue
FROM public.orders;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients) as total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions;

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions WHERE agreement_id = agr.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions WHERE agreement_id = agr.id) as sales_condition_count
FROM public.agreements agr;


-- 5. Creación de Funciones
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS table(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
  RETURN QUERY SELECT
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
    (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
    (SELECT count(*)::int FROM public.orders_with_overdue_status WHERE overdue = true);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS table(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
  RETURN QUERY SELECT
    COALESCE(sum(total_amount), 0) as total_spent,
    COALESCE(avg(total_amount), 0) as average_order_value,
    count(*) as total_orders
  FROM public.orders
  WHERE client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS table(id uuid, name text, value numeric, risk int) AS $$
BEGIN
  RETURN QUERY
    WITH client_revenue AS (
      SELECT
        o.client_id,
        SUM(o.total_amount) AS total_revenue,
        SUM(CASE WHEN oos.overdue THEN 1 ELSE 0 END) AS overdue_count
      FROM public.orders o
      JOIN public.orders_with_overdue_status oos ON o.id = oos.id
      WHERE o.status IN ('completed', 'pending')
      GROUP BY o.client_id
    )
    SELECT
      c.id,
      c.contact_name AS name,
      cr.total_revenue AS value,
      cr.overdue_count::int AS risk
    FROM public.clients c
    JOIN client_revenue cr ON c.id = cr.client_id
    WHERE c.status = 'active';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- Esta función es un marcador de posición.
  -- En un escenario real, actualizarías una tabla de agregados.
  -- Por ahora, no hace nada para evitar problemas de rendimiento.
END;
$$ LANGUAGE plpgsql;

-- 6. Habilitación de RLS (Row-Level Security)
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

-- 7. Creación de Políticas RLS
-- Permitir todo para service_role (acceso desde el backend con clave de servicio)
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Permitir acceso de solo lectura a usuarios autenticados (admin logueado)
CREATE POLICY "Allow read for authenticated users" ON public.products FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.price_lists FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.price_list_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.promotions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.sales_conditions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.agreements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.clients FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.agreement_promotions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.agreement_sales_conditions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.order_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow read for authenticated users" ON public.app_settings FOR SELECT TO authenticated USING (true);

-- Permitir acceso de solo lectura a usuarios anónimos (página de pedido)
CREATE POLICY "Allow read access to anon users" ON public.products FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read access to anon users" ON public.price_lists FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read access to anon users" ON public.price_list_items FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read access to anon users" ON public.promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read access to anon users" ON public.agreements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read access to anon users" ON public.agreement_promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read access to anon users" ON public.clients FOR SELECT TO anon USING (true);
CREATE POLICY "Allow read access to anon users" ON public.app_settings FOR SELECT TO anon USING (true);

-- Política de inserción para Pedidos
CREATE POLICY "Allow insert for anon users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated users" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow insert for anon users" ON public.order_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated users" ON public.order_items FOR INSERT TO authenticated WITH CHECK (true);

-- Políticas de la tabla de clientes (onboarding)
CREATE POLICY "Allow anon read on clients via token" ON public.clients FOR SELECT TO anon
USING (onboarding_token IS NOT NULL);
CREATE POLICY "Allow anon update on clients via token" ON public.clients FOR UPDATE TO anon
USING (onboarding_token IS NOT NULL);


-- 8. Políticas de Storage
-- Acceso público a imágenes de productos
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

-- Acceso público a assets de la app (logo)
DROP POLICY IF EXISTS "Allow public read access to app assets" ON storage.objects;
CREATE POLICY "Allow public read access to app assets" ON storage.objects FOR SELECT
USING (bucket_id = 'app_assets');

-- Permitir inserción/actualización de imágenes de productos a admins
DROP POLICY IF EXISTS "Allow admin inserts on product images" ON storage.objects;
CREATE POLICY "Allow admin inserts on product images" ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product_images');

DROP POLICY IF EXISTS "Allow admin updates on product images" ON storage.objects;
CREATE POLICY "Allow admin updates on product images" ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product_images');

-- Permitir inserción/actualización de assets de la app a admins
DROP POLICY IF EXISTS "Allow admin inserts on app assets" ON storage.objects;
CREATE POLICY "Allow admin inserts on app assets" ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'app_assets');

DROP POLICY IF EXISTS "Allow admin updates on app assets" ON storage.objects;
CREATE POLICY "Allow admin updates on app assets" ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'app_assets');

-- 9. Datos Iniciales
-- Insertar configuraciones por defecto si no existen
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '5491123456789') ON CONFLICT(key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT(key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('logo_url', null) ON CONFLICT(key) DO NOTHING;


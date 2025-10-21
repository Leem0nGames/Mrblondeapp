
-- BLONDE ORDERS - SUPABASE SCHEMA
-- VERSION: 1.5
-- DESCRIPTION: Script SQL completo para configurar la base de datos.
-- Este script es IDEMPOTENTE: puedes ejecutarlo de forma segura en cualquier momento.

-- =============================================
-- 1. LIMPIEZA Y REINICIO
-- =============================================
-- Se eliminan todos los objetos en orden inverso a su creación para evitar errores de dependencia.
-- El uso de `CASCADE` es crucial para eliminar objetos dependientes automáticamente.

-- Funciones y Vistas
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_clients_heatmap_data() CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;


-- Políticas de Almacenamiento (Storage)
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin to manage app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin to manage product_images" ON storage.objects;


-- Políticas de Tablas (RLS)
DROP POLICY IF EXISTS "Allow all for service_role" ON public.app_settings;
DROP POLICY IF EXISTS "Allow all for service_role on promotions" ON public.promotions;
DROP POLICY IF EXISTS "Allow all for service_role on price_lists" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all for service_role on sales_conditions" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.products;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreements;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.clients;
DROP POLICY IF EXISTS "Allow authenticated users to view their own client data" ON public.clients;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow insert for anonymous users" ON public.orders;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.orders;
DROP POLICY IF EXISTS "Allow all for service_role" ON public.order_items;


-- Tablas (en orden inverso de dependencia)
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;


-- Tipos
DROP TYPE IF EXISTS public.client_status;
DROP TYPE IF EXISTS public.order_status;
DROP TYPE IF EXISTS public.client_type;


-- =============================================
-- 2. CREACIÓN DE TIPOS (ENUMS)
-- =============================================

CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');


-- =============================================
-- 3. CREACIÓN DE TABLAS
-- =============================================

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
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2)
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL,
    volume_price numeric,
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
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token text DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status text,
    latitude double precision,
    longitude double precision
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
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);

-- =============================================
-- 4. VISTAS (VIEWS)
-- =============================================

CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
  *,
  (created_at::date + '30 days'::interval) as due_date,
  (status = 'pending' AND (created_at + '30 days'::interval) < now()) AS overdue,
  GREATEST(0, (now()::date - (created_at::date + '30 days'::interval)::date)) AS days_overdue
FROM
  public.orders;

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT count(*) FROM public.agreement_promotions apro WHERE apro.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM
    public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), (0)::numeric) FROM public.orders WHERE (status = 'completed')) AS total_revenue,
    (SELECT COALESCE(sum(total_amount), (0)::numeric) FROM public.orders WHERE (status = 'completed' AND created_at >= date_trunc('month'::text, now()))) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE (status = 'active')) AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions;

-- =============================================
-- 5. FUNCIONES (FUNCTIONS)
-- =============================================

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COALESCE(AVG(total_amount), 0) AS average_order_value,
        COUNT(id) AS total_orders
    FROM
        public.orders
    WHERE
        client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;


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

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk integer) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.contact_name AS name,
    COALESCE(SUM(o.total_amount), 0) AS value,
    COALESCE(SUM(CASE WHEN owos.overdue THEN 1 ELSE 0 END), 0)::integer AS risk
  FROM
    public.clients c
  LEFT JOIN
    public.orders o ON c.id = o.client_id AND o.status = 'completed'
  LEFT JOIN
    public.orders_with_overdue_status owos ON c.id = owos.client_id AND owos.overdue = true
  WHERE
    c.status = 'active'
  GROUP BY
    c.id, c.contact_name;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- Esta es una función de marcador de posición.
  -- En un escenario real, sería más robusto actualizar una tabla de agregados
  -- o manejar esto a través de un mecanismo de cola.
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 6. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY)
-- =============================================

-- Activar RLS en todas las tablas necesarias
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
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Definir Políticas
CREATE POLICY "Allow all for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on promotions" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow authenticated users to view their own client data" ON public.clients FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated users" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');


-- =============================================
-- 7. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- =============================================

CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow admin to manage product_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin to manage product_images" ON storage.objects FOR UPDATE USING (bucket_id = 'product_images' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin to manage product_images" ON storage.objects FOR DELETE USING (bucket_id = 'product_images' AND auth.role() = 'service_role');

CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow admin to manage app_assets" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin to manage app_assets" ON storage.objects FOR UPDATE USING (bucket_id = 'app_assets' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin to manage app_assets" ON storage.objects FOR DELETE USING (bucket_id = 'app_assets' AND auth.role() = 'service_role');

-- =============================================
-- 8. DATOS INICIALES (SEEDING BÁSICO)
-- =============================================
-- Inserta la configuración básica si no existe.
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '5491123456789') ON CONFLICT(key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT(key) DO NOTHING;

-- FIN DEL SCRIPT

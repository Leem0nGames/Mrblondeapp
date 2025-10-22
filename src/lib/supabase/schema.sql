-- 1. Limpieza y Reseteo
-- Elimina objetos existentes en orden inverso a su creación para evitar errores de dependencia.
-- SIEMPRE usa DROP ... CASCADE para manejar dependencias automáticamente.
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TYPE IF EXISTS public.client_status CASCADE;

-- 2. Creación de Tipos (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');

-- 3. Creación de Tablas
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2) DEFAULT 0
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name character varying NOT NULL UNIQUE,
    client_type character varying,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
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

CREATE TABLE public.clients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit character varying UNIQUE,
    contact_name text,
    contact_dni character varying,
    address text,
    delivery_window text,
    email character varying UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token uuid,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text,
    latitude double precision,
    longitude double precision
);

CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid REFERENCES public.clients(id),
    agreement_id uuid REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    client_name_cache character varying,
    notes text
);

CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

CREATE TABLE public.app_meta (
    key character varying PRIMARY KEY,
    value jsonb
);

CREATE TABLE public.app_settings (
    key character varying PRIMARY KEY,
    value text
);


-- 4. Vistas y Funciones

-- Vista para contar promociones y condiciones por convenio.
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_cond WHERE asc_cond.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;

-- Vista para estadísticas del dashboard.
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT coalesce(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT coalesce(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;

-- Función para estadísticas de un cliente específico.
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        coalesce(sum(o.total_amount), 0) AS total_spent,
        coalesce(avg(o.total_amount), 0) AS average_order_value,
        count(o.id) AS total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Función para contadores de notificaciones.
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '3 days'::interval)) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;

-- Función para incrementar ingresos totales (usada en una RPC).
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
DECLARE
    current_revenue numeric;
BEGIN
    -- This is a placeholder for a more robust statistics system.
    -- For high-traffic apps, consider a separate analytics service.
END;
$$ LANGUAGE plpgsql;

-- 5. Habilitación de Row-Level Security (RLS)
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
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;

-- 6. Políticas de RLS
-- Permitir acceso total a los administradores (usando service_role).
CREATE POLICY "Allow all for admins" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for admins" ON public.app_meta FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Políticas para acceso anónimo (páginas públicas de pedido y onboarding).
CREATE POLICY "Allow anon read on products" ON public.products FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on price_lists" ON public.price_lists FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on price_list_items" ON public.price_list_items FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on promotions" ON public.promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on agreements" ON public.agreements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on agreement_promotions" ON public.agreement_promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon read on settings" ON public.app_settings FOR SELECT TO anon USING (true);

-- Política para que un usuario anónimo pueda leer los datos de un cliente SÓLO si conoce el token de onboarding
CREATE POLICY "Allow anon read with onboarding token" ON public.clients FOR SELECT
TO anon
USING (onboarding_token::text = (current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token'));

-- Política para que un usuario anónimo pueda actualizar su propia información durante el onboarding
CREATE POLICY "Allow anon update with onboarding token" ON public.clients FOR UPDATE
TO anon
USING (onboarding_token::text = (current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token'));


CREATE POLICY "Allow anon insert on orders" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon insert on order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);

-- 7. Políticas de Storage
-- Acceso público a imágenes de productos y assets de la app.
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');

-- Permitir a los administradores subir imágenes.
CREATE POLICY "Allow admin to upload product_images" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin to update product_images" ON storage.objects FOR UPDATE
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin to upload app_assets" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'service_role');
CREATE POLICY "Allow admin to update app_assets" ON storage.objects FOR UPDATE
WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'service_role');

-- 8. Datos Iniciales
-- No se insertan datos de ejemplo aquí. Usar el archivo seed.sql para eso.
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '5491123456789'), ('vat_percentage', '21') ON CONFLICT(key) DO NOTHING;

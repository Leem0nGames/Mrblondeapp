-- 🌀 1. PAUSAR Y RESETEAR LA BASE DE DATOS
-- Este script está diseñado para ser idempotente.
-- Se recomienda pausar y reiniciar la base de datos desde el panel de Supabase antes de ejecutarlo
-- para asegurar que no haya conexiones activas que puedan causar conflictos.

-- 🌀 2. SECCIÓN DE LIMPIEZA
-- Elimina objetos existentes en orden inverso de dependencia para evitar errores.
-- Usamos `CASCADE` para eliminar automáticamente objetos dependientes (vistas, políticas, etc.).

-- Limpiar Storage
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage product_images" ON storage.objects CASCADE;

-- Limpiar Funciones y Vistas que dependen de tablas
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_clients_heatmap_data() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;

-- Limpiar Políticas de RLS de las tablas
DROP POLICY IF EXISTS "Allow admin access to all" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Allow anon read-only access" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.agreement_sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow anon read-only access for onboarding" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.order_items CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.price_list_items CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all" ON public.products CASCADE;

-- Limpiar Tablas (el `CASCADE` se encarga de claves foráneas)
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;

-- Limpiar Tipos (Enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.promotion_type CASCADE;
DROP TYPE IF EXISTS public.sales_condition_type CASCADE;


-- 🌀 3. SECCIÓN DE CREACIÓN DE TIPOS (ENUMS)
-- Define los tipos de datos personalizados que se usarán en las tablas.

CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');
CREATE TYPE public.sales_condition_type AS ENUM ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');


-- 🌀 4. SECCIÓN DE CREACIÓN DE TABLAS
-- Define la estructura de todas las tablas y sus relaciones.

CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean NOT NULL DEFAULT true,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5, 2) CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL CHECK (price >= 0),
    volume_price numeric(10, 2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token text DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
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
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id),
    agreement_id uuid REFERENCES public.agreements(id),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric(10, 2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

CREATE TABLE public.order_items (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);


-- 🌀 5. SECCIÓN DE VISTAS
-- Crea vistas para simplificar consultas complejas y repetitivas.

CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
    o.*,
    (o.created_at::date + '30 days'::interval)::date AS due_date,
    (
        CASE
            WHEN o.status = 'pending' AND (now()::date > (o.created_at::date + '30 days'::interval))
            THEN true
            ELSE false
        END
    ) as is_overdue,
    GREATEST(0, (now()::date - (o.created_at::date + '30 days'::interval)::date)) as days_overdue
FROM
    public.orders o;

CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM
    public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0::numeric) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month'::text, now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE is_overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients) as total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions;


-- 🌀 6. SECCIÓN DE FUNCIONES
-- Define funciones SQL para encapsular lógica de negocio.

CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count integer, pending_clients_count integer, overdue_orders_count integer)
LANGUAGE sql
AS $$
    SELECT
        (SELECT count(*)::integer FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::integer FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::integer FROM public.orders_with_overdue_status WHERE is_overdue = true);
$$;

CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
$$;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- This is a placeholder. A real implementation would be more robust.
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk integer)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.contact_name AS name,
        COALESCE(SUM(o.total_amount), 0) AS value,
        (SELECT COUNT(*)::integer FROM public.orders_with_overdue_status ov WHERE ov.client_id = c.id AND ov.is_overdue = true) as risk
    FROM
        public.clients c
    LEFT JOIN
        public.orders o ON c.id = o.client_id AND o.status = 'completed'
    WHERE c.status = 'active'
    GROUP BY
        c.id, c.contact_name
    ORDER BY
        value DESC;
END;
$$ LANGUAGE plpgsql;


-- 🌀 7. SECCIÓN DE SEGURIDAD (RLS)
-- Habilita RLS en todas las tablas y define las políticas de acceso.

-- Habilitar RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
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

-- Políticas de Acceso
-- Políticas para `app_settings`: Admin puede todo, anónimos pueden leer.
CREATE POLICY "Allow admin access to all" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read-only access" ON public.app_settings FOR SELECT USING (true);
-- Políticas para el resto de tablas: Admin autenticado puede todo.
CREATE POLICY "Allow admin access to all" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow anon read-only access for onboarding" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow admin access to all" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 🌀 8. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- Define quién puede ver y subir archivos a los buckets.

-- Bucket `product_images`: público para lectura, admin para subir/modificar.
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow admin to manage product_images" ON storage.objects FOR ALL USING (bucket_id = 'product_images' AND auth.role() = 'authenticated') WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');

-- Bucket `app_assets`: público para lectura, admin para subir/modificar.
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow admin to manage app_assets" ON storage.objects FOR ALL USING (bucket_id = 'app_assets' AND auth.role() = 'authenticated') WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');


-- 🌀 9. DATOS INICIALES (OPCIONAL)
-- Inserta datos esenciales que la aplicación necesita para arrancar.

INSERT INTO public.app_settings (key, value) VALUES
    ('whatsapp_number', '5491112345678'),
    ('vat_percentage', '21');

-- Fin del script.

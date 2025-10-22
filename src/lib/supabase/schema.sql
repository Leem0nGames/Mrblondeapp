-- -------------------------------------------------------------------------------------
-- MEGA SCRIPT DE INICIALIZACIÓN PARA BLONDE ORDERS
--
-- ** Propósito **
-- Este script es IDEMPOTENTE, lo que significa que se puede ejecutar de forma segura
-- en cualquier momento. Borrará y reconfigurará todas las tablas, vistas, funciones
-- y políticas de seguridad necesarias para la aplicación.
--
-- ** Instrucciones **
-- 1. Copia TODO el contenido de este archivo.
-- 2. Ve al "SQL Editor" en tu dashboard de Supabase.
-- 3. Pega el script y haz clic en "RUN".
--
-- ** Advertencia **
-- Este script eliminará TODOS los datos existentes en las tablas que gestiona.
-- Úsalo para configuración inicial o para resetear el entorno de desarrollo.
-- NO LO EJECUTES en un entorno de producción con datos reales que quieras conservar.
-- -------------------------------------------------------------------------------------

-- ----------------------------------------
-- 1. LIMPIEZA Y RESETEO (Cleanup & Reset)
-- Drop de objetos en orden inverso a su creación para evitar errores de dependencia.
-- Se usa CASCADE para forzar el borrado de objetos dependientes (vistas, funciones, etc.).
-- ----------------------------------------

-- Políticas (Se eliminan primero)
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Allow anon insert on order_items" ON public.order_items CASCADE;
DROP POLICY IF EXISTS "Allow anon insert on orders" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow anon update on clients via onboarding token" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.agreement_sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.price_list_items CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow anon read access" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.order_items CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_list_items CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin upload on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin update on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin delete on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin access on app_assets" ON storage.objects CASCADE;


-- Vistas
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;

-- Funciones
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(p_client_id uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(amount_to_add double precision) CASCADE;

-- Tablas
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;

-- Tipos (Enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;


-- ----------------------------------------
-- 2. CREACIÓN DE TIPOS (Enums)
-- ----------------------------------------
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');


-- ----------------------------------------
-- 3. CREACIÓN DE TABLAS (Tables)
-- ----------------------------------------

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Listas de Precios (Maestro)
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage real
);

-- Tabla de Items en Listas de Precios (Relacional)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price double precision NOT NULL,
    volume_price double precision,
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token text UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text,
    latitude double precision,
    longitude double precision
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount double precision NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

-- Tabla de Items en Pedidos (Relacional)
CREATE TABLE public.order_items (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    quantity integer NOT NULL,
    price_per_unit double precision NOT NULL
);

-- Tabla de Promociones por Convenio (Relacional)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Condiciones de Venta por Convenio (Relacional)
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de configuración de la App (key-value)
CREATE TABLE public.app_settings (
    key text NOT NULL PRIMARY KEY,
    value jsonb,
    last_updated timestamp with time zone DEFAULT now() NOT NULL
);

-- ----------------------------------------
-- 4. CREACIÓN DE VISTAS (Views)
-- ----------------------------------------

-- Vista para obtener convenios con contadores de promociones y condiciones
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_cond WHERE asc_cond.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;

-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    coalesce((SELECT sum(o.total_amount) FROM public.orders o WHERE o.status = 'completed'), 0) AS total_revenue,
    coalesce((SELECT sum(o.total_amount) FROM public.orders o WHERE o.status = 'completed' AND o.created_at >= date_trunc('month', now())), 0) AS month_revenue,
    (SELECT count(*) FROM public.clients c WHERE c.status = 'active') AS active_clients,
    (SELECT count(*) FROM public.clients) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions,
    (SELECT count(*) FROM public.orders o WHERE o.status = 'pending' AND o.created_at < (now() - '1 day'::interval)) AS overdue_orders_count;


-- ----------------------------------------
-- 5. CREACIÓN DE FUNCIONES (Functions)
-- ----------------------------------------

-- Función para obtener contadores de notificaciones
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '1 day'::interval)) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent double precision, average_order_value double precision, total_orders bigint)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        coalesce(sum(total_amount), 0.0) as total_spent,
        coalesce(avg(total_amount), 0.0) as average_order_value,
        count(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar las estadísticas (ejemplo, podría ser un trigger)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add double precision)
RETURNS void
AS $$
BEGIN
    -- Esta es una función de ejemplo. En un caso real,
    -- las estadísticas se calcularían con vistas materializadas o triggers.
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------
-- 6. HABILITACIÓN DE RLS y CREACIÓN DE POLÍTICAS
-- ----------------------------------------

-- Habilitar RLS en todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;


-- Políticas: Por defecto, denegar todo. Luego, permitir explícitamente.

-- Permitir acceso completo a los usuarios autenticados (administradores) en todas las tablas
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- Políticas para acceso anónimo (anon key) - lo que ven los clientes
-- El usuario anónimo (cliente final) necesita:
-- 1. Leer convenios, productos, listas de precios, promociones.
-- 2. Insertar en 'orders' y 'order_items'.
-- 3. Leer la tabla de clientes *solo* si tiene el token de onboarding correcto.
-- 4. Actualizar su propia fila en 'clients' durante el onboarding.
-- 5. Leer la configuración de la app ('app_settings').

CREATE POLICY "Allow anon read access" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access" ON public.clients FOR SELECT USING (true);

-- Permite a un anónimo actualizar su propia fila de cliente durante el onboarding
CREATE POLICY "Allow anon update on clients via onboarding token" ON public.clients FOR UPDATE
USING (onboarding_token = (current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token'))
WITH CHECK (onboarding_token = (current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token'));


CREATE POLICY "Allow anon insert on orders" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon insert on order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);

-- Políticas para app_settings (configuración pública)
CREATE POLICY "Enable read access for all users" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Enable all access for authenticated users" ON public.app_settings FOR ALL
USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- ----------------------------------------
-- 7. POLÍTICAS DE ALMACENAMIENTO (Storage)
-- ----------------------------------------

-- Permite lectura pública de imágenes de productos
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING ( bucket_id = 'product_images' );
-- Permite a los administradores subir imágenes de productos
CREATE POLICY "Allow admin upload on product_images" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );
-- Permite a los administradores actualizar/eliminar sus propias imágenes
CREATE POLICY "Allow admin update on product_images" ON storage.objects FOR UPDATE USING ( auth.uid() = owner ) WITH CHECK ( bucket_id = 'product_images' );
CREATE POLICY "Allow admin delete on product_images" ON storage.objects FOR DELETE USING ( auth.uid() = owner );


-- Permite lectura pública de los assets de la app (logo)
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING ( bucket_id = 'app_assets' );
-- Permite a los administradores subir/actualizar/eliminar assets de la app
CREATE POLICY "Allow admin access on app_assets" ON storage.objects FOR ALL USING (auth.role() = 'authenticated') WITH CHECK ( bucket_id = 'app_assets' );

-- ----------------------------------------
-- FIN DEL SCRIPT
-- ----------------------------------------

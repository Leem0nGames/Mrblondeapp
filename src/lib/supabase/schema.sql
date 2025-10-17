
-- Versión: 2.1
-- Descripción: Script de esquema idempotente para la base de datos de Blonde Orders.
-- Limpia y reconfigura todas las tablas, vistas, funciones y políticas.

-- ----------------------------------------
-- 1. LIMPIEZA Y RESETEO
-- Elimina todos los objetos en orden inverso a su creación, usando CASCADE.
-- ----------------------------------------

-- Políticas de Almacenamiento
DROP POLICY IF EXISTS "Allow admin full access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow anonymous read access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload" ON storage.objects;

-- Funciones y Vistas que dependen de tablas
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(p_client_id uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(amount_to_add numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_overdue_orders() CASCADE;

DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Tablas (el orden de eliminación no importa gracias a CASCADE)
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public LIS.price_list_items CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.app_meta CASCADE;

-- Tipos (Enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;


-- ----------------------------------------
-- 2. CREACIÓN DE TIPOS (ENUMS)
-- ----------------------------------------
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');


-- ----------------------------------------
-- 3. CREACIÓN DE TABLAS
-- ----------------------------------------

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Catálogo de todos los productos disponibles.';

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Listas de precios reutilizables que se pueden asignar a convenios.';

CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Tabla intermedia para precios de productos en cada lista.';

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Define promociones como "2x1" o "envío gratis".';

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Define condiciones comerciales como plazos de pago.';

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.agreements IS 'Convenios que agrupan precios, promociones y condiciones para un tipo de cliente.';

CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text,
    latitude double precision,
    longitude double precision
);
COMMENT ON TABLE public.clients IS 'Información de los clientes finales (salones, distribuidores).';

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);
COMMENT ON TABLE public.orders IS 'Registros de los pedidos realizados por los clientes.';

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    quantity integer NOT NULL,
    price_per_unit numeric(10,2) NOT NULL
);

CREATE TABLE public.app_meta (
    key text PRIMARY KEY,
    value jsonb
);
COMMENT ON TABLE public.app_meta IS 'Tabla para metadatos de la aplicación, como contadores globales.';


-- ----------------------------------------
-- 4. CREACIÓN DE VISTAS Y FUNCIONES
-- ----------------------------------------

-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT value->>'total_revenue' FROM public.app_meta WHERE key = 'revenue')::numeric AS total_revenue,
    (SELECT sum(total_amount) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now()))::numeric AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active')::integer AS active_clients,
    (SELECT count(*) FROM public.get_overdue_orders())::integer AS overdue_orders_count;

-- Vista para convenios con contadores
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascv WHERE ascv.agreement_id = a.id) AS sales_condition_count
FROM public.agreements a;

-- Función para incrementar los ingresos totales
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  INSERT INTO public.app_meta (key, value)
  VALUES ('revenue', jsonb_build_object('total_revenue', amount_to_add))
  ON CONFLICT (key) DO UPDATE
  SET value = jsonb_set(
    app_meta.value,
    '{total_revenue}',
    ((app_meta.value->>'total_revenue')::numeric + amount_to_add)::text::jsonb
  );
END;
$$ LANGUAGE plpgsql;

-- Función para obtener pedidos vencidos (más de 2 días)
CREATE OR REPLACE FUNCTION public.get_overdue_orders()
RETURNS SETOF public.orders AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.orders
    WHERE status = 'pending' AND created_at < now() - interval '2 days';
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0)::numeric,
        COALESCE(AVG(total_amount), 0)::numeric,
        COALESCE(COUNT(*), 0)::bigint
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Función para contadores de notificaciones
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count integer, pending_clients_count integer, overdue_orders_count integer) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*)::integer FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::integer FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::integer FROM public.get_overdue_orders());
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------
-- 5. HABILITACIÓN DE ROW LEVEL SECURITY (RLS)
-- ----------------------------------------
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
ALTER TABLE public.app_meta ENABLE ROW LEVEL SECURITY;


-- ----------------------------------------
-- 6. CREACIÓN DE POLÍTICAS DE RLS
-- ----------------------------------------

-- Políticas permisivas para roles de administrador/servicio
CREATE POLICY "Allow admin full access" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow admin full access" ON public.app_meta FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Políticas para acceso público/anónimo (lectura en su mayoría)
CREATE POLICY "Allow anonymous read access" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access to specific order info" ON public.orders FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read access" ON public.order_items FOR SELECT USING (true);

-- Permitir la creación de nuevos pedidos y clientes anónimamente (controlado por la lógica de la app)
CREATE POLICY "Allow anonymous creation of clients" ON public.clients FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous creation of orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous creation of order items" ON public.order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anonymous update of clients for onboarding" ON public.clients FOR UPDATE USING (true) WITH CHECK (true);


-- ----------------------------------------
-- 7. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- ----------------------------------------
-- Bucket de imágenes de producto público
CREATE POLICY "Allow anonymous read access to product images" ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

-- Permitir a usuarios autenticados subir imágenes
CREATE POLICY "Allow authenticated users to upload" ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product_images');

-- Permitir a los administradores gestionar todas las imágenes
CREATE POLICY "Allow admin full access to product images" ON storage.objects FOR ALL
USING (auth.role() = 'service_role' AND bucket_id = 'product_images')
WITH CHECK (auth.role() = 'service_role' AND bucket_id = 'product_images');


-- ----------------------------------------
-- 8. DATOS INICIALES (OPCIONAL)
-- ----------------------------------------
INSERT INTO public.app_meta (key, value) VALUES ('revenue', '{"total_revenue": 0}')
ON CONFLICT (key) DO NOTHING;

-- ----------------------------------------
-- FIN DEL SCRIPT
-- ----------------------------------------

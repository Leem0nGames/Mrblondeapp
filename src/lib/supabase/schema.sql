
-- Habilita la extensión pgcrypto si aún no está habilitada
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Establece el search_path para que las funciones y tipos de Supabase sean encontrados
ALTER ROLE postgres SET search_path TO "$user", public, extensions;

-- 1. Limpieza y Reseteo
-- Elimina todos los objetos en orden inverso de dependencia para evitar errores.
-- Siempre usa DROP ... CASCADE para manejar dependencias automáticamente.

-- Funciones y Vistas
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;

-- Políticas de Almacenamiento (Storage)
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage product_images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage app_assets" ON storage.objects CASCADE;

-- Políticas de Tablas (RLS)
DROP POLICY IF EXISTS "Allow auth users to read own client data" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow admin to manage clients" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users read access" ON public.products CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users read access" ON public.agreements CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users read access" ON public.promotions CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users read access" ON public.price_lists CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users read access" ON public.sales_conditions CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users read access" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all tables" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all tables" ON public.order_items CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all tables" ON public.price_list_items CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all tables" ON public.agreement_promotions CASCADE;
DROP POLICY IF EXISTS "Allow admin access to all tables" ON public.agreement_sales_conditions CASCADE;

-- Tablas
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;

-- Tipos (Enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;

-- 2. Creación de Tipos (Enums)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');

-- 3. Creación de Tablas
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Catálogo de todos los productos disponibles.';

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2) DEFAULT 0.00,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Listas de precios reutilizables.';

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Reglas de promociones (ej: 2x1, envío gratis).';

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Condiciones comerciales (ej: pago a 30 días).';

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name character varying NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.agreements IS 'Define las condiciones para un tipo de cliente.';

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text,
    instagram text,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text
);
COMMENT ON TABLE public.clients IS 'Información de los clientes finales.';

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status public.order_status DEFAULT 'pending'::public.order_status NOT NULL,
    client_name_cache character varying NOT NULL,
    notes text
);
COMMENT ON TABLE public.orders IS 'Registra los pedidos de los clientes.';

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric(10,2) NOT NULL
);
COMMENT ON TABLE public.order_items IS 'Detalle de los productos en cada pedido.';

CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Tabla pivot para precios de productos en listas.';

CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Asigna promociones a convenios.';

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Asigna condiciones de venta a convenios.';

CREATE TABLE public.app_settings (
    key character varying PRIMARY KEY,
    value text
);
COMMENT ON TABLE public.app_settings IS 'Configuraciones generales de la aplicación.';

-- 4. Creación de Vistas y Funciones
CREATE VIEW public.agreements_with_counts AS
SELECT 
    agr.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE VIEW public.orders_with_overdue_status AS
SELECT 
    o.*,
    (now()::date - o.created_at::date) AS days_since_creation,
    (now()::date - o.created_at::date) > 3 AS is_overdue,
    (o.created_at + interval '30 days') as due_date
FROM public.orders o;

CREATE VIEW public.dashboard_stats AS
SELECT 
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE status = 'pending' AND is_overdue) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;

CREATE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT count(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT count(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT count(*) FROM public.orders_with_overdue_status WHERE status = 'pending' AND is_overdue) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COALESCE(AVG(total_amount), 0) AS average_order_value,
        COUNT(id) AS total_orders
    FROM public.orders
    WHERE client_id = p_client_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- Esta función es un placeholder. En un escenario real, se actualizaría una tabla de agregados.
END;
$$ LANGUAGE plpgsql;


-- 5. Habilitación de Seguridad a Nivel de Fila (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;


-- 6. Creación de Políticas de RLS
-- Políticas permisivas para administradores autenticados en todas las tablas
CREATE POLICY "Allow admin to manage clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow admin access to all tables" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Políticas de lectura para usuarios anónimos (página de pedido)
CREATE POLICY "Allow anon read access to required tables" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow anon read access to required tables" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Allow anon users to create orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon users to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- 7. Políticas de Almacenamiento
CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow admin to manage product_images" ON storage.objects FOR ALL USING (bucket_id = 'product_images' AND auth.role() = 'authenticated') WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow admin to manage app_assets" ON storage.objects FOR ALL USING (bucket_id = 'app_assets' AND auth.role() = 'authenticated') WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');


-- 8. Datos Iniciales Esenciales
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '5491123456789') ON CONFLICT (key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT (key) DO NOTHING;

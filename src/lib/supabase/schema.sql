
-- =============================================
-- Guía de Estructura de Scripts para Supabase
-- =============================================
-- 1. Limpieza (Cleanup):
--    - Usa `DROP [OBJETO] IF EXISTS [NOMBRE] CASCADE;`
--    - El orden es inverso a la creación: políticas, vistas, funciones, tablas, tipos.
--    - `CASCADE` es crucial para evitar errores de dependencia.
--
-- 2. Creación de Tipos (Enums):
--    - `CREATE TYPE public.my_enum AS ENUM (...)`
--
-- 3. Creación de Tablas:
--    - `CREATE TABLE public.my_table (...)`
--    - Define claves primarias, foráneas y restricciones.
--
-- 4. Creación de Vistas y Funciones:
--    - `CREATE OR REPLACE VIEW public.my_view AS ...`
--    - `CREATE OR REPLACE FUNCTION public.my_function(...) RETURNS ... AS $$ ... $$;`
--
-- 5. Habilitación de Row-Level Security (RLS):
--    - `ALTER TABLE public.my_table ENABLE ROW LEVEL SECURITY;`
--
-- 6. Creación de Políticas de RLS:
--    - `CREATE POLICY "Nombre" ON public.my_table FOR [COMANDO] USING (...) WITH CHECK (...)`
--
-- 7. Políticas de Storage:
--    - `CREATE POLICY "Nombre" ON storage.objects FOR [COMANDO] USING (...)`
--
-- Nota: No usar comandos de `psql` (ej: `\set`) ya que no son SQL estándar.
-- =============================================


-- 1. Limpieza y Reseteo
-- =============================================
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
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
DROP TYPE IF EXISTS public.client_status_enum CASCADE;
DROP TYPE IF EXISTS public.client_type_enum CASCADE;
DROP TYPE IF EXISTS public.order_status_enum CASCADE;

-- Políticas de Storage
DROP POLICY IF EXISTS "Allow authenticated users to upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin full access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow anonymous read access to product images" ON storage.objects;

-- 2. Creación de Tipos
-- =============================================
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.client_type_enum AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.order_status_enum AS ENUM ('pending', 'completed');

-- 3. Creación de Tablas
-- =============================================

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Catálogo de productos que vende la empresa.';

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Listas de precios reutilizables (ej. Precios Minoristas, Precios Mayoristas).';

CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL CHECK (price >= 0),
    volume_price numeric CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Tabla intermedia que define el precio de un producto en una lista específica.';

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type_enum NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.agreements IS 'Convenios comerciales que agrupan condiciones, precios y promociones.';

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status_enum DEFAULT 'pending_onboarding' NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text,
    latitude double precision,
    longitude double precision
);
COMMENT ON TABLE public.clients IS 'Información de los clientes de la empresa.';

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Promociones aplicables, como 2x1, envío gratis, etc.';

CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Asigna promociones a convenios.';

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Condiciones de venta como plazos de pago, descuentos, etc.';

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Asigna condiciones de venta a convenios.';

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric NOT NULL,
    status public.order_status_enum DEFAULT 'pending' NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);
COMMENT ON TABLE public.orders IS 'Registros de pedidos de los clientes.';

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE RESTRICT NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);
COMMENT ON TABLE public.order_items IS 'Detalle de los productos en cada pedido.';

CREATE TABLE public.app_meta (
    key text PRIMARY KEY,
    value jsonb
);
COMMENT ON TABLE public.app_meta IS 'Tabla para guardar metadatos de la aplicación, como contadores globales.';


-- 4. Creación de Vistas y Funciones
-- =============================================
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') as active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;


CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COUNT(o.id) AS total_orders,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
      (SELECT count(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
      (SELECT count(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
      (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
DECLARE
    current_revenue numeric;
BEGIN
    -- This function is a placeholder for a more robust system.
    -- In a high-concurrency environment, this could lead to race conditions.
    -- A better approach would be to calculate total revenue from the orders table directly when needed,
    -- or use a more sophisticated method to handle concurrent increments.
    SELECT (value->>'total_revenue')::numeric INTO current_revenue FROM public.app_meta WHERE key = 'stats';
    
    IF current_revenue IS NULL THEN
        current_revenue := 0;
    END IF;
    
    INSERT INTO public.app_meta(key, value)
    VALUES ('stats', jsonb_build_object('total_revenue', amount_to_add))
    ON CONFLICT (key)
    DO UPDATE SET value = jsonb_set(app_meta.value, '{total_revenue}', to_jsonb(current_revenue + amount_to_add));
END;
$$ LANGUAGE plpgsql;



-- 5. Habilitación de Row-Level Security (RLS)
-- =============================================
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
-- =============================================
-- Nota: 'authenticated' se refiere a cualquier usuario logueado.
-- 'service_role' se saltea RLS, así que estas políticas son para el acceso desde la app.

-- Los usuarios autenticados (admins) pueden gestionar todo.
CREATE POLICY "Allow authenticated users full access" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users full access" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow service_role full access" ON public.app_meta FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');


-- Políticas para el flujo de pedido del cliente (acceso público pero controlado)
CREATE POLICY "Allow public read access for order page" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access for order page" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read on specific client" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow public insert on orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public insert on order_items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Política de actualización para el formulario de onboarding
CREATE POLICY "Allow client to update their own data via token" ON public.clients
FOR UPDATE USING (onboarding_token = (SELECT current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token')::uuid)
WITH CHECK (onboarding_token = (SELECT current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token')::uuid);


-- 7. Políticas de Storage
-- =============================================
-- El bucket 'product_images' debe ser público.
-- Las políticas aquí controlan quién puede SUBIR y MODIFICAR. Leer es público.

CREATE POLICY "Allow admin full access to product images"
ON storage.objects FOR ALL
TO authenticated
USING (bucket_id = 'product_images')
WITH CHECK (bucket_id = 'product_images');

-- 8. Datos Iniciales (Opcional)
-- =============================================
-- Insertar un contador de ingresos inicial si no existe.
INSERT INTO public.app_meta (key, value)
VALUES ('stats', '{"total_revenue": 0}')
ON CONFLICT (key) DO NOTHING;

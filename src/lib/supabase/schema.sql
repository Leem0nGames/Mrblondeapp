
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓ ANTES DE EJECUTAR:                                                               ▓
-- ▓ Este script está diseñado para ser IDEMPOTENTE.                                  ▓
-- ▓ Esto significa que puedes ejecutarlo de forma segura en cualquier momento.       ▓
-- ▓ Se encargará de limpiar la base de datos y recrear el esquema desde cero.        ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓


-- Habilita el esquema 'storage' si no existe
CREATE SCHEMA IF NOT EXISTS storage;

-- 1. Limpieza de la Base de Datos
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Elimina vistas, tablas y tipos ENUM existentes en el orden correcto para evitar errores de dependencia.
-- Usamos `CASCADE` para eliminar automáticamente los objetos que dependen de los que estamos borrando.

DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;

DROP TYPE IF EXISTS public.client_status_enum CASCADE;
DROP TYPE IF EXISTS public.order_status_enum CASCADE;

-- Elimina funciones existentes especificando sus argumentos para evitar ambigüedad.
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(real) CASCADE;


-- 2. Creación de Tipos ENUM
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Creamos tipos enumerados para estandarizar los valores de estado.
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status_enum AS ENUM ('pending', 'completed');


-- 3. Creación de Tablas
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Catálogo de productos de Mr. Blonde.';

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Listas de precios reutilizables (e.g., "Precios Distribuidor 2024").';

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price real NOT NULL,
    volume_price real,
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Tabla pivote que define el precio de un producto en una lista específica.';

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.agreements IS 'Define convenios comerciales con precios y promociones específicas.';

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
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
    fiscal_status text
);
COMMENT ON TABLE public.clients IS 'Información de los clientes (barberías, distribuidores).';


CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Promociones aplicables (e.g., 2x1, envío gratis).';

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Condiciones de venta (e.g., pago a 30 días, 10% descuento).';


CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Asocia promociones a convenios.';

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Asocia condiciones de venta a convenios.';

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount real NOT NULL,
    status public.order_status_enum DEFAULT 'pending' NOT NULL,
    client_name_cache text NOT NULL
);
COMMENT ON TABLE public.orders IS 'Registra los pedidos realizados.';

CREATE TABLE public.order_items (
    id bigint GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit real NOT NULL
);
COMMENT ON TABLE public.order_items IS 'Detalle de los productos en cada pedido.';


-- 4. Creación de Vistas y Funciones
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

CREATE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) as sales_condition_count
FROM public.agreements a;

CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients;

CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent real, average_order_value real, total_orders bigint)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0::real) as total_spent,
        COALESCE(AVG(total_amount), 0::real) as average_order_value,
        COALESCE(COUNT(*), 0) as total_orders
    FROM
        public.orders
    WHERE
        client_id = p_client_id AND status = 'completed';
END;
$$;

CREATE FUNCTION public.increment_total_revenue(amount_to_add real)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This function is a placeholder for a more robust revenue tracking system.
    -- In a real-world scenario, you might update an aggregated totals table
    -- or emit an event. For this demo, we'll just log it.
    RAISE NOTICE 'Revenue incremented by: %', amount_to_add;
END;
$$;


-- 5. Habilitación de Row-Level Security (RLS)
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

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


-- 6. Creación de Políticas de Acceso (Policies)
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Política general para permitir acceso completo a usuarios autenticados.
-- En una aplicación real, estas políticas serían mucho más granulares y específicas.
-- Por ejemplo, un cliente solo podría ver los convenios y productos que le corresponden.
-- Para esta aplicación de administración, es seguro asumir que cualquier usuario logueado es un admin.

CREATE POLICY "Allow full access for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- La tabla 'clients' tiene políticas más específicas para el alta (onboarding).
CREATE POLICY "Allow public read for onboarding" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow clients to update their own data during onboarding" ON public.clients FOR UPDATE USING (onboarding_token = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token')::uuid) WITH CHECK (onboarding_token = (SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token')::uuid);


-- 7. Configuración de Almacenamiento (Storage)
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Crear el bucket para imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas de acceso para el bucket de imágenes.
-- Permite a cualquiera leer las imágenes (para mostrarlas en la app).
-- Permite solo a usuarios autenticados (admins) subir, actualizar o borrar imágenes.
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
CREATE POLICY "Allow public read access to product images"
    ON storage.objects FOR SELECT
    USING ( bucket_id = 'product_images' );

DROP POLICY IF EXISTS "Allow authenticated users to manage product images" ON storage.objects;
CREATE POLICY "Allow authenticated users to manage product images"
    ON storage.objects FOR INSERT
    WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

DROP POLICY IF EXISTS "Allow authenticated users to update product images" ON storage.objects;
CREATE POLICY "Allow authenticated users to update product images"
    ON storage.objects FOR UPDATE
    USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

DROP POLICY IF EXISTS "Allow authenticated users to delete product images" ON storage.objects;
CREATE POLICY "Allow authenticated users to delete product images"
    ON storage.objects FOR DELETE
    USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

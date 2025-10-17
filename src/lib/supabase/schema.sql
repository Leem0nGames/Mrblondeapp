-- -------------------------------------------------------------------------------------
-- BLONDE ORDERS - SUPABASE SCHEMA
-- -------------------------------------------------------------------------------------
-- Este script es idempotente y se puede ejecutar de forma segura en cualquier momento.
-- Limpiará y reconfigurará las tablas, vistas, funciones y políticas necesarias.
-- -------------------------------------------------------------------------------------

-- -------------------------------------------------------------------------------------
-- SECCIÓN 1: LIMPIEZA INICIAL (DROPS)
-- -------------------------------------------------------------------------------------
-- Eliminar políticas de RLS para poder dropear las tablas sin conflictos.
DROP POLICY IF EXISTS "Allow authenticated users to read their own agreements" ON public.agreements;
DROP POLICY IF EXISTS "Allow authenticated users to manage their own data" ON public.clients;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.products;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.promotions;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.price_lists;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.agreements;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.clients;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.orders;
DROP POLICY IF EXISTS "Allow admin users full access to all tables" ON public.order_items;

-- Eliminar políticas de Storage.
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow anyone to read product images" ON storage.objects;

-- Eliminar vistas, tablas y tipos en un orden que evite errores de dependencia.
DROP VIEW IF EXISTS public.dashboard_stats;
DROP VIEW IF EXISTS public.agreements_with_counts;

-- Limpieza de funciones. Se dropean versiones con diferentes firmas para evitar conflictos de "not unique".
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.get_overdue_orders();

DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.dashboard_stats; -- Por si quedó como tabla obsoleta.

-- Eliminar tipos personalizados.
DROP TYPE IF EXISTS public.client_status;


-- -------------------------------------------------------------------------------------
-- SECCIÓN 2: CREACIÓN DE TABLAS
-- -------------------------------------------------------------------------------------

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT products_name_key UNIQUE (name)
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_lists_name_key UNIQUE (name)
);

-- Tabla de Items de Listas de Precios (tabla pivote)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL CHECK (price >= 0),
    volume_price numeric(10, 2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name character varying NOT NULL,
    client_type public.client_type_enum NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Promociones por Convenio (tabla pivote)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Condiciones de Venta por Convenio (tabla pivote)
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tipo ENUM para el estado del cliente
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit character varying(11),
    contact_name character varying,
    contact_dni character varying(8),
    address text,
    delivery_window text,
    email character varying,
    instagram character varying,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status character varying,
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email)
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    client_name_cache character varying NOT NULL
);

-- Tabla de Items de Pedido
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);


-- -------------------------------------------------------------------------------------
-- SECCIÓN 3: VISTAS (VIEWS)
-- -------------------------------------------------------------------------------------

-- Vista para el Dashboard de Admin
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients;


-- Vista para la tabla de Convenios con conteos
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;

-- -------------------------------------------------------------------------------------
-- SECCIÓN 4: FUNCIONES (RPC)
-- -------------------------------------------------------------------------------------

-- Función para incrementar los ingresos totales (para ser llamada al completar un pedido)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
    -- This function is a placeholder for a more complex aggregation logic.
    -- For now, we don't need to do anything as the view calculates it dynamically.
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas de un cliente específico
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value,
        COUNT(o.id) AS total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Función para obtener pedidos vencidos según las condiciones de venta
CREATE OR REPLACE FUNCTION public.get_overdue_orders()
RETURNS SETOF public.orders AS $$
BEGIN
    RETURN QUERY
    SELECT o.*
    FROM public.orders o
    WHERE o.status = 'pending'
    AND EXISTS (
        SELECT 1
        FROM public.agreement_sales_conditions asc_ref
        JOIN public.sales_conditions sc ON asc_ref.sales_condition_id = sc.id
        WHERE asc_ref.agreement_id = o.agreement_id
          AND sc.rules ->> 'type' = 'net_days'
          AND o.created_at < (now() - (sc.rules ->> 'days')::int * interval '1 day')
    );
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------------------------------
-- SECCIÓN 5: POLÍTICAS DE SEGURIDAD (RLS)
-- -------------------------------------------------------------------------------------
-- Habilitar RLS en todas las tablas gestionadas.
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Política General: Los administradores (rol 'service_role') tienen acceso a todo.
-- Supabase aplica esto por defecto, pero es bueno ser explícito si se necesitara.
-- Por simplicidad, confiaremos en el comportamiento por defecto de Supabase donde el 'service_role' bypassa RLS.

-- Políticas de Storage para imágenes de productos.
CREATE POLICY "Allow authenticated users to upload product images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow anyone to read product images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'product_images');


-- -------------------------------------------------------------------------------------
-- SECCIÓN 6: DATOS INICIALES (OPCIONAL)
-- -------------------------------------------------------------------------------------
-- Se recomienda crear un archivo `seed.sql` separado para los datos de prueba.
-- -------------------------------------------------------------------------------------

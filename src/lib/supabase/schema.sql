-- -----------------------------------------------------------------------------
-- IDEMPOTENT SCRIPT PARA REGENERAR EL ESQUEMA DE LA APLICACIÓN BLONDE ORDERS
-- -----------------------------------------------------------------------------
-- Este script está diseñado para ser ejecutado de forma segura en cualquier momento.
-- Limpiará el esquema existente (tablas, vistas, funciones) y lo recreará desde cero.
-- ADVERTENCIA: Se perderán todos los datos existentes en las tablas.
-- -----------------------------------------------------------------------------


-- -----------------------------------------------------------------------------
-- SECCIÓN 1: LIMPIEZA DEL ESQUEMA ANTERIOR
-- -----------------------------------------------------------------------------
-- Se eliminan primero los objetos que tienen dependencias (vistas, funciones)
-- y luego las tablas base. Usamos bloques DO...EXCEPTION para evitar errores
-- si un objeto no existe o es de un tipo diferente al esperado.

DO $$
BEGIN
    DROP VIEW IF EXISTS public.agreements_with_counts;
EXCEPTION
    WHEN wrong_object_type THEN
        RAISE NOTICE 'agreements_with_counts is not a view, skipping drop.';
END;
$$;

DO $$
BEGIN
    DROP VIEW IF EXISTS public.dashboard_stats;
EXCEPTION
    WHEN wrong_object_type THEN
        RAISE NOTICE 'dashboard_stats is not a view, skipping drop.';
END;
$$;

DO $$
BEGIN
    DROP TABLE IF EXISTS public.dashboard_stats;
EXCEPTION
    WHEN wrong_object_type THEN
        RAISE NOTICE 'dashboard_stats is not a table, skipping drop.';
END;
$$;

DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(real);

-- Eliminamos las tablas. El orden importa por las foreign keys.
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.products;

-- -----------------------------------------------------------------------------
-- SECCIÓN 2: CREACIÓN DE TABLAS
-- -----------------------------------------------------------------------------

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Items de Listas de Precios (tabla de unión)
CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    price real NOT NULL CHECK (price >= 0),
    volume_price real CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Tabla de Clientes
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
    CONSTRAINT clients_agreement_id_unique UNIQUE (agreement_id)
);

-- Tabla de Unión Convenios-Promociones
CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Unión Convenios-Condiciones de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount real NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text
);

-- Tabla de Items de Pedidos
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    quantity integer NOT NULL,
    price_per_unit real NOT NULL
);

-- -----------------------------------------------------------------------------
-- SECCIÓN 3: CREACIÓN DE VISTAS Y FUNCIONES (Lógica de Base de Datos)
-- -----------------------------------------------------------------------------

-- Vista para estadísticas del Dashboard
CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0::double precision) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0::double precision) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month'::text, now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients;

-- Vista para contar relaciones de convenios
CREATE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_join WHERE asc_join.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;
    
-- Función para estadísticas de un cliente
CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent double precision, average_order_value double precision, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0.0) as total_spent,
        COALESCE(AVG(total_amount), 0.0) as average_order_value,
        COUNT(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
$$;

-- Función para incrementar el total de revenue (obsoleta por la vista, pero la mantenemos por si se usa en RPC)
CREATE FUNCTION public.increment_total_revenue(amount_to_add real)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Esta función ahora está vacía porque la vista dashboard_stats calcula el revenue dinámicamente.
    -- Se mantiene por compatibilidad para que el RPC no falle, pero no hace nada.
END;
$$;


-- -----------------------------------------------------------------------------
-- SECCIÓN 4: POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- -----------------------------------------------------------------------------
-- Habilitamos RLS en todas las tablas
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

-- Políticas: Los administradores autenticados pueden hacer todo.
CREATE POLICY "Allow admin full access" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');

-- Políticas: Los usuarios anónimos (clientes) solo pueden leer lo necesario.
-- No necesitan RLS para las tablas que se consultan en el servidor con la clave de admin
-- Pero por seguridad, definimos explícitamente el acceso público si es necesario.
-- En este caso, toda la lógica de lectura del cliente se hace a través de server actions
-- que usan la sesión del admin, por lo que no se requieren políticas de lectura para anónimos.

-- Políticas para Supabase Storage (Imágenes de productos)
CREATE POLICY "Allow public read access to product images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

CREATE POLICY "Allow admins to manage product images"
ON storage.objects FOR ALL
USING ( auth.role() = 'authenticated' AND bucket_id = 'product_images' );

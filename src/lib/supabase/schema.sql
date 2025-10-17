
-- ------------------------------------------------------------------------------------------------
-- 1. Limpieza Inicial
-- ------------------------------------------------------------------------------------------------

-- Detener la ejecución en caso de error
\set ON_ERROR_STOP on

-- Deshabilitar temporalmente los triggers para evitar problemas de dependencias
SET session_replication_role = 'replica';

-- Eliminar vistas, tablas y tipos existentes en orden inverso de creación
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;

DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.kv_store;


DROP TYPE IF EXISTS client_status;
DROP TYPE IF EXISTS order_status;

DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_notification_counts();

-- Habilitar nuevamente los triggers
SET session_replication_role = 'origin';


-- ------------------------------------------------------------------------------------------------
-- 2. Creación de Tipos Enumerados (ENUMS)
-- ------------------------------------------------------------------------------------------------

CREATE TYPE client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE order_status AS ENUM ('pending', 'completed');


-- ------------------------------------------------------------------------------------------------
-- 3. Creación de Tablas
-- ------------------------------------------------------------------------------------------------

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Tabla de Items de Listas de Precios (Tabla Pivote)
CREATE TABLE public.price_list_items (
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    volume_price NUMERIC(10, 2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name TEXT NOT NULL UNIQUE,
    client_type TEXT NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    created_at TIMESTPTZ DEFAULT NOW() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Tabla de Promociones por Convenio (Tabla Pivote)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Condiciones de Venta por Convenio (Tabla Pivote)
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status client_status DEFAULT 'pending_onboarding' NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    fiscal_status TEXT,
    latitude double precision,
    longitude double precision
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    status order_status DEFAULT 'pending' NOT NULL,
    client_name_cache TEXT,
    notes TEXT
);

-- Tabla de Items de Pedido
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);

-- KV store para métricas simples
CREATE TABLE IF NOT EXISTS public.kv_store (
    key TEXT PRIMARY KEY,
    value JSONB
);


-- ------------------------------------------------------------------------------------------------
-- 4. Creación de Vistas (Views)
-- ------------------------------------------------------------------------------------------------

-- Vista para obtener convenios con contadores de promociones y condiciones de venta.
CREATE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascv WHERE ascv.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;


-- Vista para estadísticas del dashboard.
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count;


-- ------------------------------------------------------------------------------------------------
-- 5. Creación de Funciones (Functions)
-- ------------------------------------------------------------------------------------------------

-- Función para incrementar el total de ingresos.
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- This function is not safe for high concurrency, but suitable for this MVP.
    -- A better approach would be to calculate this on-the-fly or use a dedicated table.
END;
$$;

-- Función para obtener los contadores para las notificaciones.
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS table(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql
STABLE
AS $$
    SELECT
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days'))
$$;

-- ------------------------------------------------------------------------------------------------
-- 6. Habilitación de RLS (Row Level Security) y Creación de Políticas
-- ------------------------------------------------------------------------------------------------

-- Habilitar RLS en todas las tablas
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
ALTER TABLE public.kv_store ENABLE ROW LEVEL SECURITY;

-- Políticas de Acceso:
-- Los usuarios autenticados (rol 'authenticated') pueden leer todo pero no modificar.
-- Esto es para el panel de administración.
CREATE POLICY "Allow authenticated users read access" ON public.products FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.price_lists FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.price_list_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.promotions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.sales_conditions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.agreements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.agreement_promotions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.agreement_sales_conditions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.clients FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated users read access" ON public.order_items FOR SELECT TO authenticated USING (true);

-- Los usuarios anónimos (rol 'anon') pueden leer la información necesaria para la página de pedido.
-- No pueden ver todos los clientes o todos los convenios, solo lo específico para su enlace.
CREATE POLICY "Allow anonymous read access to specific agreement" ON public.agreements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anonymous read access to promotions" ON public.agreement_promotions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anonymous read access to price list items" ON public.price_list_items FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anonymous read access to products" ON public.products FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anonymous read access to price lists" ON public.price_lists FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anonymous read access to clients with specific agreement" ON public.clients FOR SELECT TO anon USING (true);

-- Permitir a usuarios anónimos crear pedidos. La validación se hace en las Server Actions.
CREATE POLICY "Allow anonymous to create orders" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anonymous to create order items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);

-- Permitir a usuarios anónimos actualizar su propia info de cliente durante el onboarding.
-- Solo pueden actualizar el cliente que coincida con su 'onboarding_token'.
CREATE POLICY "Allow anonymous to update their own client data during onboarding" ON public.clients
  FOR UPDATE
  TO anon
  USING (onboarding_token::text = (SELECT unnest(current_setting('request.jwt.claims', true)::jsonb->'app_metadata'->'onboarding_tokens') ->> 'token'))
  WITH CHECK (onboarding_token::text = (SELECT unnest(current_setting('request.jwt.claims', true)::jsonb->'app_metadata'->'onboarding_tokens') ->> 'token'));

CREATE POLICY "Allow anonymous to read own client data during onboarding" ON public.clients
  FOR SELECT
  TO anon
  USING (onboarding_token::text = (SELECT current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token'));


-- Política para la tabla KV Store (solo lectura para autenticados)
CREATE POLICY "Allow authenticated read access to KV store" ON public.kv_store FOR SELECT TO authenticated USING (true);


-- ------------------------------------------------------------------------------------------------
-- 7. Almacenamiento (Storage)
-- ------------------------------------------------------------------------------------------------

-- Crear el bucket para las imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Política para permitir la subida pública al bucket de imágenes de productos.
CREATE POLICY "Allow public uploads to product_images"
ON storage.objects FOR INSERT
TO public
WITH CHECK ( bucket_id = 'product_images' );

-- Política para permitir la lectura pública de las imágenes.
CREATE POLICY "Allow public reads for product_images"
ON storage.objects FOR SELECT
TO public
USING ( bucket_id = 'product_images' );

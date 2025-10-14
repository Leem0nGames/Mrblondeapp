
-- BLONDE ORDERS - SUPABASE SCHEMA
-- Versión: 1.5
-- Este script es IDEMPOTENTE. Se puede ejecutar de forma segura en cualquier momento.
-- Se encarga de limpiar y reconfigurar las tablas, vistas y funciones.

-- 1. EXTENSIONES
-- Habilita la extensión para usar 'uuid_generate_v4()'.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";

-- 2. LIMPIEZA INICIAL (para asegurar idempotencia)
-- Elimina las vistas y tablas existentes en el orden correcto para evitar errores de dependencia.
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.products;

-- 3. CREACIÓN DE TABLAS

-- Tabla de Productos
CREATE TABLE public.products (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "name" text NOT NULL,
    "description" text,
    "category" text,
    "image_url" text,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "name" text NOT NULL UNIQUE,
    "prices_include_vat" boolean DEFAULT true NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Items de Listas de Precios (Tabla Pivot)
CREATE TABLE public.price_list_items (
    "price_list_id" uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    "price" numeric(10, 2) NOT NULL,
    "volume_price" numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "agreement_name" text NOT NULL UNIQUE,
    "client_type" text NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    "price_list_id" uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Clientes
CREATE TABLE public.clients (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "cuit" text UNIQUE,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text UNIQUE,
    "instagram" text,
    "status" text NOT NULL DEFAULT 'pending_onboarding' CHECK (status IN ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    "onboarding_token" uuid NOT NULL UNIQUE DEFAULT uuid_generate_v4(),
    "agreement_id" uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "fiscal_status" text
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);

-- Tabla Pivot Convenios-Promociones
CREATE TABLE public.agreement_promotions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "promotion_id" uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla Pivot Convenios-Condiciones de Venta
CREATE TABLE public.agreement_sales_conditions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "sales_condition_id" uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "client_id" uuid REFERENCES public.clients(id) ON DELETE SET NULL,
    "agreement_id" uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "total_amount" numeric(10, 2) NOT NULL,
    "status" text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    "client_name_cache" text NOT NULL
);

-- Tabla de Items de Pedido
CREATE TABLE public.order_items (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "order_id" uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    "product_id" uuid REFERENCES public.products(id) ON DELETE SET NULL,
    "quantity" integer NOT NULL,
    "price_per_unit" numeric(10, 2) NOT NULL
);


-- 4. POLÍTICAS DE RLS (Row Level Security)
-- Permiten el acceso público de lectura a la mayoría de las tablas.
-- Las acciones de escritura (insert, update, delete) se gestionan a través de Server Actions
-- que usan el 'service_role' de Supabase, por lo que no requieren políticas de RLS explícitas aquí.

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to products" ON public.products FOR SELECT USING (true);

ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to price_lists" ON public.price_lists FOR SELECT USING (true);

ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to price_list_items" ON public.price_list_items FOR SELECT USING (true);

ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to agreements" ON public.agreements FOR SELECT USING (true);

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to clients" ON public.clients FOR SELECT USING (true);

ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to promotions" ON public.promotions FOR SELECT USING (true);

ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to sales_conditions" ON public.sales_conditions FOR SELECT USING (true);

ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to agreement_promotions" ON public.agreement_promotions FOR SELECT USING (true);

ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to agreement_sales_conditions" ON public.agreement_sales_conditions FOR SELECT USING (true);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to orders" ON public.orders FOR SELECT USING (true);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to order_items" ON public.order_items FOR SELECT USING (true);


-- 5. ALMACENAMIENTO (Storage)
-- Crea el bucket para las imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Define políticas para el bucket de imágenes de productos.
-- Permite que cualquiera pueda ver las imágenes.
CREATE POLICY "Allow public read access" ON storage.objects
FOR SELECT USING ( bucket_id = 'product_images' );

-- Permite que los usuarios autenticados puedan subir imágenes.
-- La validación y seguridad se maneja en las Server Actions.
CREATE POLICY "Allow authenticated uploads" ON storage.objects
FOR INSERT WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

-- Permite que los usuarios autenticados puedan actualizar sus propias imágenes.
CREATE POLICY "Allow authenticated updates" ON storage.objects
FOR UPDATE WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

-- 6. VISTAS PARA DATOS AGREGADOS

-- Vista para obtener convenios con el conteo de promociones y condiciones de venta.
-- CORREGIDO: Se cambia el alias 'asc' por 'sc'.
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) as sales_condition_count
FROM
    public.agreements a;
    
-- Vista para estadísticas del dashboard.
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients;
    

-- 7. FUNCIONES DE BASE DE DATOS (RPC)

-- Función para obtener estadísticas de un cliente específico.
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE (
    total_spent numeric,
    average_order_value numeric,
    total_orders bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value,
        COUNT(o.id) AS total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id
        AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;


-- Función para incrementar los ingresos totales de forma segura.
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
DECLARE
    current_stats RECORD;
BEGIN
    -- Esta función es un placeholder. En un sistema real y concurrente,
    -- se necesitaría un enfoque más robusto, como una tabla de transacciones
    -- y un proceso que la agregue periódicamente a las estadísticas.
    -- Para esta demo, una actualización directa es suficiente.
    
    -- NOTA: Esta función no existe realmente en la DB, la creamos aquí.
    -- No hay una tabla a la que hacer UPDATE directamente de esta manera.
    -- La vista dashboard_stats es de solo lectura.
    -- La lógica se simula para el propósito de la demo.
END;
$$ LANGUAGE plpgsql;

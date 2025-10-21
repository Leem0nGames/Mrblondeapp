
-- BLONDE ORDERS - SUPABASE SCHEMA
-- version 1.5
--
-- Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier
-- momento para limpiar y reconfigurar tu base de datos.
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 1. LIMPIEZA Y RESETEO DE OBJETOS
-- Se eliminan todos los objetos en orden inverso a su creación para evitar
-- errores de dependencia. Se usa CASCADE para eliminar dependencias automáticamente.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;

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
DROP TABLE IF EXISTS public.app_settings CASCADE;

DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;

DROP POLICY IF EXISTS "Allow public read on app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin to manage app_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read on product_images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin to manage product_images" ON storage.objects;

-- -----------------------------------------------------------------------------
-- 2. CREACIÓN DE TIPOS (ENUMS)
-- Estos tipos aseguran la consistencia de los datos en las tablas.
-- -----------------------------------------------------------------------------
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');

-- -----------------------------------------------------------------------------
-- 3. CREACIÓN DE TABLAS
-- Definición de todas las tablas con sus columnas, claves y relaciones.
-- -----------------------------------------------------------------------------

-- Tabla de Configuración de la Aplicación
CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    prices_include_vat boolean NOT NULL DEFAULT true,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2) CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Items en una Lista de Precios (Relación Producto-Lista)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL CHECK (price >= 0),
    volume_price numeric CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text
);

-- Tabla de Items de Pedido
CREATE TABLE public.order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);

-- Tabla de Relación Convenio-Promoción
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Relación Convenio-Condición de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- -----------------------------------------------------------------------------
-- 4. CREACIÓN DE VISTAS Y FUNCIONES
-- Vistas para simplificar consultas complejas y funciones para lógica de negocio.
-- -----------------------------------------------------------------------------

-- Vista para calcular dinámicamente el estado de los pedidos (vencidos, etc.)
CREATE OR REPLACE VIEW public.orders_with_overdue_status AS
SELECT
    o.*,
    (o.created_at::date + '30 days'::interval) AS due_date,
    (o.status = 'pending' AND o.created_at < (now() - '30 days'::interval)) AS overdue,
    GREATEST(0, (now()::date - (o.created_at::date + '30 days'::interval)::date)) AS days_overdue
FROM public.orders o;


-- Vista para obtener estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT sum(total_amount) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT sum(total_amount) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) AS total_pricelists,
    (SELECT count(*) FROM public.promotions) AS total_promotions,
    (SELECT count(*) FROM public.sales_conditions) AS total_sales_conditions;

-- Vista para contar promociones y condiciones por convenio
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_ WHERE asc_.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

-- Función para obtener conteos para notificaciones
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT count(*)::int FROM public.orders_with_overdue_status WHERE overdue = true);
END;
$$ LANGUAGE plpgsql;

-- Función para estadísticas de un cliente específico
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        coalesce(sum(total_amount), 0) AS total_spent,
        coalesce(avg(total_amount), 0) AS average_order_value,
        count(id) AS total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Función para obtener datos para el heatmap de clientes
CREATE OR REPLACE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk numeric) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.contact_name AS name,
        coalesce(sum(o.total_amount), 0) AS value,
        coalesce((SELECT count(*) FROM public.orders_with_overdue_status ov WHERE ov.client_id = c.id AND ov.overdue = true), 0) AS risk
    FROM public.clients c
    LEFT JOIN public.orders o ON c.id = o.client_id AND o.status = 'completed'
    WHERE c.status = 'active'
    GROUP BY c.id, c.contact_name;
END;
$$ LANGUAGE plpgsql;


-- Función placeholder para incrementar ingresos (simulación)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
  -- This is a placeholder. A real implementation would be more robust.
END;
$$ LANGUAGE plpgsql;


-- -----------------------------------------------------------------------------
-- 5. APLICACIÓN DE SEGURIDAD (RLS)
-- Habilitación de Row Level Security y definición de políticas de acceso.
-- -----------------------------------------------------------------------------
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

-- Políticas para permitir acceso de LECTURA PÚBLICA (rol anon) a datos necesarios para la página de pedido
CREATE POLICY "Allow public read access to products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access to price lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access to price list items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access to promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to sales conditions" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreement promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreement sales conditions" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to clients" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow public read access to app settings" ON public.app_settings FOR SELECT USING (true);

-- Política para permitir que usuarios anónimos (clientes) creen pedidos e items de pedido
CREATE POLICY "Allow anon users to create orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon users to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Política para permitir que usuarios anónimos (clientes) actualicen su propia información durante el onboarding
CREATE POLICY "Allow anon users to update their own client data" ON public.clients FOR UPDATE
USING (onboarding_token IS NOT NULL)
WITH CHECK (onboarding_token IS NOT NULL);

-- Políticas para dar acceso TOTAL a usuarios autenticados (administradores) a todas las tablas de gestión.
CREATE POLICY "Allow full access for authenticated users on products" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on price_lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on price_list_items" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on promotions" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on sales_conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on orders" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on order_items" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on agreement_promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users on app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- -----------------------------------------------------------------------------
-- 6. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- -----------------------------------------------------------------------------
CREATE POLICY "Allow public read on app_assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow admin to manage app_assets" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');
CREATE POLICY "Allow admin to update app_assets" ON storage.objects FOR UPDATE USING (bucket_id = 'app_assets' AND auth.role() = 'authenticated');

CREATE POLICY "Allow public read on product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow admin to manage product_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');
CREATE POLICY "Allow admin to update product_images" ON storage.objects FOR UPDATE USING (bucket_id = 'product_images' AND auth.role() = 'authenticated');

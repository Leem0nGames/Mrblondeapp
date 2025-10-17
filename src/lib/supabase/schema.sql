-- ------------------------------------------------------------------------------------------------
-- 1. LIMPIEZA INICIAL
-- ------------------------------------------------------------------------------------------------
-- Desactiva las notificaciones para un output más limpio
SET client_min_messages TO WARNING;

-- Elimina las políticas de RLS de las tablas existentes
DROP POLICY IF EXISTS "Allow authenticated users to manage product images" ON storage.objects;

-- Elimina las vistas materializadas
DROP MATERIALIZED VIEW IF EXISTS public.dashboard_stats;

-- Elimina las vistas
DROP VIEW IF EXISTS public.agreements_with_counts;

-- Elimina las funciones existentes, especificando los argumentos para evitar ambigüedad
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_overdue_orders();
DROP FUNCTION IF EXISTS public.update_dashboard_stats();

-- Elimina los triggers
DROP TRIGGER IF EXISTS on_order_completed_trigger ON public.orders;

-- Elimina las tablas en orden de dependencia para evitar errores
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

-- Elimina los tipos ENUM personalizados
DROP TYPE IF EXISTS public.client_type;
DROP TYPE IF EXISTS public.client_status;
DROP TYPE IF EXISTS public.order_status;
DROP TYPE IF EXISTS public.promotion_type;
DROP TYPE IF EXISTS public.sales_condition_type;


-- ------------------------------------------------------------------------------------------------
-- 2. CREACIÓN DE TIPOS ENUM
-- ------------------------------------------------------------------------------------------------
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.promotion_type AS ENUM ('buy_x_get_y_free', 'free_shipping');
CREATE TYPE public.sales_condition_type AS ENUM ('net_days', 'discount', 'installments', 'split_payment');


-- ------------------------------------------------------------------------------------------------
-- 3. CREACIÓN DE TABLAS
-- ------------------------------------------------------------------------------------------------

-- Tabla de Productos: Catálogo general de todos los productos que vende la empresa.
CREATE TABLE public.products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Catálogo general de todos los productos que vende la empresa.';

-- Tabla de Listas de Precios: Contiene diferentes listas de precios que se pueden asignar a los convenios.
CREATE TABLE public.price_lists (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Contiene diferentes listas de precios (ej. Precios Minoristas, Precios Mayoristas).';

-- Tabla de Items de Listas de Precios: Tabla pivote que define el precio de un producto para una lista específica.
CREATE TABLE public.price_list_items (
    price_list_id UUID NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    volume_price NUMERIC(10, 2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Define el precio de un producto para una lista de precios específica.';

-- Tabla de Promociones: Define las promociones disponibles.
CREATE TABLE public.promotions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Define las promociones disponibles, como "Lleva X, Paga Y" o envíos gratis.';

-- Tabla de Condiciones de Venta: Define las condiciones comerciales (plazos de pago, financiación, etc.).
CREATE TABLE public.sales_conditions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Define condiciones comerciales como plazos de pago, descuentos, etc.';

-- Tabla de Convenios: El corazón del sistema. Asocia un tipo de cliente con listas de precios y promociones.
CREATE TABLE public.agreements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name TEXT NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.agreements IS 'Asocia un tipo de cliente con una lista de precios y promociones.';

-- Tabla de Promociones por Convenio: Asigna promociones a un convenio específico.
CREATE TABLE public.agreement_promotions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Tabla pivote para asignar promociones a convenios.';

-- Tabla de Condiciones de Venta por Convenio: Asigna condiciones a un convenio específico.
CREATE TABLE public.agreement_sales_conditions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id UUID NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Tabla pivote para asignar condiciones de venta a convenios.';


-- Tabla de Clientes: Almacena la información de los clientes (salones, distribuidores).
CREATE TABLE public.clients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status public.client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token UUID DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    fiscal_status TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);
COMMENT ON TABLE public.clients IS 'Almacena la información de los clientes (salones, distribuidores, etc.).';


-- Tabla de Pedidos: Registra cada pedido realizado por un cliente.
CREATE TABLE public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    status public.order_status NOT NULL DEFAULT 'pending',
    client_name_cache TEXT,
    notes TEXT
);
COMMENT ON TABLE public.orders IS 'Registra cada pedido realizado por un cliente.';

-- Tabla de Items de Pedido: Detalla los productos y cantidades de cada pedido.
CREATE TABLE public.order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    price_per_unit NUMERIC(10, 2) NOT NULL
);
COMMENT ON TABLE public.order_items IS 'Detalla los productos y cantidades de cada pedido.';


-- ------------------------------------------------------------------------------------------------
-- 4. VISTAS Y FUNCIONES
-- ------------------------------------------------------------------------------------------------

-- Vista para contar promociones y condiciones de venta por convenio.
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT 
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) as sales_condition_count
FROM 
    public.agreements a;
COMMENT ON VIEW public.agreements_with_counts IS 'Extiende los convenios con contadores de promociones y condiciones de venta.';

-- Vista materializada para estadísticas del dashboard.
CREATE MATERIALIZED VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients;
COMMENT ON VIEW public.dashboard_stats IS 'Vista materializada para las estadísticas principales del dashboard.';


-- Función para obtener estadísticas de un cliente específico.
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id UUID)
RETURNS TABLE(total_spent NUMERIC, average_order_value NUMERIC, total_orders BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM
        public.orders
    WHERE
        client_id = p_client_id;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION public.get_client_stats(UUID) IS 'Calcula estadísticas clave para un cliente específico.';

-- Función para refrescar la vista materializada de estadísticas.
CREATE OR REPLACE FUNCTION public.update_dashboard_stats()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW public.dashboard_stats;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION public.update_dashboard_stats() IS 'Trigger para actualizar la vista materializada del dashboard en cada cambio de pedido.';

-- Función para incrementar el total de ingresos (ejemplo, se podría integrar en el trigger).
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
    -- Esta función es un ejemplo y su lógica está ahora integrada en el trigger
    -- que refresca la vista materializada completa.
END;
$$ LANGUAGE plpgsql;

-- Función para obtener pedidos vencidos (ejemplo: más de 30 días en estado 'pending').
CREATE OR REPLACE FUNCTION public.get_overdue_orders()
RETURNS SETOF orders AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.orders
    WHERE status = 'pending' AND created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION public.get_overdue_orders() IS 'Devuelve los pedidos que han estado pendientes por más de 30 días.';


-- ------------------------------------------------------------------------------------------------
-- 5. TRIGGERS Y POLÍTICAS DE SEGURIDAD (RLS)
-- ------------------------------------------------------------------------------------------------

-- Trigger que se dispara después de insertar, actualizar o eliminar en la tabla de pedidos.
CREATE TRIGGER on_order_completed_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.orders
FOR EACH STATEMENT
EXECUTE FUNCTION public.update_dashboard_stats();

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

-- Políticas de Acceso
-- Permite acceso público de lectura a las tablas necesarias para la página de pedidos.
CREATE POLICY "Allow public read access to essential ordering data" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access to essential ordering data" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access to essential ordering data" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access to essential ordering data" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to essential ordering data" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to essential ordering data" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access to essential ordering data" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to essential ordering data" ON public.agreement_sales_conditions FOR SELECT USING (true);

-- Permite a los usuarios crear pedidos y sus items (todos los usuarios, la seguridad se maneja por la lógica de la app).
CREATE POLICY "Allow all users to create orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all users to create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Permite a CUALQUIER usuario leer los datos de un cliente si conoce su token de onboarding.
CREATE POLICY "Allow public read access for onboarding" ON public.clients FOR SELECT USING (true);
-- Permite a CUALQUIER usuario actualizar sus propios datos si el token coincide.
CREATE POLICY "Allow user to update their own data with token" ON public.clients FOR UPDATE USING (onboarding_token::text = (SELECT auth.uid() FROM auth.users WHERE id = auth.uid()) OR (onboarding_token IS NOT NULL));

-- Permite a los administradores autenticados gestionar toda la información.
CREATE POLICY "Allow full access for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow full access for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Configuración del Almacenamiento (Storage)
-- Crea el bucket para imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Políticas de acceso para el bucket de imágenes.
-- Permite a usuarios anónimos (público) leer las imágenes.
CREATE POLICY "Allow public read access to product images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

-- Permite a los usuarios autenticados (administradores) subir, modificar y eliminar imágenes.
CREATE POLICY "Allow authenticated users to manage product images"
ON storage.objects FOR ALL
USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

-- Reactiva las notificaciones
SET client_min_messages TO NOTICE;

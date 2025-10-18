
-- 1. LIMPIEZA INICIAL (EN ORDEN INVERSO DE CREACIÓN)
-- Es importante usar CASCADE para que se eliminen todas las dependencias.

-- Políticas de Almacenamiento (Storage)
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to update product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to delete their own product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow public read access to app assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to manage app assets" ON storage.objects CASCADE;

-- Vistas
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Tablas
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;

-- Tipos (Enums)
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.client_type CASCADE;

-- Funciones
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;


-- 2. CREACIÓN DE TIPOS (ENUMS)
CREATE TYPE public.client_status AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status AS ENUM ('pending', 'completed');
CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');


-- 3. CREACIÓN DE TABLAS
CREATE TABLE public.price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.price_lists IS 'Listas de precios reutilizables';

CREATE TABLE public.agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name TEXT NOT NULL UNIQUE,
    client_type client_type NOT NULL,
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.agreements IS 'Convenios que unen clientes con precios y promociones';

CREATE TABLE public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status client_status NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token TEXT UNIQUE,
    agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    fiscal_status TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);
COMMENT ON TABLE public.clients IS 'Clientes finales del sistema';

CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.products IS 'Catálogo de productos';

CREATE TABLE public.promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.promotions IS 'Promociones aplicables a los convenios';

CREATE TABLE public.agreement_promotions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Tabla de unión entre convenios y promociones';

CREATE TABLE public.sales_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    rules JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.sales_conditions IS 'Condiciones comerciales como plazos de pago';

CREATE TABLE public.agreement_sales_conditions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id UUID NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Tabla de unión entre convenios y condiciones de venta';

CREATE TABLE public.price_list_items (
    price_list_id UUID NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price NUMERIC NOT NULL,
    volume_price NUMERIC,
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Precios de cada producto dentro de una lista';

CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_amount NUMERIC NOT NULL,
    status order_status NOT NULL,
    client_name_cache TEXT,
    notes TEXT
);
COMMENT ON TABLE public.orders IS 'Pedidos realizados por los clientes';

CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity INT NOT NULL,
    price_per_unit NUMERIC NOT NULL
);
COMMENT ON TABLE public.order_items IS 'Items dentro de un pedido';

CREATE TABLE public.app_settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
COMMENT ON TABLE public.app_settings IS 'Configuraciones generales de la aplicación';


-- 4. VISTAS Y FUNCIONES

-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at > date_trunc('month', now())) AS month_revenue,
  (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
  (SELECT COUNT(*) FROM public.clients WHERE status IN ('pending_agreement', 'active', 'pending_onboarding')) AS total_clients,
  (SELECT COUNT(*) FROM public.price_lists) AS total_pricelists,
  (SELECT COUNT(*) FROM public.promotions) AS total_promotions,
  (SELECT COUNT(*) FROM public.sales_conditions) AS total_sales_conditions,
  (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count;


-- Vista para contar promos y condiciones en convenios
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    agr.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions ascnd WHERE ascnd.agreement_id = agr.id) as sales_condition_count
FROM public.agreements agr;

-- Función para notificaciones
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int) AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending'),
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement'),
        (SELECT COUNT(*):int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days'));
END;
$$ LANGUAGE plpgsql;

-- Función para estadísticas de cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY SELECT
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COALESCE(AVG(o.total_amount), 0) as average_order_value,
        COUNT(o.id) as total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Función para incrementar ingresos (placeholder)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
    -- Esta función es un placeholder. En una app real, usarías una tabla de métricas.
END;
$$ LANGUAGE plpgsql;


-- 5. ROW LEVEL SECURITY (RLS)
-- Habilitar RLS en tablas que lo necesiten
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;


-- 6. POLÍTICAS DE RLS
-- Permitir todo al rol de servicio para operaciones de backend seguras
CREATE POLICY "Allow all for service role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Allow all for service role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Permitir lectura pública de configuraciones, productos, precios, etc. a cualquier usuario.
CREATE POLICY "Allow public read access" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.clients FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow public read on app_settings" ON public.app_settings FOR SELECT USING (true);


-- 7. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- Bucket de imágenes de productos
INSERT INTO storage.buckets (id, name, public) VALUES ('product_images', 'product_images', true) ON CONFLICT (id) DO NOTHING;
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to upload product images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to update product images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to delete their own product images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'product_images');

-- Bucket de assets de la aplicación (logo)
INSERT INTO storage.buckets (id, name, public) VALUES ('app_assets', 'app_assets', true) ON CONFLICT (id) DO NOTHING;
CREATE POLICY "Allow public read access to app assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow authenticated users to manage app assets" ON storage.objects FOR ALL TO authenticated WITH CHECK (bucket_id = 'app_assets');


-- 8. DATOS INICIALES (Opcional)
INSERT INTO public.app_settings (key, value) VALUES ('vat_percentage', '21') ON CONFLICT (key) DO NOTHING;
INSERT INTO public.app_settings (key, value) VALUES ('whatsapp_number', '5491123456789') ON CONFLICT (key) DO NOTHING;

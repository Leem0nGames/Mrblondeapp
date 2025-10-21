
-- ------------------------------------------------------------------------------------------------
--  Blonde Orders - Esquema de Base de Datos
--  Versión: 2.0
--
--  Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier momento.
--  Se encargará de limpiar y reconfigurar el esquema completo de la aplicación.
-- ------------------------------------------------------------------------------------------------


-- ------------------------------------------------------------------------------------------------
--  1. LIMPIEZA Y REINICIO
--  Drop de todos los objetos en orden inverso a la creación para evitar errores de dependencia.
--  Se utiliza CASCADE para eliminar automáticamente objetos dependientes.
-- ------------------------------------------------------------------------------------------------

-- Drop de Políticas
DROP POLICY IF EXISTS "Allow public read access to app assets" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects CASCADE;
DROP POLICY IF EXISTS "Enable all actions for service_role" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.app_settings CASCADE;
DROP POLICY IF EXISTS "Allow insert for anonymous users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.orders CASCADE;
DROP POLICY IF EXISTS "Enable all actions for service_role" ON public.clients CASCADE;
DROP POLICY IF EXISTS "Enable read access for anon users" ON public.clients CASCADE;

-- Drop de Vistas
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;
DROP VIEW IF EXISTS public.orders_with_overdue_status CASCADE;
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;

-- Drop de Funciones
DROP FUNCTION IF EXISTS public.get_notification_counts() CASCADE;
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_clients_heatmap_data() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Drop de Tablas
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

-- Drop de Tipos
DROP TYPE IF EXISTS public.client_type_enum CASCADE;
DROP TYPE IF EXISTS public.client_status_enum CASCADE;
DROP TYPE IF EXISTS public.order_status_enum CASCADE;


-- ------------------------------------------------------------------------------------------------
--  2. CREACIÓN DE TIPOS (ENUMS)
--  Tipos personalizados para estandarizar valores en las tablas.
-- ------------------------------------------------------------------------------------------------

CREATE TYPE public.client_type_enum AS ENUM ('barberia', 'distribuidor', 'especial');
CREATE TYPE public.client_status_enum AS ENUM ('pending_onboarding', 'pending_agreement', 'active', 'archived');
CREATE TYPE public.order_status_enum AS ENUM ('pending', 'completed');


-- ------------------------------------------------------------------------------------------------
--  3. CREACIÓN DE TABLAS
--  Definición de todas las tablas de la aplicación.
-- ------------------------------------------------------------------------------------------------

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage real
);

-- Tabla de Items en Listas de Precios (Relación N-N)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric NOT NULL,
    volume_price numeric,
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type_enum NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Tabla de Promociones por Convenio (Relación N-N)
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Condiciones de Venta por Convenio (Relación N-N)
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    latitude real,
    longitude real,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status_enum NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token text DEFAULT gen_random_uuid(),
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    fiscal_status text
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric NOT NULL,
    status public.order_status_enum NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    due_date date GENERATED ALWAYS AS ((created_at + '30 days'::interval)) STORED
);

-- Tabla de Items de Pedido (Relación N-N)
CREATE TABLE public.order_items (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL
);

-- Tabla de Configuración de la Aplicación
CREATE TABLE public.app_settings (
    key text PRIMARY KEY,
    value text
);


-- ------------------------------------------------------------------------------------------------
--  4. CREACIÓN DE VISTAS
--  Vistas para simplificar consultas complejas y cálculos dinámicos.
-- ------------------------------------------------------------------------------------------------

-- Vista para obtener el conteo de promociones y condiciones por convenio
CREATE VIEW public.agreements_with_counts AS
SELECT
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.created_at,
    agr.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = agr.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascnd WHERE ascnd.agreement_id = agr.id) AS sales_condition_count
FROM public.agreements agr;

-- Vista para añadir el estado 'overdue' a los pedidos
CREATE VIEW public.orders_with_overdue_status AS
SELECT
    *,
    (status = 'pending' AND due_date < now()) AS overdue
FROM public.orders;

-- Vista para las estadísticas del dashboard
CREATE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders_with_overdue_status WHERE overdue = true) AS overdue_orders_count,
    (SELECT count(*) FROM public.clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) AS total_clients,
    (SELECT count(*) FROM public.price_lists) as total_pricelists,
    (SELECT count(*) FROM public.promotions) as total_promotions,
    (SELECT count(*) FROM public.sales_conditions) as total_sales_conditions;


-- ------------------------------------------------------------------------------------------------
--  5. CREACIÓN DE FUNCIONES
--  Funciones RPC para ser llamadas desde la aplicación.
-- ------------------------------------------------------------------------------------------------

-- Función para las notificaciones
CREATE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql STABLE
AS $$
  SELECT
    (SELECT count(*)::int FROM public.orders WHERE status = 'pending'),
    (SELECT count(*)::int FROM public.clients WHERE status = 'pending_agreement'),
    (SELECT count(*)::int FROM public.orders_with_overdue_status WHERE overdue = true)
$$;

-- Función para estadísticas de un cliente
CREATE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql STABLE
AS $$
  SELECT
    COALESCE(SUM(total_amount), 0) as total_spent,
    COALESCE(AVG(total_amount), 0) as average_order_value,
    count(*) as total_orders
  FROM public.orders
  WHERE client_id = p_client_id AND status = 'completed'
$$;

-- Función para datos del heatmap de clientes
CREATE FUNCTION public.get_clients_heatmap_data()
RETURNS TABLE(id uuid, name text, value numeric, risk integer)
LANGUAGE sql STABLE
AS $$
  SELECT
    c.id,
    c.contact_name AS name,
    COALESCE(sum(o.total_amount), 0) AS value,
    (SELECT count(*)::int FROM public.orders_with_overdue_status ov WHERE ov.client_id = c.id AND ov.overdue = true) AS risk
  FROM public.clients c
  LEFT JOIN public.orders o ON c.id = o.client_id AND o.status = 'completed'
  WHERE c.status = 'active'
  GROUP BY c.id, c.contact_name
  ORDER BY value DESC
$$;

-- Función para simular el incremento de ingresos (ejemplo)
CREATE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- En una app real, esto podría actualizar una tabla de agregados.
  -- Por simplicidad, esta función está vacía. La vista `dashboard_stats` calcula esto dinámicamente.
END;
$$;


-- ------------------------------------------------------------------------------------------------
--  6. HABILITACIÓN DE ROW LEVEL SECURITY (RLS)
--  Activa RLS en todas las tablas que lo necesitan.
-- ------------------------------------------------------------------------------------------------

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
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;


-- ------------------------------------------------------------------------------------------------
--  7. CREACIÓN DE POLÍTICAS DE RLS
--  Define las reglas de acceso para cada tabla.
-- ------------------------------------------------------------------------------------------------

-- Políticas para app_settings (configuración)
CREATE POLICY "Enable all actions for service_role" ON public.app_settings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Enable read access for all users" ON public.app_settings FOR SELECT USING (true);

-- Políticas para productos y afines (lectura pública, escritura para admin)
CREATE POLICY "Enable read access for all users" ON public.products FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.products FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Enable read access for all users" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.price_lists FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Enable read access for all users" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.price_list_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Enable read access for all users" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Enable read access for all users" ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Enable read access for all users" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.agreements FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Enable read access for all users" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.agreement_promotions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Enable read access for all users" ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Políticas para clientes (lectura para anon, todo para admin)
CREATE POLICY "Enable read access for anon users" ON public.clients FOR SELECT TO anon USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.clients FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Políticas para pedidos (INSERT para todos, lectura/modificación para admin)
CREATE POLICY "Allow insert for anonymous users" ON public.orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow insert for authenticated users" ON public.orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enable read access for all users" ON public.orders FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.orders FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Políticas para items de pedidos
CREATE POLICY "Enable read access for all users" ON public.order_items FOR SELECT USING (true);
CREATE POLICY "Enable all actions for service_role" ON public.order_items FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');


-- ------------------------------------------------------------------------------------------------
--  8. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
--  Define el acceso a los buckets de archivos.
-- ------------------------------------------------------------------------------------------------

-- Bucket para assets públicos (logo)
CREATE POLICY "Allow public read access to app assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Allow authenticated users to upload app assets" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'app_assets');
CREATE POLICY "Allow authenticated users to update app assets" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'app_assets');

-- Bucket para imágenes de productos
CREATE POLICY "Allow public read access to product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to upload product images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product_images');
CREATE POLICY "Allow authenticated users to update product images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'product_images');


-- ------------------------------------------------------------------------------------------------
--  9. INSERCIÓN DE DATOS INICIALES
--  Configuraciones por defecto para el primer arranque.
-- ------------------------------------------------------------------------------------------------

INSERT INTO public.app_settings (key, value) VALUES
    ('whatsapp_number', '5491112345678'),
    ('vat_percentage', '21')
ON CONFLICT (key) DO NOTHING;

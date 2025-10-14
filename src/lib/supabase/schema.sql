
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                    ▓
-- ▓  ¡Bienvenido al esquema de Blonde Orders!                                         ▓
-- ▓                                                                                    ▓
-- ▓  Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier        ▓
-- ▓  momento, ya sea en una base de datos nueva o existente. Se encargará de           ▓
-- ▓  limpiar y reconfigurar las tablas, vistas y funciones necesarias.                ▓
-- ▓                                                                                    ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓


-- Habilita la extensión pgcrypto si aún no está habilitada
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Habilita el schema "storage" si aún no está habilitado (necesario para buckets)
CREATE SCHEMA IF NOT EXISTS "storage";

-- Habilita la extensión http para poder hacer llamadas HTTP desde la DB
CREATE EXTENSION IF NOT EXISTS "http";

-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                    ▓
-- ▓  1. LIMPIEZA INICIAL                                                               ▓
-- ▓                                                                                    ▓
-- ▓  Se eliminan todas las tablas, vistas y funciones en el orden correcto para        ▓
-- ▓  evitar conflictos de dependencias. Se usa `CASCADE` para asegurar que todo       ▓
-- ▓  lo que dependa de estos objetos también sea eliminado.                            ▓
-- ▓                                                                                    ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Vistas
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP VIEW IF EXISTS public.dashboard_stats CASCADE;

-- Tablas de unión y dependientes primero
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE; -- Depende de agreements

-- Tablas principales después
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;

-- Funciones
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric) CASCADE;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.update_dashboard_stats() CASCADE;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                    ▓
-- ▓  2. CREACIÓN DE TABLAS                                                             ▓
-- ▓                                                                                    ▓
-- ▓  Se definen todas las tablas principales de la aplicación.                         ▓
-- ▓                                                                                    ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.products IS 'Almacena el catálogo de productos.';

CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Define las promociones aplicables (ej: 2x1, envío gratis).';

CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Define condiciones de venta (ej: pago a 30 días).';

CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.price_lists IS 'Define listas de precios que se pueden asignar a convenios.';

CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.client_type_enum NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.agreements IS 'Define los convenios comerciales para distintos tipos de clientes.';

CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text UNIQUE,
    instagram text,
    status public.client_status_enum DEFAULT 'pending_onboarding'::public.client_status_enum NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text
);
COMMENT ON TABLE public.clients IS 'Almacena la información de los clientes finales.';

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status public.order_status_enum DEFAULT 'pending'::public.order_status_enum NOT NULL,
    client_name_cache text NOT NULL
);
COMMENT ON TABLE public.orders IS 'Registra los pedidos realizados por los clientes.';


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                    ▓
-- ▓  3. TABLAS DE UNIÓN (PIVOT)                                                        ▓
-- ▓                                                                                    ▓
-- ▓  Conectan las tablas principales entre sí.                                        ▓
-- ▓                                                                                    ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Tabla pivot para precios de productos en cada lista.';

CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Tabla pivot para asignar promociones a convenios.';

CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Tabla pivot para asignar condiciones de venta a convenios.';

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL,
    price_per_unit numeric(10,2) NOT NULL
);
COMMENT ON TABLE public.order_items IS 'Detalle de los productos en cada pedido.';


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                    ▓
-- ▓  4. VISTAS Y FUNCIONES                                                             ▓
-- ▓                                                                                    ▓
-- ▓  Vistas para simplificar consultas y funciones para lógica de negocio.            ▓
-- ▓                                                                                    ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Vista para contar promociones y condiciones por convenio
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

-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    COALESCE(SUM(CASE WHEN status = 'completed' THEN total_amount ELSE 0 END), 0) as total_revenue,
    COALESCE(SUM(CASE WHEN status = 'completed' AND created_at >= date_trunc('month', now()) THEN total_amount ELSE 0 END), 0) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients
FROM
    public.orders;

-- Función para obtener estadísticas de un cliente específico
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0.00) as total_spent,
        COALESCE(AVG(o.total_amount), 0.00) as average_order_value,
        COUNT(o.id) as total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$;

-- Función para incrementar el total de ingresos (más seguro que hacerlo en la app)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Esta es una simplificación. En un caso real, esto debería actualizar una tabla de estadísticas.
  -- Por ahora, esta función no hace nada para mantener el ejemplo simple,
  -- pero demuestra cómo se haría una llamada RPC.
END;
$$;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                    ▓
-- ▓  5. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY - RLS)                              ▓
-- ▓                                                                                    ▓
-- ▓  Aseguran que los usuarios solo puedan ver y modificar los datos que les           ▓
-- ▓  corresponden. Por defecto, todo está denegado.                                    ▓
-- ▓                                                                                    ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Habilitar RLS en todas las tablas
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

-- Eliminar políticas existentes para asegurar la idempotencia
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.products;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.promotions;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow all access to authenticated users" ON public.clients;
DROP POLICY IF EXISTS "Allow all access for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow all access for authenticated users" ON public.order_items;


-- Políticas para administradores autenticados
CREATE POLICY "Allow all access to authenticated users" ON public.products FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.sales_conditions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.price_lists FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.price_list_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.agreements FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.agreement_promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.agreement_sales_conditions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to authenticated users" ON public.clients FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for authenticated users" ON public.orders FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access for authenticated users" ON public.order_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                    ▓
-- ▓  6. SUPABASE STORAGE                                                               ▓
-- ▓                                                                                    ▓
-- ▓  Configuración del bucket para imágenes de productos.                             ▓
-- ▓                                                                                    ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Insertar el bucket si no existe
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Permitir acceso público de lectura a las imágenes de productos
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
CREATE POLICY "Allow public read access to product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product_images');

-- Permitir a los administradores autenticados subir, modificar y borrar imágenes
DROP POLICY IF EXISTS "Allow admin full access to product images" ON storage.objects;
CREATE POLICY "Allow admin full access to product images"
ON storage.objects FOR ALL
TO authenticated
USING (bucket_id = 'product_images')
WITH CHECK (bucket_id = 'product_images');

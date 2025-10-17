
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                         ▓
-- ▓  ██████╗ ██╗      ██████╗ ███╗   ██╗██████╗ ███████╗    ██╗    ██████╗    ▓
-- ▓  ██╔══██╗██║     ██╔═══██╗████╗  ██║██╔══██╗██╔════╝    ██║    ██╔══██╗   ▓
-- ▓  ██████╔╝██║     ██║   ██║██╔██╗ ██║██║  ██║█████╗      ██║    ██████╔╝   ▓
-- ▓  ██╔═══╝ ██║     ██║   ██║██║╚██╗██║██║  ██║██╔══╝      ██║    ██╔═══╝    ▓
-- ▓  ██║     ███████╗╚██████╔╝██║ ╚████║██████╔╝███████╗    ██████╗██║        ▓
-- ▓  ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝    ╚═════╝╚═╝        ▓
-- ▓                                                                         ▓
-- ▓  Este script SQL es IDEMPOTENTE.                                        ▓
-- ▓  Puedes ejecutarlo de forma segura en cualquier momento. Se encargará    ▓
-- <b>se encuentra en el archivo:</b>src/lib/supabase/schema.sql
-- ▓  de limpiar y reconfigurar las tablas, vistas y funciones necesarias.  ▓
-- ▓                                                                         ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Habilitar la extensión pgcrypto si no está habilitada
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                         ▓
-- ▓                         SECCIÓN DE LIMPIEZA (DROP)                      ▓
-- ▓                                                                         ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Deshabilitar RLS temporalmente en las tablas para poder eliminarlas
ALTER TABLE IF EXISTS public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.clients DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.agreements DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.agreement_promotions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.promotions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.price_lists DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.price_list_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.sales_conditions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.agreement_sales_conditions DISABLE ROW LEVEL SECURITY;

-- Eliminar vistas y funciones en orden de dependencia
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_notification_counts();


-- Eliminar políticas de RLS de las tablas
DROP POLICY IF EXISTS "Enable read access for all users" ON public.products;
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.clients;
DROP POLICY IF EXISTS "Enable update for users based on id" ON public.clients;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.clients;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.promotions;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.price_lists;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.price_list_items;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.order_items;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.sales_conditions;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.agreement_sales_conditions;

-- Eliminar políticas de Storage
DROP POLICY IF EXISTS "Allow authenticated users to upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin full access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow anonymous read access to product images" ON storage.objects;


-- Eliminar tablas en orden inverso de dependencia (de muchos a uno)
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.general_stats;

-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                         ▓
-- ▓                      SECCIÓN DE CREACIÓN (CREATE)                       ▓
-- ▓                                                                         ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Items de Lista de Precios (tabla pivote)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name character varying NOT NULL UNIQUE,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
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

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    cuit character varying UNIQUE,
    contact_name character varying,
    contact_dni character varying,
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email character varying UNIQUE,
    instagram character varying,
    status public.client_status NOT NULL,
    onboarding_token uuid NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status text
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache character varying NOT NULL,
    notes text
);

-- Tabla de Items de Pedido
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10,2) NOT NULL
);

-- Tabla para estadísticas generales
CREATE TABLE public.general_stats (
    stat_key text PRIMARY KEY,
    stat_value numeric DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);

-- Insertar la estadística de ingresos totales si no existe
INSERT INTO public.general_stats (stat_key, stat_value)
VALUES ('total_revenue', 0)
ON CONFLICT (stat_key) DO NOTHING;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                         ▓
-- ▓               VISTAS (VIEWS) Y FUNCIONES (FUNCTIONS)                    ▓
-- ▓                                                                         ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓


-- Vista para obtener convenios con sus contadores
CREATE OR REPLACE VIEW public.agreements_with_counts AS
 SELECT a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    pl.name AS price_list_name,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions ascv WHERE ascv.agreement_id = a.id) AS sales_condition_count
   FROM (public.agreements a
     LEFT JOIN public.price_lists pl ON ((a.price_list_id = pl.id)));


-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
 SELECT
    (SELECT stat_value FROM public.general_stats WHERE stat_key = 'total_revenue') AS total_revenue,
    (SELECT coalesce(sum(total_amount), 0::numeric) FROM public.orders WHERE (status = 'completed'::public.order_status) AND (created_at > (now() - '30 days'::interval))) AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active'::public.client_status) AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending'::public.order_status AND created_at < (now() - '2 days'::interval)) AS overdue_orders_count;


-- Función para obtener estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
 RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0) AS total_spent,
        COALESCE(COUNT(id), 0) AS total_orders,
        COALESCE(AVG(total_amount), 0) AS average_order_value
    FROM
        public.orders
    WHERE
        client_id = p_client_id
        AND status = 'completed';
END;
$function$;

-- Función para obtener contadores para notificaciones
CREATE OR REPLACE FUNCTION public.get_notification_counts()
 RETURNS TABLE(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint)
 LANGUAGE sql
AS $function$
  SELECT
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS pending_orders_count,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '2 days'::interval)) AS overdue_orders_count;
$function$;

-- Función para incrementar los ingresos totales
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.general_stats
  SET stat_value = stat_value + amount_to_add,
      updated_at = now()
  WHERE stat_key = 'total_revenue';
END;
$$;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                         ▓
-- ▓        POLÍTICAS DE SEGURIDAD A NIVEL DE FILA (RLS) Y STORAGE           ▓
-- ▓                                                                         ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Habilitar RLS en todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;


-- Políticas de RLS para cada tabla
CREATE POLICY "Enable read access for all users" ON public.products FOR SELECT USING (true);
CREATE POLICY "Enable all operations for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable insert for authenticated users" ON public.clients FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable update for users based on id" ON public.clients FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Enable read access for all users" ON public.clients FOR SELECT USING (true);

CREATE POLICY "Enable all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Bucket para imágenes de productos
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for product_images bucket
CREATE POLICY "Allow authenticated users to upload"
  FOR INSERT
  ON storage.objects
  TO authenticated
  WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow admin full access to product images"
  FOR ALL
  ON storage.objects
  TO service_role
  WITH CHECK (bucket_id = 'product_images');

CREATE POLICY "Allow anonymous read access to product images"
    ON storage.objects FOR SELECT
    TO anon
    USING (bucket_id = 'product_images');

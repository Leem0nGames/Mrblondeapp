
-- Versión 2.0.0
-- Limpieza y Reseteo del Esquema de Blonde Orders
-- Este script es idempotente y puede ejecutarse de forma segura.

-- Desactiva las notificaciones para evitar ruido durante la ejecución
SET client_min_messages TO WARNING;

-- Elimina las tablas existentes en el orden correcto para evitar errores de dependencia
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;

-- Elimina vistas y funciones personalizadas
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.get_overdue_orders();
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);

-- Elimina tipos ENUM personalizados
DROP TYPE IF EXISTS public.client_status;
DROP TYPE IF EXISTS public.client_type;
DROP TYPE IF EXISTS public.order_status;


--
-- Creación de Tipos ENUM
--
CREATE TYPE public.client_status AS ENUM (
    'pending_onboarding',
    'pending_agreement',
    'active',
    'archived'
);

CREATE TYPE public.client_type AS ENUM (
    'barberia',
    'distribuidor',
    'especial'
);

CREATE TYPE public.order_status AS ENUM (
    'pending',
    'completed'
);

--
-- Creación de Tablas
--

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT products_name_key UNIQUE (name)
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_lists_name_key UNIQUE (name)
);
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;


-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    agreement_name character varying NOT NULL,
    client_type public.client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    CONSTRAINT agreements_name_key UNIQUE (agreement_name)
);
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cuit character varying(11) UNIQUE,
    contact_name character varying,
    contact_dni character varying(10),
    address text,
    delivery_window text,
    email character varying UNIQUE,
    instagram character varying,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token uuid DEFAULT gen_random_uuid() NOT NULL,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fiscal_status character varying,
    latitude double precision,
    longitude double precision
);
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status public.order_status DEFAULT 'pending'::public.order_status NOT NULL,
    client_name_cache character varying NOT NULL,
    notes text
);
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Tabla de Items de Pedido
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10,2) NOT NULL
);
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;


-- Tabla de Items de Listas de Precios
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL,
    volume_price numeric(10,2),
    PRIMARY KEY (price_list_id, product_id)
);
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;


-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;


-- Tabla de Mapeo Convenio-Promoción
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;

-- Tabla de Mapeo Convenio-Condición de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;

--
-- Creación de Vistas
--

-- Vista para contar promociones y condiciones de venta por convenio
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;
    

-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    -- Total histórico de ingresos de pedidos completados
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed'::public.order_status) AS total_revenue,
    
    -- Ingresos del mes actual
    (SELECT COALESCE(sum(total_amount), 0) FROM public.orders WHERE status = 'completed'::public.order_status AND date_trunc('month', created_at) = date_trunc('month', now())) AS month_revenue,
    
    -- Cantidad de clientes activos
    (SELECT count(*) FROM public.clients WHERE status = 'active'::public.client_status) AS active_clients;

--
-- Creación de Funciones
--

-- Función para obtener estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE plpgsql
AS $$
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
$$;


-- Función para obtener pedidos vencidos (ejemplo: pedidos pendientes por más de 15 días)
CREATE OR REPLACE FUNCTION public.get_overdue_orders()
RETURNS SETOF public.orders
LANGUAGE sql
AS $$
    SELECT *
    FROM public.orders
    WHERE status = 'pending' AND created_at < (now() - interval '15 days');
$$;

-- Función para incrementar el total de ingresos (usada en RPC)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Esta función es un placeholder. En una implementación real, 
  -- se actualizaría una tabla de agregados para mantener la consistencia.
  -- Por ahora, no hace nada ya que la vista dashboard_stats calcula esto dinámicamente.
END;
$$;

--
-- Políticas de RLS (Row Level Security)
--
-- Productos: Lectura pública
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can read products" ON public.products;
CREATE POLICY "Public can read products" ON public.products FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage products" ON public.products;
CREATE POLICY "Admins can manage products" ON public.products FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Listas de Precios: Solo admins
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage price lists" ON public.price_lists;
CREATE POLICY "Admins can manage price lists" ON public.price_lists FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Items de Listas de Precios: Lectura pública, escritura para admins
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can read price list items" ON public.price_list_items;
CREATE POLICY "Public can read price list items" ON public.price_list_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage price list items" ON public.price_list_items;
CREATE POLICY "Admins can manage price list items" ON public.price_list_items FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Convenios: Lectura pública, escritura para admins
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can read agreements" ON public.agreements;
CREATE POLICY "Public can read agreements" ON public.agreements FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage agreements" ON public.agreements;
CREATE POLICY "Admins can manage agreements" ON public.agreements FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Clientes: Solo admins pueden ver todos, pero los datos para onboarding son públicos
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage clients" ON public.clients;
CREATE POLICY "Admins can manage clients" ON public.clients FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Onboarding clients can be read" ON public.clients;
CREATE POLICY "Onboarding clients can be read" ON public.clients FOR SELECT
    USING (status = 'pending_onboarding'::public.client_status);
DROP POLICY IF EXISTS "Clients can update their own onboarding data" ON public.clients;
CREATE POLICY "Clients can update their own onboarding data" ON public.clients FOR UPDATE
    USING (onboarding_token IS NOT NULL)
    WITH CHECK (onboarding_token IS NOT NULL);

-- Pedidos: Admins pueden gestionar todo, el cliente puede crear (a través de server action)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage orders" ON public.orders;
CREATE POLICY "Admins can manage orders" ON public.orders FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Items de Pedido: Admins pueden gestionar todo, el cliente puede crear
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage order items" ON public.order_items;
CREATE POLICY "Admins can manage order items" ON public.order_items FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');
    
-- Promociones, Condiciones de Venta y sus tablas de mapeo
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage promotions" ON public.promotions;
CREATE POLICY "Admins can manage promotions" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage sales conditions" ON public.sales_conditions;
CREATE POLICY "Admins can manage sales conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can read assigned promotions" ON public.agreement_promotions;
CREATE POLICY "Public can read assigned promotions" ON public.agreement_promotions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage assigned promotions" ON public.agreement_promotions;
CREATE POLICY "Admins can manage assigned promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public can read assigned sales conditions" ON public.agreement_sales_conditions;
CREATE POLICY "Public can read assigned sales conditions" ON public.agreement_sales_conditions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage assigned sales conditions" ON public.agreement_sales_conditions;
CREATE POLICY "Admins can manage assigned sales conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


--
-- Políticas de Acceso a Storage (Bucket `product_images`)
--
-- Elimina políticas existentes para empezar de cero
DROP POLICY IF EXISTS "Public read access for product images" ON storage.objects;
DROP POLICY IF EXISTS "Admin full access for product images" ON storage.objects;

-- Los visitantes pueden ver las imágenes
CREATE POLICY "Public read access for product images"
    ON storage.objects FOR SELECT
    USING ( bucket_id = 'product_images' );

-- Los administradores (usuarios autenticados) pueden subir, editar y eliminar imágenes
CREATE POLICY "Admin full access for product images"
    ON storage.objects FOR ALL
    USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

-- Reactiva las notificaciones
SET client_min_messages TO NOTICE;

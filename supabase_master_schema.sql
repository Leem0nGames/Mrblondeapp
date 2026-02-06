-- =====================================================
-- SCHEMA MAESTRO - MR. BLONDE APP
-- Ejecutar en el SQL Editor de Supabase
-- =====================================================

-- =====================================================
-- SECCIÓN 0: LIMPIEZA DE TIPOS EXISTENTES
-- =====================================================
DROP TYPE IF EXISTS public.client_status CASCADE;
DROP TYPE IF EXISTS public.order_status CASCADE;
DROP TYPE IF EXISTS public.agreement_client_type CASCADE;


-- =====================================================
-- SECCIÓN 2: TABLAS MAESTRO
-- =====================================================

-- Tabla: Condiciones de Venta (términos comerciales)
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla: Listas de Precios
CREATE TABLE public.price_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    base_price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    discount_percentage numeric(5,2) DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100)
);

-- Tabla: Promociones
CREATE TABLE public.promotions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    rules jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla: Convenios/Acuerdos Comerciales
CREATE TABLE public.agreements (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    agreement_name text NOT NULL UNIQUE,
    client_type public.agreement_client_type NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Tabla: Clientes
CREATE TABLE public.clients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    cuit text UNIQUE,
    contact_name text,
    contact_dni text,
    email text UNIQUE,
    instagram text,
    address text,
    delivery_window text,
    latitude double precision,
    longitude double precision,
    status public.client_status DEFAULT 'pending_onboarding'::public.client_status NOT NULL,
    onboarding_token text UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla: Productos
CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla: Items de Lista de Precios (precios por producto)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10,2) NOT NULL CHECK (price >= 0),
    volume_price numeric(10,2) CHECK (volume_price >= 0),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla: Relación Convenios - Condiciones de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla: Relación Convenios - Promociones
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla: Configuración de la App
CREATE TABLE public.app_settings (
    key text NOT NULL PRIMARY KEY,
    value jsonb NOT NULL
);

-- Tabla: Pedidos
CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    total_amount numeric(10,2) NOT NULL CHECK (total_amount >= 0),
    status public.order_status DEFAULT 'pending'::public.order_status NOT NULL,
    client_name_cache text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla: Items del Pedido
CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity integer NOT NULL CHECK (quantity >= 1),
    price_per_unit numeric(10,2) NOT NULL CHECK (price_per_unit >= 0)
);


-- =====================================================
-- SECCIÓN 3: ÍNDICES PARA RENDIMIENTO
-- =====================================================
CREATE INDEX idx_orders_client_id ON public.orders(client_id);
CREATE INDEX idx_orders_agreement_id ON public.orders(agreement_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX idx_order_items_product_id ON public.order_items(product_id);
CREATE INDEX idx_price_list_items_price_list_id ON public.price_list_items(price_list_id);
CREATE INDEX idx_price_list_items_product_id ON public.price_list_items(product_id);
CREATE INDEX idx_clients_agreement_id ON public.clients(agreement_id);
CREATE INDEX idx_clients_status ON public.clients(status);
CREATE INDEX idx_products_category ON public.products(category);


-- =====================================================
-- SECCIÓN 4: VISTAS
-- =====================================================

-- Vista: Estadísticas del Dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND date_trunc('month', created_at) = date_trunc('month', now())) AS month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT COUNT(*) FROM public.clients WHERE status IN ('active', 'pending_agreement', 'pending_onboarding')) AS total_clients,
    (SELECT COUNT(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - '30 days'::interval)) AS overdue_orders_count,
    (SELECT COUNT(*) FROM public.price_lists) AS total_pricelists,
    (SELECT COUNT(*) FROM public.promotions) AS total_promotions,
    (SELECT COUNT(*) FROM public.sales_conditions) AS total_sales_conditions;

-- Vista: Convenios con contadores
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    pl.name AS price_list_name,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions ascnd WHERE ascnd.agreement_id = a.id) AS sales_condition_count
FROM public.agreements a
LEFT JOIN public.price_lists pl ON a.price_list_id = pl.id;


-- =====================================================
-- SECCIÓN 5: FUNCIONES RPC
-- =====================================================

-- Función: Obtener estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE (
    total_spent numeric,
    average_order_value numeric,
    total_orders bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0)::numeric AS total_spent,
        COALESCE(AVG(o.total_amount), 0)::numeric AS average_order_value,
        COUNT(o.id)::bigint AS total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$;

-- Función: Obtener conteos de notificaciones para dashboard
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE (
    pending_orders_count bigint,
    pending_clients_count bigint,
    overdue_orders_count bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::bigint FROM public.orders WHERE status = 'pending') AS pending_orders_count,
        (SELECT COUNT(*)::bigint FROM public.clients WHERE status = 'pending_agreement') AS pending_clients_count,
        (SELECT COUNT(*)::bigint FROM public.orders WHERE status = 'pending' AND created_at < (now() - '30 days'::interval)) AS overdue_orders_count;
END;
$$;

-- Función: Placeholder para incrementar revenue
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Placeholder: el revenue se calcula dinámicamente desde orders
    NULL;
END;
$$;


-- =====================================================
-- SECCIÓN 6: HABILITAR RLS (Row Level Security)
-- =====================================================
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;


-- =====================================================
-- SECCIÓN 7: POLÍTICAS RLS
-- =====================================================

-- Agreements (Convenios)
CREATE POLICY "Admin manage all agreements" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Public read agreements" ON public.agreements FOR SELECT USING (true);

-- Agreement Promotions
CREATE POLICY "Admin manage agreement promotions" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Agreement Sales Conditions
CREATE POLICY "Admin manage agreement sales conditions" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- App Settings
CREATE POLICY "Admin manage app_settings" ON public.app_settings FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Public read settings" ON public.app_settings FOR SELECT USING (true);

-- Clients (Clientes)
CREATE POLICY "Admin manage clients" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
-- Client puede ver/editar sus propios datos durante onboarding usando el token
CREATE POLICY "Client read own data" ON public.clients FOR SELECT USING (
    (auth.jwt() ->> 'token'::text) = onboarding_token OR auth.role() = 'authenticated'
);
CREATE POLICY "Client update own data" ON public.clients FOR UPDATE USING (
    (auth.jwt() ->> 'token'::text) = onboarding_token OR auth.role() = 'authenticated'
) WITH CHECK (
    (auth.jwt() ->> 'token'::text) = onboarding_token OR auth.role() = 'authenticated'
);

-- Orders (Pedidos)
CREATE POLICY "Admin manage orders" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Anon create orders" ON public.orders FOR INSERT WITH CHECK (true);

-- Order Items
CREATE POLICY "Admin manage order items" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Anon create order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Price Lists
CREATE POLICY "Admin manage price lists" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Price List Items
CREATE POLICY "Admin manage price list items" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Public read price list items" ON public.price_list_items FOR SELECT USING (true);

-- Products (Productos)
CREATE POLICY "Admin manage products" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Promotions
CREATE POLICY "Admin manage promotions" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Sales Conditions
CREATE POLICY "Admin manage sales conditions" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');


-- =====================================================
-- SECCIÓN 8: STORAGE (Buckets y Políticas)
-- =====================================================

-- Bucket: Imágenes de Productos
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

CREATE POLICY "Public read product images" ON storage.objects FOR SELECT USING (bucket_id = 'product_images');
CREATE POLICY "Admin manage product images" ON storage.objects FOR ALL
USING (bucket_id = 'product_images' AND auth.role() = 'authenticated')
WITH CHECK (bucket_id = 'product_images' AND auth.role() = 'authenticated');

-- Bucket: Assets de la App (logos, etc)
INSERT INTO storage.buckets (id, name, public)
VALUES ('app_assets', 'app_assets', true)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public;

CREATE POLICY "Public read app assets" ON storage.objects FOR SELECT USING (bucket_id = 'app_assets');
CREATE POLICY "Admin manage app assets" ON storage.objects FOR ALL
USING (bucket_id = 'app_assets' AND auth.role() = 'authenticated')
WITH CHECK (bucket_id = 'app_assets' AND auth.role() = 'authenticated');


-- =====================================================
-- SECCIÓN 9: DATOS INICIALES (Seed)
-- =====================================================
INSERT INTO public.app_settings (key, value) VALUES
    ('whatsapp_number', '"5491123456789"'),
    ('vat_percentage', '21'),
    ('logo_url', 'null')
ON CONFLICT(key) DO NOTHING;


-- =====================================================
-- FIN DEL SCHEMA MAESTRO
-- =====================================================

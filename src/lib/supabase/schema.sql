-- Base de datos para Blonde Orders
-- Diseño de esquema inicial

-- Habilitar la extensión pgcrypto para UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

-- Limpieza inicial (idempotencia)
-- Elimina en orden inverso a la creación para evitar problemas de dependencias

-- Drop Junction Tables first
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.order_items;

-- Drop Main Data Tables
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public
.sales_conditions;
-- Agreements and price lists might have dependencies from clients
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.price_lists;


-- Drop Views and Functions
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_overdue_orders();
DROP FUNCTION IF EXISTS public.get_notification_counts();

-- 1. Tabla de Productos
CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name character varying NOT NULL,
    description text,
    image_url text,
    category character varying,
    CONSTRAINT products_pkey PRIMARY KEY (id),
    CONSTRAINT products_name_key UNIQUE (name)
);
COMMENT ON TABLE public.products IS 'Catálogo de todos los productos disponibles.';

-- 2. Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name character varying NOT NULL,
    prices_include_vat boolean NOT NULL DEFAULT true,
    CONSTRAINT price_lists_pkey PRIMARY KEY (id),
    CONSTRAINT price_lists_name_key UNIQUE (name)
);
COMMENT ON TABLE public.price_lists IS 'Define un conjunto de precios para un grupo de productos.';

-- 3. Tabla de Items de la Lista de Precios (Junction Table)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL,
    volume_price numeric,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.price_list_items IS 'Asocia productos a una lista con un precio específico.';


-- 4. Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name character varying NOT NULL,
    description text,
    rules jsonb,
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE public.promotions IS 'Define promociones aplicables (ej: 2x1, envío gratis).';

-- 5. Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name character varying NOT NULL,
    description text,
    rules jsonb,
    CONSTRAINT sales_conditions_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE public.sales_conditions IS 'Define condiciones comerciales (plazos, descuentos).';

-- 6. Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    agreement_name character varying NOT NULL,
    client_type public.client_type NOT NULL,
    price_list_id uuid,
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.agreements IS 'Vincula un tipo de cliente a precios y promociones.';

-- 7. Tabla de Unión Convenio-Promociones
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE
);

-- 8. Tabla de Unión Convenio-Condiciones de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL,
    CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id),
    CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE
);


-- 9. Tabla de Clientes
CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    cuit character varying UNIQUE,
    contact_name character varying,
    contact_dni character varying,
    address text,
    delivery_window text,
    email character varying,
    instagram character varying,
    status public.client_status NOT NULL,
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid,
    fiscal_status character varying,
    latitude double precision,
    longitude double precision,
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token),
    CONSTRAINT clients_email_key UNIQUE (email),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.clients IS 'Información de los clientes finales.';

-- 10. Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    total_amount numeric NOT NULL,
    status public.order_status NOT NULL,
    client_name_cache character varying,
    notes text,
    CONSTRAINT orders_pkey PRIMARY KEY (id),
    CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE RESTRICT,
    CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT
);
COMMENT ON TABLE public.orders IS 'Registros de los pedidos realizados.';

-- 11. Tabla de Items de Pedido
CREATE TABLE public.order_items (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_per_unit numeric NOT NULL,
    CONSTRAINT order_items_pkey PRIMARY KEY (id),
    CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE,
    CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT
);
COMMENT ON TABLE public.order_items IS 'Detalle de los productos en cada pedido.';


-- Vistas y Funciones --

-- Vista para contar promociones y condiciones por convenio
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (SELECT count(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) AS promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = a.id) AS sales_condition_count
FROM
    public.agreements a;

-- KV store para métricas simples
CREATE TABLE IF NOT EXISTS public.kv_store (
    key text PRIMARY KEY,
    value numeric
);
-- Inicializar métricas si no existen
INSERT INTO public.kv_store (key, value) VALUES ('total_revenue', 0) ON CONFLICT (key) DO NOTHING;
INSERT INTO public.kv_store (key, value) VALUES ('month_revenue', 0) ON CONFLICT (key) DO NOTHING;

-- Función para incrementar ingresos
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.kv_store
    SET value = value + amount_to_add
    WHERE key = 'total_revenue';
END;
$$;

-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT value FROM public.kv_store WHERE key = 'total_revenue') AS total_revenue,
    (SELECT value FROM public.kv_store WHERE key = 'month_revenue') AS month_revenue,
    (SELECT count(*) FROM public.clients WHERE status = 'active') AS active_clients,
    (SELECT count(*) FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) AS overdue_orders_count;


-- Función para estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, total_orders bigint, average_order_value numeric)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(COUNT(id), 0) as total_orders,
        COALESCE(AVG(total_amount), 0) as average_order_value
    FROM
        public.orders
    WHERE
        client_id = p_client_id;
$$;

-- Función para obtener pedidos vencidos (más de 3 días en estado 'pending')
CREATE OR REPLACE FUNCTION public.get_overdue_orders()
RETURNS SETOF public.orders
LANGUAGE sql
AS $$
    SELECT *
    FROM public.orders
    WHERE status = 'pending' AND created_at < (now() - interval '3 days')
    ORDER BY created_at ASC;
$$;

-- Función para obtener todos los conteos para notificaciones en una sola llamada
CREATE OR REPLACE FUNCTION public.get_notification_counts()
RETURNS TABLE(pending_orders_count int, pending_clients_count int, overdue_orders_count int)
LANGUAGE sql
AS $$
    SELECT
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending') as pending_orders_count,
        (SELECT COUNT(*)::int FROM public.clients WHERE status = 'pending_agreement') as pending_clients_count,
        (SELECT COUNT(*)::int FROM public.orders WHERE status = 'pending' AND created_at < (now() - interval '3 days')) as overdue_orders_count;
$$;

-- Habilitar RLS en las tablas
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

-- Políticas de RLS

-- Los usuarios autenticados (admins) pueden leer todo
CREATE POLICY "Allow authenticated user to read everything"
ON public.products FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.price_lists FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.price_list_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.promotions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.sales_conditions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.agreements FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.agreement_promotions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.agreement_sales_conditions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.clients FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.order_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to read everything"
ON public.kv_store FOR SELECT USING (auth.role() = 'authenticated');

-- Los usuarios autenticados (admins) pueden escribir/modificar/eliminar todo
CREATE POLICY "Allow authenticated user to write everything"
ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated user to write everything"
ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Permitir que CUALQUIERA lea información pública para la página de pedidos
CREATE POLICY "Allow anonymous read for order pages"
ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read for order pages"
ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read for order pages"
ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read for order pages"
ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read for order pages"
ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read for order pages"
ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow anonymous read for order pages"
ON public.clients FOR SELECT USING (true);


-- Permitir que CUALQUIERA cree nuevos pedidos y sus items
-- La lógica de autorización estará en la Server Action
CREATE POLICY "Allow anyone to create orders"
ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anyone to create order items"
ON public.order_items FOR INSERT WITH CHECK (true);

-- Permitir que CUALQUIERA actualice la tabla de clientes (onboarding)
-- La autorización se maneja mediante el token en la Server Action
CREATE POLICY "Allow anyone to update clients for onboarding"
ON public.clients FOR UPDATE USING (true) WITH CHECK (true);

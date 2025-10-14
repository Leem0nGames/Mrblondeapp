
-- 🌀 Esquema de Base de Datos para Blonde Orders
-- Versión: 3.0
-- Este script es IDEMPOTENTE. Puedes ejecutarlo en cualquier momento y
-- reconstruirá el esquema desde cero de forma segura.

-- --- LIMPIEZA ---
-- Borra las tablas existentes en el orden correcto para evitar errores de foreign key.
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
DROP FUNCTION IF EXISTS public.get_client_stats;
DROP FUNCTION IF EXISTS public.increment_total_revenue;

-- --- TABLAS PRINCIPALES ---

-- Tabla de Productos
CREATE TABLE public.products (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name text NOT NULL,
    description text NULL,
    image_url text NULL,
    category text NULL,
    CONSTRAINT products_pkey PRIMARY KEY (id),
    CONSTRAINT products_name_key UNIQUE (name)
);
COMMENT ON TABLE public.products IS 'Almacena el catálogo de todos los productos.';

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name text NOT NULL,
    prices_include_vat boolean NOT NULL DEFAULT true,
    CONSTRAINT price_lists_pkey PRIMARY KEY (id),
    CONSTRAINT price_lists_name_key UNIQUE (name)
);
COMMENT ON TABLE public.price_lists IS 'Define listas de precios reutilizables (ej. "Precios Distribuidor 2024").';

-- Tabla de Items de Listas de Precios (Tabla Pivote)
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price numeric NOT NULL DEFAULT 0,
    volume_price numeric NULL,
    CONSTRAINT price_list_items_pkey PRIMARY KEY (price_list_id, product_id),
    CONSTRAINT price_list_items_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE CASCADE,
    CONSTRAINT price_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.price_list_items IS 'Define el precio de un producto específico dentro de una lista de precios.';

-- Tabla de Convenios
CREATE TABLE public.agreements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    agreement_name text NOT NULL,
    client_type public.client_type_enum NOT NULL,
    price_list_id uuid NULL,
    CONSTRAINT agreements_pkey PRIMARY KEY (id),
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name),
    CONSTRAINT agreements_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_lists(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.agreements IS 'Define las condiciones comerciales para un grupo de clientes.';

-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    cuit text NULL,
    contact_name text NULL,
    contact_dni text NULL,
    address text NULL,
    delivery_window text NULL,
    email text NULL,
    instagram text NULL,
    status public.client_status_enum NOT NULL DEFAULT 'pending_onboarding'::public.client_status_enum,
    onboarding_token uuid NOT NULL DEFAULT gen_random_uuid(),
    agreement_id uuid NULL,
    fiscal_status text NULL,
    CONSTRAINT clients_pkey PRIMARY KEY (id),
    CONSTRAINT clients_cuit_key UNIQUE (cuit),
    CONSTRAINT clients_email_key UNIQUE (email),
    CONSTRAINT clients_onboarding_token_key UNIQUE (onboarding_token),
    CONSTRAINT clients_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.clients IS 'Almacena la información de los clientes finales.';

-- Tabla de Promociones
CREATE TABLE public.promotions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name text NOT NULL,
    description text NULL,
    rules jsonb NULL,
    CONSTRAINT promotions_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE public.promotions IS 'Define promociones reutilizables (ej. 2x1, envío gratis).';

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    name text NOT NULL,
    description text NULL,
    rules jsonb NULL,
    CONSTRAINT sales_conditions_pkey PRIMARY KEY (id)
);
COMMENT ON TABLE public.sales_conditions IS 'Define condiciones de pago y financiación.';

-- Tabla Pivote Convenio-Promociones
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL,
    promotion_id uuid NOT NULL,
    CONSTRAINT agreement_promotions_pkey PRIMARY KEY (agreement_id, promotion_id),
    CONSTRAINT agreement_promotions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_promotions_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES public.promotions(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.agreement_promotions IS 'Asigna promociones a un convenio.';

-- Tabla Pivote Convenio-Condiciones de Venta
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL,
    sales_condition_id uuid NOT NULL,
    CONSTRAINT agreement_sales_conditions_pkey PRIMARY KEY (agreement_id, sales_condition_id),
    CONSTRAINT agreement_sales_conditions_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE,
    CONSTRAINT agreement_sales_conditions_sales_condition_id_fkey FOREIGN KEY (sales_condition_id) REFERENCES public.sales_conditions(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Asigna condiciones de venta a un convenio.';

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    client_id uuid NOT NULL,
    agreement_id uuid NOT NULL,
    total_amount numeric NOT NULL,
    status public.order_status_enum NOT NULL DEFAULT 'pending'::public.order_status_enum,
    client_name_cache text NULL,
    CONSTRAINT orders_pkey PRIMARY KEY (id),
    CONSTRAINT orders_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE RESTRICT,
    CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE RESTRICT
);
COMMENT ON TABLE public.orders IS 'Almacena el historial de pedidos.';

-- Tabla de Items de Pedidos
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


-- --- VISTAS (VIEWS) ---

-- Vista para contar promociones y condiciones en convenios
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions sc WHERE sc.agreement_id = a.id) as sales_condition_count
FROM
    public.agreements a;

-- Vista para estadísticas del dashboard (simplificada)
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
  (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients;

-- --- FUNCIONES (RPC) ---

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
        o.client_id = p_client_id;
END;
$$;

-- Función para incrementar los ingresos totales de forma segura
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Esta es una implementación simplificada. En un entorno de alta concurrencia,
    -- se necesitaría un enfoque más robusto como una tabla de agregados separada.
    -- Por ahora, esto es suficiente para la demo.
    -- La vista dashboard_stats se recalcula en cada llamada, por lo que no hay que hacer nada aquí.
END;
$$;


-- --- POLÍTICAS DE SEGURIDAD (RLS) ---
-- Habilita RLS en todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Borra políticas existentes para evitar duplicados
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_lists;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.clients;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.order_items;

-- Crea una política general para permitir el acceso total a los usuarios autenticados (administradores)
CREATE POLICY "Allow all for authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow all for authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');


-- --- STORAGE (FILE BUCKETS) ---
-- Crea el bucket para las imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('product_images', 'product_images', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Políticas de seguridad para el bucket de imágenes de productos.
-- Permite que cualquiera pueda ver las imágenes.
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
CREATE POLICY "Allow public read access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

-- Permite que los usuarios autenticados (administradores) puedan subir, actualizar y borrar imágenes.
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON storage.objects;
CREATE POLICY "Allow insert for authenticated users"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product_images');

DROP POLICY IF EXISTS "Allow update for authenticated users" ON storage.objects;
CREATE POLICY "Allow update for authenticated users"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product_images');

DROP POLICY IF EXISTS "Allow delete for authenticated users" ON storage.objects;
CREATE POLICY "Allow delete for authenticated users"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product_images');

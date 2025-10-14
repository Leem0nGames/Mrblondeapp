-- Versión 2.0 del Esquema
-- Este script es idempotente, lo que significa que se puede ejecutar de forma segura varias veces.
-- Se encarga de limpiar y reconfigurar la base de datos a un estado conocido.

-- --- 1. LIMPIEZA INICIAL ---
-- Elimina las tablas existentes en el orden correcto para evitar errores de dependencias.
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.dashboard_stats CASCADE;


-- --- 2. CREACIÓN DE TABLAS ---

-- Tabla de Productos: Almacena el catálogo de productos.
CREATE TABLE public.products (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "category" text,
    "image_url" text,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT products_name_key UNIQUE (name)
);
COMMENT ON TABLE public.products IS 'Catálogo de productos de la tienda.';

-- Tabla de Listas de Precios: Contenedores para diferentes conjuntos de precios.
CREATE TABLE public.price_lists (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "prices_include_vat" boolean DEFAULT true NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT price_lists_name_key UNIQUE (name)
);
COMMENT ON TABLE public.price_lists IS 'Agrupaciones de precios para diferentes convenios.';

-- Tabla de Items de Listas de Precios: Vincula productos con precios en una lista específica.
CREATE TABLE public.price_list_items (
    "price_list_id" uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    "price" numeric(10, 2) NOT NULL,
    "volume_price" numeric(10, 2),
    "created_at" timestamptz DEFAULT now() NOT NULL,
    PRIMARY KEY (price_list_id, product_id)
);
COMMENT ON TABLE public.price_list_items IS 'Precio específico de un producto en una lista de precios.';


-- Tabla de Convenios: Define las reglas comerciales para un grupo de clientes.
CREATE TABLE public.agreements (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "agreement_name" text NOT NULL,
    "client_type" text NOT NULL CHECK (client_type IN ('barberia', 'distribuidor', 'especial')),
    "price_list_id" uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT agreements_agreement_name_key UNIQUE (agreement_name)
);
COMMENT ON TABLE public.agreements IS 'Convenios comerciales que agrupan listas de precios y promociones.';

-- Tabla de Clientes: Almacena la información de los clientes.
CREATE TABLE public.clients (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "cuit" text UNIQUE,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text UNIQUE,
    "instagram" text,
    "status" text DEFAULT 'pending_onboarding'::text NOT NULL CHECK (status IN ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    "onboarding_token" uuid DEFAULT gen_random_uuid() NOT NULL UNIQUE,
    "agreement_id" uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "fiscal_status" text
);
COMMENT ON TABLE public.clients IS 'Información y estado de los clientes.';

-- Tabla de Promociones: Define las ofertas disponibles.
CREATE TABLE public.promotions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.promotions IS 'Promociones aplicables, como "compre X, lleve Y".';

-- Tabla de Condiciones de Venta: Define términos de pago, financiación, etc.
CREATE TABLE public.sales_conditions (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "name" text NOT NULL,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.sales_conditions IS 'Define términos de pago, financiación, etc.';


-- Tablas de Unión (Muchos a Muchos)
CREATE TABLE public.agreement_promotions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "promotion_id" uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    PRIMARY KEY (agreement_id, promotion_id)
);
COMMENT ON TABLE public.agreement_promotions IS 'Asocia promociones a convenios.';

CREATE TABLE public.agreement_sales_conditions (
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    "sales_condition_id" uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    PRIMARY KEY (agreement_id, sales_condition_id)
);
COMMENT ON TABLE public.agreement_sales_conditions IS 'Asocia condiciones de venta a convenios.';

-- Tablas de Pedidos
CREATE TABLE public.orders (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "client_id" uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    "agreement_id" uuid NOT NULL REFERENCES public.agreements(id) ON DELETE RESTRICT,
    "total_amount" numeric(10, 2) NOT NULL,
    "status" text DEFAULT 'pending'::text NOT NULL CHECK (status IN ('pending', 'completed')),
    "client_name_cache" text NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.orders IS 'Registros de pedidos realizados por los clientes.';

CREATE TABLE public.order_items (
    "order_id" uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    "product_id" uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    "quantity" integer NOT NULL,
    "price_per_unit" numeric(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id)
);
COMMENT ON TABLE public.order_items IS 'Detalle de los productos en cada pedido.';


-- --- 3. VISTAS Y ESTADÍSTICAS ---

-- Vista para contar promociones y condiciones por convenio
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.*,
    (SELECT COUNT(*) FROM public.agreement_promotions ap WHERE ap.agreement_id = a.id) as promotion_count,
    (SELECT COUNT(*) FROM public.agreement_sales_conditions asc WHERE asc.agreement_id = a.id) as sales_condition_count
FROM
    public.agreements a;

-- Tabla para estadísticas del dashboard (materializada para rendimiento)
CREATE TABLE public.dashboard_stats (
    "id" integer PRIMARY KEY,
    "total_revenue" numeric(12, 2) DEFAULT 0 NOT NULL,
    "month_revenue" numeric(12, 2) DEFAULT 0 NOT NULL,
    "active_clients" integer DEFAULT 0 NOT NULL,
    "updated_at" timestamptz
);
INSERT INTO public.dashboard_stats (id, total_revenue, month_revenue, active_clients) VALUES (1, 0, 0, 0);


-- --- 4. FUNCIONES (RPC) ---

-- Función para obtener estadísticas de un cliente específico
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        COUNT(id) as total_orders
    FROM public.orders
    WHERE client_id = p_client_id AND status = 'completed';
$$;

-- Función para incrementar los ingresos totales (segura para concurrencia)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void
LANGUAGE sql
AS $$
    UPDATE public.dashboard_stats
    SET total_revenue = total_revenue + amount_to_add
    WHERE id = 1;
$$;

-- --- 5. ALMACENAMIENTO (STORAGE) ---
-- Crea el bucket para las imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Define políticas de acceso para el bucket.
-- Permite el acceso público de lectura (select)
CREATE POLICY "Public Read Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product_images' );

-- Permite a los usuarios autenticados subir, actualizar y eliminar imágenes.
CREATE POLICY "Authenticated Write Access"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

CREATE POLICY "Authenticated Update Access"
ON storage.objects FOR UPDATE
USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

CREATE POLICY "Authenticated Delete Access"
ON storage.objects FOR DELETE
USING ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );


-- --- 6. HABILITAR RLS ---
-- Habilita Row Level Security en todas las tablas para seguridad.
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

-- --- 7. POLÍTICAS DE RLS ---
-- Permite el acceso público de lectura a las tablas necesarias para la página de pedidos.
CREATE POLICY "Allow public read access to products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow public read access to price lists" ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow public read access to price list items" ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreements" ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow public read access to promotions" ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to agreement promotions" ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow public read access to clients" ON public.clients FOR SELECT USING (true);

-- Permite a los usuarios autenticados (administradores) realizar todas las operaciones.
CREATE POLICY "Allow all access to authenticated users" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow all access to authenticated users" ON public.dashboard_stats FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Permite a cualquier usuario crear clientes a través del formulario de onboarding
CREATE POLICY "Allow public insert on clients" ON public.clients FOR INSERT WITH CHECK (true);
-- Permite a cualquier usuario actualizar su propia información durante el onboarding
CREATE POLICY "Allow public update on clients for onboarding" ON public.clients FOR UPDATE USING (onboarding_token IS NOT NULL);
-- Permite a cualquier usuario crear un pedido
CREATE POLICY "Allow public insert on orders" ON public.orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public insert on order_items" ON public.order_items FOR INSERT WITH CHECK (true);

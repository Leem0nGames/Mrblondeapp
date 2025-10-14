-- Este script es idempotente. Puedes ejecutarlo en cualquier momento y se encargará
-- de limpiar y reconfigurar las tablas y vistas.

-- --- EXTENSIONS ---
-- Habilita la extensión para usar UUIDs
create extension if not exists "uuid-ossp" with schema extensions;

-- --- CLEANUP ---
-- Deshabilita temporalmente los triggers para evitar errores de dependencias al borrar.
-- Nota: Esto es un enfoque simple. En producción compleja, el orden de borrado es clave.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' DISABLE TRIGGER ALL;';
    END LOOP;
END $$;

-- Borra vistas y tablas existentes. "CASCADE" se encarga de las dependencias.
DROP VIEW IF EXISTS public.agreements_with_counts CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.price_list_items CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.agreement_promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.agreement_sales_conditions CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.dashboard_stats CASCADE;

-- Vuelve a habilitar los triggers (aunque las tablas ya no existen, es buena práctica si el script cambiara)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' ENABLE TRIGGER ALL;';
    END LOOP;
END $$;


-- --- TABLE CREATION ---

-- Tabla de Productos: Catálogo central de productos.
CREATE TABLE public.products (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Listas de Precios: Contiene diferentes listas (ej. barbería, distribuidor).
CREATE TABLE public.price_lists (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    name character varying NOT NULL UNIQUE,
    prices_include_vat boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Items de Lista de Precios: Define el precio de un producto en una lista específica.
CREATE TABLE public.price_list_items (
    price_list_id uuid NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price numeric(10, 2) NOT NULL,
    volume_price numeric(10, 2),
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones: Define las promociones disponibles.
CREATE TABLE public.promotions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta: Define las condiciones comerciales (pagos, etc.).
CREATE TABLE public.sales_conditions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    rules jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Convenios: Define un acuerdo comercial específico.
CREATE TABLE public.agreements (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    agreement_name character varying NOT NULL UNIQUE,
    client_type character varying NOT NULL,
    price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Asignación de Promociones a Convenios.
CREATE TABLE public.agreement_promotions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Asignación de Condiciones de Venta a Convenios.
CREATE TABLE public.agreement_sales_conditions (
    agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id uuid NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de Clientes: Almacena la información de los clientes.
CREATE TABLE public.clients (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    cuit character varying UNIQUE,
    contact_name character varying,
    contact_dni character varying,
    address text,
    delivery_window text,
    email character varying UNIQUE,
    instagram character varying,
    fiscal_status character varying,
    status character varying DEFAULT 'pending_onboarding'::character varying NOT NULL,
    onboarding_token uuid DEFAULT extensions.uuid_generate_v4() NOT NULL UNIQUE,
    agreement_id uuid REFERENCES public.agreements(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Pedidos: Registra cada pedido realizado.
CREATE TABLE public.orders (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES public.clients(id),
    agreement_id uuid NOT NULL REFERENCES public.agreements(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_amount numeric(10, 2) NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    client_name_cache character varying NOT NULL
);

-- Tabla de Items de Pedido: Detalle de los productos en cada pedido.
CREATE TABLE public.order_items (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL REFERENCES public.products(id),
    quantity integer NOT NULL,
    price_per_unit numeric(10, 2) NOT NULL
);

-- --- VIEWS ---

-- Vista para obtener convenios con conteo de promociones y condiciones.
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


-- --- FUNCTIONS (RPC) ---

CREATE TABLE public.dashboard_stats (
    id INT PRIMARY KEY,
    total_revenue NUMERIC(15, 2) DEFAULT 0,
    month_revenue NUMERIC(15, 2) DEFAULT 0,
    active_clients INT DEFAULT 0
);
-- Ensure there is always a row to update
INSERT INTO public.dashboard_stats (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add numeric)
RETURNS void AS $$
BEGIN
    UPDATE public.dashboard_stats
    SET total_revenue = total_revenue + amount_to_add
    WHERE id = 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_client_stats(p_client_id uuid)
RETURNS TABLE (
    total_spent numeric,
    average_order_value numeric,
    total_orders bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) as total_spent,
        COALESCE(AVG(o.total_amount), 0) as average_order_value,
        COUNT(o.id) as total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id;
END;
$$ LANGUAGE plpgsql;


-- --- STORAGE ---
-- Crea el bucket para las imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Define las políticas de acceso para el bucket.
-- Permite la lectura pública de imágenes.
CREATE POLICY "Public read access for product images" ON storage.objects
FOR SELECT USING ( bucket_id = 'product_images' );

-- Permite a los usuarios autenticados subir imágenes.
CREATE POLICY "Authenticated users can upload product images" ON storage.objects
FOR INSERT WITH CHECK ( bucket_id = 'product_images' AND auth.role() = 'authenticated' );

-- Permite a los usuarios autenticados actualizar sus propias imágenes.
CREATE POLICY "Authenticated users can update their own images" ON storage.objects
FOR UPDATE USING ( auth.uid() = owner ) WITH CHECK ( bucket_id = 'product_images' );


-- --- ROW LEVEL SECURITY (RLS) ---
-- Habilita RLS en todas las tablas y define políticas.
-- La política es simple: cualquier usuario autenticado puede hacer todo.
-- Esto es seguro en este contexto porque solo los administradores tienen acceso.

-- Products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on products" ON public.products FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Price Lists
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on price_lists" ON public.price_lists FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Price List Items
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on price_list_items" ON public.price_list_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Promotions
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on promotions" ON public.promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Sales Conditions
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on sales_conditions" ON public.sales_conditions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Agreements
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on agreements" ON public.agreements FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Agreement Promotions
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on agreement_promotions" ON public.agreement_promotions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Agreement Sales Conditions
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on agreement_sales_conditions" ON public.agreement_sales_conditions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Clients
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on clients" ON public.clients FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on orders" ON public.orders FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Order Items
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on order_items" ON public.order_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Dashboard Stats
ALTER TABLE public.dashboard_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated users on dashboard_stats" ON public.dashboard_stats FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- --- END OF SCRIPT ---

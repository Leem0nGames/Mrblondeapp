
-- --------------------------------------------------------------------------------
-- 1. Limpieza Inicial: Elimina todo para empezar de cero de forma segura.
-- --------------------------------------------------------------------------------

-- Deshabilita la seguridad a nivel de fila temporalmente para permitir borrados.
ALTER TABLE IF EXISTS public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.price_lists DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.price_list_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.promotions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.sales_conditions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.agreements DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.agreement_promotions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.agreement_sales_conditions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.clients DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.dashboard_stats DISABLE ROW LEVEL SECURITY;

-- Borra vistas y funciones existentes para evitar conflictos.
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP FUNCTION IF EXISTS public.get_client_stats;
DROP FUNCTION IF EXISTS public.increment_total_revenue;

-- Borra tablas en el orden correcto de dependencia (de "muchos" a "uno").
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.dashboard_stats;

-- Borra el bucket de imágenes si existe.
-- NOTA: Esto eliminará todas las imágenes de productos subidas.
-- Comenta esta línea si prefieres conservarlas entre reinicios de esquema.
-- SELECT storage.empty_bucket('product_images');
-- SELECT storage.delete_bucket('product_images');


-- --------------------------------------------------------------------------------
-- 2. Creación de Tablas
-- --------------------------------------------------------------------------------

-- Tabla de Productos: Catálogo central de todos los productos.
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    category TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de Listas de Precios: Contenedores para diferentes conjuntos de precios.
CREATE TABLE public.price_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prices_include_vat BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de Items de Lista de Precios: Define el precio de un producto en una lista específica.
CREATE TABLE public.price_list_items (
    price_list_id UUID NOT NULL REFERENCES public.price_lists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    price REAL NOT NULL,
    volume_price REAL,
    PRIMARY KEY (price_list_id, product_id)
);

-- Tabla de Promociones: Reglas de negocio como "compre X, lleve Y".
CREATE TABLE public.promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de Condiciones de Venta: Reglas financieras como plazos o descuentos.
CREATE TABLE public.sales_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    rules JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de Convenios: Vincula un tipo de cliente con una lista de precios y promociones.
CREATE TABLE public.agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agreement_name TEXT NOT NULL UNIQUE,
    client_type TEXT NOT NULL,
    price_list_id UUID REFERENCES public.price_lists(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de Unión: Asigna promociones a un convenio.
CREATE TABLE public.agreement_promotions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Unión: Asigna condiciones de venta a un convenio.
CREATE TABLE public.agreement_sales_conditions (
    agreement_id UUID NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
    sales_condition_id UUID NOT NULL REFERENCES public.sales_conditions(id) ON DELETE CASCADE,
    PRIMARY KEY (agreement_id, sales_condition_id)
);

-- Tabla de Clientes: Información de contacto y de negocio de cada cliente.
CREATE TABLE public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuit TEXT UNIQUE,
    contact_name TEXT,
    contact_dni TEXT,
    address TEXT,
    delivery_window TEXT,
    email TEXT UNIQUE,
    instagram TEXT,
    status TEXT NOT NULL DEFAULT 'pending_onboarding',
    onboarding_token UUID NOT NULL DEFAULT gen_random_uuid(),
    agreement_id UUID REFERENCES public.agreements(id) ON DELETE SET NULL,
    fiscal_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de Pedidos: Registra cada pedido realizado.
CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id),
    agreement_id UUID NOT NULL REFERENCES public.agreements(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_amount REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    client_name_cache TEXT
);

-- Tabla de Items de Pedido: Detalle de los productos en cada pedido.
CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    quantity INTEGER NOT NULL,
    price_per_unit REAL NOT NULL
);

-- Tabla de Estadísticas del Dashboard: Datos pre-agregados para un rendimiento rápido.
CREATE TABLE public.dashboard_stats (
    id INT PRIMARY KEY DEFAULT 1,
    total_revenue REAL DEFAULT 0,
    month_revenue REAL DEFAULT 0,
    active_clients INT DEFAULT 0
);
-- Inserta la fila única para las estadísticas.
INSERT INTO public.dashboard_stats (id) VALUES (1);


-- --------------------------------------------------------------------------------
-- 3. Vistas y Funciones
-- --------------------------------------------------------------------------------

-- Vista para obtener convenios con contadores de promociones y condiciones.
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

-- Función para obtener estadísticas de un cliente específico.
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id UUID)
RETURNS TABLE(total_spent REAL, average_order_value REAL, total_orders BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0)::REAL AS total_spent,
        COALESCE(AVG(total_amount), 0)::REAL AS average_order_value,
        COUNT(id)::BIGINT AS total_orders
    FROM
        public.orders
    WHERE
        client_id = p_client_id AND status = 'completed';
END;
$$;


-- Función para incrementar el total de ingresos de forma segura.
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add REAL)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.dashboard_stats
  SET total_revenue = total_revenue + amount_to_add
  WHERE id = 1;
END;
$$;


-- --------------------------------------------------------------------------------
-- 4. Storage (Almacenamiento de Archivos)
-- --------------------------------------------------------------------------------

-- Crea el bucket para imágenes de productos si no existe.
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Define políticas de acceso para el bucket de imágenes.
-- Permite a cualquiera leer las imágenes (necesario para mostrarlas en la app).
CREATE POLICY "Public Read Access" ON storage.objects
FOR SELECT USING (bucket_id = 'product_images');

-- Permite a los usuarios autenticados (administradores) subir y modificar imágenes.
CREATE POLICY "Authenticated Write Access" ON storage.objects
FOR INSERT, UPDATE WITH CHECK (
  bucket_id = 'product_images' AND auth.role() = 'authenticated'
);

-- --------------------------------------------------------------------------------
-- 5. Seguridad a Nivel de Fila (RLS)
-- --------------------------------------------------------------------------------

-- La RLS está deshabilitada por defecto. Este script la habilita y define las políticas.
-- El acceso desde el backend (Server Actions) usa la 'service_role_key' de Supabase,
-- que se salta la RLS. Estas reglas se aplican principalmente a las consultas
-- desde el lado del cliente (si las hubiera) o para añadir una capa extra de seguridad.

-- Habilita RLS en todas las tablas.
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
ALTER TABLE public.dashboard_stats ENABLE ROW LEVEL SECURITY;

-- Borra políticas existentes para evitar duplicados.
DROP POLICY IF EXISTS "Allow public read-only access." ON public.products;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.products;
-- Repite el DROP para todas las políticas en todas las tablas...
DROP POLICY IF EXISTS "Allow public read-only access." ON public.price_lists;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.price_lists;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.price_list_items;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.promotions;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.promotions;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.agreements;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.agreements;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.clients;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.clients;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.orders;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.order_items;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.order_items;
DROP POLICY IF EXISTS "Allow public read-only access." ON public.dashboard_stats;
DROP POLICY IF EXISTS "Allow authenticated users to manage data" ON public.dashboard_stats;


-- Políticas Genéricas:
-- Los administradores (rol 'authenticated') pueden hacer de todo.
-- Los usuarios no autenticados ('anon') pueden leer datos públicos (como productos en un pedido).

-- Política para Products
CREATE POLICY "Allow public read-only access." ON public.products FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.products FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para PriceLists
CREATE POLICY "Allow public read-only access." ON public.price_lists FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para PriceListItems
CREATE POLICY "Allow public read-only access." ON public.price_list_items FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para Promotions
CREATE POLICY "Allow public read-only access." ON public.promotions FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para SalesConditions
CREATE POLICY "Allow public read-only access." ON public.sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para Agreements
CREATE POLICY "Allow public read-only access." ON public.agreements FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.agreements FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para AgreementPromotions
CREATE POLICY "Allow public read-only access." ON public.agreement_promotions FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para AgreementSalesConditions
CREATE POLICY "Allow public read-only access." ON public.agreement_sales_conditions FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to manage data" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para Clients
-- Permite a un usuario no autenticado (un cliente) leer sus propios datos si conoce el 'onboarding_token'.
CREATE POLICY "Allow client to read their own data via token" ON public.clients FOR SELECT USING (onboarding_token = (current_setting('request.headers'::text, true)::jsonb ->> 'x-onboarding-token')::uuid);
CREATE POLICY "Allow authenticated users to manage data" ON public.clients FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para Orders
CREATE POLICY "Allow authenticated users to manage data" ON public.orders FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para OrderItems
CREATE POLICY "Allow authenticated users to manage data" ON public.order_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Política para DashboardStats
CREATE POLICY "Allow authenticated users to read stats" ON public.dashboard_stats FOR SELECT USING (auth.role() = 'authenticated');


-- --------------------------------------------------------------------------------
-- Finalización
-- --------------------------------------------------------------------------------

-- -------------------------------------------------------------------------------------
-- 🧹 SECCIÓN DE LIMPIEZA Y RESETEO
-- Esta sección elimina el esquema existente para asegurar una instalación limpia.
-- Es idempotente y seguro de ejecutar múltiples veces.
-- -------------------------------------------------------------------------------------

-- Desactiva la protección de borrado de esquemas en Supabase
-- DO $$
-- BEGIN
--   execute 'ALTER ROLE ' || current_user || ' SET pgrst.db_pre_request = '''';';
-- END;
-- $$;

-- Elimina el esquema 'public' existente y lo recrea.
-- DROP SCHEMA IF EXISTS public CASCADE;
-- CREATE SCHEMA public;
-- GRANT ALL ON SCHEMA public TO postgres;
-- GRANT ALL ON SCHEMA public TO public;

-- Eliminar políticas de RLS para evitar errores de "already exists"
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload product images" ON storage.objects;

DROP POLICY IF EXISTS "Allow admin full access" ON public.products;
DROP POLICY IF EXISTS "Allow public read access" ON public.products;

DROP POLICY IF EXISTS "Allow admin full access" ON public.promotions;
DROP POLICY IF EXISTS "Allow public read access" ON public.promotions;

DROP POLICY IF EXISTS "Allow admin full access" ON public.agreements;
DROP POLICY IF EXISTS "Allow public read access" ON public.agreements;

DROP POLICY IF EXISTS "Allow admin full access" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow public read access" ON public.agreement_promotions;

DROP POLICY IF EXISTS "Allow admin full access" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.agreement_sales_conditions;

DROP POLICY IF EXISTS "Allow admin full access" ON public.clients;
DROP POLICY IF EXISTS "Allow user to read their own client data" ON public.clients;

DROP POLICY IF EXISTS "Allow admin full access" ON public.price_lists;
DROP POLICY IF EXISTS "Allow admin full access" ON public.price_list_items;

DROP POLICY IF EXISTS "Allow admin full access" ON public.orders;
DROP POLICY IF EXISTS "Allow admin full access" ON public.order_items;


-- Elimina las funciones para evitar errores de "already exists"
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(real);
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_overdue_orders();


-- Elimina las vistas y tablas en un orden que respeta las dependencias.
-- Usamos DROP ... IF EXISTS para evitar errores si no existen.
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;

-- Para asegurar que se elimine sin importar si es tabla o vista.
DROP TABLE IF EXISTS public.dashboard_stats;

-- Eliminar tablas dependientes primero
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;

-- Eliminar tablas principales
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.price_lists;


-- Eliminar el bucket de storage si existe.
-- SELECT storage.delete_bucket('product_images');


-- -------------------------------------------------------------------------------------
-- 🧱 SECCIÓN DE CREACIÓN DE ESQUEMA
-- Define la estructura de las tablas, relaciones y políticas de seguridad.
-- -------------------------------------------------------------------------------------

-- Tabla de Productos
CREATE TABLE public.products (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  name text NOT NULL,
  description text,
  category text,
  image_url text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Listas de Precios
CREATE TABLE public.price_lists (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  name text NOT NULL UNIQUE,
  prices_include_vat boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Items de Lista de Precios (tabla intermedia)
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
  name text NOT NULL,
  description text,
  rules jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Condiciones de Venta
CREATE TABLE public.sales_conditions (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  name text NOT NULL,
  description text,
  rules jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Tabla de Convenios
CREATE TABLE public.agreements (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  agreement_name text NOT NULL UNIQUE,
  client_type public.client_type NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  price_list_id uuid REFERENCES public.price_lists(id) ON DELETE SET NULL
);

-- Tabla de Promociones por Convenio (tabla intermedia)
CREATE TABLE public.agreement_promotions (
  agreement_id uuid NOT NULL REFERENCES public.agreements(id) ON DELETE CASCADE,
  promotion_id uuid NOT NULL REFERENCES public.promotions(id) ON DELETE CASCADE,
  PRIMARY KEY (agreement_id, promotion_id)
);

-- Tabla de Condiciones de Venta por Convenio (tabla intermedia)
CREATE TABLE public.agreement_sales_conditions (
    id uuid default gen_random_uuid() not null primary key,
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    unique (agreement_id, sales_condition_id)
);


-- Tabla de Clientes
CREATE TABLE public.clients (
    id uuid default gen_random_uuid() not null primary key,
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status default 'pending_onboarding'::public.client_status not null,
    onboarding_token uuid default gen_random_uuid() not null,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default now() not null,
    fiscal_status text
);

-- Tabla de Pedidos
CREATE TABLE public.orders (
    id uuid default gen_random_uuid() not null primary key,
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamp with time zone default now() not null,
    total_amount numeric(10, 2) not null,
    status public.order_status default 'pending'::public.order_status not null,
    client_name_cache text not null
);

-- Tabla de Items de Pedido
CREATE TABLE public.order_items (
    id uuid default gen_random_uuid() not null primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);


-- -------------------------------------------------------------------------------------
-- 뷰 (VISTAS) Y FUNCIONES
-- Vistas pre-calculadas y funciones para simplificar consultas.
-- -------------------------------------------------------------------------------------

-- Vista para contar promociones y condiciones por convenio
create or replace view public.agreements_with_counts as
  select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count
  from
    public.agreements a;

-- Vista para las estadísticas del Dashboard
create view public.dashboard_stats as
  SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', NOW())) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients;

-- Función para obtener estadísticas de un cliente específico
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
language plpgsql
as $$
begin
  return query
  select
    coalesce(sum(o.total_amount), 0) as total_spent,
    coalesce(avg(o.total_amount), 0) as average_order_value,
    count(o.id) as total_orders
  from public.orders o
  where o.client_id = p_client_id;
end;
$$;

-- Función para obtener pedidos vencidos
CREATE OR REPLACE FUNCTION public.get_overdue_orders()
RETURNS SETOF public.orders AS $$
BEGIN
    RETURN QUERY
    SELECT o.*
    FROM public.orders o
    JOIN public.agreement_sales_conditions asc ON o.agreement_id = asc.agreement_id
    JOIN public.sales_conditions sc ON asc.sales_condition_id = sc.id
    WHERE o.status = 'pending'
      AND sc.rules ->> 'type' = 'net_days'
      AND o.created_at < (NOW() - (sc.rules ->> 'days')::INT * INTERVAL '1 day');
END;
$$ LANGUAGE plpgsql;


-- -------------------------------------------------------------------------------------
-- 🔐 SECCIÓN DE POLÍTICAS DE SEGURIDAD (RLS)
-- Define quién puede acceder y modificar los datos.
-- -------------------------------------------------------------------------------------

-- Habilita RLS en todas las tablas
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_sales_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Políticas para 'products'
CREATE POLICY "Allow admin full access" ON public.products FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.products FOR SELECT USING (true);

-- Políticas para 'promotions'
CREATE POLICY "Allow admin full access" ON public.promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.promotions FOR SELECT USING (true);

-- Políticas para 'agreements'
CREATE POLICY "Allow admin full access" ON public.agreements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.agreements FOR SELECT USING (true);

-- Políticas para 'agreement_promotions'
CREATE POLICY "Allow admin full access" ON public.agreement_promotions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.agreement_promotions FOR SELECT USING (true);

-- Políticas para 'sales_conditions'
CREATE POLICY "Allow admin full access" ON public.sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.sales_conditions FOR SELECT USING (true);


-- Políticas para 'agreement_sales_conditions'
CREATE POLICY "Allow admin full access" ON public.agreement_sales_conditions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.agreement_sales_conditions FOR SELECT USING (true);

-- Políticas para 'clients'
CREATE POLICY "Allow admin full access" ON public.clients FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow user to read own client data via token" ON public.clients FOR SELECT USING (onboarding_token::text = current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token');

-- Políticas para 'price_lists' y 'price_list_items'
CREATE POLICY "Allow admin full access" ON public.price_lists FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.price_lists FOR SELECT USING (true);

CREATE POLICY "Allow admin full access" ON public.price_list_items FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow public read access" ON public.price_list_items FOR SELECT USING (true);


-- Políticas para 'orders' y 'order_items'
CREATE POLICY "Allow admin full access" ON public.orders FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin full access" ON public.order_items FOR ALL USING (auth.role() = 'authenticated');


-- -------------------------------------------------------------------------------------
-- 📦 SECCIÓN DE STORAGE
-- Configura los buckets y políticas para el almacenamiento de archivos.
-- -------------------------------------------------------------------------------------

-- Crear el bucket para imágenes de productos si no existe
INSERT INTO storage.buckets (id, name, public)
VALUES ('product_images', 'product_images', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas para el bucket 'product_images'
CREATE POLICY "Allow public read access to product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product_images');

CREATE POLICY "Allow authenticated users to upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product_images'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Allow authenticated users to update product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'product_images'
  AND auth.role() = 'authenticated'
);


-- ----------------------------
-- BLONDE ORDERS - SCHEMA V1
-- ----------------------------
-- Este script es idempotente. Puedes ejecutarlo de forma segura en cualquier momento.
-- Se encargará de limpiar y reconfigurar el esquema de la base de datos.
-- ----------------------------

-- ----------------------------
-- SECCIÓN DE LIMPIEZA
-- Elimina todos los objetos en el orden correcto de dependencia para evitar errores.
-- ----------------------------

-- 1. Eliminar Policies
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin to manage product images" ON storage.objects;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.products;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.promotions;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.promotions;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.sales_conditions;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.sales_conditions;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.agreements;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.price_lists;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.price_lists;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.price_list_items;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.price_list_items;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.clients;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.clients;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.orders;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.order_items;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.order_items;

-- 2. Eliminar Vistas, Funciones y Triggers
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
DROP FUNCTION IF EXISTS public.get_client_stats(p_client_id uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(amount_to_add real);

-- 3. Eliminar Tablas
-- Usamos 'CASCADE' selectivamente en tablas con FKs para simplificar, 
-- ya que sabemos que las vamos a recrear todas.
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.promotions CASCADE;
DROP TABLE IF EXISTS public.sales_conditions CASCADE;
DROP TABLE IF EXISTS public.price_lists CASCADE;
DROP TABLE IF EXISTS public.agreements CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.order_items;
DROP TABLE IF EXISTS public.dashboard_stats; -- Por si quedó como tabla obsoleta.


-- ----------------------------
-- SECCIÓN DE CREACIÓN DE TABLAS
-- ----------------------------

-- Tabla de Productos
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.products is 'Catálogo de todos los productos disponibles.';

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.price_lists is 'Contenedores para diferentes listas de precios.';

-- Tabla de Items en Listas de Precios (Tabla Pivote)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null,
    volume_price real,
    primary key (price_list_id, product_id)
);
comment on table public.price_list_items is 'Define el precio de un producto en una lista específica.';

-- Tabla de Convenios
create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.agreements is 'Convenios comerciales que agrupan precios y promociones.';

-- Tabla de Promociones
create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.promotions is 'Reglas de negocio para promociones (ej. 2x1, envío gratis).';

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.sales_conditions is 'Condiciones comerciales de pago (ej. 30 días, 10% descuento).';

-- Tabla Pivote Convenio-Promoción
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
comment on table public.agreement_promotions is 'Asigna promociones a un convenio.';

-- Tabla Pivote Convenio-Condición de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
comment on table public.agreement_sales_conditions is 'Asigna condiciones de venta a un convenio.';

-- Tabla de Clientes
create table public.clients (
    id uuid default gen_random_uuid() primary key,
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null,
    onboarding_token uuid default gen_random_uuid() not null,
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.clients is 'Información de los clientes (salones, distribuidores).';

-- Tabla de Pedidos
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount real not null,
    status public.order_status not null,
    client_name_cache text not null
);
comment on table public.orders is 'Registro de los pedidos realizados.';

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit real not null
);
comment on table public.order_items is 'Detalle de los productos en cada pedido.';


-- ----------------------------
-- SECCIÓN DE VISTAS Y FUNCIONES
-- ----------------------------

-- Vista para obtener convenios con contadores de promociones y condiciones
CREATE OR REPLACE VIEW public.agreements_with_counts AS
SELECT
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    pl.name as price_list_name,
    (SELECT count(*) FROM public.agreement_promotions ap_join WHERE ap_join.agreement_id = a.id) as promotion_count,
    (SELECT count(*) FROM public.agreement_sales_conditions asc_join WHERE asc_join.agreement_id = a.id) as sales_condition_count,
    json_build_object('id', pl.id, 'name', pl.name) as price_lists
FROM
    public.agreements a
LEFT JOIN
    public.price_lists pl ON a.price_list_id = pl.id;

-- Vista para las estadísticas del Dashboard
CREATE OR REPLACE VIEW public.dashboard_stats AS
SELECT
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') as total_revenue,
    (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', NOW())) as month_revenue,
    (SELECT COUNT(*) FROM public.clients WHERE status = 'active') as active_clients;

-- Función para obtener estadísticas de un cliente
CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent real, average_order_value real, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0::real) as total_spent,
        COALESCE(AVG(o.total_amount), 0::real) as average_order_value,
        COUNT(o.id) as total_orders
    FROM public.orders o
    WHERE o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

-- Función para RPC para incrementar el total de ingresos (obsoleto, la vista lo reemplaza)
CREATE OR REPLACE FUNCTION public.increment_total_revenue(amount_to_add real)
RETURNS void AS $$
BEGIN
    -- Esta función ahora está obsoleta ya que total_revenue se calcula con una vista.
    -- Se mantiene por retrocompatibilidad si alguna acción aún la llama, pero no hace nada.
END;
$$ LANGUAGE plpgsql;


-- ----------------------------
-- SECCIÓN DE POLÍTICAS DE SEGURIDAD (RLS)
-- ----------------------------
-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Políticas para tablas principales (CRUD para admins)
create policy "Enable all access for authenticated users" on public.products for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.clients for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.orders for all using (auth.role() = 'authenticated');
create policy "Enable all access for authenticated users" on public.order_items for all using (auth.role() = 'authenticated');

-- Políticas para lectura pública en tablas necesarias para la página de pedido
create policy "Enable read access for all users" on public.products for select using (true);
create policy "Enable read access for all users" on public.promotions for select using (true);
create policy "Enable read access for all users" on public.agreements for select using (true);
create policy "Enable read access for all users" on public.price_lists for select using (true);
create policy "Enable read access for all users" on public.price_list_items for select using (true);
create policy "Enable read access for all users" on public.agreement_promotions for select using (true);
create policy "Enable read access for all users" on public.clients for select using (true);

-- ----------------------------
-- SECCIÓN DE ALMACENAMIENTO (Storage)
-- ----------------------------
-- Crear bucket para imágenes de productos si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Políticas de acceso para el bucket de imágenes
CREATE POLICY "Allow public read access to product images" ON storage.objects
FOR SELECT USING (bucket_id = 'product_images');

CREATE POLICY "Allow admin to manage product images" ON storage.objects
FOR ALL USING (bucket_id = 'product_images' AND auth.role() = 'authenticated');

-- ----------------------------
-- FIN DEL SCRIPT
-- ----------------------------

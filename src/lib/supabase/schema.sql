-- ----------------------------------------------------------------
-- ----------------------------------------------------------------
--    SCRIPT DE BASE DE DATOS PARA BLONDE ORDERS
-- ----------------------------------------------------------------
-- ----------------------------------------------------------------
-- Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura
-- en una base de datos nueva o existente. Se encargará de 
-- limpiar y reconfigurar las tablas y funciones necesarias.
-- ----------------------------------------------------------------

-- ----------------------------------------------------------------
--  1. LIMPIEZA DE OBJETOS ANTIGUOS (en el orden correcto)
-- ----------------------------------------------------------------

-- Elimina vistas que dependen de las tablas
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats;

-- Elimina funciones
drop function if exists public.get_client_stats;
drop function if exists public.increment_total_revenue;

-- Elimina tablas (ahora que no hay vistas/funciones dependiendo de ellas)
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.products;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.price_lists;

-- Elimina políticas de seguridad de Storage
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow admins to manage product images" on storage.objects;

-- ----------------------------------------------------------------
--  2. CREACIÓN DE TABLAS
-- ----------------------------------------------------------------

-- Tabla de Productos
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default now() not null
);
comment on table public.products is 'Catálogo de todos los productos disponibles.';

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default now() not null
);
comment on table public.price_lists is 'Contenedor de listas de precios reutilizables.';

-- Tabla de Items de Listas de Precios (tabla pivote)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric not null check (price >= 0),
    volume_price numeric check (volume_price >= 0),
    primary key (price_list_id, product_id)
);
comment on table public.price_list_items is 'Define el precio de un producto en una lista específica.';

-- Tabla de Convenios
create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default now() not null
);
comment on table public.agreements is 'Convenios comerciales que agrupan precios y promociones.';

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
    fiscal_status text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default now() not null,
    constraint clients_agreement_id_unique unique (agreement_id)
);
comment on table public.clients is 'Información de los clientes (salones, distribuidores).';

-- Tabla de Promociones
create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default now() not null
);
comment on table public.promotions is 'Reglas de promociones (ej. 2x1, envío gratis).';

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default now() not null
);
comment on table public.sales_conditions is 'Condiciones comerciales como plazos de pago, descuentos, etc.';

-- Tabla Pivote: Convenios y Promociones
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
comment on table public.agreement_promotions is 'Asocia promociones a un convenio.';

-- Tabla Pivote: Convenios y Condiciones de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
comment on table public.agreement_sales_conditions is 'Asocia condiciones de venta a un convenio.';

-- Tabla de Pedidos
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone default now() not null,
    total_amount numeric not null,
    status public.order_status not null,
    client_name_cache text not null
);
comment on table public.orders is 'Registra los pedidos realizados por los clientes.';

-- Tabla de Items de Pedidos
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric not null
);
comment on table public.order_items is 'Detalle de los productos en cada pedido.';


-- ----------------------------------------------------------------
--  3. HABILITACIÓN DE RLS Y CREACIÓN DE POLÍTICAS
-- ----------------------------------------------------------------

-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.agreements enable row level security;
alter table public.promotions enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_sales_conditions enable row level security;

-- Políticas para permitir acceso público a ciertas cosas
create policy "Allow public read access on agreements" on public.agreements for select using (true);
create policy "Allow public read access on products" on public.products for select using (true);
create policy "Allow public read access on promotions" on public.promotions for select using (true);
create policy "Allow public read access on agreement_promotions" on public.agreement_promotions for select using (true);
create policy "Allow public read access on price_lists" on public.price_lists for select using (true);
create policy "Allow public read access on price_list_items" on public.price_list_items for select using (true);

-- Políticas para permitir acceso de lectura público a clientes para onboarding
create policy "Allow public read for onboarding" on public.clients for select using (true);

-- Políticas para que los usuarios autenticados (admins) puedan gestionar todo
create policy "Allow full access for authenticated users" on public.products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreements for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreement_promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.clients for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.orders for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.order_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.price_lists for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.price_list_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ----------------------------------------------------------------
--  4. VISTAS Y FUNCIONES
-- ----------------------------------------------------------------

-- Vista para contar promociones y condiciones en convenios
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

-- Vista para estadísticas del dashboard
create or replace view public.dashboard_stats as
select
    coalesce(sum(case when status = 'completed' then total_amount else 0 end), 0) as total_revenue,
    coalesce(sum(case when status = 'completed' and created_at > date_trunc('month', now()) then total_amount else 0 end), 0) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients
from
    public.orders;

-- Función para estadísticas de un cliente
create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent numeric, average_order_value numeric, total_orders bigint) as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0) as total_spent,
        coalesce(avg(o.total_amount), 0) as average_order_value,
        count(o.id) as total_orders
    from
        public.orders o
    where
        o.client_id = p_client_id and o.status = 'completed';
end;
$$ language plpgsql;

-- Función para incrementar los ingresos (ya no es necesaria con la vista)
-- drop function if exists public.increment_total_revenue;

-- ----------------------------------------------------------------
--  5. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- ----------------------------------------------------------------

-- Permite lectura pública de las imágenes
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Permite a los administradores subir, editar y borrar imágenes
create policy "Allow admins to manage product images"
on storage.objects for all
using ( bucket_id = 'product_images' and auth.role() = 'authenticated' )
with check ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

-- ----------------------------------------------------------------
--  FIN DEL SCRIPT
-- ----------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------------
-- ------------               ¡ATENCIÓN! SCRIPT DE LIMPIEZA Y RECONSTRUCCIÓN                ------------
-- ------------                                                                              ------------
-- ------------  Este script está diseñado para ser idempotente. Puedes ejecutarlo          ------------
-- ------------  de forma segura en cualquier momento para resetear el esquema de la DB      ------------
-- ------------  a su estado inicial, eliminando datos existentes y re-creando las tablas.  ------------
-- ------------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------------


-- ----------------------------------------------------------------
-- 1. SECCIÓN DE LIMPIEZA PROFUNDA
-- Cierra conexiones activas y elimina el esquema 'public' completo para empezar de cero.
-- ----------------------------------------------------------------

-- Cierra todas las conexiones a la base de datos actual para evitar conflictos.
select pg_terminate_backend(pid) from pg_stat_activity where datname = current_database();

-- Elimina el esquema 'public' y todo su contenido (tablas, vistas, funciones, etc.).
-- 'CASCADE' asegura que todos los objetos dependientes se eliminen también.
drop schema if exists public cascade;

-- Re-crea el esquema 'public' vacío.
create schema public;

-- Otorga todos los privilegios sobre el nuevo esquema 'public' al rol 'postgres'.
grant all on schema public to postgres;

-- Otorga todos los privilegios sobre el nuevo esquema 'public' a todos los roles.
grant all on schema public to public;

-- Elimina cualquier política de seguridad residual en la tabla de almacenamiento de objetos.
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow admins to manage product images" on storage.objects;

-- ----------------------------------------------------------------
-- 2. CREACIÓN DE TABLAS
-- Se crean todas las tablas necesarias para la aplicación.
-- ----------------------------------------------------------------

-- Tabla de Productos
create table if not exists public.products (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default now() not null,
    name text not null,
    description text null,
    category text null,
    image_url text null
);
alter table public.products enable row level security;

-- Tabla de Listas de Precios
create table if not exists public.price_lists (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default now() not null,
    name text not null,
    prices_include_vat boolean default true not null,
    constraint price_lists_name_unique unique (name)
);
alter table public.price_lists enable row level security;

-- Tabla de Items de Listas de Precios (tabla de unión)
create table if not exists public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric not null,
    volume_price numeric null,
    primary key (price_list_id, product_id)
);
alter table public.price_list_items enable row level security;

-- Tabla de Convenios
create table if not exists public.agreements (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default now() not null,
    agreement_name text not null,
    client_type public.client_type not null,
    price_list_id uuid null references public.price_lists(id) on delete set null,
    constraint agreements_agreement_name_key unique (agreement_name)
);
alter table public.agreements enable row level security;

-- Tabla de Clientes
create table if not exists public.clients (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default now() not null,
    cuit text null,
    contact_name text null,
    contact_dni text null,
    address text null,
    delivery_window text null,
    email text null,
    instagram text null,
    status public.client_status not null,
    onboarding_token uuid not null,
    agreement_id uuid null,
    fiscal_status text null,
    constraint clients_cuit_key unique (cuit),
    constraint clients_email_key unique (email),
    constraint clients_onboarding_token_key unique (onboarding_token),
    constraint clients_agreement_id_fkey foreign key (agreement_id) references public.agreements(id) on delete set null,
    constraint clients_agreement_id_unique unique (agreement_id)
);
alter table public.clients enable row level security;

-- Tabla de Promociones
create table if not exists public.promotions (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default now() not null,
    name text not null,
    description text null,
    rules jsonb null
);
alter table public.promotions enable row level security;

-- Tabla de Condiciones de Venta
create table if not exists public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default now() not null,
    name text not null,
    description text null,
    rules jsonb null
);
alter table public.sales_conditions enable row level security;

-- Tabla de Promociones por Convenio (tabla de unión)
create table if not exists public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
alter table public.agreement_promotions enable row level security;

-- Tabla de Condiciones de Venta por Convenio (tabla de unión)
create table if not exists public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table public.agreement_sales_conditions enable row level security;

-- Tabla de Pedidos
create table if not exists public.orders (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default now() not null,
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    total_amount numeric not null,
    status public.order_status not null,
    client_name_cache text not null
);
alter table public.orders enable row level security;

-- Tabla de Items de Pedido
create table if not exists public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric not null
);
alter table public.order_items enable row level security;

-- ----------------------------------------------------------------
-- 3. CREACIÓN DE VISTAS
-- Vistas que simplifican las consultas complejas.
-- ----------------------------------------------------------------

-- Vista para obtener estadísticas del dashboard
create or replace view public.dashboard_stats as
select
    coalesce(sum(case when status = 'completed' then total_amount else 0 end), 0) as total_revenue,
    coalesce(sum(case when status = 'completed' and created_at > date_trunc('month', now()) then total_amount else 0 end), 0) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients
from public.orders;

-- Vista para contar promociones y condiciones por convenio
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions where agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions where agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

-- ----------------------------------------------------------------
-- 4. CREACIÓN DE FUNCIONES
-- Funciones personalizadas de la base de datos.
-- ----------------------------------------------------------------

-- Función para obtener estadísticas de un cliente específico
create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent numeric, average_order_value numeric, total_orders bigint)
language plpgsql
as $$
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
$$;

-- ----------------------------------------------------------------
-- 5. POLÍTICAS DE SEGURIDAD (RLS)
-- Políticas que definen quién puede acceder o modificar los datos.
-- ----------------------------------------------------------------

-- Políticas para 'products'
create policy "Allow all for authenticated users" on public.products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Políticas para 'price_lists'
create policy "Allow all for authenticated users" on public.price_lists for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Políticas para 'price_list_items'
create policy "Allow all for authenticated users" on public.price_list_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Políticas para 'agreements'
create policy "Allow all for authenticated users" on public.agreements for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow public read access" on public.agreements for select using (true);

-- Políticas para 'clients'
create policy "Allow all for authenticated users" on public.clients for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow public read for onboarding" on public.clients for select using (true);

-- Políticas para 'promotions'
create policy "Allow all for authenticated users" on public.promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Políticas para 'sales_conditions'
create policy "Allow all for authenticated users" on public.sales_conditions for all using (auth.role() = 'authenticated') with check (auth_role() = 'authenticated');

-- Políticas para 'agreement_promotions'
create policy "Allow all for authenticated users" on public.agreement_promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow public read access" on public.agreement_promotions for select using (true);

-- Políticas para 'agreement_sales_conditions'
create policy "Allow all for authenticated users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow public read access" on public.agreement_sales_conditions for select using (true);

-- Políticas para 'orders'
create policy "Allow all for authenticated users" on public.orders for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow public insert access" on public.orders for insert with check (true);

-- Políticas para 'order_items'
create policy "Allow all for authenticated users" on public.order_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow public insert access" on public.order_items for insert with check (true);


-- ----------------------------------------------------------------
-- 6. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- Políticas que gestionan el acceso a los archivos en Supabase Storage.
-- ----------------------------------------------------------------

-- Permite la lectura pública de todas las imágenes en el bucket 'product_images'.
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Permite a los usuarios autenticados (administradores) subir, modificar y eliminar imágenes.
create policy "Allow admins to manage product images"
on storage.objects for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );

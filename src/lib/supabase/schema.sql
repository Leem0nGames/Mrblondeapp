-- 1. Limpieza y Reseteo
-- Drop de objetos en orden inverso a su creación para evitar errores de dependencia.
-- SIEMPRE usar DROP ... CASCADE para manejar dependencias automáticamente.
drop function if exists public.get_notification_counts() cascade;
drop function if exists public.get_client_stats(uuid) cascade;
drop function if exists public.increment_total_revenue(double precision) cascade;
drop view if exists public.agreements_with_counts cascade;
drop view if exists public.dashboard_stats cascade;
drop table if exists public.app_settings cascade;
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreements cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.products cascade;
drop type if exists public.client_status cascade;

-- Políticas de Storage
drop policy if exists "Allow public read access to app assets" on storage.objects;
drop policy if exists "Allow authenticated admin to manage product images" on storage.objects;
drop policy if exists "Allow public read access to product images" on storage.objects;


-- 2. Creación de Tipos (Enums)
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');


-- 3. Creación de Tablas
create table public.products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamptz not null default now()
);

create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamptz not null default now(),
    base_price_list_id uuid references public.price_lists(id) on delete set null,
    discount_percentage real
);

create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null,
    volume_price real,
    primary key (price_list_id, product_id)
);

create table public.promotions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamptz not null default now()
);

create table public.sales_conditions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamptz not null default now()
);

create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null unique,
    client_type text not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamptz not null default now()
);

create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    latitude float8,
    longitude float8,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null,
    onboarding_token text unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamptz not null default now()
);

create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamptz not null default now(),
    total_amount real not null,
    status text not null,
    client_name_cache text not null,
    notes text
);

create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit real not null
);

create table public.app_settings (
    key text primary key,
    value jsonb
);


-- 4. Creación de Vistas y Funciones

-- Vista para estadísticas del dashboard
create or replace view public.dashboard_stats as
select
    coalesce((select sum(total_amount) from public.orders where status = 'completed'), 0) as total_revenue,
    coalesce((select sum(total_amount) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())), 0) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients,
    (select count(*) from public.orders where status = 'pending' and created_at < now() - interval '2 days') as overdue_orders_count,
    (select count(*) from public.clients) as total_clients,
    (select count(*) from public.price_lists) as total_pricelists,
    (select count(*) from public.promotions) as total_promotions,
    (select count(*) from public.sales_conditions) as total_sales_conditions;

-- Vista para convenios con conteo de promociones y condiciones
create or replace view public.agreements_with_counts as
select
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    coalesce(pc.count, 0) as promotion_count,
    coalesce(scc.count, 0) as sales_condition_count
from
    public.agreements agr
left join (
    select agreement_id, count(*) as count
    from public.agreement_promotions
    group by agreement_id
) pc on agr.id = pc.agreement_id
left join (
    select agreement_id, count(*) as count
    from public.agreement_sales_conditions
    group by agreement_id
) scc on agr.id = scc.agreement_id;

-- Función para estadísticas de un cliente
create or replace function public.get_client_stats(p_client_id uuid)
returns table (
    total_spent real,
    average_order_value real,
    total_orders bigint
)
language plpgsql
as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0.0)::real as total_spent,
        coalesce(avg(o.total_amount), 0.0)::real as average_order_value,
        count(o.id)::bigint as total_orders
    from public.orders as o
    where o.client_id = p_client_id and o.status = 'completed';
end;
$$;

-- Función para contadores de notificaciones
create or replace function public.get_notification_counts()
returns table (
    pending_orders_count bigint,
    pending_clients_count bigint,
    overdue_orders_count bigint
)
language plpgsql
as $$
begin
    return query
    select
        (select count(*) from public.orders where status = 'pending') as pending_orders_count,
        (select count(*) from public.clients where status = 'pending_agreement') as pending_clients_count,
        (select count(*) from public.orders where status = 'pending' and created_at < now() - interval '2 days') as overdue_orders_count;
end;
$$;


-- 5. Habilitación de Row-Level Security (RLS)
alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreements enable row level security;
alter table public.clients enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.app_settings enable row level security;


-- 6. Creación de Políticas RLS
-- Permite acceso de lectura público para ciertas tablas si es necesario.
-- Por defecto, se deniega el acceso a menos que se cree una política.

-- Políticas para administradores autenticados
create policy "Allow all for authenticated admins" on public.products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.price_lists for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.price_list_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.agreements for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.clients for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.agreement_promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.orders for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow all for authenticated admins" on public.order_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admins to manage app settings" on public.app_settings for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- Políticas para acceso anónimo (si es necesario)
create policy "Allow anonymous read access to agreements" on public.agreements for select using (true);
create policy "Allow anonymous read access to price lists" on public.price_lists for select using (true);
create policy "Allow anonymous read access to price list items" on public.price_list_items for select using (true);
create policy "Allow anonymous read access to products" on public.products for select using (true);
create policy "Allow anonymous read access to promotions" on public.promotions for select using (true);
create policy "Allow anonymous read access to agreement promotions" on public.agreement_promotions for select using (true);
create policy "Allow anonymous read access to app settings" on public.app_settings for select using (true);

-- Políticas para que los clientes se registren y creen pedidos
create policy "Allow anonymous access to create orders" on public.orders for insert with check (true);
create policy "Allow anonymous access to create order items" on public.order_items for insert with check (true);
create policy "Allow anonymous read on clients for onboarding" on public.clients for select using (onboarding_token is not null);
create policy "Allow anonymous update on clients for onboarding" on public.clients for update using (onboarding_token is not null) with check (onboarding_token is not null);


-- 7. Políticas de Storage
create policy "Allow public read access to app assets" on storage.objects for select to public using (bucket_id = 'app_assets');
create policy "Allow authenticated admin to manage product images" on storage.objects for all to authenticated with check (bucket_id = 'product_images');
create policy "Allow public read access to product images" on storage.objects for select to public using (bucket_id = 'product_images');


-- 1. Limpieza y Reseteo
-- Drop de objetos en orden inverso a su creación para evitar errores de dependencia.
-- Se usa CASCADE para eliminar objetos dependientes automáticamente.
drop function if exists public.get_notification_counts() cascade;
drop view if exists public.agreements_with_counts cascade;
drop view if exists public.dashboard_stats cascade;
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.products cascade;
drop table if exists public.app_settings cascade;
drop type if exists public.client_status cascade;


-- 2. Creación de Tipos (Enums)
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');

-- 3. Creación de Tablas
create table public.products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default now() not null
);

create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default now() not null
);

create table public.price_list_items (
    price_list_id uuid references public.price_lists(id) on delete cascade not null,
    product_id uuid references public.products(id) on delete cascade not null,
    price numeric(10, 2) not null check (price >= 0),
    volume_price numeric(10, 2) check (volume_price >= 0),
    primary key (price_list_id, product_id)
);

create table public.promotions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone default now() not null
);

create table public.sales_conditions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone default now() not null
);

create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null unique,
    client_type text not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default now() not null
);

create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid unique default gen_random_uuid(),
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    latitude double precision,
    longitude double precision,
    created_at timestamp with time zone default now() not null
);

create table public.agreement_promotions (
    agreement_id uuid references public.agreements(id) on delete cascade not null,
    promotion_id uuid references public.promotions(id) on delete cascade not null,
    primary key (agreement_id, promotion_id)
);

create table public.agreement_sales_conditions (
    agreement_id uuid references public.agreements(id) on delete cascade not null,
    sales_condition_id uuid references public.sales_conditions(id) on delete cascade not null,
    primary key (agreement_id, sales_condition_id)
);

create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid references public.clients(id) on delete set null,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default now() not null,
    total_amount numeric(10, 2) not null,
    status text default 'pending' not null,
    client_name_cache text not null,
    notes text
);

create table public.order_items (
    order_id uuid references public.orders(id) on delete cascade not null,
    product_id uuid references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null,
    primary key (order_id, product_id)
);

create table public.app_settings (
    key text primary key,
    value jsonb
);

-- 4. Creación de Vistas y Funciones
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_cond where asc_cond.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients,
    (select count(*) from public.orders where status = 'pending' and created_at < now() - interval '3 days') as overdue_orders_count,
    (select count(*) from public.clients where status in ('active', 'pending_agreement')) as total_clients,
    (select count(*) from public.price_lists) as total_pricelists,
    (select count(*) from public.promotions) as total_promotions,
    (select count(*) from public.sales_conditions) as total_sales_conditions;

create or replace function public.get_notification_counts()
returns table (pending_orders_count int, pending_clients_count int, overdue_orders_count int) as $$
begin
    return query
    select
        (select count(*)::int from public.orders where status = 'pending'),
        (select count(*)::int from public.clients where status = 'pending_agreement'),
        (select count(*)::int from public.orders where status = 'pending' and created_at < now() - interval '3 days');
end;
$$ language plpgsql;

create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
    -- This function is a placeholder and might not be the most performant way
    -- to update stats in a high-traffic environment. For this app, it's sufficient.
end;
$$ language plpgsql;

create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent numeric, average_order_value numeric, total_orders bigint) as $$
begin
  return query
  select
    coalesce(sum(o.total_amount), 0) as total_spent,
    coalesce(avg(o.total_amount), 0) as average_order_value,
    count(o.id) as total_orders
  from public.orders o
  where o.client_id = p_client_id;
end;
$$ language plpgsql;


-- 5. Habilitar Row-Level Security (RLS)
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

-- 6. Creación de Políticas de RLS
-- Permitir acceso completo a los administradores (usando service_role)
create policy "Allow all for service role" on public.products for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.price_lists for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.price_list_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.agreements for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.clients for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.agreement_promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.agreement_sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.orders for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.order_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service role" on public.app_settings for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- Permitir lectura pública (anónima) para datos necesarios en páginas de pedido/onboarding
create policy "Allow public read on settings" on public.app_settings for select using (true);
create policy "Allow public read on agreements" on public.agreements for select using (true);
create policy "Allow public read on promotions" on public.promotions for select using (true);
create policy "Allow public read on price_lists" on public.price_lists for select using (true);
create policy "Allow public read on price_list_items" on public.price_list_items for select using (true);
create policy "Allow public read on products" on public.products for select using (true);
create policy "Allow public read on agreement_promotions" on public.agreement_promotions for select using (true);

-- Política específica para que el cliente pueda ver sus propios datos de onboarding
drop policy if exists "Allow anon read for onboarding" on public.clients;
create policy "Allow anon read for onboarding" on public.clients for select using (onboarding_token = (select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token', '')::uuid));

-- Políticas para que usuarios anónimos creen pedidos y se registren
create policy "Allow anon insert for orders" on public.orders for insert with check (true);
create policy "Allow anon insert for order_items" on public.order_items for insert with check (true);
create policy "Allow anon update for clients on onboarding" on public.clients for update using (onboarding_token = (select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'onboarding_token', '')::uuid));

-- 7. Políticas de Almacenamiento (Storage)
-- Limpiar políticas existentes antes de crearlas
drop policy if exists "Allow public read on product_images" on storage.objects;
drop policy if exists "Allow admin full access on product_images" on storage.objects;
drop policy if exists "Allow public read on app_assets" on storage.objects;
drop policy if exists "Allow admin full access on app_assets" on storage.objects;

-- Asegurar que los buckets existen
insert into storage.buckets (id, name, public) values ('product_images', 'product_images', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('app_assets', 'app_assets', false) on conflict (id) do nothing;

-- Políticas para el bucket 'product_images'
create policy "Allow public read on product_images" on storage.objects for select to anon, authenticated using (bucket_id = 'product_images');
create policy "Allow admin full access on product_images" on storage.objects for all to service_role using (bucket_id = 'product_images');

-- Políticas para el bucket 'app_assets' (logo)
create policy "Allow public read on app_assets" on storage.objects for select to anon, authenticated using (bucket_id = 'app_assets');
create policy "Allow admin full access on app_assets" on storage.objects for all to service_role using (bucket_id = 'app_assets');

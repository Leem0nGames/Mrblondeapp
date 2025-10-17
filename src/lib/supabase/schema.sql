
-- Versión 2.0.0
-- Limpieza y Reseteo
drop table if exists public.app_meta cascade;
drop table if exists public.products cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.agreements cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.clients cascade;
drop table if exists public.orders cascade;
drop table if exists public.order_items cascade;
drop view if exists public.agreements_with_counts cascade;
drop view if exists public.dashboard_stats cascade;
drop function if exists public.get_client_stats(uuid) cascade;
drop function if exists public.get_notification_counts() cascade;
drop function if exists public.increment_total_revenue(double precision) cascade;

-- 1. Tipos (ENUMS)
-- (No hay enums personalizados por ahora)

-- 2. Creación de Tablas
create table public.app_meta (
    key text primary key,
    value jsonb not null
);

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
    created_at timestamptz not null default now()
);

create table public.price_list_items (
    price_list_id uuid not null references public.price_lists on delete cascade,
    product_id uuid not null references public.products on delete cascade,
    price double precision not null,
    volume_price double precision,
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
    created_at timestamptz not null default now(),
    price_list_id uuid references public.price_lists on delete set null
);

create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements on delete cascade,
    promotion_id uuid not null references public.promotions on delete cascade,
    primary key (agreement_id, promotion_id)
);

create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions on delete cascade,
    primary key (agreement_id, sales_condition_id)
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
    status text not null,
    onboarding_token text not null unique,
    agreement_id uuid references public.agreements on delete set null,
    created_at timestamptz not null default now(),
    fiscal_status text,
    latitude double precision,
    longitude double precision
);

create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients,
    agreement_id uuid not null references public.agreements,
    created_at timestamptz not null default now(),
    total_amount double precision not null,
    status text not null,
    client_name_cache text not null,
    notes text
);

create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders on delete cascade,
    product_id uuid not null references public.products,
    quantity integer not null,
    price_per_unit double precision not null
);

-- 3. Vistas
create or replace view public.agreements_with_counts as
select
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_ where asc_.agreement_id = a.id) as sales_condition_count
from public.agreements a;


create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', current_date)) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients,
    (select count(*) from public.orders where status = 'pending' and created_at < (now() - interval '3 days')) as overdue_orders_count;


-- 4. Funciones
create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent double precision, average_order_value double precision, total_orders bigint) as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0.0) as total_spent,
        coalesce(avg(o.total_amount), 0.0) as average_order_value,
        count(o.id) as total_orders
    from
        public.orders as o
    where
        o.client_id = p_client_id;
end;
$$ language plpgsql;

create or replace function public.get_notification_counts()
returns table (pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint) as $$
begin
  return query
  select
    (select count(*) from public.orders where status = 'pending') as pending_orders_count,
    (select count(*) from public.clients where status = 'pending_agreement') as pending_clients_count,
    (select count(*) from public.orders where status = 'pending' and created_at < (now() - interval '3 days')) as overdue_orders_count;
end;
$$ language plpgsql;


create or replace function public.increment_total_revenue(amount_to_add double precision)
returns void as $$
declare
    current_revenue double precision;
begin
    -- Get current value
    select coalesce((value->>'total_revenue')::double precision, 0)
    into current_revenue
    from public.app_meta
    where key = 'stats';

    -- Upsert new value
    insert into public.app_meta (key, value)
    values ('stats', jsonb_build_object('total_revenue', current_revenue + amount_to_add))
    on conflict (key) do update
    set value = jsonb_set(
        app_meta.value,
        '{total_revenue}',
        to_jsonb(coalesce((app_meta.value->>'total_revenue')::double precision, 0) + amount_to_add)
    );
end;
$$ language plpgsql;


-- 5. Row Level Security (RLS)
alter table public.app_meta enable row level security;
alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;


-- 6. Policies
create policy "Allow all for service_role" on public.app_meta for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.products for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.price_lists for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.price_list_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreements for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreement_promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreement_sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.clients for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- ANONYMOUS POLICIES (for public access)
create policy "Allow anonymous read for public data" on public.products for select using (true);
create policy "Allow anonymous read for public data" on public.price_lists for select using (true);
create policy "Allow anonymous read for public data" on public.price_list_items for select using (true);
create policy "Allow anonymous read for public data" on public.promotions for select using (true);
create policy "Allow anonymous read for public data" on public.agreements for select using (true);
create policy "Allow anonymous read for public data" on public.agreement_promotions for select using (true);
create policy "Allow anonymous read for public data" on public.clients for select using (true);

-- ONBOARDING POLICIES (let users update their own client entry if they have the token)
create policy "Allow anonymous update for onboarding" on public.clients for update
using (onboarding_token = (select current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token'))
with check (onboarding_token = (select current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token'));

-- ORDER POLICIES
create policy "Allow all for service_role" on public.orders for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.order_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- *** SOLUCIÓN: Política para permitir que usuarios anónimos creen pedidos ***
create policy "Allow anonymous insert for orders" on public.orders for insert
with check (true);
create policy "Allow anonymous insert for order items" on public.order_items for insert
with check (true);


-- 7. Storage Policies
create policy "Allow public read on product_images" on storage.objects for select using (bucket_id = 'product_images');
create policy "Allow insert for service_role on product_images" on storage.objects for insert with check (bucket_id = 'product_images' and auth.role() = 'service_role');
create policy "Allow update for service_role on product_images" on storage.objects for update with check (bucket_id = 'product_images' and auth.role() = 'service_role');

-- 8. Seed Data
-- Insertar el total de revenue inicial
insert into public.app_meta (key, value)
values ('stats', '{"total_revenue": 0}')
on conflict (key) do nothing;


-- 1. Reinicio del Esquema (Idempotente)
-- Elimina todo en orden inverso a la creación para evitar errores de dependencia.
-- Usar CASCADE para eliminar objetos dependientes automáticamente.
drop view if exists public.dashboard_stats cascade;
drop view if exists public.orders_with_overdue_status cascade;
drop view if exists public.agreements_with_counts cascade;
drop function if exists public.get_notification_counts() cascade;
drop function if exists public.get_client_stats(uuid) cascade;
drop function if exists public.get_clients_heatmap_data() cascade;
drop function if exists public.increment_total_revenue(numeric) cascade;
drop table if exists public.app_settings cascade;
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreements cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.products cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop type if exists public.client_status cascade;
drop type if exists public.order_status cascade;

-- 2. Definición de Tipos (ENUMS)
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.order_status as enum ('pending', 'completed');

-- 3. Creación de Tablas
create table public.products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);

create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);

create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric not null,
    volume_price numeric,
    primary key (price_list_id, product_id)
);

create table public.promotions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

create table public.sales_conditions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null unique,
    client_type public.client_status not null default 'active',
    price_list_id uuid references public.price_lists(id),
    created_at timestamp with time zone not null default now()
);

create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    latitude double precision,
    longitude double precision,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid default gen_random_uuid(),
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamp with time zone not null default now()
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
    client_id uuid references public.clients(id),
    agreement_id uuid references public.agreements(id),
    created_at timestamp with time zone not null default now(),
    total_amount numeric not null,
    status public.order_status not null default 'pending',
    client_name_cache text not null,
    notes text,
    due_date date GENERATED ALWAYS AS ((created_at + '30 days'::interval)::date) STORED
);

create table public.order_items (
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit numeric not null,
    primary key (order_id, product_id)
);

create table public.app_settings (
    key text primary key,
    value jsonb
);

-- 4. Vistas
create or replace view public.agreements_with_counts as
select
    agr.id,
    agr.agreement_name,
    agr.client_type,
    agr.price_list_id,
    agr.created_at,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = agr.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions ascnd where ascnd.agreement_id = agr.id) as sales_condition_count
from
    public.agreements agr;

create or replace view public.orders_with_overdue_status as
select
  *,
  (status = 'pending' and due_date < now()::date) as overdue,
  GREATEST(0, (now()::date - due_date)) as days_overdue
from
  public.orders;

create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients,
    (select count(*) from public.orders_with_overdue_status where overdue = true) as overdue_orders_count,
    (select count(*) from public.clients where status in ('active', 'pending_agreement')) as total_clients,
    (select count(*) from public.price_lists) as total_pricelists,
    (select count(*) from public.promotions) as total_promotions,
    (select count(*) from public.sales_conditions) as total_sales_conditions;


-- 5. Funciones
create or replace function public.get_notification_counts()
returns table (pending_orders_count int, pending_clients_count int, overdue_orders_count int)
language sql
as $$
    select
        (select count(*)::int from public.orders where status = 'pending'),
        (select count(*)::int from public.clients where status = 'pending_agreement'),
        (select count(*)::int from public.orders_with_overdue_status where overdue = true);
$$;

create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent numeric, average_order_value numeric, total_orders bigint)
language sql
as $$
    select
        coalesce(sum(total_amount), 0) as total_spent,
        coalesce(avg(total_amount), 0) as average_order_value,
        count(id) as total_orders
    from public.orders
    where client_id = p_client_id and status = 'completed';
$$;

create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
    -- Esta función es un placeholder. En un sistema real, la agregación de estadísticas
    -- se manejaría de una forma más robusta, posiblemente con triggers o tareas programadas.
end;
$$ language plpgsql;

create or replace function public.get_clients_heatmap_data()
returns table (id uuid, name text, value numeric, risk int)
language sql
as $$
    select
        c.id,
        c.contact_name as name,
        coalesce(sum(o.total_amount), 0) as value,
        (select count(*)::int from public.orders_with_overdue_status ov where ov.client_id = c.id and ov.overdue = true) as risk
    from public.clients c
    left join public.orders o on c.id = o.client_id
    where c.status = 'active'
    group by c.id, c.contact_name
    order by value desc;
$$;


-- 6. Seguridad (RLS y Policies)
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

-- Políticas para permitir acceso total al rol de servicio (administrador)
create policy "Allow all for service_role" on public.products for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.price_lists for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.price_list_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreements for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.clients for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreement_promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreement_sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.orders for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.order_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.app_settings for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- Políticas para acceso anónimo (páginas de pedido y onboarding)
create policy "Allow read for anon" on public.products for select to anon using (true);
create policy "Allow read for anon" on public.price_lists for select to anon using (true);
create policy "Allow read for anon" on public.price_list_items for select to anon using (true);
create policy "Allow read for anon" on public.promotions for select to anon using (true);
create policy "Allow read for anon" on public.agreements for select to anon using (true);
create policy "Allow read for anon" on public.agreement_promotions for select to anon using (true);
create policy "Allow read for anon" on public.clients for select to anon using (true);
create policy "Allow read for anon" on public.app_settings for select to anon using (true);

-- Permisos de escritura para anónimos (muy específicos)
create policy "Allow insert for anon users" on public.orders for insert to anon with check (true);
create policy "Allow insert for anon users" on public.order_items for insert to anon with check (true);
create policy "Allow update for onboarding clients" on public.clients for update to anon using (onboarding_token is not null) with check (onboarding_token is not null);

-- 7. Bucket de Storage
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('app_assets', 'app_assets', true)
on conflict (id) do nothing;

create policy "Allow public read access" on storage.objects for select
using ( bucket_id in ('product_images', 'app_assets') );

create policy "Allow insert for service_role" on storage.objects for insert to service_role
with check ( bucket_id in ('product_images', 'app_assets') );

create policy "Allow update for service_role" on storage.objects for update to service_role
using ( bucket_id in ('product_images', 'app_assets') );

create policy "Allow delete for service_role" on storage.objects for delete to service_role
using ( bucket_id in ('product_images', 'app_assets') );

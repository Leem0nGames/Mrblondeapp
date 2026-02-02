-- 1. Cleanup and Reset
-- Drop existing objects in reverse order of creation.
-- ALWAYS use DROP ... CASCADE to handle dependencies automatically.

drop view if exists public.dashboard_stats cascade;
drop view if exists public.agreements_with_counts cascade;
drop function if exists public.get_client_stats(uuid) cascade;
drop function if exists public.get_notification_counts() cascade;
drop function if exists public.increment_total_revenue(double precision) cascade;
drop table if exists public.app_settings cascade;
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreements cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.products cascade;
drop type if exists public.client_status_enum cascade;
drop type if exists public.client_type_enum cascade;
drop type if exists public.order_status_enum cascade;
drop type if exists public.promotion_type_enum cascade;
drop type if exists public.sales_condition_type_enum cascade;


-- 2. Create Types (Enums)
create type public.client_status_enum as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.client_type_enum as enum ('barberia', 'distribuidor', 'especial');
create type public.order_status_enum as enum ('pending', 'completed');
create type public.promotion_type_enum as enum ('buy_x_get_y_free', 'free_shipping', 'min_amount_discount');
create type public.sales_condition_type_enum as enum ('net_days', 'discount', 'installments', 'split_payment', 'cash_on_delivery');


-- 3. Create Tables
create table public.products (
    id uuid not null default gen_random_uuid(),
    name text not null,
    description text null,
    category text null,
    image_url text null,
    created_at timestamp with time zone not null default now(),
    constraint products_pkey primary key (id)
);

create table public.price_lists (
    id uuid not null default gen_random_uuid(),
    name text not null,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now(),
    base_price_list_id uuid null,
    discount_percentage double precision null,
    constraint price_lists_pkey primary key (id),
    constraint price_lists_name_key unique (name),
    constraint price_lists_base_price_list_id_fkey foreign key (base_price_list_id) references public.price_lists(id) on delete set null
);

create table public.price_list_items (
    price_list_id uuid not null,
    product_id uuid not null,
    price double precision not null,
    volume_price double precision null,
    constraint price_list_items_pkey primary key (price_list_id, product_id),
    constraint price_list_items_price_list_id_fkey foreign key (price_list_id) references public.price_lists(id) on delete cascade,
    constraint price_list_items_product_id_fkey foreign key (product_id) references public.products(id) on delete cascade
);

create table public.agreements (
    id uuid not null default gen_random_uuid(),
    agreement_name text not null,
    client_type public.client_type_enum not null,
    created_at timestamp with time zone not null default now(),
    price_list_id uuid null,
    constraint agreements_pkey primary key (id),
    constraint agreements_agreement_name_key unique (agreement_name),
    constraint agreements_price_list_id_fkey foreign key (price_list_id) references public.price_lists(id) on delete set null
);

create table public.clients (
    id uuid not null default gen_random_uuid(),
    cuit text null,
    contact_name text null,
    contact_dni text null,
    address text null,
    latitude double precision null,
    longitude double precision null,
    delivery_window text null,
    email text null,
    instagram text null,
    status public.client_status_enum not null,
    onboarding_token text null,
    agreement_id uuid null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text null,
    constraint clients_pkey primary key (id),
    constraint clients_cuit_key unique (cuit),
    constraint clients_email_key unique (email),
    constraint clients_onboarding_token_key unique (onboarding_token),
    constraint clients_agreement_id_fkey foreign key (agreement_id) references public.agreements(id) on delete set null
);

create table public.promotions (
    id uuid not null default gen_random_uuid(),
    name text not null,
    description text null,
    rules jsonb null,
    created_at timestamp with time zone not null default now(),
    constraint promotions_pkey primary key (id)
);

create table public.sales_conditions (
    id uuid not null default gen_random_uuid(),
    name text not null,
    description text null,
    rules jsonb null,
    created_at timestamp with time zone not null default now(),
    constraint sales_conditions_pkey primary key (id)
);

create table public.agreement_promotions (
    agreement_id uuid not null,
    promotion_id uuid not null,
    constraint agreement_promotions_pkey primary key (agreement_id, promotion_id),
    constraint agreement_promotions_agreement_id_fkey foreign key (agreement_id) references public.agreements(id) on delete cascade,
    constraint agreement_promotions_promotion_id_fkey foreign key (promotion_id) references public.promotions(id) on delete cascade
);

create table public.agreement_sales_conditions (
    agreement_id uuid not null,
    sales_condition_id uuid not null,
    constraint agreement_sales_conditions_pkey primary key (agreement_id, sales_condition_id),
    constraint agreement_sales_conditions_agreement_id_fkey foreign key (agreement_id) references public.agreements(id) on delete cascade,
    constraint agreement_sales_conditions_sales_condition_id_fkey foreign key (sales_condition_id) references public.sales_conditions(id) on delete cascade
);

create table public.orders (
    id uuid not null default gen_random_uuid(),
    client_id uuid not null,
    agreement_id uuid not null,
    created_at timestamp with time zone not null default now(),
    total_amount double precision not null,
    status public.order_status_enum not null,
    client_name_cache text not null,
    notes text null,
    constraint orders_pkey primary key (id),
    constraint orders_agreement_id_fkey foreign key (agreement_id) references public.agreements(id) on delete restrict,
    constraint orders_client_id_fkey foreign key (client_id) references public.clients(id) on delete restrict
);

create table public.order_items (
    id uuid not null default gen_random_uuid(),
    order_id uuid not null,
    product_id uuid not null,
    quantity integer not null,
    price_per_unit double precision not null,
    constraint order_items_pkey primary key (id),
    constraint order_items_order_id_fkey foreign key (order_id) references public.orders(id) on delete cascade,
    constraint order_items_product_id_fkey foreign key (product_id) references public.products(id) on delete restrict
);

create table public.app_settings (
    key text not null,
    value text null,
    constraint app_settings_pkey primary key (key)
);

-- 4. Create Views
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions where agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions where agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

create or replace view public.dashboard_stats as
select
    (select coalesce(sum(o.total_amount), (0)::double precision) from public.orders o where o.status = 'completed') as total_revenue,
    (select coalesce(sum(o.total_amount), (0)::double precision) from public.orders o where o.status = 'completed' and o.created_at >= date_trunc('month'::text, now())) as month_revenue,
    (select count(*) from public.clients c where c.status = 'active') as active_clients,
    (select count(*) from public.orders o where o.status = 'pending' and o.created_at < (now() - '3 days'::interval)) as overdue_orders_count,
    (select count(*) from public.clients c where c.status in ('active', 'pending_agreement', 'pending_onboarding')) as total_clients,
    (select count(*) from public.price_lists) as total_pricelists,
    (select count(*) from public.promotions) as total_promotions,
    (select count(*) from public.sales_conditions) as total_sales_conditions;


-- 5. Create Functions
create or replace function public.get_notification_counts()
returns table(pending_orders_count bigint, pending_clients_count bigint, overdue_orders_count bigint)
language sql
as $$
  select
    (select count(*) from public.orders where status = 'pending') as pending_orders_count,
    (select count(*) from public.clients where status = 'pending_agreement') as pending_clients_count,
    (select count(*) from public.orders where status = 'pending' and created_at < (now() - '3 days'::interval)) as overdue_orders_count;
$$;

create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent double precision, average_order_value double precision, total_orders bigint)
language sql
as $$
    select
        coalesce(sum(total_amount), 0) as total_spent,
        coalesce(avg(total_amount), 0) as average_order_value,
        count(*) as total_orders
    from public.orders
    where client_id = p_client_id and status = 'completed';
$$;

create or replace function public.increment_total_revenue(amount_to_add double precision)
returns void
language plpgsql
as $$
begin
  -- This is a placeholder for a more robust stats update mechanism.
  -- For this MVP, we acknowledge it exists but don't implement a complex materialized view.
end;
$$;


-- 6. Enable Row-Level Security (RLS)
alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.agreements enable row level security;
alter table public.clients enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.app_settings enable row level security;


-- 7. Create RLS Policies
-- Admin policies (full access)
create policy "Allow all for service_role" on public.products for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.price_lists for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.price_list_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreements for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.clients for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreement_promotions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.agreement_sales_conditions for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.orders for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.order_items for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "Allow all for service_role" on public.app_settings for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- Public/Anonymous policies
create policy "Allow anon read on app_settings" on public.app_settings for select using (true);
create policy "Allow anon read on agreements" on public.agreements for select using (true);
create policy "Allow anon read on agreement_promotions" on public.agreement_promotions for select using (true);
create policy "Allow anon read on promotions" on public.promotions for select using (true);
create policy "Allow anon read on price_lists" on public.price_lists for select using (true);
create policy "Allow anon read on price_list_items" on public.price_list_items for select using (true);
create policy "Allow anon read on products" on public.products for select using (true);
create policy "Allow anon read on clients" on public.clients for select using (true);
create policy "Allow anon insert on orders" on public.orders for insert with check (true);
create policy "Allow anon insert on order_items" on public.order_items for insert with check (true);
create policy "Allow anon update on clients for onboarding" on public.clients for update using (onboarding_token is not null) with check (onboarding_token is not null);


-- 8. Storage Policies
create policy "Allow public read on app_assets" on storage.objects for select
  using (bucket_id = 'app_assets');

create policy "Allow service_role full access on app_assets" on storage.objects for all
  using (bucket_id = 'app_assets' and auth.role() = 'service_role')
  with check (bucket_id = 'app_assets' and auth.role() = 'service_role');

create policy "Allow public read on product_images" on storage.objects for select
  using (bucket_id = 'product_images');

create policy "Allow service_role full access on product_images" on storage.objects for all
  using (bucket_id = 'product_images' and auth.role() = 'service_role')
  with check (bucket_id = 'product_images' and auth.role() = 'service_role');

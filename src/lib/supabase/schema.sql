
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓                           SCHEMA CLEANUP & RESET                                 ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Drop policies for storage.objects
drop policy if exists "Allow authenticated users to read product images" on storage.objects;
drop policy if exists "Allow authenticated users to update product images" on storage.objects;

-- Drop existing tables in reverse order of dependency
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.price_lists;
drop table if exists public.products;
drop table if exists public.revenue_stats;

-- Drop existing types
drop type if exists public.client_status;
drop type if exists public.order_status;
drop type if exists public.client_type;

-- Drop existing functions to avoid conflicts
drop function if exists public.get_client_stats(uuid);
drop function if exists public.get_overdue_orders();
drop function if exists public.increment_total_revenue(double precision);

-- Drop views
drop view if exists public.dashboard_stats;
drop view if exists public.agreements_with_counts;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓                                 CUSTOM TYPES                                     ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.order_status as enum ('pending', 'completed');
create type public.client_type as enum ('barberia', 'distribuidor', 'especial');


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓                                     TABLES                                       ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Products Table
create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.products enable row level security;

-- Price Lists Table
create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.price_lists enable row level security;

-- Price List Items Table (Junction table for Products and Price Lists)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null check (price >= 0),
    volume_price numeric(10, 2) check (volume_price >= 0),
    primary key (price_list_id, product_id)
);
alter table public.price_list_items enable row level security;

-- Agreements Table
create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null unique,
    client_type client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.agreements enable row level security;

-- Clients Table
create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    fiscal_status text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status client_status default 'pending_onboarding' not null,
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.clients enable row level security;

-- Promotions Table
create table public.promotions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.promotions enable row level security;

-- Agreement Promotions (Junction table for Agreements and Promotions)
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
alter table public.agreement_promotions enable row level security;

-- Sales Conditions Table
create table public.sales_conditions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.sales_conditions enable row level security;

-- Agreement Sales Conditions (Junction table for Agreements and Sales Conditions)
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table public.agreement_sales_conditions enable row level security;


-- Orders Table
create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount numeric(10, 2) not null check (total_amount >= 0),
    status order_status default 'pending' not null,
    client_name_cache text not null,
    notes text
);
alter table public.orders enable row level security;

-- Order Items Table
create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null check (quantity > 0),
    price_per_unit numeric(10, 2) not null check (price_per_unit >= 0)
);
alter table public.order_items enable row level security;

-- Table for tracking key revenue stats to avoid expensive queries
create table public.revenue_stats (
    id int primary key default 1,
    total_revenue numeric(15, 2) default 0.00 not null,
    month_revenue numeric(15, 2) default 0.00 not null,
    active_clients int default 0 not null,
    constraint only_one_row check (id = 1)
);
alter table public.revenue_stats enable row level security;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓                                     VIEWS                                        ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- View to get dashboard stats
create or replace view public.dashboard_stats as
select
    rs.total_revenue,
    rs.month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients
from public.revenue_stats rs
where rs.id = 1;

-- View to get agreement counts for easier display
create or replace view public.agreements_with_counts as
select
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    pl.name as price_list_name,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc where asc.agreement_id = a.id) as sales_condition_count
from
    public.agreements a
left join
    public.price_lists pl on a.price_list_id = pl.id;

-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓                                    FUNCTIONS                                     ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Function to get stats for a single client
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

-- Function to get overdue orders based on sales conditions
create or replace function public.get_overdue_orders()
returns setof public.orders
language plpgsql
as $$
begin
  return query
  select o.*
  from public.orders o
  join public.agreement_sales_conditions asc on o.agreement_id = asc.agreement_id
  join public.sales_conditions sc on asc.sales_condition_id = sc.id
  where o.status = 'pending'
    and sc.rules->>'type' = 'net_days'
    and o.created_at < (now() - ( (sc.rules->>'days')::int * interval '1 day' ));
end;
$$;


-- Function to increment total revenue
create or replace function public.increment_total_revenue(amount_to_add double precision)
returns void
language plpgsql
as $$
begin
    update public.revenue_stats
    set total_revenue = total_revenue + amount_to_add
    where id = 1;
end;
$$;

-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓                         ROW LEVEL SECURITY (RLS) POLICIES                          ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Policies for Products
create policy "Allow all access to authenticated users" on public.products for all to authenticated using (true) with check (true);

-- Policies for Price Lists
create policy "Allow all access to authenticated users" on public.price_lists for all to authenticated using (true) with check (true);
create policy "Allow all access to authenticated users" on public.price_list_items for all to authenticated using (true) with check (true);

-- Policies for Agreements
create policy "Allow all access to authenticated users" on public.agreements for all to authenticated using (true) with check (true);

-- Policies for Clients
create policy "Allow all access to authenticated users" on public.clients for all to authenticated using (true) with check (true);
create policy "Allow public read access to onboarding clients" on public.clients for select to public using (status = 'pending_onboarding' or status = 'active');

-- Policies for Promotions
create policy "Allow all access to authenticated users" on public.promotions for all to authenticated using (true) with check (true);
create policy "Allow all access to authenticated users" on public.agreement_promotions for all to authenticated using (true) with check (true);

-- Policies for Sales Conditions
create policy "Allow all access to authenticated users" on public.sales_conditions for all to authenticated using (true) with check (true);
create policy "Allow all access to authenticated users" on public.agreement_sales_conditions for all to authenticated using (true) with check (true);

-- Policies for Orders
create policy "Allow authenticated users to manage orders" on public.orders for all to authenticated using (true) with check (true);
create policy "Allow all access to authenticated users" on public.order_items for all to authenticated using (true) with check (true);

-- Policies for Revenue Stats
create policy "Allow authenticated users read access" on public.revenue_stats for select to authenticated using (true);


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                                  ▓
-- ▓                              STORAGE POLICIES                                    ▓
-- ▓                                                                                  ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Create the bucket for product images if it doesn't exist
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Policies for product_images bucket
create policy "Allow authenticated users to read product images"
on storage.objects for select
to public
using (bucket_id = 'product_images');

create policy "Allow authenticated users to insert product images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'product_images');

create policy "Allow authenticated users to update product images"
on storage.objects for update
to authenticated
using (bucket_id = 'product_images');

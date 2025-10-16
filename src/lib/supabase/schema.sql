-- -----------------------------------------------------------------------------------------------
--  Idempotent script for setting up the Supabase schema for Blonde Orders
--
--  This script is designed to be run safely multiple times. It will:
--  1. Drop dependent views and functions first.
--  2. Drop tables with CASCADE to remove dependencies.
--  3. Drop types.
--  4. Re-create everything from scratch.
-- -----------------------------------------------------------------------------------------------

-- --- 1. Drop existing objects in reverse order of dependency ---

-- Drop views that depend on tables
drop view if exists public.dashboard_stats cascade;
drop view if exists public.agreements_with_counts cascade;

-- Drop functions
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.increment_total_revenue(amount_to_add real);

-- Drop tables
drop table if exists "public"."order_items" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."products" cascade;

-- Drop storage buckets (be careful with this in production if you want to keep data)
-- For a clean dev setup, this is useful.
-- Note: Dropping buckets requires extra privileges. This might fail if the user doesn't have them.
-- We will handle bucket and policy creation idempotently to avoid issues.

-- Drop policies if they exist
drop policy if exists "Allow public read access to product images" on storage.objects;

-- --- 2. Re-create the schema ---

-- Enable UUID extension
create extension if not exists "uuid-ossp" with schema extensions;

-- PRODUCTS table
create table "public"."products" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text null,
  category text null,
  image_url text null,
  created_at timestamp with time zone not null default now()
);
alter table "public"."products" enable row level security;

-- PROMOTIONS table
create table "public"."promotions" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text null,
  rules jsonb not null,
  created_at timestamp with time zone not null default now()
);
alter table "public"."promotions" enable row level security;

-- SALES_CONDITIONS table
create table "public"."sales_conditions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text null,
    rules jsonb not null,
    created_at timestamp with time zone not null default now()
);
alter table "public"."sales_conditions" enable row level security;

-- PRICE_LISTS table
create table "public"."price_lists" (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);
alter table "public"."price_lists" enable row level security;

-- PRICE_LIST_ITEMS table (join table for price_lists and products)
create table "public"."price_list_items" (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null,
    volume_price real null,
    primary key (price_list_id, product_id)
);
alter table "public"."price_list_items" enable row level security;

-- AGREEMENTS table
create table "public"."agreements" (
  id uuid primary key default uuid_generate_v4(),
  agreement_name text not null unique,
  client_type text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
  price_list_id uuid null references public.price_lists(id) on delete set null,
  created_at timestamp with time zone not null default now()
);
alter table "public"."agreements" enable row level security;


-- CLIENTS table
create table "public"."clients" (
    id uuid primary key default uuid_generate_v4(),
    cuit text null unique,
    contact_name text null,
    contact_dni text null,
    address text null,
    delivery_window text null,
    email text null unique,
    instagram text null,
    status text not null default 'pending_onboarding'::text check (status in ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    onboarding_token uuid not null unique,
    agreement_id uuid null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text null,
    constraint clients_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete set null,
    constraint clients_agreement_id_unique unique (agreement_id)
);
alter table "public"."clients" enable row level security;

-- AGREEMENT_PROMOTIONS table (join table)
create table "public"."agreement_promotions" (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);
alter table "public"."agreement_promotions" enable row level security;

-- AGREEMENT_SALES_CONDITIONS table (join table)
create table "public"."agreement_sales_conditions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table "public"."agreement_sales_conditions" enable row level security;

-- ORDERS table
create table "public"."orders" (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone not null default now(),
    total_amount real not null,
    status text not null default 'pending'::text check (status in ('pending', 'completed')),
    client_name_cache text not null
);
alter table "public"."orders" enable row level security;

-- ORDER_ITEMS table
create table "public"."order_items" (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit real not null
);
alter table "public"."order_items" enable row level security;

-- --- 3. Create Views ---

-- View for agreement counts
create view public.agreements_with_counts as
select
  a.id,
  a.agreement_name,
  a.client_type,
  a.price_list_id,
  a.created_at,
  pl.name as price_list_name,
  (select count(*) from agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from agreement_sales_conditions as asc_count where asc_count.agreement_id = a.id) as sales_condition_count,
  a.price_lists
from
  agreements a
left join
    price_lists pl on a.price_list_id = pl.id;


-- View for dashboard stats
create view public.dashboard_stats as
select
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients;


-- --- 4. Create Functions ---

create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent real, average_order_value real, total_orders bigint)
language plpgsql
as $$
begin
  return query
  select
    coalesce(sum(o.total_amount), 0.0)::real as total_spent,
    coalesce(avg(o.total_amount), 0.0)::real as average_order_value,
    count(o.id) as total_orders
  from
    public.orders o
  where
    o.client_id = p_client_id and o.status = 'completed';
end;
$$;


create or replace function public.increment_total_revenue(amount_to_add real)
returns void
language plpgsql
as $$
begin
  -- This function is a placeholder for a more complex revenue tracking system.
  -- In a real scenario, this might update a running totals table.
  -- For now, the dashboard_stats view calculates this dynamically.
end;
$$;


-- --- 5. Set up Storage and Policies ---

-- Create a bucket for product images if it doesn't exist.
-- The `true` at the end makes it public.
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do update set public = true;


-- Create policy for public read access on product_images bucket
create policy "Allow public read access to product images"
on storage.objects for select
to public
using (bucket_id = 'product_images');

-- Create policy for authenticated users to upload/update/delete their own images
-- This is a more secure setup, assuming you have a mapping between users and products.
-- For this MVP, we are allowing any authenticated user to manage images.
create policy "Allow authenticated users to manage images"
on storage.objects for insert, update, delete
to authenticated
with check (bucket_id = 'product_images');


-- --- 6. Set up RLS (Row Level Security) Policies ---

-- Products: Publicly readable
create policy "Allow public read access to products" on public.products for select using (true);
create policy "Allow admin users to manage products" on public.products for all using (auth.role() = 'service_role');

-- Promotions: Admin-only
create policy "Allow admin users to manage promotions" on public.promotions for all using (auth.role() = 'service_role');

-- Sales Conditions: Admin-only
create policy "Allow admin users to manage sales conditions" on public.sales_conditions for all using (auth.role() = 'service_role');

-- Price Lists: Admin-only
create policy "Allow admin users to manage price lists" on public.price_lists for all using (auth.role() = 'service_role');
create policy "Allow public read for price lists" on public.price_lists for select using (true);

-- Price List Items: Admin-only for management, public read
create policy "Allow admin users to manage price list items" on public.price_list_items for all using (auth.role() = 'service_role');
create policy "Allow public read for price list items" on public.price_list_items for select using (true);

-- Agreements: Admin-only for management, public read
create policy "Allow admin users to manage agreements" on public.agreements for all using (auth.role() = 'service_role');
create policy "Allow public read for agreements" on public.agreements for select using (true);


-- Agreement Promotions: Admin-only for management, public read
create policy "Allow admin users to manage agreement promotions" on public.agreement_promotions for all using (auth.role() = 'service_role');
create policy "Allow public read for agreement promotions" on public.agreement_promotions for select using (true);

-- Agreement Sales Conditions: Admin-only for management, public read
create policy "Allow admin users to manage agreement sales conditions" on public.agreement_sales_conditions for all using (auth.role() = 'service_role');
create policy "Allow public read for agreement sales conditions" on public.agreement_sales_conditions for select using (true);


-- Clients: Admin-only for management, public read for onboarding
create policy "Allow admin users to manage clients" on public.clients for all using (auth.role() = 'service_role');
create policy "Allow public read for client onboarding" on public.clients for select using (true);

-- Orders: Admin-only for management, public write for creation
create policy "Allow admin users to manage orders" on public.orders for all using (auth.role() = 'service_role');
create policy "Allow anonymous users to create orders" on public.orders for insert with check (true);

-- Order Items: Admin-only for management, public write for creation
create policy "Allow admin users to manage order items" on public.order_items for all using (auth.role() = 'service_role');
create policy "Allow anonymous users to create order items" on public.order_items for insert with check (true);

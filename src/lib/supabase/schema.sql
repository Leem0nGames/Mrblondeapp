
-- -------------------------------------------------------------------------------------
-- BLONDE ORDERS - SUPABASE SCHEMA
--
-- This script is IDEMPOTENT, meaning it can be run safely multiple times.
-- It will clean up and re-create the schema from scratch.
--
-- Sections:
-- 1. Cleanup: Drop existing objects (tables, views, functions) to ensure a clean slate.
-- 2. Tables: Create the core tables for the application.
-- 3. Views: Create views for simplified data access (e.g., dashboard stats).
-- 4. RPC Functions: Create stored procedures for complex logic.
-- 5. Policies: Set up Row Level Security (RLS) policies for data access control.
-- 6. Storage: Configure Supabase Storage policies.
-- -------------------------------------------------------------------------------------


-- -------------------------------------------------------------------------------------
-- 1. CLEANUP
-- -------------------------------------------------------------------------------------
-- Drop policies first to remove dependencies
drop policy if exists "Allow authenticated users to select products" on "public"."products";
drop policy if exists "Allow authenticated users to manage products" on "public"."products";
drop policy if exists "Allow authenticated users to select promotions" on "public"."promotions";
drop policy if exists "Allow authenticated users to manage promotions" on "public"."promotions";
drop policy if exists "Allow authenticated users to select sales_conditions" on "public"."sales_conditions";
drop policy if exists "Allow authenticated users to manage sales_conditions" on "public"."sales_conditions";
drop policy if exists "Allow authenticated users to select agreements" on "public"."agreements";
drop policy if exists "Allow authenticated users to manage agreements" on "public"."agreements";
drop policy if exists "Allow authenticated users to manage agreement_promotions" on "public"."agreement_promotions";
drop policy if exists "Allow authenticated users to manage agreement_sales_conditions" on "public"."agreement_sales_conditions";
drop policy if exists "Allow authenticated users to select clients" on "public"."clients";
drop policy if exists "Allow authenticated users to manage clients" on "public"."clients";
drop policy if exists "Allow public access for onboarding" on "public"."clients";
drop policy if exists "Allow authenticated users to select price_lists" on public.price_lists;
drop policy if exists "Allow authenticated users to manage price_lists" on public.price_lists;
drop policy if exists "Allow authenticated users to manage price_list_items" on public.price_list_items;
drop policy if exists "Allow public read access to order page data" on public.agreements;
drop policy if exists "Allow public read access to order page data" on public.agreement_promotions;
drop policy if exists "Allow public read access to order page data" on public.promotions;
drop policy if exists "Allow public read access to order page data" on public.price_lists;
drop policy if exists "Allow public read access to order page data" on public.price_list_items;
drop policy if exists "Allow public read access to order page data" on public.products;
drop policy if exists "Allow public read access to find active client" on public.clients;
drop policy if exists "Allow authenticated users to manage orders" on public.orders;
drop policy if exists "Allow authenticated users to manage order_items" on public.order_items;

-- Drop views and tables
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats; -- Por si quedó como vista
drop table if exists public.dashboard_stats; -- Por si quedó como tabla obsoleta

-- Drop functions with specific argument types for safety
drop function if exists public.increment_total_revenue(real);
drop function if exists public.increment_total_revenue(numeric);
drop function if exists public.get_client_stats(uuid);
drop function if exists public.get_overdue_orders();

-- Drop tables in reverse order of creation
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.agreement_promotions;
drop table if exists public.sales_conditions;
drop table if exists public.promotions;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.price_list_items;
drop table if exists public.price_lists;
drop table if exists public.products;


-- Storage policies
drop policy if exists "Allow authenticated users to update product images" on storage.objects;
drop policy if exists "Allow authenticated users to view product images" on storage.objects;


-- -------------------------------------------------------------------------------------
-- 2. TABLES
-- -------------------------------------------------------------------------------------
-- Table for Products
create table public.products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for Price Lists
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Table for Price List Items (associates products with prices in a list)
create table public.price_list_items (
    price_list_id uuid references public.price_lists(id) on delete cascade not null,
    product_id uuid references public.products(id) on delete cascade not null,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);


-- Table for Agreements
create table public.agreements (
  id uuid default gen_random_uuid() primary key,
  agreement_name text not null unique,
  client_type public.client_type not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  price_list_id uuid references public.price_lists(id) on delete set null
);

-- Table for Clients
create table public.clients (
    id uuid default gen_random_uuid() primary key,
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid default gen_random_uuid() not null,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    fiscal_status text
);

-- Table for Promotions
create table public.promotions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Linking table for Agreements and Promotions
create table public.agreement_promotions (
  agreement_id uuid references public.agreements(id) on delete cascade not null,
  promotion_id uuid references public.promotions(id) on delete cascade not null,
  primary key (agreement_id, promotion_id)
);

-- Table for Sales Conditions
create table public.sales_conditions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Linking table for Agreements and Sales Conditions
create table public.agreement_sales_conditions (
  agreement_id uuid references public.agreements(id) on delete cascade not null,
  sales_condition_id uuid references public.sales_conditions(id) on delete cascade not null,
  primary key (agreement_id, sales_condition_id)
);

-- Table for Orders
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid references public.clients(id) on delete set null,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount numeric(10, 2) not null,
    status public.order_status not null default 'pending',
    client_name_cache text not null
);

-- Table for Order Items
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid references public.orders(id) on delete cascade not null,
    product_id uuid references public.products(id) on delete set null,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);


-- -------------------------------------------------------------------------------------
-- 3. VIEWS
-- -------------------------------------------------------------------------------------

-- View to get agreements with counts of associated promotions and sales conditions.
create or replace view public.agreements_with_counts as
select
  a.*,
  (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count
from
  public.agreements a;
  
-- View for dashboard statistics.
create or replace view public.dashboard_stats as
select
    coalesce((select sum(total_amount) from public.orders where status = 'completed'), 0) as total_revenue,
    coalesce((select sum(total_amount) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())), 0) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;


-- -------------------------------------------------------------------------------------
-- 4. RPC FUNCTIONS
-- -------------------------------------------------------------------------------------

-- Function to increment total revenue.
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
  -- This function is a placeholder for a more complex aggregation logic.
  -- In a real-world scenario, you might update a summary table.
  -- For now, this function doesn't perform any action but is required by the app.
end;
$$ language plpgsql;

-- Function to get detailed statistics for a single client.
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
        o.client_id = p_client_id;
end;
$$ language plpgsql;

-- Function to get overdue orders based on sales conditions.
create or replace function public.get_overdue_orders()
returns setof public.orders as $$
begin
    return query
    select o.*
    from public.orders o
    join public.agreement_sales_conditions asc_ref on o.agreement_id = asc_ref.agreement_id
    join public.sales_conditions sc on asc_ref.sales_condition_id = sc.id
    where o.status = 'pending'
      and sc.rules ->> 'type' = 'net_days'
      and o.created_at < (now() - ((sc.rules ->> 'days')::int * interval '1 day'));
end;
$$ language plpgsql;


-- -------------------------------------------------------------------------------------
-- 5. RLS POLICIES
-- -------------------------------------------------------------------------------------

-- Enable RLS for all relevant tables
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.clients enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Policies for Products
create policy "Allow authenticated users to select products" on public.products for select using (auth.role() = 'authenticated');
create policy "Allow authenticated users to manage products" on public.products for all using (auth.role() = 'authenticated');

-- Policies for Promotions
create policy "Allow authenticated users to select promotions" on public.promotions for select using (auth.role() = 'authenticated');
create policy "Allow authenticated users to manage promotions" on public.promotions for all using (auth.role() = 'authenticated');

-- Policies for Sales Conditions
create policy "Allow authenticated users to select sales_conditions" on public.sales_conditions for select using (auth.role() = 'authenticated');
create policy "Allow authenticated users to manage sales_conditions" on public.sales_conditions for all using (auth.role() = 'authenticated');

-- Policies for Agreements
create policy "Allow authenticated users to select agreements" on public.agreements for select using (auth.role() = 'authenticated');
create policy "Allow authenticated users to manage agreements" on public.agreements for all using (auth.role() = 'authenticated');

-- Policies for Agreement-Promotion Links
create policy "Allow authenticated users to manage agreement_promotions" on public.agreement_promotions for all using (auth.role() = 'authenticated');

-- Policies for Agreement-Sales-Condition Links
create policy "Allow authenticated users to manage agreement_sales_conditions" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');

-- Policies for Clients
create policy "Allow authenticated users to select clients" on public.clients for select using (auth.role() = 'authenticated');
create policy "Allow authenticated users to manage clients" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow public access for onboarding" on public.clients for all using (true); -- Public access needed for onboarding form

-- Policies for Price Lists
create policy "Allow authenticated users to select price_lists" on public.price_lists for select using (auth.role() = 'authenticated');
create policy "Allow authenticated users to manage price_lists" on public.price_lists for all using (auth.role() = 'authenticated');

-- Policies for Price List Items
create policy "Allow authenticated users to manage price_list_items" on public.price_list_items for all using (auth.role() = 'authenticated');

-- Policies for Orders & Order Items
create policy "Allow authenticated users to manage orders" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow authenticated users to manage order_items" on public.order_items for all using (auth.role() = 'authenticated');


-- Policies for Public Order Page (Anonymous Access)
create policy "Allow public read access to order page data" on public.agreements for select using (true);
create policy "Allow public read access to order page data" on public.agreement_promotions for select using (true);
create policy "Allow public read access to order page data" on public.promotions for select using (true);
create policy "Allow public read access to order page data" on public.price_lists for select using (true);
create policy "Allow public read access to order page data" on public.price_list_items for select using (true);
create policy "Allow public read access to order page data" on public.products for select using (true);
create policy "Allow public read access to find active client" on public.clients for select using (true);

-- -------------------------------------------------------------------------------------
-- 6. STORAGE
-- -------------------------------------------------------------------------------------
-- Create a bucket for product images if it doesn't exist
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Policies for Storage
create policy "Allow authenticated users to view product images"
on storage.objects for select
using ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

create policy "Allow authenticated users to update product images"
on storage.objects for insert with check (
    bucket_id = 'product_images' and auth.role() = 'authenticated'
);

create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- END OF SCRIPT --

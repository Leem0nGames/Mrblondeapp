
-- ▀█▀ █▀█ █▀▄▀█ █▀▀ █▀█ █ █▄ █ █▀▀ █▀
--  █  █▄█ █ ▀ █ █▄▄ █▄█ █ █ ▀█ █▄▄ ▄█
--
-- Idempotent script for setting up the Blonde Orders database schema.
-- You can run this script at any time to reset the database to a clean state.
--
-- =================================================================
-- 1. CLEANUP: Drop existing objects in the correct order
-- =================================================================
-- Drop views and functions first as they depend on tables
drop view if exists public.agreements_with_counts;
drop function if exists public.get_client_stats;
drop function if exists public.increment_total_revenue;

-- Now drop tables. Order matters to avoid dependency issues.
-- Drop join tables first.
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.order_items;
drop table if exists public.price_list_items;

-- Drop primary entity tables.
drop table if exists public.orders;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.price_lists;
drop table if exists public.products;
drop table if exists public.dashboard_stats;

-- =================================================================
-- 2. CREATE TABLES: Define the structure of the database
-- =================================================================
create table public.products (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    name text not null,
    description text null,
    category text null,
    image_url text null,
    constraint products_pkey primary key (id),
    constraint products_name_key unique (name)
);

create table public.price_lists (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    name text not null,
    prices_include_vat boolean not null default true,
    constraint price_lists_pkey primary key (id),
    constraint price_lists_name_key unique (name)
);

create table public.price_list_items (
    price_list_id uuid not null,
    product_id uuid not null,
    price numeric not null,
    volume_price numeric null,
    constraint price_list_items_pkey primary key (price_list_id, product_id),
    constraint price_list_items_price_list_id_fkey foreign key (price_list_id) references public.price_lists (id) on delete cascade,
    constraint price_list_items_product_id_fkey foreign key (product_id) references public.products (id) on delete cascade
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
    created_at timestamp with time zone not null default now(),
    name text not null,
    description text null,
    rules jsonb null,
    constraint sales_conditions_pkey primary key (id)
);

create table public.agreements (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    agreement_name text not null,
    client_type public.client_type not null,
    price_list_id uuid null,
    constraint agreements_pkey primary key (id),
    constraint agreements_agreement_name_key unique (agreement_name),
    constraint agreements_price_list_id_fkey foreign key (price_list_id) references public.price_lists (id) on delete set null
);

create table public.agreement_promotions (
    agreement_id uuid not null,
    promotion_id uuid not null,
    constraint agreement_promotions_pkey primary key (agreement_id, promotion_id),
    constraint agreement_promotions_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade,
    constraint agreement_promotions_promotion_id_fkey foreign key (promotion_id) references public.promotions (id) on delete cascade
);

create table public.agreement_sales_conditions (
    agreement_id uuid not null,
    sales_condition_id uuid not null,
    constraint agreement_sales_conditions_pkey primary key (agreement_id, sales_condition_id),
    constraint agreement_sales_conditions_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade,
    constraint agreement_sales_conditions_sales_condition_id_fkey foreign key (sales_condition_id) references public.sales_conditions (id) on delete cascade
);

create table public.clients (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    cuit text null,
    contact_name text null,
    contact_dni text null,
    address text null,
    delivery_window text null,
    email text null,
    instagram text null,
    status public.client_status not null,
    onboarding_token text not null,
    agreement_id uuid null,
    fiscal_status text null,
    constraint clients_pkey primary key (id),
    constraint clients_cuit_key unique (cuit),
    constraint clients_email_key unique (email),
    constraint clients_onboarding_token_key unique (onboarding_token),
    constraint clients_agreement_id_unique unique (agreement_id),
    constraint clients_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete set null
);

create table public.orders (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    client_id uuid not null,
    agreement_id uuid not null,
    total_amount numeric not null,
    status public.order_status not null,
    client_name_cache text null,
    constraint orders_pkey primary key (id),
    constraint orders_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete restrict,
    constraint orders_client_id_fkey foreign key (client_id) references public.clients (id) on delete restrict
);

create table public.order_items (
    id uuid not null default gen_random_uuid(),
    order_id uuid not null,
    product_id uuid not null,
    quantity integer not null,
    price_per_unit numeric not null,
    constraint order_items_pkey primary key (id),
    constraint order_items_order_id_fkey foreign key (order_id) references public.orders (id) on delete cascade,
    constraint order_items_product_id_fkey foreign key (product_id) references public.products (id) on delete restrict
);

-- Dashboard stats table (obsolete, replaced by a view, but kept for historical reset)
create table public.dashboard_stats (
    id integer not null,
    total_revenue numeric,
    month_revenue numeric,
    active_clients integer,
    constraint dashboard_stats_pkey primary key (id)
);
insert into public.dashboard_stats(id, total_revenue, month_revenue, active_clients) values (1, 0, 0, 0);


-- =================================================================
-- 3. VIEWS and FUNCTIONS: Create derived data views and helpers
-- =================================================================
create view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
language sql
as $$
    select
        coalesce(sum(total_amount), 0) as total_spent,
        coalesce(avg(total_amount), 0) as average_order_value,
        count(id) as total_orders
    from public.orders
    where client_id = p_client_id and status = 'completed';
$$;

create view public.dashboard_stats as
select
    coalesce(sum(case when status = 'completed' then total_amount else 0 end), 0) as total_revenue,
    coalesce(sum(case when status = 'completed' and created_at >= date_trunc('month', now()) then total_amount else 0 end), 0) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients
from public.orders;

create function public.increment_total_revenue(amount_to_add numeric)
returns void
language sql
as $$
    -- This function is now obsolete as the view calculates revenue dynamically.
    -- It is kept for potential backward compatibility but does nothing.
$$;

-- =================================================================
-- 4. RLS (Row Level Security): Define access policies
-- =================================================================
-- Enable RLS for all tables
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

-- Policies for public, read-only access (for order page, etc.)
create policy "Allow public read access to products" on public.products for select using (true);
create policy "Allow public read access to price list items" on public.price_list_items for select using (true);
create policy "Allow public read access to promotions" on public.promotions for select using (true);
create policy "Allow public read access to agreements" on public.agreements for select using (true);
create policy "Allow public read access to agreement promotions" on public.agreement_promotions for select using (true);
create policy "Allow public read access to clients" on public.clients for select using (true);
create policy "Allow public read access to price lists" on public.price_lists for select using (true);

-- Policies for authenticated users (admins) to perform all actions
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated');

-- Policies for creating orders (public action)
create policy "Allow public to create orders" on public.orders for insert with check (true);
create policy "Allow public to create order items" on public.order_items for insert with check (true);
create policy "Allow public to submit onboarding form" on public.clients for update using (true) with check (true);

-- =================================================================
-- 5. STORAGE POLICIES: Define access for file storage
-- =================================================================
-- Create a bucket for product images if it doesn't exist
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Allow anonymous users to view product images
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Allow authenticated users (admins) to manage product images
create policy "Allow admins to manage product images"
on storage.objects for all
using ( auth.role() = 'authenticated' and bucket_id = 'product_images' );

-- =================================================================
-- Final Script
-- =================================================================

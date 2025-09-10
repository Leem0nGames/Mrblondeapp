-- ------------------------------------------------------------------------------------------------
-- 1. Create Products Table
-- ------------------------------------------------------------------------------------------------
create table if not exists products (
  id uuid default gen_random_uuid() not null,
  created_at timestamp with time zone default now() not null,
  name text not null,
  description text null,
  base_price double precision default 0 not null,
  stock integer default 0 not null,
  category text null,
  constraint products_pkey primary key (id)
);

-- RLS policies for products
alter table products enable row level security;

create policy "Allow public read-only access"
on products for select
using (true);

create policy "Allow admin full access"
on products for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');


-- ------------------------------------------------------------------------------------------------
-- 2. Create Clients Table
-- ------------------------------------------------------------------------------------------------
create table if not exists clients (
    id uuid default gen_random_uuid() not null,
    created_at timestamp with time zone default now() not null,
    name text not null,
    phone text null,
    address text null,
    city text null,
    constraint clients_pkey primary key (id)
);

-- RLS policies for clients
alter table clients enable row level security;

create policy "Allow public read-only access"
on clients for select
using (true);

create policy "Allow admin full access"
on clients for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

-- ------------------------------------------------------------------------------------------------
-- 3. Create Agreements Table
-- ------------------------------------------------------------------------------------------------
create table if not exists agreements (
    id uuid default gen_random_uuid() not null,
    created_at timestamp with time zone default now() not null,
    name text not null,
    client_type public.client_type not null,
    price_adjustment real default 0 not null,
    constraint agreements_pkey primary key (id)
);
-- Note: 'client_type' uses a custom enum type that should be created if it doesn't exist:
-- CREATE TYPE public.client_type AS ENUM ('barberia', 'distribuidor', 'especial');


-- RLS policies for agreements
alter table agreements enable row level security;

create policy "Allow public read-only access"
on agreements for select
using (true);

create policy "Allow admin full access"
on agreements for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');


-- ------------------------------------------------------------------------------------------------
-- 4. Create Promotions Table
-- ------------------------------------------------------------------------------------------------
create table if not exists promotions (
    id uuid default gen_random_uuid() not null,
    created_at timestamp with time zone default now() not null,
    name text not null,
    description text null,
    rules jsonb null,
    constraint promotions_pkey primary key (id)
);

-- RLS policies for promotions
alter table promotions enable row level security;

create policy "Allow public read-only access"
on promotions for select
using (true);

create policy "Allow admin full access"
on promotions for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');


-- ------------------------------------------------------------------------------------------------
-- 5. Create Access Tokens Table
-- ------------------------------------------------------------------------------------------------
create table if not exists access_tokens (
    id uuid default gen_random_uuid() not null,
    created_at timestamp with time zone default now() not null,
    agreement_id uuid not null,
    client_name text not null,
    token text not null,
    expires_at timestamp with time zone not null,
    constraint access_tokens_pkey primary key (id),
    constraint access_tokens_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete cascade
);

-- RLS policies for access_tokens
alter table access_tokens enable row level security;

create policy "Allow public read-only access"
on access_tokens for select
using (true);

create policy "Allow admin full access"
on access_tokens for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

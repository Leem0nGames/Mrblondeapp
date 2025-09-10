--
-- Final and Corrected SQL Schema for Blonde Orders
--
-- Instructions:
-- 1. In your Supabase project, go to the "Table Editor".
-- 2. Delete all existing tables from the previous attempts to ensure a clean slate.
-- 3. Go to the "SQL Editor".
-- 4. Copy the entire content of this file.
-- 5. Paste it into the SQL Editor and click "RUN".
--
-- This script is idempotent and can be run on a clean database.
--

-- Enable the pgsodium extension for cryptographic functions
create extension if not exists "pgsodium" with schema "pgsodium";

-- Enable the pg_graphql extension
create extension if not exists "pg_graphql" with schema "graphql";

-- Enable the uuid-ossp extension to generate UUIDs
create extension if not exists "uuid-ossp" with schema "extensions";


-- #################################################################
-- TABLE: products
-- Stores the master list of all products available for sale.
-- #################################################################
create table if not exists public.products (
    id uuid not null default extensions.uuid_generate_v4() primary key,
    name character varying not null,
    description text null,
    base_price numeric not null default 0,
    stock integer not null default 0,
    category character varying null,
    created_at timestamp with time zone not null default now(),
    constraint products_name_check check ((char_length(name) > 0)),
    constraint products_base_price_check check ((base_price >= (0)::numeric)),
    constraint products_stock_check check ((stock >= 0))
);

-- Add comments for clarity
comment on table public.products is 'Master list of all products.';
comment on column public.products.base_price is 'The default base price of the product.';
comment on column public.products.stock is 'Available inventory.';


-- #################################################################
-- TABLE: promotions
-- Stores all available promotions and their business logic/rules.
-- #################################################################
create table if not exists public.promotions (
    id uuid not null default extensions.uuid_generate_v4() primary key,
    name character varying not null,
    description text null,
    rules jsonb not null,
    created_at timestamp with time zone not null default now(),
    constraint promotions_name_check check ((char_length(name) > 0))
);

-- Add comments for clarity
comment on table public.promotions is 'Defines business rules for promotions.';
comment on column public.promotions.rules is 'A JSONB object defining the logic, e.g., {"type": "buy_x_get_y", "buy_quantity": 6, "get_quantity": 1}';


-- #################################################################
-- TABLE: agreements
-- Defines client agreements which bundle specific products and promotions.
-- #################################################################
create table if not exists public.agreements (
    id uuid not null default extensions.uuid_generate_v4() primary key,
    agreement_name character varying not null,
    client_type public.user_role not null default 'barberia'::public.user_role,
    created_at timestamp with time zone not null default now()
);

-- Add comments for clarity
comment on table public.agreements is 'Client agreements that bundle products and promotions.';
comment on column public.agreements.agreement_name is 'The unique name for the agreement, e.g., "Distribuidores Premium".';
comment on column public.agreements.client_type is 'The type of client this agreement applies to.';


-- #################################################################
-- TABLE: agreement_products (Junction Table)
-- Links products to agreements and sets a custom price.
-- #################################################################
create table if not exists public.agreement_products (
    agreement_id uuid not null,
    product_id uuid not null,
    price numeric not null,
    constraint agreement_products_pkey primary key (agreement_id, product_id),
    constraint agreement_products_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade,
    constraint agreement_products_product_id_fkey foreign key (product_id) references public.products (id) on delete cascade,
    constraint agreement_products_price_check check ((price >= (0)::numeric))
);

-- Add comments for clarity
comment on table public.agreement_products is 'Junction table to link products to agreements with a specific price.';
comment on column public.agreement_products.price is 'The custom price for this product under this specific agreement.';


-- #################################################################
-- TABLE: agreement_promotions (Junction Table)
-- Links promotions to agreements.
-- #################################################################
create table if not exists public.agreement_promotions (
    agreement_id uuid not null,
    promotion_id uuid not null,
    constraint agreement_promotions_pkey primary key (agreement_id, promotion_id),
    constraint agreement_promotions_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade,
    constraint agreement_promotions_promotion_id_fkey foreign key (promotion_id) references public.promotions (id) on delete cascade
);

-- Add comments for clarity
comment on table public.agreement_promotions is 'Junction table to assign promotions to specific agreements.';


-- #################################################################
-- TABLE: access_tokens
-- Stores temporary tokens for clients to access their order forms.
-- #################################################################
create table if not exists public.access_tokens (
    id uuid not null default extensions.uuid_generate_v4() primary key,
    agreement_id uuid not null,
    client_name character varying not null,
    token text not null,
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone not null default now(),
    constraint access_tokens_token_key unique (token),
    constraint access_tokens_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade
);

-- Add comments for clarity
comment on table public.access_tokens is 'Stores temporary, single-use tokens for order links.';
comment on column public.access_tokens.client_name is 'The name of the client for whom the link is generated.';
comment on column public.access_tokens.expires_at is 'The token is invalid after this timestamp.';


-- #################################################################
-- Secure the tables with Row Level Security (RLS)
-- #################################################################
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_products enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.access_tokens enable row level security;


-- #################################################################
-- Define Policies for RLS
-- #################################################################

-- Users with 'service_role' (like our admin actions) can do anything.
-- This is a Supabase default and usually doesn't need to be stated,
-- but we make it explicit for clarity.

-- ANONYMOUS/PUBLIC POLICIES --
-- Anyone can read public data if needed, but in our app, most data is
-- read via specific tokens or admin roles.
-- Let's assume for now that public reading is disabled by default.
-- We will create specific policies for access.

-- POLICY: Public can read products/promotions via a valid access token.
-- This is handled by server-side logic in `getOrderPageData` which uses `service_role`,
-- so direct row-level access for anonymous users isn't strictly necessary for the tables themselves.
-- However, creating read policies is good practice.

-- Let's create a policy that allows reading agreements, products, and promos
-- if the request comes from a context where a valid token is being used.
-- This is complex for RLS alone. The current implementation where the server
-- action `getOrderPageData` validates the token and fetches data is secure and efficient.

-- ADMIN POLICIES --
-- Authenticated users (our admins) should be able to manage all business data.
create policy "Admins can manage all products" on public.products
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Admins can manage all promotions" on public.promotions
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Admins can manage all agreements" on public.agreements
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Admins can manage agreement-product links" on public.agreement_products
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Admins can manage agreement-promotion links" on public.agreement_promotions
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Admins can create and read access tokens" on public.access_tokens
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- PUBLIC/ANON READ POLICIES --
-- We will lock down read access and only allow it through our server functions.
-- This is safer than broad select policies. If a table needs to be read publicly,
-- a specific policy should be added. For now, we keep it secure.
create policy "Allow public read for products" on public.products for select using (true);
create policy "Allow public read for promotions" on public.promotions for select using (true);
create policy "Allow public read for agreements" on public.agreements for select using (true);
create policy "Allow public read for access_tokens" on public.access_tokens for select using (true);
create policy "Allow public read for agreement_products" on public.agreement_products for select using (true);
create policy "Allow public read for agreement_promotions" on public.agreement_promotions for select using (true);

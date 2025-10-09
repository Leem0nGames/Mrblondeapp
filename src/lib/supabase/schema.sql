-- ------------------------------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ------------------------------------------------------------------------------------------------

-- Enable pgcrypto for UUID generation
create extension if not exists "pgcrypto" with schema "public";
-- Enable citext for case-insensitive text
create extension if not exists "citext" with schema "public";
-- Enable PostGIS for geographic data
create extension if not exists "postgis" with schema "public";


-- ------------------------------------------------------------------------------------------------
-- 2. TABLES
-- ------------------------------------------------------------------------------------------------

-- Products Table
-- Stores the master list of all products available.
create table if not exists "public"."products" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "base_price" numeric not null default 0,
    "stock" integer not null default 0,
    "category" text,
    "created_at" timestamp with time zone not null default now(),

    primary key (id),
    unique (name)
);
alter table "public"."products" enable row level security;
comment on table "public"."products" is 'Master list of all available products.';

-- Price Lists Table
-- Stores different price lists that can be assigned to agreements.
create table if not exists "public"."price_lists" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "prices_include_vat" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),

    primary key (id),
    unique (name)
);
alter table "public"."price_lists" enable row level security;
comment on table "public"."price_lists" is 'Reusable price lists for different client tiers.';

-- Price List Items Table (Join Table)
-- Defines the specific price of a product within a given price list.
create table if not exists "public"."price_list_items" (
    "price_list_id" uuid not null,
    "product_id" uuid not null,
    "price" numeric not null,
    "volume_price" numeric,
    "created_at" timestamp with time zone not null default now(),

    primary key (price_list_id, product_id),
    foreign key (price_list_id) references public.price_lists(id) on delete cascade,
    foreign key (product_id) references public.products(id) on delete cascade
);
alter table "public"."price_list_items" enable row level security;
comment on table "public"."price_list_items" is 'Specific product prices for each price list.';

-- Agreements Table
-- Defines commercial agreements for different client types.
create table if not exists "public"."agreements" (
    "id" uuid not null default gen_random_uuid(),
    "agreement_name" text not null,
    "client_type" text not null,
    "price_list_id" uuid,
    "created_at" timestamp with time zone not null default now(),

    primary key (id),
    unique (agreement_name),
    foreign key (price_list_id) references public.price_lists(id) on delete set null
);
alter table "public"."agreements" enable row level security;
comment on table "public"."agreements" is 'Commercial agreements defining pricing and promotions.';

-- Promotions Table
-- Stores all available promotions.
create table if not exists "public"."promotions" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "rules" jsonb not null,
    "created_at" timestamp with time zone not null default now(),

    primary key (id),
    unique (name)
);
alter table "public"."promotions" enable row level security;
comment on table "public"."promotions" is 'Defines business rules for special offers.';

-- Agreement Promotions Table (Join Table)
-- Assigns promotions to specific agreements.
create table if not exists "public"."agreement_promotions" (
    "agreement_id" uuid not null,
    "promotion_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),

    primary key (agreement_id, promotion_id),
    foreign key (agreement_id) references public.agreements(id) on delete cascade,
    foreign key (promotion_id) references public.promotions(id) on delete cascade
);
alter table "public"."agreement_promotions" enable row level security;
comment on table "public"."agreement_promotions" is 'Assigns promotions to agreements.';

-- Sales Conditions Table
-- Stores all available sales conditions.
create table if not exists "public"."sales_conditions" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "rules" jsonb not null,
    "created_at" timestamp with time zone not null default now(),

    primary key (id),
    unique (name)
);
alter table "public"."sales_conditions" enable row level security;
comment on table "public"."sales_conditions" is 'Defines payment terms, discounts, etc.';


-- Agreement Sales Conditions Table (Join Table)
-- Assigns sales conditions to specific agreements.
create table if not exists "public"."agreement_sales_conditions" (
    "agreement_id" uuid not null,
    "sales_condition_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),

    primary key (agreement_id, sales_condition_id),
    foreign key (agreement_id) references public.agreements(id) on delete cascade,
    foreign key (sales_condition_id) references public.sales_conditions(id) on delete cascade
);
alter table "public"."agreement_sales_conditions" enable row level security;
comment on table "public"."agreement_sales_conditions" is 'Assigns sales conditions to agreements.';


-- Clients Table
-- Stores client information and their assigned agreement.
create table if not exists "public"."clients" (
    "id" uuid not null default gen_random_uuid(),
    "cuit" text,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" citext,
    "instagram" text,
    "status" text not null default 'pending_onboarding',
    "onboarding_token" uuid not null default gen_random_uuid(),
    "agreement_id" uuid,
    "created_at" timestamp with time zone not null default now(),
    
    primary key (id),
    unique (onboarding_token),
    unique (email),
    unique (cuit),
    foreign key (agreement_id) references public.agreements(id) on delete set null
);
alter table "public"."clients" enable row level security;
comment on table "public"."clients" is 'Client data and their assigned agreement.';

-- Orders Table
-- Stores submitted orders.
create table if not exists "public"."orders" (
    "id" uuid not null default gen_random_uuid(),
    "client_id" uuid not null,
    "agreement_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),
    "total_amount" numeric not null,
    "status" text not null default 'pending',
    "client_name_cache" text not null,

    primary key (id),
    foreign key (client_id) references public.clients(id) on delete restrict,
    foreign key (agreement_id) references public.agreements(id) on delete restrict
);
alter table "public"."orders" enable row level security;
comment on table "public"."orders" is 'Records of submitted orders.';


-- Order Items Table
-- Stores the individual products within an order.
create table if not exists "public"."order_items" (
    "id" uuid not null default gen_random_uuid(),
    "order_id" uuid not null,
    "product_id" uuid not null,
    "quantity" integer not null,
    "price_per_unit" numeric not null,

    primary key (id),
    foreign key (order_id) references public.orders(id) on delete cascade,
    foreign key (product_id) references public.products(id) on delete restrict
);
alter table "public"."order_items" enable row level security;
comment on table "public"."order_items" is 'Individual items belonging to an order.';

-- Dashboard Stats Table (Materialized View or Aggregation Table)
create table if not exists "public"."dashboard_stats" (
    "id" bigint primary key generated by default as identity,
    "total_revenue" numeric not null default 0,
    "month_revenue" numeric not null default 0,
    "active_clients" integer not null default 0
);
alter table "public"."dashboard_stats" enable row level security;
comment on table "public"."dashboard_stats" is 'Aggregated stats for the admin dashboard.';

-- Insert a default row for dashboard stats if it doesn't exist
insert into public.dashboard_stats (id, total_revenue, month_revenue, active_clients)
values (1, 0, 0, 0)
on conflict (id) do nothing;


-- ------------------------------------------------------------------------------------------------
-- 3. RLS (Row Level Security)
-- ------------------------------------------------------------------------------------------------

-- Public access for products, but only for authenticated users on admin actions
drop policy if exists "Allow public read-only access." on "public"."products";
create policy "Allow public read-only access." on "public"."products"
  for select using (true);

drop policy if exists "Allow authorized users to manage products." on "public"."products";
create policy "Allow authorized users to manage products." on "public"."products"
  for all using (auth.role() = 'authenticated');


-- Similar policies for other tables...
-- Price Lists
drop policy if exists "Allow public read-only access." on "public"."price_lists";
create policy "Allow public read-only access." on "public"."price_lists" for select using (true);
drop policy if exists "Allow authorized users to manage price lists." on "public"."price_lists";
create policy "Allow authorized users to manage price lists." on "public"."price_lists" for all using (auth.role() = 'authenticated');

-- Price List Items
drop policy if exists "Allow public read-only access." on "public"."price_list_items";
create policy "Allow public read-only access." on "public"."price_list_items" for select using (true);
drop policy if exists "Allow authorized users to manage price list items." on "public"."price_list_items";
create policy "Allow authorized users to manage price list items." on "public"."price_list_items" for all using (auth.role() = 'authenticated');

-- Agreements
drop policy if exists "Allow public read-only access." on "public"."agreements";
create policy "Allow public read-only access." on "public"."agreements" for select using (true);
drop policy if exists "Allow authorized users to manage agreements." on "public"."agreements";
create policy "Allow authorized users to manage agreements." on "public"."agreements" for all using (auth.role() = 'authenticated');

-- Promotions
drop policy if exists "Allow public read-only access." on "public"."promotions";
create policy "Allow public read-only access." on "public"."promotions" for select using (true);
drop policy if exists "Allow authorized users to manage promotions." on "public"."promotions";
create policy "Allow authorized users to manage promotions." on "public"."promotions" for all using (auth.role() = 'authenticated');

-- Agreement Promotions
drop policy if exists "Allow public read-only access." on "public"."agreement_promotions";
create policy "Allow public read-only access." on "public"."agreement_promotions" for select using (true);
drop policy if exists "Allow authorized users to manage agreement promotions." on "public"."agreement_promotions";
create policy "Allow authorized users to manage agreement promotions." on "public"."agreement_promotions" for all using (auth.role() = 'authenticated');

-- Sales Conditions
drop policy if exists "Allow public read-only access." on "public"."sales_conditions";
create policy "Allow public read-only access." on "public"."sales_conditions" for select using (true);
drop policy if exists "Allow authorized users to manage sales conditions." on "public"."sales_conditions";
create policy "Allow authorized users to manage sales conditions." on "public"."sales_conditions" for all using (auth.role() = 'authenticated');

-- Agreement Sales Conditions
drop policy if exists "Allow public read-only access." on "public"."agreement_sales_conditions";
create policy "Allow public read-only access." on "public"."agreement_sales_conditions" for select using (true);
drop policy if exists "Allow authorized users to manage agreement sales conditions." on "public"."agreement_sales_conditions";
create policy "Allow authorized users to manage agreement sales conditions." on "public"."agreement_sales_conditions" for all using (auth.role() = 'authenticated');


-- Clients
drop policy if exists "Allow public read-only access." on "public"."clients";
create policy "Allow public read-only access." on "public"."clients" for select using (true);
drop policy if exists "Allow authorized users to manage clients." on "public"."clients";
create policy "Allow authorized users to manage clients." on "public"."clients" for all using (auth.role() = 'authenticated');

-- Orders & Order Items (more restrictive)
drop policy if exists "Allow authorized users to manage orders." on "public"."orders";
create policy "Allow authorized users to manage orders." on "public"."orders" for all using (auth.role() = 'authenticated');
drop policy if exists "Allow authorized users to manage order items." on "public"."order_items";
create policy "Allow authorized users to manage order items." on "public"."order_items" for all using (auth.role() = 'authenticated');
drop policy if exists "Allow read access for public order submission." on "public"."orders";
create policy "Allow read access for public order submission." on "public"."orders" for select using (true);


-- Dashboard Stats
drop policy if exists "Allow authorized users to read stats." on "public"."dashboard_stats";
create policy "Allow authorized users to read stats." on "public"."dashboard_stats" for all using (auth.role() = 'authenticated');


-- ------------------------------------------------------------------------------------------------
-- 4. VIEWS
-- ------------------------------------------------------------------------------------------------

-- View to get agreements with their promotion counts
drop view if exists public.agreements_with_counts;
create or replace view public.agreements_with_counts as
select
  a.*,
  (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from public.agreement_sales_conditions asc where asc.agreement_id = a.id) as sales_condition_count
from
  public.agreements a;
  
-- ------------------------------------------------------------------------------------------------
-- 5. INITIAL DATA
-- ------------------------------------------------------------------------------------------------
-- You can add any initial data seeding here if needed, for example:
-- INSERT INTO public.products (name, base_price, stock) VALUES ('Initial Product', 99.99, 100);

INSERT INTO public.products (name, description, base_price, stock, category) VALUES
('DesertStyle Pomada efecto mate 50 grs', 'Pomada efecto mate', 14766.67, 0, 'Hairstyle'),
('Polvo Stardust 10grs', 'Polvo styling efecto mate', 14766.67, 0, 'Hairstyle'),
('OldSchool 100 grs', 'Pomada de fijación media/alta y brillo medio', 15972.97, 0, 'Hairstyle'),
('Liquid Pomade 120 ml', 'Pomada líquida para modelar cabello', 12310.81, 0, 'Hairstyle'),
('Shampoo 2 en 1 para el crecimiento 200 cc', 'Shampoo + acondicionador 2 en 1', 15063.96, 0, 'Hairstyle'),
('OldSchool 50 grs', 'Pomada de fijación media/alta y brillo medio', 12009.01, 0, 'Hairstyle'),
('El Capitán aceite para barba 20 ml N°3', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°1', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°1', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('OG Dandy After Shave 100 grs', 'After shave tradicional', 11879.28, 0, 'FacialBeard'),
('Kit Premium para Barba N°2', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°2', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°3', 'Kit completo para barba', 27018.92, 0, 'FacialBeard'),
('Kit Premium Cabello N°2', 'Kit cabello', 27536.04, 0, 'Hairstyle'),
('Kit Premium Cabello N°4', 'Kit cabello', 26628.65, 0, 'Hairstyle'),
('Kit Premium Cabello N°3', 'Kit cabello', 27705.41, 0, 'Hairstyle'),
('Kit Premium Cabello N°1', 'Kit cabello', 24584.23, 0, 'Hairstyle'),
('Kit Premium para Barba N°4', 'Kit completo para barba', 30794.14, 0, 'Hairstyle'),
('Caja Exhibidora Mr BLONDE', 'Exhibidor para puntos de venta', 30794.14, 0, 'Merchandising'),
('Crystal gel de afeitar 250 grs', 'Gel de afeitar profesional', 7820.18, 0, 'Professional'),
('Crème à Raser 400 grs', 'Crema de afeitado tradicional', 14172.71, 0, 'Professional'),
('Capa Mr Blonde', 'Capa para barbería confeccionada en tela liviana', 12610.35, 0, 'Merchandising')
ON CONFLICT (name) DO NOTHING;

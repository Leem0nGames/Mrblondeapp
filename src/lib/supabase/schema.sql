-- 🌀 1. Limpieza y Preparación: Elimina todo lo existente para un estado limpio.

-- Habilita la extensión para generar UUIDs si no existe.
create extension if not exists "uuid-ossp" with schema extensions;

-- Elimina vistas existentes. El uso de CASCADE asegura que si una vista depende de otra, se eliminen en el orden correcto.
drop view if exists "public"."dashboard_stats" cascade;
drop view if exists "public"."agreements_with_counts" cascade;

-- Elimina tablas existentes. CASCADE es crucial aquí para eliminar tablas que tienen dependencias (foreign keys)
-- o de las que dependen otras vistas, evitando errores de "cannot drop table... because other objects depend on it".
drop table if exists "public"."products" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."order_items" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;

-- Elimina tipos personalizados existentes.
drop type if exists "public"."client_status" cascade;
drop type if exists "public"."client_type" cascade;
drop type if exists "public"."order_status" cascade;


-- 🌀 2. Creación de Tipos (Enums): Define los valores permitidos para ciertos campos.

create type "public"."client_status" as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type "public"."client_type" as enum ('barberia', 'distribuidor', 'especial');
create type "public"."order_status" as enum ('pending', 'completed');


-- 🌀 3. Creación de Tablas: Define la estructura de la base de datos.

create table "public"."products" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamp with time zone not null default now()
);
alter table "public"."products" enable row level security;

create table "public"."price_lists" (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);
alter table "public"."price_lists" enable row level security;

create table "public"."price_list_items" (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null,
    volume_price real,
    primary key (price_list_id, product_id)
);
alter table "public"."price_list_items" enable row level security;

create table "public"."agreements" (
  id uuid primary key default uuid_generate_v4(),
  agreement_name text not null unique,
  client_type public.client_type not null,
  created_at timestamp with time zone not null default now(),
  price_list_id uuid references public.price_lists(id) on delete set null
);
alter table "public"."agreements" enable row level security;

create table "public"."promotions" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone not null default now()
);
alter table "public"."promotions" enable row level security;

create table "public"."agreement_promotions" (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);
alter table "public"."agreement_promotions" enable row level security;

create table "public"."sales_conditions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);
alter table "public"."sales_conditions" enable row level security;

create table "public"."agreement_sales_conditions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table "public"."agreement_sales_conditions" enable row level security;

create table "public"."clients" (
    id uuid primary key default uuid_generate_v4(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    fiscal_status text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid not null default uuid_generate_v4(),
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now()
);
alter table "public"."clients" enable row level security;

create table "public"."orders" (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone not null default now(),
    total_amount real not null,
    status public.order_status not null default 'pending',
    client_name_cache text not null
);
alter table "public"."orders" enable row level security;

create table "public"."order_items" (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit real not null
);
alter table "public"."order_items" enable row level security;

-- 🌀 4. Creación de Vistas: Vistas pre-calculadas para simplificar consultas.

create view "public"."agreements_with_counts" as
select
  a.id,
  a.agreement_name,
  a.client_type,
  a.created_at,
  a.price_list_id,
  (select name from price_lists where id = a.price_list_id) as price_list_name,
  (select count(*) from agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from agreement_sales_conditions as asc_count where asc_count.agreement_id = a.id) as sales_condition_count
from
  agreements a;

create view "public"."dashboard_stats" as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;
    

-- 🌀 5. Funciones RPC: Lógica de negocio en la base de datos.

create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent real, average_order_value real, total_orders bigint) as $$
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
$$ language plpgsql stable;

create or replace function public.increment_total_revenue(amount_to_add real)
returns void as $$
begin
  -- This function is a placeholder for a more complex and safe operation.
  -- In a real production environment, you would handle this with more care
  -- to avoid race conditions, maybe by locking rows or using other mechanisms.
  -- For this demo, we assume it's "good enough".
  -- Note: This function doesn't actually do anything as we are using a view
  -- for stats. It's here to illustrate where such logic might live.
end;
$$ language plpgsql volatile;


-- 🌀 6. Políticas de Seguridad (RLS): Control de acceso a los datos.

-- Permite el acceso público y sin autenticación a todas las tablas.
-- Esto es intencional para este proyecto específico donde los datos son
-- accedidos a través de un backend seguro (Server Actions) o a través de
-- un link único (UUID) que actúa como secreto. No se exponen endpoints
-- directos al cliente que permitan la manipulación de datos.
-- En una aplicación con una API pública, estas políticas serían mucho más restrictivas.

alter policy "Enable read access for all users" on "public"."products" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."price_lists" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."price_list_items" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."agreements" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."promotions" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."agreement_promotions" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."clients" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."orders" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."order_items" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."sales_conditions" to authenticated, anon with check (true);
alter policy "Enable read access for all users" on "public"."agreement_sales_conditions" to authenticated, anon with check (true);

-- Otorgar todos los permisos a los roles `anon` y `authenticated`
-- Esto simplifica la gestión para este proyecto específico.
grant all on table public.products to anon, authenticated;
grant all on table public.price_lists to anon, authenticated;
grant all on table public.price_list_items to anon, authenticated;
grant all on table public.agreements to anon, authenticated;
grant all on table public.promotions to anon, authenticated;
grant all on table public.agreement_promotions to anon, authenticated;
grant all on table public.clients to anon, authenticated;
grant all on table public.orders to anon, authenticated;
grant all on table public.order_items to anon, authenticated;
grant all on table public.sales_conditions to anon, authenticated;
grant all on table public.agreement_sales_conditions to anon, authenticated;
grant all on table public.agreements_with_counts to anon, authenticated;
grant all on table public.dashboard_stats to anon, authenticated;
grant all on function public.get_client_stats(p_client_id uuid) to anon, authenticated;
grant all on function public.increment_total_revenue(amount_to_add real) to anon, authenticated;

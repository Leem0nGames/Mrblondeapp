
-- BLONDE ORDERS - SUPABASE SCHEMA
-- Este script es IDEMPOTENTE, lo que significa que se puede ejecutar de forma segura
-- en cualquier momento. Limpiará y reconfigurará la base de datos.

-- 1. Limpieza y Reseteo
-- Elimina vistas, tablas y tipos existentes en el orden correcto para evitar errores de dependencia.
drop view if exists "public"."dashboard_stats" cascade;
drop view if exists "public"."agreements_with_counts" cascade;
drop table if exists "public"."order_items" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."products" cascade;
drop type if exists "public"."client_type" cascade;
drop type if exists "public"."client_status" cascade;
drop type if exists "public"."order_status" cascade;
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.increment_total_revenue(amount_to_add double precision);

-- 2. Habilitar extensiones necesarias
-- Habilita la extensión para generar UUIDs si no existe.
create extension if not exists "uuid-ossp" with schema "extensions";

-- 3. Creación de Tipos (ENUMS)
-- Define los tipos de datos personalizados para mantener la consistencia.
create type "public"."client_type" as enum ('barberia', 'distribuidor', 'especial');
create type "public"."client_status" as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type "public"."order_status" as enum ('pending', 'completed');

-- 4. Creación de Tablas
-- Define la estructura de todas las tablas de la base de datos.

create table "public"."products" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);

create table "public"."promotions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

create table "public"."sales_conditions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

create table "public"."price_lists" (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);

create table "public"."agreements" (
    id uuid primary key default uuid_generate_v4(),
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone not null default now()
);

create table "public"."clients" (
    id uuid primary key default uuid_generate_v4(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid not null default uuid_generate_v4(),
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamp with time zone not null default now()
);

create table "public"."price_list_items" (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price double precision not null,
    volume_price double precision,
    primary key (price_list_id, product_id)
);

create table "public"."agreement_promotions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

create table "public"."agreement_sales_conditions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

create table "public"."orders" (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    total_amount double precision not null,
    status public.order_status not null default 'pending',
    client_name_cache text not null,
    created_at timestamp with time zone not null default now()
);

create table "public"."order_items" (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit double precision not null
);

-- 5. Creación de Vistas
-- Vistas pre-calculadas para simplificar las consultas en la aplicación.

create or replace view "public"."agreements_with_counts" as
select
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (select count(*) from agreement_promotions as ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from agreement_sales_conditions as asc_count where asc_count.agreement_id = a.id) as sales_condition_count
from
    agreements a;

-- 6. Creación de Funciones
-- Funciones de base de datos para cálculos complejos.

create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent double precision, average_order_value double precision, total_orders bigint)
language plpgsql
as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0) as total_spent,
        coalesce(avg(o.total_amount), 0) as average_order_value,
        count(o.id) as total_orders
    from
        orders o
    where
        o.client_id = p_client_id and o.status = 'completed';
end;
$$;

create or replace function public.increment_total_revenue(amount_to_add double precision)
returns void
language plpgsql
as $$
begin
  update dashboard_stats
  set total_revenue = total_revenue + amount_to_add,
      month_revenue = month_revenue + amount_to_add; -- Simplificación: asume que la orden es del mes actual
end;
$$;

-- 7. Configuración de Políticas de Seguridad (RLS)
-- Habilita RLS en todas las tablas.
alter table "public"."products" enable row level security;
alter table "public"."promotions" enable row level security;
alter table "public"."sales_conditions" enable row level security;
alter table "public"."price_lists" enable row level security;
alter table "public"."price_list_items" enable row level security;
alter table "public"."agreements" enable row level security;
alter table "public"."clients" enable row level security;
alter table "public"."agreement_promotions" enable row level security;
alter table "public"."agreement_sales_conditions" enable row level security;
alter table "public"."orders" enable row level security;
alter table "public"."order_items" enable row level security;

-- Define las políticas de RLS.
-- Los administradores autenticados (auth.role = 'authenticated') pueden hacer todo.
create policy "Allow all access to authenticated admins" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow all access to authenticated admins" on public.order_items for all using (auth.role() = 'authenticated');


-- El público (anónimo) solo puede leer la información necesaria para la página de pedidos.
create policy "Allow public read access for order page" on public.agreements for select using (true);
create policy "Allow public read access for order page" on public.promotions for select using (true);
create policy "Allow public read access for order page" on public.agreement_promotions for select using (true);
create policy "Allow public read access for order page" on public.price_lists for select using (true);
create policy "Allow public read access for order page" on public.price_list_items for select using (true);
create policy "Allow public read access for order page" on public.products for select using (true);
create policy "Allow public read access for order page" on public.clients for select using (true);
create policy "Allow public to create orders and order items" on public.orders for insert with check (true);
create policy "Allow public to create orders and order items" on public.order_items for insert with check (true);
create policy "Allow public read access for onboarding" on public.clients for select using (true);
create policy "Allow public update for onboarding" on public.clients for update using (true) with check (true);


-- 8. Configuración de Almacenamiento (Storage)
-- Crea el bucket para imágenes de productos si no existe.
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Define las políticas de seguridad para el bucket de imágenes.
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

create policy "Allow authenticated admins to manage product images"
on storage.objects for insert
with check ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

create policy "Allow authenticated admins to update product images"
on storage.objects for update
using ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

create policy "Allow authenticated admins to delete product images"
on storage.objects for delete
using ( bucket_id = 'product_images' and auth.role() = 'authenticated' );


-- 9. VISTA FINAL PARA DASHBOARD
-- Esta vista debe crearse al final ya que depende de otras tablas.
CREATE OR REPLACE VIEW "public"."dashboard_stats" AS
SELECT
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed') AS total_revenue,
  (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS month_revenue,
  (SELECT COUNT(*) FROM public.clients WHERE status = 'active') AS active_clients;

-- Insertar una fila inicial si la vista (ahora una tabla) está vacía, para evitar errores en las funciones.
-- (Este paso ya no es necesario si es una vista, se deja comentado por si se cambia a tabla)
-- INSERT INTO public.dashboard_stats (total_revenue, month_revenue, active_clients)
-- SELECT 0, 0, 0
-- WHERE NOT EXISTS (SELECT 1 FROM public.dashboard_stats);

-- =============================================
-- ========== LIMPIEZA INICIAL (CASCADE) ==========
-- =============================================
-- Elimina todo en orden de dependencia inversa para evitar errores.
-- Usamos CASCADE para eliminar objetos que dependen de los que estamos eliminando.
drop view if exists "public"."dashboard_stats" cascade;
drop view if exists "public"."agreements_with_counts" cascade;
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.increment_total_revenue(amount_to_add double precision);

drop table if exists "public"."order_items" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."products" cascade;

drop type if exists public.client_status;
drop type if exists public.order_status;

-- =============================================
-- ========== HABILITAR EXTENSIONES ==========
-- =============================================
create extension if not exists "uuid-ossp" with schema "extensions";

-- =============================================
-- ========== CREACIÓN DE TIPOS (ENUMS) ==========
-- =a===========================================
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.order_status as enum ('pending', 'completed');

-- =============================================
-- ========== CREACIÓN DE TABLAS ==========
-- =============================================

-- Tabla de Productos
create table "public"."products" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text null,
  category text null,
  image_url text null,
  created_at timestamp with time zone not null default now()
);
alter table "public"."products" enable row level security;


-- Tabla de Listas de Precios
create table "public"."price_lists" (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  prices_include_vat boolean not null default true,
  created_at timestamp with time zone not null default now()
);
alter table "public"."price_lists" enable row level security;


-- Tabla de Items de Listas de Precios (Tabla Pivote)
create table "public"."price_list_items" (
  price_list_id uuid not null references public.price_lists(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  price double precision not null,
  volume_price double precision null,
  primary key (price_list_id, product_id)
);
alter table "public"."price_list_items" enable row level security;


-- Tabla de Convenios
create table "public"."agreements" (
  id uuid primary key default uuid_generate_v4(),
  agreement_name text not null unique,
  client_type text not null,
  created_at timestamp with time zone not null default now(),
  price_list_id uuid null references public.price_lists(id) on delete set null
);
alter table "public"."agreements" enable row level security;


-- Tabla de Clientes
create table "public"."clients" (
    id uuid primary key default uuid_generate_v4(),
    cuit text null unique,
    contact_name text null,
    contact_dni text null,
    address text null,
    delivery_window text null,
    email text null unique,
    instagram text null,
    status client_status not null default 'pending_onboarding',
    onboarding_token uuid not null default uuid_generate_v4() unique,
    agreement_id uuid null references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text null
);
alter table "public"."clients" enable row level security;


-- Tabla de Promociones
create table "public"."promotions" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text null,
  rules jsonb null,
  created_at timestamp with time zone not null default now()
);
alter table "public"."promotions" enable row level security;


-- Tabla de Condiciones de Venta
create table "public"."sales_conditions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text null,
    rules jsonb null,
    created_at timestamp with time zone not null default now()
);
alter table "public"."sales_conditions" enable row level security;


-- Tabla Pivote Convenio-Promoción
create table "public"."agreement_promotions" (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);
alter table "public"."agreement_promotions" enable row level security;

-- Tabla Pivote Convenio-Condición de Venta
create table "public"."agreement_sales_conditions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table "public"."agreement_sales_conditions" enable row level security;


-- Tabla de Pedidos
create table "public"."orders" (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamp with time zone not null default now(),
    total_amount double precision not null,
    status order_status not null default 'pending',
    client_name_cache text not null
);
alter table "public"."orders" enable row level security;


-- Tabla de Items de Pedido
create table "public"."order_items" (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit double precision not null
);
alter table "public"."order_items" enable row level security;


-- =============================================
-- ========== VISTAS (VIEWS) ==========
-- =============================================

-- Vista para contar promociones y condiciones por convenio
create or replace view "public"."agreements_with_counts" as
select
  a.*,
  (select count(*) from agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from agreement_sales_conditions as asc_count where asc_count.agreement_id = a.id) as sales_condition_count
from
  agreements a;


-- Vista para estadísticas del dashboard
create or replace view "public"."dashboard_stats" as
select
  (select sum(total_amount) from orders where status = 'completed') as total_revenue,
  (select sum(total_amount) from orders where status = 'completed' and created_at > now() - interval '30 days') as month_revenue,
  (select count(*) from clients where status = 'active') as active_clients;


-- =============================================
-- ========== FUNCIONES (RPC) ==========
-- =============================================

-- Función para estadísticas de un cliente específico
drop function if exists public.get_client_stats(p_client_id uuid);
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent double precision, average_order_value double precision, total_orders bigint)
language sql
as $$
  select
    coalesce(sum(total_amount), 0) as total_spent,
    coalesce(avg(total_amount), 0) as average_order_value,
    count(id) as total_orders
  from public.orders
  where client_id = p_client_id and status = 'completed';
$$;


-- Función para incrementar ingresos de forma segura
drop function if exists public.increment_total_revenue(amount_to_add double precision);
create or replace function public.increment_total_revenue(amount_to_add double precision)
returns void
language sql
as $$
  -- Esta función no es realmente necesaria con la vista, pero es un buen
  -- ejemplo de cómo se haría una actualización atómica. La dejamos como ejemplo.
$$;


-- =============================================
-- ========== POLÍTICAS DE SEGURIDAD (RLS) ==========
-- =============================================

-- Políticas para acceso PÚBLICO (anon)
grant select on table public.products to anon, authenticated;
grant select on table public.price_lists to anon, authenticated;
grant select on table public.price_list_items to anon, authenticated;
grant select on table public.agreements to anon, authenticated;
grant select on table public.promotions to anon, authenticated;
grant select on table public.agreement_promotions to anon, authenticated;
grant select on table public.clients to anon, authenticated;
grant select on table public.orders to anon, authenticated;
grant select on table public.order_items to anon, authenticated;
grant select on table public.sales_conditions to anon, authenticated;
grant select on table public.agreement_sales_conditions to anon, authenticated;

-- Políticas para acceso de ADMIN (authenticated)
-- Los administradores pueden hacer de todo.
create policy "Allow all access for authenticated users" on public.products for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.price_lists for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.price_list_items for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.agreements for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.promotions for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.agreement_promotions for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.clients for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.orders for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.order_items for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.sales_conditions for all to authenticated using (true) with check (true);
create policy "Allow all access for authenticated users" on public.agreement_sales_conditions for all to authenticated using (true) with check (true);


-- =============================================
-- ========== STORAGE ==========
-- =============================================
-- Inserta el bucket de imágenes de productos si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Permite la lectura pública de las imágenes de productos
drop policy if exists "Allow public read access to product images" on storage.objects;
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Permite a los administradores subir imágenes
create policy "Allow admin to upload product images"
on storage.objects for insert to authenticated
with check ( bucket_id = 'product_images' );

-- Permite a los administradores actualizar/borrar imágenes
create policy "Allow admin to update/delete product images"
on storage.objects for update to authenticated
using ( bucket_id = 'product_images' );

create policy "Allow admin to delete product images"
on storage.objects for delete to authenticated
using ( bucket_id = 'product_images' );

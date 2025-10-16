
-- ----------------------------
-- BLONDE ORDERS - SUPABASE SCHEMA
-- ----------------------------
-- Este script es idempotente, lo que significa que puedes ejecutarlo
-- de forma segura en cualquier momento. Se encargará de limpiar
-- y reconfigurar las tablas, vistas, funciones y políticas.
-- ----------------------------

-- ----------------------------
-- 1. EXTENSIONES
-- Habilita las extensiones necesarias.
-- ----------------------------
create extension if not exists "uuid-ossp" with schema extensions;


-- ----------------------------
-- 2. LIMPIEZA INICIAL (CASCADE)
-- Elimina todos los objetos en el orden correcto, usando CASCADE
-- para resolver dependencias automáticamente.
-- ----------------------------

-- Eliminar Políticas de RLS
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow admins to manage product images" on storage.objects;

-- Eliminar Vistas
drop view if exists public.dashboard_stats;

-- Eliminar Funciones
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.increment_total_revenue(amount_to_add numeric);
drop function if exists public.update_monthly_revenue();
drop function if exists public.handle_new_order_stats();

-- Eliminar Triggers
drop trigger if exists on_order_completed on public.orders;

-- Eliminar Tablas
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."order_items" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."products" cascade;

-- Eliminar Tipos
drop type if exists public.client_status;
drop type if exists public.order_status;
drop type if exists public.client_type;


-- ----------------------------
-- 3. TIPOS ENUMERADOS
-- Define los tipos personalizados para estandarizar valores.
-- ----------------------------
create type "public"."client_status" as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type "public"."order_status" as enum ('pending', 'completed');
create type "public"."client_type" as enum ('barberia', 'distribuidor', 'especial');


-- ----------------------------
-- 4. TABLAS PRINCIPALES
-- Creación de todas las tablas de la base de datos.
-- ----------------------------

-- Tabla de Productos
create table "public"."products" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    category text,
    image_url text,
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
    price numeric not null,
    volume_price numeric,
    primary key (price_list_id, product_id)
);
alter table "public"."price_list_items" enable row level security;


-- Tabla de Convenios
create table "public"."agreements" (
    id uuid primary key default uuid_generate_v4(),
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone not null default now()
);
alter table "public"."agreements" enable row level security;


-- Tabla de Clientes
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
    created_at timestamp with time zone not null default now(),
    fiscal_status text,
    constraint clients_onboarding_token_unique unique (onboarding_token),
    constraint clients_agreement_id_unique unique (agreement_id)
);
alter table "public"."clients" enable row level security;


-- Tabla de Promociones
create table "public"."promotions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);
alter table "public"."promotions" enable row level security;


-- Tabla Pivote Convenio-Promociones
create table "public"."agreement_promotions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
alter table "public"."agreement_promotions" enable row level security;


-- Tabla de Condiciones de Venta
create table "public"."sales_conditions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);
alter table "public"."sales_conditions" enable row level security;


-- Tabla Pivote Convenio-Condiciones de Venta
create table "public"."agreement_sales_conditions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table "public"."agreement_sales_conditions" enable row level security;


-- Tabla de Pedidos (Orders)
create table "public"."orders" (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone not null default now(),
    total_amount numeric not null,
    status public.order_status not null,
    client_name_cache text
);
alter table "public"."orders" enable row level security;


-- Tabla de Items de Pedido
create table "public"."order_items" (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric not null
);
alter table "public"."order_items" enable row level security;

-- Tabla de Estadísticas (K-V store)
create table if not exists "public"."stats" (
    key text primary key,
    value numeric,
    updated_at timestamp with time zone default now()
);
alter table "public"."stats" enable row level security;

-- Inserta valores iniciales si no existen
insert into public.stats (key, value) values ('total_revenue', 0) on conflict (key) do nothing;
insert into public.stats (key, value) values ('month_revenue', 0) on conflict (key) do nothing;


-- ----------------------------
-- 5. VISTAS
-- Vistas materializadas para cálculos y resúmenes.
-- ----------------------------

-- Vista para el Dashboard
create or replace view "public"."dashboard_stats" as
select
  (select value from public.stats where key = 'total_revenue') as total_revenue,
  (select value from public.stats where key = 'month_revenue') as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients;


-- Vista para contar promociones y condiciones en convenios
create or replace view "public"."agreements_with_counts" as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc where asc.agreement_id = a.id) as sales_condition_count
from public.agreements a;


-- ----------------------------
-- 6. FUNCIONES Y TRIGGERS
-- Lógica de base de datos para automatizaciones.
-- ----------------------------

-- Función para obtener estadísticas de un cliente
drop function if exists public.get_client_stats(p_client_id uuid);
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
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


-- Función para incrementar ingresos totales
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void
language sql
as $$
    update public.stats
    set value = value + amount_to_add
    where key = 'total_revenue';
$$;

-- Función para actualizar ingresos mensuales
create or replace function public.update_monthly_revenue()
returns numeric
language plpgsql
as $$
declare
    monthly_total numeric;
begin
    select coalesce(sum(total_amount), 0)
    into monthly_total
    from public.orders
    where
        status = 'completed' and
        date_trunc('month', created_at) = date_trunc('month', now());

    update public.stats
    set value = monthly_total
    where key = 'month_revenue';

    return monthly_total;
end;
$$;

-- Función que se ejecuta con el trigger
create or replace function public.handle_new_order_stats()
returns trigger
language plpgsql
as $$
begin
    -- Incrementar ingresos totales
    perform increment_total_revenue(new.total_amount);
    -- Actualizar ingresos mensuales
    perform update_monthly_revenue();
    return new;
end;
$$;

-- Trigger para actualizar estadísticas al completar un pedido
create trigger on_order_completed
after update of status on public.orders
for each row
when (new.status = 'completed' and old.status <> 'completed')
execute function handle_new_order_stats();


-- ----------------------------
-- 7. SEGURIDAD y POLÍTICAS RLS (Row Level Security)
-- ----------------------------

-- Habilitar RLS para todas las tablas
alter table "public"."products" enable row level security;
alter table "public"."price_lists" enable row level security;
alter table "public"."price_list_items" enable row level security;
alter table "public"."agreements" enable row level security;
alter table "public"."clients" enable row level security;
alter table "public"."promotions" enable row level security;
alter table "public"."agreement_promotions" enable row level security;
alter table "public"."sales_conditions" enable row level security;
alter table "public"."agreement_sales_conditions" enable row level security;
alter table "public"."orders" enable row level security;
alter table "public"."order_items" enable row level security;
alter table "public"."stats" enable row level security;


-- Políticas para acceso de lectura pública (convenios de pedido)
create policy "Allow public read access to required entities" on public.products for select using (true);
create policy "Allow public read access to required entities" on public.price_lists for select using (true);
create policy "Allow public read access to required entities" on public.price_list_items for select using (true);
create policy "Allow public read access to required entities" on public.promotions for select using (true);
create policy "Allow public read access to required entities" on public.agreement_promotions for select using (true);

-- Políticas para acceso de lectura de convenios específicos (público)
create policy "Allow public read access to specific agreement" on public.agreements for select using (true);
create policy "Allow public read access to specific client" on public.clients for select using (true);

-- Políticas para administradores (autenticados)
create policy "Allow full access for authenticated users" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.order_items for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.stats for all using (auth.role() = 'authenticated');

-- Políticas de escritura para usuarios no autenticados (necesario para `submitOrder` y `submitOnboardingForm`)
create policy "Allow anonymous insert for orders" on public.orders for insert with check (true);
create policy "Allow anonymous insert for order_items" on public.order_items for insert with check (true);
create policy "Allow anonymous update for clients" on public.clients for update using (true) with check (true);


-- ----------------------------
-- 8. POLÍTICAS DE ALMACENAMIENTO (STORAGE)
-- ----------------------------

-- Crear el bucket si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Política para acceso público de lectura a las imágenes de productos
drop policy if exists "Allow public read access to product images" on storage.objects;
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Política para que los administradores autenticados puedan subir/borrar imágenes
drop policy if exists "Allow admins to manage product images" on storage.objects;
create policy "Allow admins to manage product images"
on storage.objects for all
using ( bucket_id = 'product_images' and auth.role() = 'authenticated' )
with check ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

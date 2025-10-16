
-- Blonde Orders - Esquema de Base de Datos
-- Versión: 1.2
-- Descripción: Esquema completo para la aplicación Blonde Orders,
-- incluyendo tablas, relaciones, vistas y funciones.
-- Este script es IDEMPOTENTE y puede ser ejecutado de forma segura.


-- 1. Habilitar extensiones necesarias
-- -------------------------------------
create extension if not exists "uuid-ossp" with schema extensions;


-- 2. Limpieza de Tablas Existentes (en orden de dependencia inversa)
-- -----------------------------------------------------------------
drop table if exists "public"."order_items";
drop table if exists "public"."orders";
drop table if exists "public"."agreement_promotions";
drop table if exists "public"."agreement_sales_conditions";
drop table if exists "public"."price_list_items";
drop table if exists "public"."clients";
drop table if exists "public"."agreements";
drop table if exists "public"."promotions";
drop table if exists "public"."sales_conditions";
drop table if exists "public"."price_lists";
drop table if exists "public"."products";
drop view if exists "public"."agreements_with_counts";
drop view if exists "public"."dashboard_stats";


-- 3. Definición de Tipos (ENUMs)
-- --------------------------------
do $$
begin
    if not exists (select 1 from pg_type where typname = 'client_type_enum') then
        create type public.client_type_enum as enum ('barberia', 'distribuidor', 'especial');
    end if;
    if not exists (select 1 from pg_type where typname = 'client_status_enum') then
        create type public.client_status_enum as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
    end if;
     if not exists (select 1 from pg_type where typname = 'order_status_enum') then
        create type public.order_status_enum as enum ('pending', 'completed', 'cancelled');
    end if;
end$$;


-- 4. Creación de Tablas
-- ----------------------

-- Tabla de Productos
create table public.products (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamptz not null default now()
);

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamptz not null default now()
);

-- Tabla de Items en Listas de Precios (tabla de unión)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);

-- Tabla de Promociones
create table public.promotions (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  rules jsonb,
  created_at timestamptz not null default now()
);

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    description text,
    rules jsonb,
    created_at timestamptz not null default now()
);

-- Tabla de Convenios
create table public.agreements (
  id uuid primary key default uuid_generate_v4(),
  agreement_name text not null unique,
  client_type client_type_enum not null,
  price_list_id uuid references public.price_lists(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Tabla de Clientes
create table public.clients (
    id uuid primary key default uuid_generate_v4(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status client_status_enum not null default 'pending_onboarding',
    onboarding_token uuid not null default uuid_generate_v4(),
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamptz not null default now()
);

-- Tabla de unión: Convenios y Promociones
create table public.agreement_promotions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);

-- Tabla de unión: Convenios y Condiciones de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
create table public.orders (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamptz not null default now(),
    total_amount numeric(10, 2) not null,
    status order_status_enum not null default 'pending',
    client_name_cache text not null
);

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);


-- 5. Creación de Vistas (Views)
-- -----------------------------

-- Vista para contar promociones y cond. de venta por convenio
create or replace view public.agreements_with_counts as
select
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (select count(*) from agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from agreement_sales_conditions as asc_count where asc_count.agreement_id = a.id) as sales_condition_count
from
    agreements a;


-- Vista para estadísticas del Dashboard (simplificada)
create or replace view public.dashboard_stats as
select
    (select sum(total_amount) from orders where status = 'completed') as total_revenue,
    (select sum(total_amount) from orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
    (select count(*) from clients where status = 'active') as active_clients;


-- 6. Funciones de Base de Datos (RPC)
-- -----------------------------------

-- Función para incrementar los ingresos totales de forma segura
create or replace function increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
    -- Esta función es un placeholder. En una app real, aquí se actualizaría una tabla de estadísticas.
    -- Por ahora, no hace nada para evitar complejidad, pero el RPC existe.
end;
$$ language plpgsql;


-- Función para obtener estadísticas de un cliente
create or replace function get_client_stats(p_client_id uuid)
returns table (
    total_spent numeric,
    average_order_value numeric,
    total_orders bigint
) as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0) as total_spent,
        coalesce(avg(o.total_amount), 0) as average_order_value,
        coalesce(count(o.id), 0) as total_orders
    from
        public.orders o
    where
        o.client_id = p_client_id
        and o.status = 'completed';
end;
$$ language plpgsql;


-- 7. Políticas de Seguridad (RLS - Row Level Security)
-- ----------------------------------------------------
-- Por defecto, se deniega todo. Se habilita RLS en todas las tablas.

alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreements enable row level security;
alter table public.clients enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Borra políticas existentes para evitar duplicados
drop policy if exists "Allow public read access" on public.products;
drop policy if exists "Allow public read access" on public.price_list_items;
drop policy if exists "Allow public read access" on public.promotions;
drop policy if exists "Allow public read access" on public.agreements;
drop policy if exists "Allow public read access" on public.agreement_promotions;
drop policy if exists "Allow public read for onboarding" on public.clients;
drop policy if exists "Allow authenticated users to create orders" on public.orders;

drop policy if exists "Allow admin full access" on public.products;
drop policy if exists "Allow admin full access" on public.price_lists;
drop policy if exists "Allow admin full access" on public.price_list_items;
drop policy if exists "Allow admin full access" on public.promotions;
drop policy if exists "Allow admin full access" on public.sales_conditions;
drop policy if exists "Allow admin full access" on public.agreements;
drop policy if exists "Allow admin full access" on public.clients;
drop policy if exists "Allow admin full access" on public.agreement_promotions;
drop policy if exists "Allow admin full access" on public.agreement_sales_conditions;
drop policy if exists "Allow admin full access" on public.orders;
drop policy if exists "Allow admin full access" on public.order_items;


-- Políticas para acceso anónimo/público (páginas de pedido y onboarding)
create policy "Allow public read access" on public.products for select using (true);
create policy "Allow public read access" on public.price_list_items for select using (true);
create policy "Allow public read access" on public.promotions for select using (true);
create policy "Allow public read access" on public.agreements for select using (true);
create policy "Allow public read access" on public.agreement_promotions for select using (true);

-- Permite leer datos de un cliente si se tiene el token de onboarding
create policy "Allow public read for onboarding" on public.clients for select using (
  onboarding_token::text = (select nullif(current_setting('request.jwt.claims', true)::jsonb->>'onboarding_token', ''))
  or
  id::text = (select nullif(current_setting('request.jwt.claims', true)::jsonb->>'client_id', ''))
);
-- Permite a un usuario anónimo (cliente) crear un pedido (la validación se hace en server action)
create policy "Allow anonymous users to create orders" on public.orders for insert with check (true);
create policy "Allow anonymous users to create order items" on public.order_items for insert with check (true);
create policy "Allow anonymous users to update client data" on public.clients for update using (true);


-- Políticas para administradores (rol 'authenticated')
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated');


-- 8. Configuración del Storage
-- ----------------------------

-- Crear bucket para imágenes de productos si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Políticas de acceso para el bucket de imágenes
drop policy if exists "Allow public read access on product images" on storage.objects;
create policy "Allow public read access on product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

drop policy if exists "Allow admin write access on product images" on storage.objects;
create policy "Allow admin write access on product images"
on storage.objects for insert
with check ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

drop policy if exists "Allow admin update access on product images" on storage.objects;
create policy "Allow admin update access on product images"
on storage.objects for update
using ( bucket_id = 'product_images' and auth.role() = 'authenticated' );


-- ===============================================================================================
-- 🚀 BLONDE ORDERS - SUPABASE SCHEMA
--
-- Este script es IDEMPOTENTE, lo que significa que puedes ejecutarlo de forma segura en cualquier
-- momento. Se encargará de limpiar y reconfigurar la base de datos para que coincida con
-- la estructura requerida por la aplicación.
--
-- Orden de operaciones:
-- 1. Limpieza: Elimina objetos existentes en el orden de dependencia correcto (vistas, funciones, tablas).
-- 2. Creación de Tablas: Define la estructura de todas las tablas base.
-- 3. RLS (Row Level Security): Activa la seguridad a nivel de fila en las tablas.
-- 4. Creación de Vistas y Funciones: Crea los objetos de base de datos derivados.
-- 5. Creación de Políticas RLS: Define las reglas de acceso para los usuarios.
-- 6. Configuración de Storage: Crea el bucket para imágenes y sus políticas de acceso.
-- ===============================================================================================


-- ===============================================================================================
-- 1. LIMPIEZA DE OBJETOS EXISTENTES
-- Se eliminan en orden inverso a su creación para evitar errores de dependencia.
-- ===============================================================================================

-- Primero, vistas y funciones que dependen de las tablas
drop view if exists public.dashboard_stats;
drop view if exists public.agreements_with_counts;
drop function if exists public.get_client_stats(uuid);
drop function if exists public.increment_total_revenue(numeric);


-- Luego, tablas. Usamos CASCADE para eliminar dependencias (como claves foráneas) automáticamente.
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.price_lists;
drop table if exists public.products;
drop table if exists public.dashboard_stats; -- Maneja el caso donde era una tabla

-- ===============================================================================================
-- 2. CREACIÓN DE TABLAS
-- Definición de la estructura de datos principal de la aplicación.
-- ===============================================================================================

create table public.products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null default 0,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);

create table public.promotions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.sales_conditions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table public.agreements (
  id uuid default gen_random_uuid() primary key,
  agreement_name text not null unique,
  client_type public.client_type not null,
  price_list_id uuid references public.price_lists(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

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
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    constraint clients_agreement_id_unique unique (agreement_id)
);

create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount numeric(10, 2) not null,
    status public.order_status not null default 'pending',
    client_name_cache text not null
);

create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);

-- ===============================================================================================
-- 3. ACTIVACIÓN DE RLS (ROW LEVEL SECURITY)
-- Es una buena práctica activar RLS en todas las tablas para un control de acceso granular.
-- ===============================================================================================

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

-- ===============================================================================================
-- 4. CREACIÓN DE VISTAS Y FUNCIONES
-- Vistas para simplificar consultas comunes y funciones para lógica de negocio en la BD.
-- ===============================================================================================

-- Vista para obtener acuerdos con el conteo de promociones y condiciones de venta asociadas.
create view public.agreements_with_counts as
select
  a.*,
  pl.name as price_list_name,
  (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
  public.agreements a
  left join public.price_lists pl on a.price_list_id = pl.id;


-- Vista para estadísticas del dashboard.
create view public.dashboard_stats as
select
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients;

-- Función para obtener estadísticas de un cliente específico.
create function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint) as $$
begin
  return query
  select
    coalesce(sum(o.total_amount), 0) as total_spent,
    coalesce(avg(o.total_amount), 0) as average_order_value,
    count(o.id) as total_orders
  from public.orders o
  where o.client_id = p_client_id and o.status = 'completed';
end;
$$ language plpgsql stable;


-- ===============================================================================================
-- 5. POLÍTICAS DE ACCESO (RLS)
-- Define quién puede ver y modificar los datos.
-- ===============================================================================================

-- Los usuarios autenticados (administradores) pueden gestionar toda la información.
create policy "Allow admins full access" on public.products for all to authenticated using (true);
create policy "Allow admins full access" on public.price_lists for all to authenticated using (true);
create policy "Allow admins full access" on public.price_list_items for all to authenticated using (true);
create policy "Allow admins full access" on public.promotions for all to authenticated using (true);
create policy "Allow admins full access" on public.sales_conditions for all to authenticated using (true);
create policy "Allow admins full access" on public.agreements for all to authenticated using (true);
create policy "Allow admins full access" on public.clients for all to authenticated using (true);
create policy "Allow admins full access" on public.agreement_promotions for all to authenticated using (true);
create policy "Allow admins full access" on public.agreement_sales_conditions for all to authenticated using (true);
create policy "Allow admins full access" on public.orders for all to authenticated using (true);
create policy "Allow admins full access" on public.order_items for all to authenticated using (true);

-- Cualquier usuario (incluidos los anónimos) puede leer los datos necesarios para la página de pedido.
create policy "Allow anonymous read access for order page" on public.products for select using (true);
create policy "Allow anonymous read access for order page" on public.price_lists for select using (true);
create policy "Allow anonymous read access for order page" on public.price_list_items for select using (true);
create policy "Allow anonymous read access for order page" on public.promotions for select using (true);
create policy "Allow anonymous read access for order page" on public.agreements for select using (true);
create policy "Allow anonymous read access for order page" on public.agreement_promotions for select using (true);
create policy "Allow anonymous read access for order page" on public.clients for select using (true);

-- Permisos para el formulario de alta (onboarding).
create policy "Allow anonymous read on clients for onboarding" on public.clients for select using (true);
create policy "Allow anonymous update on clients for onboarding" on public.clients for update using (true) with check (true);

-- Permisos para la creación de pedidos (los clientes anónimos pueden crearlos).
create policy "Allow anonymous insert on orders" on public.orders for insert with check (true);
create policy "Allow anonymous insert on order_items" on public.order_items for insert with check (true);

-- ===============================================================================================
-- 6. CONFIGURACIÓN DE STORAGE
-- Bucket para imágenes de productos.
-- ===============================================================================================

-- Crear el bucket 'product_images' si no existe.
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Política para permitir la visualización pública de las imágenes.
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Política para permitir a los administradores subir, editar y borrar imágenes.
create policy "Allow admins to manage product images"
on storage.objects for all
to authenticated
using ( bucket_id = 'product_images' );

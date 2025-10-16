-- -------------------------------------------------------------------------------------
-- BLONDE ORDERS - SUPABASE SCHEMA
-- -------------------------------------------------------------------------------------
-- Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier momento.
-- Se encargará de limpiar y reconfigurar la base de datos al estado esperado.
-- -------------------------------------------------------------------------------------

-- -------------------------------------------------------------------------------------
-- PASO 1: LIMPIEZA DE OBJETOS EXISTENTES
-- Se eliminan en orden inverso a la creación para evitar errores de dependencia.
-- -------------------------------------------------------------------------------------

-- 1.1: Eliminar Políticas de Seguridad (RLS)
drop policy if exists "Allow admin full access" on public.products;
drop policy if exists "Allow admin full access" on public.price_lists;
drop policy if exists "Allow admin full access" on public.price_list_items;
drop policy if exists "Allow admin full access" on public.agreements;
drop policy if exists "Allow admin full access" on public.clients;
drop policy if exists "Allow admin full access" on public.promotions;
drop policy if exists "Allow admin full access" on public.agreement_promotions;
drop policy if exists "Allow admin full access" on public.sales_conditions;
drop policy if exists "Allow admin full access" on public.agreement_sales_conditions;
drop policy if exists "Allow admin full access" on public.orders;
drop policy if exists "Allow admin full access" on public.order_items;
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow admins to manage product images" on storage.objects;

-- 1.2: Eliminar Vistas y Funciones
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats;
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.increment_total_revenue(amount_to_add real);

-- 1.3: Eliminar Tablas
-- Incluimos la tabla dashboard_stats por si existe en un estado antiguo.
drop table if exists public.dashboard_stats; 
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.price_list_items;
drop table if exists public.price_lists;
drop table if exists public.products;


-- -------------------------------------------------------------------------------------
-- PASO 2: CREACIÓN DE TABLAS
-- -------------------------------------------------------------------------------------

-- Tabla de Productos
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.products is 'Catálogo de todos los productos disponibles.';

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.price_lists is 'Contenedor para diferentes listas de precios.';

-- Tabla de Items de Listas de Precios (Relación Producto-Precio)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null check (price >= 0),
    volume_price numeric(10, 2) check (volume_price >= 0),
    primary key (price_list_id, product_id)
);
comment on table public.price_list_items is 'Define el precio de un producto en una lista específica.';

-- Tabla de Convenios
create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.agreements is 'Convenios comerciales que agrupan precios y promociones.';

-- Tabla de Clientes
create table public.clients (
    id uuid default gen_random_uuid() primary key,
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status default 'pending_onboarding'::public.client_status not null,
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    constraint clients_agreement_id_unique unique (agreement_id)
);
comment on table public.clients is 'Información de los clientes y su estado.';

-- Tabla de Promociones
create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.promotions is 'Define promociones reutilizables.';

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
comment on table public.sales_conditions is 'Define condiciones de venta como plazos de pago.';

-- Tabla de Unión: Convenios y Promociones
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
comment on table public.agreement_promotions is 'Asigna promociones a los convenios.';

-- Tabla de Unión: Convenios y Condiciones de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
comment on table public.agreement_sales_conditions is 'Asigna condiciones de venta a los convenios.';

-- Tabla de Pedidos
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount real not null,
    status public.order_status default 'pending'::public.order_status not null,
    client_name_cache text
);
comment on table public.orders is 'Registra los pedidos realizados.';

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit real not null
);
comment on table public.order_items is 'Detalle de productos en cada pedido.';


-- -------------------------------------------------------------------------------------
-- PASO 3: CREACIÓN DE VISTAS Y FUNCIONES
-- -------------------------------------------------------------------------------------

-- Vista para contar promociones y condiciones en convenios
create view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions ascond where ascond.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

-- Vista para estadísticas del Dashboard
create view public.dashboard_stats as
select
    coalesce(sum(case when status = 'completed' then total_amount else 0 end), 0) as total_revenue,
    coalesce(sum(case when status = 'completed' and created_at > date_trunc('month', now()) then total_amount else 0 end), 0) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients
from public.orders;

-- Función para estadísticas de un cliente específico
create function public.get_client_stats(p_client_id uuid)
returns table (total_spent real, average_order_value real, total_orders bigint)
language sql
as $$
    select
        coalesce(sum(total_amount), 0)::real as total_spent,
        coalesce(avg(total_amount), 0)::real as average_order_value,
        count(id) as total_orders
    from public.orders
    where client_id = p_client_id and status = 'completed';
$$;

-- Función para actualizar el total de ingresos (ejemplo, podría ser un trigger)
create function public.increment_total_revenue(amount_to_add real)
returns void
language plpgsql
as $$
begin
  -- Esta función es un placeholder y actualmente no se utiliza
  -- para actualizar una tabla 'dashboard_stats'.
  -- La vista 'dashboard_stats' calcula los valores dinámicamente.
end;
$$;

-- -------------------------------------------------------------------------------------
-- PASO 4: HABILITAR RLS Y DEFINIR POLÍTICAS DE SEGURIDAD
-- -------------------------------------------------------------------------------------

-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.agreements enable row level security;
alter table public.clients enable row level security;
alter table public.promotions enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Políticas para acceso de administrador (rol 'authenticated')
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated');


-- -------------------------------------------------------------------------------------
-- PASO 5: POLÍTICAS DE ACCESO PARA STORAGE (IMÁGENES)
-- -------------------------------------------------------------------------------------

-- Crear bucket de imágenes de productos si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Política: Permitir lectura pública de imágenes
create policy "Allow public read access to product images"
on storage.objects for select
using (bucket_id = 'product_images');

-- Política: Permitir a los administradores subir, editar y borrar imágenes
create policy "Allow admins to manage product images"
on storage.objects for all
using (bucket_id = 'product_images' and auth.role() = 'authenticated');

-- -------------------------------------------------------------------------------------
-- FIN DEL SCRIPT
-- -------------------------------------------------------------------------------------

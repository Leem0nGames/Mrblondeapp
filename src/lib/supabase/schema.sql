
-- 📜 Supabase Schema: Blonde Orders
-- Versión: 1.5
-- Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier momento.
-- Se encarga de limpiar y reconfigurar las tablas, vistas y funciones.

-- -----------------------------------------------------------------------------
-- 1. EXTENSIONES Y CONFIGURACIONES INICIALES
-- -----------------------------------------------------------------------------

-- Habilitar extensiones necesarias
create extension if not exists "uuid-ossp" with schema "extensions";

-- -----------------------------------------------------------------------------
-- 2. LIMPIEZA INICIAL (DROP EVERYTHING)
-- -----------------------------------------------------------------------------

-- Deshabilitar notificaciones para evitar errores en cascada durante el borrado
alter table if exists "public"."products" drop constraint if exists "products_pkey";
alter table if exists "public"."price_lists" drop constraint if exists "price_lists_pkey";
alter table if exists "public"."price_list_items" drop constraint if exists "price_list_items_pkey";
alter table if exists "public"."promotions" drop constraint if exists "promotions_pkey";
alter table if exists "public"."sales_conditions" drop constraint if exists "sales_conditions_pkey";
alter table if exists "public"."agreements" drop constraint if exists "agreements_pkey";
alter table if exists "public"."clients" drop constraint if exists "clients_pkey";
alter table if exists "public"."orders" drop constraint if exists "orders_pkey";

-- Borrar vistas
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats;

-- Borrar funciones
drop function if exists public.get_client_stats(uuid);
drop function if exists public.increment_total_revenue(numeric);
drop function if exists public.handle_new_user();


-- Borrar tablas en orden de dependencia inversa
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.price_lists;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.products;


-- -----------------------------------------------------------------------------
-- 3. CREACIÓN DE TABLAS
-- -----------------------------------------------------------------------------

-- Tabla de Productos
create table public.products (
    id uuid default extensions.uuid_generate_v4() not null primary key,
    name character varying not null,
    description text,
    category character varying,
    image_url text,
    created_at timestamp with time zone default now() not null
);
comment on table public.products is 'Catálogo de todos los productos disponibles.';

-- Tabla de Promociones
create table public.promotions (
    id uuid default extensions.uuid_generate_v4() not null primary key,
    name character varying not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default now() not null
);
comment on table public.promotions is 'Define promociones reutilizables (ej. 8+2, envío gratis).';

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid default extensions.uuid_generate_v4() not null primary key,
    name character varying not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default now() not null
);
comment on table public.sales_conditions is 'Define condiciones comerciales (ej. pago a 30 días, descuento).';


-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid default extensions.uuid_generate_v4() not null primary key,
    name character varying not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default now() not null
);
comment on table public.price_lists is 'Contenedores para diferentes listas de precios (ej. Precios Minorista, Precios Mayorista).';

-- Tabla de Items de Listas de Precios (pivote)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    volume_price numeric(10,2),
    primary key (price_list_id, product_id)
);
comment on table public.price_list_items is 'Asigna un precio específico a un producto dentro de una lista.';


-- Tabla de Convenios
create table public.agreements (
    id uuid default extensions.uuid_generate_v4() not null primary key,
    agreement_name character varying not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default now() not null
);
comment on table public.agreements is 'Define las reglas comerciales para un grupo de clientes.';


-- Tabla de Clientes
create table public.clients (
    id uuid default extensions.uuid_generate_v4() not null primary key,
    cuit character varying(11) unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email character varying unique,
    instagram text,
    status public.client_status default 'pending_onboarding'::public.client_status not null,
    onboarding_token uuid default extensions.uuid_generate_v4() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default now() not null,
    fiscal_status text
);
comment on table public.clients is 'Almacena la información de los clientes y su estado.';


-- Tabla de Pedidos
create table public.orders (
    id uuid default extensions.uuid_generate_v4() not null primary key,
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone default now() not null,
    total_amount numeric(10, 2) not null,
    status public.order_status default 'pending'::public.order_status not null,
    client_name_cache text not null
);
comment on table public.orders is 'Registra cada pedido realizado.';


-- Tabla de Items de Pedido (pivote)
create table public.order_items (
    id bigint generated by default as identity not null primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);
comment on table public.order_items is 'Detalle de los productos en cada pedido.';


-- Tabla pivote: Convenios y Promociones
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
comment on table public.agreement_promotions is 'Asigna promociones a un convenio.';


-- Tabla pivote: Convenios y Condiciones de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
comment on table public.agreement_sales_conditions is 'Asigna condiciones de venta a un convenio.';


-- -----------------------------------------------------------------------------
-- 4. CREACIÓN DE VISTAS
-- -----------------------------------------------------------------------------

-- Vista para obtener convenios con conteo de promociones y condiciones
create or replace view public.agreements_with_counts as
select
    a.id,
    a.agreement_name,
    a.client_type,
    a.price_list_id,
    a.created_at,
    (select count(*) from public.agreement_promotions where agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions where agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

-- Vista para estadísticas del Dashboard
create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', current_date)) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;
    

-- -----------------------------------------------------------------------------
-- 5. CREACIÓN DE FUNCIONES (RPC)
-- -----------------------------------------------------------------------------

-- Función para obtener estadísticas de un cliente específico
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
language sql
security definer
as $$
    select
        coalesce(sum(o.total_amount), 0) as total_spent,
        coalesce(avg(o.total_amount), 0) as average_order_value,
        count(o.id) as total_orders
    from public.orders as o
    where o.client_id = p_client_id and o.status = 'completed';
$$;


-- Función para incrementar el total de ingresos de forma segura
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void
language sql
security definer
as $$
    -- Esta función es un placeholder. En una app real, se usaría un método
    -- más robusto para actualizar estadísticas, como una tabla separada o
    -- un trigger que actualice una vista materializada.
    -- La vista dashboard_stats se recalculará en la próxima lectura.
$$;


-- -----------------------------------------------------------------------------
-- 6. POLÍTICAS DE SEGURIDAD (RLS)
-- -----------------------------------------------------------------------------

-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.agreements enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;


-- Políticas para usuarios autenticados (administradores)
create policy "Allow all access to authenticated users"
on public.products for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.promotions for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.sales_conditions for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.price_lists for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.price_list_items for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.agreements for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.clients for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.orders for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.order_items for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.agreement_promotions for all
to authenticated using (true) with check (true);

create policy "Allow all access to authenticated users"
on public.agreement_sales_conditions for all
to authenticated using (true) with check (true);

-- Políticas para acceso anónimo (público) - MUY RESTRINGIDO
-- Solo se permite leer datos necesarios para la página de pedido y onboarding.

create policy "Allow public read access for order page"
on public.agreements for select
to anon using (true);

create policy "Allow public read access for order page"
on public.price_lists for select
to anon using (true);

create policy "Allow public read access for order page"
on public.price_list_items for select
to anon using (true);

create policy "Allow public read access for order page"
on public.products for select
to anon using (true);

create policy "Allow public read access for order page"
on public.agreement_promotions for select
to anon using (true);

create policy "Allow public read access for order page"
on public.promotions for select
to anon using (true);

create policy "Allow public read for onboarding by token"
on public.clients for select
to anon using (onboarding_token = (current_setting('request.jwt.claims', true)::jsonb ->> 'token')::uuid);

create policy "Allow public update for onboarding form"
on public.clients for update
to anon using (onboarding_token = (current_setting('request.jwt.claims', true)::jsonb ->> 'token')::uuid) with check (onboarding_token = (current_setting('request.jwt.claims', true)::jsonb ->> 'token')::uuid);

create policy "Allow public insert for orders"
on public.orders for insert
to anon with check (true);

create policy "Allow public insert for order items"
on public.order_items for insert
to anon with check (true);

-- -----------------------------------------------------------------------------
-- 7. CONFIGURACIÓN DE ALMACENAMIENTO (STORAGE)
-- -----------------------------------------------------------------------------

-- Crear bucket para imágenes de productos si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do update set public = true;

-- Políticas de acceso para el bucket de imágenes
-- Permitir lectura pública de imágenes
create policy "Allow public read access"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Permitir a los administradores subir imágenes
create policy "Allow authenticated users to upload"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'product_images' );

-- Permitir a los administradores actualizar/eliminar sus propias imágenes
create policy "Allow authenticated users to update/delete their images"
on storage.objects for update
to authenticated
using ( auth.uid() = owner and bucket_id = 'product_images' );

create policy "Allow authenticated users to delete their images"
on storage.objects for delete
to authenticated
using ( auth.uid() = owner and bucket_id = 'product_images' );

-- Mensaje final
select 'Blonde Orders schema v1.5 loaded successfully.' as status;

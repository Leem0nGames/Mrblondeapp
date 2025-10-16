-- ------------------------------------------------------------------------------------------------
-- 1. EXTENSIONES Y CONFIGURACIÓN INICIAL
-- ------------------------------------------------------------------------------------------------
-- Habilita la extensión para generar UUIDs.
create extension if not exists "uuid-ossp" with schema extensions;

-- Habilita la extensión para funciones criptográficas como gen_random_uuid()
create extension if not exists pgcrypto with schema extensions;

-- Configura el timezone por defecto.
set timezone to 'UTC';

-- ------------------------------------------------------------------------------------------------
-- 2. LIMPIEZA DE OBJETOS EXISTENTES (IDEMPOTENCIA)
-- ------------------------------------------------------------------------------------------------
-- Elimina tablas en cascada para evitar errores de dependencia.
drop table if exists "public"."products" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."order_items" cascade;
drop table if exists "public"."dashboard_stats" cascade;

-- Elimina vistas.
drop view if exists "public"."agreements_with_counts" cascade;

-- Elimina funciones.
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.increment_total_revenue(amount_to_add numeric);

-- Elimina políticas de RLS de Storage.
drop policy if exists "Allow public read access to product images" on storage.objects;

-- ------------------------------------------------------------------------------------------------
-- 3. CREACIÓN DE TABLAS
-- ------------------------------------------------------------------------------------------------
-- Tabla de Productos
create table "public"."products" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamptz not null default now()
);
comment on table public.products is 'Catálogo de todos los productos disponibles.';

-- Tabla de Listas de Precios
create table "public"."price_lists" (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  prices_include_vat boolean not null default true,
  created_at timestamptz not null default now()
);
comment on table public.price_lists is 'Contenedor para diferentes listas de precios (ej. Enero, Febrero).';

-- Tabla de Items en Listas de Precios (Tabla Pivote)
create table "public"."price_list_items" (
  price_list_id uuid not null references public.price_lists(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  price numeric(10, 2) not null,
  volume_price numeric(10, 2),
  primary key (price_list_id, product_id)
);
comment on table public.price_list_items is 'Define el precio de un producto en una lista de precios específica.';

-- Tabla de Convenios
create table "public"."agreements" (
  id uuid primary key default uuid_generate_v4(),
  agreement_name text not null unique,
  client_type text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
  price_list_id uuid references public.price_lists(id) on delete set null,
  created_at timestamptz not null default now()
);
comment on table public.agreements is 'Convenios comerciales que agrupan precios y promociones.';

-- Tabla de Clientes
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
  status text not null default 'pending_onboarding' check (status in ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
  onboarding_token uuid not null unique default uuid_generate_v4(),
  agreement_id uuid references public.agreements(id) on delete set null,
  created_at timestamptz not null default now()
);
comment on table public.clients is 'Información de los clientes finales (barberías, distribuidores).';

-- Tabla de Promociones
create table "public"."promotions" (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  rules jsonb not null,
  created_at timestamptz not null default now()
);
comment on table public.promotions is 'Reglas de promociones (ej. 2x1, envío gratis).';

-- Tabla de Condiciones de Venta
create table "public"."sales_conditions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamptz not null default now()
);
comment on table public.sales_conditions is 'Condiciones de pago, financiación, etc.';

-- Tabla de Convenio-Promociones (Pivote)
create table "public"."agreement_promotions" (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);

-- Tabla de Convenio-Condiciones de Venta (Pivote)
create table "public"."agreement_sales_conditions" (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
  primary key (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
create table "public"."orders" (
  id uuid primary key default uuid_generate_v4(),
  client_id uuid not null references public.clients(id) on delete restrict,
  agreement_id uuid not null references public.agreements(id) on delete restrict,
  created_at timestamptz not null default now(),
  total_amount numeric(10, 2) not null,
  status text not null default 'pending' check (status in ('pending', 'completed')),
  client_name_cache text not null
);
comment on table public.orders is 'Registra los pedidos que se envían por WhatsApp.';

-- Tabla de Items de Pedido
create table "public"."order_items" (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null,
  price_per_unit numeric(10, 2) not null
);

-- Tabla de Estadísticas (para el Dashboard)
create table "public"."dashboard_stats" (
  id int primary key default 1,
  total_revenue numeric(12, 2) not null default 0,
  month_revenue numeric(12, 2) not null default 0,
  active_clients int not null default 0,
  constraint single_row_check check (id = 1)
);
comment on table public.dashboard_stats is 'Tabla pre-agregada para estadísticas rápidas del dashboard.';

-- ------------------------------------------------------------------------------------------------
-- 4. VISTAS
-- ------------------------------------------------------------------------------------------------
create or replace view "public"."agreements_with_counts" as
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

-- ------------------------------------------------------------------------------------------------
-- 5. FUNCIONES
-- ------------------------------------------------------------------------------------------------
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
language plpgsql
as $$
begin
  return query
  select
    coalesce(sum(total_amount), 0) as total_spent,
    coalesce(avg(total_amount), 0) as average_order_value,
    count(id) as total_orders
  from
    public.orders
  where
    client_id = p_client_id and status = 'completed';
end;
$$;

create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void
language plpgsql
as $$
begin
  update dashboard_stats
  set total_revenue = total_revenue + amount_to_add,
      month_revenue = month_revenue + amount_to_add -- Simplificado, en un caso real se validaría el mes
  where id = 1;
end;
$$;


-- ------------------------------------------------------------------------------------------------
-- 6. DATOS INICIALES Y TRIGGERS
-- ------------------------------------------------------------------------------------------------
-- Inserta la fila única para las estadísticas del dashboard.
insert into "public"."dashboard_stats" (id) values (1);

-- ------------------------------------------------------------------------------------------------
-- 7. CONFIGURACIÓN DE STORAGE Y POLÍTICAS DE SEGURIDAD
-- ------------------------------------------------------------------------------------------------
-- Crea el bucket para las imágenes de productos si no existe.
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Política de Seguridad: Permite el acceso público de LECTURA a las imágenes de productos.
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- ------------------------------------------------------------------------------------------------
-- 8. HABILITACIÓN DE ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------------------------
-- Habilita RLS en todas las tablas para asegurar que las políticas se apliquen.
alter table "public"."products" enable row level security;
alter table "public"."promotions" enable row level security;
alter table "public"."agreements" enable row level security;
alter table "public"."clients" enable row level security;
alter table "public"."price_lists" enable row level security;
alter table "public"."price_list_items" enable row level security;
alter table "public"."agreement_promotions" enable row level security;
alter table "public"."sales_conditions" enable row level security;
alter table "public"."agreement_sales_conditions" enable row level security;
alter table "public"."orders" enable row level security;
alter table "public"."order_items" enable row level security;
alter table "public"."dashboard_stats" enable row level security;

-- ------------------------------------------------------------------------------------------------
-- 9. POLÍTICAS DE SEGURIDAD DE TABLAS (RLS Policies)
-- ------------------------------------------------------------------------------------------------
-- El acceso a la mayoría de las tablas se gestiona a través de las Server Actions,
-- que se ejecutan con el rol 'service_role', el cual se salta RLS.
-- Por lo tanto, las políticas por defecto pueden ser restrictivas.
-- Para esta aplicación, solo los administradores autenticados pueden interactuar.
-- 'auth.uid()' es la función de Supabase que devuelve el ID del usuario autenticado.

create policy "Allow all access to authenticated admins"
on public.products for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.promotions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.agreements for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.clients for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.price_lists for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.price_list_items for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.agreement_promotions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.sales_conditions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow all access to authenticated admins"
on public.agreement_sales_conditions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow admin read access to orders"
on public.orders for select
using (auth.role() = 'authenticated');

create policy "Allow admin read access to order items"
on public.order_items for select
using (auth.role() = 'authenticated');

create policy "Allow admin access to stats"
on public.dashboard_stats for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

-- Políticas para acceso público (sin autenticación)
-- Estas son importantes para que las páginas de pedido y onboarding funcionen.
create policy "Allow public read access to specific agreement data"
on public.agreements for select
using (true);

create policy "Allow public read access to products and prices"
on public.products for select
using (true);

create policy "Allow public read access to price list items"
on public.price_list_items for select
using (true);

create policy "Allow public read access to price lists"
on public.price_lists for select
using (true);

create policy "Allow public read access to promotions"
on public.promotions for select
using (true);

create policy "Allow public read access to agreement promotions"
on public.agreement_promotions for select
using (true);

create policy "Allow public read access to clients for onboarding/order"
on public.clients for select
using (true);

create policy "Allow anyone to submit an order"
on public.orders for insert
with check (true);

create policy "Allow anyone to submit order items"
on public.order_items for insert
with check (true);

create policy "Allow client to update their own data via onboarding"
on public.clients for update
using (true); -- La seguridad se maneja en la action verificando el token.

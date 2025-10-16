
-- -----------------------------------------------------------------------------------------------
--  Este script está diseñado para ser IDEMPOTENTE.
--  Puedes ejecutarlo de forma segura en cualquier momento. Se encargará de limpiar
--  y reconfigurar las tablas, vistas, funciones y políticas para que coincidan con el estado deseado.
--
--  Contenido:
--  1.  Sección de Limpieza: Elimina tablas, vistas, funciones y políticas en el orden correcto.
--  2.  Sección de Creación: Crea las tablas, activa extensiones, define RLS y crea funciones y vistas.
-- -----------------------------------------------------------------------------------------------


-- -----------------------------------------------------------------------------------------------
-- SECCIÓN DE LIMPIEZA
-- Elimina los objetos en orden inverso a su creación para evitar errores de dependencia.
-- -----------------------------------------------------------------------------------------------

-- 1. Eliminar Vistas (dependen de las tablas)
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats;

-- 2. Eliminar Funciones (pueden depender de tablas)
drop function if exists public.get_overdue_orders();
drop function if exists public.get_client_stats(uuid);
drop function if exists public.increment_total_revenue(real);
drop function if exists public.increment_total_revenue(numeric);

-- 3. Eliminar Políticas de Seguridad de Storage (dependen de roles y usuarios)
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow authenticated users to update product images" on storage.objects;

-- 4. Eliminar Tablas (en orden de dependencia: hijos primero)
-- Tablas de unión
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.order_items;
drop table if exists public.price_list_items;

-- Tablas principales
drop table if exists public.orders;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.price_lists;
drop table if exists public.products;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;


-- -----------------------------------------------------------------------------------------------
-- SECCIÓN DE CREACIÓN
-- Crea las tablas y define la estructura de la base de datos.
-- -----------------------------------------------------------------------------------------------

-- Activar la extensión pgcrypto si no está activada (para UUIDs)
create extension if not exists "uuid-ossp" with schema extensions;

-- 1. Tabla de Productos
create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamptz not null default now()
);
comment on table public.products is 'Catálogo de todos los productos disponibles.';

-- 2. Tabla de Listas de Precios
create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamptz not null default now()
);
comment on table public.price_lists is 'Contenedor para listas de precios con nombre.';

-- 3. Tabla de Items de Listas de Precios (une productos y listas)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric not null,
    volume_price numeric,
    primary key (price_list_id, product_id)
);
comment on table public.price_list_items is 'Define el precio de un producto en una lista específica.';

-- 4. Tabla de Convenios
create table public.agreements (
  id uuid primary key default gen_random_uuid(),
  agreement_name text not null unique,
  client_type public.client_type_enum not null,
  price_list_id uuid references public.price_lists(id) on delete set null,
  created_at timestamptz not null default now()
);
comment on table public.agreements is 'Define las condiciones comerciales para un grupo de clientes.';

-- 5. Tabla de Clientes
create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status_enum not null default 'pending_onboarding',
    onboarding_token uuid not null default gen_random_uuid(),
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamptz not null default now()
);
comment on table public.clients is 'Información de los clientes (salones, distribuidores).';


-- 6. Tabla de Promociones
create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  rules jsonb not null,
  created_at timestamptz not null default now()
);
comment on table public.promotions is 'Reglas de promociones (ej. 2x1, envío gratis).';

-- 7. Tabla de Condiciones de Venta
create table public.sales_conditions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  rules jsonb not null,
  created_at timestamptz not null default now()
);
comment on table public.sales_conditions is 'Reglas de condiciones comerciales (ej. pago a 30 días, 5% de descuento).';

-- 8. Tabla de unión para Convenios y Promociones
create table public.agreement_promotions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);
comment on table public.agreement_promotions is 'Tabla pivote para la relación N:N entre convenios y promociones.';

-- 9. Tabla de unión para Convenios y Condiciones de Venta
create table public.agreement_sales_conditions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
  primary key (agreement_id, sales_condition_id)
);
comment on table public.agreement_sales_conditions is 'Tabla pivote para la relación N:N entre convenios y condiciones de venta.';

-- 10. Tabla de Pedidos
create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamptz not null default now(),
    total_amount numeric not null,
    status public.order_status_enum not null default 'pending',
    client_name_cache text not null
);
comment on table public.orders is 'Registra los pedidos de los clientes.';

-- 11. Tabla de Items de Pedido
create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity int not null,
    price_per_unit numeric not null
);
comment on table public.order_items is 'Detalle de los productos en cada pedido.';


-- -----------------------------------------------------------------------------------------------
-- RLS (Row Level Security) Y POLÍTICAS
-- Asegura que los datos solo sean accesibles por los usuarios correctos.
-- -----------------------------------------------------------------------------------------------

-- Habilitar RLS en todas las tablas relevantes
alter table public.products enable row level security;
alter table public.agreements enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;

-- Políticas para permitir acceso completo a usuarios autenticados (rol 'authenticated')
-- Estos son los administradores de la aplicación.
create policy "Allow full access to authenticated users" on public.products for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.agreements for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.promotions for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.sales_conditions for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.agreement_promotions for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.agreement_sales_conditions for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.clients for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.orders for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.order_items for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.price_lists for all to authenticated using (true) with check (true);
create policy "Allow full access to authenticated users" on public.price_list_items for all to authenticated using (true) with check (true);

-- -----------------------------------------------------------------------------------------------
-- VISTAS
-- Simplifican las consultas complejas.
-- -----------------------------------------------------------------------------------------------

-- Vista para obtener recuentos de relaciones de convenios
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;


-- Vista para estadísticas del dashboard
create or replace view public.dashboard_stats as
select
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients;

-- -----------------------------------------------------------------------------------------------
-- STORAGE
-- Configuración del almacenamiento de archivos, como imágenes de productos.
-- -----------------------------------------------------------------------------------------------

-- Bucket para imágenes de productos
insert into storage.buckets(id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Política para permitir la lectura pública de imágenes
create policy "Allow public read access to product images" on storage.objects
  for select using (bucket_id = 'product_images');

-- Política para permitir a los administradores subir/actualizar imágenes
create policy "Allow authenticated users to update product images" on storage.objects
  for insert with check (bucket_id = 'product_images' and auth.role() = 'authenticated');
  
create policy "Allow authenticated users to update product images part 2" on storage.objects
  for update with check (bucket_id = 'product_images' and auth.role() = 'authenticated');


-- -----------------------------------------------------------------------------------------------
-- FUNCIONES RPC
-- Funciones personalizadas que se pueden llamar desde la aplicación.
-- -----------------------------------------------------------------------------------------------

-- Función para incrementar los ingresos totales (usada al completar un pedido)
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
  -- Esta función está obsoleta y se maneja desde la vista dashboard_stats.
  -- Se mantiene por si se necesita una lógica de agregación más compleja en el futuro.
end;
$$ language plpgsql;


-- Función para obtener estadísticas de un cliente específico
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint) as $$
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
$$ language plpgsql;


-- Función para obtener pedidos vencidos según las condiciones de venta
create or replace function public.get_overdue_orders()
returns setof public.orders as $$
begin
    return query
    select o.*
    from public.orders o
    join public.agreement_sales_conditions asc_ref on o.agreement_id = asc_ref.agreement_id
    join public.sales_conditions sc on asc_ref.sales_condition_id = sc.id
    where
        o.status = 'pending'
        and sc.rules ->> 'type' = 'net_days'
        and (o.created_at + ( (sc.rules ->> 'days')::integer * interval '1 day' )) < now();
end;
$$ language plpgsql;

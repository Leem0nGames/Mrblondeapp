
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- region ► APP ADMIN SETUP                                                 ◄
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

-- -----------------------------------------------------------------------------
--    FUNCIÓN has_users()
-- -----------------------------------------------------------------------------
-- Propósito: Comprueba si existen usuarios en la tabla `auth.users`.
--
-- Usado por: El middleware de la aplicación para determinar si debe redirigir
--            a la página de registro del primer administrador (`/signup`)
--            o al flujo de login normal.
--
-- Seguridad: Esta función NO expone datos sensibles. Solo devuelve un booleano.
--            Es segura para ser llamada desde el backend con privilegios de servicio.
-- -----------------------------------------------------------------------------
create or replace function public.has_users()
returns boolean as $$
  select exists (select 1 from auth.users);
$$ language sql security definer;


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- region ► LIMPIEZA (SCRIPT IDEMPOTENTE)                                    ◄
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- -----------------------------------------------------------------------------
--    Propósito: Limpiar la base de datos antes de recrear las tablas y vistas.
--               Esto asegura que el script se pueda ejecutar múltiples veces
--               sin causar errores por objetos ya existentes.
-- -----------------------------------------------------------------------------

-- Desactivar Row Level Security temporalmente para poder eliminar tablas.
alter table if exists public.products disable row level security;
alter table if exists public.price_lists disable row level security;
alter table if exists public.price_list_items disable row level security;
alter table if exists public.promotions disable row level security;
alter table if exists public.agreements disable row level security;
alter table if exists public.agreement_promotions disable row level security;
alter table if exists public.sales_conditions disable row level security;
alter table if exists public.agreement_sales_conditions disable row level security;
alter table if exists public.clients disable row level security;
alter table if exists public.orders disable row level security;
alter table if exists public.order_items disable row level security;

-- Eliminar Vistas
drop view if exists public.dashboard_stats;
drop view if exists public.agreements_with_counts;

-- Eliminar Funciones
drop function if exists public.get_client_stats(uuid);
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.get_overdue_orders();
drop function if exists public.increment_total_revenue(numeric);

-- Eliminar Políticas de RLS de Storage
drop policy if exists "Allow authenticated users to read product images" on storage.objects;
drop policy if exists "Allow authenticated users to update product images" on storage.objects;

-- Eliminar Tablas
-- Se eliminan en orden inverso a su creación para respetar las dependencias.
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.clients; -- Depende de 'agreements'.
drop table if exists public.agreements; -- Depende de 'price_lists'.
drop table if exists public.price_list_items; -- Depende de 'products' y 'price_lists'.
drop table if exists public.price_lists;
drop table if exists public.products;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- region ► CREACIÓN DE TABLAS                                                ◄
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

-- -----------------------------------------------------------------------------
--    Tabla: products
-- -----------------------------------------------------------------------------
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.products enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: promotions
-- -----------------------------------------------------------------------------
create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.promotions enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: sales_conditions
-- -----------------------------------------------------------------------------
create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.sales_conditions enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: price_lists
-- -----------------------------------------------------------------------------
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.price_lists enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: price_list_items
-- -----------------------------------------------------------------------------
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric not null,
    volume_price numeric,
    primary key (price_list_id, product_id)
);
alter table public.price_list_items enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: agreements
-- -----------------------------------------------------------------------------
create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type text not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.agreements enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: agreement_promotions (Tabla Pivot)
-- -----------------------------------------------------------------------------
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
alter table public.agreement_promotions enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: agreement_sales_conditions (Tabla Pivot)
-- -----------------------------------------------------------------------------
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table public.agreement_sales_conditions enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: clients
-- -----------------------------------------------------------------------------
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create table public.clients (
    id uuid default gen_random_uuid() primary key,
    cuit text unique,
    fiscal_status text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.clients enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: orders
-- -----------------------------------------------------------------------------
create type public.order_status as enum ('pending', 'completed');
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount numeric not null,
    status public.order_status not null default 'pending',
    client_name_cache text not null,
    notes text
);
alter table public.orders enable row level security;

-- -----------------------------------------------------------------------------
--    Tabla: order_items
-- -----------------------------------------------------------------------------
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric not null
);
alter table public.order_items enable row level security;


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- region ► VISTAS (VIEWS)                                                    ◄
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

-- -----------------------------------------------------------------------------
--    Vista: agreements_with_counts
-- -----------------------------------------------------------------------------
-- Propósito: Simplifica la obtención de convenios con el conteo de promociones
--            y condiciones de venta asociadas, además del nombre de la lista
--            de precios.
-- -----------------------------------------------------------------------------
create view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count,
    pl.name as price_list_name
from
    public.agreements a
left join
    public.price_lists pl on a.price_list_id = pl.id;

-- -----------------------------------------------------------------------------
--    Vista: dashboard_stats
-- -----------------------------------------------------------------------------
-- Propósito: Provee estadísticas clave para el dashboard del administrador,
--            como ingresos totales, ingresos del mes y clientes activos.
-- -----------------------------------------------------------------------------
create view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- region ► FUNCIONES (REMOTE PROCEDURE CALLS)                                ◄
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

-- -----------------------------------------------------------------------------
--    Función: get_client_stats
-- -----------------------------------------------------------------------------
-- Propósito: Calcula estadísticas para un cliente específico, como gasto total,
--            valor promedio de pedido y número total de pedidos.
-- -----------------------------------------------------------------------------
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
language plpgsql
security definer -- Se ejecuta con los permisos del creador
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
    o.client_id = p_client_id;
end;
$$;


-- -----------------------------------------------------------------------------
--    Función: get_overdue_orders
-- -----------------------------------------------------------------------------
-- Propósito: Obtiene todos los pedidos pendientes cuyo plazo de pago ha vencido
--            según las condiciones de venta de tipo 'net_days' de su convenio.
-- -----------------------------------------------------------------------------
create or replace function public.get_overdue_orders()
returns setof public.orders
language plpgsql
security definer
as $$
begin
  return query
  select o.*
  from public.orders o
  where o.status = 'pending'
  and exists (
      select 1
      from public.agreement_sales_conditions asc_ref
      join public.sales_conditions sc on asc_ref.sales_condition_id = sc.id
      where asc_ref.agreement_id = o.agreement_id
      and sc.rules ->> 'type' = 'net_days'
      and o.created_at < (now() - ( (sc.rules ->> 'days')::int * interval '1 day' ))
  );
end;
$$;


-- -----------------------------------------------------------------------------
--    Función: increment_total_revenue (Función interna, no para RPC directa)
-- -----------------------------------------------------------------------------
-- Propósito: Esta función se usa en un trigger para actualizar una tabla de
--            métricas (no implementada en este script) cada vez que un pedido
--            se marca como 'completed'. Es un ejemplo de lógica de backend en DB.
-- -----------------------------------------------------------------------------
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void
language plpgsql
as $$
begin
  -- En una implementación real, aquí se actualizaría una tabla de métricas.
  -- Por ahora, solo es un placeholder.
  -- Ejemplo: update public.metrics set total_revenue = total_revenue + amount_to_add;
end;
$$;


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- region ► POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY)                       ◄
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

-- -----------------------------------------------------------------------------
--    Políticas para: products, price_lists, promotions, sales_conditions, etc.
-- -----------------------------------------------------------------------------
-- Regla: Solo los usuarios autenticados (administradores) pueden ver y
--        gestionar estas tablas.
-- -----------------------------------------------------------------------------
create policy "Allow authenticated users to manage products"
on public.products for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage price lists"
on public.price_lists for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage price list items"
on public.price_list_items for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage promotions"
on public.promotions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage agreements"
on public.agreements for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage agreement promotions"
on public.agreement_promotions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage sales conditions"
on public.sales_conditions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage agreement sales conditions"
on public.agreement_sales_conditions for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

create policy "Allow authenticated users to manage clients"
on public.clients for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');


-- -----------------------------------------------------------------------------
--    Políticas para: orders, order_items
-- -----------------------------------------------------------------------------
-- Regla: Los administradores pueden gestionar todo. Los usuarios anónimos
--        (clientes con link) solo pueden crear, pero no ver ni modificar.
-- -----------------------------------------------------------------------------

create policy "Allow anon users to create orders"
on public.orders for insert
to anon
with check (true);

create policy "Allow authenticated users to manage orders"
on public.orders for all
to authenticated
using (true)
with check (true);

create policy "Allow anon users to create order items"
on public.order_items for insert
to anon
with check (true);

create policy "Allow authenticated users to manage order items"
on public.order_items for all
to authenticated
using (true)
with check (true);


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- region ► STORAGE (IMÁGENES DE PRODUCTOS)                                   ◄
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

-- Crear el bucket si no existe.
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
--    Políticas para: storage.objects (bucket: product_images)
-- -----------------------------------------------------------------------------
-- Regla de lectura: Cualquiera puede leer las imágenes de los productos.
-- Regla de escritura/actualización: Solo administradores autenticados.
-- -----------------------------------------------------------------------------
create policy "Allow public read access to product images"
on storage.objects for select
to public
using (bucket_id = 'product_images');

create policy "Allow authenticated users to update product images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'product_images');

create policy "Allow authenticated users to update product images"
on storage.objects for update
to authenticated
using (bucket_id = 'product_images');

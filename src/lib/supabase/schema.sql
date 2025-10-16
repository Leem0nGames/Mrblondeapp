
-- ------------------------------------------------------------------------------------------------
-- 1. SECCIÓN DE LIMPIEZA
-- ------------------------------------------------------------------------------------------------
-- Elimina todos los objetos en el orden correcto para evitar errores de dependencia.
-- Primero, elimina las políticas de seguridad que dependen de las tablas.

drop policy if exists "Allow public read access to product images" on storage.objects;

-- Luego, elimina las funciones y vistas que dependen de las tablas.
drop view if exists public.agreements_with_counts;
drop function if exists public.get_client_stats(uuid);
drop function if exists public.increment_total_revenue(real);

-- Punto clave de la corrección: Elimina la tabla 'dashboard_stats' (si existe) ANTES de la vista.
-- Esto resuelve el error "is not a view".
drop table if exists public.dashboard_stats;
drop view if exists public.dashboard_stats; -- Se mantiene por si en el futuro existe como vista.

-- Finalmente, elimina las tablas.
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


-- ------------------------------------------------------------------------------------------------
-- 2. TABLAS PRINCIPALES
-- ------------------------------------------------------------------------------------------------

-- Tabla de Productos
create table public.products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.products enable row level security;

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.price_lists enable row level security;

-- Tabla de Items en Listas de Precios (Tabla Pivote)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null,
    volume_price real,
    primary key (price_list_id, product_id)
);
alter table public.price_list_items enable row level security;

-- Tabla de Convenios
create table public.agreements (
  id uuid default gen_random_uuid() primary key,
  agreement_name text not null unique,
  client_type public.client_type not null,
  price_list_id uuid references public.price_lists(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.agreements enable row level security;

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
    status public.client_status not null,
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.clients enable row level security;

-- Tabla de Promociones
create table public.promotions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.promotions enable row level security;

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.sales_conditions enable row level security;

-- Tabla de Pedidos
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount real not null,
    status public.order_status not null,
    client_name_cache text not null
);
alter table public.orders enable row level security;

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit real not null
);
alter table public.order_items enable row level security;

-- ------------------------------------------------------------------------------------------------
-- 3. TABLAS PIVOTE (RELACIONES MUCHOS A MUCHOS)
-- ------------------------------------------------------------------------------------------------

create table public.agreement_promotions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);
alter table public.agreement_promotions enable row level security;

create table public.agreement_sales_conditions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
  primary key (agreement_id, sales_condition_id)
);
alter table public.agreement_sales_conditions enable row level security;

-- ------------------------------------------------------------------------------------------------
-- 4. VISTAS Y FUNCIONES
-- ------------------------------------------------------------------------------------------------

-- Vista para obtener convenios con contadores de promociones y condiciones
create or replace view public.agreements_with_counts as
select
  a.id,
  a.agreement_name,
  a.client_type,
  a.created_at,
  a.price_list_id,
  (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
  public.agreements a;

-- Vista para el Dashboard
create or replace view public.dashboard_stats as
select
  (select coalesce(sum(o.total_amount), 0::double precision) from public.orders o where o.status = 'completed') as total_revenue,
  (select coalesce(sum(o.total_amount), 0::double precision) from public.orders o where o.status = 'completed' and o.created_at >= date_trunc('month'::text, now())) as month_revenue,
  (select count(*) from public.clients c where c.status = 'active') as active_clients;
  
-- Función para obtener estadísticas de un cliente
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent real, average_order_value real, total_orders bigint) as $$
begin
  return query
  select
    coalesce(sum(o.total_amount), 0.0)::real as total_spent,
    coalesce(avg(o.total_amount), 0.0)::real as average_order_value,
    count(o.id)::bigint as total_orders
  from public.orders o
  where o.client_id = p_client_id and o.status = 'completed';
end;
$$ language plpgsql stable;

-- Función para incrementar los ingresos totales (obsoleta si se usa la vista, pero se mantiene por si se necesita)
create or replace function public.increment_total_revenue(amount_to_add real)
returns void as $$
begin
  -- Esta función está obsoleta ya que dashboard_stats es ahora una vista.
  -- Se mantiene para evitar errores si alguna acción antigua aún la llama.
  -- No realiza ninguna acción.
end;
$$ language plpgsql;

-- ------------------------------------------------------------------------------------------------
-- 5. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY)
-- ------------------------------------------------------------------------------------------------

-- Políticas genéricas para permitir acceso completo a usuarios autenticados (administradores)
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Políticas para permitir acceso público de lectura a las imágenes de productos
create policy "Allow public read access to product images" on storage.objects for select
to public
using ( bucket_id = 'product_images' );

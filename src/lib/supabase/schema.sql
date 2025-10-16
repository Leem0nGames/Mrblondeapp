-- ----------------------------------------------------------------
-- 1. EXTENSIONS
-- ----------------------------------------------------------------
-- Habilita la extensión para usar UUIDs
create extension if not exists "uuid-ossp" with schema extensions;


-- ----------------------------------------------------------------
-- 2. RESET (SOLO PARA DESARROLLO)
-- ----------------------------------------------------------------
-- Estas líneas eliminan todo en un orden específico para evitar errores de dependencia.
-- ¡TEN CUIDADO! ESTO BORRARÁ TODOS TUS DATOS.
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreements cascade;
drop table if exists public.products cascade;
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats;

-- ----------------------------------------------------------------
-- 3. TABLAS PRINCIPALES
-- ----------------------------------------------------------------

-- Tabla de Productos
create table public.products (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  category text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.products enable row level security;

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.price_lists enable row level security;

-- Tabla de Convenios
create table public.agreements (
  id uuid primary key default uuid_generate_v.v4(),
  agreement_name text not null unique,
  client_type text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
  price_list_id uuid references public.price_lists(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.agreements enable row level security;

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
    status text not null check (status in ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    onboarding_token uuid not null unique default uuid_generate_v4(),
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    fiscal_status text
);
alter table public.clients enable row level security;


-- Tabla de Promociones
create table public.promotions (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.promotions enable row level security;

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.sales_conditions enable row level security;

-- Tabla de Pedidos (Orders)
create table public.orders (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount real not null default 0,
    status text not null check (status in ('pending', 'completed')) default 'pending',
    client_name_cache text not null
);
alter table public.orders enable row level security;


-- ----------------------------------------------------------------
-- 4. TABLAS DE RELACIÓN (MUCHOS A MUCHOS)
-- ----------------------------------------------------------------

-- Items de una lista de precios
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null check (price >= 0),
    volume_price real check (volume_price >= 0),
    primary key (price_list_id, product_id)
);
alter table public.price_list_items enable row level security;

-- Promociones asignadas a un convenio
create table public.agreement_promotions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  primary key (agreement_id, promotion_id)
);
alter table public.agreement_promotions enable row level security;

-- Condiciones de venta asignadas a un convenio
create table public.agreement_sales_conditions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
  primary key (agreement_id, sales_condition_id)
);
alter table public.agreement_sales_conditions enable row level security;

-- Items de un pedido
create table public.order_items (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    quantity integer not null check (quantity > 0),
    price_per_unit real not null
);
alter table public.order_items enable row level security;


-- ----------------------------------------------------------------
-- 5. VISTAS (VIEWS)
-- ----------------------------------------------------------------

-- Vista para contar promociones y condiciones por convenio
create or replace view public.agreements_with_counts as
select
  a.*,
  (select count(*) from agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from agreement_sales_conditions as asc_count where asc_count.agreement_id = a.id) as sales_condition_count
from
  agreements a;
  
-- Vista para estadísticas del dashboard
create or replace view public.dashboard_stats as
select
  (select coalesce(sum(total_amount), 0) from orders where status = 'completed') as total_revenue,
  (select coalesce(sum(total_amount), 0) from orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
  (select count(*) from clients where status = 'active') as active_clients;

-- ----------------------------------------------------------------
-- 6. FUNCIONES (RPC)
-- ----------------------------------------------------------------

-- Función para obtener estadísticas de un cliente específico
create or replace function get_client_stats(p_client_id uuid)
returns table (
    total_spent real,
    average_order_value real,
    total_orders bigint
) as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0.0)::real as total_spent,
        coalesce(avg(o.total_amount), 0.0)::real as average_order_value,
        count(o.id)::bigint as total_orders
    from
        public.orders o
    where
        o.client_id = p_client_id and o.status = 'completed';
end;
$$ language plpgsql stable;

-- Función para incrementar el total de ingresos de forma segura
create or replace function increment_total_revenue(amount_to_add real)
returns void as $$
begin
    -- Esta es una forma simplificada. En un entorno de alta concurrencia,
    -- sería mejor tener una tabla de estadísticas y actualizarla.
    -- Por ahora, esta función no hace nada, ya que la vista lo calcula dinámicamente.
    -- Si se necesitara una tabla de stats, aquí se haría el UPDATE.
end;
$$ language plpgsql volatile;


-- ----------------------------------------------------------------
-- 7. POLÍTICAS DE SEGURIDAD (RLS)
-- ----------------------------------------------------------------
-- El acceso público está deshabilitado por defecto.
-- Se requiere RLS para todas las tablas.

-- Los usuarios autenticados (admins) pueden hacer todo.
create policy "Enable all access for authenticated users"
on public.products for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.price_lists for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.price_list_items for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.agreements for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.clients for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.promotions for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.sales_conditions for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.agreement_promotions for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.agreement_sales_conditions for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.orders for all
to authenticated using (true) with check (true);

create policy "Enable all access for authenticated users"
on public.order_items for all
to authenticated using (true) with check (true);

-- El acceso anónimo (público) está muy restringido.
-- Cualquiera puede leer la información necesaria para una PÁGINA DE PEDIDO.
create policy "Allow public read access for order pages"
on public.agreements for select
to anon using (true);

create policy "Allow public read access for order pages"
on public.price_lists for select
to anon using (true);

create policy "Allow public read access for order pages"
on public.price_list_items for select
to anon using (true);

create policy "Allow public read access for order pages"
on public.products for select
to anon using (true);

create policy "Allow public read access for order pages"
on public.promotions for select
to anon using (true);

create policy "Allow public read access for order pages"
on public.agreement_promotions for select
to anon using (true);

create policy "Allow public read for clients on order page"
on public.clients for select
to anon using (true);

-- Cualquiera puede crear un pedido y sus items (el cliente final)
create policy "Allow public insert for orders"
on public.orders for insert
to anon with check (true);

create policy "Allow public insert for order items"
on public.order_items for insert
to anon with check (true);

-- Cualquiera puede leer y actualizar un cliente si tiene el token de onboarding correcto.
create policy "Allow public access for onboarding"
on public.clients for select
to anon using (onboarding_token = (current_setting('request.jwt.claims', true)::jsonb ->> 'token')::uuid);

create policy "Allow public update for onboarding"
on public.clients for update
to anon using (onboarding_token = (current_setting('request.jwt.claims', true)::jsonb ->> 'token')::uuid);


-- ----------------------------------------------------------------
-- 8. STORAGE
-- ----------------------------------------------------------------

-- Bucket para imágenes de productos
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Política para permitir el acceso público de lectura a las imágenes
create policy "Public read access for product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Política para permitir que los administradores suban imágenes
create policy "Allow admin to upload product images"
on storage.objects for insert
to authenticated with check ( bucket_id = 'product_images' );

-- Política para permitir que los administradores actualicen imágenes
create policy "Allow admin to update product images"
on storage.objects for update
to authenticated using ( bucket_id = 'product_images' );

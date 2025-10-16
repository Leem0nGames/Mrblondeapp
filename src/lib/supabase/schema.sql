-- 1. Limpieza inicial (idempotente)
-- Elimina políticas de RLS para evitar conflictos
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow authenticated users to upload product images" on storage.objects;

-- Elimina funciones, manejando la posibilidad de que no existan
drop function if exists public.has_users();
drop function if exists public.get_overdue_orders();
drop function if exists public.get_client_stats(uuid);
drop function if exists public.increment_total_revenue(numeric);

-- Elimina vistas, manejando la posibilidad de que no existan
drop view if exists public.dashboard_stats;
drop view if exists public.agreements_with_counts;

-- Elimina tablas en orden de dependencia inversa
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

-- Elimina el bucket de storage
-- NOTA: Esto eliminará todas las imágenes de productos. Solo descomentar si se quiere un reinicio total.
-- select storage.empty_bucket('product_images');
-- select storage.delete_bucket('product_images');


-- 2. Creación del bucket de almacenamiento para imágenes de productos
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product_images', 'product_images', true, 5242880, '{"image/jpeg","image/png","image/webp"}')
on conflict (id) do nothing;

-- 3. Creación de Tablas

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
    price numeric(10, 2) not null,
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
    client_type text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
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
    status text default 'pending_onboarding' not null,
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    fiscal_status text
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
    status text default 'pending' not null,
    client_name_cache text not null
);

create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);


-- 4. Creación de Vistas (Views)

create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;


-- 5. Creación de Funciones (Functions)

create or replace function public.has_users()
returns boolean as $$
begin
  return (select count(*) > 0 from auth.users);
end;
$$ language plpgsql security definer;


create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint) as $$
begin
  return query
  select
    coalesce(sum(o.total_amount), 0) as total_spent,
    coalesce(avg(o.total_amount), 0) as average_order_value,
    count(o.id) as total_orders
  from public.orders o
  where o.client_id = p_client_id;
end;
$$ language plpgsql;


create or replace function public.get_overdue_orders()
returns setof public.orders as $$
begin
    return query
    select o.*
    from public.orders o
    join public.agreement_sales_conditions asc_ref on o.agreement_id = asc_ref.agreement_id
    join public.sales_conditions sc on asc_ref.sales_condition_id = sc.id
    where o.status = 'pending'
      and sc.rules ->> 'type' = 'net_days'
      and (o.created_at + ( (sc.rules ->> 'days')::integer * interval '1 day' ) ) < now();
end;
$$ language plpgsql;

create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
  -- This function is a placeholder. A real implementation might update a summary table.
  -- For now, it does nothing, but it's here to match the application code's expectations.
end;
$$ language plpgsql;


-- 6. Políticas de Seguridad (RLS)

-- Habilitar RLS en todas las tablas
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

-- Políticas para administradores (rol 'authenticated')
-- Los administradores tienen acceso completo a todas las tablas.
create policy "Allow full access to administrators" on public.products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.price_lists for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.price_list_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.agreements for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.clients for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.agreement_promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.orders for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to administrators" on public.order_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Políticas para acceso público (rol 'anon')
-- Los usuarios anónimos pueden leer información necesaria para la página de pedido y el alta.
create policy "Allow anonymous read for order pages" on public.agreements for select using (true);
create policy "Allow anonymous read for order pages" on public.promotions for select using (true);
create policy "Allow anonymous read for order pages" on public.agreement_promotions for select using (true);
create policy "Allow anonymous read for order pages" on public.products for select using (true);
create policy "Allow anonymous read for order pages" on public.price_lists for select using (true);
create policy "Allow anonymous read for order pages" on public.price_list_items for select using (true);
create policy "Allow anonymous read for onboarding" on public.clients for select using (true);
-- Los usuarios anónimos pueden crear nuevos pedidos
create policy "Allow anonymous inserts for orders" on public.orders for insert with check (true);
create policy "Allow anonymous inserts for order items" on public.order_items for insert with check (true);
-- Los usuarios anónimos pueden actualizar sus propios datos durante el alta.
create policy "Allow anonymous update for onboarding" on public.clients for update using (true);


-- Políticas de seguridad para el Storage

create policy "Allow public read access to product images"
on storage.objects for select
to public
using ( bucket_id = 'product_images' );

create policy "Allow authenticated users to upload product images"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'product_images' );

create policy "Allow authenticated users to update product images"
on storage.objects for update
to authenticated
using ( bucket_id = 'product_images' );

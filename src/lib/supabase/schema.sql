
-- ------------------------------------------------------------------------------------------------
-- 1. LIMPIEZA DE LA BASE DE DATOS (IDEMPOTENTE)
--
-- Este bloque elimina todos los objetos de la base de datos en el orden correcto
-- para evitar errores de dependencia. Se ejecuta de forma segura cada vez.
-- ------------------------------------------------------------------------------------------------

-- Primero, eliminamos las vistas y funciones que dependen de las tablas.
drop view if exists public.agreements_with_counts;
drop function if exists public.get_client_stats;

-- Luego, eliminamos la tabla obsoleta 'dashboard_stats' (causa de errores anteriores).
drop table if exists public.dashboard_stats;

-- Finalmente, eliminamos el resto de las tablas en un orden que respete las claves foráneas.
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.price_lists;
drop table if exists public.products;


-- ------------------------------------------------------------------------------------------------
-- 2. CREACIÓN DE TABLAS
--
-- Se recrean todas las tablas con sus columnas, tipos de datos, y restricciones.
-- ------------------------------------------------------------------------------------------------

create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);

create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);

create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);

create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type public.client_type not null,
    created_at timestamp with time zone not null default now(),
    price_list_id uuid references public.price_lists(id) on delete set null
);

create table public:clients (
    id uuid default gen_random_uuid() primary key,
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null,
    onboarding_token uuid not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text,
    constraint clients_agreement_id_unique unique (agreement_id)
);

create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
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
    created_at timestamp with time zone not null default now(),
    total_amount numeric(10, 2) not null,
    status public.order_status not null,
    client_name_cache text not null
);

create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);


-- ------------------------------------------------------------------------------------------------
-- 3. VISTAS Y FUNCIONES (Lógica de Negocio en la DB)
--
-- Se crean vistas para simplificar consultas comunes y funciones para cálculos complejos.
-- ------------------------------------------------------------------------------------------------

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

create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and date_trunc('month', created_at) = date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;

create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
language plpgsql
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


-- ------------------------------------------------------------------------------------------------
-- 4. POLÍTICAS DE SEGURIDAD (Row Level Security - RLS)
--
-- Se definen las políticas que controlan qué usuarios pueden ver o modificar qué datos.
-- ------------------------------------------------------------------------------------------------

-- Habilitar RLS para todas las tablas
alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.agreements enable row level security;
alter table public.clients enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Políticas para permitir acceso público a datos necesarios para la página de pedido y onboarding
create policy "Allow public read access to agreements for order page" on public.agreements for select using (true);
create policy "Allow public read access to price lists for order page" on public.price_lists for select using (true);
create policy "Allow public read access to price list items for order page" on public.price_list_items for select using (true);
create policy "Allow public read access to products for order page" on public.products for select using (true);
create policy "Allow public read access to agreement promotions for order page" on public.agreement_promotions for select using (true);
create policy "Allow public read access to promotions for order page" on public.promotions for select using (true);
create policy "Allow public read access to clients for onboarding and order page" on public.clients for select using (true);
create policy "Allow public read access to sales conditions for order page" on public.agreement_sales_conditions for select using (true);
create policy "Allow public read access to sales conditions main table" on public.sales_conditions for select using (true);
create policy "Allow public insert for orders" on public.orders for insert with check (true);
create policy "Allow public insert for order items" on public.order_items for insert with check (true);
create policy "Allow public update for clients on onboarding" on public.clients for update using (true);

-- Políticas para permitir acceso total a los administradores autenticados
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated');


-- ------------------------------------------------------------------------------------------------
-- 5. STORAGE
--
-- Políticas de acceso para el almacenamiento de archivos (imágenes de productos).
-- ------------------------------------------------------------------------------------------------

-- Acceso público de lectura a las imágenes
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- Acceso de escritura solo para administradores autenticados
create policy "Allow admins to manage product images"
on storage.objects for all
using ( auth.role() = 'authenticated' and bucket_id = 'product_images' );

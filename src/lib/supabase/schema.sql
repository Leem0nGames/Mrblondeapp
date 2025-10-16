
-- ------------------------------------------------------------------------------------------------
-- 1. Limpieza Inicial: Elimina tablas en orden de dependencia para evitar errores.
-- ------------------------------------------------------------------------------------------------

-- Junction tables
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.order_items;

-- Primary tables
drop table if exists public.orders;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.price_lists;
drop table if exists public.products;

-- Drop views and functions
drop view if exists public.agreements_with_counts;
DROP FUNCTION IF EXISTS public.get_client_stats(p_client_id uuid);

-- ------------------------------------------------------------------------------------------------
-- 2. Creación de Tablas
-- ------------------------------------------------------------------------------------------------

-- Tabla de Productos
create table public.products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);
alter table "public"."products" enable row level security;

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);
alter table "public"."price_lists" enable row level security;

-- Tabla de Items de la Lista de Precios (Junction)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);
alter table "public"."price_list_items" enable row level security;

-- Tabla de Promociones
create table public.promotions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);
alter table "public"."promotions" enable row level security;


-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);
alter table "public"."sales_conditions" enable row level security;


-- Tabla de Convenios
create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone not null default now()
);
alter table "public"."agreements" enable row level security;


-- Tabla de Clientes
create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null default 'pending_onboarding',
    onboarding_token uuid not null default gen_random_uuid() unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text,
    constraint clients_agreement_id_unique unique (agreement_id)
);
alter table "public"."clients" enable row level security;


-- Tabla de Pedidos
create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone not null default now(),
    total_amount numeric(10, 2) not null,
    status public.order_status not null default 'pending',
    client_name_cache text not null
);
alter table "public"."orders" enable row level security;


-- Tabla de Items del Pedido (Junction)
create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);
alter table "public"."order_items" enable row level security;


-- Tabla de Convenios y Promociones (Junction)
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
alter table "public"."agreement_promotions" enable row level security;

-- Tabla de Convenios y Condiciones de Venta (Junction)
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table "public"."agreement_sales_conditions" enable row level security;


-- ------------------------------------------------------------------------------------------------
-- 3. Vistas y Funciones
-- ------------------------------------------------------------------------------------------------
drop table if exists public.dashboard_stats; -- Drop the old table if it exists
create or replace view public.dashboard_stats as
select
    coalesce((select sum(total_amount) from public.orders where status = 'completed'), 0) as total_revenue,
    coalesce((select count(*) from public.clients where status = 'active'), 0) as active_clients,
    coalesce((select sum(total_amount) from public.orders where status = 'completed' and created_at > date_trunc('month', now())), 0) as month_revenue;


create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;


CREATE OR REPLACE FUNCTION public.get_client_stats(p_client_id uuid)
RETURNS TABLE(total_spent numeric, average_order_value numeric, total_orders bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS average_order_value,
        COUNT(o.id) AS total_orders
    FROM
        public.orders o
    WHERE
        o.client_id = p_client_id AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;


-- ------------------------------------------------------------------------------------------------
-- 4. Almacenamiento (Storage)
-- ------------------------------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

drop policy if exists "Allow public read access to product images" on storage.objects;
create policy "Allow public read access to product images"
on storage.objects for select
to public
using (bucket_id = 'product_images');

drop policy if exists "Allow admins to manage product images" on storage.objects;
create policy "Allow admins to manage product images"
on storage.objects for all
to authenticated
using (bucket_id = 'product_images');


-- ------------------------------------------------------------------------------------------------
-- 5. Seguridad y Políticas de Acceso (RLS)
-- ------------------------------------------------------------------------------------------------
-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Políticas para acceso de lectura público (solo lo necesario)
create policy "Public can read products" on public.products for select using (true);
create policy "Public can read promotions" on public.promotions for select using (true);
create policy "Public can read price lists and items" on public.price_lists for select using (true);
create policy "Public can read price list items" on public.price_list_items for select using (true);
create policy "Public can read agreements and related data" on public.agreements for select using (true);
create policy "Public can read agreement promotions" on public.agreement_promotions for select using (true);
create policy "Public can read clients for onboarding" on public.clients for select using (true);

-- Políticas para el rol autenticado (administradores)
create policy "Admins can manage everything" on public.products for all using (auth.role() = 'authenticated');
create policy "Admins can manage promotions" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Admins can manage sales conditions" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Admins can manage price lists" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Admins can manage price list items" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Admins can manage agreements" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Admins can manage agreement promotions" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Admins can manage agreement sales conditions" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Admins can manage clients" on public.clients for all using (auth.role() = 'authenticated');
create policy "Admins can manage orders" on public.orders for all using (auth.role() = 'authenticated');
create policy "Admins can manage order items" on public.order_items for all using (auth.role() = 'authenticated');

-- Políticas específicas para escritura
create policy "Allow client to create their own orders" on public.orders for insert with check (true);
create policy "Allow client to create their own order items" on public.order_items for insert with check (true);
create policy "Allow client to submit onboarding form" on public.clients for update using (true);


-- ▀█▀ █▀█ ▀█▀ █▀█ █ █▀▀ █▀█
--  █  █▄█  █  █▄█ █ █▄▄ █▀▄
-- BLONDE ORDERS - SUPABASE SCHEMA


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                             ▓
-- ▓  1. LIMPIEZA INICIAL (IDEMPOTENCIA)                                         ▓
-- ▓  Esta sección elimina objetos existentes para asegurar una reinstalación   ▓
-- ▓  limpia. El orden es crucial para manejar dependencias.                     ▓
-- ▓                                                                             ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Primero, eliminamos las VISTAS y FUNCIONES que dependen de las tablas.
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats;
drop function if exists public.get_client_stats(uuid);
drop function if exists public.increment_total_revenue(double precision);

-- Luego, eliminamos las TABLAS. El uso de IF EXISTS evita errores si las tablas no existen.
-- Las tablas con dependencias foráneas se eliminan antes que las tablas a las que referencian.
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.clients;
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.agreements;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.price_lists;
drop table if exists public.products;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                             ▓
-- ▓  2. CREACIÓN DE TABLAS                                                      ▓
-- ▓  Definición de la estructura de datos principal de la aplicación.           ▓
-- ▓                                                                             ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Tabla de Productos
create table public.products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);

-- Tabla de Items de Listas de Precios (tabla pivote)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null check (price >= 0),
    volume_price numeric(10, 2) check (volume_price >= 0),
    primary key (price_list_id, product_id)
);

-- Tabla de Convenios
create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null unique,
    client_type text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone not null default now()
);

-- Tabla de Clientes
create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    fiscal_status text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status text not null default 'pending_onboarding'::text,
    onboarding_token uuid not null default gen_random_uuid(),
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    constraint clients_agreement_id_unique unique (agreement_id)
);

-- Tabla de Promociones
create table public.promotions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

-- Tabla de Convenios-Promociones (tabla pivote)
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

-- Tabla de Convenios-Condiciones de Venta (tabla pivote)
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients(id) on delete cascade,
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    created_at timestamp with time zone not null default now(),
    total_amount numeric(10, 2) not null,
    status text not null default 'pending'::text,
    client_name_cache text not null
);

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                             ▓
-- ▓  3. VISTAS Y FUNCIONES (RPC)                                                ▓
-- ▓  Vistas para cálculos complejos y funciones para lógica de negocio.         ▓
-- ▓                                                                             ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- Vista para estadísticas del dashboard
create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;


-- Vista para convenios con conteo de promociones y condiciones
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

-- Función para estadísticas de un cliente específico
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
        o.client_id = p_client_id and o.status = 'completed';
end;
$$;


-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
-- ▓                                                                             ▓
-- ▓  4. POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY - RLS)                       ▓
-- ▓  Reglas que definen qué usuarios pueden ver o modificar qué datos.          ▓
-- ▓                                                                             ▓
-- ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

-- --- Políticas para TABLAS ---

-- Habilitar RLS en todas las tablas
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

-- Políticas de LECTURA (SELECT)
create policy "Allow all read access" on public.products for select using (true);
create policy "Allow all read access" on public.price_lists for select using (true);
create policy "Allow all read access" on public.price_list_items for select using (true);
create policy "Allow all read access" on public.agreements for select using (true);
create policy "Allow all read access" on public.clients for select using (true);
create policy "Allow all read access" on public.promotions for select using (true);
create policy "Allow all read access" on public.sales_conditions for select using (true);
create policy "Allow all read access" on public.agreement_promotions for select using (true);
create policy "Allow all read access" on public.agreement_sales_conditions for select using (true);
create policy "Allow all read access" on public.orders for select using (true);
create policy "Allow all read access" on public.order_items for select using (true);

-- Políticas de MODIFICACIÓN (INSERT, UPDATE, DELETE) para usuarios autenticados (rol 'authenticated')
create policy "Allow full access for authenticated users" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow full access for authenticated users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');

-- Políticas específicas para Pedidos (solo INSERT y SELECT son públicos)
create policy "Allow insert for anyone" on public.orders for insert with check (true);
create policy "Allow insert for anyone" on public.order_items for insert with check (true);
create policy "Allow admin update and delete" on public.orders for update using (auth.role() = 'authenticated');
create policy "Allow admin update and delete" on public.orders for delete using (auth.role() = 'authenticated');

-- --- Políticas para STORAGE (Imágenes de productos) ---

-- Crear el bucket de imágenes si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do update set public = true;

-- Políticas de acceso al bucket
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

create policy "Allow admins to manage product images"
on storage.objects for all
using ( auth.role() = 'authenticated' and bucket_id = 'product_images' );

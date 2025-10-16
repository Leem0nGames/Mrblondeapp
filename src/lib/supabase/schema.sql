
-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
--  क्लीन-अप स्क्रिप्ट [ LIMPIEZA ]
--
-- Este script primero elimina todo en el orden correcto para evitar errores de dependencia.
-- Es seguro ejecutarlo en cualquier momento.
-- ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄

-- Primero, eliminamos las políticas de seguridad a nivel de fila (RLS)
DROP POLICY IF EXISTS "Allow admin full access" ON public.products;
DROP POLICY IF EXISTS "Allow admin full access" ON public.promotions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.agreements;
DROP POLICY IF EXISTS "Allow admin full access" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.price_lists;
DROP POLICY IF EXISTS "Allow admin full access" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow admin full access" ON public.clients;
DROP POLICY IF EXISTS "Allow admin full access" ON public.orders;
DROP POLICY IF EXISTS "Allow admin full access" ON public.order_items;
DROP POLICY IF EXISTS "Allow admin full access" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.agreement_sales_conditions;

-- Luego, las políticas de almacenamiento (Storage)
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admins to upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admins to update product images" ON storage.objects;

-- Luego, las vistas y funciones que dependen de las tablas
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats;
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(real);

-- Finalmente, eliminamos las tablas. 
-- El uso de CASCADE aquí es seguro si se eliminan primero las dependencias más complejas.
DROP TABLE IF EXISTS public.agreement_promotions;
DROP TABLE IF EXISTS public.agreement_sales_conditions;
DROP TABLE IF EXISTS public.price_list_items;
DROP TABLE IF EXISTS public.order_items;

DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.promotions;
DROP TABLE IF EXISTS public.sales_conditions;
DROP TABLE IF EXISTS public.price_lists;
DROP TABLE IF EXISTS public.orders;
DROP TABLE IF EXISTS public.clients;
DROP TABLE IF EXISTS public.agreements;


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- टेबल्स [ TABLAS ]
--
-- Definición de todas las tablas de la base de datos.
-- ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄

create table public.products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);

create table public.promotions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

create table public.sales_conditions (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone not null default now()
);

create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);

create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null,
    volume_price real,
    primary key (price_list_id, product_id)
);

create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
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

create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status not null,
    onboarding_token uuid not null default gen_random_uuid(),
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text,
    constraint clients_agreement_id_unique unique (agreement_id)
);

create table public.orders (
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamp with time zone not null default now(),
    total_amount real not null,
    status public.order_status not null,
    client_name_cache text not null
);

create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit real not null
);

-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- दृश्य [ VISTAS ]
--
-- Vistas de solo lectura para simplificar consultas complejas.
-- ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄

create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;

-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- फ़ंक्शंस [ FUNCIONES ]
--
-- Funciones SQL reutilizables.
-- ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄

create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent real, average_order_value real, total_orders bigint)
language sql
as $$
    select
        coalesce(sum(total_amount), 0.0)::real as total_spent,
        coalesce(avg(total_amount), 0.0)::real as average_order_value,
        count(id)::bigint as total_orders
    from public.orders
    where client_id = p_client_id and status = 'completed';
$$;

create or replace function public.increment_total_revenue(amount_to_add real)
returns void
language plpgsql
security definer
as $$
begin
  -- This function is a placeholder for a more complex operation.
  -- In a real scenario, you might update a summary table.
  -- For now, it does nothing as the dashboard_stats view is dynamic.
end;
$$;


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- RLS नीतियां [ POLÍTICAS RLS ]
--
-- Políticas de seguridad a nivel de fila para proteger los datos.
-- ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄

-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_sales_conditions enable row level security;


-- Políticas: Permitir acceso de lectura pública a productos y promociones
create policy "Allow public read access" on public.products for select using (true);
create policy "Allow public read access" on public.promotions for select using (true);

-- Políticas: Acceso total para administradores (rol 'authenticated')
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
-- स्टोरेज [ ALMACENAMIENTO ]
--
-- Configuración del bucket de almacenamiento y sus políticas.
-- ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄

-- Insertar bucket para imágenes de productos (si no existe)
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Políticas de Almacenamiento
create policy "Allow public read access to product images" on storage.objects for select using (bucket_id = 'product_images');
create policy "Allow admins to upload product images" on storage.objects for insert with check (bucket_id = 'product_images' and auth.role() = 'authenticated');
create policy "Allow admins to update product images" on storage.objects for update using (bucket_id = 'product_images' and auth.role() = 'authenticated');

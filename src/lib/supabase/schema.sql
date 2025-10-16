
-- ================================================================================= --
--                           LIMPIEZA INICIAL (IDEMPOTENTE)                            --
-- ================================================================================= --
-- Eliminar políticas de RLS existentes para evitar conflictos
DROP POLICY IF EXISTS "Allow public read access to product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow admin full access" ON public.products;
DROP POLICY IF EXISTS "Allow admin full access" ON public.promotions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.sales_conditions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.agreements;
DROP POLICY IF EXISTS "Allow admin full access" ON public.price_lists;
DROP POLICY IF EXISTS "Allow admin full access" ON public.price_list_items;
DROP POLICY IF EXISTS "Allow admin full access" ON public.agreement_promotions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.agreement_sales_conditions;
DROP POLICY IF EXISTS "Allow admin full access" ON public.clients;
DROP POLICY IF EXISTS "Allow admin full access" ON public.orders;
DROP POLICY IF EXISTS "Allow admin full access" ON public.order_items;

-- Eliminar vistas y funciones
DROP VIEW IF EXISTS public.agreements_with_counts;
DROP VIEW IF EXISTS public.dashboard_stats; -- Por si quedó como vista obsoleta
DROP TABLE IF EXISTS public.dashboard_stats; -- Por si quedó como tabla obsoleta
DROP FUNCTION IF EXISTS public.get_client_stats(uuid);
DROP FUNCTION IF EXISTS public.increment_total_revenue(real); -- Versión obsoleta
DROP FUNCTION IF EXISTS public.increment_total_revenue(numeric);
DROP FUNCTION IF EXISTS public.get_overdue_orders();


-- ================================================================================= --
--                                     TABLAS                                        --
-- ================================================================================= --

-- Tabla de Productos
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default now() not null
);

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default now() not null
);

-- Tabla de Items de Listas de Precios (Tabla Pivote)
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);

-- Tabla de Convenios
create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type public.client_type not null,
    created_at timestamp with time zone default now() not null,
    price_list_id uuid references public.price_lists(id) on delete set null
);

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
    status public.client_status default 'pending_onboarding' not null,
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default now() not null,
    fiscal_status text
);

-- Tabla de Promociones
create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default now() not null
);

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default now() not null
);

-- Tabla Pivote Convenio-Promoción
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

-- Tabla Pivote Convenio-Condición de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    created_at timestamp with time zone default now() not null,
    total_amount numeric(10, 2) not null,
    status public.order_status default 'pending' not null,
    client_name_cache text not null
);

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);

-- Tabla para Estadísticas del Dashboard (agregada)
create table public.dashboard_stats (
    id int primary key,
    total_revenue numeric(12, 2) default 0 not null,
    month_revenue numeric(12, 2) default 0 not null,
    active_clients int default 0 not null
);

-- Insertar una fila inicial en la tabla de estadísticas
insert into public.dashboard_stats(id, total_revenue, month_revenue, active_clients)
values (1, 0, 0, 0)
on conflict (id) do nothing;


-- ================================================================================= --
--                                     VISTAS                                        --
-- ================================================================================= --

-- Vista para contar promociones y condiciones por convenio
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc where asc.agreement_id = a.id) as sales_condition_count
from public.agreements a;

-- Vista para estadísticas del Dashboard (recreada como tabla)
-- Ahora se maneja como una tabla `dashboard_stats` con una función `increment_total_revenue`.


-- ================================================================================= --
--                                   FUNCIONES (RPC)                                 --
-- ================================================================================= --

-- Función para obtener estadísticas de un cliente específico
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint) as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0) as total_spent,
        coalesce(avg(o.total_amount), 0) as average_order_value,
        count(o.id) as total_orders
    from public.orders o
    where o.client_id = p_client_id and o.status = 'completed';
end;
$$ language plpgsql;


-- Función para recalcular e incrementar los ingresos totales
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
    -- Actualizar ingresos totales
    update public.dashboard_stats
    set total_revenue = total_revenue + amount_to_add
    where id = 1;

    -- Recalcular ingresos del mes actual
    update public.dashboard_stats
    set month_revenue = (
        select coalesce(sum(total_amount), 0)
        from public.orders
        where status = 'completed' and created_at >= date_trunc('month', now())
    )
    where id = 1;

    -- Recalcular clientes activos
    update public.dashboard_stats
    set active_clients = (
        select count(*) from public.clients where status = 'active'
    )
    where id = 1;
end;
$$ language plpgsql;


-- Función para obtener pedidos vencidos
create or replace function public.get_overdue_orders()
returns setof public.orders as $$
begin
    return query
    select o.*
    from public.orders o
    join public.agreement_sales_conditions asc on o.agreement_id = asc.agreement_id
    join public.sales_conditions sc on asc.sales_condition_id = sc.id
    where
        o.status = 'pending'
        and sc.rules ->> 'type' = 'net_days'
        and o.created_at + ((sc.rules ->> 'days')::integer * interval '1 day') < now();
end;
$$ language plpgsql stable;


-- ================================================================================= --
--                         POLÍTICAS DE SEGURIDAD (RLS)                              --
-- ================================================================================= --

-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreements enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.dashboard_stats enable row level security;

-- Políticas de acceso
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.dashboard_stats for all using (auth.role() = 'authenticated');

-- Políticas para el almacenamiento de imágenes de productos
create policy "Allow public read access to product images" on storage.objects for select using ( bucket_id = 'product_images' );
create policy "Allow admin insert access to product images" on storage.objects for insert with check ( bucket_id = 'product_images' and auth.role() = 'authenticated' );
create policy "Allow admin update access to product images" on storage.objects for update with check ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

-- ================================================================================= --
--                           CONFIGURACIÓN DE PUBLICACIÓN                            --
-- ================================================================================= --
-- Publicar los cambios para que Supabase los detecte
begin;
    drop publication if exists supabase_realtime;
    create publication supabase_realtime;
commit;
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.promotions;
alter publication supabase_realtime add table public.sales_conditions;
alter publication supabase_realtime add table public.agreements;
alter publication supabase_realtime add table public.price_lists;
alter publication supabase_realtime add table public.price_list_items;
alter publication supabase_realtime add table public.agreement_promotions;
alter publication supabase_realtime add table public.agreement_sales_conditions;
alter publication supabase_realtime add table public.clients;
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.order_items;
alter publication supabase_realtime add table public.dashboard_stats;

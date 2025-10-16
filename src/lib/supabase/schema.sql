
-- 🌀 1. Limpieza y Reseteo
-- Elimina políticas de seguridad existentes para evitar conflictos.
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow authenticated users to upload" on storage.objects;
drop policy if exists "Allow authenticated read access" on public.price_lists;

-- Elimina vistas y tablas en orden de dependencia para evitar errores.
-- Usamos DROP...IF EXISTS para que no falle si el objeto no existe.
drop view if exists public.agreements_with_counts;
drop view if exists public.dashboard_stats;
drop table if exists public.dashboard_stats; -- Por si quedó como tabla obsoleta

-- Elimina funciones personalizadas.
drop function if exists public.get_overdue_orders();
drop function ifexists public.get_client_stats(uuid);
drop function if exists public.increment_total_revenue(real);
drop function if exists public.increment_total_revenue(numeric);
drop function if exists public.handle_new_user();

-- Elimina tablas principales. Usamos CASCADE para eliminar dependencias (FKs).
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreements cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.products cascade;

-- 🌀 2. Creación de Tablas

-- Tabla de Productos: Catálogo central de todos los productos.
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Listas de Precios: Contenedores para diferentes conjuntos de precios.
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Items de Listas de Precios: Vincula productos a una lista con un precio específico.
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);

-- Tabla de Promociones: Define reglas de negocio como "2x1", "envío gratis", etc.
create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Condiciones de Venta: Define reglas financieras como "pago a 30 días".
create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Convenios: El corazón del sistema. Agrupa una lista de precios, promociones y condiciones para un tipo de cliente.
create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Clientes: Almacena la información de los clientes.
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
    fiscal_status text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Pedidos: Registra cada pedido enviado desde la app.
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    total_amount numeric(10, 2) not null,
    status public.order_status default 'pending' not null,
    client_name_cache text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Items de Pedido: Detalle de los productos en cada pedido.
create table public.order_items (
    id bigint generated by default as identity primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit numeric(10, 2) not null,
    created_at timestamp with time zone default timezone('utc'text, now()) not null
);

-- Tablas de Vínculo (Muchos a Muchos)
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

-- Tabla para Estadísticas (pre-agregada)
create table public.dashboard_stats (
    id int primary key,
    total_revenue numeric(15, 2) default 0,
    -- Campos adicionales como month_revenue, etc., se calculan con la vista.
    -- El active_clients se obtiene de la vista.
    last_updated timestamptz
);

-- Insertar una única fila para las estadísticas
insert into public.dashboard_stats(id, total_revenue) values (1, 0) on conflict (id) do nothing;


-- 🌀 3. Vistas (Views)

-- Vista para contar promociones y condiciones por convenio
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;

-- Vista para el Dashboard
create or replace view public.dashboard_stats as
select
  (select total_revenue from public.dashboard_stats where id = 1) as total_revenue,
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients;

-- 🌀 4. Funciones (Functions)

-- Función para incrementar los ingresos totales.
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
    update public.dashboard_stats
    set total_revenue = total_revenue + amount_to_add,
        last_updated = now()
    where id = 1;
end;
$$ language plpgsql;

-- Función para obtener estadísticas de un cliente
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

-- Función para obtener pedidos vencidos
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
        and sc.rules->>'type' = 'net_days'
        and o.created_at + ((sc.rules->>'days')::int * interval '1 day') < now();
end;
$$ language plpgsql;


-- 🌀 5. Políticas de Seguridad (RLS)

-- Habilitar RLS en todas las tablas relevantes.
alter table public.products enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.promotions enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreements enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.agreement_sales_conditions enable row level security;

-- Políticas para administradores autenticados (rol 'authenticated').
-- Los administradores pueden hacer todo en estas tablas.
create policy "Allow all for authenticated users" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.orders for all using (auth.role()_ = 'authenticated');
create policy "Allow all for authenticated users" on public.order_items for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');


-- Políticas para acceso PÚBLICO (rol 'anon').
-- Se necesita acceso de lectura a varias tablas para la página de pedidos del cliente.
create policy "Allow public read access" on public.products for select using (true);
create policy "Allow public read access" on public.price_lists for select using (true);
create policy "Allow public read access" on public.price_list_items for select using (true);
create policy "Allow public read access" on public.promotions for select using (true);
create policy "Allow public read access" on public.agreements for select using (true);
create policy "Allow public read access" on public.agreement_promotions for select using (true);
create policy "Allow public read access for specific client" on public.clients for select using (true);
create policy "Allow public insert access" on public.orders for insert with check (true);
create policy "Allow public insert access" on public.order_items for insert with check (true);
create policy "Allow public read for onboarding" on public.clients for select using (onboarding_token::text = (current_setting('request.jwt.claims', true)::jsonb->>'token'));
create policy "Allow public update for onboarding" on public.clients for update using (onboarding_token::text = (current_setting('request.jwt.claims', true)::jsonb->>'token'));

-- Políticas para Storage (Imágenes de productos).
create policy "Allow public read access to product images" on storage.objects for select using ( bucket_id = 'product_images' );
create policy "Allow authenticated users to upload" on storage.objects for insert to authenticated with check ( bucket_id = 'product_images' );
create policy "Allow authenticated users to update" on storage.objects for update to authenticated with check ( bucket_id = 'product_images' );
create policy "Allow authenticated users to delete" on storage.objects for delete to authenticated using ( bucket_id = 'product_images' );


-- 🌀 6. Tipos Personalizados (Enums)
create type public.client_type as enum ('barberia', 'distribuidor', 'especial');
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.order_status as enum ('pending', 'completed');

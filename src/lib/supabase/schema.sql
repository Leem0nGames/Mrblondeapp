
-- ------------------------------------------------------------------------------------------------
-- 1. LIMPIEZA INICIAL
--
-- Este bloque elimina todas las tablas y tipos personalizados en el orden correcto de dependencia
-- para asegurar que el script se pueda ejecutar múltiples veces sin errores.
-- ------------------------------------------------------------------------------------------------

-- Primero, eliminamos las vistas y funciones que dependen de las tablas.
drop view if exists public.agreements_with_counts;
drop function if exists public.get_client_stats(p_client_id uuid);
drop view if exists public.dashboard_stats;
drop function if exists public.increment_total_revenue(amount_to_add real);


-- Luego, eliminamos las tablas.
-- El uso de 'if exists' previene errores si la tabla no existe en la primera ejecución.
drop table if exists public.dashboard_stats; -- Tabla obsoleta, se elimina por si existe
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.order_items;
drop table if exists public.orders;
drop table if exists public.price_list_items;
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.price_lists;
drop table if exists public.products;


-- ------------------------------------------------------------------------------------------------
-- 2. CREACIÓN DE TABLAS
--
-- Se definen todas las tablas de la base de datos con sus columnas, tipos de datos y restricciones.
-- ------------------------------------------------------------------------------------------------

create table public.products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);

create table public.price_lists (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now(),
    constraint price_lists_name_unique unique (name)
);

create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price real not null,
    volume_price real,
    primary key (price_list_id, product_id)
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

create table public.agreements (
    id uuid primary key default gen_random_uuid(),
    agreement_name text not null,
    client_type text not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    constraint agreements_agreement_name_unique unique (agreement_name)
);

create table public.clients (
    id uuid primary key default gen_random_uuid(),
    cuit text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text,
    instagram text,
    status text not null default 'pending_onboarding',
    onboarding_token uuid not null default gen_random_uuid(),
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text,
    constraint clients_cuit_unique unique (cuit),
    constraint clients_email_unique unique (email),
    constraint clients_agreement_id_unique unique (agreement_id)
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
    id uuid primary key default gen_random_uuid(),
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone not null default now(),
    total_amount real not null,
    status text not null default 'pending',
    client_name_cache text not null
);

create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit real not null
);


-- ------------------------------------------------------------------------------------------------
-- 3. HABILITACIÓN DE RLS (ROW-LEVEL SECURITY)
--
-- Se activa la seguridad a nivel de fila para todas las tablas.
-- Esto asegura que ninguna data sea accesible a menos que una política explícita lo permita.
-- ------------------------------------------------------------------------------------------------

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


-- ------------------------------------------------------------------------------------------------
-- 4. POLÍTICAS DE ACCESO (RLS)
--
-- Se definen las reglas sobre quién puede ver y modificar la información.
-- La regla general es: los usuarios autenticados (administradores) pueden hacer todo.
-- Las tablas públicas como 'products' tienen políticas de lectura para todos.
-- ------------------------------------------------------------------------------------------------

create policy "Allow public read access to products" on public.products for select using (true);
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');

create policy "Allow public read access to price lists" on public.price_lists for select using (true);
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated');

create policy "Allow public read access to price list items" on public.price_list_items for select using (true);
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');

create policy "Allow public read access to promotions" on public.promotions for select using (true);
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');

create policy "Allow public read access to sales conditions" on public.sales_conditions for select using (true);
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');

create policy "Allow public read access to agreements" on public.agreements for select using (true);
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');

create policy "Allow public read access for onboarding" on public.clients for select using (true);
create policy "Allow user to update their own client data via onboarding token" on public.clients for update using (onboarding_token::text = (select request.headers->>'x-onboarding-token')) with check (onboarding_token::text = (select request.headers->>'x-onboarding-token'));
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');

create policy "Allow public read access" on public.agreement_promotions for select using (true);
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');

create policy "Allow public read access" on public.agreement_sales_conditions for select using (true);
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');

create policy "Allow all users to create orders" on public.orders for insert with check (true);
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated');

create policy "Allow all users to create order items" on public.order_items for insert with check (true);
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated');


-- ------------------------------------------------------------------------------------------------
-- 5. STORAGE (ALMACENAMIENTO DE IMÁGENES)
--
-- Configuración del bucket de almacenamiento para las imágenes de productos.
-- ------------------------------------------------------------------------------------------------

-- Crear el bucket si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do update set public = true;

-- Políticas de acceso al bucket
create policy "Allow public read access on product images" on storage.objects for select using (bucket_id = 'product_images');
create policy "Allow admins to manage product images" on storage.objects for all using (bucket_id = 'product_images' and auth.role() = 'authenticated');


-- ------------------------------------------------------------------------------------------------
-- 6. VISTAS Y FUNCIONES
--
-- Se crean vistas y funciones de base de datos para simplificar consultas complejas
-- y realizar cálculos de manera eficiente.
-- ------------------------------------------------------------------------------------------------

-- Vista para obtener convenios con el conteo de promociones y condiciones
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count,
    (select row_to_json(pl) from public.price_lists pl where pl.id = a.price_list_id) as price_lists
from
    public.agreements a;

-- Función para obtener estadísticas de un cliente
create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent double precision, average_order_value double precision, total_orders bigint) as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0)::double precision as total_spent,
        coalesce(avg(o.total_amount), 0)::double precision as average_order_value,
        count(o.id)::bigint as total_orders
    from
        public.orders o
    where
        o.client_id = p_client_id and o.status = 'completed';
end;
$$ language plpgsql;

-- Creamos una VISTA en lugar de una tabla para que los datos sean siempre actuales.
create or replace view public.dashboard_stats as
select
    coalesce((select sum(total_amount) from public.orders where status = 'completed'), 0) as total_revenue,
    coalesce((select sum(total_amount) from public.orders where status = 'completed' and created_at > date_trunc('month', now())), 0) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;

-- Función para actualizar los ingresos totales (ya no se usa con la vista, pero se mantiene por si acaso)
create or replace function public.increment_total_revenue(amount_to_add real)
returns void as $$
begin
    -- Esta función ahora está obsoleta ya que total_revenue se calcula en una vista.
    -- Se mantiene vacía por compatibilidad con código antiguo que pueda llamarla.
end;
$$ language plpgsql;

-- FIN DEL SCRIPT --

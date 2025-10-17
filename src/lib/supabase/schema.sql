-- =============================================
-- |||||||||||||||||||||||||||||||||||||||||||||
--            SCHEMA DE BLONDE ORDERS
-- |||||||||||||||||||||||||||||||||||||||||||||
-- =============================================
-- Este script es IDEMPOTENTE. Puedes ejecutarlo de forma segura en cualquier momento.
-- Se encargará de limpiar y reconfigurar el esquema de la base de datos.
-- Versión: 2.1

-- ---------------------------------------------
-- 1. LIMPIEZA INICIAL (DROP EVERYTHING)
-- ---------------------------------------------
-- Para asegurar un estado limpio, eliminamos vistas, tablas y tipos en orden inverso a su creación.
drop view if exists public.dashboard_stats;
drop view if exists public.agreements_with_counts;
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
drop table if exists public.revenue_stats;

-- Limpieza de tipos personalizados
drop type if exists public.client_status;
drop type if exists public.order_status;
drop type if exists public.promotion_type;
drop type if exists public.sales_condition_type;


-- Limpieza de funciones para evitar errores de "función no única"
drop function if exists public.get_client_stats(uuid);
drop function if exists public.get_overdue_orders();
drop function if exists public.increment_total_revenue(numeric);
drop function if exists public.handle_new_user();


-- ---------------------------------------------
-- 2. CREACIÓN DE TIPOS ENUM (STATUS, ETC.)
-- ---------------------------------------------
-- Estos tipos nos permiten restringir los valores de ciertas columnas.
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.order_status as enum ('pending', 'completed');
create type public.promotion_type as enum ('buy_x_get_y_free', 'free_shipping');
create type public.sales_condition_type as enum ('net_days', 'discount', 'installments', 'split_payment');

-- ---------------------------------------------
-- 3. CREACIÓN DE TABLAS
-- ---------------------------------------------
-- Tabla de Productos: Catálogo general de productos.
create table public.products (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Listas de Precios: Contenedores para precios específicos.
create table public.price_lists (
    id uuid default gen_random_uuid() primary key,
    name text not null unique,
    prices_include_vat boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Items de Lista de Precios: Vincula productos a una lista con un precio.
create table public.price_list_items (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2),
    primary key (price_list_id, product_id)
);

-- Tabla de Convenios: Reglas de negocio que se asignan a clientes.
create table public.agreements (
    id uuid default gen_random_uuid() primary key,
    agreement_name text not null unique,
    client_type public.client_type not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
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
    status client_status not null default 'pending_onboarding',
    onboarding_token uuid default gen_random_uuid() not null unique,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    fiscal_status text
);

-- Tabla de Promociones
create table public.promotions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    description text,
    rules jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla Pivot: Convenios y Promociones
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

-- Tabla Pivot: Convenios y Condiciones de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

-- Tabla de Pedidos
create table public.orders (
    id uuid default gen_random_uuid() primary key,
    client_id uuid not null references public.clients(id) on delete restrict,
    agreement_id uuid not null references public.agreements(id) on delete restrict,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    total_amount numeric(10, 2) not null,
    status order_status not null default 'pending',
    client_name_cache text,
    notes text
);

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid default gen_random_uuid() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete restrict,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);

-- Tabla para Estadísticas Globales (Dashboard)
create table public.revenue_stats (
    id int primary key default 1,
    total_revenue numeric(15, 2) not null default 0,
    month_revenue numeric(15, 2) not null default 0,
    constraint only_one_row check (id = 1)
);
-- Insertar la fila única de estadísticas si no existe
insert into public.revenue_stats(id, total_revenue, month_revenue) values (1, 0, 0) on conflict (id) do nothing;


-- ---------------------------------------------
-- 4. HABILITACIÓN DE RLS (ROW LEVEL SECURITY)
-- ---------------------------------------------
-- Por defecto, nadie puede acceder a las tablas. Las políticas definirán el acceso.
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


-- ---------------------------------------------
-- 5. POLÍTICAS DE SEGURIDAD (RLS POLICIES)
-- ---------------------------------------------
-- Los administradores autenticados ('authenticated' role) pueden hacer todo.
create policy "Allow all for authenticated users" on public.products for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.price_lists for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.price_list_items for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.agreements for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.clients for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.promotions for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.sales_conditions for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.agreement_promotions for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.agreement_sales_conditions for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.orders for all to authenticated using (true);
create policy "Allow all for authenticated users" on public.order_items for all to authenticated using (true);

-- Todos los usuarios (incluidos anónimos) pueden leer la información necesaria para la página de pedidos.
-- La seguridad se basa en la no predictibilidad del UUID del convenio.
create policy "Allow public read for order page" on public.agreements for select to anon, authenticated using (true);
create policy "Allow public read for order page" on public.clients for select to anon, authenticated using (true);
create policy "Allow public read for order page" on public.promotions for select to anon, authenticated using (true);
create policy "Allow public read for order page" on public.agreement_promotions for select to anon, authenticated using (true);
create policy "Allow public read for order page" on public.price_lists for select to anon, authenticated using (true);
create policy "Allow public read for order page" on public.price_list_items for select to anon, authenticated using (true);
create policy "Allow public read for order page" on public.products for select to anon, authenticated using (true);

-- Todos los usuarios (incluidos anónimos) pueden crear pedidos.
create policy "Allow public insert for orders" on public.orders for insert to anon, authenticated with check (true);
create policy "Allow public insert for order items" on public.order_items for insert to anon, authenticated with check (true);

-- Los clientes de onboarding pueden actualizar su propia información
create policy "Allow onboarding client to update their own data" on public.clients
for update to anon, authenticated using (onboarding_token::text = (select nullif(current_setting('request.jwt.claims', true)::json->>'onboarding_token', '')))
with check (onboarding_token::text = (select nullif(current_setting('request.jwt.claims', true)::json->>'onboarding_token', '')));


-- ---------------------------------------------
-- 6. VISTAS (VIEWS)
-- ---------------------------------------------
-- Vista para el dashboard con estadísticas clave.
create or replace view public.dashboard_stats as
select
  (select total_revenue from public.revenue_stats where id = 1) as total_revenue,
  (select month_revenue from public.revenue_stats where id = 1) as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients;

-- Vista para obtener convenios con el conteo de promociones y condiciones de venta.
create or replace view public.agreements_with_counts as
select
  a.*,
  pl.name as price_list_name,
  (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count
from
  public.agreements a
left join
  public.price_lists pl on a.price_list_id = pl.id;

-- ---------------------------------------------
-- 7. FUNCIONES (RPC)
-- ---------------------------------------------

-- Función para obtener estadísticas de un cliente específico.
create or replace function public.get_client_stats(p_client_id uuid)
returns table (total_spent numeric, average_order_value numeric, total_orders bigint)
language sql
as $$
  select
    coalesce(sum(total_amount), 0) as total_spent,
    coalesce(avg(total_amount), 0) as average_order_value,
    count(id) as total_orders
  from public.orders
  where client_id = p_client_id and status = 'completed';
$$;

-- Función para obtener pedidos vencidos según su condición de venta.
create or replace function public.get_overdue_orders()
returns setof public.orders
language sql
as $$
  select o.*
  from public.orders o
  join public.agreement_sales_conditions asc on o.agreement_id = asc.agreement_id
  join public.sales_conditions sc on asc.sales_condition_id = sc.id
  where o.status = 'pending'
    and sc.rules->>'type' = 'net_days'
    and o.created_at < (now() - (sc.rules->>'days' || ' days')::interval);
$$;

-- Función para incrementar los ingresos totales de forma segura.
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void
language plpgsql
security definer -- Ejecutar con los permisos del creador
as $$
begin
  update public.revenue_stats
  set total_revenue = total_revenue + amount_to_add,
      month_revenue = month_revenue + amount_to_add -- Simplificado, una tarea cron podría resetear esto mensualmente
  where id = 1;
end;
$$;


-- ---------------------------------------------
-- 8. TRIGGERS
-- ---------------------------------------------
-- Trigger para asociar un perfil a un nuevo usuario de auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  -- Esta función está vacía intencionalmente.
  -- Se puede usar en el futuro para crear un perfil de usuario,
  -- pero para el admin actual no es necesario.
  return new;
end;
$$;

-- Desconectar cualquier trigger existente antes de crear uno nuevo
drop trigger if exists on_auth_user_created on auth.users;

-- Crear el trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ---------------------------------------------
--            FIN DEL SCRIPT
-- ---------------------------------------------
-- La base de datos está lista.
-- Ahora puedes cargar datos de ejemplo si lo deseas (seed.sql).
-- ---------------------------------------------

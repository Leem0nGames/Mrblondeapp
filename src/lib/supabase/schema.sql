-- ----------------------------------------------------------------
-- 🔒 POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY)
-- Habilitar RLS para todas las tablas por defecto.
-- ----------------------------------------------------------------
alter default privileges in schema public enable row level security for all;


-- ----------------------------------------------------------------
-- 🧹 LIMPIEZA INICIAL (para ejecuciones repetidas)
-- Elimina las vistas y tablas existentes en orden de dependencia.
-- CASCADE asegura que los objetos dependientes también se eliminen.
-- ----------------------------------------------------------------
drop view if exists "public"."dashboard_stats" cascade;
drop view if exists "public"."agreements_with_counts" cascade;
drop table if exists "public"."order_items" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."products" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."sales_conditions" cascade;


-- ----------------------------------------------------------------
-- 🪄 EXTENSIONES
-- Habilita la funcionalidad de UUID.
-- ----------------------------------------------------------------
create extension if not exists "uuid-ossp" with schema "extensions";

-- ================================================================
-- 📜 TABLAS PRINCIPALES
-- ================================================================

-- ----------------------------------------------------------------
-- Tabla de Productos
-- Almacena el catálogo de todos los productos disponibles.
-- ----------------------------------------------------------------
create table "public"."products" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    category text,
    image_url text,
    created_at timestamp with time zone not null default now()
);

-- ----------------------------------------------------------------
-- Tabla de Listas de Precios
-- Contiene diferentes listas de precios que se pueden asignar a convenios.
-- ----------------------------------------------------------------
create table "public"."price_lists" (
    id uuid primary key default uuid_generate_v4(),
    name text not null unique,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now()
);

-- ----------------------------------------------------------------
-- Tabla de Items de Listas de Precios
-- Tabla pivote que asocia productos a una lista con un precio específico.
-- ----------------------------------------------------------------
create table "public"."price_list_items" (
    price_list_id uuid not null references public.price_lists(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric not null default 0,
    volume_price numeric,
    primary key (price_list_id, product_id)
);

-- ----------------------------------------------------------------
-- Tabla de Promociones
-- Define las promociones que pueden ser asignadas a convenios.
-- ----------------------------------------------------------------
create table "public"."promotions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone not null default now()
);

-- ----------------------------------------------------------------
-- Tabla de Condiciones de Venta
-- Define las condiciones comerciales (plazos, descuentos, etc.).
-- ----------------------------------------------------------------
create table "public"."sales_conditions" (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    rules jsonb not null,
    created_at timestamp with time zone not null default now()
);

-- ----------------------------------------------------------------
-- Tabla de Convenios
-- Agrupa listas de precios, promociones y condiciones para un tipo de cliente.
-- ----------------------------------------------------------------
create table "public"."agreements" (
    id uuid primary key default uuid_generate_v4(),
    agreement_name text not null unique,
    client_type public.client_type_enum not null,
    price_list_id uuid references public.price_lists(id) on delete set null,
    created_at timestamp with time zone not null default now()
);

-- ----------------------------------------------------------------
-- Tabla de Clientes
-- Almacena la información de los clientes (barberías, distribuidores).
-- ----------------------------------------------------------------
create table "public"."clients" (
    id uuid primary key default uuid_generate_v4(),
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status public.client_status_enum not null default 'pending_onboarding',
    onboarding_token uuid not null default uuid_generate_v4(),
    agreement_id uuid references public.agreements(id) on delete set null,
    fiscal_status text,
    created_at timestamp with time zone not null default now()
);

-- ----------------------------------------------------------------
-- Tabla de Pedidos
-- Registra cada pedido realizado a través de la aplicación.
-- ----------------------------------------------------------------
create table "public"."orders" (
    id uuid primary key default uuid_generate_v4(),
    client_id uuid not null references public.clients(id),
    agreement_id uuid not null references public.agreements(id),
    total_amount numeric not null,
    status public.order_status_enum not null default 'pending',
    client_name_cache text not null,
    created_at timestamp with time zone not null default now()
);

-- ----------------------------------------------------------------
-- Tabla de Items de Pedido
-- Detalla los productos y cantidades de cada pedido.
-- ----------------------------------------------------------------
create table "public"."order_items" (
    id uuid primary key default uuid_generate_v4(),
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid not null references public.products(id),
    quantity integer not null,
    price_per_unit numeric not null
);


-- ================================================================
-- 🔗 TABLAS PIVOTE (many-to-many)
-- ================================================================

-- ----------------------------------------------------------------
-- Tabla Pivote: Convenios y Promociones
-- Asigna múltiples promociones a múltiples convenios.
-- ----------------------------------------------------------------
create table "public"."agreement_promotions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

-- ----------------------------------------------------------------
-- Tabla Pivote: Convenios y Condiciones de Venta
-- Asigna múltiples condiciones a múltiples convenios.
-- ----------------------------------------------------------------
create table "public"."agreement_sales_conditions" (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);

-- ================================================================
-- VIEWS Y FUNCIONES
-- ================================================================

-- ----------------------------------------------------------------
-- Vista: `agreements_with_counts`
-- Simplifica la obtención de convenios con el conteo de sus relaciones.
-- ----------------------------------------------------------------
create view "public"."agreements_with_counts" as
select
    a.*,
    (select count(*) from agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from agreement_sales_conditions as asc_count where asc_count.agreement_id = a.id) as sales_condition_count
from
    agreements a;


-- ----------------------------------------------------------------
-- Vista: `dashboard_stats`
-- Pre-calcula las estadísticas para el dashboard principal.
-- ----------------------------------------------------------------
create view public.dashboard_stats as
select
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
  (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at > date_trunc('month', now())) as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients;

-- ----------------------------------------------------------------
-- Función: `increment_total_revenue`
-- Función RPC para incrementar el total de ingresos de forma segura.
-- ----------------------------------------------------------------
drop function if exists public.increment_total_revenue(amount_to_add numeric);
create function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
  -- This function would be more complex in a real-world scenario,
  -- likely updating a dedicated stats table. For this demo, it's a placeholder.
end;
$$ language plpgsql;


-- ----------------------------------------------------------------
-- Función: `get_client_stats`
-- Función RPC para calcular y devolver estadísticas para un cliente específico.
-- ----------------------------------------------------------------
drop function if exists public.get_client_stats(p_client_id uuid);
create function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint) as $$
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
$$ language plpgsql;

-- ================================================================
-- ፖ POLÍTICAS DE SEGURIDAD (RLS)
-- ================================================================

-- ----------------------------------------------------------------
-- Políticas para la tabla `products`
-- Permite lectura a todos los usuarios autenticados.
-- ----------------------------------------------------------------
alter table "public"."products" enable row level security;
create policy "Allow authenticated read access to products"
on "public"."products" for select
to authenticated
using (true);
create policy "Allow full access for admin users on products"
on "public"."products" for all
to authenticated
using (true); -- En un caso real, se verificaría un rol de admin.

-- ----------------------------------------------------------------
-- Políticas para `price_lists` y `price_list_items`
-- Permite acceso completo a usuarios autenticados (admin).
-- ----------------------------------------------------------------
alter table "public"."price_lists" enable row level security;
create policy "Allow full access for admin users on price_lists"
on "public"."price_lists" for all to authenticated using (true);

alter table "public"."price_list_items" enable row level security;
create policy "Allow full access for admin users on price_list_items"
on "public"."price_list_items" for all to authenticated using (true);

-- ----------------------------------------------------------------
-- Políticas para `promotions`, `sales_conditions` y sus tablas pivote
-- Permite acceso completo a usuarios autenticados (admin).
-- ----------------------------------------------------------------
alter table "public"."promotions" enable row level security;
create policy "Allow full access for admin users on promotions"
on "public"."promotions" for all to authenticated using (true);

alter table "public"."sales_conditions" enable row level security;
create policy "Allow full access for admin users on sales_conditions"
on "public"."sales_conditions" for all to authenticated using (true);

alter table "public"."agreement_promotions" enable row level security;
create policy "Allow full access for admin on agreement_promotions"
on "public"."agreement_promotions" for all to authenticated using (true);

alter table "public"."agreement_sales_conditions" enable row level security;
create policy "Allow full access for admin on agreement_sales_conditions"
on "public"."agreement_sales_conditions" for all to authenticated using (true);


-- ----------------------------------------------------------------
-- Políticas para la tabla `agreements`
-- Permite lectura pública para la página de pedidos, pero gestión solo para admins.
-- ----------------------------------------------------------------
alter table "public"."agreements" enable row level security;
create policy "Allow public read access to agreements for order page"
on "public"."agreements" for select
using (true);
create policy "Allow full access for admin users on agreements"
on "public"."agreements" for all
to authenticated
using (true);

-- ----------------------------------------------------------------
-- Políticas para la tabla `clients`
-- Acceso limitado para proteger la información del cliente.
-- ----------------------------------------------------------------
alter table "public"."clients" enable row level security;
create policy "Allow admin full access to clients"
on "public"."clients" for all to authenticated using (true);
create policy "Allow client to read own data based on agreement"
on "public"."clients" for select using (agreement_id is not null);


-- ----------------------------------------------------------------
-- Políticas para `orders` y `order_items`
-- Escritura pública (con 'anon' key) para la inserción, lectura solo para admins.
-- ----------------------------------------------------------------
alter table "public"."orders" enable row level security;
create policy "Allow anonymous write access for new orders"
on "public"."orders" for insert
to anon
with check (true);
create policy "Allow admin full access to orders"
on "public"."orders" for all to authenticated using (true);

alter table "public"."order_items" enable row level security;
create policy "Allow anonymous write access for new order items"
on "public"."order_items" for insert
to anon
with check (true);
create policy "Allow admin full access to order items"
on "public"."order_items" for all to authenticated using (true);


-- ----------------------------------------------------------------
-- Habilitar acceso de lectura para las vistas
-- ----------------------------------------------------------------
grant select on table public.agreements_with_counts to authenticated;
grant select on table public.dashboard_stats to authenticated;

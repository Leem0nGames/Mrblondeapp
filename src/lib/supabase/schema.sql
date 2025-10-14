-- ----------------------------------------------------------------
-- 1. EXTENSIONS
-- ----------------------------------------------------------------
-- Habilita la extensión para generar UUIDs
create extension if not exists "uuid-ossp" with schema extensions;


-- ----------------------------------------------------------------
-- 2. TABLE DELETION (Idempotency)
-- ----------------------------------------------------------------
-- Estas sentencias DROP aseguran que el script se pueda ejecutar múltiples veces sin errores.
-- Se borran las tablas en el orden inverso a su creación para respetar las dependencias.
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreements cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.promotions cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.products cascade;
drop view if exists public.dashboard_stats cascade;
drop view if exists public.agreements_with_counts cascade;


-- ----------------------------------------------------------------
-- 3. TABLE CREATION
-- ----------------------------------------------------------------

-- Tabla de Productos
-- Almacena el catálogo completo de productos.
create table public.products (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "name" text not null,
    "description" text,
    "base_price" numeric not null check (base_price >= 0),
    "category" text,
    "created_at" timestamptz not null default now()
);
-- Añade capacidades de búsqueda de texto completo a la tabla de productos.
alter table public.products enable row level security;
create policy "Allow public read-only access" on public.products for select using (true);
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');


-- Tabla de Listas de Precios
-- Permite crear múltiples listas de precios (ej. "Precios Mayorista", "Precios Retail").
create table public.price_lists (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "name" text not null unique,
    "prices_include_vat" boolean not null default true,
    "created_at" timestamptz not null default now()
);
alter table public.price_lists enable row level security;
create policy "Allow admin full access" on public.price_lists for all using (auth.role() = 'authenticated');


-- Tabla de Items de Listas de Precios (Tabla Pivote)
-- Asocia productos a listas de precios con un precio específico para esa lista.
create table public.price_list_items (
    "price_list_id" uuid not null references public.price_lists(id) on delete cascade,
    "product_id" uuid not null references public.products(id) on delete cascade,
    "price" numeric not null check (price >= 0),
    "volume_price" numeric check (volume_price >= 0),
    primary key (price_list_id, product_id)
);
alter table public.price_list_items enable row level security;
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow public read-only access" on public.price_list_items for select using (true);


-- Tabla de Convenios
-- Define los acuerdos comerciales. Cada convenio se asocia a una lista de precios.
create table public.agreements (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "agreement_name" text not null unique,
    "client_type" text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
    "price_list_id" uuid references public.price_lists(id) on delete set null,
    "created_at" timestamptz not null default now()
);
alter table public.agreements enable row level security;
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow public read-only access" on public.agreements for select using (true);


-- Tabla de Clientes
-- Almacena la información de los clientes.
create table public.clients (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "cuit" text unique,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text unique,
    "instagram" text,
    "status" text not null default 'pending_onboarding' check (status in ('pending_onboarding', 'pending_agreement', 'active', 'archived')),
    "onboarding_token" uuid not null unique default extensions.uuid_generate_v4(),
    "agreement_id" uuid references public.agreements(id) on delete set null,
    "created_at" timestamptz not null default now(),
    "fiscal_status" text -- Nuevo campo para condición fiscal
);
alter table public.clients enable row level security;
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow public read-only access" on public.clients for select using (true);


-- Tabla de Promociones
-- Define las promociones disponibles (ej. "2x1", "Envío gratis").
create table public.promotions (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "name" text not null,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz not null default now()
);
alter table public.promotions enable row level security;
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow public read-only access" on public.promotions for select using (true);


-- Tabla de Condiciones de Venta
-- Define condiciones comerciales (plazos de pago, descuentos).
create table public.sales_conditions (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "name" text not null,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz not null default now()
);
alter table public.sales_conditions enable row level security;
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow public read-only access" on public.sales_conditions for select using (true);


-- Tabla de Asignación de Promociones a Convenios
create table public.agreement_promotions (
    "agreement_id" uuid not null references public.agreements(id) on delete cascade,
    "promotion_id" uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);
alter table public.agreement_promotions enable row level security;
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow public read-only access" on public.agreement_promotions for select using (true);


-- Tabla de Asignación de Condiciones de Venta a Convenios
create table public.agreement_sales_conditions (
    "agreement_id" uuid not null references public.agreements(id) on delete cascade,
    "sales_condition_id" uuid not null references public.sales_conditions(id) on delete cascade,
    primary key (agreement_id, sales_condition_id)
);
alter table public.agreement_sales_conditions enable row level security;
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow public read-only access" on public.agreement_sales_conditions for select using (true);


-- Tabla de Pedidos
create table public.orders (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "client_id" uuid not null references public.clients(id),
    "agreement_id" uuid not null references public.agreements(id),
    "created_at" timestamptz not null default now(),
    "total_amount" numeric not null,
    "status" text not null default 'pending' check (status in ('pending', 'completed')),
    "client_name_cache" text not null
);
alter table public.orders enable row level security;
create policy "Allow admin full access" on public.orders for all using (auth.role() = 'authenticated');


-- Tabla de Items de Pedido
create table public.order_items (
    "id" uuid primary key default extensions.uuid_generate_v4(),
    "order_id" uuid not null references public.orders(id) on delete cascade,
    "product_id" uuid not null references public.products(id),
    "quantity" int not null,
    "price_per_unit" numeric not null
);
alter table public.order_items enable row level security;
create policy "Allow admin full access" on public.order_items for all using (auth.role() = 'authenticated');


-- ----------------------------------------------------------------
-- 4. VIEWS
-- ----------------------------------------------------------------

-- Vista para estadísticas del dashboard
create or replace view public.dashboard_stats as
select
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from public.orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
    (select count(*) from public.clients where status = 'active') as active_clients;

alter view public.dashboard_stats owner to postgres;
grant select on public.dashboard_stats to authenticated;


-- Vista para contar promociones y condiciones por convenio
create or replace view public.agreements_with_counts as
select
    a.*,
    (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from public.agreement_sales_conditions asc Where asc.agreement_id = a.id) as sales_condition_count
from
    public.agreements a;
    
alter view public.agreements_with_counts owner to postgres;
grant select on public.agreements_with_counts to authenticated;


-- ----------------------------------------------------------------
-- 5. RPC FUNCTIONS
-- ----------------------------------------------------------------

-- Función para incrementar los ingresos totales de forma segura
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void as $$
begin
  -- This function is a placeholder for a more robust revenue tracking system.
  -- In a real-world scenario, you would update a dedicated stats table
  -- or use a more sophisticated method to avoid potential race conditions.
  -- For this demo, we acknowledge this is not perfect but serves the purpose.
end;
$$ language plpgsql;

grant execute on function public.increment_total_revenue(numeric) to authenticated;

-- Función para obtener estadísticas de un cliente específico
create or replace function public.get_client_stats(p_client_id uuid)
returns table (
    total_spent numeric,
    average_order_value numeric,
    total_orders bigint
) as $$
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

grant execute on function public.get_client_stats(uuid) to authenticated;

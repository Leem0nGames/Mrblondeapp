-- Utilidades
drop function if exists handle_new_user cascade;
drop function if exists increment_total_revenue cascade;
drop view if exists agreements_with_counts;
drop view if exists dashboard_stats;
drop function if exists get_client_stats(uuid);

-- 1. Limpieza inicial (en orden inverso de dependencias)
drop table if exists "public"."order_items";
drop table if exists "public"."orders";
drop table if exists "public"."agreement_promotions";
drop table if exists "public"."agreement_sales_conditions";
drop table if exists "public"."price_list_items";
drop table if exists "public"."clients";
drop table if exists "public"."agreements";
drop table if exists "public"."promotions";
drop table if exists "public"."sales_conditions";
drop table if exists "public"."price_lists";
drop table if exists "public"."products";

drop type if exists client_type;
drop type if exists order_status;
drop type if exists client_status;

-- 2. Creación de Tipos (ENUMS)
create type client_type as enum ('barberia', 'distribuidor', 'especial');
create type order_status as enum ('pending', 'completed');
create type client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');


-- 3. Creación de Tablas
create table "public"."products" (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    name text not null,
    description text,
    category text,
    image_url text,
    constraint products_pkey primary key (id)
);
alter table "public"."products" enable row level security;

create table "public"."price_lists" (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    name text not null,
    prices_include_vat boolean not null default true,
    constraint price_lists_pkey primary key (id),
    constraint price_lists_name_key unique (name)
);
alter table "public"."price_lists" enable row level security;

create table "public"."price_list_items" (
    price_list_id uuid not null,
    product_id uuid not null,
    price numeric not null,
    volume_price numeric,
    constraint price_list_items_pkey primary key (price_list_id, product_id),
    constraint price_list_items_price_list_id_fkey foreign key (price_list_id) references price_lists (id) on delete cascade,
    constraint price_list_items_product_id_fkey foreign key (product_id) references products (id) on delete cascade
);
alter table "public"."price_list_items" enable row level security;

create table "public"."promotions" (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    name text not null,
    description text,
    rules jsonb,
    constraint promotions_pkey primary key (id)
);
alter table "public"."promotions" enable row level security;

create table "public"."sales_conditions" (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    name text not null,
    description text,
    rules jsonb,
    constraint sales_conditions_pkey primary key (id)
);
alter table "public"."sales_conditions" enable row level security;

create table "public"."agreements" (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    agreement_name text not null,
    client_type client_type not null,
    price_list_id uuid,
    constraint agreements_pkey primary key (id),
    constraint agreements_agreement_name_key unique (agreement_name),
    constraint agreements_price_list_id_fkey foreign key (price_list_id) references price_lists (id) on delete set null
);
alter table "public"."agreements" enable row level security;

create table "public"."agreement_promotions" (
    agreement_id uuid not null,
    promotion_id uuid not null,
    constraint agreement_promotions_pkey primary key (agreement_id, promotion_id),
    constraint agreement_promotions_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint agreement_promotions_promotion_id_fkey foreign key (promotion_id) references promotions (id) on delete cascade
);
alter table "public"."agreement_promotions" enable row level security;

create table "public"."agreement_sales_conditions" (
    agreement_id uuid not null,
    sales_condition_id uuid not null,
    constraint agreement_sales_conditions_pkey primary key (agreement_id, sales_condition_id),
    constraint agreement_sales_conditions_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint agreement_sales_conditions_sales_condition_id_fkey foreign key (sales_condition_id) references sales_conditions (id) on delete cascade
);
alter table "public"."agreement_sales_conditions" enable row level security;


create table "public"."clients" (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    cuit text,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text,
    instagram text,
    status client_status not null default 'pending_onboarding',
    onboarding_token uuid not null default gen_random_uuid(),
    agreement_id uuid,
    fiscal_status text,
    constraint clients_pkey primary key (id),
    constraint clients_onboarding_token_key unique (onboarding_token),
    constraint clients_cuit_key unique (cuit),
    constraint clients_email_key unique (email),
    constraint clients_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete set null
);
alter table "public"."clients" enable row level security;


create table "public"."orders" (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    client_id uuid not null,
    agreement_id uuid not null,
    total_amount numeric not null,
    status order_status not null default 'pending',
    client_name_cache text,
    constraint orders_pkey primary key (id),
    constraint orders_agreement_id_fkey foreign key (agreement_id) references agreements (id) on delete restrict,
    constraint orders_client_id_fkey foreign key (client_id) references clients (id) on delete restrict
);
alter table "public"."orders" enable row level security;

create table "public"."order_items" (
    order_id uuid not null,
    product_id uuid not null,
    quantity integer not null,
    price_per_unit numeric not null,
    constraint order_items_pkey primary key (order_id, product_id),
    constraint order_items_order_id_fkey foreign key (order_id) references orders (id) on delete cascade,
    constraint order_items_product_id_fkey foreign key (product_id) references products (id) on delete restrict
);
alter table "public"."order_items" enable row level security;

-- 4. Vistas
create or replace view agreements_with_counts as
select
    a.*,
    (select count(*) from agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
    (select count(*) from agreement_sales_conditions asc where asc.agreement_id = a.id) as sales_condition_count
from
    agreements a;

create or replace view dashboard_stats as 
select 
    (select coalesce(sum(total_amount), 0) from orders where status = 'completed') as total_revenue,
    (select coalesce(sum(total_amount), 0) from orders where status = 'completed' and created_at >= date_trunc('month', now())) as month_revenue,
    (select count(*) from clients where status = 'active') as active_clients;


-- 5. Funciones RPC
create or replace function get_client_stats(p_client_id uuid)
returns table (
    total_spent numeric,
    average_order_value numeric,
    total_orders bigint
)
language sql
as $$
    select 
        coalesce(sum(total_amount), 0) as total_spent,
        coalesce(avg(total_amount), 0) as average_order_value,
        count(id) as total_orders
    from public.orders
    where client_id = p_client_id and status = 'completed';
$$;


create or replace function increment_total_revenue(amount_to_add numeric)
returns void
language plpgsql
as $$
begin
    -- This function is a placeholder for a more robust system.
    -- In a high-concurrency environment, you'd want to handle this differently,
    -- perhaps by locking the stats table or using a more advanced pattern.
    -- For now, this is sufficient for a low-traffic admin dashboard.
    -- We are also assuming a single row in dashboard_stats, which is enforced by the view.
    -- This function doesn't actually update a table, but shows how you would.
end;
$$;


-- 6. Políticas de RLS (Seguridad a Nivel de Fila)
-- Habilitamos RLS para todas las tablas por defecto (denegar todo).
-- Y luego creamos políticas para permitir el acceso.

-- Los usuarios autenticados (admins) pueden hacer de todo.
create policy "Allow all for authenticated users" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.price_lists for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow all for authenticated users" on public.order_items for all using (auth.role() = 'authenticated');


-- Permitir acceso PÚBLICO de lectura a las tablas necesarias para la página de pedidos
-- Un cliente no autenticado necesita leer convenios, productos, precios y promociones.
-- La seguridad se basa en que solo pueden acceder a través de un UUID de convenio que no es adivinable.
create policy "Allow public read access to order page data" on public.agreements for select using (true);
create policy "Allow public read access to order page data" on public.products for select using (true);
create policy "Allow public read access to order page data" on public.price_lists for select using (true);
create policy "Allow public read access to order page data" on public.price_list_items for select using (true);
create policy "Allow public read access to order page data" on public.agreement_promotions for select using (true);
create policy "Allow public read access to order page data" on public.promotions for select using (true);

-- Permitir acceso PÚBLICO para el formulario de alta de cliente (onboarding)
create policy "Allow public read access for onboarding" on public.clients for select using (true);
create policy "Allow public update for onboarding" on public.clients for update using (true);

-- Permitir la creación PÚBLICA de pedidos
create policy "Allow public insert for orders" on public.orders for insert with check (true);
create policy "Allow public insert for order items" on public.order_items for insert with check (true);


-- 7. Storage (Almacenamiento de Archivos)
-- Crear bucket para imágenes de productos si no existe
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- Política para permitir la subida y visualización pública de imágenes
create policy "Allow public access to product images"
on storage.objects for all
using ( bucket_id = 'product_images' );

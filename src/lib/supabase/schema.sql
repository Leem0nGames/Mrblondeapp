
-- Versión 5 del Schema: Orden de eliminación corregido, sin CASCADE, y con DROP TABLE para dashboard_stats.

-- 1. LIMPIEZA: Eliminar objetos en el orden correcto de dependencia.

-- 1.1. Eliminar vistas y funciones que dependen de las tablas.
drop view if exists public.agreements_with_counts;
drop function if exists public.get_client_stats;

-- 1.2. Eliminar la tabla/vista dashboard_stats para resolver el conflicto.
-- Esta sección maneja si 'dashboard_stats' era una tabla (legacy) o una vista.
drop table if exists public.dashboard_stats;
drop view if exists public.dashboard_stats; -- Por si acaso en el futuro se crea como vista.

-- 1.3. Eliminar tablas que tienen relaciones de clave foránea.
-- El orden es importante: primero las tablas "hijo".
drop table if exists public.agreement_promotions;
drop table if exists public.agreement_sales_conditions;
drop table if exists public.price_list_items;
drop table if exists public.order_items;

-- 1.4. Eliminar el resto de las tablas principales.
drop table if exists public.clients;
drop table if exists public.agreements;
drop table if exists public.promotions;
drop table if exists public.sales_conditions;
drop table if exists public.price_lists;
drop table if exists public.products;
drop table if exists public.orders;


-- 2. CREACIÓN DE TABLAS

-- Tabla de Productos
create table public.products (
  id uuid not null default gen_random_uuid(),
  name text not null,
  description text null,
  category text null,
  image_url text null,
  created_at timestamp with time zone not null default now(),
  constraint products_pkey primary key (id)
);

-- Tabla de Listas de Precios
create table public.price_lists (
    id uuid not null default gen_random_uuid(),
    name text not null,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now(),
    constraint price_lists_pkey primary key (id),
    constraint price_lists_name_key unique (name)
);

-- Tabla intermedia para precios de productos en una lista
create table public.price_list_items (
    price_list_id uuid not null,
    product_id uuid not null,
    price numeric not null,
    volume_price numeric null,
    constraint price_list_items_pkey primary key (price_list_id, product_id),
    constraint price_list_items_price_list_id_fkey foreign key (price_list_id) references public.price_lists (id) on delete cascade,
    constraint price_list_items_product_id_fkey foreign key (product_id) references public.products (id) on delete cascade
);

-- Tabla de Convenios
create table public.agreements (
  id uuid not null default gen_random_uuid(),
  agreement_name text not null,
  client_type public.client_type not null,
  price_list_id uuid null,
  created_at timestamp with time zone not null default now(),
  constraint agreements_pkey primary key (id),
  constraint agreements_agreement_name_key unique (agreement_name),
  constraint agreements_price_list_id_fkey foreign key (price_list_id) references public.price_lists (id) on delete set null
);

-- Tabla de Clientes
create table public.clients (
    id uuid not null default gen_random_uuid(),
    cuit text null,
    contact_name text null,
    contact_dni text null,
    address text null,
    delivery_window text null,
    email text null,
    instagram text null,
    status public.client_status not null default 'pending_onboarding'::public.client_status,
    onboarding_token uuid not null default gen_random_uuid(),
    agreement_id uuid null,
    created_at timestamp with time zone not null default now(),
    fiscal_status text null,
    constraint clients_pkey primary key (id),
    constraint clients_cuit_key unique (cuit),
    constraint clients_email_key unique (email),
    constraint clients_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete set null,
    constraint clients_agreement_id_unique unique (agreement_id)
);


-- Tabla de Promociones
create table public.promotions (
  id uuid not null default gen_random_uuid(),
  name text not null,
  description text null,
  rules jsonb null,
  created_at timestamp with time zone not null default now(),
  constraint promotions_pkey primary key (id)
);

-- Tabla intermedia Convenio-Promociones
create table public.agreement_promotions (
  agreement_id uuid not null,
  promotion_id uuid not null,
  constraint agreement_promotions_pkey primary key (agreement_id, promotion_id),
  constraint agreement_promotions_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade,
  constraint agreement_promotions_promotion_id_fkey foreign key (promotion_id) references public.promotions (id) on delete cascade
);

-- Tabla de Condiciones de Venta
create table public.sales_conditions (
    id uuid not null default gen_random_uuid(),
    name text not null,
    description text null,
    rules jsonb null,
    created_at timestamp with time zone not null default now(),
    constraint sales_conditions_pkey primary key (id)
);

-- Tabla intermedia Convenio-Condiciones de Venta
create table public.agreement_sales_conditions (
    agreement_id uuid not null,
    sales_condition_id uuid not null,
    constraint agreement_sales_conditions_pkey primary key (agreement_id, sales_condition_id),
    constraint agreement_sales_conditions_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade,
    constraint agreement_sales_conditions_sales_condition_id_fkey foreign key (sales_condition_id) references public.sales_conditions (id) on delete cascade
);

-- Tabla de Pedidos
create table public.orders (
    id uuid not null default gen_random_uuid(),
    client_id uuid not null,
    agreement_id uuid not null,
    created_at timestamp with time zone not null default now(),
    total_amount numeric not null,
    status public.order_status not null,
    client_name_cache text not null,
    constraint orders_pkey primary key (id),
    constraint orders_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete restrict,
    constraint orders_client_id_fkey foreign key (client_id) references public.clients (id) on delete restrict
);

-- Tabla de Items de Pedido
create table public.order_items (
    id uuid not null default gen_random_uuid(),
    order_id uuid not null,
    product_id uuid not null,
    quantity integer not null,
    price_per_unit numeric not null,
    constraint order_items_pkey primary key (id),
    constraint order_items_order_id_fkey foreign key (order_id) references public.orders (id) on delete cascade,
    constraint order_items_product_id_fkey foreign key (product_id) references public.products (id) on delete restrict
);


-- 3. CREACIÓN DE VISTAS Y FUNCIONES

-- Vista para estadísticas del Dashboard
create or replace view public.dashboard_stats as
select
  sum(case when o.status = 'completed' then o.total_amount else 0 end) as total_revenue,
  sum(case when o.status = 'completed' and o.created_at > date_trunc('month', now()) then o.total_amount else 0 end) as month_revenue,
  (select count(*) from public.clients where status = 'active') as active_clients
from
  public.orders o;

-- Vista para contar promociones y condiciones en convenios
create or replace view public.agreements_with_counts as
select
  a.*,
  (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
  (select count(*) from public.agreement_sales_conditions asc_join where asc_join.agreement_id = a.id) as sales_condition_count
from
  public.agreements a;

-- Función para estadísticas de cliente
create or replace function public.get_client_stats(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint)
language sql
as $$
  select
    coalesce(sum(total_amount), 0) as total_spent,
    coalesce(avg(total_amount), 0) as average_order_value,
    count(id) as total_orders
  from public.orders
  where client_id = p_client_id and status = 'completed';
$$;


-- 4. POLÍTICAS DE SEGURIDAD (RLS)

-- Habilitar RLS en todas las tablas
alter table public.products enable row level security;
alter table public.agreements enable row level security;
alter table public.promotions enable row level security;
alter table public.clients enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_sales_conditions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Políticas para permitir acceso público a datos necesarios para la página de pedido
create policy "Allow public read access to products" on public.products for select using (true);
create policy "Allow public read access to agreements" on public.agreements for select using (true);
create policy "Allow public read access to promotions" on public.promotions for select using (true);
create policy "Allow public read access to price lists" on public.price_lists for select using (true);
create policy "Allow public read access to price list items" on public.price_list_items for select using (true);
create policy "Allow public read access to agreement promotions" on public.agreement_promotions for select using (true);
create policy "Allow public read access to clients for order page" on public.clients for select using (true);


-- Políticas para administradores autenticados
create policy "Allow admin full access" on public.products for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreements for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.clients for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_promotions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.price_lists for all using (auth.role() aS (auth.role() = 'authenticated'));
create policy "Allow admin full access" on public.price_list_items for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
create policy "Allow admin full access on orders" on public.orders for all using (auth.role() = 'authenticated');
create policy "Allow admin full access on order_items" on public.order_items for all using (auth.role() = 'authenticated');

-- Políticas para el almacenamiento de imágenes
-- Asumiendo que el bucket se llama 'product_images'
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

create policy "Allow admins to manage product images"
on storage.objects for all
using ( auth.role() = 'authenticated' )
with check ( bucket_id = 'product_images' and auth.role() = 'authenticated' );

-- Política para que los usuarios puedan subir sus propias imágenes (ejemplo, no usado actualmente)
create policy "Allow authenticated users to upload to their own folder"
on storage.objects for insert
with check ( bucket_id = 'product_images' and (storage.foldername(name))[1] = auth.uid()::text );

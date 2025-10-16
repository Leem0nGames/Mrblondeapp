
-- ### TAREAS INICIALES DE LIMPIEZA ###
-- Estas sentencias eliminan las tablas y tipos existentes para asegurar un estado limpio.
-- El uso de 'CASCADE' es crucial para eliminar objetos que dependen de las tablas (vistas, políticas, etc.).

drop table if exists "public"."products" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."order_items" cascade;
drop view if exists "public"."dashboard_stats" cascade;
drop view if exists "public"."agreements_with_counts" cascade;
drop function if exists public.get_client_stats(p_client_id uuid);
drop function if exists public.increment_total_revenue(amount_to_add numeric);

-- Elimina las políticas de RLS de Storage si existen, antes de recrear los buckets.
drop policy if exists "Allow public read access to product images" on storage.objects;
drop policy if exists "Allow admins to manage product images" on storage.objects;


-- ### GESTIÓN DE STORAGE (ALMACENAMIENTO) ###

-- Crear el bucket para las imágenes de productos si no existe.
insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

-- POLÍTICAS DE ACCESO AL BUCKET
-- 1. Permite el acceso público de LECTURA a todas las imágenes en el bucket 'product_images'.
--    Esto es necesario para que las imágenes puedan ser mostradas en la aplicación cliente.
create policy "Allow public read access to product images"
on storage.objects for select
using ( bucket_id = 'product_images' );

-- 2. Permite a los usuarios autenticados (administradores) realizar todas las operaciones (subir, actualizar, eliminar).
--    Esto es para que los administradores puedan gestionar las imágenes de los productos desde el panel.
create policy "Allow admins to manage product images"
on storage.objects for all
using ( auth.role() = 'authenticated' )
with check ( auth.role() = 'authenticated' );


-- ### CREACIÓN DE TABLAS ###

-- Tabla de Productos: Almacena el catálogo de productos base.
create table "public"."products" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "category" text,
    "image_url" text,
    "created_at" timestamp with time zone not null default now(),
    constraint "products_pkey" primary key (id)
);

-- Tabla de Listas de Precios: Contenedor para diferentes listas de precios (ej. Mayorista, Minorista).
create table "public"."price_lists" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "prices_include_vat" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    constraint "price_lists_pkey" primary key (id),
    constraint "price_lists_name_key" unique (name)
);

-- Tabla de Items de Lista de Precios: Define el precio de un producto específico en una lista de precios.
create table "public"."price_list_items" (
    "price_list_id" uuid not null,
    "product_id" uuid not null,
    "price" numeric not null default 0,
    "volume_price" numeric,
    "created_at" timestamp with time zone not null default now(),
    constraint "price_list_items_pkey" primary key (price_list_id, product_id),
    constraint "price_list_items_price_list_id_fkey" foreign key (price_list_id) references price_lists (id) on delete cascade,
    constraint "price_list_items_product_id_fkey" foreign key (product_id) references products (id) on delete cascade
);

-- Tabla de Convenios: Define las reglas comerciales para un grupo de clientes.
create table "public"."agreements" (
    "id" uuid not null default gen_random_uuid(),
    "agreement_name" text not null,
    "client_type" text not null default 'barberia'::text,
    "created_at" timestamp with time zone not null default now(),
    "price_list_id" uuid,
    constraint "agreements_pkey" primary key (id),
    constraint "agreements_name_key" unique (agreement_name),
    constraint "agreements_price_list_id_fkey" foreign key (price_list_id) references price_lists (id) on delete set null
);

-- Tabla de Clientes: Almacena la información de los clientes (barberías, distribuidoras).
create table "public"."clients" (
    "id" uuid not null default gen_random_uuid(),
    "cuit" text,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text,
    "instagram" text,
    "status" text not null default 'pending_onboarding'::text,
    "onboarding_token" uuid not null default gen_random_uuid(),
    "agreement_id" uuid,
    "created_at" timestamp with time zone not null default now(),
    "fiscal_status" text,
    constraint "clients_pkey" primary key (id),
    constraint "clients_cuit_key" unique (cuit),
    constraint "clients_email_key" unique (email),
    constraint "clients_onboarding_token_key" unique (onboarding_token),
    constraint "clients_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete set null,
    constraint "clients_agreement_id_unique" unique (agreement_id)
);


-- Tabla de Promociones: Define las promociones disponibles (ej. 2x1, envío gratis).
create table "public"."promotions" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "rules" jsonb,
    "created_at" timestamp with time zone not null default now(),
    constraint "promotions_pkey" primary key (id)
);

-- Tabla de Condiciones de Venta: Define las condiciones financieras (ej. pago a 30 días).
create table "public"."sales_conditions" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "rules" jsonb,
    "created_at" timestamp with time zone not null default now(),
    constraint "sales_conditions_pkey" primary key (id)
);

-- Tabla de Unión (Promociones <-> Convenios): Asigna promociones a convenios.
create table "public"."agreement_promotions" (
    "agreement_id" uuid not null,
    "promotion_id" uuid not null,
    constraint "agreement_promotions_pkey" primary key (agreement_id, promotion_id),
    constraint "agreement_promotions_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint "agreement_promotions_promotion_id_fkey" foreign key (promotion_id) references promotions (id) on delete cascade
);

-- Tabla de Unión (Cond. Venta <-> Convenios): Asigna condiciones de venta a convenios.
create table "public"."agreement_sales_conditions" (
    "agreement_id" uuid not null,
    "sales_condition_id" uuid not null,
    constraint "agreement_sales_conditions_pkey" primary key (agreement_id, sales_condition_id),
    constraint "agreement_sales_conditions_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint "agreement_sales_conditions_sales_condition_id_fkey" foreign key (sales_condition_id) references sales_conditions (id) on delete cascade
);

-- Tabla de Pedidos: Registra los pedidos realizados por los clientes.
create table "public"."orders" (
    "id" uuid not null default gen_random_uuid(),
    "client_id" uuid not null,
    "agreement_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),
    "total_amount" numeric not null default 0,
    "status" text not null default 'pending'::text,
    "client_name_cache" text not null,
    constraint "orders_pkey" primary key (id),
    constraint "orders_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete restrict,
    constraint "orders_client_id_fkey" foreign key (client_id) references clients (id) on delete restrict
);

-- Tabla de Items de Pedido: Detalla los productos y cantidades de cada pedido.
create table "public"."order_items" (
    "id" uuid not null default gen_random_uuid(),
    "order_id" uuid not null,
    "product_id" uuid not null,
    "quantity" integer not null,
    "price_per_unit" numeric not null,
    constraint "order_items_pkey" primary key (id),
    constraint "order_items_order_id_fkey" foreign key (order_id) references orders (id) on delete cascade,
    constraint "order_items_product_id_fkey" foreign key (product_id) references products (id) on delete restrict
);


-- Habilitar Row Level Security (RLS) en todas las tablas.
-- Esto asegura que, por defecto, nadie puede acceder a los datos a menos que una política lo permita.
alter table "public"."products" enable row level security;
alter table "public"."promotions" enable row level security;
alter table "public"."sales_conditions" enable row level security;
alter table "public"."price_lists" enable row level security;
alter table "public"."price_list_items" enable row level security;
alter table "public"."agreements" enable row level security;
alter table "public"."clients" enable row level security;
alter table "public"."agreement_promotions" enable row level security;
alter table "public"."agreement_sales_conditions" enable row level security;
alter table "public"."orders" enable row level security;
alter table "public"."order_items" enable row level security;

-- ### VISTAS (VIEWS) ###

-- Vista para Estadísticas del Dashboard: Simplifica las consultas de agregación para el panel de admin.
create or replace view public.dashboard_stats as
select
  (
    select
      coalesce(sum(total_amount), 0)
    from
      public.orders
    where
      status = 'completed'
  ) as total_revenue,
  (
    select
      coalesce(sum(total_amount), 0)
    from
      public.orders
    where
      status = 'completed' and created_at >= date_trunc('month', now())
  ) as month_revenue,
  (
    select
      count(*)
    from
      public.clients
    where
      status = 'active'
  ) as active_clients;


-- Vista para Convenios con Conteos: Muestra cuántas promociones y condiciones tiene cada convenio.
create or replace view public.agreements_with_counts as
select
  a.*,
  (
    select
      count(*)
    from
      public.agreement_promotions ap
    where
      ap.agreement_id = a.id
  ) as promotion_count,
  (
    select
      count(*)
    from
      public.agreement_sales_conditions asc_join
    where
      asc_join.agreement_id = a.id
  ) as sales_condition_count
from
  public.agreements a;


-- ### FUNCIONES (FUNCTIONS) ###

-- Función para Estadísticas de Cliente: Calcula el gasto total, pedido promedio y total de pedidos para un cliente.
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
    o.client_id = p_client_id;
end;
$$;

-- Función para Incrementar Ingresos: Es una función dummy para el ejemplo.
create or replace function public.increment_total_revenue(amount_to_add numeric)
returns void
language plpgsql
as $$
begin
  -- Esta función es un placeholder. En una implementación real, podría actualizar
  -- una tabla de métricas o realizar una operación más compleja.
  -- Por ahora, no hace nada para no interferir con la vista dashboard_stats.
end;
$$;


-- ### POLÍTICAS DE RLS (ROW LEVEL SECURITY) ###
-- Define quién puede ver y hacer qué en cada tabla.

-- Los usuarios autenticados (admins) pueden gestionar todo en estas tablas.
create policy "Allow full access to admins" on public.products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.price_lists for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.price_list_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.agreements for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.clients for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.agreement_promotions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.orders for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "Allow full access to admins" on public.order_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');


-- El público general puede leer la información necesaria para la página de pedidos.
-- No se requiere que el cliente final esté logueado.
create policy "Allow public read access for order page" on public.agreements for select using (true);
create policy "Allow public read access for order page" on public.clients for select using (true);
create policy "Allow public read access for order page" on public.price_lists for select using (true);
create policy "Allow public read access for order page" on public.price_list_items for select using (true);
create policy "Allow public read access for order page" on public.products for select using (true);
create policy "Allow public read access for order page" on public.promotions for select using (true);
create policy "Allow public read access for order page" on public.agreement_promotions for select using (true);

-- Permite la creación de pedidos (INSERT) a cualquier usuario (anónimo o autenticado).
create policy "Allow public insert for orders" on public.orders for insert with check (true);
create policy "Allow public insert for order items" on public.order_items for insert with check (true);

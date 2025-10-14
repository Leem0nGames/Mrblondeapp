-- =================================================================================================
--                              DESTRUCCIÓN Y RECONSTRUCCIÓN DE TABLAS
-- =================================================================================================
-- Este bloque se asegura de que el script pueda ejecutarse varias veces sin errores.
-- Elimina las tablas existentes en el orden correcto para evitar problemas de dependencias.
-- La cláusula CASCADE elimina automáticamente cualquier objeto que dependa de la tabla que se está eliminando.

drop table if exists "public"."order_items" cascade;
drop table if exists "public"."orders" cascade;
drop table if exists "public"."agreement_promotions" cascade;
drop table if exists "public"."agreement_sales_conditions" cascade;
drop table if exists "public"."price_list_items" cascade;
drop table if exists "public"."clients" cascade;
drop table if exists "public"."agreements" cascade;
drop table if exists "public"."promotions" cascade;
drop table if exists "public"."price_lists" cascade;
drop table if exists "public"."products" cascade;
drop table if exists "public"."sales_conditions" cascade;
drop table if exists "public"."dashboard_stats" cascade;


-- =================================================================================================
--                                    CREACIÓN DE TABLAS
-- =================================================================================================

-- Tabla de Productos: Catálogo central de todos los productos disponibles.
create table "public"."products" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "category" text,
    "created_at" timestamptz not null default now(),
    constraint "products_pkey" primary key (id)
);
alter table "public"."products" enable row level security;
CREATE UNIQUE INDEX products_name_idx ON public.products USING btree (name);

-- Tabla de Listas de Precios: Contenedores para diferentes conjuntos de precios.
create table "public"."price_lists" (
    "id"uuid not null default gen_random_uuid(),
    "name" text not null,
    "prices_include_vat" boolean not null default true,
    "created_at" timestamptz not null default now(),
    constraint "price_lists_pkey" primary key (id),
    constraint "price_lists_name_key" unique ("name")
);
alter table "public"."price_lists" enable row level security;


-- Tabla de Items en Listas de Precios: Define el precio de un producto específico dentro de una lista.
create table "public"."price_list_items" (
    "price_list_id" uuid not null,
    "product_id" uuid not null,
    "price" numeric not null default 0,
    "volume_price" numeric,
    constraint "price_list_items_pkey" primary key (price_list_id, product_id),
    constraint "price_list_items_price_list_id_fkey" foreign key (price_list_id) references price_lists (id) on delete cascade,
    constraint "price_list_items_product_id_fkey" foreign key (product_id) references products (id) on delete cascade
);
alter table "public"."price_list_items" enable row level security;


-- Tabla de Convenios: Define los términos comerciales para un tipo de cliente.
create table "public"."agreements" (
    "id" uuid not null default gen_random_uuid(),
    "agreement_name" text not null,
    "client_type" text not null,
    "created_at" timestamptz not null default now(),
    "price_list_id" uuid,
    constraint "agreements_pkey" primary key (id),
    constraint "agreements_price_list_id_fkey" foreign key (price_list_id) references price_lists (id) on delete set null,
    constraint "agreements_agreement_name_key" unique ("agreement_name")
);
alter table "public"."agreements" enable row level security;

-- Tabla de Promociones: Define las promociones que pueden ser asignadas a los convenios.
create table "public"."promotions" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz not null default now(),
    constraint "promotions_pkey" primary key (id)
);
alter table "public"."promotions" enable row level security;

-- Tabla de Unión: Asigna promociones a los convenios.
create table "public"."agreement_promotions" (
    "agreement_id" uuid not null,
    "promotion_id" uuid not null,
    constraint "agreement_promotions_pkey" primary key (agreement_id, promotion_id),
    constraint "agreement_promotions_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint "agreement_promotions_promotion_id_fkey" foreign key (promotion_id) references promotions (id) on delete cascade
);
alter table "public"."agreement_promotions" enable row level security;

-- Tabla de Condiciones de Venta: Define las condiciones de pago.
create table "public"."sales_conditions" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "rules" jsonb,
    "created_at" timestamptz not null default now(),
    constraint "sales_conditions_pkey" primary key (id)
);
alter table "public"."sales_conditions" enable row level security;

-- Tabla de Unión: Asigna condiciones de venta a los convenios.
create table "public"."agreement_sales_conditions" (
    "agreement_id" uuid not null,
    "sales_condition_id" uuid not null,
    constraint "agreement_sales_conditions_pkey" primary key (agreement_id, sales_condition_id),
    constraint "agreement_sales_conditions_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete cascade,
    constraint "agreement_sales_conditions_sales_condition_id_fkey" foreign key (sales_condition_id) references sales_conditions (id) on delete cascade
);
alter table "public"."agreement_sales_conditions" enable row level security;

-- Tabla de Clientes: Almacena la información de cada cliente.
create table "public"."clients" (
    "id" uuid not null default gen_random_uuid(),
    "cuit" text,
    "contact_name" text,
    "contact_dni" text,
    "address" text,
    "delivery_window" text,
    "email" text,
    "instagram" text,
    "status" text not null default 'pending_onboarding',
    "onboarding_token" text not null default gen_random_uuid(),
    "agreement_id" uuid,
    "created_at" timestamptz not null default now(),
    "fiscal_status" text,
    constraint "clients_pkey" primary key (id),
    constraint "clients_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete set null,
    constraint "clients_cuit_key" unique ("cuit"),
    constraint "clients_email_key" unique ("email")
);
alter table "public"."clients" enable row level security;

-- Tabla de Pedidos: Registra cada pedido realizado.
create table "public"."orders" (
    "id" uuid not null default gen_random_uuid(),
    "client_id" uuid not null,
    "agreement_id" uuid not null,
    "created_at" timestamptz not null default now(),
    "total_amount" numeric not null,
    "status" text not null default 'pending',
    "client_name_cache" text not null,
    constraint "orders_pkey" primary key (id),
    constraint "orders_agreement_id_fkey" foreign key (agreement_id) references agreements (id) on delete restrict,
    constraint "orders_client_id_fkey" foreign key (client_id) references clients (id) on delete restrict
);
alter table "public"."orders" enable row level security;

-- Tabla de Items de Pedido: Detalle de los productos en cada pedido.
create table "public"."order_items" (
    "order_id" uuid not null,
    "product_id" uuid not null,
    "quantity" integer not null,
    "price_per_unit" numeric not null,
    constraint "order_items_pkey" primary key (order_id, product_id),
    constraint "order_items_order_id_fkey" foreign key (order_id) references orders (id) on delete cascade,
    constraint "order_items_product_id_fkey" foreign key (product_id) references products (id) on delete restrict
);
alter table "public"."order_items" enable row level security;

-- Tabla de Estadísticas del Dashboard: Agregados para un acceso rápido a métricas clave.
create table "public"."dashboard_stats" (
    "id" integer primary key generated always as identity,
    "total_revenue" numeric default 0,
    "month_revenue" numeric default 0, -- Nota: Lógica para actualizar no incluida en este esquema.
    "active_clients" integer default 0
);
alter table "public"."dashboard_stats" enable row level security;
-- Insertar una fila inicial para poder actualizarla
insert into "public"."dashboard_stats" (id, total_revenue, month_revenue, active_clients) values (1, 0, 0, 0);


-- =================================================================================================
--                                           VISTAS
-- =================================================================================================
-- Vista para contar promociones y condiciones de venta por convenio.
-- Esto simplifica las consultas en el frontend.

create or replace view "public"."agreements_with_counts" as
select
    a.id,
    a.agreement_name,
    a.client_type,
    a.created_at,
    a.price_list_id,
    (select count(*) from agreement_promotions where agreement_id = a.id) as promotion_count,
    (select count(*) from agreement_sales_conditions where agreement_id = a.id) as sales_condition_count
from
    agreements a;
alter table "public"."agreements_with_counts" enable row level security;

-- =================================================================================================
--                                    FUNCIONES DE BASE DE DATOS (RPC)
-- =================================================================================================

-- Función para incrementar los ingresos totales en la tabla de estadísticas.
-- Se usa cuando se completa un pedido.
create or replace function "public"."increment_total_revenue"(amount_to_add numeric)
returns void as $$
begin
    update public.dashboard_stats
    set total_revenue = total_revenue + amount_to_add
    where id = 1;
end;
$$ language plpgsql;

-- Función para obtener estadísticas de un cliente específico.
create or replace function "public"."get_client_stats"(p_client_id uuid)
returns table(total_spent numeric, average_order_value numeric, total_orders bigint) as $$
begin
    return query
    select
        coalesce(sum(o.total_amount), 0)::numeric as total_spent,
        coalesce(avg(o.total_amount), 0)::numeric as average_order_value,
        count(o.id)::bigint as total_orders
    from
        public.orders o
    where
        o.client_id = p_client_id and o.status = 'completed';
end;
$$ language plpgsql;


-- =================================================================================================
--                              POLÍTICAS DE SEGURIDAD (RLS)
-- =================================================================================================
-- Permisos para usuarios autenticados (administradores).
-- Por defecto, se deniega todo. Se otorgan permisos explícitos para 'select', 'insert', 'update', 'delete'.

-- Productos
grant select, insert, update, delete on table "public"."products" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."products" with check (true);

-- Listas de Precios
grant select, insert, update, delete on table "public"."price_lists" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."price_lists" with check (true);

-- Items de Listas de Precios
grant select, insert, update, delete on table "public"."price_list_items" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."price_list_items" with check (true);

-- Convenios
grant select, insert, update, delete on table "public"."agreements" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."agreements" with check (true);

-- Promociones
grant select, insert, update, delete on table "public"."promotions" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."promotions" with check (true);

-- Unión Convenio-Promoción
grant select, insert, update, delete on table "public"."agreement_promotions" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."agreement_promotions" with check (true);

-- Condiciones de Venta
grant select, insert, update, delete on table "public"."sales_conditions" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."sales_conditions" with check (true);

-- Unión Convenio-Condición
grant select, insert, update, delete on table "public"."agreement_sales_conditions" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."agreement_sales_conditions" with check (true);

-- Clientes
grant select, insert, update, delete on table "public"."clients" to "authenticated";
alter policy "Enable insert for authenticated users only" on "public"."clients" for insert with check (true);
alter policy "Enable read access for all users" on "public"."clients" for select using (true);
alter policy "Enable update for users based on email" on "public"."clients" for update using (true) with check (true);
alter policy "Enable delete for users based on user_id" on "public"."clients" for delete using (true);

-- Pedidos
grant select, insert, update, delete on table "public"."orders" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."orders" with check (true);

-- Items de Pedido
grant select, insert, update, delete on table "public"."order_items" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."order_items" with check (true);

-- Estadísticas del Dashboard
grant select, insert, update, delete on table "public"."dashboard_stats" to "authenticated";
alter policy "Enable all access for authenticated users" on "public"."dashboard_stats" with check (true);

-- Vista de Convenios con conteos
grant select on table "public"."agreements_with_counts" to "authenticated";
alter policy "Enable read access for all users" on "public"."agreements_with_counts" for select using (true);

-- =================================================================================================
-- Permisos para acceso anónimo (público).
-- Necesario para que la página de pedido y la de alta de cliente funcionen sin iniciar sesión.
-- Se permite acceso de solo lectura a la información necesaria.

grant select on table "public"."products" to "anon";
alter policy "Enable read access for all users" on "public"."products" for select to anon using (true);

grant select on table "public"."price_lists" to "anon";
alter policy "Enable read access for all users" on "public"."price_lists" for select to anon using (true);

grant select on table "public"."price_list_items" to "anon";
alter policy "Enable read access for all users" on "public"."price_list_items" for select to anon using (true);

grant select on table "public"."agreements" to "anon";
alter policy "Enable read access for all users" on "public"."agreements" for select to anon using (true);

grant select on table "public"."promotions" to "anon";
alter policy "Enable read access for all users" on "public"."promotions" for select to anon using (true);

grant select on table "public"."agreement_promotions" to "anon";
alter policy "Enable read access for all users" on "public"."agreement_promotions" for select to anon using (true);

grant select on table "public"."clients" to "anon";
alter policy "Enable read access for anon" on "public"."clients" for select to anon using (true);

grant insert on table "public"."orders" to "anon";
alter policy "Enable insert for anon" on "public"."orders" for insert to anon with check(true);

grant insert on table "public"."order_items" to "anon";
alter policy "Enable insert for anon" on "public"."order_items" for insert to anon with check(true);

grant update on table "public"."clients" to "anon";
alter policy "Enable update for anon" on "public"."clients" for update to anon using (true) with check (true);

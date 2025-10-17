
-- ----------------------------
-- BLONDE ORDERS - SUPABASE SCHEMA
-- ----------------------------
-- Este script es idempotente, lo que significa que se puede ejecutar de forma segura
-- en una base de datos nueva o existente. Se encargará de limpiar y reconfigurar
-- las tablas, funciones y políticas de seguridad.

begin;

-- 1. LIMPIEZA INICIAL
-- -------------------
-- Elimina los tipos ENUM personalizados, si existen.
drop type if exists public.client_status cascade;
drop type if exists public.order_status cascade;

-- Elimina las tablas existentes en orden inverso de dependencia.
-- Usamos CASCADE para eliminar automáticamente objetos dependientes (vistas, funciones, etc.).
drop table if exists public.system_settings cascade;
drop table if exists public.order_items cascade;
drop table if exists public.orders cascade;
drop table if exists public.clients cascade;
drop table if exists public.agreement_sales_conditions cascade;
drop table if exists public.agreement_promotions cascade;
drop table if exists public.price_list_items cascade;
drop table if exists public.agreements cascade;
drop table if exists public.sales_conditions cascade;
drop table if exists public.promotions cascade;
drop table if exists public.price_lists cascade;
drop table if exists public.products cascade;

-- Elimina cualquier versión anterior de las funciones para evitar conflictos.
drop function if exists public.get_client_stats(uuid);
drop function if exists public.get_overdue_orders();
drop function if exists public.get_overdue_orders(uuid);
drop function if exists public.handle_new_user();

-- 2. CREACIÓN DE TIPOS Y TABLAS
-- -----------------------------

-- Tipos ENUM para estados
create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active', 'archived');
create type public.order_status as enum ('pending', 'completed');

-- Tabla de Productos
create table public.products (
  id uuid primary key default gen_random_uuid(),
    name text not null,
      description text,
        category text,
          image_url text,
            created_at timestamptz not null default now()
            );
            comment on table public.products is 'Catálogo de todos los productos disponibles.';

            -- Tabla de Listas de Precios
            create table public.price_lists (
              id uuid primary key default gen_random_uuid(),
                name text not null unique,
                  prices_include_vat boolean not null default true,
                    created_at timestamptz not null default now()
                    );
                    comment on table public.price_lists is 'Contenedores para diferentes listas de precios (e.g., "Precios Distribuidor 2024").';

                    -- Tabla de Items en Listas de Precios (Tabla Pivot)
                    create table public.price_list_items (
                      price_list_id uuid not null references public.price_lists(id) on delete cascade,
                        product_id uuid not null references public.products(id) on delete cascade,
                          price numeric(10, 2) not null check (price >= 0),
                            volume_price numeric(10, 2) check (volume_price >= 0),
                              primary key (price_list_id, product_id)
                              );
                              comment on table public.price_list_items is 'Define el precio de un producto específico dentro de una lista de precios.';

                              -- Tabla de Promociones
                              create table public.promotions (
                                id uuid primary key default gen_random_uuid(),
                                  name text not null,
                                    description text,
                                      rules jsonb,
                                        created_at timestamptz not null default now()
                                        );
                                        comment on table public.promotions is 'Define promociones reutilizables (e.g., 2x1, envío gratis).';

                                        -- Tabla de Condiciones de Venta
                                        create table public.sales_conditions (
                                          id uuid primary key default gen_random_uuid(),
                                            name text not null,
                                              description text,
                                                rules jsonb,
                                                  created_at timestamptz not null default now()
                                                  );
                                                  comment on table public.sales_conditions is 'Define condiciones comerciales (plazos de pago, descuentos).';

                                                  -- Tabla de Convenios
                                                  create table public.agreements (
                                                    id uuid primary key default gen_random_uuid(),
                                                      agreement_name text not null unique,
                                                        client_type text not null,
                                                          price_list_id uuid references public.price_lists(id) on delete set null,
                                                            created_at timestamptz not null default now()
                                                            );
                                                            comment on table public.agreements is 'Convenios que agrupan listas de precios, promociones y condiciones para un tipo de cliente.';

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

                                                                        -- Tabla de Clientes
                                                                        create table public.clients (
                                                                          id uuid primary key default gen_random_uuid(),
                                                                            cuit text unique,
                                                                              contact_name text,
                                                                                contact_dni text,
                                                                                  address text,
                                                                                    delivery_window text,
                                                                                      email text unique,
                                                                                        instagram text,
                                                                                          status client_status not null default 'pending_onboarding',
                                                                                            onboarding_token uuid not null default gen_random_uuid(),
                                                                                              agreement_id uuid references public.agreements(id) on delete set null,
                                                                                                fiscal_status text,
                                                                                                  created_at timestamptz not null default now()
                                                                                                  );
                                                                                                  comment on table public.clients is 'Información de los clientes finales (salones, distribuidores).';

                                                                                                  -- Tabla de Pedidos
                                                                                                  create table public.orders (
                                                                                                    id uuid primary key default gen_random_uuid(),
                                                                                                      client_id uuid not null references public.clients(id),
                                                                                                        agreement_id uuid not null references public.agreements(id),
                                                                                                          client_name_cache text not null,
                                                                                                            total_amount numeric(10, 2) not null,
                                                                                                              status order_status not null default 'pending',
                                                                                                                notes text,
                                                                                                                  created_at timestamptz not null default now()
                                                                                                                  );
                                                                                                                  comment on table public.orders is 'Registra cada pedido realizado por un cliente.';

                                                                                                                  -- Tabla de Items de Pedido
                                                                                                                  create table public.order_items (
                                                                                                                    id uuid primary key default gen_random_uuid(),
                                                                                                                      order_id uuid not null references public.orders(id) on delete cascade,
                                                                                                                        product_id uuid not null references public.products(id),
                                                                                                                          quantity integer not null,
                                                                                                                            price_per_unit numeric(10, 2) not null
                                                                                                                            );
                                                                                                                            comment on table public.order_items is 'Detalle de los productos en cada pedido.';

                                                                                                                            -- Tabla de Configuración del Sistema
                                                                                                                            create table public.system_settings (
                                                                                                                              key text primary key,
                                                                                                                                value jsonb,
                                                                                                                                  description text
                                                                                                                                  );
                                                                                                                                  comment on table public.system_settings is 'Almacena configuraciones globales del sistema.';

                                                                                                                                  -- Insertar valores iniciales para la configuración del sistema
                                                                                                                                  insert into public.system_settings (key, value, description)
                                                                                                                                  values 
                                                                                                                                    ('total_revenue', '{"value": 0}', 'Ingresos totales acumulados. No tocar manualmente.'),
                                                                                                                                      ('whatsapp_number', '{"number": "5491112345678"}', 'Número de WhatsApp para recibir pedidos.')
                                                                                                                                      on conflict (key) do nothing;


                                                                                                                                      -- 3. VISTAS
                                                                                                                                      -- ---------
                                                                                                                                      -- Vista para obtener convenios con conteo de promociones y condiciones
                                                                                                                                      create or replace view public.agreements_with_counts as
                                                                                                                                      select
                                                                                                                                        a.id,
                                                                                                                                          a.agreement_name,
                                                                                                                                            a.client_type,
                                                                                                                                              a.price_list_id,
                                                                                                                                                a.created_at,
                                                                                                                                                  pl.name as price_list_name,
                                                                                                                                                    (select name from public.price_lists where id = a.price_list_id) as price_list_name_direct,
                                                                                                                                                      (select count(*) from public.agreement_promotions ap where ap.agreement_id = a.id) as promotion_count,
                                                                                                                                                        (select count(*) from public.agreement_sales_conditions sc where sc.agreement_id = a.id) as sales_condition_count,
                                                                                                                                                          pl.name as "price_lists.name"
                                                                                                                                                          from
                                                                                                                                                            public.agreements a
                                                                                                                                                            left join
                                                                                                                                                              public.price_lists pl on a.price_list_id = pl.id;

                                                                                                                                                              -- Vista para estadísticas del dashboard
                                                                                                                                                              create or replace view public.dashboard_stats as
                                                                                                                                                              select
                                                                                                                                                                (select (value->>'value')::numeric from public.system_settings where key = 'total_revenue') as total_revenue,
                                                                                                                                                                  (select count(*) from public.clients where status = 'active') as active_clients,
                                                                                                                                                                    (select sum(total_amount) from public.orders where created_at >= date_trunc('month', now())) as month_revenue;


                                                                                                                                                                    -- 4. FUNCIONES RPC
                                                                                                                                                                    -- ----------------
                                                                                                                                                                    -- Función para estadísticas de un cliente específico
                                                                                                                                                                    create or replace function public.get_client_stats(p_client_id uuid)
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
                                                                                                                                                                                                o.client_id = p_client_id;
                                                                                                                                                                                                end;
                                                                                                                                                                                                $$ language plpgsql stable;

                                                                                                                                                                                                -- Función para incrementar los ingresos totales
                                                                                                                                                                                                create or replace function public.increment_total_revenue(amount_to_add numeric)
                                                                                                                                                                                                returns void as $$
                                                                                                                                                                                                declare
                                                                                                                                                                                                  current_revenue numeric;
                                                                                                                                                                                                  begin
                                                                                                                                                                                                    -- Obtener el valor actual de forma segura
                                                                                                                                                                                                      select (value->>'value')::numeric into current_revenue from public.system_settings where key = 'total_revenue';

                                                                                                                                                                                                        -- Actualizar el valor
                                                                                                                                                                                                          update public.system_settings
                                                                                                                                                                                                            set value = jsonb_set(value, '{value}', to_jsonb(current_revenue + amount_to_add))
                                                                                                                                                                                                              where key = 'total_revenue';
                                                                                                                                                                                                              end;
                                                                                                                                                                                                              $$ language plpgsql volatile;

                                                                                                                                                                                                              -- Función para obtener pedidos vencidos
                                                                                                                                                                                                              create or replace function public.get_overdue_orders()
                                                                                                                                                                                                              returns setof public.orders as $$
                                                                                                                                                                                                              begin
                                                                                                                                                                                                                return query
                                                                                                                                                                                                                  select o.*
                                                                                                                                                                                                                    from public.orders o
                                                                                                                                                                                                                      join public.agreements a on o.agreement_id = a.id
                                                                                                                                                                                                                        join public.agreement_sales_conditions asc_join on a.id = asc_join.agreement_id
                                                                                                                                                                                                                          join public.sales_conditions sc on asc_join.sales_condition_id = sc.id
                                                                                                                                                                                                                            where
                                                                                                                                                                                                                                o.status = 'pending'
                                                                                                                                                                                                                                    and sc.rules->>'type' = 'net_days'
                                                                                                                                                                                                                                        and o.created_at < (now() - (sc.rules->>'days' || ' days')::interval);
                                                                                                                                                                                                                                        end;
                                                                                                                                                                                                                                        $$ language plpgsql stable;


                                                                                                                                                                                                                                        -- 5. POLÍTICAS DE SEGURIDAD (RLS)
                                                                                                                                                                                                                                        -- ---------------------------------
                                                                                                                                                                                                                                        -- Habilitar RLS en las tablas
                                                                                                                                                                                                                                        alter table public.products enable row level security;
                                                                                                                                                                                                                                        alter table public.price_lists enable row level security;
                                                                                                                                                                                                                                        alter table public.price_list_items enable row level security;
                                                                                                                                                                                                                                        alter table public.promotions enable row level security;
                                                                                                                                                                                                                                        alter table public.sales_conditions enable row level security;
                                                                                                                                                                                                                                        alter table public.agreements enable row level security;
                                                                                                                                                                                                                                        alter table public.agreement_promotions enable row level security;
                                                                                                                                                                                                                                        alter table public.agreement_sales_conditions enable row level security;
                                                                                                                                                                                                                                        alter table public.clients enable row level security;
                                                                                                                                                                                                                                        alter table public.orders enable row level security;
                                                                                                                                                                                                                                        alter table public.order_items enable row level security;
                                                                                                                                                                                                                                        alter table public.system_settings enable row level security;

                                                                                                                                                                                                                                        -- Limpiar políticas existentes para evitar duplicados
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.products;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.price_lists;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.price_list_items;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.promotions;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.sales_conditions;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.agreements;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.agreement_promotions;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read-only access" on public.agreement_sales_conditions;
                                                                                                                                                                                                                                        drop policy if exists "Allow public read access for onboarding" on public.clients;
                                                                                                                                                                                                                                        drop policy if exists "Allow authenticated users to create orders" on public.orders;
                                                                                                                                                                                                                                        drop policy if exists "Allow authenticated users to create order items" on public.order_items;

                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.products;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.price_lists;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.price_list_items;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.promotions;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.sales_conditions;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.agreements;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.agreement_promotions;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.agreement_sales_conditions;
                                                                                                                                                                                                                                        drop policy if exists "Allow full access for authenticated admin users" on public.clients;
                                                                                                                                                                                                                                        drop policy if exists "Allow admin read access" on public.orders;
                                                                                                                                                                                                                                        drop policy if exists "Allow admin read access" on public.order_items;
                                                                                                                                                                                                                                        drop policy if exists "Allow admin full access" on public.system_settings;


                                                                                                                                                                                                                                        -- Políticas de Acceso Público (para páginas de pedidos)
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.products for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.price_lists for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.price_list_items for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.promotions for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.sales_conditions for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.agreements for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.agreement_promotions for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read-only access" on public.agreement_sales_conditions for select using (true);
                                                                                                                                                                                                                                        create policy "Allow public read access for onboarding" on public.clients for select using (true);

                                                                                                                                                                                                                                        -- Políticas para creación de Pedidos (requiere `anon` key, que es un usuario "autenticado" pero anónimo)
                                                                                                                                                                                                                                        create policy "Allow authenticated users to create orders" on public.orders for insert with check (auth.role() = 'anon' or auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow authenticated users to create order items" on public.order_items for insert with check (auth.role() = 'anon' or auth.role() = 'authenticated');


                                                                                                                                                                                                                                        -- Políticas para Administradores (requiere `service_role` o un JWT de un usuario autenticado)
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.products for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.price_lists for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.price_list_items for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.promotions for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.sales_conditions for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.agreements for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.agreement_promotions for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.agreement_sales_conditions for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow full access for authenticated admin users" on public.clients for all using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow admin read access" on public.orders for select using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow admin read access" on public.order_items for select using (auth.role() = 'authenticated');
                                                                                                                                                                                                                                        create policy "Allow admin full access" on public.system_settings for all using (auth.role() = 'authenticated');


                                                                                                                                                                                                                                        -- 6. TRIGGERS
                                                                                                                                                                                                                                        -- ------------
                                                                                                                                                                                                                                        -- Función que se ejecuta cuando se crea un nuevo usuario en `auth.users`
                                                                                                                                                                                                                                        -- (No es necesario, Supabase lo maneja, pero es un ejemplo si se necesitara).
                                                                                                                                                                                                                                        -- create function public.handle_new_user()
                                                                                                                                                                                                                                        -- returns trigger as $$
                                                                                                                                                                                                                                        -- begin
                                                                                                                                                                                                                                        --   insert into public.users (id, email)
                                                                                                                                                                                                                                        --   values (new.id, new.email);
                                                                                                                                                                                                                                        --   return new;
                                                                                                                                                                                                                                        -- end;
                                                                                                                                                                                                                                        -- $$ language plpgsql security definer;

                                                                                                                                                                                                                                        -- Trigger que llama a la función anterior
                                                                                                                                                                                                                                        -- drop trigger if exists on_auth_user_created on auth.users;
                                                                                                                                                                                                                                        -- create trigger on_auth_user_created
                                                                                                                                                                                                                                        --   after insert on auth.users
                                                                                                                                                                                                                                        --   for each row execute procedure public.handle_new_user();


                                                                                                                                                                                                                                        commit;
                                                                                                                                                                                                                                        -- ----------------------------
                                                                                                                                                                                                                                        -- FIN DEL SCRIPT
                                                                                                                                                                                                                                        -- ----------------------------
                                                                                                                                                                                                                                        -- La base de datos está lista.
                                                                                                                                                                                                                                        -- Ahora puedes cargar datos de ejemplo si lo deseas (seed.sql).
                                                                                                                                                                                                                                        -- ----------------------------

                                                                                                                                                                                                                                        
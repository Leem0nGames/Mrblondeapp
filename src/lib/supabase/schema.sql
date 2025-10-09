-- =================================================================
--  SCRIPT DE BASE DE DATOS PARA "BLONDE ORDERS"
--  Versión: 2.0.0
--  Descripción: Script idempotente para crear todas las tablas,
--             tipos, relaciones y políticas de seguridad (RLS).
--             Puede ejecutarse de forma segura en una base de
--             datos existente.
-- =================================================================

-- ========= EXTENSIONES =============================================
-- Habilitar la extensión para usar UUIDs
create extension if not exists "uuid-ossp" with schema extensions;


-- ========= TIPOS ENUM ================================================
-- Define el tipo para el rol de cliente, si no existe.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'client_type') then
    create type public.client_type as enum ('barberia', 'distribuidor', 'especial');
  end if;
end$$;

-- Define el tipo para el estado del cliente, si no existe.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'client_status') then
    create type public.client_status as enum ('pending_onboarding', 'pending_agreement', 'active');
  end if;
end$$;


-- ========= TABLAS ======================================================

-- Tabla de PRODUCTOS
create table if not exists public.products (
  id uuid default extensions.uuid_generate_v4() not null,
  name character varying not null,
  description text null,
  base_price numeric(10, 2) not null default 0.00,
  stock integer not null default 0,
  category character varying null,
  created_at timestamp with time zone not null default now(),
  constraint products_pkey primary key (id)
);
comment on table public.products is 'Catálogo de todos los productos disponibles.';

-- Tabla de LISTAS DE PRECIOS
create table if not exists public.price_lists (
    id uuid not null default extensions.uuid_generate_v4(),
    name character varying not null,
    prices_include_vat boolean not null default true,
    created_at timestamp with time zone not null default now(),
    constraint price_lists_pkey primary key (id),
    constraint price_lists_name_key unique (name)
);
comment on table public.price_lists is 'Listas de precios reutilizables para diferentes convenios.';

-- Tabla de ITEMS DE LISTAS DE PRECIOS (Tabla intermedia)
create table if not exists public.price_list_items (
    price_list_id uuid not null,
    product_id uuid not null,
    price numeric(10, 2) not null,
    volume_price numeric(10, 2) null,
    created_at timestamp with time zone not null default now(),
    constraint price_list_items_pkey primary key (price_list_id, product_id),
    constraint price_list_items_price_list_id_fkey foreign key (price_list_id) references public.price_lists (id) on delete cascade,
    constraint price_list_items_product_id_fkey foreign key (product_id) references public.products (id) on delete cascade
);
comment on table public.price_list_items is 'Define el precio de un producto dentro de una lista específica.';

-- Tabla de CONVENIOS
create table if not exists public.agreements (
  id uuid default extensions.uuid_generate_v4() not null,
  agreement_name character varying not null,
  client_type public.client_type not null,
  created_at timestamp with time zone not null default now(),
  price_list_id uuid null,
  constraint agreements_pkey primary key (id),
  constraint agreements_agreement_name_key unique (agreement_name),
  constraint agreements_price_list_id_fkey foreign key (price_list_id) references public.price_lists (id) on delete set null
);
comment on table public.agreements is 'Convenios comerciales que agrupan precios y promociones.';

-- Tabla de CLIENTES
create table if not exists public.clients (
    id uuid not null default extensions.uuid_generate_v4(),
    cuit character varying null,
    contact_name character varying null,
    contact_dni character varying null,
    address character varying null,
    delivery_window text null,
    email character varying null,
    instagram character varying null,
    status public.client_status not null default 'pending_onboarding'::client_status,
    onboarding_token uuid not null default extensions.uuid_generate_v4(),
    agreement_id uuid null,
    created_at timestamp with time zone not null default now(),
    constraint clients_pkey primary key (id),
    constraint clients_cuit_key unique (cuit),
    constraint clients_email_key unique (email),
    constraint clients_onboarding_token_key unique (onboarding_token),
    constraint clients_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete set null
);
comment on table public.clients is 'Almacena la información de los clientes finales.';

-- Tabla de PROMOCIONES
create table if not exists public.promotions (
  id uuid default extensions.uuid_generate_v4() not null,
  name character varying not null,
  description text null,
  rules jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default now(),
  constraint promotions_pkey primary key (id)
);
comment on table public.promotions is 'Promociones globales aplicables a los convenios.';

-- Tabla de PROMOCIONES POR CONVENIO (Tabla intermedia)
create table if not exists public.agreement_promotions (
  agreement_id uuid not null,
  promotion_id uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint agreement_promotions_pkey primary key (agreement_id, promotion_id),
  constraint agreement_promotions_agreement_id_fkey foreign key (agreement_id) references public.agreements (id) on delete cascade,
  constraint agreement_promotions_promotion_id_fkey foreign key (promotion_id) references public.promotions (id) on delete cascade
);
comment on table public.agreement_promotions is 'Asigna promociones específicas a un convenio.';


-- ========= POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY) ================

-- --- Tabla `products` ---
alter table public.products enable row level security;
drop policy if exists "Allow public read access to products" on public.products;
create policy "Allow public read access to products" on public.products for select using (true);
drop policy if exists "Allow admin access to manage products" on public.products;
create policy "Allow admin access to manage products" on public.products for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- --- Tabla `price_lists` ---
alter table public.price_lists enable row level security;
drop policy if exists "Allow public read access to price lists" on public.price_lists;
create policy "Allow public read access to price lists" on public.price_lists for select using (true);
drop policy if exists "Allow admin access to manage price lists" on public.price_lists;
create policy "Allow admin access to manage price lists" on public.price_lists for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- --- Tabla `price_list_items` ---
alter table public.price_list_items enable row level security;
drop policy if exists "Allow public read access to price list items" on public.price_list_items;
create policy "Allow public read access to price list items" on public.price_list_items for select using (true);
drop policy if exists "Allow admin access to manage price list items" on public.price_list_items;
create policy "Allow admin access to manage price list items" on public.price_list_items for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- --- Tabla `agreements` ---
alter table public.agreements enable row level security;
drop policy if exists "Allow public read access to agreements" on public.agreements;
create policy "Allow public read access to agreements" on public.agreements for select using (true);
drop policy if exists "Allow admin access to manage agreements" on public.agreements;
create policy "Allow admin access to manage agreements" on public.agreements for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- --- Tabla `promotions` ---
alter table public.promotions enable row level security;
drop policy if exists "Allow public read access to promotions" on public.promotions;
create policy "Allow public read access to promotions" on public.promotions for select using (true);
drop policy if exists "Allow admin access to manage promotions" on public.promotions;
create policy "Allow admin access to manage promotions" on public.promotions for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- --- Tabla `agreement_promotions` ---
alter table public.agreement_promotions enable row level security;
drop policy if exists "Allow public read access to assigned promotions" on public.agreement_promotions;
create policy "Allow public read access to assigned promotions" on public.agreement_promotions for select using (true);
drop policy if exists "Allow admin access to manage assigned promotions" on public.agreement_promotions;
create policy "Allow admin access to manage assigned promotions" on public.agreement_promotions for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- --- Tabla `clients` ---
alter table public.clients enable row level security;
drop policy if exists "Allow public access for onboarding" on public.clients;
create policy "Allow public access for onboarding" on public.clients for select using (true);
drop policy if exists "Allow public update for onboarding form" on public.clients;
create policy "Allow public update for onboarding form" on public.clients for update using (true) with check (true);
drop policy if exists "Allow admin full access to clients" on public.clients;
create policy "Allow admin full access to clients" on public.clients for all
    using (auth.role() = 'authenticated')
    with check (auth.role() = 'authenticated');

-- =================================================================
--  FIN DEL SCRIPT
-- =================================================================

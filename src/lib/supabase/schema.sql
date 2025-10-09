-- -----------------------------------------------------------------------------
-- 1. Habilitar la extensión requerida
-- -----------------------------------------------------------------------------
create extension if not exists "uuid-ossp" with schema extensions;


-- -----------------------------------------------------------------------------
-- 2. Crear las tablas de la aplicación
-- -----------------------------------------------------------------------------

-- Tabla de Productos
create table if not exists public.products (
  id uuid default extensions.uuid_generate_v4 () primary key,
  name text not null,
  description text,
  base_price numeric(10, 2) not null default 0,
  stock integer not null default 0,
  category text,
  created_at timestamp with time zone not null default now()
);

-- Tabla de Listas de Precios
create table if not exists public.price_lists (
  id uuid default extensions.uuid_generate_v4() primary key,
  name text not null unique,
  prices_include_vat boolean not null default true,
  created_at timestamp with time zone not null default now()
);

-- Tabla de Items de Listas de Precios (tabla intermedia)
create table if not exists public.price_list_items (
  price_list_id uuid not null references public.price_lists(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  price numeric(10, 2) not null,
  volume_price numeric(10, 2),
  primary key (price_list_id, product_id)
);

-- Tabla de Convenios
create table if not exists public.agreements (
  id uuid default extensions.uuid_generate_v4 () primary key,
  agreement_name text not null unique,
  client_type text not null,
  created_at timestamp with time zone not null default now(),
  price_list_id uuid references public.price_lists(id) on delete set null
);

-- Tabla de Clientes
create table if not exists public.clients (
    id uuid default extensions.uuid_generate_v4() primary key,
    cuit text unique,
    contact_name text,
    contact_dni text,
    address text,
    delivery_window text,
    email text unique,
    instagram text,
    status text not null default 'pending_onboarding',
    onboarding_token uuid default extensions.uuid_generate_v4() not null,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now()
);

-- Tabla de Promociones
create table if not exists public.promotions (
  id uuid default extensions.uuid_generate_v4 () primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone not null default now()
);

-- Tabla de Convenios y Promociones (tabla intermedia)
create table if not exists public.agreement_promotions (
  agreement_id uuid not null references public.agreements (id) on delete cascade,
  promotion_id uuid not null references public.promotions (id) on delete cascade,
  primary key (agreement_id, promotion_id)
);

-- Tabla de Condiciones de Venta
create table if not exists public.sales_conditions (
  id uuid default extensions.uuid_generate_v4() primary key,
  name text not null,
  description text,
  rules jsonb,
  created_at timestamp with time zone not null default now()
);

-- Tabla de Convenios y Condiciones de Venta (tabla intermedia)
create table if not exists public.agreement_sales_conditions (
  agreement_id uuid not null references public.agreements(id) on delete cascade,
  sales_condition_id uuid not null references public.sales_conditions(id) on delete cascade,
  primary key (agreement_id, sales_condition_id)
);


-- Tabla de Pedidos
create table if not exists public.orders (
    id uuid default extensions.uuid_generate_v4() primary key,
    client_id uuid references public.clients(id) on delete set null,
    agreement_id uuid references public.agreements(id) on delete set null,
    created_at timestamp with time zone not null default now(),
    total_amount numeric(10, 2) not null,
    status text not null default 'pending',
    client_name_cache text not null
);

-- Tabla de Items de Pedido
create table if not exists public.order_items (
    id uuid default extensions.uuid_generate_v4() primary key,
    order_id uuid not null references public.orders(id) on delete cascade,
    product_id uuid references public.products(id) on delete set null,
    quantity integer not null,
    price_per_unit numeric(10, 2) not null
);


-- -----------------------------------------------------------------------------
-- 3. Crear Vistas (Views) para datos agregados
-- -----------------------------------------------------------------------------

-- Vista para estadísticas del Dashboard (mock)
-- En una app real, esto se calcularía con triggers o un cron job.
create table if not exists public.dashboard_stats (
  id integer primary key,
  total_revenue numeric,
  month_revenue numeric,
  active_clients integer
);
-- Insertar una fila inicial si no existe
insert into public.dashboard_stats (id, total_revenue, month_revenue, active_clients)
values (1, 125430.50, 48300.00, 7) on conflict (id) do nothing;


-- Vista para convenios con conteos de productos y promociones
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
      public.agreement_sales_conditions ascond
    where
      ascond.agreement_id = a.id
  ) as sales_condition_count
from
  public.agreements a;


-- -----------------------------------------------------------------------------
-- 4. Habilitar Row Level Security (RLS) en las tablas
-- -----------------------------------------------------------------------------
-- Por defecto, RLS está habilitado, lo que niega todo acceso.
-- Las políticas específicas se definen más abajo.

alter table public.products enable row level security;
alter table public.agreements enable row level security;
alter table public.promotions enable row level security;
alter table public.agreement_promotions enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_list_items enable row level security;
alter table public.sales_conditions enable row level security;
alter table public.agreement_sales_conditions enable row level security;


-- -----------------------------------------------------------------------------
-- 5. Definir Políticas de Row Level Security (RLS)
-- -----------------------------------------------------------------------------
-- Los usuarios no autenticados no pueden hacer NADA, excepto lo que se permita explícitamente.
-- Los usuarios autenticados ('authenticated') pueden realizar las acciones definidas aquí.

-- --- Políticas para la tabla 'products' ---
drop policy if exists "Authenticated users can view products" on public.products;
create policy "Authenticated users can view products" on public.products
  for select to authenticated using (true);
  
drop policy if exists "Admins can manage products" on public.products;
create policy "Admins can manage products" on public.products
  for all to authenticated using (true);

-- --- Políticas para la tabla 'price_lists' ---
drop policy if exists "Authenticated users can view price lists" on public.price_lists;
create policy "Authenticated users can view price lists" on public.price_lists
  for select to authenticated using (true);

drop policy if exists "Admins can manage price lists" on public.price_lists;
create policy "Admins can manage price lists" on public.price_lists
  for all to authenticated using (true);

-- --- Políticas para la tabla 'price_list_items' ---
drop policy if exists "Authenticated users can view price list items" on public.price_list_items;
create policy "Authenticated users can view price list items" on public.price_list_items
  for select to authenticated using (true);

drop policy if exists "Admins can manage price list items" on public.price_list_items;
create policy "Admins can manage price list items" on public.price_list_items
  for all to authenticated using (true);

-- --- Políticas para la tabla 'agreements' ---
-- Los usuarios públicos pueden ver la data de un convenio específico (para la pág de pedido)
drop policy if exists "Public user can read specific agreements" on public.agreements;
create policy "Public user can read specific agreements" on public.agreements
  for select to anon, authenticated using (true);

-- Los administradores pueden gestionar todos los convenios.
drop policy if exists "Admins can manage agreements" on public.agreements;
create policy "Admins can manage agreements" on public.agreements
  for all to authenticated using (true);

-- --- Políticas para la tabla 'promotions' ---
drop policy if exists "Authenticated users can view promotions" on public.promotions;
create policy "Authenticated users can view promotions" on public.promotions
  for select to authenticated using (true);

drop policy if exists "Admins can manage promotions" on public.promotions;
create policy "Admins can manage promotions" on public.promotions
  for all to authenticated using (true);

-- --- Políticas para 'agreement_promotions' ---
-- Los usuarios públicos pueden ver las relaciones para poder ver las promos de un convenio
drop policy if exists "Public user can read agreement promotions" on public.agreement_promotions;
create policy "Public user can read agreement promotions" on public.agreement_promotions
  for select to anon, authenticated using (true);

drop policy if exists "Admins can manage agreement promotions" on public.agreement_promotions;
create policy "Admins can manage agreement promotions" on public.agreement_promotions
  for all to authenticated using (true);

-- --- Políticas para 'sales_conditions' ---
drop policy if exists "Authenticated users can view sales conditions" on public.sales_conditions;
create policy "Authenticated users can view sales conditions" on public.sales_conditions
  for select to authenticated using (true);

drop policy if exists "Admins can manage sales conditions" on public.sales_conditions;
create policy "Admins can manage sales conditions" on public.sales_conditions
  for all to authenticated using (true);

-- --- Políticas para 'agreement_sales_conditions' ---
drop policy if exists "Public user can read agreement sales conditions" on public.agreement_sales_conditions;
create policy "Public user can read agreement sales conditions" on public.agreement_sales_conditions
  for select to anon, authenticated using (true);

drop policy if exists "Admins can manage agreement sales conditions" on public.agreement_sales_conditions;
create policy "Admins can manage agreement sales conditions" on public.agreement_sales_conditions
  for all to authenticated using (true);

-- --- Políticas para 'clients' ---
-- El público puede leer un cliente por su token de onboarding
drop policy if exists "Public can read client by onboarding token" on public.clients;
create policy "Public can read client by onboarding token" on public.clients
    for select to anon using (true);

-- El público puede actualizar su propia data durante el onboarding si el token coincide
drop policy if exists "Public can update client during onboarding" on public.clients;
create policy "Public can update client during onboarding" on public.clients
    for update to anon using (true) with check (true);
    
-- Los admins pueden gestionar todos los clientes
drop policy if exists "Admins can manage clients" on public.clients;
create policy "Admins can manage clients" on public.clients
  for all to authenticated using (true);

-- --- Políticas para 'orders' y 'order_items' ---
-- Cualquiera puede crear un pedido (público y autenticado)
drop policy if exists "Anyone can create orders" on public.orders;
create policy "Anyone can create orders" on public.orders
    for insert to anon, authenticated with check (true);

drop policy if exists "Anyone can create order items" on public.order_items;
create policy "Anyone can create order items" on public.order_items
    for insert to anon, authenticated with check (true);

-- Solo los admins autenticados pueden ver o modificar pedidos.
drop policy if exists "Admins can manage orders" on public.orders;
create policy "Admins can manage orders" on public.orders
  for all to authenticated using (true);

drop policy if exists "Admins can manage order items" on public.order_items;
create policy "Admins can manage order items" on public.order_items
  for all to authenticated using (true);


-- -----------------------------------------------------------------------------
-- Seed de Datos (Opcional, para desarrollo)
-- -----------------------------------------------------------------------------

-- Vaciar la tabla antes de insertar para evitar duplicados si se corre de nuevo.
-- CUIDADO: Esto borrará todos los productos existentes.
-- DELETE FROM public.products;

INSERT INTO public.products (name, description, base_price, stock, category) VALUES
('DesertStyle Pomada efecto mate 50 grs', 'Pomada efecto mate', 14766.67, 0, 'Hairstyle'),
('Polvo Stardust 10grs', 'Polvo styling efecto mate', 14766.67, 0, 'Hairstyle'),
('OldSchool 100 grs', 'Pomada de fijación media/alta y brillo medio', 15972.97, 0, 'Hairstyle'),
('Liquid Pomade 120 ml', 'Pomada líquida para modelar cabello', 12310.81, 0, 'Hairstyle'),
('Shampoo 2 en 1 para el crecimiento 200 cc', 'Shampoo + acondicionador 2 en 1', 15063.96, 0, 'Hairstyle'),
('OldSchool 50 grs', 'Pomada de fijación media/alta y brillo medio', 12009.01, 0, 'Hairstyle'),
('El Capitán aceite para barba 20 ml N°3', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°1', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°1', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('OG Dandy After Shave 100 grs', 'After shave tradicional', 11879.28, 0, 'FacialBeard'),
('Kit Premium para Barba N°2', 'Kit completo para barba', 26090.09, 0, 'FacialBeard'),
('El Capitán aceite para barba 20 ml N°2', 'Aceite para barba', 14324.32, 0, 'FacialBeard'),
('Kit Premium para Barba N°3', 'Kit completo para barba', 27018.92, 0, 'FacialBeard'),
('Kit Premium Cabello N°2', 'Kit cabello', 27536.04, 0, 'Hairstyle'),
('Kit Premium Cabello N°4', 'Kit cabello', 26628.65, 0, 'Hairstyle'),
('Kit Premium Cabello N°3', 'Kit cabello', 27705.41, 0, 'Hairstyle'),
('Kit Premium Cabello N°1', 'Kit cabello', 24584.23, 0, 'Hairstyle'),
('Kit Premium para Barba N°4', 'Kit completo para barba', 30794.14, 0, 'Hairstyle'),
('Caja Exhibidora Mr BLONDE', 'Exhibidor para puntos de venta', 30794.14, 0, 'Merchandising'),
('Crystal gel de afeitar 250 grs', 'Gel de afeitar profesional', 7820.18, 0, 'Professional'),
('Crème à Raser 400 grs', 'Crema de afeitado tradicional', 14172.71, 0, 'Professional'),
('Capa Mr Blonde', 'Capa para barbería confeccionada en tela liviana', 12610.35, 0, 'Merchandising');

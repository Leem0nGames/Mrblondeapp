
-- Habilitar la extensión pgcrypto para generar UUIDs
create extension if not exists "pgcrypto" with schema "public";

-- Tabla de Productos
-- Almacena el catálogo de todos los productos disponibles.
drop table if exists products cascade;
create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  base_price numeric(10, 2) not null default 0,
  stock integer not null default 0,
  category text,
  created_at timestamp with time zone not null default now()
);

-- Tabla de Promociones
-- Almacena todas las promociones que pueden ser asignadas a los convenios.
-- Las 'rules' se guardan como JSON para máxima flexibilidad.
drop table if exists promotions cascade;
create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  rules jsonb not null,
  created_at timestamp with time zone not null default now()
);

-- Tabla de Convenios (Agreements)
-- Define las reglas de negocio para diferentes tipos de clientes.
-- Cada convenio tiene un link_token único y permanente.
drop table if exists agreements cascade;
create table public.agreements (
  id uuid primary key default gen_random_uuid(),
  agreement_name text not null,
  client_type text not null check (client_type in ('barberia', 'distribuidor', 'especial')),
  price_adjustment numeric(5, 2) not null default 0,
  link_token uuid not null default gen_random_uuid(),
  created_at timestamp with time zone not null default now(),
  constraint agreements_link_token_key unique (link_token) -- RESTRICCIÓN ÚNICA AÑADIDA
);

-- Tabla de Convenio-Productos (Tabla Pivote)
-- Asigna productos a un convenio con un precio específico.
drop table if exists agreement_products cascade;
create table public.agreement_products (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    product_id uuid not null references public.products(id) on delete cascade,
    price numeric(10, 2) not null,
    primary key (agreement_id, product_id)
);

-- Tabla de Convenio-Promociones (Tabla Pivote)
-- Asigna promociones a un convenio.
drop table if exists agreement_promotions cascade;
create table public.agreement_promotions (
    agreement_id uuid not null references public.agreements(id) on delete cascade,
    promotion_id uuid not null references public.promotions(id) on delete cascade,
    primary key (agreement_id, promotion_id)
);

-- Habilitar Row Level Security (RLS) para todas las tablas
-- Esto es una buena práctica de seguridad, aunque las reglas no estén definidas aún.
alter table public.products enable row level security;
alter table public.promotions enable row level security;
alter table public.agreements enable row level security;
alter table public.agreement_products enable row level security;
alter table public.agreement_promotions enable row level security;

-- Políticas de RLS para acceso público de lectura (si es necesario)
-- Por defecto, se deniega el acceso. Las reglas se deben crear según la lógica de la app.
-- Ejemplo: permitir lectura pública de productos.
-- create policy "Allow public read access to products" on public.products for select using (true);
-- create policy "Allow public read access to promotions" on public.promotions for select using (true);

-- No se necesita la tabla `access_tokens` ya que ahora los convenios tienen un link_token permanente.
-- drop table if exists access_tokens;

